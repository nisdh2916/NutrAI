"""POST /recommend 엔드포인트 테스트. ChromaDB와 Ollama는 mock."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import pytest
from fastapi.testclient import TestClient

from server.main import app

client = TestClient(app, raise_server_exceptions=True)

_GOOD_LLM_RESPONSE = json.dumps({
    "items": [
        {"name": "닭가슴살 샐러드", "kcal": 300, "carb": 15, "protein": 35, "fat": 8, "reason": "고단백", "tags": []},
        {"name": "현미밥", "kcal": 200, "carb": 42, "protein": 4, "fat": 1, "reason": "복합탄수화물", "tags": []},
        {"name": "두부조림", "kcal": 180, "carb": 10, "protein": 15, "fat": 7, "reason": "식물성 단백질", "tags": []},
    ],
    "coaching": "균형 잡힌 식사로 하루를 마무리하세요.",
})

_ALLERGEN_LLM_RESPONSE = json.dumps({
    "items": [
        {"name": "우유 라떼", "kcal": 200, "carb": 20, "protein": 8, "fat": 6, "reason": "테스트", "tags": []},
        {"name": "현미밥", "kcal": 200, "carb": 42, "protein": 4, "fat": 1, "reason": "테스트", "tags": []},
    ],
    "coaching": "테스트 코칭",
})


def _mock_retrieve(docs=None):
    """_retrieve_docs를 지정 문서 목록 반환 AsyncMock으로 교체."""
    if docs is None:
        docs = ["닭가슴살 | 칼로리 165kcal | 단백질 31g"]
    return patch("server.api.routes_recommend._retrieve_docs", new=AsyncMock(return_value=docs))


def _mock_ollama(raw=_GOOD_LLM_RESPONSE):
    return patch("server.api.routes_recommend._call_ollama_json", return_value=raw)


class TestRecommendBasic:
    def test_returns_200_with_items(self):
        with _mock_retrieve(), _mock_ollama():
            res = client.post("/recommend", json={})
        assert res.status_code == 200
        data = res.json()
        assert "items" in data
        assert "coaching" in data

    def test_items_list_length(self):
        with _mock_retrieve(), _mock_ollama():
            res = client.post("/recommend", json={"count": 3})
        items = res.json()["items"]
        assert len(items) <= 3

    def test_item_has_required_fields(self):
        with _mock_retrieve(), _mock_ollama():
            res = client.post("/recommend", json={})
        item = res.json()["items"][0]
        for field in ("name", "kcal", "carb", "protein", "fat", "reason", "allergen_warning"):
            assert field in item

    def test_coaching_includes_calorie_status(self):
        """코칭 메시지에 칼로리 정보가 포함되어야 함."""
        with _mock_retrieve(), _mock_ollama():
            res = client.post("/recommend", json={
                "user_profile": {"target_kcal": 2000, "weight": 70, "age": 30},
                "meal_history": [{"meal_type": "lunch", "total_kcal": 600, "foods": []}],
            })
        coaching = res.json()["coaching"]
        assert "kcal" in coaching or "칼로리" in coaching


class TestRecommendAllergyFiltering:
    def test_allergen_item_excluded_from_results(self):
        """알레르기 항목은 최종 결과에서 제외되어야 함."""
        with _mock_retrieve(), _mock_ollama(_ALLERGEN_LLM_RESPONSE):
            res = client.post("/recommend", json={
                "user_profile": {"allergy": "유제품"},
            })
        names = [item["name"] for item in res.json()["items"]]
        assert "우유 라떼" not in names

    def test_safe_item_remains(self):
        with _mock_retrieve(), _mock_ollama(_ALLERGEN_LLM_RESPONSE):
            res = client.post("/recommend", json={
                "user_profile": {"allergy": "유제품"},
            })
        names = [item["name"] for item in res.json()["items"]]
        assert "현미밥" in names

    def test_no_allergy_returns_all_items(self):
        with _mock_retrieve(), _mock_ollama(_GOOD_LLM_RESPONSE):
            res = client.post("/recommend", json={"user_profile": {"allergy": None}})
        assert len(res.json()["items"]) == 3


class TestRecommendLLMFailure:
    def test_ollama_failure_returns_200_with_fallback(self):
        """LLM 호출 실패 시 200 + 빈 items + 안내 메시지 반환."""
        with _mock_retrieve(), patch(
            "server.api.routes_recommend._call_ollama_json",
            side_effect=ValueError("Ollama timeout"),
        ):
            res = client.post("/recommend", json={})
        assert res.status_code == 200
        data = res.json()
        assert data["items"] == []
        assert len(data["coaching"]) > 0

    def test_malformed_json_returns_fallback(self):
        with _mock_retrieve(), _mock_ollama("not json at all"):
            res = client.post("/recommend", json={})
        assert res.status_code == 200
        assert res.json()["items"] == []


class TestBuildWhereFilter:
    """_build_where_filter() 단위 테스트 (라우터 내부 함수)."""

    def setup_method(self):
        from server.api.routes_recommend import _build_where_filter
        self.f = _build_where_filter

    def test_supplement_filter(self):
        f = self.f("건강기능식품", "meal")
        assert f == {"is_supplement": {"$eq": True}}

    def test_diet_filter_with_mealtime(self):
        f = self.f("다이어트", "lunch")
        assert f is not None
        assert {"is_diet": {"$eq": True}} in f.get("$and", [])
        assert {"is_lunch": {"$eq": True}} in f.get("$and", [])

    def test_diet_filter_no_mealtime(self):
        f = self.f("다이어트", "meal")
        assert f == {"is_diet": {"$eq": True}}

    def test_diabetes_condition(self):
        f = self.f("질환맞춤", "lunch", condition="당뇨")
        assert f == {"is_diabetes": {"$eq": True}}

    def test_hypertension_condition(self):
        f = self.f("질환맞춤", "dinner", condition="고혈압")
        assert f == {"is_hypertension": {"$eq": True}}

    def test_unknown_condition_uses_guideline(self):
        f = self.f("질환맞춤", "lunch", condition="통풍")
        assert f == {"category": {"$eq": "가이드라인"}}

    def test_general_category_mealtime_filter(self):
        f = self.f("전체", "breakfast")
        assert f == {"is_morning": {"$eq": True}}

    def test_general_no_mealtime_returns_none(self):
        f = self.f("전체", "meal")
        assert f is None


class TestExtractJson:
    """_extract_json() 단위 테스트."""

    def setup_method(self):
        from server.api.routes_recommend import _extract_json, _try_extract_json
        self.extract = _extract_json
        self.try_extract = _try_extract_json

    def test_plain_json(self):
        data = self.extract('{"items": [], "coaching": "test"}')
        assert data["coaching"] == "test"

    def test_markdown_fenced_json(self):
        text = '```json\n{"items": [], "coaching": "ok"}\n```'
        data = self.extract(text)
        assert data["coaching"] == "ok"

    def test_no_json_raises(self):
        with pytest.raises((ValueError, Exception)):
            self.extract("no json here")

    def test_partial_recovery_via_try_extract(self):
        """LLM 응답이 잘려서 outer JSON 파싱 실패 시, 개별 item 객체 복구."""
        # 바깥 ] } 가 없어 전체 파싱 실패 → 내부 객체는 복구 가능
        truncated = '{"items": [{"name": "비빔밥", "kcal": 550}'
        data = self.try_extract(truncated)
        assert "items" in data
        assert data["items"][0]["name"] == "비빔밥"
