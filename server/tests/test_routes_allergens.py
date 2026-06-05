"""GET /allergens 엔드포인트 테스트."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from fastapi.testclient import TestClient

from server.main import app

client = TestClient(app, raise_server_exceptions=True)


class TestGetAllergens:
    def test_returns_200(self):
        res = client.get("/allergens")
        assert res.status_code == 200

    def test_response_has_categories_and_keywords(self):
        data = client.get("/allergens").json()
        assert "categories" in data
        assert "keywords" in data

    def test_categories_is_list(self):
        data = client.get("/allergens").json()
        assert isinstance(data["categories"], list)
        assert len(data["categories"]) > 0

    def test_keywords_is_dict(self):
        data = client.get("/allergens").json()
        assert isinstance(data["keywords"], dict)

    def test_known_categories_present(self):
        data = client.get("/allergens").json()
        for expected in ("유제품", "견과류", "갑각류", "계란", "대두"):
            assert expected in data["categories"]

    def test_categories_match_keywords_keys(self):
        data = client.get("/allergens").json()
        assert set(data["categories"]) == set(data["keywords"].keys())

    def test_each_keyword_list_nonempty(self):
        data = client.get("/allergens").json()
        for category, kws in data["keywords"].items():
            assert len(kws) > 0, f"{category} 키워드 없음"
