"""
챗봇 + 알레르기 필터 비교 스크립트

세 가지 비교를 한 번에 출력:
  1. 챗봇 쿼리 — 일반 유저 vs 당뇨 유저
  2. 챗봇 컨텍스트 — 기록 없는 유저 vs 기록 있는 유저
  3. 알레르기 필터 — 필터링 전 문서 vs 후, 후처리 경고 배너

실행:
  .venv\Scripts\python server/scripts/compare_chat_and_allergy.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from ai.rag_engine.rag_pipeline import (
    _build_meal_status_str,
    _build_profile_str,
    _build_allergen_warning,
    _calc_remaining_kcal,
    _extract_allergens,
    _rewrite_queries,
    post_process,
)

# ── 공통 쿼리 ──────────────────────────────────────────────────
QUERY = "저녁 뭐 먹을까요?"
MEAL_TIME = "저녁"

# ── 시나리오 프로필 ────────────────────────────────────────────
PROFILE_NORMAL = {
    "age": 28, "gender": "여", "weight": 58, "height": 163,
    "goal": "일반 건강 관리", "target_kcal": 1800,
    "allergy": None, "condition": None, "activity_level": "보통",
}
PROFILE_DIABETES = {
    **PROFILE_NORMAL,
    "condition": "당뇨",
    "goal": "체중 유지",
}
PROFILE_ALLERGY = {
    **PROFILE_NORMAL,
    "allergy": "유제품, 갑각류",
}

HISTORY_EMPTY: list[dict] = []
HISTORY_RICH = [
    {
        "meal_type": "breakfast", "total_kcal": 380,
        "foods": [
            {"name": "오트밀", "carb_g": 55, "protein_g": 10, "fat_g": 6},
            {"name": "바나나", "carb_g": 23, "protein_g": 1, "fat_g": 0},
        ],
    },
    {
        "meal_type": "lunch", "total_kcal": 620,
        "foods": [
            {"name": "닭가슴살", "carb_g": 0, "protein_g": 30, "fat_g": 3},
            {"name": "현미밥", "carb_g": 60, "protein_g": 5, "fat_g": 1},
            {"name": "브로콜리볶음", "carb_g": 8, "protein_g": 4, "fat_g": 2},
        ],
    },
]

# ── 알레르기 테스트용 샘플 문서 ────────────────────────────────
SAMPLE_DOCS = [
    "닭가슴살구이 | 분류: 구이류 | 칼로리 165kcal | 단백질 31g",
    "치즈피자 | 분류: 빵 및 과자류 | 칼로리 280kcal | 단백질 12g",
    "새우볶음밥 | 분류: 볶음류 | 칼로리 320kcal | 단백질 14g",
    "된장찌개 | 분류: 찌개 및 전골류 | 칼로리 68kcal | 나트륨 820mg",
    "우유라떼 | 분류: 음료 및 차류 | 칼로리 110kcal | 단백질 4g",
    "현미밥 | 분류: 밥류 | 칼로리 130kcal | 탄수화물 28g",
]

# ── 알레르기 LLM 응답 샘플 ────────────────────────────────────
LLM_ANSWER_WITH_ALLERGEN = """\
**치즈닭갈비** (칼로리: 420kcal)
추천 이유: 단백질이 풍부하고 채소와 함께 먹으면 균형 잡힌 식사가 됩니다.

**현미밥** (칼로리: 130kcal)
추천 이유: 복합 탄수화물로 포만감이 오래 지속됩니다.

