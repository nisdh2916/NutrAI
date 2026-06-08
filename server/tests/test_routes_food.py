"""food 관련 엔드포인트 + 유틸리티 함수 테스트."""
from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import pytest
from fastapi.testclient import TestClient
from server.main import app
from server.api.routes_food import _parse_float, _doc_to_result
from server.api.schemas import FoodAddResponse

client = TestClient(app, raise_server_exceptions=True)

_ADD_PAYLOAD = {
    "name": "현미밥",
    "category": "밥류",
    "kcal": 340.0,
    "carb_g": 73.0,
    "protein_g": 7.0,
    "fat_g": 2.0,
}

_BULK_PAYLOAD = {
    "items": [
        {"name": "닭가슴살", "kcal": 165.0, "carb_g": 0.0, "protein_g": 31.0, "fat_g": 3.6},
        {"name": "고구마", "kcal": 130.0, "carb_g": 31.0, "protein_g": 2.0, "fat_g": 0.0},
    ]
}


class TestParseFloat:
    def test_parses_kcal(self):
        assert _parse_float("현미밥 | 칼로리 340kcal | 탄수화물 73g", "칼로리") == pytest.approx(340.0)

    def test_parses_carb(self):
        assert _parse_float("칼로리 200kcal 탄수화물 30.5g", "탄수화물") == pytest.approx(30.5)

    def test_returns_zero_when_not_found(self):
        assert _parse_float("칼로리 200kcal", "나트륨") == 0.0

    def test_handles_decimal(self):
        assert _parse_float("단백질 15.75g", "단백질") == pytest.approx(15.75)


class TestDocToResult:
    _DOC_PIPE = "현미밥 | 분류: 밥류 | 칼로리 340kcal | 탄수화물 73g | 단백질 7g | 지방 2g | 나트륨 5mg | 당류 0g | 포화지방산 0.5g | 콜레스테롤 0mg | (기준: 1공기)"
    _DOC_COMMA = "닭가슴살 , 분류: 육류 , 칼로리 165kcal , 단백질 31g , 지방 3.6g , (기준: 100g)"

    def test_pipe_separator_name(self):
        assert _doc_to_result(self._DOC_PIPE).name == "현미밥"

    def test_comma_separator_name(self):
        assert _doc_to_result(self._DOC_COMMA).name == "닭가슴살"

    def test_extracts_category(self):
        assert _doc_to_result(self._DOC_PIPE).category == "밥류"

    def test_extracts_kcal(self):
        assert _doc_to_result(self._DOC_PIPE).kcal == pytest.approx(340.0)

    def test_extracts_protein(self):
        assert _doc_to_result(self._DOC_PIPE).protein_g == pytest.approx(7.0)

    def test_extracts_serving(self):
        assert _doc_to_result(self._DOC_PIPE).serving == "1공기"


class TestFoodAdd:
    def _mock_add_foods(self, names):
        return FoodAddResponse(added=len(names), failed=0, names=names)

    def test_post_food_add_200(self):
        with patch("server.api.routes_food.add_foods", return_value=self._mock_add_foods(["현미밥"])):
            res = client.post("/food/add", json=_ADD_PAYLOAD)
        assert res.status_code == 200

    def test_post_food_add_response_fields(self):
        with patch("server.api.routes_food.add_foods", return_value=self._mock_add_foods(["현미밥"])):
            data = client.post("/food/add", json=_ADD_PAYLOAD).json()
        assert data["added"] == 1
        assert data["failed"] == 0
        assert "현미밥" in data["names"]

    def test_post_food_add_import_error_returns_503(self):
        with patch("server.api.routes_food.add_foods", side_effect=ImportError("no module")):
            res = client.post("/food/add", json=_ADD_PAYLOAD)
        assert res.status_code == 503

    def test_post_food_bulk_200(self):
        names = [i["name"] for i in _BULK_PAYLOAD["items"]]
        with patch("server.api.routes_food.add_foods", return_value=self._mock_add_foods(names)):
            res = client.post("/food/bulk", json=_BULK_PAYLOAD)
        assert res.status_code == 200

    def test_post_food_bulk_added_count(self):
        names = [i["name"] for i in _BULK_PAYLOAD["items"]]
        with patch("server.api.routes_food.add_foods", return_value=self._mock_add_foods(names)):
            data = client.post("/food/bulk", json=_BULK_PAYLOAD).json()
        assert data["added"] == 2


class TestFoodSearch:
    def test_returns_503_when_no_rag(self):
        with patch.dict("sys.modules", {"ai.rag_engine.rag_pipeline": None}):
            res = client.get("/food/search", params={"q": "밥"})
        assert res.status_code == 503

    def test_missing_query_param_rejected(self):
        res = client.get("/food/search")
        assert res.status_code == 422

    def test_empty_query_rejected(self):
        res = client.get("/food/search", params={"q": ""})
        assert res.status_code == 422

    def test_k_exceeds_max_rejected(self):
        res = client.get("/food/search", params={"q": "밥", "k": 100})
        assert res.status_code == 422
