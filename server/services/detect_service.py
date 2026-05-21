"""
food_detect_service.py
YOLOv11m 기반 음식 탐지 서비스
- ai/models/best.pt (YOLOv11m, 800 클래스) 모델을 싱글톤으로 로드
- 이미지 바이트를 받아 DetectionItem 리스트 반환
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

# 모델 파일 경로 (프로젝트 루트 기준)
_MODEL_PATH = Path(__file__).resolve().parents[2] / "ai" / "models" / "best.pt"

# 싱글톤 모델 인스턴스
_model = None


def _load_model():
    """YOLO 모델을 싱글톤으로 로드합니다."""
    global _model
    if _model is not None:
        return _model

    try:
        from ultralytics import YOLO  # type: ignore
    except ImportError as e:
        raise RuntimeError(
            "ultralytics 패키지가 설치되어 있지 않습니다. "
            "`pip install ultralytics` 를 실행하세요."
        ) from e

    if not _MODEL_PATH.exists():
        raise FileNotFoundError(
            f"YOLO 모델 파일을 찾을 수 없습니다: {_MODEL_PATH}\n"
            "ai/models/best.pt 경로에 모델 파일을 배치하세요."
        )

    logger.info("YOLOv11m 모델 로드 중: %s", _MODEL_PATH)
    _model = YOLO(str(_MODEL_PATH))
    logger.info("YOLOv11m 모델 로드 완료 — 클래스 수: %d", len(_model.names))
    return _model


def detect_foods(
    image_bytes: bytes,
    conf_threshold: float = 0.25,
    iou_threshold: float = 0.45,
    imgsz: int = 640,
) -> dict:
    """
    이미지 바이트에서 음식을 탐지합니다.

    Parameters
    ----------
    image_bytes : bytes
        업로드된 이미지 파일의 원시 바이트
    conf_threshold : float
        신뢰도 임계값 (기본값: 0.25)
    iou_threshold : float
        NMS IoU 임계값 (기본값: 0.45)
    imgsz : int
        추론 이미지 크기 (기본값: 640)

    Returns
    -------
    dict
        {
          "detections": [
            {"food_name": str, "confidence": float, "bbox": [x1,y1,x2,y2], "count": int},
            ...
          ],
          "inference_ms": int
        }
    """
    model = _load_model()

    # 바이트 → PIL Image → numpy array
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img_array = np.array(image)

    # 추론
    t0 = time.perf_counter()
    results = model.predict(
        source=img_array,
        conf=conf_threshold,
        iou=iou_threshold,
        imgsz=imgsz,
        verbose=False,
    )
    inference_ms = int((time.perf_counter() - t0) * 1000)

    # 결과 파싱
    detections: list[dict] = []
    if results and len(results) > 0:
        result = results[0]
        boxes = result.boxes

        if boxes is not None and len(boxes) > 0:
            # 음식 이름별로 집계 (중복 탐지 처리)
            food_map: dict[str, dict] = {}

            for box in boxes:
                cls_id = int(box.cls[0].item())
                conf = float(box.conf[0].item())
                xyxy = box.xyxy[0].tolist()
                bbox = [int(v) for v in xyxy]  # [x1, y1, x2, y2]
                food_name = model.names[cls_id]

                if food_name not in food_map:
                    food_map[food_name] = {
                        "food_name": food_name,
                        "confidence": conf,
                        "bbox": bbox,
                        "count": 1,
                    }
                else:
                    # 같은 음식이 여러 번 탐지되면 count 증가, 최고 confidence 유지
                    food_map[food_name]["count"] += 1
                    if conf > food_map[food_name]["confidence"]:
                        food_map[food_name]["confidence"] = conf
                        food_map[food_name]["bbox"] = bbox

            # confidence 내림차순 정렬
            detections = sorted(
                food_map.values(),
                key=lambda x: x["confidence"],
                reverse=True,
            )

    logger.info(
        "탐지 완료 — 음식 %d 종류, 추론 시간: %d ms",
        len(detections),
        inference_ms,
    )

    return {
        "detections": detections,
        "inference_ms": inference_ms,
    }
