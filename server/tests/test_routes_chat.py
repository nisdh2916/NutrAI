"""POST /chat 및 POST /chat/stream 엔드포인트 테스트."""
from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from fastapi.testclient import TestClient
from server.main import app

client = TestClient(app, raise_server_exceptions=True)

_CHAT_PAYLOAD = {
    "message": "점심으로 뭐 먹을까요?",
    "user_profile": {"age": 25, "gender": "여", "goal": "다이어트"},
    "detected_foods": [],
    "meal_history": [],
}

_RAG_RESULT = {
    "answer": "닭가슴살 샐러드를 추천드려요.",
    "sources": ["닭가슴살 | 칼로리 165kcal"],
    "detected_foods": [],
}


class TestChatEndpoint:
    def test_returns_503_when_no_rag(self):
        with patch("server.api.routes_chat.run_in_threadpool", side_effect=ImportError("no rag")):
            res = client.post("/chat", json=_CHAT_PAYLOAD)
        assert res.status_code == 503

    def test_returns_200_with_mocked_rag(self):
        with patch("server.api.routes_chat.run_in_threadpool", return_value=_RAG_RESULT):
            res = client.post("/chat", json=_CHAT_PAYLOAD)
        assert res.status_code == 200

    def test_response_has_answer(self):
        with patch("server.api.routes_chat.run_in_threadpool", return_value=_RAG_RESULT):
            data = client.post("/chat", json=_CHAT_PAYLOAD).json()
        assert data["answer"] == _RAG_RESULT["answer"]

    def test_response_has_sources_list(self):
        with patch("server.api.routes_chat.run_in_threadpool", return_value=_RAG_RESULT):
            data = client.post("/chat", json=_CHAT_PAYLOAD).json()
        assert isinstance(data["sources"], list)

    def test_response_has_detected_foods(self):
        with patch("server.api.routes_chat.run_in_threadpool", return_value=_RAG_RESULT):
            data = client.post("/chat", json=_CHAT_PAYLOAD).json()
        assert isinstance(data["detected_foods"], list)

    def test_missing_message_rejected(self):
        res = client.post("/chat", json={})
        assert res.status_code == 422

    def test_runtime_error_returns_503(self):
        with patch("server.api.routes_chat.run_in_threadpool", side_effect=RuntimeError("model offline")):
            res = client.post("/chat", json=_CHAT_PAYLOAD)
        assert res.status_code == 503

    def test_minimal_payload_ok(self):
        with patch("server.api.routes_chat.run_in_threadpool", return_value=_RAG_RESULT):
            res = client.post("/chat", json={"message": "안녕"})
        assert res.status_code == 200


class TestChatStream:
    def test_stream_returns_200(self):
        with patch("server.api.routes_chat.run_in_threadpool"):
            res = client.post("/chat/stream", json=_CHAT_PAYLOAD)
        assert res.status_code == 200

    def test_stream_content_type_is_event_stream(self):
        with patch("server.api.routes_chat.run_in_threadpool"):
            res = client.post("/chat/stream", json=_CHAT_PAYLOAD)
        assert "text/event-stream" in res.headers.get("content-type", "")
