"""POST /detect endpoint tests with the detector service mocked."""
from __future__ import annotations

import sys
from io import BytesIO
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from server.main import app

client = TestClient(app, raise_server_exceptions=True)


def _valid_image() -> BytesIO:
    image = Image.new("RGB", (2, 2), color=(255, 255, 255))
    buf = BytesIO()
    image.save(buf, format="JPEG")
    buf.seek(0)
    return buf


@pytest.fixture(autouse=True)
def fake_detect_foods(monkeypatch):
    def _fake_detect_foods(_contents: bytes, **_kwargs):
        return {
            "detections": [
                {
                    "food_name": "비빔밥",
                    "confidence": 0.91,
                    "bbox": [0, 0, 2, 2],
                    "count": 1,
                    "quantity_class": "Q3",
                    "quantity_ratio": 1.0,
                }
            ],
            "inference_ms": 12,
        }

    monkeypatch.setattr("server.api.routes_detect.detect_foods", _fake_detect_foods)


def _post_detect():
    return client.post(
        "/detect",
        files={"image": ("test.jpg", _valid_image(), "image/jpeg")},
    )


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

    def test_rejects_invalid_image(self):
        response = client.post(
            "/detect",
            files={"image": ("bad.jpg", BytesIO(b"not an image"), "image/jpeg")},
        )
        assert response.status_code == 400
