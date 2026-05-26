"""GET /health 엔드포인트 테스트."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from fastapi.testclient import TestClient
from server.main import app

client = TestClient(app, raise_server_exceptions=True)


class TestGetHealth:
    def test_returns_200(self):
        assert client.get("/health").status_code == 200

    def test_status_is_ok(self):
        assert client.get("/health").json()["status"] == "ok"

    def test_version_field_present(self):
        data = client.get("/health").json()
        assert "version" in data
        assert data["version"]
