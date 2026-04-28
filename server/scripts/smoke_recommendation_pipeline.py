from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from server.services.recommendation_pipeline import (
    build_recommendation_context,
    item_has_allergen,
    validate_and_rank_items,
)


def main() -> None:
    profile = {
        "goal": "감량",
        "target_kcal": 1700,
        "allergy": "유제품",
        "condition": "",
        "activity_level": "보통",
    }
    meals = [
        {
            "meal_type": "lunch",
            "foods": [
                {
                    "name": "비빔밥",
                    "carb_g": 80,
                    "protein_g": 25,
                    "fat_g": 20,
                }
            ],
            "total_kcal": 1220,
        }
    ]

    ctx = build_recommendation_context(
        profile=profile,
        meal_history=meals,
        category="저녁",
        user_query="오늘 저녁 뭐 먹지?",
    )
    assert ctx.goal == "weight_loss"
    assert ctx.meal_time == "dinner"
    assert ctx.meal_status.consumed_today == 1220
    assert ctx.meal_status.remaining_kcal == 480
    assert any("저녁" in query for query in ctx.queries)

    assert item_has_allergen("치즈 샐러드", "유제품")[0]
    assert not item_has_allergen("닭가슴살 샐러드", "유제품")[0]

    items = validate_and_rank_items(
        [
            {"name": "치즈 샐러드", "kcal": 300, "reason": "유제품 포함"},
            {"name": "닭가슴살 샐러드", "kcal": 360, "protein": 30, "reason": "고단백"},
            {"name": "고칼로리 정식", "kcal": 900, "protein": 20, "reason": "초과"},
        ],
        remaining_kcal=ctx.meal_status.remaining_kcal,
        allergy_str=profile["allergy"],
        count=3,
    )
    assert [item["name"] for item in items] == ["닭가슴살 샐러드"]

    blocked = validate_and_rank_items(
        [{"name": "치즈 샐러드", "kcal": 300, "reason": "유제품 포함"}],
        remaining_kcal=ctx.meal_status.remaining_kcal,
        allergy_str=profile["allergy"],
        count=3,
    )
    assert blocked == []

    print("recommendation pipeline smoke test passed")


if __name__ == "__main__":
    main()
