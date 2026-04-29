import json
import logging
import re
import time

import requests as _requests
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from starlette.concurrency import run_in_threadpool

from server.services.recommendation_pipeline import (
    build_coaching_prefix,
    build_recommendation_context,
    format_context_block,
    validate_and_rank_items,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/recommend", tags=["recommend"])


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
    foods: list[dict] = Field(default_factory=list)
    total_kcal: float = 0.0


class RecommendRequest(BaseModel):
    user_profile: UserProfile = Field(default_factory=UserProfile)
    meal_history: list[MealHistoryItem] = Field(default_factory=list)
    count: int = Field(default=5, ge=1, le=10)
    category: str = "전체"


class RecommendMenuItem(BaseModel):
    name: str
    kcal: float = 0.0
    carb: float = 0.0
    protein: float = 0.0
    fat: float = 0.0
    reason: str = ""
    tags: list[str] = Field(default_factory=list)
    allergen_warning: bool = False
    allergen_names: list[str] = Field(default_factory=list)


class RecommendResponse(BaseModel):
    items: list[RecommendMenuItem]
    coaching: str = ""


RECOMMEND_PROMPT = """
당신은 NutrAI의 개인 맞춤형 식단 코치입니다.
의료 진단은 하지 말고, 제공된 사용자 데이터와 검색 근거만 사용하세요.

핵심 원칙:
- 계산값은 아래 [MEAL_STATUS]를 신뢰하고 임의로 다시 계산하지 마세요.
- 알레르기, 질환, 저염식/저당식/고단백 같은 제약을 우선 반영하세요.
- 메뉴명은 일반적인 음식명으로 작성하고 브랜드명/상품명은 피하세요.
- 존재하지 않는 가상의 메뉴나 과도하게 특수한 메뉴는 추천하지 마세요.
- 출력은 JSON만 반환하세요.

{context}

[USER_PROFILE]
{profile_str}

[MEAL_HISTORY]
{meal_str}

반드시 아래 JSON 형식으로만 답하세요.
{{
  "items": [
    {{
      "name": "메뉴명",
      "kcal": 350,
      "carb": 30,
      "protein": 25,
      "fat": 10,
      "reason": "추천 이유 1~2문장",
      "tags": ["#저녁", "#고단백"]
    }}
  ],
  "coaching": "사용자가 바로 이해할 수 있는 짧은 조언 1~2문장"
}}

추천 메뉴는 {count}개 생성하세요.
"""


def _build_profile_str(profile: dict) -> str:
    parts = [
        f"age={profile.get('age')}",
        f"gender={profile.get('gender')}",
        f"height_cm={profile.get('height')}",
        f"weight_kg={profile.get('weight')}",
        f"goal={profile.get('goal')}",
        f"condition={profile.get('condition') or '없음'}",
        f"allergy={profile.get('allergy') or '없음'}",
        f"activity_level={profile.get('activity_level')}",
        f"target_kcal={profile.get('target_kcal')}",
    ]
    return "\n".join(f"- {part}" for part in parts)


def _build_meal_str(meals: list[dict]) -> str:
    if not meals:
        return "- 기록 없음"

    lines = []
    total_kcal = total_carb = total_protein = total_fat = 0.0
    for meal in meals:
        foods = meal.get("foods", []) or []
        names = [str(food.get("name", "")) for food in foods if food.get("name")]
        kcal = float(meal.get("total_kcal") or 0)
        total_kcal += kcal
        for food in foods:
            total_carb += float(food.get("carb_g") or 0)
            total_protein += float(food.get("protein_g") or 0)
            total_fat += float(food.get("fat_g") or 0)
        lines.append(f"- {meal.get('meal_type', '식사')}: {', '.join(names)} ({kcal:.0f}kcal)")

    lines.append(
        f"- total: {total_kcal:.0f}kcal, carb={total_carb:.0f}g, "
        f"protein={total_protein:.0f}g, fat={total_fat:.0f}g"
    )
    return "\n".join(lines)


def _extract_json(text: str) -> dict:
    """LLM 응답에서 JSON 객체를 안전하게 추출. 실패 시 ValueError."""
    match = re.search(r"```(?:json)?\s*(.*?)```", text, re.DOTALL)
    if match:
        text = match.group(1)
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1:
        raise ValueError("JSON not found in response")
    return json.loads(text[start : end + 1])


def _try_extract_json(text: str) -> dict:
    """Strict 파싱 실패 시 항목 단위 부분 추출을 시도하는 폴백."""
    try:
        return _extract_json(text)
    except (ValueError, json.JSONDecodeError):
        # items 배열만이라도 살려본다 — JSON 일부가 잘려도 메뉴 일부는 복구
        items: list[dict] = []
        for chunk in re.findall(r"\{[^{}]*\"name\"[^{}]*\}", text, re.DOTALL):
            try:
                items.append(json.loads(chunk))
            except json.JSONDecodeError:
                continue
        if items:
            logger.info("Recovered %d items via fragment parsing", len(items))
            return {"items": items, "coaching": ""}
        raise


# 재시도 대상 예외 — 네트워크/타임아웃까지 포함
_RETRYABLE = (
    _requests.exceptions.Timeout,
    _requests.exceptions.ConnectionError,
    _requests.exceptions.HTTPError,
    ValueError,
    KeyError,
    json.JSONDecodeError,
)


def _call_ollama_json(messages: list[dict], retries: int | None = None) -> str:
    """
    Ollama chat API를 JSON 응답 모드로 호출.
    네트워크/타임아웃/JSON 파싱 오류 모두 exponential backoff로 재시도.
    """
    from server.common.llm_config import LLM, JSON_TEMPERATURE, JSON_NUM_PREDICT

    if retries is None:
        retries = LLM.retries

    payload = {
        "model": LLM.model,
        "format": "json",
        "stream": False,
        "think": False,
        "options": {"temperature": JSON_TEMPERATURE, "num_predict": JSON_NUM_PREDICT},
        "messages": messages,
    }
    last_err: Exception | None = None
    for attempt in range(retries + 1):
        try:
            resp = _requests.post(
                f"{LLM.base_url}/api/chat", json=payload, timeout=LLM.timeout_s
            )
            resp.raise_for_status()
            raw = resp.json()["message"]["content"]
            _extract_json(raw)  # 파싱 가능한지 검증
            return raw
        except _RETRYABLE as e:
            last_err = e
            wait = min(2 ** attempt, 8)  # 1s, 2s, 4s, 8s 상한
            logger.warning(
                "Ollama call failed (%d/%d): %s — retry in %ds",
                attempt + 1, retries + 1, type(e).__name__, wait,
            )
            if attempt < retries:
                time.sleep(wait)
    raise ValueError(f"Ollama call failed after {retries + 1} attempts: {last_err}")


def _fallback_response(category: str, reason: str) -> "RecommendResponse":
    """LLM/네트워크 완전 실패 시 사용자에게 보낼 최소 안내 응답."""
    return RecommendResponse(
        items=[],
        coaching=(
            f"⚠️ 추천 엔진이 일시적으로 응답하지 않아요 ({reason}). "
            "잠시 후 새로고침해주세요."
        ),
    )


async def _retrieve_docs(
    queries: list[str],
    limit: int = 8,
    where: dict | None = None,
) -> list[str]:
    from ai.rag_engine.rag_pipeline import _get_embed_model, get_collection

    embed_model = _get_embed_model()
    collection = get_collection()
    docs: list[str] = []
    seen_docs: set[str] = set()

    for query in queries:
        query_embedding = (
            await run_in_threadpool(embed_model.encode, query, convert_to_numpy=True)
        ).tolist()
        query_kwargs: dict = dict(query_embeddings=[query_embedding], n_results=4)
        if where:
            query_kwargs["where"] = where
        results = await run_in_threadpool(collection.query, **query_kwargs)
        for doc in results["documents"][0] if results["documents"] else []:
            if doc in seen_docs:
                continue
            docs.append(doc)
            seen_docs.add(doc)
            if len(docs) >= limit:
                return docs
    return docs


@router.post("", response_model=RecommendResponse)
async def recommend(req: RecommendRequest) -> RecommendResponse:
    try:
        profile = req.user_profile.model_dump(exclude_none=False)
        meal_history = [meal.model_dump() for meal in req.meal_history]
        pipeline_ctx = build_recommendation_context(
            profile=profile,
            meal_history=meal_history,
            category=req.category,
            user_query=f"{req.category} 메뉴 추천",
        )

        # 건강기능식품 카테고리는 해당 소스만 검색
        where_filter = {"source": "건강기능식품DB"} if req.category == "건강기능식품" else None
        docs = await _retrieve_docs(pipeline_ctx.queries, where=where_filter)
        context = format_context_block(pipeline_ctx, docs)
        messages = [
            {
                "role": "system",
                "content": RECOMMEND_PROMPT.format(
                    context=context,
                    profile_str=_build_profile_str(profile),
                    meal_str=_build_meal_str(meal_history),
                    count=req.count,
                ),
            },
            {
                "role": "user",
                "content": f"카테고리: {req.category}\n위 정보를 바탕으로 메뉴를 JSON으로 추천해주세요.",
            },
        ]

        try:
            raw = await run_in_threadpool(_call_ollama_json, messages)
            data = _try_extract_json(raw)
        except (ValueError, _requests.exceptions.RequestException) as e:
            # 재시도 모두 실패 → 빈 추천으로 폴백 (5xx 대신 200 + 안내)
            logger.warning("Recommendation fallback: %s", e)
            return _fallback_response(req.category, "LLM 응답 실패")

        ranked_items = validate_and_rank_items(
            data.get("items", []),
            remaining_kcal=pipeline_ctx.meal_status.remaining_kcal,
            allergy_str=profile.get("allergy"),
            count=req.count,
        )

        return RecommendResponse(
            items=[RecommendMenuItem(**item) for item in ranked_items],
            coaching=f"{build_coaching_prefix(pipeline_ctx)} {data.get('coaching', '')}".strip(),
        )

    except (ImportError, RuntimeError) as e:
        logger.error("Recommendation pipeline error: %s", e)
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.exception("Unexpected recommendation error")
        raise HTTPException(status_code=500, detail=str(e))
