from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any


NO_LIMIT_REMAINING_KCAL = 0.0
KCAL_TOLERANCE = 50.0


@dataclass(frozen=True)
class MealStatus:
    consumed_today: float
    remaining_kcal: float
    detected_foods: list[str] = field(default_factory=list)
    total_carb_g: float = 0.0
    total_protein_g: float = 0.0
    total_fat_g: float = 0.0


@dataclass(frozen=True)
class RecommendationContext:
    intent: str
    meal_time: str
    goal: str
    constraints: list[str]
    meal_status: MealStatus
    queries: list[str]


def _as_float(value: Any, default: float = 0.0) -> float:
    try:
        if value is None:
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def _split_words(value: str | None) -> list[str]:
    if not value:
        return []
    return [part.strip() for part in re.split(r"[,/\s]+", value) if part.strip()]


def infer_meal_time(text: str, category: str = "") -> str:
    source = f"{text} {category}".lower()
    if any(token in source for token in ("breakfast", "아침")):
        return "breakfast"
    if any(token in source for token in ("lunch", "점심")):
        return "lunch"
    if any(token in source for token in ("dinner", "저녁")):
        return "dinner"
    if any(token in source for token in ("snack", "간식", "야식")):
        return "snack"
    return "meal"


def normalize_goal(profile: dict) -> str:
    raw = str(profile.get("goal") or "").strip().lower()
    if any(token in raw for token in ("diet", "loss", "감량", "다이어트", "체중")):
        return "weight_loss"
    if any(token in raw for token in ("gain", "증량", "벌크")):
        return "weight_gain"
    if any(token in raw for token in ("maintain", "유지")):
        return "maintenance"
    return raw or "general_health"


def extract_constraints(profile: dict, category: str = "") -> list[str]:
    constraints: list[str] = []
    condition = str(profile.get("condition") or "").strip()
    allergy = str(profile.get("allergy") or "").strip()
    activity = str(profile.get("activity_level") or "").strip()
    source = f"{profile.get('goal') or ''} {category} {condition} {allergy}".lower()

    if any(token in source for token in ("저염", "low_sodium", "나트륨")):
        constraints.append("low_sodium")
    if any(token in source for token in ("저당", "low_sugar", "당뇨", "혈당")):
        constraints.append("low_sugar")
    if any(token in source for token in ("고단백", "protein", "근력")):
        constraints.append("high_protein")
    if condition:
        constraints.append(f"condition:{condition}")
    if allergy and allergy not in ("없음", "none", "None"):
        constraints.extend(f"allergy:{item}" for item in _split_words(allergy))
    if activity:
        constraints.append(f"activity:{activity}")
    return list(dict.fromkeys(constraints))


def build_meal_status(
    profile: dict,
    meal_history: list[dict] | None,
    detected_foods: list[str] | None = None,
) -> MealStatus:
    consumed_today = 0.0
    total_carb = total_protein = total_fat = 0.0
    foods = list(detected_foods or [])

    for meal in meal_history or []:
        consumed_today += _as_float(meal.get("total_kcal"))
        for food in meal.get("foods", []) or []:
            name = food.get("name")
            if name:
                foods.append(str(name))
            total_carb += _as_float(food.get("carb_g"))
            total_protein += _as_float(food.get("protein_g"))
            total_fat += _as_float(food.get("fat_g"))

    target = _as_float(profile.get("target_kcal"), default=NO_LIMIT_REMAINING_KCAL)
    remaining = max(0.0, target - consumed_today) if target > 0 else NO_LIMIT_REMAINING_KCAL

    return MealStatus(
        consumed_today=round(consumed_today, 2),
        remaining_kcal=round(remaining, 2),
        detected_foods=list(dict.fromkeys(foods)),
        total_carb_g=round(total_carb, 2),
        total_protein_g=round(total_protein, 2),
        total_fat_g=round(total_fat, 2),
    )


def build_recommendation_context(
    *,
    profile: dict,
    meal_history: list[dict] | None,
    category: str,
    user_query: str = "",
    detected_foods: list[str] | None = None,
) -> RecommendationContext:
    goal = normalize_goal(profile)
    constraints = extract_constraints(profile, category)
    meal_time = infer_meal_time(user_query, category)
    meal_status = build_meal_status(profile, meal_history, detected_foods)
    queries = rewrite_queries(goal, constraints, meal_status, meal_time, category, user_query)
    return RecommendationContext(
        intent="menu_recommendation",
        meal_time=meal_time,
        goal=goal,
        constraints=constraints,
        meal_status=meal_status,
        queries=queries,
    )


