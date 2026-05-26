from __future__ import annotations

import re
import logging

from server.api.schemas import (
    NutritionBreakdown,
    NutritionRequest,
    NutritionResponse,
)

logger = logging.getLogger(__name__)

# 공통 정규식 — ChromaDB 문서 두 가지 포맷 모두 대응
# 포맷1(CSV): "음식명 | ... | 칼로리 165kcal | 탄수화물 0g | ..."
# 포맷2(text): "닭가슴살 100g: 칼로리 165kcal, 탄수화물 0g, ..."
_RE_KCAL    = re.compile(r"칼로리\s*([\d.]+)kcal",  re.IGNORECASE)
_RE_CARB    = re.compile(r"탄수화물\s*([\d.]+)g",    re.IGNORECASE)
_RE_PROTEIN = re.compile(r"단백질\s*([\d.]+)g",      re.IGNORECASE)
_RE_FAT     = re.compile(r"지방\s*([\d.]+)g",        re.IGNORECASE)

_GENERIC = {"kcal": 250.0, "carb_g": 30.0, "protein_g": 10.0, "fat_g": 8.0}


def _parse_nutrition(doc: str) -> dict | None:
    """ChromaDB 문서 텍스트에서 영양 수치 추출. 파싱 실패 시 None."""
    try:
        kcal    = float(_RE_KCAL.search(doc).group(1))    # type: ignore[union-attr]
        carb    = float(_RE_CARB.search(doc).group(1))    # type: ignore[union-attr]
        protein = float(_RE_PROTEIN.search(doc).group(1)) # type: ignore[union-attr]
        fat     = float(_RE_FAT.search(doc).group(1))     # type: ignore[union-attr]
        return {"kcal": kcal, "carb_g": carb, "protein_g": protein, "fat_g": fat}
    except (AttributeError, ValueError):
        return None


def _lookup_chromadb(food_name: str) -> dict | None:
    """ChromaDB에서 food_name에 가장 가까운 문서 검색 후 영양 정보 파싱."""
    try:
        from ai.rag_engine.rag_pipeline import _get_embed_model, get_collection, SIMILARITY_THRESHOLD

        embed_model = _get_embed_model()
        collection  = get_collection()
        embedding   = embed_model.encode(food_name, convert_to_numpy=True).tolist()

        results = collection.query(
            query_embeddings=[embedding],
            n_results=1,
            include=["documents", "distances"],
        )
        docs  = results["documents"][0]  if results["documents"]  else []
        dists = results["distances"][0]  if results["distances"]  else []

        if not docs or dists[0] > SIMILARITY_THRESHOLD:
            return None

        return _parse_nutrition(docs[0])
    except Exception as e:
        logger.debug("ChromaDB 조회 실패 (%s): %s", food_name, e)
        return None


def _get_nutrition(food_name: str) -> dict:
    """음식명 → 영양 정보 (100g 기준). ChromaDB 조회 → 실패 시 generic fallback."""
    result = _lookup_chromadb(food_name)
    if result:
        return result
    logger.debug("영양 정보 없음, generic fallback 사용: %s", food_name)
    return _GENERIC


def calculate_nutrition(payload: NutritionRequest) -> NutritionResponse:
    total_kcal = total_carb = total_protein = total_fat = 0.0
    breakdown: list[NutritionBreakdown] = []

    for item in payload.items:
        base    = _get_nutrition(item.food_name)
        kcal    = round(base["kcal"]      * item.serving, 2)
        carb    = round(base["carb_g"]    * item.serving, 2)
        protein = round(base["protein_g"] * item.serving, 2)
        fat     = round(base["fat_g"]     * item.serving, 2)

        total_kcal    += kcal
        total_carb    += carb
        total_protein += protein
        total_fat     += fat
        breakdown.append(NutritionBreakdown(food_name=item.food_name, kcal=kcal))

    return NutritionResponse(
        total_kcal=round(total_kcal, 2),
        carb_g=round(total_carb, 2),
        protein_g=round(total_protein, 2),
        fat_g=round(total_fat, 2),
        breakdown=breakdown,
    )
