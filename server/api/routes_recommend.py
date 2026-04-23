import json
import logging
import re

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ai.rag_engine.rag_pipeline import (
    get_collection, _get_embed_model, LLM_MODEL, OLLAMA_BASE_URL,
)
from langchain_ollama import OllamaLLM

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/recommend", tags=["recommend"])


# ── Request / Response ────────────────────────────
class UserProfile(BaseModel):
    age: int | None = None
    height: float | None = None
    weight: float | None = None
    gender: str | None = None
    goal: str = "일반 건강 관리"
    condition: str | None = None
    allergy: str | None = None
    activity_level: str | None = None
    target_kcal: float | None = None


class MealHistoryItem(BaseModel):
    meal_type: str = ""
    foods: list[dict] = []
    total_kcal: float = 0.0


class RecommendRequest(BaseModel):
    user_profile: UserProfile = UserProfile()
    meal_history: list[MealHistoryItem] = []
    count: int = 5


class RecommendMenuItem(BaseModel):
    name: str
    kcal: float = 0.0
    carb: float = 0.0
    protein: float = 0.0
    fat: float = 0.0
    reason: str = ""
    tags: list[str] = []


class RecommendResponse(BaseModel):
    items: list[RecommendMenuItem]
    coaching: str = ""


# ── 프롬프트 ────────────────────────────────────────
RECOMMEND_PROMPT = """당신은 NutrAI의 전문 영양 코치입니다.
반드시 한국어로만 답변하세요.

사용자 정보와 오늘 식단을 분석하여 맞춤형 메뉴를 추천해주세요.

중요 규칙:
- 알레르기 식품은 절대 추천하지 마세요
- 질환이 있으면 해당 질환에 맞는 식단을 우선 고려하세요
- 오늘 이미 먹은 음식의 영양소 균형을 고려하여 부족한 영양소를 보충하세요
- 한국인이 쉽게 구할 수 있는 음식 위주로 추천하세요
- 프랜차이즈 메뉴, 편의점 음식, 배달 음식도 적극 활용하세요

참고 영양 정보:
{context}

{profile_str}

{meal_str}

반드시 아래 JSON 형식으로만 답변하세요. 다른 텍스트는 포함하지 마세요:
{{"items": [{{"name": "메뉴명", "kcal": 숫자, "carb": 탄수화물g, "protein": 단백질g, "fat": 지방g, "reason": "추천 이유 1~2문장", "tags": ["#태그1", "#태그2"]}}], "coaching": "코칭 메시지 1~2문장"}}

{count}개의 메뉴를 추천해주세요.
"""


def _build_profile_str(p: dict) -> str:
    parts = [
        f"나이 {p.get('age', '미입력')}세",
        f"성별 {p.get('gender', '미입력')}",
        f"키 {p.get('height', '미입력')}cm",
        f"몸무게 {p.get('weight', '미입력')}kg",
        f"활동량 {p.get('activity_level', '미입력')}",
        f"건강 목표: {p.get('goal', '일반 건강 관리')}",
    ]
    if p.get("target_kcal"):
        parts.append(f"목표 칼로리: {p['target_kcal']}kcal")
    parts.append(f"질환: {p.get('condition') or '없음'}")
    parts.append(f"알레르기: {p.get('allergy') or '없음'}")
    return "사용자 정보: " + ", ".join(parts)


def _build_meal_str(meals: list[dict]) -> str:
    if not meals:
        return "오늘 식단 기록: 없음"
    lines = ["오늘 식단 기록:"]
    total_kcal = 0.0
    for m in meals:
        food_names = [f.get("name", "") for f in m.get("foods", [])]
        kcal = m.get("total_kcal", 0)
        total_kcal += kcal
        lines.append(f"- {m.get('meal_type', '식사')}: {', '.join(food_names)} ({kcal:.0f}kcal)")
    lines.append(f"- 합계: {total_kcal:.0f}kcal")
    return "\n".join(lines)


def _extract_json(text: str) -> dict:
    """LLM 응답에서 JSON 추출"""
    # 코드블록 안에 있을 수 있음
    m = re.search(r"```(?:json)?\s*(.*?)```", text, re.DOTALL)
    if m:
        text = m.group(1)
    # { 로 시작하는 부분 찾기
    start = text.find("{")
    if start == -1:
        raise ValueError("JSON not found in response")
    # 마지막 } 찾기
    end = text.rfind("}")
    if end == -1:
        raise ValueError("JSON not found in response")
    return json.loads(text[start:end + 1])


@router.post("", response_model=RecommendResponse)
async def recommend(req: RecommendRequest) -> RecommendResponse:
    try:
        profile = req.user_profile.model_dump(exclude_none=False)
        meal_history = [m.model_dump() for m in req.meal_history]

        # RAG 검색: 사용자 목표 + 조건에 맞는 음식 검색
        goal = profile.get("goal", "건강 식단")
        condition = profile.get("condition", "")
        search_query = f"{goal} 추천 메뉴"
        if condition:
            search_query += f" {condition} 식단"

        embed_model = _get_embed_model()
        query_embedding = embed_model.encode(search_query, convert_to_numpy=True).tolist()

        collection = get_collection()
        results = collection.query(query_embeddings=[query_embedding], n_results=8)
        docs = results["documents"][0] if results["documents"] else []
        cleaned_docs = [doc.replace("|", ",") for doc in docs]
        context = "\n".join(cleaned_docs)

        prompt = RECOMMEND_PROMPT.format(
            context=context,
            profile_str=_build_profile_str(profile),
            meal_str=_build_meal_str(meal_history),
            count=req.count,
        )

        llm = OllamaLLM(
            model=LLM_MODEL,
            base_url=OLLAMA_BASE_URL,
            temperature=0.4,
        )
        raw = llm.invoke(prompt)
        data = _extract_json(raw)

        items = []
        for item in data.get("items", []):
            items.append(RecommendMenuItem(
                name=item.get("name", ""),
                kcal=float(item.get("kcal", 0)),
                carb=float(item.get("carb", 0)),
                protein=float(item.get("protein", 0)),
                fat=float(item.get("fat", 0)),
                reason=item.get("reason", ""),
                tags=item.get("tags", []),
            ))

        return RecommendResponse(
            items=items,
            coaching=data.get("coaching", ""),
        )

    except RuntimeError as e:
        logger.error("추천 파이프라인 오류: %s", e)
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.exception("추천 처리 중 오류")
        raise HTTPException(status_code=500, detail=str(e))
