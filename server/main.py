import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI

from server.api.routes_detect import router as detect_router
from server.api.routes_health import router as health_router
from server.api.routes_meals import router as meals_router
from server.api.routes_nutrition import router as nutrition_router
from server.api.routes_chat import router as chat_router
from server.api.routes_food import router as food_router
from server.api.routes_recommend import router as recommend_router
from server.api.routes_profile import router as profile_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 서버 시작 시 LLM + 임베딩 모델 사전 로드
    logger.info("NutrAI 서버 시작 — 모델 예열 중...")
    try:
        await asyncio.get_event_loop().run_in_executor(None, _warmup)
        logger.info("모델 예열 완료")
    except Exception as e:
        logger.warning("모델 예열 실패 (첫 요청 시 로드됨): %s", e)
    yield


def _warmup():
    from ai.rag_engine.rag_pipeline import _get_embed_model, _get_llm
    _get_embed_model()
    llm = _get_llm()
    # Ollama에 모델 로드 트리거 (빈 메시지)
    try:
        from langchain_core.messages import HumanMessage
        llm.invoke([HumanMessage(content="안녕")])
    except Exception:
        pass


app = FastAPI(title="NutrAI API", version="0.1.0", lifespan=lifespan)

app.include_router(health_router)
app.include_router(detect_router)
app.include_router(nutrition_router)
app.include_router(meals_router)
app.include_router(chat_router)
app.include_router(food_router)
app.include_router(recommend_router)
app.include_router(profile_router)
