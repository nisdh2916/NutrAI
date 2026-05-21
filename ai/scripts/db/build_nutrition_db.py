"""
음식분류 AI 데이터 영양DB xlsx → ChromaDB 벡터 DB 구축 스크립트

데이터: 음식분류_AI_데이터_영양DB.xlsx (400개 외식메뉴)

실행:
  python -m ai.scripts.db.build_nutrition_db

특징:
  - GPU 자동 사용 (CUDA)
  - 체크포인트 지원 (끊겨도 이어서 시작)
"""

import sys
import time
import json
import pandas as pd
from pathlib import Path
from sentence_transformers import SentenceTransformer
import chromadb

REPO_ROOT  = Path(__file__).parent.parent.parent.parent
DATA_DIR   = REPO_ROOT / "data" / "nutrition_db"
CHROMA_DIR = REPO_ROOT / "ai" / "rag_engine" / "chroma_db"
CHECKPOINT = REPO_ROOT / "ai" / "rag_engine" / "build_checkpoint.json"

# 업로드된 파일명
FOOD_XLSX = DATA_DIR / "음식분류_AI_데이터_영양DB.xlsx"

EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"
BATCH_SIZE  = 256

SOURCE = "음식분류 AI 데이터 영양DB"


def _fval(row, col: str, default: float = 0.0) -> float:
    try:
        v = row.get(col)
        return float(v) if v is not None and not pd.isna(v) else default
    except (TypeError, ValueError):
        return default


def tag_row(row) -> dict:
    """영양소 기반 boolean 메타데이터 태그 계산."""
    kcal    = _fval(row, "에너지(kcal)")
    protein = _fval(row, "단백질(g)")
    fat     = _fval(row, "지방(g)")
    sodium  = _fval(row, "나트륨(mg)")
    sugar   = _fval(row, "당류(g)")
    carb    = _fval(row, "탄수화물(g)")

    is_diet = (
        (0 < kcal <= 400)
        or (protein >= 15 and fat <= 8 and 0 < kcal <= 500)
    )
    is_diabetes = sugar <= 5 and carb <= 40 and kcal > 0
    is_hypertension = 0 < sodium <= 400

    return {
        "is_diet":         is_diet,
        "is_diabetes":     is_diabetes,
        "is_hypertension": is_hypertension,
    }


def row_to_doc(row) -> str:
    name   = str(row.get("음 식 명", "")).strip()
    weight = _fval(row, "중량(g)")
    kcal   = _fval(row, "에너지(kcal)")
    carb   = _fval(row, "탄수화물(g)")
    sugar  = _fval(row, "당류(g)")
    fat    = _fval(row, "지방(g)")
    prot   = _fval(row, "단백질(g)")
    calc   = _fval(row, "칼슘(mg)")
    sodium = _fval(row, "나트륨(mg)")
    chol   = _fval(row, "콜레스테롤(mg)")

    parts = [name]
    if weight: parts.append(f"중량 {round(weight,1)}g")
    if kcal:   parts.append(f"칼로리 {round(kcal,1)}kcal")
    if carb:   parts.append(f"탄수화물 {round(carb,1)}g")
    if sugar:  parts.append(f"당류 {round(sugar,1)}g")
    if fat:    parts.append(f"지방 {round(fat,1)}g")
    if prot:   parts.append(f"단백질 {round(prot,1)}g")
    if calc:   parts.append(f"칼슘 {round(calc,1)}mg")
    if sodium: parts.append(f"나트륨 {round(sodium,1)}mg")
    if chol:   parts.append(f"콜레스테롤 {round(chol,1)}mg")
    parts.append(f"(출처: {SOURCE})")

    return " | ".join(parts)


def load_food_docs() -> tuple[list[str], list[dict]]:
    print(f"영양DB 로드 중: {FOOD_XLSX.name}")
    if not FOOD_XLSX.exists():
        raise FileNotFoundError(
            f"파일을 찾을 수 없습니다: {FOOD_XLSX}\n"
            f"다음 경로에 파일을 복사하세요: {DATA_DIR}"
        )
    df = pd.read_excel(FOOD_XLSX, engine="openpyxl")
    df = df.dropna(subset=["음 식 명", "에너지(kcal)"])
    df = df.drop_duplicates(subset=["음 식 명"])
    print(f"  → {len(df):,}건")

    texts, metas = [], []
    for _, row in df.iterrows():
        texts.append(row_to_doc(row))
        metas.append({
            "source":  SOURCE,
            "name":    str(row.get("음 식 명", "")).strip(),
            "kcal":    _fval(row, "에너지(kcal)"),
            "protein": _fval(row, "단백질(g)"),
            "fat":     _fval(row, "지방(g)"),
            "sodium":  _fval(row, "나트륨(mg)"),
            **tag_row(row),
        })
    return texts, metas


def load_checkpoint() -> int:
    if CHECKPOINT.exists():
        data = json.loads(CHECKPOINT.read_text(encoding="utf-8"))
        return data.get("done", 0)
    return 0


def save_checkpoint(done: int):
    CHECKPOINT.write_text(json.dumps({"done": done}), encoding="utf-8")


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"디바이스: {device.upper()}")
    print(f"출처: {SOURCE}\n")

    start_from = load_checkpoint()
    if start_from > 0:
        print(f"체크포인트 발견: {start_from:,}건부터 이어서 시작")
    else:
        if CHROMA_DIR.exists():
            import shutil
            print("기존 ChromaDB 삭제 중...")
            shutil.rmtree(CHROMA_DIR)

    texts, metas = load_food_docs()
    total = len(texts)
    print(f"\n총 {total:,}개 문서")

    print(f"임베딩 모델 로드 중: {EMBED_MODEL}")
    model = SentenceTransformer(EMBED_MODEL, device=device)

    CHROMA_DIR.mkdir(parents=True, exist_ok=True)
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    collection = client.get_or_create_collection(
        name="nutrition",
        metadata={"hnsw:space": "l2"},
    )

    print(f"\nEmbedding 시작 (배치 {BATCH_SIZE}건씩)\n")
    start = time.time()

    for i in range(start_from, total, BATCH_SIZE):
        batch_texts = texts[i : i + BATCH_SIZE]
        batch_metas = metas[i : i + BATCH_SIZE]
        batch_ids   = [f"doc_{j}" for j in range(i, i + len(batch_texts))]

        embeddings = model.encode(
            batch_texts,
            batch_size=64,
            show_progress_bar=False,
            convert_to_numpy=True,
        ).tolist()

        collection.add(
            ids=batch_ids,
            embeddings=embeddings,
            documents=batch_texts,
            metadatas=batch_metas,
        )

        done = i + len(batch_texts)
        save_checkpoint(done)

        elapsed = time.time() - start
        speed = (done - start_from) / elapsed if elapsed > 0 else 0
        pct = done * 100 // total
        print(f"  [{pct:3d}%] {done}/{total}건  경과: {elapsed:.1f}초  속도: {speed:.0f}건/초", flush=True)

    CHECKPOINT.unlink(missing_ok=True)
    total_sec = time.time() - start
    print(f"\n✅ 완료! 총 소요: {total_sec:.1f}초")
    print(f"ChromaDB 저장 위치: {CHROMA_DIR}")
    print(f"총 문서 수: {collection.count():,}건")
    print("서버를 재시작하면 새 데이터가 적용됩니다.")


if __name__ == "__main__":
    main()
