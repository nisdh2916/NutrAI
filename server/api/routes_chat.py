from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ai.rag_engine import get_recommendation

router = APIRouter(prefix="/chat", tags=["chat"])


class UserProfile(BaseModel):
    age: int | None = None
    height: float | None = None
    weight: float | None = None
    goal: str = "일반 건강 관리"       # 다이어트, 근육 증가, 당뇨 관리 등
    condition: str | None = None       # 당뇨, 고혈압, 없음
    allergy: str | None = None


class ChatRequest(BaseModel):
    message: str
    user_profile: UserProfile = UserProfile()
    detected_foods: list[str] = []     # YOLO 인식 결과


class ChatResponse(BaseModel):
    answer: str
    sources: list[str]
    detected_foods: list[str]


@router.post("", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    try:
        result = get_recommendation(
            user_query=req.message,
            user_profile=req.user_profile.model_dump(exclude_none=False),
            detected_foods=req.detected_foods or None,
        )
        return ChatResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
