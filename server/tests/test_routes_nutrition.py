"""POST /nutrition/calculate 엔드포인트 테스트. ChromaDB는 mock."""
from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import pytest
from fastapi.testclient import TestClient
from server.main import app
from server.api.schemas import NutritionResponse, NutritionBreakdown

client = TestClient(app, raise_server_exceptions=True)


def _mock_nutrition(total_kcal=500.0, carb_g=60.0, protein_g=30.0, fat_g=10.0):
    return NutritionResponse(
        total_kcal=total_kcal,
        carb_g=carb_g,
        protein_g=protein_g,
        fat_g=fat_g,
        breakdown=[NutritionBreakdown(food_name="테스트", kcal=total_kcal)],
    )


class TestNutritionCalculate:
    def test_returns_200(self):
        with patch("server.api.routes_nutrition.calculate_nutrition", return_value=_mock_nutrition()):
            res = client.post("/nutrition/calculate", json={"items": [{"food_name": "밥", "serving": 1.0}]})
        assert res.status_code == 200

    def test_response_has_required_fields(self):
        with patch("server.api.routes_nutrition.calculate_nutrition", return_value=_mock_nutrition()):
            data = client.post("/nutrition/calculate", json={"items": [{"food_name": "밥", "serving": 1.0}]}).json()
        for field in ("total_kcal", "carb_g", "protein_g", "fat_g", "breakdown"):
            assert field in data

    def test_breakdown_is_list(self):
        with patch("server.api.routes_nutrition.calculate_nutrition", return_value=_mock_nutrition()):
            data = client.post("/nutrition/calculate", json={"items": [{"food_name": "밥", "serving": 1.0}]}).json()
        assert isinstance(data["breakdown"], list)

    def test_empty_items_returns_200(self):
        with patch("server.api.routes_nutrition.calculate_nutrition", return_value=_mock_nutrition(0)):
            res = client.post("/nutrition/calculate", json={"items": []})
        assert res.status_code == 200

    def test_invalid_serving_rejected(self):
        res = client.post("/nutrition/calculate", json={"items": [{"food_name": "밥", "serving": 0}]})
        assert res.status_code == 422

    def test_missing_items_field_rejected(self):
        res = client.post("/nutrition/calculate", json={})
        assert res.status_code == 422
