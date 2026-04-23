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
FETCH_MULTIPLIER = 4  # k*4 후보 검색 후 필터링

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


# ── 프롬프트 템플릿 ───────────────────────────────────
SYSTEM_PROMPT = """한국어로만 답변하는 NutrAI 영양 코치입니다.
반드시 아래 [참고 영양 정보]에 있는 식품 데이터를 바탕으로 추천하세요. 목록에 없는 음식은 추천하지 마세요.
알레르기 성분이 포함된 음식은 절대 추천하지 마세요.
질환이 있으면 해당 질환에 적합한 식단을 최우선으로 고려하세요.
음식명은 일반 음식명(김치찌개, 된장찌개 등)만 사용하고 브랜드명·제품명·가공식품은 절대 사용하지 마세요.

[참고 영양 정보]
{context}

반드시 아래 형식으로 추천 메뉴 3개와 코칭 메시지를 답변하세요:

**음식명** (칼로리: Xkcal)
추천 이유: 설명 1~2문장

코칭 메시지: 전체 식단 조언 1~2문장"""


# ── 쿼리 / 알레르기 유틸 ─────────────────────────────
def _build_search_query(
    user_query: str,
    user_profile: dict,
    detected_foods: list[str] | None,
) -> str:
    """임베딩에 최적화된 짧고 명확한 검색 쿼리 구성"""
    keywords: list[str] = []
    if detected_foods:
        keywords.extend(detected_foods[:3])
    condition = user_profile.get("condition", "")
    if condition:
        keywords.append(condition)
    goal = user_profile.get("goal", "")
    if goal and goal not in ("일반 건강 관리", ""):
        keywords.append(goal)
    return " ".join(keywords) if keywords else user_query


def _extract_allergens(user_profile: dict) -> list[str]:
    """사용자 알레르기 항목을 실제 검색 키워드 목록으로 변환"""
    raw = user_profile.get("allergy", "") or ""
    categories = [a.strip() for a in raw.replace("，", ",").split(",") if a.strip() and a.strip() != "없음"]
    keywords: list[str] = []
    for cat in categories:
        keywords.extend(_ALLERGEN_KEYWORDS.get(cat, [cat]))
    return list(dict.fromkeys(keywords))  # 중복 제거, 순서 유지


# ── 컨텍스트 포맷 ─────────────────────────────────────
def _format_context(docs: list[str]) -> str:
    """검색 문서를 LLM이 이해하기 쉬운 번호 목록으로 포맷"""
    if not docs:
        return "관련 영양 정보를 찾지 못했습니다."
    return "\n".join(f"{i}. {doc.replace('|', ', ')}" for i, doc in enumerate(docs, 1))


# ── 공통 검색 로직 ────────────────────────────────────
def _retrieve(
    user_query: str,
    user_profile: dict,
    detected_foods: list[str] | None,
    k: int,
) -> tuple[list[str], str]:
    """
    1. 최적화된 쿼리 구성
    2. k*FETCH_MULTIPLIER 후보 검색
    3. 유사도 임계값 필터 (SIMILARITY_THRESHOLD 이하만 유지)
    4. 알레르기 키워드 포함 문서 제거
    5. 상위 k개 선택 → 포맷
    임계값 통과 문서가 k보다 적으면 임계값 완화 fallback으로 채움
    """
    search_query = _build_search_query(user_query, user_profile, detected_foods)

    embed_model = _get_embed_model()
    query_embedding = embed_model.encode(search_query, convert_to_numpy=True).tolist()

    collection = get_collection()
    n_fetch = min(k * FETCH_MULTIPLIER, collection.count())
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=n_fetch,
        include=["documents", "distances"],
    )

    raw_docs: list[str] = results["documents"][0] if results["documents"] else []
    distances: list[float] = results["distances"][0] if results["distances"] else []
    allergens = _extract_allergens(user_profile)

    def _has_allergen(doc: str) -> bool:
        return bool(allergens) and any(kw in doc for kw in allergens)

    # 1차: 유사도 임계값 + 알레르기 필터
    filtered = [
        doc for doc, dist in zip(raw_docs, distances)
        if dist <= SIMILARITY_THRESHOLD and not _has_allergen(doc)
    ]

    # 2차: 임계값 통과 문서가 부족하면 알레르기 필터만 적용한 fallback으로 채우기
    if len(filtered) < k:
        seen = set(filtered)
        fallback = [
            doc for doc in raw_docs
            if doc not in seen and not _has_allergen(doc)
        ]
        filtered += fallback[:k - len(filtered)]

    retrieved_docs = filtered[:k]
    return retrieved_docs, _format_context(retrieved_docs)


# ── 포스트 프로세싱 ────────────────────────────────────
_THINK_TAG_RE = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)
_KCAL_RE = re.compile(r"(\d+)\s*kcal", re.IGNORECASE)
_MULTI_BLANK_RE = re.compile(r"\n{3,}")


