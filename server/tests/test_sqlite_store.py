"""server/db/sqlite_store.py 단위 테스트 — in-process SQLite."""
from __future__ import annotations

from datetime import datetime

import pytest

import server.db.sqlite_store as store


@pytest.fixture(autouse=True)
def temp_db(tmp_path, monkeypatch):
    monkeypatch.setattr(store, "DB_PATH", tmp_path / "test.db")


_ITEMS = [{"food_name": "밥", "serving": 1.0, "kcal": 300.0}]


class TestInsertMeal:
    def test_returns_meal_id_with_prefix(self):
        mid = store.insert_meal(
            user_id="u1",
            eaten_at=datetime(2024, 1, 15, 12, 0),
            items=_ITEMS,
            total_kcal=300.0,
        )
        assert mid.startswith("m_")

    def test_meal_id_unique_per_call(self):
        ids = {
            store.insert_meal(
                user_id="u1",
                eaten_at=datetime(2024, 1, 15, 12, i),
                items=_ITEMS,
                total_kcal=300.0,
            )
            for i in range(5)
        }
        assert len(ids) == 5

    def test_items_roundtrip(self):
        store.insert_meal(
            user_id="u1",
            eaten_at=datetime(2024, 1, 15, 8, 0),
            items=_ITEMS,
            total_kcal=300.0,
        )
        meals = store.find_meals_by_date(user_id="u1", date="2024-01-15")
        assert meals[0]["items"] == _ITEMS

    def test_total_kcal_roundtrip(self):
        store.insert_meal(
            user_id="u1",
            eaten_at=datetime(2024, 1, 15, 8, 0),
            items=_ITEMS,
            total_kcal=512.5,
        )
        meals = store.find_meals_by_date(user_id="u1", date="2024-01-15")
        assert meals[0]["total_kcal"] == pytest.approx(512.5)


class TestFindMealsByDate:
    def test_empty_when_no_data(self):
        result = store.find_meals_by_date(user_id="u1", date="2024-01-01")
        assert result == []

    def test_returns_only_target_date(self):
        store.insert_meal(user_id="u1", eaten_at=datetime(2024, 1, 15, 12, 0), items=_ITEMS, total_kcal=300.0)
        store.insert_meal(user_id="u1", eaten_at=datetime(2024, 1, 16, 12, 0), items=_ITEMS, total_kcal=300.0)
        result = store.find_meals_by_date(user_id="u1", date="2024-01-15")
        assert len(result) == 1

    def test_isolates_by_user(self):
        store.insert_meal(user_id="u1", eaten_at=datetime(2024, 1, 15, 12, 0), items=_ITEMS, total_kcal=300.0)
        store.insert_meal(user_id="u2", eaten_at=datetime(2024, 1, 15, 12, 0), items=_ITEMS, total_kcal=200.0)
        assert len(store.find_meals_by_date(user_id="u1", date="2024-01-15")) == 1
        assert len(store.find_meals_by_date(user_id="u2", date="2024-01-15")) == 1

    def test_multiple_meals_same_day(self):
        for hour in (8, 12, 18):
            store.insert_meal(user_id="u1", eaten_at=datetime(2024, 1, 15, hour, 0), items=_ITEMS, total_kcal=300.0)
        result = store.find_meals_by_date(user_id="u1", date="2024-01-15")
        assert len(result) == 3

    def test_result_ordered_by_eaten_at(self):
        for hour in (18, 8, 12):
            store.insert_meal(user_id="u1", eaten_at=datetime(2024, 1, 15, hour, 0), items=_ITEMS, total_kcal=300.0)
        result = store.find_meals_by_date(user_id="u1", date="2024-01-15")
        times = [r["eaten_at"].hour for r in result]
        assert times == sorted(times)

    def test_eaten_at_parsed_as_datetime(self):
        store.insert_meal(user_id="u1", eaten_at=datetime(2024, 1, 15, 9, 30), items=_ITEMS, total_kcal=100.0)
        result = store.find_meals_by_date(user_id="u1", date="2024-01-15")
        assert isinstance(result[0]["eaten_at"], datetime)

    def test_boundary_start_of_day(self):
        store.insert_meal(user_id="u1", eaten_at=datetime(2024, 1, 15, 0, 0, 0), items=_ITEMS, total_kcal=50.0)
        result = store.find_meals_by_date(user_id="u1", date="2024-01-15")
        assert len(result) == 1

    def test_boundary_end_of_day(self):
        store.insert_meal(user_id="u1", eaten_at=datetime(2024, 1, 15, 23, 59, 59), items=_ITEMS, total_kcal=50.0)
        result = store.find_meals_by_date(user_id="u1", date="2024-01-15")
        assert len(result) == 1
