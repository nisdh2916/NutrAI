from fastapi import APIRouter

from server.api.schemas import FoodAddRequest, FoodBulkAddRequest, FoodAddResponse
from server.services.food_add_service import add_foods

router = APIRouter(tags=["food"])


@router.post("/food/add", response_model=FoodAddResponse)
def post_food_add(payload: FoodAddRequest) -> FoodAddResponse:
    """식품 단건 추가"""
    return add_foods([payload])


@router.post("/food/bulk", response_model=FoodAddResponse)
def post_food_bulk(payload: FoodBulkAddRequest) -> FoodAddResponse:
    """식품 일괄 추가"""
    return add_foods(payload.items)
