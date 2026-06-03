"""
detect_service.py
YOLOv11m 기반 음식 탐지 + 양 추정 서비스

파이프라인:
  1. 음식 탐지 모델 (401클래스) → 음식 이름 + bbox
  2. 양 추정 모델 (Q1~Q5) → 각 음식 bbox 영역의 양 추정
  3. 결과 합산 반환
"""

from __future__ import annotations

import io
import logging
import time
from pathlib import Path
from typing import Optional

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# 모델 파일 경로
_MODEL_DIR   = Path(__file__).resolve().parents[2] / "ai" / "models"
_DETECT_PATH = _MODEL_DIR / "best.pt"
_QUANT_PATH  = _MODEL_DIR / "quantity_best.pt"

# 싱글톤 모델 인스턴스
_detect_model = None
_quant_model  = None

# 음식이 아닌 제외 클래스
_EXCLUDE = {"container"}

# 양 추정 비율 (1인분 = Q3 = 100%)
_QUANTITY_RATIO = {
    "Q1": 0.2,
    "Q2": 0.5,
    "Q3": 1.0,
    "Q4": 1.5,
    "Q5": 2.0,
}


def _load_detect_model():
    global _detect_model
    if _detect_model is not None:
        return _detect_model
    try:
        from ultralytics import YOLO
    except ImportError as e:
        raise RuntimeError("ultralytics 패키지가 필요합니다: pip install ultralytics") from e
    if not _DETECT_PATH.exists():
        raise FileNotFoundError(f"음식 탐지 모델을 찾을 수 없습니다: {_DETECT_PATH}")
    logger.info("YOLOv11m 음식 탐지 모델 로드 중: %s", _DETECT_PATH)
    _detect_model = YOLO(str(_DETECT_PATH))
    logger.info("음식 탐지 모델 로드 완료 — 클래스 수: %d", len(_detect_model.names))
    return _detect_model


def _load_quant_model():
    global _quant_model
    if _quant_model is not None:
        return _quant_model
    try:
        from ultralytics import YOLO
    except ImportError as e:
        raise RuntimeError("ultralytics 패키지가 필요합니다: pip install ultralytics") from e
    if not _QUANT_PATH.exists():
        logger.warning("양 추정 모델을 찾을 수 없습니다: %s", _QUANT_PATH)
        return None
    logger.info("YOLOv11m 양 추정 모델 로드 중: %s", _QUANT_PATH)
    _quant_model = YOLO(str(_QUANT_PATH))
    logger.info("양 추정 모델 로드 완료 — 클래스 수: %d", len(_quant_model.names))
    return _quant_model


def _estimate_quantity(img_array: np.ndarray, bbox: list[int]) -> dict:
    """
    bbox 영역을 잘라서 양 추정 모델에 입력합니다.
    반환: {"quantity_class": "Q3", "quantity_ratio": 1.0}
    """
    quant_model = _load_quant_model()
    if quant_model is None:
        return {"quantity_class": "Q3", "quantity_ratio": 1.0}

    x1, y1, x2, y2 = bbox
    h, w = img_array.shape[:2]
    x1 = max(0, x1)
    y1 = max(0, y1)
    x2 = min(w, x2)
    y2 = min(h, y2)

    crop = img_array[y1:y2, x1:x2]
    if crop.size == 0:
        return {"quantity_class": "Q3", "quantity_ratio": 1.0}

    results = quant_model.predict(source=crop, conf=0.1, verbose=False)
    if not results or len(results[0].boxes) == 0:
        return {"quantity_class": "Q3", "quantity_ratio": 1.0}

    # 가장 높은 confidence의 클래스 선택
    boxes = results[0].boxes
    best_idx = int(boxes.conf.argmax())
    cls_id   = int(boxes.cls[best_idx].item())
    cls_name = quant_model.names[cls_id]  # Q1~Q5
    ratio    = _QUANTITY_RATIO.get(cls_name, 1.0)

    return {"quantity_class": cls_name, "quantity_ratio": ratio}


def detect_foods(
    image_bytes: bytes,
    conf_threshold: float = 0.35,
    iou_threshold: float  = 0.45,
    imgsz: int            = 640,
) -> dict:
    """
    이미지 바이트에서 음식을 탐지하고 양을 추정합니다.

    Returns
    -------
    dict
        {
          "detections": [
            {
              "food_name": str,
              "confidence": float,
              "bbox": [x1,y1,x2,y2],
              "count": int,
              "quantity_class": str,   # Q1~Q5
              "quantity_ratio": float, # 0.2~2.0
            },
            ...
          ],
          "inference_ms": int
        }
    """
    detect_model = _load_detect_model()

    image     = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img_array = np.array(image)

    t0      = time.perf_counter()
    results = detect_model.predict(
        source=img_array,
        conf=conf_threshold,
        iou=iou_threshold,
        imgsz=imgsz,
        verbose=False,
    )
    inference_ms = int((time.perf_counter() - t0) * 1000)

    detections: list[dict] = []
    if results and len(results) > 0:
        result = results[0]
        boxes  = result.boxes

        food_map: dict[str, dict] = {}

        if boxes is not None and len(boxes) > 0:
            for box in boxes:
                cls_id    = int(box.cls[0].item())
                conf      = float(box.conf[0].item())
                xyxy      = box.xyxy[0].tolist()
                bbox      = [int(v) for v in xyxy]
                food_name = detect_model.names[cls_id]

                # 음식이 아닌 클래스 제외
                if food_name in _EXCLUDE:
                    continue

                if food_name not in food_map:
                    # 양 추정
                    qty = _estimate_quantity(img_array, bbox)
                    food_map[food_name] = {
                        "food_name":      food_name,
                        "confidence":     conf,
                        "bbox":           bbox,
                        "count":          1,
                        "quantity_class": qty["quantity_class"],
                        "quantity_ratio": qty["quantity_ratio"],
                    }
                else:
                    food_map[food_name]["count"] += 1
                    if conf > food_map[food_name]["confidence"]:
                        food_map[food_name]["confidence"] = conf
                        food_map[food_name]["bbox"]       = bbox

            detections = sorted(
                food_map.values(),
                key=lambda x: x["confidence"],
                reverse=True,
            )

    logger.info("탐지 완료 — %d종류, %d ms", len(detections), inference_ms)

    return {"detections": detections, "inference_ms": inference_ms}
