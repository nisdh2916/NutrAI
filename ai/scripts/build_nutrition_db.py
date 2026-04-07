"""
식품영양성분 CSV → ChromaDB 벡터 DB 전체 구축 스크립트

사전 준비:
  .venv\Scripts\pip install sentence-transformers

실행:
  .venv\Scripts\python ai\scripts\build_nutrition_db.py

데이터:
  - 음식 데이터   ~15,568건 (중복제거 후)
  - 가공식품 데이터 ~232,202건 (중복제거 후)
  - 합계 ~247,770건
  - 예상 시간: 30분~1시간 (RTX GPU 기준)

특징:
  - GPU 자동 사용 (CUDA)
  - 체크포인트 지원 (끊겨도 이어서 시작)
"""
import time
import json
import pandas as pd
from pathlib import Path
from sentence_transformers import SentenceTransformer
import chromadb

# ── 경로 설정 ────────────────────────────────────────────
REPO_ROOT   = Path(__file__).parent.parent.parent
DATA_DIR    = REPO_ROOT / "data" / "nutrition_db"
CHROMA_DIR  = REPO_ROOT / "ai" / "rag_engine" / "chroma_db"
CHECKPOINT  = REPO_ROOT / "ai" / "rag_engine" / "build_checkpoint.json"

FOOD_CSV = DATA_DIR / "식품의약품안전처_통합식품영양성분정보(음식)_20251229 (1).csv"
PROC_CSV = DATA_DIR / "식품의약품안전처_통합식품영양성분정보(가공식품)_20260402.csv"

EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"  # 한국어 특화 모델
BATCH_SIZE  = 2000  # GPU 사용 시 큰 배치 가능


def safe(val, unit=""):
    if pd.isna(val):
        return ""
    return f"{round(float(val), 1)}{unit}"


def row_to_doc(row, category="") -> str:
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

    return " | ".join(parts)


def load_all_docs() -> tuple[list[str], list[dict]]:
    """전체 문서 로드 → (texts, metadatas)"""
    texts, metas = [], []

    print("음식 데이터 로드 중...")
    df = pd.read_csv(FOOD_CSV, encoding="utf-8", low_memory=False)
    df = df.dropna(subset=["식품명", "에너지(kcal)"]).drop_duplicates(subset=["식품명"])
    print(f"  → {len(df)}건")
    for _, row in df.iterrows():
        cat = str(row.get("식품대분류명", ""))
        texts.append(row_to_doc(row, cat))
        metas.append({"source": "음식DB", "category": cat, "name": str(row.get("식품명", ""))})

    print("가공식품 데이터 로드 중...")
    df = pd.read_csv(PROC_CSV, encoding="utf-8", low_memory=False)
    df = df.dropna(subset=["식품명", "에너지(kcal)"]).drop_duplicates(subset=["식품명"])
    print(f"  → {len(df)}건")
    for _, row in df.iterrows():
        cat = str(row.get("식품대분류명", row.get("식품기원명", "")))
        texts.append(row_to_doc(row, cat))
        metas.append({"source": "가공식품DB", "category": cat, "name": str(row.get("식품명", ""))})

    print(f"총 {len(texts)}개 문서 생성 완료")
    return texts, metas


def load_checkpoint() -> int:
    if CHECKPOINT.exists():
        data = json.loads(CHECKPOINT.read_text())
        return data.get("done", 0)
    return 0


def save_checkpoint(done: int):
    CHECKPOINT.write_text(json.dumps({"done": done}))


def main():
    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"디바이스: {device.upper()}")

    # 체크포인트 확인
    start_from = load_checkpoint()
    if start_from > 0:
        print(f"체크포인트 발견: {start_from:,}건부터 이어서 시작")
    else:
        # 처음 시작 시 기존 ChromaDB 삭제
        if CHROMA_DIR.exists():
            import shutil
            print("기존 ChromaDB 삭제 중...")
            shutil.rmtree(CHROMA_DIR)

    texts, metas = load_all_docs()
    total = len(texts)

    print(f"\n모델 로드 중: {EMBED_MODEL}")
    model = SentenceTransformer(EMBED_MODEL, device=device)

    # ChromaDB 초기화
    CHROMA_DIR.mkdir(parents=True, exist_ok=True)
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    collection = client.get_or_create_collection(
        name="nutrition",
        metadata={"hnsw:space": "cosine"},
    )

    print(f"\nEmbedding 시작 (배치 {BATCH_SIZE}건씩)")
    start = time.time()

    for i in range(start_from, total, BATCH_SIZE):
        batch_texts = texts[i:i + BATCH_SIZE]
        batch_metas = metas[i:i + BATCH_SIZE]
        batch_ids   = [f"doc_{j}" for j in range(i, i + len(batch_texts))]

        # GPU 배치 임베딩
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
        print(f"  [{pct:3d}%] {done:,}/{total:,}건  "
              f"경과: {elapsed/60:.1f}분  남은시간: {eta/60:.1f}분  "
              f"속도: {speed:.0f}건/초", flush=True)

    total_min = (time.time() - start) / 60
    CHECKPOINT.unlink(missing_ok=True)  # 체크포인트 삭제
    print(f"\n완료! 총 소요: {total_min:.1f}분")
    print(f"ChromaDB 저장 위치: {CHROMA_DIR}")
    print("서버를 재시작하면 새 데이터가 적용됩니다.")


if __name__ == "__main__":
    main()
