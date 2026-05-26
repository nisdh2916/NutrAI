from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from fastapi.testclient import TestClient

from server.main import app


def assert_status(response, allowed: set[int], name: str) -> None:
    if response.status_code not in allowed:
        raise AssertionError(f"{name} returned {response.status_code}: {response.text}")


def main() -> None:
    client = TestClient(app)

    assert_status(client.get("/health"), {200}, "GET /health")

    meal_payload = {
        "user_id": "smoke-user",
        "eaten_at": "2026-04-28T12:00:00+09:00",
        "items": [{"food_name": "bibimbap", "serving": 1, "kcal": 600}],
        "total_kcal": 600,
    }
    assert_status(client.post("/meals", json=meal_payload), {200}, "POST /meals")
    assert_status(
        client.get("/meals", params={"user_id": "smoke-user", "date": "2026-04-28"}),
        {200},
        "GET /meals",
    )

    optional_dependency_checks = [
        (
            "POST /chat",
            client.post("/chat", json={"message": "dinner recommendation"}),
        ),
        (
            "POST /recommend",
            client.post(
                "/recommend",
                json={
                    "profile": {
                        "goal": "weight_loss",
                        "daily_target_kcal": 1700,
                        "allergies": ["milk"],
                        "preferences": ["low_sodium"],
                    },
                    "detected_foods": ["bibimbap"],
                    "meal_status": {"breakfast_kcal": 380, "lunch_kcal": 840},
                    "question": "recommend dinner",
                },
            ),
        ),
        ("GET /food/search", client.get("/food/search", params={"q": "salad"})),
        ("POST /food/add", client.post("/food/add", json={"name": "salad", "kcal": 120})),
    ]
    for name, response in optional_dependency_checks:
        assert_status(response, {200, 503}, name)

    print("api contract smoke test passed")


if __name__ == "__main__":
    main()
