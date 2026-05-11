"""
식품영양성분 xlsx → ChromaDB 벡터 DB 구축 스크립트

데이터 출처:
  한글: 식품영양성분 데이터베이스
  영문: Korean Food Composition Database system (K-FCDB)

실행:
  .venv\Scripts\python ai\scripts\build_nutrition_db.py [--all]

옵션:
  (없음)   음식DB만 빌드 (~19,495건, 5~10분)
  --all    음식DB + 가공식품DB 모두 빌드 (~296,000건, 1시간+)

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

REPO_ROOT  = Path(__file__).parent.parent.parent
DATA_DIR   = REPO_ROOT / "data" / "nutrition_db"
CHROMA_DIR = REPO_ROOT / "ai" / "rag_engine" / "chroma_db"
CHECKPOINT = REPO_ROOT / "ai" / "rag_engine" / "build_checkpoint.json"

FOOD_XLSX = DATA_DIR / "20251229_음식DB 19495건.xlsx"
PROC_XLSX = DATA_DIR / "20260429_가공식품_277074건.xlsx"

EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"
BATCH_SIZE  = 2000

SOURCE_KR = "식품영양성분 데이터베이스"
SOURCE_EN = "Korean Food Composition Database system (K-FCDB)"


def safe(val, unit="") -> str:
    try:
        if pd.isna(val):
            return ""
        return f"{round(float(val), 1)}{unit}"
    except (TypeError, ValueError):
        return ""


def row_to_doc(row, category: str = "") -> str:
    name  = str(row.get("식품명", "")).strip()
    kcal  = safe(row.get("에너지(kcal)"), "kcal")
    carb  = safe(row.get("탄수화물(g)"), "g")
    prot  = safe(row.get("단백질(g)"), "g")
    fat   = safe(row.get("지방(g)"), "g")
    sod   = safe(row.get("나트륨(mg)"), "mg")
    fiber = safe(row.get("식이섬유(g)"), "g")
    sugar = safe(row.get("당류(g)"), "g")
    calc  = safe(row.get("칼슘(mg)"), "mg")
    vitc  = safe(row.get("비타민 C(mg)"), "mg")

    parts = [name]
    if category:
        parts.append(f"분류: {category}")
    if kcal:  parts.append(f"칼로리 {kcal}")
    if carb:  parts.append(f"탄수화물 {carb}")
    if prot:  parts.append(f"단백질 {prot}")
    if fat:   parts.append(f"지방 {fat}")
    if sod:   parts.append(f"나트륨 {sod}")
    if fiber: parts.append(f"식이섬유 {fiber}")
    if sugar: parts.append(f"당류 {sugar}")
    if calc:  parts.append(f"칼슘 {calc}")
    if vitc:  parts.append(f"비타민C {vitc}")

    ref = row.get("영양성분함량기준량", "100g")
    parts.append(f"(기준: {ref})")
    parts.append(f"(출처: {SOURCE_EN})")

    return " | ".join(parts)


def load_food_docs() -> tuple[list[str], list[dict]]:
    """음식DB xlsx 로드"""
    print(f"음식DB 로드 중: {FOOD_XLSX.name}")
    df = pd.read_excel(FOOD_XLSX, engine="openpyxl")
    df = df.dropna(subset=["식품명", "에너지(kcal)"]).drop_duplicates(subset=["식품명"])
    print(f"  → {len(df):,}건")

    texts, metas = [], []
    for _, row in df.iterrows():
        cat = str(row.get("식품대분류명", ""))
        texts.append(row_to_doc(row, cat))
        metas.append({
            "source": "K-FCDB_음식DB",
            "source_kr": SOURCE_KR,
            "source_en": SOURCE_EN,
            "category": cat,
            "name": str(row.get("식품명", "")),
        })
    return texts, metas


def load_proc_docs() -> tuple[list[str], list[dict]]:
    """가공식품DB xlsx 로드"""
    print(f"가공식품DB 로드 중: {PROC_XLSX.name}")
    df = pd.read_excel(PROC_XLSX, engine="openpyxl")
    df = df.dropna(subset=["식품명", "에너지(kcal)"]).drop_duplicates(subset=["식품명"])
    print(f"  → {len(df):,}건")

    texts, metas = [], []
    for _, row in df.iterrows():
        cat = str(row.get("식품대분류명", row.get("식품기원명", "")))
        texts.append(row_to_doc(row, cat))
        metas.append({
            "source": "K-FCDB_가공식품DB",
            "source_kr": SOURCE_KR,
            "source_en": SOURCE_EN,
            "category": cat,
            "name": str(row.get("식품명", "")),
        })
    return texts, metas


def load_checkpoint() -> int:
    if CHECKPOINT.exists():
        data = json.loads(CHECKPOINT.read_text())
        return data.get("done", 0)
    return 0


def save_checkpoint(done: int):
    CHECKPOINT.write_text(json.dumps({"done": done}))


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    include_proc = "--all" in sys.argv

    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"디바이스: {device.upper()}")
    print(f"모드: {'음식DB + 가공식품DB' if include_proc else '음식DB만'}")
    print(f"출처: {SOURCE_KR} ({SOURCE_EN})\n")

    start_from = load_checkpoint()
    if start_from > 0:
        print(f"체크포인트 발견: {start_from:,}건부터 이어서 시작")
    else:
        if CHROMA_DIR.exists():
            import shutil
            print("기존 ChromaDB 삭제 중...")
            shutil.rmtree(CHROMA_DIR)

    texts, metas = load_food_docs()
    if include_proc:
        t2, m2 = load_proc_docs()
        texts += t2
        metas += m2

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

    print(f"\nEmbedding 시작 (배치 {BATCH_SIZE:,}건씩)\n")
    start = time.time()

    for i in range(start_from, total, BATCH_SIZE):
        batch_texts = texts[i : i + BATCH_SIZE]
        batch_metas = metas[i : i + BATCH_SIZE]
        batch_ids   = [f"doc_{j}" for j in range(i, i + len(batch_texts))]

        embeddings = model.encode(
            batch_texts,
            batch_size=256,
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
        eta = (total - done) / speed if speed > 0 else 0
        pct = done * 100 // total
        print(
            f"  [{pct:3d}%] {done:,}/{total:,}건  "
            f"경과: {elapsed/60:.1f}분  남은시간: {eta/60:.1f}분  "
            f"속도: {speed:.0f}건/초",
            flush=True,
        )

    CHECKPOINT.unlink(missing_ok=True)
    total_min = (time.time() - start) / 60
    print(f"\n완료! 총 소요: {total_min:.1f}분")
    print(f"ChromaDB 저장 위치: {CHROMA_DIR}")
    print(f"총 문서 수: {collection.count():,}건")
    print("서버를 재시작하면 새 데이터가 적용됩니다.")


if __name__ == "__main__":
    main()
