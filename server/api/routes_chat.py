import json
import logging
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from ai.rag_engine import get_recommendation, stream_recommendation

logger = logging.getLogger(__name__)

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
    except RuntimeError as e:
        logger.error("RAG 파이프라인 오류: %s", e)
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.exception("채팅 처리 중 예기치 않은 오류")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/stream")
async def chat_stream(req: ChatRequest):
    def generate():
        try:
            for chunk in stream_recommendation(
                user_query=req.message,
                user_profile=req.user_profile.model_dump(exclude_none=False),
                detected_foods=req.detected_foods or None,
            ):
                yield f"data: {json.dumps({'chunk': chunk}, ensure_ascii=False)}\n\n"
        except RuntimeError as e:
            logger.error("스트리밍 RAG 오류: %s", e)
            yield f"data: {json.dumps({'error': str(e)}, ensure_ascii=False)}\n\n"
        except Exception as e:
            logger.exception("스트리밍 중 예기치 않은 오류")
            yield f"data: {json.dumps({'error': '서버 내부 오류가 발생했습니다.'}, ensure_ascii=False)}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
