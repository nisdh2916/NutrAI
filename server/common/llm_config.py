"""
LLM 호출 공통 설정 (단일 출처).

Ollama 호출 파라미터를 한 곳에 모아 routes_recommend.py와
ai/rag_engine/rag_pipeline.py에서 동일한 기본값을 공유한다.
환경변수로 오버라이드 가능.
"""

from __future__ import annotations

import os
from dataclasses import dataclass


def _f(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, default))
    except (TypeError, ValueError):
        return default


def _i(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, default))
    except (TypeError, ValueError):
        return default


@dataclass(frozen=True)
class LLMSettings:
    """공통 호출 설정. 호출 종류별로 일부만 오버라이드해서 사용."""
    model: str = os.getenv("NUTRAI_LLM_MODEL", "qwen3:8b")
    base_url: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    keep_alive: str = os.getenv("NUTRAI_LLM_KEEP_ALIVE", "1h")
    timeout_s: int = _i("NUTRAI_LLM_TIMEOUT", 120)
    retries: int = _i("NUTRAI_LLM_RETRIES", 2)


# 채팅·자유형식 응답: 약간 더 창의적 (0.6)
CHAT_TEMPERATURE = _f("NUTRAI_CHAT_TEMPERATURE", 0.6)
CHAT_NUM_PREDICT = _i("NUTRAI_CHAT_NUM_PREDICT", 2048)

# JSON 추천: 결정적·구조 안정성 우선 (0.4)
JSON_TEMPERATURE = _f("NUTRAI_JSON_TEMPERATURE", 0.4)
JSON_NUM_PREDICT = _i("NUTRAI_JSON_NUM_PREDICT", 1024)

LLM = LLMSettings()
