import io
import time
from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import Image

from server.api.schemas import DetectResponse, DetectionItem

router = APIRouter(tags=["detect"])

# 프로젝트 루트 기준 모델 경로 (server/api/ → 두 단계 위)
_MODEL_DIR = Path(__file__).resolve().parents[2] / "ai" / "models"
_CLASSIFY_PATH = str(_MODEL_DIR / "best.pt")
_QUANTITY_PATH = str(_MODEL_DIR / "quantity_best.pt")

_classify_model = None
_quantity_model = None


def _get_models():
    global _classify_model, _quantity_model
    if _classify_model is None:
        from ultralytics import YOLO  # noqa: PLC0415
        _classify_model = YOLO(_CLASSIFY_PATH)
    if _quantity_model is None:
        from ultralytics import YOLO  # noqa: PLC0415
        _quantity_model = YOLO(_QUANTITY_PATH)
    return _classify_model, _quantity_model


@router.post("/detect", response_model=DetectResponse)
async def post_detect(image: UploadFile = File(...)) -> DetectResponse:
    contents = await image.read()
    t0 = time.monotonic()

    try:
        classify_model, quantity_model = _get_models()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"YOLO 모델 로드 실패: {e}")

    try:
        img = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="이미지를 읽을 수 없습니다")

    # 음식 탐지 (best.pt) — conf 0.4 미만 탐지는 제외
    cls_results = classify_model(img, verbose=False, conf=0.4)

    detections: list[DetectionItem] = []
    for result in cls_results:
        for box in result.boxes:
            cls_id = int(box.cls[0])
            food_name = classify_model.names[cls_id]
            confidence = float(box.conf[0])
            x1, y1, x2, y2 = [int(v) for v in box.xyxy[0].tolist()]

            # 양 추정 (quantity_best.pt) — crop 영역에 대해 실행
            quantity_g: float | None = None
            try:
                crop = img.crop((x1, y1, x2, y2))
                qty_results = quantity_model(crop, verbose=False)
                for qr in qty_results:
                    if qr.boxes:
                        qcls = int(qr.boxes[0].cls[0])
                        qname = quantity_model.names.get(qcls, "")
                        # 클래스명에서 숫자 파싱 (예: "150g" → 150.0)
                        digits = ''.join(c for c in qname if c.isdigit() or c == '.')
                        if digits:
                            quantity_g = float(digits)
            except Exception:
                pass

            detections.append(DetectionItem(
                food_name=food_name,
                confidence=confidence,
                bbox=[x1, y1, x2, y2],
                count=1,
                quantity_g=quantity_g,
            ))

    inference_ms = int((time.monotonic() - t0) * 1000)
    return DetectResponse(detections=detections, inference_ms=inference_ms)
