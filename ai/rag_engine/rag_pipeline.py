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

CHROMA_DIR = Path(__file__).parent / "chroma_db"
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"
LLM_MODEL = "qwen3:8b"

# 정규화된 L2 거리 임계값: sqrt(2*(1-cos)) 기준, 1.0 ≈ cosine 유사도 0.5
SIMILARITY_THRESHOLD = 1.0
FETCH_MULTIPLIER = 2  # 쿼리당 k*2개 후보 검색 (다중 쿼리이므로 1개당 multiplier 줄임)

_embed_model: SentenceTransformer | None = None
_collection = None
_llm: ChatOllama | None = None


# ── 알레르기 키워드 매핑 ────────────────────────────
_ALLERGEN_KEYWORDS: dict[str, list[str]] = {
    "유제품": ["우유", "치즈", "버터", "요거트", "크림", "유청", "밀크", "라떼", "카푸치노", "아이스크림"],
    "견과류": ["아몬드", "호두", "캐슈", "땅콩", "잣", "피스타치오", "마카다미아", "헤이즐넛", "피넛", "견과"],
    "갑각류": ["새우", "게", "랍스터", "크랩", "대게"],
    "밀":    ["빵", "파스타", "면", "국수", "라면", "우동", "스파게티", "밀가루", "만두", "냉면", "소면"],
    "글루텐": ["빵", "파스타", "면", "국수", "라면", "우동", "밀가루"],
    "계란":  ["계란", "달걀", "에그", "오믈렛", "마요네즈"],
    "대두":  ["두부", "된장", "간장", "두유", "콩국수", "낫토", "청국장"],
    "복숭아": ["복숭아", "피치"],
    "토마토": ["토마토", "케첩"],
    "고등어": ["고등어"],
    "조개류": ["조개", "홍합", "굴", "전복", "바지락", "오징어", "낙지", "문어"],
}

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
            model=LLM_MODEL,
            base_url=OLLAMA_BASE_URL,
            temperature=0.3,
            num_predict=2048,
            think=False,
            keep_alive="1h",
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
음식명은 일반 음식명만 사용하고 브랜드명·제품명·가공식품은 사용하지 마세요.
의료적 확정 표현은 사용하지 말고 권고 표현을 사용하세요.
수치 계산(칼로리, 남은 열량)은 반드시 [식단 현황]의 수치를 그대로 사용하고 임의로 계산하지 마세요.

반드시 아래 형식으로 추천 메뉴 3개와 코칭 메시지를 답변하세요:

**음식명** (칼로리: Xkcal)
추천 이유: 설명 1~2문장

