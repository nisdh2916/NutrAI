"""
build_full_db.py — 영양 ChromaDB 빌더 (옵션 B + 탐지/추천 분리)

두 개의 컬렉션을 만든다:
  • detection : 음식분류 AI 데이터 400개 — YOLO 탐지 클래스와 1:1 정렬.
                /detect 결과(food_name)를 영양정보로 매핑하는 전용 DB.
  • nutrition : K-FCDB 음식DB(19,495건) + 질환별 가이드라인 — LLM 추천/검색/RAG 전용.
                (외식 메뉴 400개는 여기 넣지 않음 → 추천 품질에 노이즈 방지)

실행:
  .venv\\Scripts\\python ai\\scripts\\db\\build_full_db.py

데이터 위치: data/nutrition_db/
  - 음식분류_AI_데이터_영양DB.xlsx   (detection)
  - 20251229_음식DB 19495건.xlsx     (nutrition)
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

import pandas as pd
from sentence_transformers import SentenceTransformer
import chromadb

REPO_ROOT  = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT))

DATA_DIR   = REPO_ROOT / "data" / "nutrition_db"
CHROMA_DIR = REPO_ROOT / "ai" / "rag_engine" / "chroma_db"

AI_XLSX    = DATA_DIR / "음식분류_AI_데이터_영양DB.xlsx"   # 400개, 컬럼 "음 식 명"
KFCDB_XLSX = DATA_DIR / "20251229_음식DB 19495건.xlsx"     # K-FCDB, 컬럼 "식품명"

EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"
BATCH_SIZE  = 2000

DETECTION_COLLECTION = "detection"
NUTRITION_COLLECTION = "nutrition"

AI_SOURCE    = "음식분류 AI 데이터 영양DB"
KFCDB_SOURCE = "Korean Food Composition Database system (K-FCDB)"

# ── K-FCDB 카테고리 기반 태깅 규칙 ──
_MORNING_CATS  = {"죽 및 스프류", "과일류", "음료 및 차류", "빵 및 과자류", "유제품류 및 빙과류", "밥류"}
_LUNCH_CATS    = {"밥류", "면 및 만두류", "국 및 탕류", "찌개 및 전골류", "구이류", "볶음류", "찜류",
                  "전·적 및 부침류", "조림류", "튀김류", "나물·숙채류", "생채·무침류", "수·조·어·육류"}
_DINNER_CATS   = {"밥류", "국 및 탕류", "찌개 및 전골류", "구이류", "볶음류", "찜류", "수·조·어·육류", "면 및 만두류"}
_SNACK_CATS    = {"빵 및 과자류", "과일류", "음료 및 차류", "두류, 견과 및 종실류"}
_HIGH_SODIUM_CATS = {"젓갈류", "김치류", "장류, 양념류", "장아찌·절임류"}
_HIGH_SUGAR_CATS  = {"음료 및 차류", "빵 및 과자류", "유제품류 및 빙과류", "과일류", "장류, 양념류"}


def _fval(row, col: str, default: float = 0.0) -> float:
    try:
        v = row.get(col)
        return float(v) if v is not None and not pd.isna(v) else default
    except (TypeError, ValueError):
        return default


def _tag(row, category: str = "") -> dict:
    kcal = _fval(row, "에너지(kcal)"); protein = _fval(row, "단백질(g)")
    fat = _fval(row, "지방(g)"); sodium = _fval(row, "나트륨(mg)")
    sugar = _fval(row, "당류(g)"); carb = _fval(row, "탄수화물(g)")
    non_diet = {"빵 및 과자류", "유제품류 및 빙과류", "튀김류", "장류, 양념류"}
    return {
        "is_morning": category in _MORNING_CATS,
        "is_lunch":   category in _LUNCH_CATS,
        "is_dinner":  category in _DINNER_CATS,
        "is_snack":   category in _SNACK_CATS,
        "is_diet": (0 < kcal <= 300 and category not in non_diet)
                   or (protein >= 15 and fat <= 8 and 0 < kcal <= 350),
        "is_diabetes": (sugar <= 5 and carb <= 30 and kcal > 0 and category not in _HIGH_SUGAR_CATS),
        "is_hypertension": (0 < sodium <= 300 and category not in _HIGH_SODIUM_CATS),
        "is_supplement": False,
    }


def _ai_doc(row) -> str:
    """음식분류 400 → 문서 (컬럼 '음 식 명')"""
    name = str(row.get("음 식 명", "")).strip()
    parts = [name]
    for col, label, unit in [
        ("중량(g)", "중량", "g"), ("에너지(kcal)", "칼로리", "kcal"),
        ("탄수화물(g)", "탄수화물", "g"), ("당류(g)", "당류", "g"),
        ("지방(g)", "지방", "g"), ("단백질(g)", "단백질", "g"),
        ("칼슘(mg)", "칼슘", "mg"), ("나트륨(mg)", "나트륨", "mg"),
        ("콜레스테롤(mg)", "콜레스테롤", "mg"),
    ]:
        v = _fval(row, col)
        if v:
            parts.append(f"{label} {round(v, 1)}{unit}")
    parts.append(f"(출처: {AI_SOURCE})")
    return " | ".join(parts)


def _kfcdb_doc(row, category: str) -> str:
    """K-FCDB → 문서 (컬럼 '식품명')"""
    name = str(row.get("식품명", "")).strip()
    parts = [name]
    if category:
        parts.append(f"분류: {category}")
    for col, label, unit in [
        ("에너지(kcal)", "칼로리", "kcal"), ("탄수화물(g)", "탄수화물", "g"),
        ("단백질(g)", "단백질", "g"), ("지방(g)", "지방", "g"),
        ("나트륨(mg)", "나트륨", "mg"), ("식이섬유(g)", "식이섬유", "g"),
        ("당류(g)", "당류", "g"), ("칼슘(mg)", "칼슘", "mg"),
        ("비타민 C(mg)", "비타민C", "mg"),
    ]:
        v = _fval(row, col)
        if v:
            parts.append(f"{label} {round(v, 1)}{unit}")
    ref = row.get("영양성분함량기준량", "100g")
    parts.append(f"(기준: {ref})")
    parts.append(f"(출처: {KFCDB_SOURCE})")
    return " | ".join(parts)


def _embed_add(collection, model, texts, metas, ids, label):
    start = time.time()
    total = len(texts)
    for s in range(0, total, BATCH_SIZE):
        bt, bm, bi = texts[s:s + BATCH_SIZE], metas[s:s + BATCH_SIZE], ids[s:s + BATCH_SIZE]
        emb = model.encode(bt, batch_size=256, show_progress_bar=False, convert_to_numpy=True).tolist()
        collection.add(ids=bi, embeddings=emb, documents=bt, metadatas=bm)
        done = min(s + BATCH_SIZE, total)
        print(f"  [{label}] {done:,}/{total:,}  ({(time.time() - start):.0f}s)")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")

    if not AI_XLSX.exists():
        raise FileNotFoundError(f"음식분류 xlsx 없음: {AI_XLSX}")
    if not KFCDB_XLSX.exists():
        raise FileNotFoundError(f"K-FCDB xlsx 없음: {KFCDB_XLSX}")

    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"디바이스: {device.upper()}")

    # ChromaDB 초기화 (한 번만)
    if CHROMA_DIR.exists():
        import shutil
        print("기존 ChromaDB 삭제 중...")
        shutil.rmtree(CHROMA_DIR)
    CHROMA_DIR.mkdir(parents=True, exist_ok=True)

    print(f"임베딩 모델 로드: {EMBED_MODEL}")
    model = SentenceTransformer(EMBED_MODEL, device=device)
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))

    # ── (1) detection 컬렉션: 음식분류 400 (YOLO 탐지 전용) ──
    df_ai = pd.read_excel(AI_XLSX, engine="openpyxl")
    df_ai = df_ai.dropna(subset=["음 식 명", "에너지(kcal)"]).drop_duplicates(subset=["음 식 명"])
    print(f"\n[detection] 음식분류 AI 데이터: {len(df_ai):,}건")
    det = client.get_or_create_collection(name=DETECTION_COLLECTION, metadata={"hnsw:space": "l2"})
    texts, metas, ids = [], [], []
    for i, (_, row) in enumerate(df_ai.iterrows()):
        nm = str(row.get("음 식 명", "")).strip()
        texts.append(_ai_doc(row))
        metas.append({"source": AI_SOURCE, "name": nm, "category": "", **_tag(row)})
        ids.append(f"det_{i}")
    _embed_add(det, model, texts, metas, ids, "detection")
    print(f"[detection] 완료: {det.count():,}건")

    # ── (2) nutrition 컬렉션: K-FCDB (LLM 추천/검색 전용) ──
    df_k = pd.read_excel(KFCDB_XLSX, engine="openpyxl")
    df_k = df_k.dropna(subset=["식품명", "에너지(kcal)"]).drop_duplicates(subset=["식품명"])
    print(f"\n[nutrition] K-FCDB 음식DB: {len(df_k):,}건")
    nut = client.get_or_create_collection(name=NUTRITION_COLLECTION, metadata={"hnsw:space": "l2"})
    texts, metas, ids = [], [], []
    for i, (_, row) in enumerate(df_k.iterrows()):
        nm = str(row.get("식품명", "")).strip()
        cat = str(row.get("식품대분류명", ""))
        texts.append(_kfcdb_doc(row, cat))
        metas.append({"source": "K-FCDB_음식DB", "name": nm, "category": cat, **_tag(row, cat)})
        ids.append(f"kfcdb_{i}")
    _embed_add(nut, model, texts, metas, ids, "nutrition")
    print(f"[nutrition] 음식 완료: {nut.count():,}건")

    # ── (3) 질환별 가이드라인 → nutrition 컬렉션에 추가 ──
    print("\n[nutrition] 가이드라인 추가 중...")
    from ai.scripts.db import build_guidelines_db
    build_guidelines_db.main()

    print(f"\n✅ 완료!")
    print(f"  detection 컬렉션: {det.count():,}건 (YOLO 탐지 매핑)")
    print(f"  nutrition 컬렉션: {nut.count():,}건 (LLM 추천/검색 + 가이드라인)")
    print("서버를 재시작하면 새 데이터가 적용됩니다.")


if __name__ == "__main__":
    main()