코칭 메시지: 저녁은 단백질 위주로 드시고 탄수화물은 줄이는 것이 좋습니다.
"""


def _divider(title: str, char: str = "─") -> None:
    print(f"\n{char * 62}")
    print(f"  {title}")
    print(f"{char * 62}")


def _side_by_side(label_a: str, items_a: list[str],
                  label_b: str, items_b: list[str]) -> None:
    only_a = [q for q in items_a if q not in items_b]
    only_b = [q for q in items_b if q not in items_a]
    common = [q for q in items_a if q in items_b]

    print(f"\n  공통 쿼리 ({len(common)}개):")
    for q in common:
        print(f"    = {q}")

    if only_a:
        print(f"\n  {label_a}에만 있는 쿼리:")
        for q in only_a:
            print(f"    A. {q}")

    if only_b:
        print(f"\n  {label_b}에만 있는 쿼리:")
        for q in only_b:
            print(f"    B. {q}")


# ══════════════════════════════════════════════════════════════
# 1. 챗봇 쿼리 비교 — 일반 유저 vs 당뇨 유저
# ══════════════════════════════════════════════════════════════
def section_query_comparison() -> None:
    _divider("1. 챗봇 쿼리 비교 — 일반 유저 vs 당뇨 유저", "═")

    remaining_normal  = _calc_remaining_kcal(PROFILE_NORMAL, HISTORY_EMPTY)
    remaining_diabetes = _calc_remaining_kcal(PROFILE_DIABETES, HISTORY_EMPTY)

    q_normal   = _rewrite_queries(QUERY, PROFILE_NORMAL,   None, remaining_normal,   MEAL_TIME)
    q_diabetes = _rewrite_queries(QUERY, PROFILE_DIABETES, None, remaining_diabetes, MEAL_TIME)

    print(f"\n  질문: \"{QUERY}\"")
    print(f"\n  [A] 일반 유저  | 목표: {PROFILE_NORMAL['goal']}")
    for i, q in enumerate(q_normal, 1):
        print(f"       {i}. {q}")

    print(f"\n  [B] 당뇨 유저  | 목표: {PROFILE_DIABETES['goal']} / 질환: 당뇨")
    for i, q in enumerate(q_diabetes, 1):
        print(f"       {i}. {q}")

    _side_by_side("일반", q_normal, "당뇨", q_diabetes)


# ══════════════════════════════════════════════════════════════
# 2. 챗봇 컨텍스트 비교 — 기록 없음 vs 기록 있음
# ══════════════════════════════════════════════════════════════
def section_context_comparison() -> None:
    _divider("2. 챗봇 컨텍스트 비교 — 기록 없음 vs 기록 있음", "═")

    status_empty = _build_meal_status_str(PROFILE_NORMAL, HISTORY_EMPTY)
    status_rich  = _build_meal_status_str(PROFILE_NORMAL, HISTORY_RICH)

    print("\n  [A] 기록 없는 유저 — LLM에 전달되는 [식단 현황]:")
    for line in status_empty.splitlines():
        print(f"       {line}")

    print("\n  [B] 기록 있는 유저 — LLM에 전달되는 [식단 현황]:")
    for line in status_rich.splitlines():
        print(f"       {line}")

    remaining_rich = _calc_remaining_kcal(PROFILE_NORMAL, HISTORY_RICH)
    q_empty = _rewrite_queries(QUERY, PROFILE_NORMAL, None, None,          MEAL_TIME)
    q_rich  = _rewrite_queries(QUERY, PROFILE_NORMAL, None, remaining_rich, MEAL_TIME)

    print(f"\n  쿼리 차이 (기록 반영 여부):")
    _side_by_side("기록없음", q_empty, "기록있음", q_rich)


# ══════════════════════════════════════════════════════════════
# 3. 알레르기 필터 비교
# ══════════════════════════════════════════════════════════════
def section_allergy_comparison() -> None:
    _divider("3. 알레르기 필터 비교 — 없음 vs 유제품+갑각류", "═")

    allergens = _extract_allergens(PROFILE_ALLERGY)
    print(f"\n  알레르기 설정: {PROFILE_ALLERGY['allergy']}")
    print(f"  → 확장된 키워드: {allergens}")

    print(f"\n  RAG 검색 결과 필터링 ({len(SAMPLE_DOCS)}개 문서):")
    passed, blocked = [], []
    for doc in SAMPLE_DOCS:
        hits = [kw for kw in allergens if kw in doc]
        if hits:
            blocked.append((doc.split("|")[0].strip(), hits))
        else:
            passed.append(doc.split("|")[0].strip())

    print(f"\n    통과 ({len(passed)}개) — LLM에 전달됨:")
    for name in passed:
        print(f"      ✓  {name}")

    print(f"\n    차단 ({len(blocked)}개) — LLM에 전달 안 됨:")
    for name, hits in blocked:
        print(f"      ✗  {name}  ← '{', '.join(hits)}' 포함")

    # 후처리 경고 배너
    print(f"\n  LLM 응답 후처리 — 알레르기 경고 주입:")
    print(f"\n  [알레르기 없는 유저] 후처리 결과:")
    result_no_allergy = post_process(LLM_ANSWER_WITH_ALLERGEN, PROFILE_NORMAL)
    first_line = result_no_allergy.splitlines()[0]
    print(f"    첫 줄: {first_line}")

    print(f"\n  [유제품 알레르기 유저] 후처리 결과:")
    result_with_allergy = post_process(LLM_ANSWER_WITH_ALLERGEN, PROFILE_ALLERGY)
    first_line_allergy = result_with_allergy.splitlines()[0]
    print(f"    첫 줄: {first_line_allergy}")
    if result_with_allergy.startswith("> ⚠️"):
        print(f"    → 경고 배너 자동 삽입됨")


# ══════════════════════════════════════════════════════════════
def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")

    print("\n" + "═" * 62)
    print("  NutrAI 챗봇 + 알레르기 파이프라인 비교")
    print("═" * 62)

    section_query_comparison()
    section_context_comparison()
    section_allergy_comparison()

    print("\n" + "═" * 62 + "\n")


if __name__ == "__main__":
    main()
