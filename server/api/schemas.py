from datetime import datetime

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"


class DetectionItem(BaseModel):
    food_name: str
    confidence: float = Field(ge=0.0, le=1.0)
    bbox: list[int]
    count: int = Field(ge=1)


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
