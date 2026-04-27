from __future__ import annotations

import json
import sqlite3
import uuid
from datetime import datetime
from pathlib import Path
from threading import Lock

DB_PATH = Path(__file__).with_name("nutrai_server.db")
_LOCK = Lock()


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS meals (
            meal_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            eaten_at TEXT NOT NULL,
            items_json TEXT NOT NULL,
            total_kcal REAL NOT NULL
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_meals_user_date ON meals(user_id, eaten_at)")
    return conn


def insert_meal(
    *,
    user_id: str,
    eaten_at: datetime,
    items: list[dict],
    total_kcal: float,
) -> str:
    meal_id = f"m_{uuid.uuid4().hex[:12]}"
    with _LOCK, _connect() as conn:
        conn.execute(
            """
            INSERT INTO meals (meal_id, user_id, eaten_at, items_json, total_kcal)
            VALUES (?, ?, ?, ?, ?)
            """,
            (meal_id, user_id, eaten_at.isoformat(), json.dumps(items, ensure_ascii=False), total_kcal),
        )
    return meal_id


def find_meals_by_date(*, user_id: str, date: str) -> list[dict]:
    start = f"{date}T00:00:00"
    end = f"{date}T23:59:59.999999"
    with _connect() as conn:
        rows = conn.execute(
            """
            SELECT meal_id, eaten_at, items_json, total_kcal
            FROM meals
            WHERE user_id = ? AND eaten_at BETWEEN ? AND ?
            ORDER BY eaten_at ASC
            """,
            (user_id, start, end),
        ).fetchall()

    return [
        {
            "meal_id": row["meal_id"],
            "eaten_at": datetime.fromisoformat(row["eaten_at"]),
            "items": json.loads(row["items_json"]),
            "total_kcal": row["total_kcal"],
        }
        for row in rows
    ]
