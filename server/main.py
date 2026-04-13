from fastapi import FastAPI

from server.api.routes_detect import router as detect_router
from server.api.routes_health import router as health_router
from server.api.routes_meals import router as meals_router
from server.api.routes_nutrition import router as nutrition_router
from server.api.routes_chat import router as chat_router
from server.api.routes_food import router as food_router
from server.api.routes_recommend import router as recommend_router
from server.api.routes_profile import router as profile_router

app = FastAPI(title="NutrAI API", version="0.1.0")

app.include_router(health_router)
app.include_router(detect_router)
app.include_router(nutrition_router)
app.include_router(meals_router)
app.include_router(chat_router)
app.include_router(food_router)
app.include_router(recommend_router)
app.include_router(profile_router)
