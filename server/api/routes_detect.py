from fastapi import APIRouter, File, UploadFile

from server.api.schemas import DetectResponse
from server.services.detect_service import run_mock_detection

router = APIRouter(tags=["detect"])


@router.post("/detect", response_model=DetectResponse)
async def post_detect(image: UploadFile = File(...)) -> DetectResponse:
    return await run_mock_detection(image)
