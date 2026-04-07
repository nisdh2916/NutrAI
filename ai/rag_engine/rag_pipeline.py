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
LLM_MODEL = "qwen2.5:7b"         # 답변 생성용

_embed_model: SentenceTransformer | None = None
_collection = None


def _get_embed_model() -> SentenceTransformer:
    global _embed_model
    if _embed_model is None:
        import torch
        device = "cuda" if torch.cuda.is_available() else "cpu"
        _embed_model = SentenceTransformer(EMBED_MODEL, device=device)
    return _embed_model


def get_collection():
    global _collection
    if _collection is None:
        client = chromadb.PersistentClient(path=str(CHROMA_DIR))
        _collection = client.get_collection("nutrition")
    return _collection


# ── 프롬프트 템플릿 ───────────────────────────────────
SYSTEM_PROMPT = """당신은 NutrAI의 전문 영양 코치입니다.
반드시 한국어로만 답변하세요. 영어나 중국어로 절대 답변하지 마세요.
사용자의 건강 목표와 현재 식단을 분석하여 근거 있는 맞춤형 식단 추천을 제공합니다.

아래 영양 정보를 참고하여 답변하세요:
{context}

답변 형식:
1. 추천 메뉴 3~5개 (각 메뉴명, 예상 칼로리, 추천 이유)
2. 코칭 메시지 (1~2문장)
3. 주의사항 (해당 시)
"""


def build_prompt(context: str, user_query: str, user_profile: dict) -> str:
    profile_str = (
        f"사용자 정보: 나이 {user_profile.get('age', '미입력')}세, "
        f"키 {user_profile.get('height', '미입력')}cm, "
        f"몸무게 {user_profile.get('weight', '미입력')}kg, "
        f"건강 목표: {user_profile.get('goal', '일반 건강 관리')}, "
        f"질환: {user_profile.get('condition', '없음')}, "
        f"알레르기: {user_profile.get('allergy', '없음')}"
    )
    return f"{SYSTEM_PROMPT.format(context=context)}\n\n{profile_str}\n\n사용자 질문: {user_query}"


# ── 메인 RAG 함수 ─────────────────────────────────────
def get_recommendation(
    user_query: str,
    user_profile: dict,
    detected_foods: list[str] | None = None,
    k: int = 5,
) -> dict:
    """
    RAG 기반 식단 추천

    Args:
        user_query: 사용자 질문 ("오늘 점심 뭐 먹을까요?")
        user_profile: 사용자 건강 정보
        detected_foods: YOLO로 인식된 음식 목록
        k: 검색할 문서 수

    Returns:
        {"answer": str, "sources": list[str], "detected_foods": list}
    """
    # 검색 쿼리 구성 (인식된 음식 + 사용자 질문)
    search_query = user_query
    if detected_foods:
        search_query = f"{', '.join(detected_foods)} {user_query}"
    if user_profile.get("condition"):
        search_query += f" {user_profile['condition']}"

    embed_model = _get_embed_model()
    query_embedding = embed_model.encode(search_query, convert_to_numpy=True).tolist()

    collection = get_collection()
    results = collection.query(query_embeddings=[query_embedding], n_results=k)

    retrieved_docs = results["documents"][0] if results["documents"] else []
    context = "\n".join(retrieved_docs)

    prompt = build_prompt(context, user_query, user_profile)

    llm = OllamaLLM(
        model=LLM_MODEL,
        base_url=OLLAMA_BASE_URL,
        temperature=0.3,
    )
    answer = llm.invoke(prompt)

    return {
        "answer": answer,
        "sources": [doc[:80] + "..." for doc in retrieved_docs],
        "detected_foods": detected_foods or [],
    }
