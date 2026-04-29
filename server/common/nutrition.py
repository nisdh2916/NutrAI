"""
영양 목표값 계산 유틸 (단일 출처).

사용자 프로필이 명시적 `target_kcal`을 갖지 않을 때
나이·성별·키·몸무게·활동량을 기반으로 권장 칼로리와
영양소 목표를 산출한다. Mifflin-St Jeor 공식을 기반으로 한다.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

# 활동 계수 (Harris-Benedict 변형)
_ACTIVITY_FACTOR: dict[str, float] = {
    "낮음":   1.375,
    "보통":   1.55,
    "높음":   1.725,
    "low":    1.375,
    "moderate": 1.55,
    "high":   1.725,
}

# 매크로 비율 (탄수화물:단백질:지방 = 50:25:25 — WHO 권장)
CARB_RATIO    = 0.50
PROTEIN_RATIO = 0.25
FAT_RATIO     = 0.25

# 매크로 1g당 kcal
KCAL_PER_G = {"carb": 4.0, "protein": 4.0, "fat": 9.0}

# 프로필 정보가 거의 없을 때의 안전 기본값 (성인 평균)
DEFAULT_TARGET_KCAL = 2000.0


@dataclass(frozen=True)
class NutritionGoal:
    """일일 영양 목표."""
    target_kcal: float
    carb_g: float
    protein_g: float
    fat_g: float

    @classmethod
    def from_kcal(cls, kcal: float) -> "NutritionGoal":
        return cls(
            target_kcal=round(kcal, 1),
            carb_g=round(kcal * CARB_RATIO / KCAL_PER_G["carb"], 1),
            protein_g=round(kcal * PROTEIN_RATIO / KCAL_PER_G["protein"], 1),
            fat_g=round(kcal * FAT_RATIO / KCAL_PER_G["fat"], 1),
        )


def _as_float(v: Any) -> float | None:
    if v is None:
        return None
    try:
        f = float(v)
        return f if f > 0 else None
    except (TypeError, ValueError):
        return None


def calculate_bmr(*, gender: str | None, age: int | None,
                  height_cm: float | None, weight_kg: float | None) -> float | None:
    """Mifflin-St Jeor 공식으로 기초대사량 계산."""
    if age is None or not height_cm or not weight_kg or age <= 0:
        return None
    g = (gender or "").strip().lower()
    if g in ("남", "m", "male"):
        return 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
    if g in ("여", "f", "female"):
        return 10 * weight_kg + 6.25 * height_cm - 5 * age - 161
    # 성별 미상 → 평균
    return 10 * weight_kg + 6.25 * height_cm - 5 * age - 78


def calculate_target_kcal(profile: dict[str, Any]) -> float:
    """
    프로필에서 권장 일일 칼로리를 계산한다.
    1) profile["target_kcal"]가 명시되어 있으면 그대로 사용
    2) 그렇지 않으면 BMR × 활동계수로 계산
    3) 둘 다 불가능하면 DEFAULT_TARGET_KCAL 반환
    """
    explicit = _as_float(profile.get("target_kcal"))
    if explicit:
        return explicit

    bmr = calculate_bmr(
        gender=profile.get("gender"),
        age=profile.get("age") if isinstance(profile.get("age"), int) else None,
        height_cm=_as_float(profile.get("height") or profile.get("height_cm")),
        weight_kg=_as_float(profile.get("weight") or profile.get("weight_kg")),
    )
    if bmr is None:
        return DEFAULT_TARGET_KCAL

    activity = (profile.get("activity_level") or "보통").strip()
    factor = _ACTIVITY_FACTOR.get(activity, 1.55)

    # 다이어트 목표면 -15%, 증량 목표면 +10%
    goal = (profile.get("goal") or "").strip()
    adjustment = 1.0
    if any(t in goal for t in ("다이어트", "감량", "diet", "loss")):
        adjustment = 0.85
    elif any(t in goal for t in ("증량", "벌크", "gain")):
        adjustment = 1.10

    return round(bmr * factor * adjustment, 1)


def calculate_nutrition_goal(profile: dict[str, Any]) -> NutritionGoal:
    """프로필 기반 일일 영양 목표 (칼로리 + 매크로)."""
    return NutritionGoal.from_kcal(calculate_target_kcal(profile))
