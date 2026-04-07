import uuid
import chromadb
from pathlib import Path
from sentence_transformers import SentenceTransformer

from server.api.schemas import FoodAddRequest, FoodAddResponse

CHROMA_DIR = Path(__file__).parent.parent.parent / "ai" / "rag_engine" / "chroma_db"
EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"

_model: SentenceTransformer | None = None
_collection = None


def _get_model() -> SentenceTransformer:
    global _model
    if _model is None:
        import torch
        device = "cuda" if torch.cuda.is_available() else "cpu"
        _model = SentenceTransformer(EMBED_MODEL, device=device)
    return _model


def _get_collection():
    global _collection
    if _collection is None:
        client = chromadb.PersistentClient(path=str(CHROMA_DIR))
        _collection = client.get_or_create_collection(
            name="nutrition",
            metadata={"hnsw:space": "cosine"},
        )
    return _collection


def _food_to_doc(item: FoodAddRequest) -> str:
    parts = [item.name]
    if item.category:
        parts.append(f"분류: {item.category}")
    if item.kcal:    parts.append(f"칼로리 {item.kcal}kcal")
    if item.carb_g:  parts.append(f"탄수화물 {item.carb_g}g")
    if item.protein_g: parts.append(f"단백질 {item.protein_g}g")
    if item.fat_g:   parts.append(f"지방 {item.fat_g}g")
    if item.sodium_mg: parts.append(f"나트륨 {item.sodium_mg}mg")
    if item.fiber_g: parts.append(f"식이섬유 {item.fiber_g}g")
    if item.sugar_g: parts.append(f"당류 {item.sugar_g}g")
    parts.append(f"(기준: {item.serving})")
    return " | ".join(parts)


def add_foods(items: list[FoodAddRequest]) -> FoodAddResponse:
    model = _get_model()
    collection = _get_collection()

    texts = [_food_to_doc(item) for item in items]
    metas = [{"source": item.source, "category": item.category, "name": item.name} for item in items]
    ids = [f"custom_{uuid.uuid4().hex}" for _ in items]

    embeddings = model.encode(texts, convert_to_numpy=True).tolist()
    collection.add(ids=ids, embeddings=embeddings, documents=texts, metadatas=metas)

    return FoodAddResponse(
        added=len(items),
        failed=0,
        names=[item.name for item in items],
    )
