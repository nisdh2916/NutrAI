from fastapi import APIRouter, Query

from server.api.schemas import MealCreateRequest, MealCreateResponse, MealsByDateResponse
from server.services.meal_service import create_meal, get_meals_by_date

router = APIRouter(tags=["meals"])


@router.post("/meals", response_model=MealCreateResponse)
def post_meals(payload: MealCreateRequest) -> MealCreateResponse:
    return create_meal(payload)


@router.get("/meals", response_model=MealsByDateResponse)
def get_meals(
    user_id: str = Query(..., min_length=1),
    date: str = Query(..., pattern=r"^\d{4}-\d{2}-\d{2}$"),
) -> MealsByDateResponse:
    return get_meals_by_date(user_id=user_id, date=date)
