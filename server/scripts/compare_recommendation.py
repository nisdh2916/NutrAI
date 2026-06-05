"""
추천 파이프라인 비교 스크립트

기록 없는 유저 vs 기록 있는 유저의 파이프라인 컨텍스트를 나란히 출력.
LLM/ChromaDB 없이 전처리 레이어만 실행.

실행:
  .venv\Scripts\python server/scripts/compare_recommendation.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from server.services.recommendation_pipeline import (
    build_recommendation_context,
    build_coaching_prefix,
    format_context_block,
)

# ── 공통 프로필 ────────────────────────────────────────────────
PROFILE = {
    "age": 30,
    "gender": "남",
    "weight": 75,
    "height": 175,
    "goal": "다이어트",
    "target_kcal": 1800,
    "allergy": "유제품",
    "condition": "",
    "activity_level": "보통",
}

CATEGORY = "다이어트"

# ── 시나리오 A: 기록 없는 유저 ──────────────────────────────────
HISTORY_EMPTY: list[dict] = []

# ── 시나리오 B: 기록 있는 유저 (아침+점심 이미 섭취) ────────────────
HISTORY_RICH = [
    {
        "meal_type": "breakfast",
        "total_kcal": 450,
        "foods": [
            {"name": "식빵", "carb_g": 55, "protein_g": 8, "fat_g": 5},
            {"name": "아메리카노", "carb_g": 0, "protein_g": 0, "fat_g": 0},
        ],
    },
    {
        "meal_type": "lunch",
        "total_kcal": 680,
        "foods": [
            {"name": "된장찌개", "carb_g": 15, "protein_g": 12, "fat_g": 4},
            {"name": "흰쌀밥", "carb_g": 65, "protein_g": 5, "fat_g": 1},
            {"name": "김치", "carb_g": 5, "protein_g": 2, "fat_g": 0},
        ],
    },
]


def _divider(title: str) -> None:
    width = 60
    print(f"\n{'─' * width}")
    print(f"  {title}")
    print(f"{'─' * width}")


def _print_ctx(label: str, ctx, history: list[dict]) -> None:
    _divider(label)

    print(f"  목표:          {ctx.goal}")
    print(f"  식사 시간대:   {ctx.meal_time}")
    print(f"  제약 조건:     {', '.join(ctx.constraints) if ctx.constraints else '없음'}")
    print()
    print(f"  오늘 섭취:     {ctx.meal_status.consumed_today:.0f} kcal")
    print(f"  남은 칼로리:   {ctx.meal_status.remaining_kcal:.0f} kcal")
    print(f"  탄/단/지:      "
          f"탄수화물 {ctx.meal_status.total_carb_g:.0f}g  "
          f"단백질 {ctx.meal_status.total_protein_g:.0f}g  "
          f"지방 {ctx.meal_status.total_fat_g:.0f}g")

    if ctx.meal_status.detected_foods:
        print(f"  오늘 먹은 것:  {', '.join(ctx.meal_status.detected_foods)}")
    else:
        print(f"  오늘 먹은 것:  (없음)")

    print()
    print(f"  생성된 쿼리 ({len(ctx.queries)}개):")
    for i, q in enumerate(ctx.queries, 1):
        print(f"    {i}. {q}")

    print()
    print(f"  코칭 프리픽스:")
    print(f"    → {build_coaching_prefix(ctx)}")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")

    print("\n" + "═" * 60)
    print("  NutrAI 추천 파이프라인 비교")
    print(f"  프로필: {PROFILE['age']}세 {PROFILE['gender']} / 목표칼로리 {PROFILE['target_kcal']}kcal")
    print(f"  목표: {PROFILE['goal']} / 알레르기: {PROFILE['allergy']}")
    print(f"  카테고리: {CATEGORY}")
    print("═" * 60)

    ctx_empty = build_recommendation_context(
        profile=PROFILE,
        meal_history=HISTORY_EMPTY,
        category=CATEGORY,
        user_query=f"{CATEGORY} 메뉴 추천",
    )
    _print_ctx("시나리오 A — 기록 없는 유저 (첫 방문)", ctx_empty, HISTORY_EMPTY)

    ctx_rich = build_recommendation_context(
        profile=PROFILE,
        meal_history=HISTORY_RICH,
        category=CATEGORY,
        user_query=f"{CATEGORY} 메뉴 추천",
    )
    _print_ctx("시나리오 B — 기록 있는 유저 (아침 450kcal + 점심 680kcal 섭취)", ctx_rich, HISTORY_RICH)

    # 차이 요약
    _divider("차이 요약")
    diff_remaining = ctx_empty.meal_status.remaining_kcal - ctx_rich.meal_status.remaining_kcal
    print(f"  남은 칼로리 차이:  {diff_remaining:.0f} kcal (B가 {diff_remaining:.0f}kcal 더 적음)")
    print(f"  쿼리 수:           A={len(ctx_empty.queries)}개  B={len(ctx_rich.queries)}개")

    a_queries = set(ctx_empty.queries)
    b_queries = set(ctx_rich.queries)
    only_b = b_queries - a_queries
    if only_b:
        print(f"  B에만 있는 쿼리:")
        for q in only_b:
            print(f"    + {q}")
    print()


if __name__ == "__main__":
    main()
