from server.api.schemas import (
    MealCreateRequest,
    MealCreateResponse,
    MealsByDateResponse,
    MealSummary,
)
from server.db.sqlite_store import find_meals_by_date, insert_meal


def create_meal(payload: MealCreateRequest) -> MealCreateResponse:
    meal_id = insert_meal(
        user_id=payload.user_id,
        eaten_at=payload.eaten_at,
        items=[i.model_dump() for i in payload.items],
        total_kcal=payload.total_kcal,
    )
    return MealCreateResponse(meal_id=meal_id, saved=True)


def get_meals_by_date(user_id: str, date: str) -> MealsByDateResponse:
    summaries: list[MealSummary] = []
    total_kcal = 0.0

    for meal in find_meals_by_date(user_id=user_id, date=date):
        kcal = float(meal["total_kcal"])
        total_kcal += kcal
        summaries.append(
            MealSummary(
                meal_id=meal["meal_id"],
                time=meal["eaten_at"].strftime("%H:%M"),
                items=[item["food_name"] for item in meal["items"]],
                kcal=kcal,
            )
        )

    return MealsByDateResponse(date=date, total_kcal=round(total_kcal, 2), meals=summaries)
