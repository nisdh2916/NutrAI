"""
NutrAI RAG 파이프라인
- 벡터 DB: ChromaDB (로컬)
- LLM: Qwen2.5:7b via Ollama
- 프레임워크: LangChain
"""

from __future__ import annotations

import os
from pathlib import Path

import chromadb
from sentence_transformers import SentenceTransformer
from langchain_ollama import OllamaLLM

# ChromaDB 저장 경로
CHROMA_DIR = Path(__file__).parent / "chroma_db"
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"  # 한국어 특화 모델
LLM_MODEL = "gemma4:e4b"         # 답변 생성용

_embed_model: SentenceTransformer | None = None
_collection = None
_llm: OllamaLLM | None = None


def _get_embed_model() -> SentenceTransformer:
    global _embed_model
    if _embed_model is None:
        import torch
        device = "cuda" if torch.cuda.is_available() else "cpu"
        _embed_model = SentenceTransformer(EMBED_MODEL, device=device)
    return _embed_model


def _get_llm() -> OllamaLLM:
    global _llm
    if _llm is None:
        _llm = OllamaLLM(
            model=LLM_MODEL,
            base_url=OLLAMA_BASE_URL,
            temperature=0.3,
            num_predict=512,
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
알레르기 식품 추천 금지. 질환 있으면 맞는 식단 우선. 추천 메뉴명은 **메뉴명** 형식으로.

참고 영양 정보:
{context}

추천 메뉴 3개(**메뉴명**, 칼로리, 추천 이유)와 코칭 메시지를 한국어로 답변하세요."""


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
    if condition:
        parts.append(f"질환: {condition}")
    else:
        parts.append("질환: 없음")
    allergy = user_profile.get("allergy")
    if allergy:
        parts.append(f"알레르기: {allergy}")
    else:
        parts.append("알레르기: 없음")
    return "사용자 정보: " + ", ".join(parts)


def _build_meal_history_str(meal_history: list[dict] | None) -> str:
    if not meal_history:
        return ""
    lines = ["오늘 식단 기록:"]
    total_kcal = 0.0
    total_carb = 0.0
    total_protein = 0.0
    total_fat = 0.0
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
    lines.append(f"- 합계: {total_kcal:.0f}kcal (탄수화물 {total_carb:.0f}g, 단백질 {total_protein:.0f}g, 지방 {total_fat:.0f}g)")
    return "\n".join(lines)


def build_prompt(
    context: str,
    user_query: str,
    user_profile: dict,
    meal_history: list[dict] | None = None,
) -> str:
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
    k: int = 3,
) -> dict:
    """
    RAG 기반 식단 추천

    Args:
        user_query: 사용자 질문 ("오늘 점심 뭐 먹을까요?")
        user_profile: 사용자 건강 정보
        detected_foods: YOLO로 인식된 음식 목록
        meal_history: 오늘 식단 이력
        k: 검색할 문서 수

    Returns:
        {"answer": str, "sources": list[str], "detected_foods": list}
    """
    # 검색 쿼리 구성 (인식된 음식 + 사용자 질문 + 건강 목표)
    search_query = user_query
    if detected_foods:
        search_query = f"{', '.join(detected_foods)} {user_query}"
    if user_profile.get("condition"):
        search_query += f" {user_profile['condition']}"
    goal = user_profile.get("goal", "")
    if goal and goal != "일반 건강 관리":
        search_query += f" {goal}"

    embed_model = _get_embed_model()
    query_embedding = embed_model.encode(search_query, convert_to_numpy=True).tolist()

    collection = get_collection()
    results = collection.query(query_embeddings=[query_embedding], n_results=k)

    retrieved_docs = results["documents"][0] if results["documents"] else []
    cleaned_docs = [doc.replace("|", ",") for doc in retrieved_docs]
    context = "\n".join(cleaned_docs)

    prompt = build_prompt(context, user_query, user_profile, meal_history=meal_history)

    llm = _get_llm()
    try:
        answer = llm.invoke(prompt)
    except Exception as e:
        raise RuntimeError(f"LLM 응답 실패 (Ollama 서버 확인 필요): {e}")

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
    k: int = 3,
):
    """스트리밍 버전 — 청크 단위로 텍스트를 yield"""
    search_query = user_query
    if detected_foods:
        search_query = f"{', '.join(detected_foods)} {user_query}"
    if user_profile.get("condition"):
        search_query += f" {user_profile['condition']}"
    goal = user_profile.get("goal", "")
    if goal and goal != "일반 건강 관리":
        search_query += f" {goal}"

    embed_model = _get_embed_model()
    query_embedding = embed_model.encode(search_query, convert_to_numpy=True).tolist()

    collection = get_collection()
    results = collection.query(query_embeddings=[query_embedding], n_results=k)

    retrieved_docs = results["documents"][0] if results["documents"] else []
    cleaned_docs = [doc.replace("|", ",") for doc in retrieved_docs]
    context = "\n".join(cleaned_docs)
    prompt = build_prompt(context, user_query, user_profile, meal_history=meal_history)

    llm = _get_llm()
    try:
        for chunk in llm.stream(prompt):
            yield chunk
    except Exception as e:
        yield f"\n\n[오류] LLM 응답 실패: {e}"