def rewrite_queries(
    goal: str,
    constraints: list[str],
    meal_status: MealStatus,
    meal_time: str,
    category: str,
    user_query: str,
) -> list[str]:
    queries: list[str] = []
    if user_query.strip():
        queries.append(user_query.strip())
    if category and category not in ("전체", "all"):
        queries.append(f"{category} 메뉴 추천")
    if goal == "weight_loss":
        queries.append(f"체중 감량 {meal_time} 메뉴 추천")
    elif goal == "weight_gain":
        queries.append(f"증량 고단백 {meal_time} 메뉴 추천")
    else:
        queries.append(f"건강한 {meal_time} 메뉴 추천")

    if meal_status.remaining_kcal > 0:
        queries.append(f"남은 칼로리 {meal_status.remaining_kcal:.0f}kcal 이하 {meal_time} 식사")
    if meal_status.detected_foods:
        queries.append(f"{', '.join(meal_status.detected_foods[:3])} 섭취 후 {meal_time} 조절 식단")

    if "low_sodium" in constraints:
        queries.append(f"저염식 {meal_time} 메뉴 예시")
    if "low_sugar" in constraints:
        queries.append(f"저당식 {meal_time} 메뉴 예시")
    if "high_protein" in constraints:
        queries.append(f"고단백 {meal_time} 메뉴 예시")

    for constraint in constraints:
        if constraint.startswith("condition:"):
            queries.append(f"{constraint.split(':', 1)[1]} 맞춤 식단")

    return list(dict.fromkeys(q for q in queries if q.strip()))[:6]


def format_context_block(ctx: RecommendationContext, docs: list[str]) -> str:
    constraints = ", ".join(ctx.constraints) if ctx.constraints else "none"
    foods = ", ".join(ctx.meal_status.detected_foods) if ctx.meal_status.detected_foods else "none"
    knowledge = "\n".join(f"- {doc.replace('|', ', ')}" for doc in docs[:5]) or "- 검색된 식단 문서가 없습니다."
    return "\n".join(
        [
            "[PIPELINE_CONTEXT]",
            f"- intent: {ctx.intent}",
            f"- meal_time: {ctx.meal_time}",
            f"- goal: {ctx.goal}",
            f"- constraints: {constraints}",
            "",
            "[MEAL_STATUS]",
            f"- consumed_today: {ctx.meal_status.consumed_today:.0f}kcal",
            f"- remaining_kcal: {ctx.meal_status.remaining_kcal:.0f}kcal",
            f"- macros: carb {ctx.meal_status.total_carb_g:.0f}g, protein {ctx.meal_status.total_protein_g:.0f}g, fat {ctx.meal_status.total_fat_g:.0f}g",
            f"- detected_or_logged_foods: {foods}",
            "",
            "[RETRIEVED_KNOWLEDGE]",
            knowledge,
        ]
    )


def item_has_allergen(name: str, allergy_str: str | None) -> tuple[bool, list[str]]:
    allergens = [item for item in _split_words(allergy_str) if item.lower() not in ("none", "없음")]
    matched = [allergen for allergen in allergens if allergen and allergen in name]
    return bool(matched), matched


def validate_and_rank_items(
    raw_items: list[dict],
    *,
    remaining_kcal: float,
    allergy_str: str | None,
    count: int,
) -> list[dict]:
    valid: list[dict] = []
    fallback: list[dict] = []

    for raw in raw_items:
        name = str(raw.get("name") or raw.get("menu") or "").strip()
        if not name:
            continue
        kcal = _as_float(raw.get("kcal", raw.get("estimated_kcal")))
        allergen_warning, allergen_names = item_has_allergen(name, allergy_str)
        item = {
            "name": name,
            "kcal": kcal,
            "carb": _as_float(raw.get("carb")),
            "protein": _as_float(raw.get("protein")),
            "fat": _as_float(raw.get("fat")),
            "reason": str(raw.get("reason") or ""),
            "tags": list(raw.get("tags") or []),
            "allergen_warning": allergen_warning,
            "allergen_names": allergen_names,
        }
        fallback.append(item)
        if allergen_warning:
            continue
        if remaining_kcal > 0 and kcal > remaining_kcal + KCAL_TOLERANCE:
            continue
        valid.append(item)

    candidates = valid or fallback
    return sorted(candidates, key=lambda item: _score_item(item, remaining_kcal), reverse=True)[:count]


def _score_item(item: dict, remaining_kcal: float) -> float:
    score = 0.0
    kcal = _as_float(item.get("kcal"))
    protein = _as_float(item.get("protein"))
    if remaining_kcal > 0:
        score += max(0.0, 100.0 - abs(remaining_kcal - kcal))
    if protein > 0:
        score += min(protein, 40.0)
    if not item.get("allergen_warning"):
        score += 25.0
    if item.get("reason"):
        score += 5.0
    return score


def build_coaching_prefix(ctx: RecommendationContext) -> str:
    if ctx.meal_status.remaining_kcal <= 0:
        return f"오늘 누적 섭취량은 약 {ctx.meal_status.consumed_today:.0f}kcal입니다."
    return (
        f"오늘 누적 섭취량은 약 {ctx.meal_status.consumed_today:.0f}kcal이고, "
        f"남은 칼로리는 약 {ctx.meal_status.remaining_kcal:.0f}kcal입니다."
    )
