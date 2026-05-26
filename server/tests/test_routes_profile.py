"""POST /profile/extract 및 _extract_json 유틸 테스트."""
from __future__ import annotations

import sys
import json
from pathlib import Path
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import pytest
from fastapi.testclient import TestClient
from server.main import app
from server.api.routes_profile import _extract_json

client = TestClient(app, raise_server_exceptions=True)

_PROFILE_DATA = {
    "name": "홍길동",
    "gender": "남",
    "age": 28,
    "height": 175.0,
    "weight": 70.0,
    "goal": "근육 증진",
    "activity_level": "높음",
    "allergy": None,
    "condition": None,
    "reply": "모든 정보를 확인했어요!",
}

_MESSAGES = [
    {"role": "user", "text": "안녕하세요, 저는 홍길동이에요."},
    {"role": "bot", "text": "반갑습니다! 나이가 어떻게 되시나요?"},
    {"role": "user", "text": "28살이고 키 175, 몸무게 70kg이에요."},
]


class TestExtractJson:
    def test_plain_json_object(self):
        raw = '{"name": "test", "age": 25}'
        assert _extract_json(raw) == {"name": "test", "age": 25}

    def test_json_in_markdown_code_block(self):
        raw = '```json\n{"name": "test"}\n```'
        assert _extract_json(raw) == {"name": "test"}

    def test_json_embedded_in_text(self):
        raw = '여기 결과입니다: {"name": "홍길동", "age": 28} 감사합니다.'
        result = _extract_json(raw)
        assert result["name"] == "홍길동"

    def test_raises_when_no_json(self):
        with pytest.raises((ValueError, json.JSONDecodeError)):
            _extract_json("JSON이 없는 텍스트입니다.")

    def test_nested_json(self):
        raw = '{"profile": {"age": 25}, "reply": "ok"}'
        result = _extract_json(raw)
        assert result["profile"]["age"] == 25


class TestProfileExtract:
    def _mock_module(self, raw=None):
        """langchain_ollama 모듈 전체를 mock으로 교체."""
        raw = raw or json.dumps(_PROFILE_DATA)
        mock_instance = MagicMock()
        mock_instance.invoke.return_value = raw
        mock_module = MagicMock()
        mock_module.OllamaLLM.return_value = mock_instance
        return mock_module

    def test_returns_503_when_no_ollama(self):
        with patch.dict("sys.modules", {"langchain_ollama": None}):
            res = client.post("/profile/extract", json={"messages": _MESSAGES})
        assert res.status_code == 503

    def test_returns_200_with_mocked_llm(self):
        with patch.dict("sys.modules", {"langchain_ollama": self._mock_module()}):
            res = client.post("/profile/extract", json={"messages": _MESSAGES})
        assert res.status_code == 200

    def test_response_has_name(self):
        with patch.dict("sys.modules", {"langchain_ollama": self._mock_module()}):
            data = client.post("/profile/extract", json={"messages": _MESSAGES}).json()
        assert data["name"] == "홍길동"

    def test_response_has_reply(self):
        with patch.dict("sys.modules", {"langchain_ollama": self._mock_module()}):
            data = client.post("/profile/extract", json={"messages": _MESSAGES}).json()
        assert "reply" in data

    def test_null_fields_allowed(self):
        partial = {**_PROFILE_DATA, "allergy": None, "condition": None}
        with patch.dict("sys.modules", {"langchain_ollama": self._mock_module(json.dumps(partial))}):
            res = client.post("/profile/extract", json={"messages": _MESSAGES})
        assert res.status_code == 200

    def test_empty_messages_ok(self):
        with patch.dict("sys.modules", {"langchain_ollama": self._mock_module()}):
            res = client.post("/profile/extract", json={"messages": []})
        assert res.status_code == 200

    def test_missing_messages_field_rejected(self):
        res = client.post("/profile/extract", json={})
        assert res.status_code == 422
