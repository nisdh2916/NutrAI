"""
routes_detect.py
POST /detect  —  이미지를 업로드하면 YOLOv11m 모델로 음식을 탐지하고
                 탐지된 음식의 영양 정보를 ChromaDB에서 조회해 함께 반환합니다.
"""

import logging

from fastapi import APIRouter, File, HTTPException, UploadFile

from server.api.schemas import DetectResponse, DetectionItem, NutritionInfo
from server.services.detect_service import detect_foods

logger = logging.getLogger(__name__)

router = APIRouter(tags=["detect"])

_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/bmp"}


def _fetch_nutrition(food_name: str) -> NutritionInfo:
    """ChromaDB에서 음식명으로 영양 정보 조회. 실패 시 빈 값 반환."""
    try:
        from ai.rag_engine.rag_pipeline import _get_embed_model, get_collection, SIMILARITY_THRESHOLD
        import re

        embed_model = _get_embed_model()
        collection  = get_collection()
        embedding   = embed_model.encode(food_name, convert_to_numpy=True).tolist()

        results = collection.query(
            query_embeddings=[embedding],
            n_results=1,
            include=["documents", "distances", "metadatas"],
        )
        docs   = results["documents"][0]  if results["documents"]  else []
        dists  = results["distances"][0]  if results["distances"]  else []
        metas  = results["metadatas"][0]  if results["metadatas"]  else []

        if not docs or dists[0] > SIMILARITY_THRESHOLD:
            return NutritionInfo()

        doc  = docs[0]
        meta = metas[0] if metas else {}

        def parse(pattern, text):
            m = re.search(pattern, text, re.IGNORECASE)
            return float(m.group(1)) if m else 0.0

        return NutritionInfo(
            kcal      = meta.get("kcal")    or parse(r"칼로리\s*([\d.]+)kcal", doc),
            carb_g    = parse(r"탄수화물\s*([\d.]+)g",  doc),
            protein_g = meta.get("protein") or parse(r"단백질\s*([\d.]+)g",    doc),
            fat_g     = meta.get("fat")     or parse(r"지방\s*([\d.]+)g",      doc),
            sodium_mg = meta.get("sodium")  or parse(r"나트륨\s*([\d.]+)mg",   doc),
            sugar_g   = parse(r"당류\s*([\d.]+)g",    doc),
            weight_g  = parse(r"중량\s*([\d.]+)g",    doc),
        )
    except Exception as e:
        logger.debug("영양 정보 조회 실패 (%s): %s", food_name, e)
        return NutritionInfo()


@router.post("/detect", response_model=DetectResponse, summary="음식 이미지 탐지 + 영양 정보")
async def post_detect(
    image: UploadFile = File(..., description="탐지할 음식 이미지 (JPEG / PNG / WebP)"),
) -> DetectResponse:
    """
    업로드된 이미지에서 음식을 탐지하고 영양 정보를 함께 반환합니다.

    - **food_name**: 탐지된 음식 이름
    - **confidence**: 탐지 신뢰도 (0.0 ~ 1.0)
    - **bbox**: 바운딩 박스 [x1, y1, x2, y2]
    - **count**: 동일 음식 탐지 횟수
    - **nutrition**: 칼로리·탄수화물·단백질·지방·나트륨·당류·중량
    - **inference_ms**: 추론 소요 시간 (밀리초)
    """
    if image.content_type and image.content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"지원하지 않는 이미지 형식: {image.content_type}",
        )

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="빈 이미지 파일입니다.")

    try:
        result = detect_foods(image_bytes, conf_threshold=0.6)
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.exception("음식 탐지 오류: %s", e)
        raise HTTPException(status_code=500, detail="음식 탐지 처리 중 오류가 발생했습니다.")

    detections = []
    for d in result["detections"]:
        nutrition = _fetch_nutrition(d["food_name"])
        # 양 비율 적용한 영양정보 계산
        ratio = d.get("quantity_ratio", 1.0)
        if nutrition and ratio != 1.0:
            from server.api.schemas import NutritionInfo as NI
            nutrition = NI(
                kcal      = round(nutrition.kcal      * ratio, 1),
                carb_g    = round(nutrition.carb_g    * ratio, 1),
                protein_g = round(nutrition.protein_g * ratio, 1),
                fat_g     = round(nutrition.fat_g     * ratio, 1),
                sodium_mg = round(nutrition.sodium_mg * ratio, 1),
                sugar_g   = round(nutrition.sugar_g   * ratio, 1),
                weight_g  = round(nutrition.weight_g  * ratio, 1),
            )

        detections.append(
            DetectionItem(
                food_name      = d["food_name"],
                confidence     = round(d["confidence"], 4),
                bbox           = d["bbox"],
                count          = d["count"],
                quantity_class = d.get("quantity_class", "Q3"),
                quantity_ratio = d.get("quantity_ratio", 1.0),
                nutrition      = nutrition,
            )
        )

    return DetectResponse(
        detections   = detections,
        inference_ms = result["inference_ms"],
    )
