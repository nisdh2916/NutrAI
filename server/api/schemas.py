from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"


class NutritionInfo(BaseModel):
    kcal: float = 0.0
    carb_g: float = 0.0
    protein_g: float = 0.0
    fat_g: float = 0.0
    sodium_mg: float = 0.0
    sugar_g: float = 0.0
    weight_g: float = 0.0


class DetectionItem(BaseModel):
    food_name: str
    confidence: float = Field(ge=0.0, le=1.0)
    bbox: list[int]
    count: int = Field(ge=1)
    quantity_class: str = "Q3"        # Q1~Q5 (1인분 기준)
    quantity_ratio: float = 1.0       # 0.2~2.0 (1인분=1.0)
    nutrition: Optional[NutritionInfo] = None


class DetectResponse(BaseModel):
    detections: list[DetectionItem]
    inference_ms: int = Field(ge=0)


class NutritionItemRequest(BaseModel):
    food_name: str
    serving: float = Field(gt=0)


class NutritionRequest(BaseModel):
    items: list[NutritionItemRequest]


class NutritionBreakdown(BaseModel):
    food_name: str
    kcal: float


class NutritionResponse(BaseModel):
    total_kcal: float
    carb_g: float
    protein_g: float
    fat_g: float
    breakdown: list[NutritionBreakdown]


class MealItem(BaseModel):
    food_name: str
    serving: float = Field(gt=0)
    kcal: float = Field(ge=0)


class MealCreateRequest(BaseModel):
    user_id: str
    eaten_at: datetime
    items: list[MealItem]
    total_kcal: float = Field(ge=0)


class MealCreateResponse(BaseModel):
    meal_id: str
    saved: bool


class MealSummary(BaseModel):
    meal_id: str
    time: str
    items: list[str]
    kcal: float


class MealsByDateResponse(BaseModel):
    date: str
    total_kcal: float
    meals: list[MealSummary]


class FoodAddRequest(BaseModel):
    name: str
    category: str = ""
    source: str = "직접입력"
    kcal: float = Field(ge=0)
    carb_g: float = Field(ge=0, default=0.0)
    protein_g: float = Field(ge=0, default=0.0)
    fat_g: float = Field(ge=0, default=0.0)
    sodium_mg: float = Field(ge=0, default=0.0)
    fiber_g: float = Field(ge=0, default=0.0)
    sugar_g: float = Field(ge=0, default=0.0)
    serving: str = "1인분"


class FoodBulkAddRequest(BaseModel):
    items: list[FoodAddRequest]


class FoodAddResponse(BaseModel):
    added: int
    failed: int
    names: list[str]


class FoodSearchResult(BaseModel):
    name: str
    category: str = ""
    kcal: float = 0.0
    carb_g: float = 0.0
    protein_g: float = 0.0
    fat_g: float = 0.0
    sodium_mg: float = 0.0
    sugar_g: float = 0.0
    sat_fat_g: float = 0.0
    cholesterol_mg: float = 0.0
    serving: str = ""


class FoodSearchResponse(BaseModel):
    results: list[FoodSearchResult]
