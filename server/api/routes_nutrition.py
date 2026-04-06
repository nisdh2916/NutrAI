from fastapi import APIRouter

from server.api.schemas import NutritionRequest, NutritionResponse
from server.services.nutrition_service import calculate_nutrition

router = APIRouter(tags=["nutrition"])


@router.post("/nutrition/calculate", response_model=NutritionResponse)
def post_nutrition_calculate(payload: NutritionRequest) -> NutritionResponse:
    return calculate_nutrition(payload)
