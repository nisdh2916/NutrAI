from fastapi import UploadFile

from server.api.schemas import DetectResponse, DetectionItem


async def run_mock_detection(image: UploadFile) -> DetectResponse:
    await image.read()

    detections = [
        DetectionItem(food_name="김치찌개", confidence=0.91, bbox=[120, 80, 300, 260], count=1),
        DetectionItem(food_name="쌀밥", confidence=0.95, bbox=[320, 110, 510, 300], count=1),
    ]
    return DetectResponse(detections=detections, inference_ms=820)
