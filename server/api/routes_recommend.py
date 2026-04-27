import json
import logging
import re

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

import requests as _requests
from ai.rag_engine.rag_pipeline import (
    get_collection, _get_embed_model, LLM_MODEL, OLLAMA_BASE_URL,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/recommend", tags=["recommend"])

# 알레르기 유발 성분 키워드 매핑
_ALLERGEN_KEYWORDS: dict[str, list[str]] = {
    "유제품": ["우유", "치즈", "버터", "요거트", "크림", "유청", "밀크", "라떼", "카푸치노", "아이스크림", "그라탱"],
    "견과류": ["아몬드", "호두", "캐슈", "땅콩", "잣", "피스타치오", "마카다미아", "헤이즐넛", "피넛", "견과"],
    "갑각류": ["새우", "게", "랍스터", "크랩", "대게"],
    "밀": ["빵", "파스타", "면", "국수", "라면", "우동", "스파게티", "밀가루", "도넛", "케이크", "쿠키", "크래커", "베이글", "피자", "만두", "냉면", "소면", "중면"],
    "글루텐": ["빵", "파스타", "면", "국수", "라면", "우동", "밀가루"],
    "계란": ["계란", "달걀", "에그", "오믈렛", "마요네즈", "계란찜", "달걀찜"],
    "대두": ["두부", "된장", "간장", "두유", "콩국수", "낫토", "청국장"],
    "복숭아": ["복숭아", "피치"],
    "토마토": ["토마토", "케첩"],
    "고등어": ["고등어"],
    "조개류": ["조개", "홍합", "굴", "전복", "바지락", "오징어", "낙지", "문어"],
}


def _check_allergens(food_name: str, allergy_str: str | None) -> tuple[bool, list[str]]:
    """음식명과 알레르기 목록을 비교해 경고 여부와 해당 알레르기 이름 목록 반환"""
    if not allergy_str:
        return False, []
    allergens = [a.strip() for a in allergy_str.replace(",", " ").split() if a.strip()]
    matched = []
    for allergen in allergens:
        if allergen == "없음":
            continue
        keywords = _ALLERGEN_KEYWORDS.get(allergen, [allergen])
        if any(kw in food_name for kw in keywords):
            matched.append(allergen)
    return bool(matched), matched


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
    category: str = "전체"


class RecommendMenuItem(BaseModel):
    name: str
    kcal: float = 0.0
    carb: float = 0.0
    protein: float = 0.0
    fat: float = 0.0
    reason: str = ""
    tags: list[str] = []
    allergen_warning: bool = False
    allergen_names: list[str] = []


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
- 메뉴명은 반드시 일반 음식명으로 작성하세요 (예: 김치찌개, 된장찌개, 닭가슴살 샐러드)
- 브랜드명, 제품명, 상품명은 절대 사용하지 마세요 (예: "OO 단백질 쉐이크", "XX 도시락" 금지)
- 가공식품, 즉석식품, 영양제는 추천하지 마세요
- 집밥, 한식, 카페 메뉴 등 일반적으로 알려진 음식명만 사용하세요

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


def _call_ollama_json(messages: list[dict], retries: int = 2) -> str:
    payload = {
        "model": LLM_MODEL,
        "format": "json",
        "stream": False,
        "think": False,
        "options": {"temperature": 0.4, "num_predict": 1024},
        "messages": messages,
    }
    last_err = None
    for attempt in range(retries + 1):
        try:
            resp = _requests.post(
                f"{OLLAMA_BASE_URL}/api/chat",
                json=payload,
                timeout=120,
            )
            resp.raise_for_status()
            raw = resp.json()["message"]["content"]
            _extract_json(raw)  # 파싱 가능한지 검증
            return raw
        except (ValueError, KeyError, json.JSONDecodeError) as e:
            last_err = e
            logger.warning("JSON 파싱 실패 (시도 %d/%d): %s", attempt + 1, retries + 1, e)
    raise ValueError(f"JSON 파싱 {retries + 1}회 실패: {last_err}")


@router.post("", response_model=RecommendResponse)
async def recommend(req: RecommendRequest) -> RecommendResponse:
    try:
        profile = req.user_profile.model_dump(exclude_none=False)
        meal_history = [m.model_dump() for m in req.meal_history]

        # RAG 검색: 카테고리별 + 사용자 프로필 기반 쿼리
        goal = profile.get("goal", "건강 식단")
        condition = profile.get("condition", "")
        category = req.category

        _CATEGORY_QUERIES = {
            "다이어트":    "저칼로리 다이어트 체중감량 식단",
            "기호별":     "취향 맞춤 인기 음식 선호",
            "질환맞춤":   f"{condition or '건강'} 질환 맞춤 식이요법",
            "건강기능식품": "건강기능식품 영양제 보충제",
        }
        search_query = _CATEGORY_QUERIES.get(category, f"{goal} 추천 메뉴")
        if category == "전체" and condition:
            search_query += f" {condition} 식단"

        embed_model = _get_embed_model()
        query_embedding = embed_model.encode(search_query, convert_to_numpy=True).tolist()

        collection = get_collection()
        # 건강기능식품 카테고리는 메타데이터 필터로 영양제 데이터만 검색
        where_filter = {"source": "건강기능식품DB"} if category == "건강기능식품" else None
        query_kwargs = dict(query_embeddings=[query_embedding], n_results=12)
        if where_filter:
            query_kwargs["where"] = where_filter
        results = collection.query(**query_kwargs)
        docs = results["documents"][0] if results["documents"] else []
        cleaned_docs = [doc.replace("|", ",") for doc in docs]
        context = "\n".join(cleaned_docs)

        system_content = RECOMMEND_PROMPT.format(
            context=context,
            profile_str=_build_profile_str(profile),
            meal_str=_build_meal_str(meal_history),
            count=req.count,
        )
        messages = [
            {"role": "system", "content": system_content},
            {"role": "user", "content": f"카테고리: {category}\n위 정보를 바탕으로 {req.count}개 메뉴를 JSON으로 추천해주세요."},
        ]

        raw = _call_ollama_json(messages)
        data = _extract_json(raw)

        allergy_str = profile.get("allergy")
        items = []
        for item in data.get("items", []):
            name = item.get("name", "")
            warning, allergen_names = _check_allergens(name, allergy_str)
            if warning:
                continue  # 알레르기 성분 포함 메뉴는 목록에서 제외
            items.append(RecommendMenuItem(
                name=name,
                kcal=float(item.get("kcal", 0)),
                carb=float(item.get("carb", 0)),
                protein=float(item.get("protein", 0)),
                fat=float(item.get("fat", 0)),
                reason=item.get("reason", ""),
                tags=item.get("tags", []),
                allergen_warning=False,
                allergen_names=[],
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
