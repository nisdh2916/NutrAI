"""
nutrition_data.py 샘플 데이터 → ChromaDB 빌드 스크립트

실행:
  .venv\Scripts\python ai\scripts\build_sample_db.py

기존 'nutrition' 컬렉션을 삭제하고 nutrition_data.py 전체를 새로 임베딩한다.
메타데이터(meal_time, goal_tag, category, source)도 함께 저장한다.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

import chromadb
from sentence_transformers import SentenceTransformer
from ai.rag_engine.nutrition_data import get_all_items


def _expand_meta(meta: dict) -> dict:
    """meal_time, goal_tag 문자열 → bool 플래그로 변환 (ChromaDB where 필터용)"""
    times = {t.strip() for t in meta.get("meal_time", "").split(",")}
    is_all = "all" in times
    meta["is_morning"] = is_all or "아침" in times
    meta["is_lunch"] = is_all or "점심" in times
    meta["is_dinner"] = is_all or "저녁" in times
    meta["is_snack"] = is_all or "간식" in times

    tags = {t.strip() for t in meta.get("goal_tag", "").split(",")}
    meta["is_diet"] = "다이어트" in tags
    meta["is_muscle"] = "근육증가" in tags
    meta["is_diabetes"] = "당뇨" in tags
    meta["is_hypertension"] = "고혈압" in tags
    meta["is_supplement"] = meta.get("category") == "건강기능식품"
    return meta

CHROMA_DIR = ROOT / "ai" / "rag_engine" / "chroma_db"
EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    items = get_all_items()
    print(f"데이터 로드 완료: {len(items)}개")

    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"임베딩 모델 로드 중 ({device})...")
    model = SentenceTransformer(EMBED_MODEL, device=device)

    CHROMA_DIR.mkdir(parents=True, exist_ok=True)
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))

    # 기존 컬렉션 삭제 후 재생성
    try:
        client.delete_collection("nutrition")
        print("기존 컬렉션 삭제 완료")
    except Exception:
        pass

    collection = client.create_collection(
        name="nutrition",
        metadata={"hnsw:space": "l2"},
    )

    texts = [t for t, _ in items]
    raw_metas = [m for _, m in items]
    metas = [_expand_meta(dict(m)) for m in raw_metas]
    ids = [f"sample_{i}" for i in range(len(items))]

    print("임베딩 중...")
    embeddings = model.encode(texts, show_progress_bar=True, convert_to_numpy=True)

    collection.add(
        ids=ids,
        documents=texts,
        embeddings=embeddings.tolist(),
        metadatas=metas,
    )

    print(f"\n완료! ChromaDB 문서 수: {collection.count()}")
    print(f"저장 위치: {CHROMA_DIR}")


if __name__ == "__main__":
    main()
