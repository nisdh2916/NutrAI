"""Development-only FastAPI app for testing NutrAI chat routes.

Run:
    python -m uvicorn server.dev_chat_only:app --reload --port 8001
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from server.api.routes_chat import router as chat_router


app = FastAPI(title="NutrAI Chat API", version="0.1.0-dev")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(chat_router)


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "NutrAI chat-only development API"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "chat-only"}
