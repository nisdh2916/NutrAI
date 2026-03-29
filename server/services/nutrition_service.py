from server.api.schemas import (
    NutritionBreakdown,
    NutritionRequest,
    NutritionResponse,
)

FOOD_NUTRITION = {
    "김치찌개": {"kcal": 280, "carb_g": 16.0, "protein_g": 18.0, "fat_g": 14.0},
    "쌀밥": {"kcal": 400, "carb_g": 76.1, "protein_g": 6.3, "fat_g": 4.6},
    "닭가슴살": {"kcal": 165, "carb_g": 0.0, "protein_g": 31.0, "fat_g": 3.6},
}


def calculate_nutrition(payload: NutritionRequest) -> NutritionResponse:
    total_kcal = 0.0
    total_carb = 0.0
    total_protein = 0.0
    total_fat = 0.0
    breakdown: list[NutritionBreakdown] = []

    for item in payload.items:
        base = FOOD_NUTRITION.get(
            item.food_name,
            {"kcal": 250.0, "carb_g": 30.0, "protein_g": 10.0, "fat_g": 8.0},
        )
        kcal = round(base["kcal"] * item.serving, 2)
        carb = round(base["carb_g"] * item.serving, 2)
        protein = round(base["protein_g"] * item.serving, 2)
        fat = round(base["fat_g"] * item.serving, 2)

        total_kcal += kcal
        total_carb += carb
        total_protein += protein
        total_fat += fat
        breakdown.append(NutritionBreakdown(food_name=item.food_name, kcal=kcal))

    return NutritionResponse(
        total_kcal=round(total_kcal, 2),
        carb_g=round(total_carb, 2),
        protein_g=round(total_protein, 2),
        fat_g=round(total_fat, 2),
        breakdown=breakdown,
    )
