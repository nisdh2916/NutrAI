from fastapi import APIRouter, File, UploadFile

from server.api.schemas import DetectResponse, DetectionItem

router = APIRouter(tags=["detect"])


@router.post("/detect", response_model=DetectResponse)
async def post_detect(image: UploadFile = File(...)) -> DetectResponse:
    # TODO: YOLO 모델 통합 전 mock 응답
    await image.read()
    return DetectResponse(
        detections=[
            DetectionItem(food_name="김치찌개", confidence=0.91, bbox=[120, 80, 300, 260], count=1),
            DetectionItem(food_name="쌀밥", confidence=0.95, bbox=[320, 110, 510, 300], count=1),
        ],
        inference_ms=820,
    )
