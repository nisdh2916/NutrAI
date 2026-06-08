"""POST /meals 및 GET /meals 엔드포인트 테스트. sqlite_store는 mock."""
from __future__ import annotations

import sys
from pathlib import Path
from datetime import datetime
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from fastapi.testclient import TestClient
from server.main import app

client = TestClient(app, raise_server_exceptions=True)

_MOCK_MEAL_ID = "m_abc123456789"
_MOCK_DB_MEALS = [
    {
        "meal_id": "m_xyz987654321",
        "eaten_at": datetime(2024, 1, 15, 12, 30),
        "items": [{"food_name": "밥", "serving": 1.0, "kcal": 300.0}],
        "total_kcal": 300.0,
    }
]

_CREATE_PAYLOAD = {
    "user_id": "user_001",
    "eaten_at": "2024-01-15T12:30:00",
    "items": [{"food_name": "밥", "serving": 1.0, "kcal": 300.0}],
    "total_kcal": 300.0,
}


def _patch_insert(return_value=_MOCK_MEAL_ID):
    return patch("server.services.meal_service.insert_meal", return_value=return_value)


def _patch_find(return_value=_MOCK_DB_MEALS):
    return patch("server.services.meal_service.find_meals_by_date", return_value=return_value)


class TestPostMeals:
    def test_returns_200(self):
        with _patch_insert():
            res = client.post("/meals", json=_CREATE_PAYLOAD)
        assert res.status_code == 200

    def test_response_has_meal_id(self):
        with _patch_insert():
            data = client.post("/meals", json=_CREATE_PAYLOAD).json()
        assert "meal_id" in data
        assert data["meal_id"] == _MOCK_MEAL_ID

    def test_response_saved_true(self):
        with _patch_insert():
            data = client.post("/meals", json=_CREATE_PAYLOAD).json()
        assert data["saved"] is True

    def test_missing_user_id_rejected(self):
        payload = {**_CREATE_PAYLOAD}
        del payload["user_id"]
        res = client.post("/meals", json=payload)
        assert res.status_code == 422

    def test_negative_total_kcal_rejected(self):
        payload = {**_CREATE_PAYLOAD, "total_kcal": -1.0}
        res = client.post("/meals", json=payload)
        assert res.status_code == 422


class TestGetMeals:
    def test_returns_200(self):
        with _patch_find():
            res = client.get("/meals", params={"user_id": "user_001", "date": "2024-01-15"})
        assert res.status_code == 200

    def test_response_has_date_field(self):
        with _patch_find():
            data = client.get("/meals", params={"user_id": "user_001", "date": "2024-01-15"}).json()
        assert data["date"] == "2024-01-15"

    def test_response_has_total_kcal(self):
        with _patch_find():
            data = client.get("/meals", params={"user_id": "user_001", "date": "2024-01-15"}).json()
        assert "total_kcal" in data

    def test_response_has_meals_list(self):
        with _patch_find():
            data = client.get("/meals", params={"user_id": "user_001", "date": "2024-01-15"}).json()
        assert isinstance(data["meals"], list)

    def test_empty_db_returns_zero_kcal(self):
        with _patch_find(return_value=[]):
            data = client.get("/meals", params={"user_id": "user_001", "date": "2024-01-15"}).json()
        assert data["total_kcal"] == 0.0
        assert data["meals"] == []

    def test_missing_user_id_rejected(self):
        res = client.get("/meals", params={"date": "2024-01-15"})
        assert res.status_code == 422

    def test_invalid_date_format_rejected(self):
        res = client.get("/meals", params={"user_id": "user_001", "date": "20240115"})
        assert res.status_code == 422

    def test_meal_summary_fields(self):
        with _patch_find():
            data = client.get("/meals", params={"user_id": "user_001", "date": "2024-01-15"}).json()
        meal = data["meals"][0]
        for field in ("meal_id", "time", "items", "kcal"):
            assert field in meal
