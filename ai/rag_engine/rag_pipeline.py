"""
NutrAI RAG 파이프라인
- 벡터 DB: ChromaDB (로컬)
- LLM: Qwen3:8b via Ollama
- 프레임워크: LangChain
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import chromadb
from sentence_transformers import SentenceTransformer
from langchain_ollama import ChatOllama
from langchain_core.messages import HumanMessage, SystemMessage

from server.common.llm_config import LLM, CHAT_TEMPERATURE, CHAT_NUM_PREDICT
from server.common.allergens import extract_allergen_keywords

CHROMA_DIR = Path(__file__).parent / "chroma_db"
EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"
# 하위 호환: 기존 import 사용처를 위해 모듈 레벨 alias 유지
OLLAMA_BASE_URL = LLM.base_url
LLM_MODEL = LLM.model

# 정규화된 L2 거리 임계값: sqrt(2*(1-cos)) 기준, 1.0 ≈ cosine 유사도 0.5
SIMILARITY_THRESHOLD = 1.0
FETCH_MULTIPLIER = 2  # 쿼리당 k*2개 후보 검색 (다중 쿼리이므로 1개당 multiplier 줄임)

_embed_model: SentenceTransformer | None = None
_collection = None
_llm: ChatOllama | None = None


from ai.allergens import ALLERGEN_KEYWORDS as _ALLERGEN_KEYWORDS

# ── 시간대 / 의도 키워드 ──────────────────────────
_MEAL_TIME_MAP: dict[str, str] = {
    "아침": "아침",
    "모닝": "아침",
    "브런치": "아침",
    "점심": "점심",
    "런치": "점심",
    "저녁": "저녁",
    "야식": "저녁",
    "간식": "간식",
    "스낵": "간식",
}


def _get_embed_model() -> SentenceTransformer:
    global _embed_model
    if _embed_model is None:
        import torch
        device = "cuda" if torch.cuda.is_available() else "cpu"
        _embed_model = SentenceTransformer(EMBED_MODEL, device=device)
    return _embed_model


def _get_llm() -> ChatOllama:
    global _llm
    if _llm is None:
        _llm = ChatOllama(
            model=LLM.model,
            base_url=LLM.base_url,
            temperature=CHAT_TEMPERATURE,
            num_predict=CHAT_NUM_PREDICT,
            think=False,
            keep_alive=LLM.keep_alive,
        )
    return _llm


def get_collection():
    global _collection
    if _collection is None:
        if not CHROMA_DIR.exists():
            raise RuntimeError(f"ChromaDB 경로가 존재하지 않습니다: {CHROMA_DIR}")
        client = chromadb.PersistentClient(path=str(CHROMA_DIR))
        try:
            _collection = client.get_collection("nutrition")
        except Exception:
            raise RuntimeError("ChromaDB 'nutrition' 컬렉션이 없습니다. build_nutrition_db.py를 먼저 실행하세요.")
    return _collection


# ── 시스템 프롬프트 ────────────────────────────────
# {context}를 제거하고 HumanMessage에 구조화된 섹션으로 전달
SYSTEM_PROMPT = """한국어로만 답변하는 NutrAI 영양 코치입니다.
반드시 [참고 영양 정보]에 있는 식품 데이터를 바탕으로 추천하세요. 목록에 없는 음식은 추천하지 마세요.
알레르기 성분이 포함된 음식은 절대 추천하지 마세요.
질환이 있으면 해당 질환에 적합한 식단을 최우선으로 고려하세요.
의료적 확정 표현은 사용하지 말고 권고 표현을 사용하세요.
수치 계산(칼로리, 남은 열량)은 반드시 [식단 현황]의 수치를 그대로 사용하고 임의로 계산하지 마세요.

[칼로리 표기 기준 - 반드시 준수]
[참고 영양 정보]에는 각 음식에 '1인분 기준: Xkcal' 값이 이미 계산되어 있습니다.
음식명 옆 칼로리는 반드시 그 '1인분 기준' 값을 사용하세요.
절대 임의로 계산하거나 100g 수치를 그대로 사용하지 마세요.

[음식 선택 우선순위 - 반드시 준수]
- 밥, 국, 찌개, 구이, 볶음, 나물 등 일반 가정식·한식 위주로 추천하세요.
- 즉석식품, 가공식품, 냉동식품, 포장 간편식(제품명/브랜드명이 있는 식품)은 절대 추천하지 마세요.
- [참고 영양 정보]에 브랜드명이 포함된 항목은 건너뛰고 다른 항목을 선택하세요.
- 추천 음식명은 '된장찌개', '닭가슴살 샐러드', '현미밥' 같은 일반 음식명으로만 표기하세요.