def _strip_think_streaming(buffer: str, in_think: bool) -> tuple[str, str, bool]:
    """스트리밍 청크에서 <think> 태그를 상태 머신으로 제거"""
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
                buffer = ""  # think 블록 내용은 버림
                break
            buffer = buffer[idx + 8:]
            in_think = False
    return output, buffer, in_think


def _validate_kcal(answer: str) -> str:
    """비현실적 칼로리(50kcal 미만 또는 2000kcal 초과) 항목에 경고 마크 추가"""
    def _mark(m: re.Match) -> str:
        val = int(m.group(1))
        return f"{val}kcal ⚠️" if val < 50 or val > 2000 else m.group(0)
    return _KCAL_RE.sub(_mark, answer)


def _build_allergen_warning(answer: str, allergens: list[str]) -> str:
    """응답 텍스트에 알레르기 키워드가 포함되어 있으면 경고 문자열 반환, 없으면 빈 문자열"""
    found = list(dict.fromkeys(kw for kw in allergens if kw in answer))
    if not found:
        return ""
    return f"> ⚠️ **알레르기 주의**: 추천 내용에 '{', '.join(found)}' 성분이 포함될 수 있습니다. 섭취 전 반드시 확인하세요."


def post_process(answer: str, user_profile: dict) -> str:
    """
    LLM 응답 후처리:
    1. <think> 태그 제거 (Qwen3 CoT 잔여물)
    2. 비현실적 칼로리 경고 마크
    3. 알레르기 성분 언급 시 상단 경고 삽입
    4. 과도한 빈 줄 정규화
    """
    answer = _THINK_TAG_RE.sub("", answer).strip()
    answer = _validate_kcal(answer)

    allergens = _extract_allergens(user_profile)
    warning = _build_allergen_warning(answer, allergens)
    if warning:
        answer = warning + "\n\n" + answer

    answer = _MULTI_BLANK_RE.sub("\n\n", answer).strip()
    return answer


# ── 프로필 / 식단 이력 빌더 ──────────────────────────
def _build_profile_str(user_profile: dict) -> str:
    parts = [
        f"나이 {user_profile.get('age', '미입력')}세",
        f"성별 {user_profile.get('gender', '미입력')}",
        f"키 {user_profile.get('height', '미입력')}cm",
        f"몸무게 {user_profile.get('weight', '미입력')}kg",
        f"활동량 {user_profile.get('activity_level', '미입력')}",
        f"건강 목표: {user_profile.get('goal', '일반 건강 관리')}",
    ]
    target = user_profile.get("target_kcal")
    if target:
        parts.append(f"목표 칼로리: {target}kcal")
    condition = user_profile.get("condition")
    parts.append(f"질환: {condition if condition else '없음'}")
    allergy = user_profile.get("allergy")
    parts.append(f"알레르기: {allergy if allergy else '없음'}")
    return "사용자 정보: " + ", ".join(parts)


def _build_meal_history_str(meal_history: list[dict] | None) -> str:
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
    """ChatOllama용 메시지 리스트 반환"""
    profile_str = _build_profile_str(user_profile)
    meal_str = _build_meal_history_str(meal_history)
    user_parts = [profile_str]
    if meal_str:
        user_parts.append(meal_str)
    user_parts.append(f"사용자 질문: {user_query}")
    return [
        SystemMessage(content=SYSTEM_PROMPT.format(context=context)),
        HumanMessage(content="\n\n".join(user_parts)),
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
    sections = [SYSTEM_PROMPT.format(context=context), profile_str]
    if meal_str:
        sections.append(meal_str)
    sections.append(f"사용자 질문: {user_query}")
    return "\n\n".join(sections)


# ── 메인 RAG 함수 ─────────────────────────────────────
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
        user_query: 사용자 질문 ("오늘 점심 뭐 먹을까요?")
        user_profile: 사용자 건강 정보
        detected_foods: YOLO로 인식된 음식 목록
        meal_history: 오늘 식단 이력
        k: 최종 사용 문서 수 (후보 k*FETCH_MULTIPLIER개 검색 후 필터링)

    Returns:
        {"answer": str, "sources": list[str], "detected_foods": list}
    """
    retrieved_docs, context = _retrieve(user_query, user_profile, detected_foods, k)
    messages = build_messages(context, user_query, user_profile, meal_history=meal_history)

    llm = _get_llm()
    try:
        response = llm.invoke(messages)
        answer = response.content
    except Exception as e:
        raise RuntimeError(f"LLM 응답 실패 (Ollama 서버 확인 필요): {e}")

    answer = post_process(answer, user_profile)

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
    - 청크 단위 yield (스트리밍 중 <think> 태그 실시간 제거)
    - 스트리밍 완료 후 알레르기 경고 / 칼로리 이상 경고를 추가 yield
    """
    _, context = _retrieve(user_query, user_profile, detected_foods, k)
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
    ]
    if kcal_warnings:
        yield (
            f"\n\n> ⚠️ 일부 칼로리 정보({', '.join(kcal_warnings)})가 비정상적입니다. "
            "참고용으로만 활용하세요."
        )
