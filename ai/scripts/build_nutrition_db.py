# -*- coding: utf-8 -*-
"""카테고리·영양소 기반 boolean 메타데이터 태그 계산."""
from __future__ import annotations

_MORNING_CATS = {"죽 및 스프류", "과일류", "음료 및 차류", "빵 및 과자류",
                 "유제품류 및 빙과류", "밥류"}
_LUNCH_CATS   = {"밥류", "면 및 만두류", "국 및 탕류", "찌개 및 전골류",
                 "구이류", "볶음류", "찜류", "전·적 및 부침류", "조림류",
                 "튀김류", "나물·숙채류", "생채·무침류", "수·조·어·육류"}
_DINNER_CATS  = {"밥류", "국 및 탕류", "찌개 및 전골류", "구이류",
                 "볶음류", "찜류", "수·조·어·육류", "면 및 만두류"}
_SNACK_CATS   = {"빵 및 과자류", "과일류", "음료 및 차류",
                 "두류, 견과 및 종실류"}

_HIGH_SODIUM_CATS = {"젓갈류", "김치류", "장류, 양념류", "장아찌·절임류"}
_HIGH_SUGAR_CATS  = {"음료 및 차류", "빵 및 과자류", "유제품류 및 빙과류",
                     "과일류", "장류, 양념류"}
_NON_DIET_CATS    = {"빵 및 과자류", "유제품류 및 빙과류", "튀김류", "장류, 양념류"}


def _fval(row: dict, col: str, default: float = 0.0) -> float:
    try:
        v = row.get(col)
        if v is None:
            return default
        # pandas NaN guard (works without pandas import)
        f = float(v)
        return default if f != f else f  # NaN check: NaN != NaN
    except (TypeError, ValueError):
        return default


def tag_row(row: dict, category: str, source: str = "food") -> dict:
    """카테고리·영양소 기반 boolean 메타데이터 태그 계산."""
    kcal    = _fval(row, "에너지(kcal)")
    protein = _fval(row, "단백질(g)")
    fat     = _fval(row, "지방(g)")
    sodium  = _fval(row, "나트륨(mg)")
    sugar   = _fval(row, "당류(g)")
    carb    = _fval(row, "탄수화물(g)")

    is_morning = category in _MORNING_CATS
    is_lunch   = category in _LUNCH_CATS
    is_dinner  = category in _DINNER_CATS
    is_snack   = category in _SNACK_CATS

    is_diet = (
        (0 < kcal <= 300 and category not in _NON_DIET_CATS)
        or (protein >= 15 and fat <= 8 and 0 < kcal <= 350)
    )

    is_diabetes = (
        sugar <= 5 and carb <= 30 and kcal > 0
        and category not in _HIGH_SUGAR_CATS
    )

    is_hypertension = (
        0 < sodium <= 300
        and category not in _HIGH_SODIUM_CATS
    )

    is_supplement = source == "supplement"

    return {
        "is_morning":      is_morning,
        "is_lunch":        is_lunch,
        "is_dinner":       is_dinner,
        "is_snack":        is_snack,
        "is_diet":         is_diet,
        "is_diabetes":     is_diabetes,
        "is_hypertension": is_hypertension,
        "is_supplement":   is_supplement,
    }