[영양 추론 규칙 - 반드시 준수]
- 당뇨 관련: 혈당을 올리는 것은 탄수화물(당류)이지 단백질이 아닙니다. "단백질이 낮아서 당뇨에 좋다"는 표현은 절대 사용하지 마세요. 당뇨에는 저당·저탄수화물·적정 단백질을 강조하세요.
- 고혈압 관련: 나트륨(염분) 제한이 핵심입니다. "지방이 낮아서 혈압에 좋다"는 단순화 표현은 피하세요.
- 추천 이유는 반드시 [참고 영양 정보]의 수치(칼로리·탄수화물·단백질·지방)를 근거로만 작성하세요. 데이터에 없는 효능·효과를 임의로 추가하지 마세요.

사용자 질문 유형에 따라 답변 형식을 선택하세요:

[특정 음식에 대한 직접 질문 — 칼로리/영양 문의]
해당 음식이 [참고 영양 정보]에 있으면:
  음식명 1인분 기준 칼로리: Xkcal (100g당 Ykcal)
  탄수화물 Ag / 단백질 Bg / 지방 Cg
  코칭 메시지: 1문장
없으면: 데이터 없음을 솔직하게 답하고 유사한 음식의 데이터를 대신 제공

[식단 추천 질문] — 아래 형식 규칙을 따라 추천 3개를 출력하세요:
- 첫 줄: **실제 음식 이름** (칼로리: 숫자kcal)  ← '음식명' 또는 '실제 음식 이름' 이라고 쓰지 말고, 실제 음식 이름을 직접 쓰세요
- 둘째 줄: 추천 이유: [참고 영양 정보] 수치 기반 1~2문장
- 3개 항목 반복 후 코칭 메시지 1~2문장"""


# ── 전처리: 의도·시간대 감지 ─────────────────────
def _detect_meal_time(user_query: str) -> str:
    for kw, label in _MEAL_TIME_MAP.items():
        if kw in user_query:
            return label
    return ""


def _calc_consumed_today(meal_history: list[dict] | None) -> float:
    if not meal_history:
        return 0.0
    return sum(m.get("total_kcal", 0.0) for m in meal_history)


def _calc_remaining_kcal(user_profile: dict, meal_history: list[dict] | None) -> float | None:
    target = user_profile.get("target_kcal")
    if not target:
        return None
    consumed = _calc_consumed_today(meal_history)
    return max(0.0, float(target) - consumed)


_SUPPLEMENT_KEYWORDS = ["영양제", "보충제", "비타민", "건강기능", "영양성분", "미네랄", "오메가"]


def _rewrite_queries(
    user_query: str,
    user_profile: dict,
    detected_foods: list[str] | None,
    remaining_kcal: float | None,
    meal_time: str,
) -> list[str]:
    """
    다중 검색 쿼리 재작성 (최대 4개)

    영양제/보충제 쿼리는 건강기능식품 전용 쿼리로 별도 처리
    일반 식사 쿼리: 시간대 / 목표 / 칼로리 제약 / 질환 연계
    """
    goal = user_profile.get("goal", "")
    condition = user_profile.get("condition", "")

    # 영양제/보충제 의도 감지 → 건강기능식품 전용 쿼리
    if any(kw in user_query for kw in _SUPPLEMENT_KEYWORDS):
        queries = ["비타민 미네랄 건강기능식품"]
        if condition:
            queries.append(f"{condition} 영양 보충 건강기능식품")
        if goal and goal not in ("일반 건강 관리", ""):
            queries.append(f"{goal} 영양제 보충제")
        queries.append("건강기능식품 영양소 보충")
        return queries[:4]

    queries: list[str] = []

    # 1. 사용자 원문 — 항상 포함 (meal_time 감지 여부와 무관)
    if user_query.strip():
        queries.append(user_query.strip())

    # 2. 시간대 + 목표 복합 쿼리
    if meal_time:
        if goal and goal not in ("일반 건강 관리", ""):
            queries.append(f"{goal} {meal_time} 메뉴")
        else:
            queries.append(f"건강한 {meal_time} 메뉴 추천")

    # 3. 질환 맞춤 쿼리 — 질환이 있으면 항상 포함 (우선순위 상향)
    if condition:
        queries.append(f"{condition} 맞춤 식단 가이드라인")

    # 4. 남은 칼로리 제약
    if remaining_kcal is not None and len(queries) < 4:
        queries.append(f"{int(remaining_kcal)}kcal 이하 {meal_time} 식사" if meal_time
                       else f"{int(remaining_kcal)}kcal 이하 메뉴")

    # 5. 감지 음식 연계 (질환 없을 때)
    if detected_foods and not condition and len(queries) < 4:
        foods_str = " ".join(detected_foods[:2])
        queries.append(f"{foods_str} 후 균형 식단")

    return list(dict.fromkeys(q for q in queries if q.strip()))[:4]


# ── 알레르기 유틸 ─────────────────────────────────
def _extract_allergens(user_profile: dict) -> list[str]:
    """알레르기 카테고리 → 실제 식재료 키워드 변환 (server.common.allergens 위임)"""
    return extract_allergen_keywords(user_profile.get("allergy"))


# ── 1인분 환산 ────────────────────────────────────
_SERVING_MULTIPLIER: dict[str, float] = {
    "찌개 및 전골류": 2.5,
    "국 및 탕류": 2.5,
    "탕류": 2.5,
    "밥류": 2.1,
    "면 및 만두류": 2.0,
    "구이류": 1.5,
    "볶음류": 1.5,
    "튀김류": 1.5,
    "조림류": 1.0,
    "나물류": 1.0,
    "무침류": 1.0,
    "김치류": 0.5,
    "장류 및 양념류": 0.3,
    "과일류": 1.5,
    "음료 및 차류": 2.0,
    "과자류": 1.0,
    "떡류": 1.5,
}
_KCAL_100G_RE = re.compile(r"칼로리\s*([\d.]+)kcal", re.IGNORECASE)
_CATEGORY_RE = re.compile(r"분류:\s*([^|,\n]+)")


def _add_serving_kcal(doc: str) -> str:
    """문서에 1인분 칼로리를 계산해서 추가한다."""
    kcal_m = _KCAL_100G_RE.search(doc)
    cat_m = _CATEGORY_RE.search(doc)
    if not kcal_m or not cat_m:
        return doc
    kcal_100g = float(kcal_m.group(1))
    category = cat_m.group(1).strip()
    multiplier = _SERVING_MULTIPLIER.get(category, 1.0)
    serving_kcal = round(kcal_100g * multiplier)
    return doc + f" | 1인분 기준: {serving_kcal}kcal ({multiplier}배 환산)"


# ── 직접 영양 질문 감지 및 즉시 응답 ─────────────────
_NUTRITION_QUESTION_RE = re.compile(
    r"(칼로리|열량|kcal|영양|탄수화물|단백질|지방|나트륨|당류)"
    r".*(얼마|알려|몇|어떻게|뭐야|뭔가요|어때|있어)",
    re.IGNORECASE,
)
_FOOD_NAME_RE = re.compile(r"^([^|,\s][^|]+?)\s*\|")


def _build_direct_nutrition_answer(food_name_kw: str, docs: list[str]) -> str | None:
    """
    특정 음식명 키워드가 검색 결과 상위에 있으면 즉시 답변 생성.
    LLM을 거치지 않아 일관된 수치를 보장.
    """
    for doc in docs[:3]:  # 상위 3개만 확인
        m = _FOOD_NAME_RE.match(doc)
        if not m:
            continue
        doc_name = m.group(1).strip()
        if food_name_kw not in doc_name:
            continue

        # 칼로리 파싱
        kcal_m = _KCAL_100G_RE.search(doc)
        cat_m = _CATEGORY_RE.search(doc)
        serving_m = re.search(r"1인분 기준:\s*([\d]+)kcal", _add_serving_kcal(doc))

        if not kcal_m:
            return None

        kcal_100g = float(kcal_m.group(1))
        category = cat_m.group(1).strip() if cat_m else ""
        serving_kcal = int(serving_m.group(1)) if serving_m else None

        lines = [f"**{doc_name}** 영양 정보 (100g 기준)"]
        lines.append(f"- 칼로리: {kcal_100g}kcal")

        for field, label in [
            (r"탄수화물\s*([\d.]+)g", "탄수화물"),
            (r"단백질\s*([\d.]+)g", "단백질"),
            (r"지방\s*([\d.]+)g", "지방"),
            (r"나트륨\s*([\d.]+)mg", "나트륨"),
        ]:
            fm = re.search(field, doc)
            if fm:
                unit = "mg" if "나트륨" in label else "g"
                lines.append(f"- {label}: {fm.group(1)}{unit}")

        if serving_kcal:
            multiplier = _SERVING_MULTIPLIER.get(category, 1.0)
            serving_g = round(multiplier * 100)
            lines.append(f"\n**1인분 기준 ({serving_g}g):** {serving_kcal}kcal")

        lines.append(f"\n*출처: 식품영양성분 데이터베이스*")
        return "\n".join(lines)
    return None


# ── 컨텍스트 포맷 ─────────────────────────────────
def _format_context(docs: list[str]) -> str:
    if not docs:
        return "관련 영양 정보를 찾지 못했습니다."
    return "\n".join(
        f"{i}. {_add_serving_kcal(doc).replace('|', ', ')}"
        for i, doc in enumerate(docs, 1)
    )


# ── 핵심 검색 로직 ────────────────────────────────
def _diversify_docs(docs: list[str], max_per_category: int = 2) -> list[str]:
    """
    동일 카테고리 문서가 max_per_category개 초과하지 않도록 제한
    카테고리: 문서 첫 번째 쉼표 이전의 '_' 앞 토큰 (예: '피자_랍스타...' → '피자')
    """
    seen: dict[str, int] = {}
    result = []
    for doc in docs:
        first_token = doc.split(",")[0].strip()
        category = first_token.split("_")[0].strip()
        cnt = seen.get(category, 0)
        if cnt < max_per_category:
            result.append(doc)
            seen[category] = cnt + 1
    return result


_QUERY_STOP_WORDS = frozenset([
    "추천", "알려줘", "뭐", "먹을까", "먹어", "먹고", "싶어", "어때",
    "괜찮", "해줘", "주세요", "줘", "있어", "없어", "뭐야", "얼마야",
    "칼로리", "영양", "정보", "좋아", "싫어", "대신", "말고", "이거",
    "저거", "이런", "저런", "오늘", "내일", "아침", "점심", "저녁",
    "간식", "다이어트", "중인데", "중에", "할때", "할때는",
])
_KO_WORD_RE = re.compile(r"[가-힣]{2,6}")


def _extract_food_keywords(query: str) -> list[str]:
    """쿼리에서 음식명 후보 단어 추출 (2~6자 한글, 불용어 제외)"""
    words = _KO_WORD_RE.findall(query)
    return [w for w in words if w not in _QUERY_STOP_WORDS]


def _search_by_keyword(keyword: str, k: int) -> list[str]:
    """ChromaDB where_document 텍스트 포함 검색 — 음식명 직접 매칭용"""
    try:
        collection = get_collection()
        results = collection.get(
            where_document={"$contains": keyword},
            limit=min(k, collection.count()),
            include=["documents"],
        )
        return results.get("documents", [])
    except Exception:
        return []


def _search_single(search_query: str, n_results: int) -> tuple[list[str], list[float]]:
    """단일 쿼리 ChromaDB 검색"""
    embed_model = _get_embed_model()
    query_embedding = embed_model.encode(search_query, convert_to_numpy=True).tolist()
    collection = get_collection()
    n_results = min(n_results, collection.count())
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=n_results,
        include=["documents", "distances"],
    )
    docs = results["documents"][0] if results["documents"] else []
    dists = results["distances"][0] if results["distances"] else []
    return docs, dists


def _retrieve_multi(
    queries: list[str],
    user_profile: dict,
    k: int,
) -> tuple[list[str], str]:
    """
    다중 쿼리 검색 + 중복 제거 + 유사도 필터 + 알레르기 제거 + 상위 k개

    각 쿼리마다 k*FETCH_MULTIPLIER개 검색 → 문서별 최고 유사도 유지 →
    임계값 필터 → 알레르기 제거 → 정렬 후 상위 k개
    """
    allergens = _extract_allergens(user_profile)

    def _has_allergen(doc: str) -> bool:
        return bool(allergens) and any(kw in doc for kw in allergens)

    # ── 1단계: 키워드 직접 매칭 (음식명 포함 문서 우선 확보) ──────
    # 임베딩 유사도가 낮아도 음식명이 정확히 일치하는 문서를 먼저 가져옴
    keyword_docs: list[str] = []
    for q in queries:
        for kw in _extract_food_keywords(q):
            for doc in _search_by_keyword(kw, k):
                if doc not in keyword_docs and not _has_allergen(doc):
                    keyword_docs.append(doc)
                if len(keyword_docs) >= k * 2:
                    break

    # ── 2단계: 임베딩 검색 → 문서별 최고 유사도 보존 ──────────────
    best_dist: dict[str, float] = {}
    for q in queries:
        docs, dists = _search_single(q, k * FETCH_MULTIPLIER)
        for doc, dist in zip(docs, dists):
            if doc not in best_dist or dist < best_dist[doc]:
                best_dist[doc] = dist

    # 유사도 기준 정렬
    sorted_docs = sorted(best_dist.items(), key=lambda x: x[1])

    # 1차: 임계값 + 알레르기 필터
    filtered = [doc for doc, dist in sorted_docs
                if dist <= SIMILARITY_THRESHOLD and not _has_allergen(doc)]

    # 2차: 임계값 완화 fallback (알레르기 필터는 유지)
    if len(filtered) < k:
        extra = [doc for doc, _ in sorted_docs
                 if doc not in filtered and not _has_allergen(doc)]
        filtered += extra[:k - len(filtered)]

    # ── 3단계: 키워드 매칭 결과를 앞에 배치 후 임베딩 결과 보충 ──
    merged: list[str] = []
    seen: set[str] = set()
    for doc in keyword_docs + filtered:
        if doc not in seen:
            merged.append(doc)
            seen.add(doc)
    filtered = merged

    # 카테고리 다양성 적용 (동일 카테고리 최대 2개)
    diverse = _diversify_docs(filtered, max_per_category=2)
    if len(diverse) < k:
        already = set(diverse)
        diverse += [d for d in filtered if d not in already][:k - len(diverse)]

    retrieved_docs = diverse[:k]
    return retrieved_docs, _format_context(retrieved_docs)



# ── 프로필 / 식단 빌더 ───────────────────────────
def _build_profile_str(user_profile: dict) -> str:
    parts = [
        f"나이 {user_profile.get('age', '미입력')}세",
        f"성별 {user_profile.get('gender', '미입력')}",
        f"키 {user_profile.get('height', '미입력')}cm",
        f"몸무게 {user_profile.get('weight', '미입력')}kg",
        f"활동량 {user_profile.get('activity_level', '미입력')}",
        f"건강 목표: {user_profile.get('goal', '일반 건강 관리')}",
    ]
    condition = user_profile.get("condition")
    parts.append(f"질환: {condition if condition else '없음'}")
    allergy = user_profile.get("allergy")
    parts.append(f"알레르기: {allergy if allergy else '없음'}")
    target = user_profile.get("target_kcal")
    if target:
        parts.append(f"목표 칼로리: {target}kcal")
    return "[사용자 정보]\n" + ", ".join(parts)


def _build_meal_status_str(
    user_profile: dict,
    meal_history: list[dict] | None,
) -> str:
    """[식단 현황] 섹션: 섭취 이력 + 남은 칼로리 계산값 포함"""
    consumed = _calc_consumed_today(meal_history)
    remaining = _calc_remaining_kcal(user_profile, meal_history)
    target = user_profile.get("target_kcal")

    lines = ["[식단 현황]"]
    if meal_history:
        for meal in meal_history:
            meal_type = meal.get("meal_type", "식사")
            foods = meal.get("foods", [])
            names = [f.get("name", "") for f in foods]
            kcal = meal.get("total_kcal", 0)
            total_carb = sum(f.get("carb_g", 0) for f in foods)
            total_protein = sum(f.get("protein_g", 0) for f in foods)
            total_fat = sum(f.get("fat_g", 0) for f in foods)
            lines.append(
                f"- {meal_type}: {', '.join(names)} ({kcal:.0f}kcal"
                + (f", 탄수화물 {total_carb:.0f}g, 단백질 {total_protein:.0f}g, 지방 {total_fat:.0f}g" if any([total_carb, total_protein, total_fat]) else "")
                + ")"
            )
        lines.append(f"- 오늘 섭취 합계: {consumed:.0f}kcal")
    else:
        lines.append("- 오늘 식단 기록 없음")

    if target:
        lines.append(f"- 하루 목표 칼로리: {float(target):.0f}kcal")
    if remaining is not None:
        lines.append(f"- 남은 칼로리: {remaining:.0f}kcal")

    return "\n".join(lines)


def _build_meal_history_str(meal_history: list[dict] | None) -> str:
    """하위 호환용 — build_prompt에서 사용"""
    if not meal_history:
        return ""
    lines = ["오늘 식단 기록:"]
    total_kcal = total_carb = total_protein = total_fat = 0.0
    for meal in meal_history:
        meal_type = meal.get("meal_type", "식사")
        foods = meal.get("foods", [])
        food_names = [f.get("name", "") for f in foods]
        kcal = meal.get("total_kcal", 0)
        total_kcal += kcal
        for f in foods:
            total_carb += f.get("carb_g", 0)
            total_protein += f.get("protein_g", 0)
            total_fat += f.get("fat_g", 0)
        lines.append(f"- {meal_type}: {', '.join(food_names)} ({kcal:.0f}kcal)")
    lines.append(
        f"- 합계: {total_kcal:.0f}kcal "
        f"(탄수화물 {total_carb:.0f}g, 단백질 {total_protein:.0f}g, 지방 {total_fat:.0f}g)"
    )
    return "\n".join(lines)


def build_messages(
    context: str,
    user_query: str,
    user_profile: dict,
    meal_history: list[dict] | None = None,
) -> list:
    """
    ChatOllama용 메시지 리스트 반환

    HumanMessage 구조:
      [사용자 정보] / [식단 현황] / [참고 영양 정보] / 사용자 질문
    """
    sections = [
        _build_profile_str(user_profile),
        _build_meal_status_str(user_profile, meal_history),
        f"[참고 영양 정보]\n{context}",
        f"사용자 질문: {user_query}",
    ]
    return [
        SystemMessage(content=SYSTEM_PROMPT),
        HumanMessage(content="\n\n".join(sections)),
    ]


def build_prompt(
    context: str,
    user_query: str,
    user_profile: dict,
    meal_history: list[dict] | None = None,
) -> str:
    """하위 호환용 — build_messages 사용 권장"""
    profile_str = _build_profile_str(user_profile)
    meal_str = _build_meal_history_str(meal_history)
    sections = [SYSTEM_PROMPT, profile_str]
    if meal_str:
        sections.append(meal_str)
    sections.append(f"[참고 영양 정보]\n{context}")
    sections.append(f"사용자 질문: {user_query}")
    return "\n\n".join(sections)


# ── 포스트 프로세싱 ────────────────────────────────
_THINK_TAG_RE = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)
_KCAL_RE = re.compile(r"(\d+)\s*kcal", re.IGNORECASE)
_MULTI_BLANK_RE = re.compile(r"\n{3,}")
# "**음식명**" 아티팩트 정규화:
#   패턴 A: "**음식명** 실제음식명 (칼로리: Xkcal)" → "**실제음식명** (칼로리: Xkcal)"
#   패턴 B: "**음식명** (칼로리: Xkcal)" (실제 이름 없음) → 줄 전체 제거
_ARTIFACT_LABEL_NAMES = r"(음식명|실제 음식 이름|음식 이름|식품명)"
_ARTIFACT_LABEL_RE = re.compile(
    r"\*\*" + _ARTIFACT_LABEL_NAMES + r"\*\*\s+"
    r"(?!\()"            # 바로 '('가 아닐 때만 (실제 음식명이 뒤에 있음)
    r"([^(\n]+?)\s*"     # 음식명 (괄호·줄바꿈 직전까지)
    r"(\([^\n]*)?"       # 선택: (칼로리: Xkcal) 부분
    r"(?=\n|$)",
    re.IGNORECASE,
)
_ARTIFACT_EMPTY_RE = re.compile(
    r"\*\*" + _ARTIFACT_LABEL_NAMES + r"\*\*[^\n]*\n?",
    re.IGNORECASE,
)


def _remove_format_artifacts(text: str) -> str:
    """LLM이 포맷 템플릿을 그대로 출력하는 아티팩트를 수정/제거한다."""
    def _fix_label(m: re.Match) -> str:
        food = m.group(2).strip()
        rest = (" " + m.group(3)) if m.group(3) else ""
        return f"**{food}**{rest}"

    # A: **음식명** 실제음식 (칼로리: Xkcal) → **실제음식** (칼로리: Xkcal)
    text = _ARTIFACT_LABEL_RE.sub(_fix_label, text)
    # B: 남은 **음식명** 아티팩트 줄 제거
    text = _ARTIFACT_EMPTY_RE.sub("", text)
    return text


def _strip_think_streaming(buffer: str, in_think: bool) -> tuple[str, str, bool]:
    """스트리밍 청크에서 <think> 태그를 상태 머신으로 실시간 제거"""
    output = ""
    while True:
        if not in_think:
            idx = buffer.find("<think>")
            if idx == -1:
                output += buffer
                buffer = ""
                break
            output += buffer[:idx]
            buffer = buffer[idx + 7:]
            in_think = True
        else:
            idx = buffer.find("</think>")
            if idx == -1:
                buffer = ""
                break
            buffer = buffer[idx + 8:]
            in_think = False
    return output, buffer, in_think


def _validate_kcal(answer: str, remaining_kcal: float | None = None) -> str:
    """
    칼로리 유효성 검사:
    - 절대값: 1~49kcal(영양성분 표기의 0은 제외) 또는 2000kcal 초과 → ⚠️
    - 남은 칼로리 기준: remaining_kcal의 120% 초과 → ⚠️(남은 칼로리 초과)
    """
    def _mark(m: re.Match) -> str:
        val = int(m.group(1))
        if val == 0:
            return m.group(0)  # 영양성분 표기의 0kcal은 무시
        if val < 50 or val > 2000:
            return f"{val}kcal ⚠️"
        if remaining_kcal is not None and val > remaining_kcal * 1.2:
            return f"{val}kcal ⚠️(남은 {remaining_kcal:.0f}kcal 초과)"
        return m.group(0)
    return _KCAL_RE.sub(_mark, answer)


def _build_allergen_warning(answer: str, allergens: list[str]) -> str:
    """
    **음식명** 라인만 검사하여 알레르기 경고 반환
    코칭 메시지에서 알레르기를 언급하는 것은 정상이므로 제외
    """
    name_lines = " ".join(
        line for line in answer.split("\n")
        if line.strip().startswith("**")
    )
    found = list(dict.fromkeys(kw for kw in allergens if kw in name_lines))
    if not found:
        return ""
    return f"> ⚠️ **알레르기 주의**: 추천 내용에 '{', '.join(found)}' 성분이 포함될 수 있습니다. 섭취 전 반드시 확인하세요."


def post_process(
    answer: str,
    user_profile: dict,
    remaining_kcal: float | None = None,
) -> str:
    """
    LLM 응답 후처리:
    1. <think> 태그 제거 (Qwen3 CoT 잔여물)
    2. 칼로리 유효성 검사 (절대값 + 남은 칼로리 기준)
    3. 알레르기 성분 언급 시 상단 경고 삽입
    4. 과도한 빈 줄 정규화
    """
    answer = _THINK_TAG_RE.sub("", answer).strip()
    answer = _remove_format_artifacts(answer)
    answer = _validate_kcal(answer, remaining_kcal)

    allergens = _extract_allergens(user_profile)
    warning = _build_allergen_warning(answer, allergens)
    if warning:
        answer = warning + "\n\n" + answer

    answer = _MULTI_BLANK_RE.sub("\n\n", answer).strip()
    return answer


# ── 메인 RAG 함수 ─────────────────────────────────
def get_recommendation(
    user_query: str,
    user_profile: dict,
    detected_foods: list[str] | None = None,
    meal_history: list[dict] | None = None,
    k: int = 5,
) -> dict:
    """
    RAG 기반 식단 추천

    Args:
        user_query: 사용자 질문
        user_profile: 사용자 건강 정보
        detected_foods: YOLO로 인식된 음식 목록
        meal_history: 오늘 식단 이력
        k: 최종 사용 문서 수

    Returns:
        {"answer": str, "sources": list[str], "detected_foods": list}

    파이프라인:
        전처리(의도·시간대 감지, 쿼리 재작성, 남은 칼로리 계산)
        → 다중 쿼리 RAG 검색
        → 구조화 컨텍스트 조합 ([사용자 정보] / [식단 현황] / [참고 영양 정보])
        → LLM 생성
        → 후처리(think 제거, 칼로리 검증, 알레르기 이중 확인)
    """
    # 전처리
    remaining_kcal = _calc_remaining_kcal(user_profile, meal_history)
    meal_time = _detect_meal_time(user_query)
    queries = _rewrite_queries(user_query, user_profile, detected_foods, remaining_kcal, meal_time)

    # 다중 쿼리 검색
    retrieved_docs, context = _retrieve_multi(queries, user_profile, k)

    # 직접 영양 질문 감지 → LLM 우회, 즉시 답변
    if _NUTRITION_QUESTION_RE.search(user_query):
        for kw in _extract_food_keywords(user_query):
            direct = _build_direct_nutrition_answer(kw, retrieved_docs)
            if direct:
                return {
                    "answer": direct,
                    "sources": [doc[:80] + "..." for doc in retrieved_docs[:1]],
                    "detected_foods": detected_foods or [],
                }

    # LLM 입력 구성 (구조화된 섹션)
    messages = build_messages(context, user_query, user_profile, meal_history=meal_history)

    llm = _get_llm()
    try:
        response = llm.invoke(messages)
        answer = response.content
    except Exception as e:
        raise RuntimeError(f"LLM 응답 실패 (Ollama 서버 확인 필요): {e}")

    # 후처리
    answer = post_process(answer, user_profile, remaining_kcal=remaining_kcal)

    return {
        "answer": answer,
        "sources": [doc[:80] + "..." for doc in retrieved_docs],
        "detected_foods": detected_foods or [],
    }


def _preprocess_query(
    user_query: str,
    user_profile: dict,
    detected_foods: list[str] | None,
    meal_history: list[dict] | None,
) -> tuple[float | None, str, list[str]]:
    """쿼리 전처리: 남은 칼로리 계산 → 시간대 감지 → 다중 쿼리 재작성"""
    remaining_kcal = _calc_remaining_kcal(user_profile, meal_history)
    meal_time = _detect_meal_time(user_query)
    queries = _rewrite_queries(user_query, user_profile, detected_foods, remaining_kcal, meal_time)
    return remaining_kcal, meal_time, queries


def _stream_ollama_raw(messages: list):
    """Ollama /api/chat 스트리밍 호출. <think> 태그를 실시간 제거하며 yield.

    Returns (generator, collected_chunks_list) — 호출자가 next()로 소비하며
    clean_chunks 리스트에 출력된 텍스트가 누적됨.
    실제로는 generator 함수이므로 yield 방식으로 사용.
    """
    import json as _json
    import requests as _req

    payload = {
        "model": LLM_MODEL,
        "stream": True,
        "think": False,
        "options": {"temperature": 0.6, "num_predict": 2048},
        "messages": [
            {
                "role": "user" if m.__class__.__name__ == "HumanMessage" else "system",
                "content": m.content,
            }
            for m in messages
        ],
    }

    buffer = ""
    in_think = False

    try:
        with _req.post(f"{OLLAMA_BASE_URL}/api/chat", json=payload, stream=True, timeout=120) as r:
            for line in r.iter_lines():
                if not line:
                    continue
                data = _json.loads(line)
                text = data.get("message", {}).get("content", "")
                if text:
                    buffer += text
                    output, buffer, in_think = _strip_think_streaming(buffer, in_think)
                    if output:
                        yield output
                if data.get("done"):
                    if buffer and not in_think:
                        yield buffer
                    break
    except Exception as e:
        yield f"\n\n[오류] LLM 응답 실패: {e}"


def stream_recommendation(
    user_query: str,
    user_profile: dict,
    detected_foods: list[str] | None = None,
    meal_history: list[dict] | None = None,
    k: int = 5,
):
    """
    스트리밍 버전 오케스트레이터.

    전처리 → 검색 → 생성(_stream_ollama_raw) → 후처리 경고 yield
    """
    remaining_kcal, _, queries = _preprocess_query(
        user_query, user_profile, detected_foods, meal_history
    )

    retrieved_docs, context = _retrieve_multi(queries, user_profile, k)

    # 직접 영양 질문 → LLM 우회, 즉시 yield
    if _NUTRITION_QUESTION_RE.search(user_query):
        for kw in _extract_food_keywords(user_query):
            direct = _build_direct_nutrition_answer(kw, retrieved_docs)
            if direct:
                yield direct
                return

    messages = build_messages(context, user_query, user_profile, meal_history=meal_history)

    raw_chunks: list[str] = []
    for chunk in _stream_ollama_raw(messages):
        raw_chunks.append(chunk)

    # 아티팩트 제거 후 스트리밍 (청크 단위 yield는 완성 텍스트 기준)
    full_response = _remove_format_artifacts("".join(raw_chunks))
    yield full_response

    allergens = _extract_allergens(user_profile)
    allergen_warning = _build_allergen_warning(full_response, allergens)
    if allergen_warning:
        yield "\n\n" + allergen_warning

    kcal_warnings = [
        f"{int(m.group(1))}kcal"
        for m in _KCAL_RE.finditer(full_response)
        if int(m.group(1)) != 0 and (
            int(m.group(1)) < 50 or int(m.group(1)) > 2000
            or (remaining_kcal is not None and int(m.group(1)) > remaining_kcal * 1.2)
        )
    ]
    if kcal_warnings:
        yield (
            f"\n\n> ⚠️ 일부 칼로리 정보({', '.join(kcal_warnings)})가 "
            "목표 범위를 벗어납니다. 참고용으로만 활용하세요."
        )
