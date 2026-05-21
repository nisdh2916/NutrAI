"""
routes_detect.py
POST /detect  —  이미지를 업로드하면 YOLOv11m 모델로 음식을 탐지합니다.
"""

import logging

from fastapi import APIRouter, File, HTTPException, UploadFile

from server.api.schemas import DetectResponse, DetectionItem
from server.services.detect_service import detect_foods

logger = logging.getLogger(__name__)

router = APIRouter(tags=["detect"])

# 허용 MIME 타입
_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/bmp"}


@router.post("/detect", response_model=DetectResponse, summary="음식 이미지 탐지")
async def post_detect(
    image: UploadFile = File(..., description="탐지할 음식 이미지 (JPEG / PNG / WebP)"),
) -> DetectResponse:
    """
    업로드된 이미지에서 음식을 탐지하고 결과를 반환합니다.

    - **food_name**: 탐지된 음식 이름 (한국어)
    - **confidence**: 탐지 신뢰도 (0.0 ~ 1.0)
    - **bbox**: 바운딩 박스 [x1, y1, x2, y2]
    - **count**: 동일 음식 탐지 횟수
    - **inference_ms**: 추론 소요 시간 (밀리초)
    """
    # Content-Type 검증
    if image.content_type and image.content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail=(
                f"지원하지 않는 이미지 형식입니다: {image.content_type}. "
                f"허용 형식: {', '.join(_ALLOWED_CONTENT_TYPES)}"
            ),
        )

    image_bytes = await image.read()

    if not image_bytes:
        raise HTTPException(status_code=400, detail="빈 이미지 파일입니다.")

    try:
        result = detect_foods(image_bytes)
    except FileNotFoundError as e:
        logger.error("모델 파일 없음: %s", e)
        raise HTTPException(status_code=503, detail=str(e))
    except RuntimeError as e:
        logger.error("모델 로드 실패: %s", e)
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.exception("음식 탐지 중 예상치 못한 오류: %s", e)
        raise HTTPException(status_code=500, detail="음식 탐지 처리 중 오류가 발생했습니다.")

    detections = [
        DetectionItem(
            food_name=d["food_name"],
            confidence=round(d["confidence"], 4),
            bbox=d["bbox"],
            count=d["count"],
        )
        for d in result["detections"]
    ]

    return DetectResponse(
        detections=detections,
        inference_ms=result["inference_ms"],
    )