코칭 메시지: 전체 식단 조언 1~2문장"""


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


def _rewrite_queries(
    user_query: str,
    user_profile: dict,
    detected_foods: list[str] | None,
    remaining_kcal: float | None,
    meal_time: str,
) -> list[str]:
    """
    다중 검색 쿼리 재작성 (최대 4개)

    1. 기본 시간대 쿼리
    2. 목표 + 시간대
    3. 칼로리 제약 조건
    4. 질환/감지 음식 연계
    """
    queries: list[str] = []
    goal = user_profile.get("goal", "")
    condition = user_profile.get("condition", "")

    # 1. 기본 쿼리: 시간대가 있으면 시간대 중심, 없으면 원문
    base = f"{meal_time} 메뉴 추천" if meal_time else user_query
    queries.append(base)

    # 2. 목표 + 시간대
    if goal and goal not in ("일반 건강 관리", ""):
        queries.append(f"{goal} {meal_time} 메뉴" if meal_time else f"{goal} 맞춤 메뉴")

    # 3. 남은 칼로리 기반 제약 쿼리
    if remaining_kcal is not None:
        queries.append(f"{int(remaining_kcal)}kcal 이하 {meal_time} 식사" if meal_time
                       else f"{int(remaining_kcal)}kcal 이하 메뉴")

    # 4. 질환 맞춤 or 감지 음식 연계
    if condition and len(queries) < 4:
        queries.append(f"{condition} {meal_time} 식단" if meal_time else f"{condition} 맞춤 식단")
    elif detected_foods and len(queries) < 4:
        foods_str = " ".join(detected_foods[:2])
        queries.append(f"{foods_str} 후 {meal_time} 균형 식단" if meal_time else f"{foods_str} 균형 식단")

    return queries[:4]


# ── 알레르기 유틸 ─────────────────────────────────
def _extract_allergens(user_profile: dict) -> list[str]:
    """알레르기 카테고리 → 실제 식재료 키워드 변환"""
    raw = user_profile.get("allergy", "") or ""
    categories = [a.strip() for a in raw.replace("，", ",").split(",")
                  if a.strip() and a.strip() != "없음"]
    keywords: list[str] = []
    for cat in categories:
        keywords.extend(_ALLERGEN_KEYWORDS.get(cat, [cat]))
    return list(dict.fromkeys(keywords))


# ── 컨텍스트 포맷 ─────────────────────────────────
def _format_context(docs: list[str]) -> str:
    if not docs:
        return "관련 영양 정보를 찾지 못했습니다."
    return "\n".join(f"{i}. {doc.replace('|', ', ')}" for i, doc in enumerate(docs, 1))


# ── 핵심 검색 로직 ────────────────────────────────
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

    # 쿼리별 검색 → 문서별 최고 유사도(최솟값) 보존
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

    retrieved_docs = filtered[:k]
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
    - 절대값: 50kcal 미만 또는 2000kcal 초과 → ⚠️
    - 남은 칼로리 기준: remaining_kcal의 120% 초과 → ⚠️(남은 칼로리 초과)
    """
    def _mark(m: re.Match) -> str:
        val = int(m.group(1))
        if val < 50 or val > 2000:
            return f"{val}kcal ⚠️"
        if remaining_kcal is not None and val > remaining_kcal * 1.2:
            return f"{val}kcal ⚠️(남은 {remaining_kcal:.0f}kcal 초과)"
        return m.group(0)
    return _KCAL_RE.sub(_mark, answer)


def _build_allergen_warning(answer: str, allergens: list[str]) -> str:
    """응답 텍스트에 알레르기 키워드가 포함되면 경고 문자열 반환, 없으면 빈 문자열"""
    found = list(dict.fromkeys(kw for kw in allergens if kw in answer))
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


def stream_recommendation(
    user_query: str,
    user_profile: dict,
    detected_foods: list[str] | None = None,
    meal_history: list[dict] | None = None,
    k: int = 5,
):
    """
    스트리밍 버전

    - 스트리밍 중: <think> 태그 상태 머신으로 실시간 제거 후 yield
    - 스트리밍 완료 후: 알레르기 경고 / 칼로리 이상 경고를 추가 yield
    """
    # 전처리
    remaining_kcal = _calc_remaining_kcal(user_profile, meal_history)
    meal_time = _detect_meal_time(user_query)
    queries = _rewrite_queries(user_query, user_profile, detected_foods, remaining_kcal, meal_time)

    # 다중 쿼리 검색
    _, context = _retrieve_multi(queries, user_profile, k)
    messages = build_messages(context, user_query, user_profile, meal_history=meal_history)

    import json as _json
    import requests as _req

    payload = {
        "model": LLM_MODEL,
        "stream": True,
        "think": False,
        "options": {"temperature": 0.3, "num_predict": 2048},
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
    clean_chunks: list[str] = []

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
                        clean_chunks.append(output)
                        yield output
                if data.get("done"):
                    if buffer and not in_think:
                        clean_chunks.append(buffer)
                        yield buffer
                    break
    except Exception as e:
        yield f"\n\n[오류] LLM 응답 실패: {e}"
        return

    # 스트리밍 완료 후 후처리 경고 yield
    full_response = "".join(clean_chunks)
    allergens = _extract_allergens(user_profile)
    allergen_warning = _build_allergen_warning(full_response, allergens)
    if allergen_warning:
        yield "\n\n" + allergen_warning

    kcal_warnings = [
        f"{int(m.group(1))}kcal"
        for m in _KCAL_RE.finditer(full_response)
        if int(m.group(1)) < 50 or int(m.group(1)) > 2000
        or (remaining_kcal is not None and int(m.group(1)) > remaining_kcal * 1.2)
    ]
    if kcal_warnings:
        yield (
            f"\n\n> ⚠️ 일부 칼로리 정보({', '.join(kcal_warnings)})가 "
            "목표 범위를 벗어납니다. 참고용으로만 활용하세요."
        )
