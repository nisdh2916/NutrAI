"""server/common/nutrition.py 단위 테스트."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from server.common.nutrition import (
    DEFAULT_TARGET_KCAL,
    NutritionGoal,
    calculate_bmr,
    calculate_nutrition_goal,
    calculate_target_kcal,
)


class TestCalculateBmr:
    def test_male_formula(self):
        # 남성: 10W + 6.25H - 5A + 5
        result = calculate_bmr(gender="남", age=30, height_cm=175.0, weight_kg=70.0)
        expected = 10 * 70 + 6.25 * 175 - 5 * 30 + 5
        assert result == expected

    def test_female_formula(self):
        # 여성: 10W + 6.25H - 5A - 161
        result = calculate_bmr(gender="여", age=25, height_cm=163.0, weight_kg=55.0)
        expected = 10 * 55 + 6.25 * 163 - 5 * 25 - 161
        assert result == expected

    def test_english_gender_m(self):
        r1 = calculate_bmr(gender="남", age=30, height_cm=175.0, weight_kg=70.0)
        r2 = calculate_bmr(gender="m", age=30, height_cm=175.0, weight_kg=70.0)
        assert r1 == r2

    def test_english_gender_f(self):
        r1 = calculate_bmr(gender="여", age=25, height_cm=163.0, weight_kg=55.0)
        r2 = calculate_bmr(gender="f", age=25, height_cm=163.0, weight_kg=55.0)
        assert r1 == r2

    def test_unknown_gender_returns_average(self):
        # 성별 미상: 10W + 6.25H - 5A - 78 (남·여 평균)
        result = calculate_bmr(gender=None, age=30, height_cm=170.0, weight_kg=65.0)
        expected = 10 * 65 + 6.25 * 170 - 5 * 30 - 78
        assert result == expected

    def test_missing_age_returns_none(self):
        assert calculate_bmr(gender="남", age=None, height_cm=175.0, weight_kg=70.0) is None

    def test_zero_age_returns_none(self):
        assert calculate_bmr(gender="남", age=0, height_cm=175.0, weight_kg=70.0) is None

    def test_missing_weight_returns_none(self):
        assert calculate_bmr(gender="남", age=30, height_cm=175.0, weight_kg=None) is None

    def test_missing_height_returns_none(self):
        assert calculate_bmr(gender="남", age=30, height_cm=None, weight_kg=70.0) is None


class TestCalculateTargetKcal:
    def test_explicit_target_kcal_used_as_is(self):
        result = calculate_target_kcal({"target_kcal": 1800})
        assert result == 1800.0

    def test_empty_profile_returns_default(self):
        result = calculate_target_kcal({})
        assert result == DEFAULT_TARGET_KCAL

    def test_activity_factor_applied(self):
        profile = {"gender": "남", "age": 30, "height_cm": 175.0, "weight_kg": 70.0, "activity_level": "높음"}
        bmr = calculate_bmr(gender="남", age=30, height_cm=175.0, weight_kg=70.0)
        expected = round(bmr * 1.725, 1)
        assert calculate_target_kcal(profile) == expected

    def test_default_activity_moderate(self):
        profile = {"gender": "남", "age": 30, "height_cm": 175.0, "weight_kg": 70.0}
        bmr = calculate_bmr(gender="남", age=30, height_cm=175.0, weight_kg=70.0)
        expected = round(bmr * 1.55, 1)
        assert calculate_target_kcal(profile) == expected

    def test_diet_goal_reduces_kcal(self):
        base_profile = {"gender": "남", "age": 30, "height_cm": 175.0, "weight_kg": 70.0}
        diet_profile = {**base_profile, "goal": "다이어트"}
        bmr = calculate_bmr(gender="남", age=30, height_cm=175.0, weight_kg=70.0)
        base = calculate_target_kcal(base_profile)
        diet = calculate_target_kcal(diet_profile)
        # 다이어트는 base보다 작아야 함 (구현: bmr * factor * 0.85)
        assert diet < base
        assert diet == round(bmr * 1.55 * 0.85, 1)

    def test_gain_goal_increases_kcal(self):
        base_profile = {"gender": "남", "age": 30, "height_cm": 175.0, "weight_kg": 70.0}
        gain_profile = {**base_profile, "goal": "벌크업"}
        bmr = calculate_bmr(gender="남", age=30, height_cm=175.0, weight_kg=70.0)
        base = calculate_target_kcal(base_profile)
        gain = calculate_target_kcal(gain_profile)
        assert gain > base
        assert gain == round(bmr * 1.55 * 1.10, 1)

    def test_weight_key_alias(self):
        # "weight"와 "weight_kg" 둘 다 인식
        p1 = {"gender": "남", "age": 30, "height_cm": 175.0, "weight_kg": 70.0}
        p2 = {"gender": "남", "age": 30, "height_cm": 175.0, "weight": 70.0}
        assert calculate_target_kcal(p1) == calculate_target_kcal(p2)

    def test_height_key_alias(self):
        p1 = {"gender": "남", "age": 30, "height_cm": 175.0, "weight_kg": 70.0}
        p2 = {"gender": "남", "age": 30, "height": 175.0, "weight_kg": 70.0}
        assert calculate_target_kcal(p1) == calculate_target_kcal(p2)


class TestNutritionGoal:
    def test_macro_ratios_sum_to_kcal(self):
        goal = NutritionGoal.from_kcal(2000.0)
        # 탄 50%×4 + 단 25%×4 + 지 25%×9 ≈ 2000kcal (반올림 오차 허용)
        reconstructed = goal.carb_g * 4 + goal.protein_g * 4 + goal.fat_g * 9
        assert abs(reconstructed - 2000.0) < 10

    def test_from_kcal_values(self):
        goal = NutritionGoal.from_kcal(2000.0)
        assert goal.target_kcal == 2000.0
        assert goal.carb_g == round(2000 * 0.50 / 4, 1)
        assert goal.protein_g == round(2000 * 0.25 / 4, 1)
        assert goal.fat_g == round(2000 * 0.25 / 9, 1)

    def test_zero_kcal_produces_zeros(self):
        goal = NutritionGoal.from_kcal(0.0)
        assert goal.carb_g == 0.0
        assert goal.protein_g == 0.0
        assert goal.fat_g == 0.0


class TestCalculateNutritionGoal:
    def test_returns_nutrition_goal_instance(self):
        result = calculate_nutrition_goal({"target_kcal": 2000})
        assert isinstance(result, NutritionGoal)
        assert result.target_kcal == 2000.0

    def test_empty_profile_uses_default(self):
        result = calculate_nutrition_goal({})
        assert result.target_kcal == DEFAULT_TARGET_KCAL
