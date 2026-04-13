import re

from fastapi import APIRouter, Query

from server.api.schemas import (
    FoodAddRequest, FoodBulkAddRequest, FoodAddResponse,
    FoodSearchResponse, FoodSearchResult,
)
from server.services.food_add_service import add_foods
from ai.rag_engine.rag_pipeline import get_collection, _get_embed_model

router = APIRouter(tags=["food"])


@router.post("/food/add", response_model=FoodAddResponse)
def post_food_add(payload: FoodAddRequest) -> FoodAddResponse:
    """식품 단건 추가"""
    return add_foods([payload])


@router.post("/food/bulk", response_model=FoodAddResponse)
def post_food_bulk(payload: FoodBulkAddRequest) -> FoodAddResponse:
    """식품 일괄 추가"""
    return add_foods(payload.items)


def _parse_float(text: str, label: str) -> float:
    """문서 텍스트에서 '라벨 숫자단위' 패턴 추출"""
    m = re.search(rf"{label}\s*([\d.]+)", text)
    return float(m.group(1)) if m else 0.0


def _doc_to_result(doc: str) -> FoodSearchResult:
    """ChromaDB 문서 텍스트를 FoodSearchResult로 변환"""
    # 이름: 첫 번째 구분자 전까지
    sep = " , " if " , " in doc else " | "
    parts = doc.split(sep)
    name = parts[0].strip()

    category = ""
    for p in parts:
        if "분류:" in p:
            category = p.replace("분류:", "").strip()
            break

    serving = ""
    for p in parts:
        if "기준:" in p:
            serving = p.replace("(기준:", "").replace(")", "").strip()
            break

    return FoodSearchResult(
        name=name,
        category=category,
        kcal=_parse_float(doc, "칼로리"),
        carb_g=_parse_float(doc, "탄수화물"),
        protein_g=_parse_float(doc, "단백질"),
        fat_g=_parse_float(doc, "지방"),
        sodium_mg=_parse_float(doc, "나트륨"),
        sugar_g=_parse_float(doc, "당류"),
        sat_fat_g=_parse_float(doc, "포화지방산"),
        cholesterol_mg=_parse_float(doc, "콜레스테롤"),
        serving=serving,
    )


@router.get("/food/search", response_model=FoodSearchResponse)
def get_food_search(
    q: str = Query(..., min_length=1, description="검색어"),
    k: int = Query(5, ge=1, le=20, description="결과 수"),
) -> FoodSearchResponse:
    """ChromaDB에서 음식 시맨틱 검색"""
    model = _get_embed_model()
    emb = model.encode(q, convert_to_numpy=True).tolist()
    collection = get_collection()
    results = collection.query(query_embeddings=[emb], n_results=k)
    docs = results["documents"][0] if results["documents"] else []
    return FoodSearchResponse(results=[_doc_to_result(d) for d in docs])
