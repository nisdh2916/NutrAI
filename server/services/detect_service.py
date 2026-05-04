import io
import time
from pathlib import Path

import cv2
import numpy as np
from fastapi import UploadFile

from server.api.schemas import DetectResponse, DetectionItem

MODEL_PATH = Path("C:/Users/user/Documents/NutrAI-main/ai/models/best.pt")

_model = None


def _get_model():
    global _model
    if _model is None:
        from ultralytics import YOLO
        if not MODEL_PATH.exists():
            raise FileNotFoundError(f"모델 파일을 찾을 수 없습니다: {MODEL_PATH}")
        _model = YOLO(str(MODEL_PATH))
    return _model


async def run_detection(image: UploadFile) -> DetectResponse:
    # 이미지 bytes 읽기 (딱 1번만)
    image_bytes = await image.read()
    print("bytes 크기:", len(image_bytes))

    # cv2로 디코딩 (BGR)
    nparr = np.frombuffer(image_bytes, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img_bgr is None:
        print("cv2 디코딩 실패, PIL로 재시도")
        from PIL import Image
        pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        img_bgr = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)

    print("이미지 shape:", img_bgr.shape)

    model = _get_model()

    start = time.perf_counter()
    results = model(img_bgr, verbose=False, conf=0.1)
    elapsed_ms = int((time.perf_counter() - start) * 1000)

    detections: list[DetectionItem] = []
    seen: dict[str, int] = {}

    for result in results:
        boxes = result.boxes
        if boxes is None:
            continue
        print("감지 수:", len(boxes))
        for box in boxes:
            confidence = float(box.conf[0])
            class_id = int(box.cls[0])
            food_name = model.names[class_id]
            x1, y1, x2, y2 = [int(v) for v in box.xyxy[0].tolist()]
            print(f"  -> {food_name}: {confidence:.2f}")

            if food_name in seen:
                seen[food_name] += 1
                for item in detections:
                    if item.food_name == food_name:
                        item.count = seen[food_name]
                        break
            else:
                seen[food_name] = 1
                detections.append(DetectionItem(
                    food_name=food_name,
                    confidence=round(confidence, 4),
                    bbox=[x1, y1, x2, y2],
                    count=1,
                ))

    return DetectResponse(detections=detections, inference_ms=elapsed_ms)


run_mock_detection = run_detection
