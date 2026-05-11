"""nutrition_service.calculate_nutrition() 단위 테스트. ChromaDB는 mock."""
from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from server.api.schemas import NutritionItemRequest, NutritionRequest
from server.services.nutrition_service import (
    _GENERIC,
    _parse_nutrition,
    calculate_nutrition,
)

# 테스트용 ChromaDB 문서 픽스처
_CHICKEN_DOC = "닭가슴살 | 분류: 육류 | 칼로리 165kcal | 탄수화물 0g | 단백질 31g | 지방 3.6g (기준: 100g)"
_RICE_DOC    = "흰쌀밥 | 분류: 밥류 | 칼로리 130kcal | 탄수화물 28g | 단백질 2.7g | 지방 0.3g (기준: 100g)"


def _make_chroma_result(doc: str, distance: float = 0.3):
    return {"documents": [[doc]], "distances": [[distance]]}


class TestParseNutrition:
    def test_parses_pipe_format(self):
        result = _parse_nutrition(_CHICKEN_DOC)
        assert result is not None
        assert result["kcal"] == 165.0
        assert result["carb_g"] == 0.0
        assert result["protein_g"] == 31.0
        assert result["fat_g"] == 3.6

    def test_parses_colon_format(self):
        doc = "닭가슴살 100g: 칼로리 165kcal, 탄수화물 0g, 단백질 31g, 지방 3.6g"
        result = _parse_nutrition(doc)
        assert result is not None
        assert result["kcal"] == 165.0

    def test_missing_field_returns_none(self):
        doc = "닭가슴살 | 칼로리 165kcal | 탄수화물 0g | 단백질 31g"  # 지방 없음
        result = _parse_nutrition(doc)
        assert result is None

    def test_empty_doc_returns_none(self):
        assert _parse_nutrition("") is None

    def test_nonnumeric_returns_none(self):
        assert _parse_nutrition("칼로리 N/Akcal 탄수화물 0g 단백질 0g 지방 0g") is None


class TestCalculateNutrition:
    def _req(self, *items):
        return NutritionRequest(items=[NutritionItemRequest(food_name=n, serving=s) for n, s in items])

    def test_chromadb_hit_uses_real_values(self):
        with patch(
            "server.services.nutrition_service._lookup_chromadb",
            return_value={"kcal": 165.0, "carb_g": 0.0, "protein_g": 31.0, "fat_g": 3.6},
        ):
            resp = calculate_nutrition(self._req(("닭가슴살", 1.0)))
        assert resp.total_kcal == 165.0
        assert resp.protein_g == 31.0
        assert resp.fat_g == 3.6

    def test_chromadb_miss_uses_generic_fallback(self):
        with patch("server.services.nutrition_service._lookup_chromadb", return_value=None):
            resp = calculate_nutrition(self._req(("알수없는음식", 1.0)))
        assert resp.total_kcal == _GENERIC["kcal"]

    def test_serving_multiplier_applied(self):
        with patch(
            "server.services.nutrition_service._lookup_chromadb",
            return_value={"kcal": 100.0, "carb_g": 20.0, "protein_g": 5.0, "fat_g": 2.0},
        ):
            resp = calculate_nutrition(self._req(("테스트음식", 2.5)))
        assert resp.total_kcal == 250.0
        assert resp.carb_g == 50.0

    def test_multiple_items_summed(self):
        side_effects = [
            {"kcal": 165.0, "carb_g": 0.0, "protein_g": 31.0, "fat_g": 3.6},
            {"kcal": 130.0, "carb_g": 28.0, "protein_g": 2.7, "fat_g": 0.3},
        ]
        with patch("server.services.nutrition_service._lookup_chromadb", side_effect=side_effects):
            resp = calculate_nutrition(self._req(("닭가슴살", 1.0), ("흰쌀밥", 1.0)))
        assert resp.total_kcal == round(165.0 + 130.0, 2)
        assert len(resp.breakdown) == 2

    def test_breakdown_contains_food_names(self):
        with patch("server.services.nutrition_service._lookup_chromadb", return_value=None):
            resp = calculate_nutrition(self._req(("비빔밥", 1.0), ("된장찌개", 1.0)))
        names = [b.food_name for b in resp.breakdown]
        assert "비빔밥" in names
        assert "된장찌개" in names

    def test_values_rounded_to_two_decimals(self):
        with patch(
            "server.services.nutrition_service._lookup_chromadb",
            return_value={"kcal": 100.0, "carb_g": 1.0, "protein_g": 1.0, "fat_g": 1.0},
        ):
            resp = calculate_nutrition(self._req(("음식", 1.333)))
        # serving 1.333 × 100 = 133.3 → rounded
        assert resp.total_kcal == round(100.0 * 1.333, 2)
