import io

from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import Image

from server.api.schemas import DetectResponse
from server.services.detect_service import detect_foods

router = APIRouter(tags=["detect"])


@router.post("/detect", response_model=DetectResponse)
async def post_detect(image: UploadFile = File(...)) -> DetectResponse:
    contents = await image.read()

    try:
        Image.open(io.BytesIO(contents)).verify()
    except Exception as e:
        raise HTTPException(status_code=400, detail="이미지를 읽을 수 없습니다") from e

    try:
        result = detect_foods(contents, conf_threshold=0.4)
    except (FileNotFoundError, RuntimeError) as e:
        raise HTTPException(status_code=503, detail=f"YOLO 모델 로드 실패: {e}") from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"음식 탐지 실패: {e}") from e

    return DetectResponse(**result)
