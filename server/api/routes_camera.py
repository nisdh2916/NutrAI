from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from server.db.mysql_db import get_db
from server.db.mysql_models import Meal, MealImage, FoodAnalysisResult, MealFood

router = APIRouter(prefix="/camera", tags=["camera"])


class DetectedFood(BaseModel):
    food_name:   str
    amount_g:    float
    kcal:        float        = 0.0
    carb_g:      float        = 0.0
    protein_g:   float        = 0.0
    fat_g:       float        = 0.0
    confidence:  Optional[float] = None
    raw_label:   Optional[str]   = None


class CameraDetectRequest(BaseModel):
    user_id:    int
    meal_type:  str                    # breakfast | lunch | dinner | snack
    image_url:  Optional[str] = None
    eaten_at:   Optional[str] = None   # ISO8601, 없으면 현재 시각
    memo:       Optional[str] = None
    foods:      list[DetectedFood]


class CameraDetectResponse(BaseModel):
    meal_id:       int
    meal_image_id: Optional[int]
    saved_foods:   int
    total_kcal:    float


@router.post("/detect", response_model=CameraDetectResponse)
def receive_camera_detection(req: CameraDetectRequest, db: Session = Depends(get_db)):
    eaten_at = datetime.fromisoformat(req.eaten_at) if req.eaten_at else datetime.utcnow()

    total_kcal      = sum(f.kcal      for f in req.foods)
    total_carb_g    = sum(f.carb_g    for f in req.foods)
    total_protein_g = sum(f.protein_g for f in req.foods)
    total_fat_g     = sum(f.fat_g     for f in req.foods)

    meal = Meal(
        users_id        = req.user_id,
        meal_type       = req.meal_type,
        eaten_at        = eaten_at,
        memo            = req.memo,
        source_type     = "camera",
        total_kcal      = total_kcal,
        total_carb_g    = total_carb_g,
        total_protein_g = total_protein_g,
        total_fat_g     = total_fat_g,
    )
    db.add(meal)
    db.flush()  # meal.id 확보

    meal_image_id = None
    if req.image_url:
        image = MealImage(meals_id=meal.id, image_url=req.image_url)
        db.add(image)
        db.flush()
        meal_image_id = image.id

        for f in req.foods:
            db.add(FoodAnalysisResult(
                meal_images_id     = image.id,
                detected_food_name = f.food_name,
                estimated_amount_g = f.amount_g,
                confidence         = f.confidence,
                raw_label          = f.raw_label,
            ))

    for f in req.foods:
        db.add(MealFood(
            meals_id   = meal.id,
            food_name  = f.food_name,
            amount_g   = f.amount_g,
            kcal       = f.kcal,
            carb_g     = f.carb_g,
            protein_g  = f.protein_g,
            fat_g      = f.fat_g,
            confidence = f.confidence,
        ))

    db.commit()

    return CameraDetectResponse(
        meal_id       = meal.id,
        meal_image_id = meal_image_id,
        saved_foods   = len(req.foods),
        total_kcal    = float(total_kcal),
    )


@router.get("/meals/{user_id}")
def get_user_meals(user_id: int, date: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(Meal).filter(Meal.users_id == user_id)

    if date:
        try:
            target = datetime.fromisoformat(date).date()
        except ValueError:
            raise HTTPException(status_code=400, detail="date format must be YYYY-MM-DD")
        query = query.filter(Meal.eaten_at >= f"{target} 00:00:00",
                             Meal.eaten_at <= f"{target} 23:59:59")

    meals = query.order_by(Meal.eaten_at.desc()).all()

    return [
        {
            "id":           m.id,
            "meal_type":    m.meal_type,
            "eaten_at":     m.eaten_at.isoformat(),
            "source_type":  m.source_type,
            "total_kcal":   float(m.total_kcal or 0),
            "foods": [
                {
                    "food_name": mf.food_name,
                    "amount_g":  float(mf.amount_g),
                    "kcal":      float(mf.kcal),
                }
                for mf in m.meal_foods
            ],
        }
        for m in meals
    ]
