"""recommendation_pipeline.py 순수 함수 단위 테스트."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from server.services.recommendation_pipeline import (
    MealStatus,
    build_meal_status,
    extract_constraints,
    infer_meal_time,
    item_has_allergen,
    normalize_goal,
    rewrite_queries,
    validate_and_rank_items,
    _category_queries,
    _score_item,
)


# ── infer_meal_time ─────────────────────────────────
class TestInferMealTime:
    def test_korean_keywords(self):
        assert infer_meal_time("아침 메뉴 추천") == "breakfast"
        assert infer_meal_time("점심 뭐 먹지") == "lunch"
        assert infer_meal_time("저녁 추천해줘") == "dinner"
        assert infer_meal_time("간식거리") == "snack"
        assert infer_meal_time("야식 추천") == "snack"

    def test_english_keywords(self):
        assert infer_meal_time("breakfast ideas") == "breakfast"
        assert infer_meal_time("LUNCH menu") == "lunch"

    def test_fallback(self):
        assert infer_meal_time("뭐 먹을까") == "meal"
        assert infer_meal_time("") == "meal"

    def test_category_fallback(self):
        assert infer_meal_time("추천", category="아침") == "breakfast"


# ── normalize_goal ──────────────────────────────────
class TestNormalizeGoal:
    def test_weight_loss(self):
        assert normalize_goal({"goal": "다이어트"}) == "weight_loss"
        assert normalize_goal({"goal": "체중 감량"}) == "weight_loss"
        assert normalize_goal({"goal": "weight loss"}) == "weight_loss"

    def test_weight_gain(self):
        assert normalize_goal({"goal": "벌크업"}) == "weight_gain"
        assert normalize_goal({"goal": "근육 증량"}) == "weight_gain"

    def test_maintenance(self):
        assert normalize_goal({"goal": "체중 유지"}) == "maintenance"

    def test_default(self):
        assert normalize_goal({}) == "general_health"
        assert normalize_goal({"goal": ""}) == "general_health"


# ── extract_constraints ─────────────────────────────
class TestExtractConstraints:
    def test_low_sodium_from_condition(self):
        c = extract_constraints({"condition": "고혈압"})
        # '고혈압' 자체로 저염 키워드 매칭은 안되지만 condition 자체는 추가됨
        assert "condition:고혈압" in c

    def test_diabetes_low_sugar(self):
        c = extract_constraints({"condition": "당뇨"})
        assert "low_sugar" in c
        assert "condition:당뇨" in c

    def test_allergy_split(self):
        c = extract_constraints({"allergy": "유제품, 견과류"})
        assert "allergy:유제품" in c
        assert "allergy:견과류" in c

    def test_allergy_none_ignored(self):
        c = extract_constraints({"allergy": "없음"})
        assert not any(x.startswith("allergy:") for x in c)

    def test_dedup(self):
        c = extract_constraints({"goal": "고단백 다이어트", "condition": ""})
        assert c.count("high_protein") == 1


# ── build_meal_status ───────────────────────────────
class TestBuildMealStatus:
    def test_empty_history(self):
        s = build_meal_status({"target_kcal": 2000}, [])
        assert s.consumed_today == 0.0
        assert s.remaining_kcal == 2000.0
        assert s.detected_foods == []

    def test_remaining_clamped_to_zero(self):
        s = build_meal_status(
            {"target_kcal": 1000},
            [{"total_kcal": 1500, "foods": []}],
        )
        assert s.consumed_today == 1500.0
        assert s.remaining_kcal == 0.0  # max(0, target - consumed)

    def test_no_target_returns_zero_remaining(self):
        s = build_meal_status({}, [{"total_kcal": 500, "foods": []}])
        assert s.remaining_kcal == 0.0

    def test_macro_aggregation(self):
        s = build_meal_status(
            {"target_kcal": 2000},
            [{
                "total_kcal": 600,
                "foods": [
                    {"name": "비빔밥", "carb_g": 65, "protein_g": 18, "fat_g": 8},
                    {"name": "된장찌개", "carb_g": 12, "protein_g": 8, "fat_g": 4},
                ],
            }],
        )
        assert s.consumed_today == 600.0
        assert s.total_carb_g == 77.0
        assert s.total_protein_g == 26.0
        assert s.total_fat_g == 12.0
        assert "비빔밥" in s.detected_foods
        assert "된장찌개" in s.detected_foods

    def test_detected_foods_dedup(self):
        s = build_meal_status(
            {"target_kcal": 2000},
            [{"total_kcal": 100, "foods": [{"name": "라면"}]}],
            detected_foods=["라면", "라면", "김치"],
        )
        assert s.detected_foods.count("라면") == 1
        assert "김치" in s.detected_foods


# ── item_has_allergen ───────────────────────────────
class TestItemHasAllergen:
    def test_no_allergy(self):
        ok, names = item_has_allergen("치즈피자", "")
        assert ok is False
        assert names == []

    def test_dairy_match(self):
        ok, names = item_has_allergen("치즈피자", "유제품")
        assert ok is True
        assert "유제품" in names

    def test_no_match(self):
        ok, names = item_has_allergen("닭가슴살 샐러드", "유제품")
        assert ok is False

    def test_multiple_allergens(self):
        ok, names = item_has_allergen("치즈빵", "유제품, 밀")
        assert ok is True
        assert set(names) == {"유제품", "밀"}

    def test_none_keyword_ignored(self):
        ok, _ = item_has_allergen("우유", "없음")
        assert ok is False


# ── rewrite_queries ─────────────────────────────────
class TestRewriteQueries:
    def test_max_six_queries(self):
        from server.services.recommendation_pipeline import MealStatus
        ms = MealStatus(
            consumed_today=500, remaining_kcal=800,
            detected_foods=["비빔밥", "라면", "치킨"],
        )
        queries = rewrite_queries(
            goal="weight_loss",
            constraints=["low_sodium", "low_sugar", "high_protein", "condition:당뇨"],
            meal_status=ms,
            meal_time="lunch",
            category="한식",
            user_query="다이어트 점심",
        )
        assert len(queries) <= 6
        assert all(q.strip() for q in queries)

    def test_dedup(self):
        from server.services.recommendation_pipeline import MealStatus
        ms = MealStatus(consumed_today=0, remaining_kcal=0)
        queries = rewrite_queries(
            goal="general_health",
            constraints=[],
            meal_status=ms,
            meal_time="meal",
            category="",
            user_query="추천",
        )
        assert len(queries) == len(set(queries))


# ── validate_and_rank_items ─────────────────────────
class TestValidateAndRankItems:
    def test_filters_allergens(self):
        items = [
            {"name": "치즈피자", "kcal": 500},
            {"name": "닭가슴살 샐러드", "kcal": 300},
        ]
        result = validate_and_rank_items(items, remaining_kcal=800, allergy_str="유제품", count=5)
        names = [r["name"] for r in result]
        assert "치즈피자" not in names
        assert "닭가슴살 샐러드" in names

    def test_calorie_fallback_when_all_over(self):
        items = [
            {"name": "삼겹살", "kcal": 800},
            {"name": "갈비찜", "kcal": 700},
        ]
        # 남은 200kcal인데 둘 다 초과 → 모두 calorie_fallback으로 빠지지만
        # valid이 비어있으면 fallback이 사용됨
        result = validate_and_rank_items(items, remaining_kcal=200, allergy_str=None, count=5)
        assert len(result) == 2

    def test_count_limit(self):
        items = [{"name": f"음식{i}", "kcal": 300} for i in range(10)]
        result = validate_and_rank_items(items, remaining_kcal=2000, allergy_str=None, count=3)
        assert len(result) == 3

    def test_empty_name_skipped(self):
        items = [{"name": "", "kcal": 300}, {"name": "비빔밥", "kcal": 400}]
        result = validate_and_rank_items(items, remaining_kcal=2000, allergy_str=None, count=5)
        assert len(result) == 1
        assert result[0]["name"] == "비빔밥"


# ── _category_queries ───────────────────────────────
class TestCategoryQueries:
    def test_diet_category(self):
        q = _category_queries("다이어트", "weight_loss", [], "점심")
        assert any("저칼로리" in x or "체중" in x or "다이어트" in x for x in q)

    def test_preference_weight_loss(self):
        q = _category_queries("기호별", "weight_loss", [], "점심")
        assert len(q) > 0
        # "기호별" 키워드가 쿼리에 직접 들어가면 안 됨
        assert not any("기호별" in x for x in q)

    def test_preference_weight_gain(self):
        q = _category_queries("기호별", "weight_gain", [], "저녁")
        assert any("고단백" in x or "증량" in x for x in q)

    def test_disease_with_condition(self):
        q = _category_queries("질환맞춤", "general_health", ["condition:당뇨"], "점심")
        assert any("당뇨" in x for x in q)

    def test_disease_no_condition_fallback(self):
        q = _category_queries("질환맞춤", "general_health", [], "점심")
        assert len(q) > 0
        assert any("가이드라인" in x or "건강" in x for x in q)

    def test_supplement_category(self):
        q = _category_queries("건강기능식품", "general_health", [], "점심")
        assert any("건강기능식품" in x or "영양제" in x for x in q)

    def test_all_category_returns_empty(self):
        q = _category_queries("전체", "general_health", [], "점심")
        assert q == []


# ── rewrite_queries (새 카테고리 로직) ──────────────
class TestRewriteQueriesWithCategory:
    _ms = MealStatus(consumed_today=500, remaining_kcal=800)

    def test_diet_category_queries(self):
        qs = rewrite_queries("weight_loss", [], self._ms, "lunch", "다이어트", "")
        assert len(qs) <= 6
        assert any("다이어트" in q or "저칼로리" in q or "체중" in q for q in qs)

    def test_disease_uses_condition(self):
        constraints = ["condition:당뇨"]
        qs = rewrite_queries("general_health", constraints, self._ms, "lunch", "질환맞춤", "")
        assert any("당뇨" in q for q in qs)

    def test_preference_no_keyword_in_query(self):
        qs = rewrite_queries("weight_loss", [], self._ms, "dinner", "기호별", "")
        assert not any("기호별" in q for q in qs)

    def test_supplement_category(self):
        qs = rewrite_queries("general_health", [], self._ms, "meal", "건강기능식품", "")
        assert any("건강기능식품" in q or "영양제" in q for q in qs)


# ── _score_item ─────────────────────────────────────
class TestScoreItem:
    def test_closer_to_remaining_scores_higher(self):
        item_close = {"kcal": 500, "protein": 25, "reason": "good", "allergen_warning": False}
        item_far   = {"kcal": 100, "protein": 25, "reason": "good", "allergen_warning": False}
        assert _score_item(item_close, 500) > _score_item(item_far, 500)

    def test_higher_protein_scores_higher(self):
        low  = {"kcal": 400, "protein": 5,  "reason": "", "allergen_warning": False}
        high = {"kcal": 400, "protein": 35, "reason": "", "allergen_warning": False}
        assert _score_item(high, 400) > _score_item(low, 400)

    def test_allergen_penalty(self):
        safe    = {"kcal": 400, "protein": 20, "reason": "", "allergen_warning": False}
        unsafe  = {"kcal": 400, "protein": 20, "reason": "", "allergen_warning": True}
        assert _score_item(safe, 400) > _score_item(unsafe, 400)
