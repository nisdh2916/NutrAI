import json
import logging
import re

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from langchain_ollama import OllamaLLM
from ai.rag_engine.rag_pipeline import LLM_MODEL, OLLAMA_BASE_URL

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/profile", tags=["profile"])


class ExtractRequest(BaseModel):
    messages: list[dict]  # [{"role": "user"/"bot", "text": "..."}, ...]


class ExtractedProfile(BaseModel):
    name: str | None = None
    gender: str | None = None           # '남' or '여'
    age: int | None = None
    height: float | None = None         # cm
    weight: float | None = None         # kg
    goal: str | None = None             # '다이어트', '체중 유지', '근육 증진', '건강 관리'
    activity_level: str | None = None   # '낮음', '보통', '높음'
    allergy: str | None = None          # 쉼표 구분
    condition: str | None = None        # 쉼표 구분
    reply: str = ""                     # 챗봇 다음 응답


EXTRACT_PROMPT = """당신은 NutrAI 온보딩 챗봇입니다.
사용자와의 대화에서 아래 정보를 추출하세요. 아직 모르는 정보는 null로 두세요.

추출할 항목:
- name: 이름 (문자열)
- gender: 성별 ("남" 또는 "여")
- age: 나이 (숫자)
- height: 키 cm (숫자)
- weight: 몸무게 kg (숫자)
- goal: 건강 목표 ("다이어트", "체중 유지", "근육 증진", "건강 관리" 중 하나)
- activity_level: 활동량 ("낮음", "보통", "높음" 중 하나)
- allergy: 알레르기 (쉼표로 구분, 없으면 null)
- condition: 질환 (쉼표로 구분, 없으면 null)

규칙:
- 대화 전체를 분석하여 정보를 추출하세요
- 확실하지 않은 정보는 null로 두세요
- reply 필드에는 아직 수집하지 못한 정보를 자연스럽게 물어보는 한국어 응답을 작성하세요
- 모든 필수 정보(name, gender, age, height, weight, goal)가 수집되면 reply에 "모든 정보를 확인했어요! 입력하신 내용을 정리해볼게요."라고 작성하세요
- 반드시 아래 JSON 형식으로만 답변하세요

대화 내용:
{conversation}

JSON 형식:
{{"name": null, "gender": null, "age": null, "height": null, "weight": null, "goal": null, "activity_level": null, "allergy": null, "condition": null, "reply": "다음 질문"}}
"""


def _extract_json(text: str) -> dict:
    """LLM 응답에서 JSON 추출"""
    m = re.search(r"```(?:json)?\s*(.*?)```", text, re.DOTALL)
    if m:
        text = m.group(1)
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1:
        raise ValueError("JSON not found in LLM response")
    return json.loads(text[start:end + 1])


@router.post("/extract", response_model=ExtractedProfile)
async def extract_profile(req: ExtractRequest) -> ExtractedProfile:
    try:
        # 대화 내용을 텍스트로 변환
        conv_lines = []
        for msg in req.messages:
            role = "사용자" if msg.get("role") == "user" else "챗봇"
            conv_lines.append(f"{role}: {msg.get('text', '')}")
        conversation = "\n".join(conv_lines)

        prompt = EXTRACT_PROMPT.format(conversation=conversation)

        llm = OllamaLLM(
            model=LLM_MODEL,
            base_url=OLLAMA_BASE_URL,
            temperature=0.1,
        )
        raw = llm.invoke(prompt)
        data = _extract_json(raw)

        return ExtractedProfile(
            name=data.get("name"),
            gender=data.get("gender"),
            age=int(data["age"]) if data.get("age") is not None else None,
            height=float(data["height"]) if data.get("height") is not None else None,
            weight=float(data["weight"]) if data.get("weight") is not None else None,
            goal=data.get("goal"),
            activity_level=data.get("activity_level"),
            allergy=data.get("allergy"),
            condition=data.get("condition"),
            reply=data.get("reply", ""),
        )

    except Exception as e:
        logger.exception("프로필 추출 중 오류")
        raise HTTPException(status_code=500, detail=str(e))
