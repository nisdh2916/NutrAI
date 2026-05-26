"""POST /detect 엔드포인트 테스트 (현재 mock 응답)."""
from __future__ import annotations

import sys
from io import BytesIO
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from fastapi.testclient import TestClient
from server.main import app

client = TestClient(app, raise_server_exceptions=True)

_FAKE_IMAGE = BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)


def _post_detect():
    _FAKE_IMAGE.seek(0)
    return client.post("/detect", files={"image": ("test.jpg", _FAKE_IMAGE, "image/jpeg")})


class TestPostDetect:
    def test_returns_200(self):
        assert _post_detect().status_code == 200

    def test_response_has_detections(self):
        data = _post_detect().json()
        assert "detections" in data
        assert isinstance(data["detections"], list)
        assert len(data["detections"]) > 0

    def test_response_has_inference_ms(self):
        data = _post_detect().json()
        assert "inference_ms" in data
        assert data["inference_ms"] >= 0

    def test_detection_item_has_food_name(self):
        detections = _post_detect().json()["detections"]
        for item in detections:
            assert "food_name" in item
            assert item["food_name"]

    def test_detection_item_confidence_in_range(self):
        detections = _post_detect().json()["detections"]
        for item in detections:
            assert 0.0 <= item["confidence"] <= 1.0

    def test_detection_item_has_bbox(self):
        detections = _post_detect().json()["detections"]
        for item in detections:
            assert "bbox" in item
            assert len(item["bbox"]) == 4
