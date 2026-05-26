"""ai/rag_engine/rag_pipeline.py 순수 함수 단위 테스트. ChromaDB/LLM mock 없음."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from ai.rag_engine.rag_pipeline import (
    _build_allergen_warning,
    _build_meal_status_str,
    _build_profile_str,
    _calc_consumed_today,
    _calc_remaining_kcal,
    _detect_meal_time,
    _diversify_docs,
    _format_context,
    _rewrite_queries,
    _strip_think_streaming,
    _validate_kcal,
    post_process,
)


# ── _detect_meal_time ──────────────────────────────────────────
class TestDetectMealTime:
    def test_아침_keyword(self):
        assert _detect_meal_time("아침 뭐 먹지") == "아침"

    def test_점심_keyword(self):
        assert _detect_meal_time("점심 추천해줘") == "점심"

    def test_저녁_keyword(self):
        assert _detect_meal_time("저녁 메뉴") == "저녁"

    def test_야식_keyword(self):
        assert _detect_meal_time("야식 먹고 싶어") == "저녁"

    def test_간식_keyword(self):
        assert _detect_meal_time("간식 추천") == "간식"

    def test_no_keyword_returns_empty(self):
        assert _detect_meal_time("뭐 먹을까") == ""


# ── _calc_consumed_today / _calc_remaining_kcal ────────────────
class TestCalcKcal:
    def test_consumed_sums_meals(self):
        meals = [{"total_kcal": 400}, {"total_kcal": 600}]
        assert _calc_consumed_today(meals) == 1000.0

    def test_consumed_empty_returns_zero(self):
        assert _calc_consumed_today([]) == 0.0
        assert _calc_consumed_today(None) == 0.0

    def test_remaining_with_target(self):
        meals = [{"total_kcal": 500}]
        result = _calc_remaining_kcal({"target_kcal": 2000}, meals)
        assert result == 1500.0

    def test_remaining_clamped_to_zero(self):
        meals = [{"total_kcal": 2500}]
        result = _calc_remaining_kcal({"target_kcal": 2000}, meals)
        assert result == 0.0

    def test_remaining_no_target_returns_none(self):
        assert _calc_remaining_kcal({}, []) is None


# ── _rewrite_queries ───────────────────────────────────────────
class TestRewriteQueries:
    def _run(self, query, profile=None, detected=None, remaining=None, meal_time=""):
        return _rewrite_queries(query, profile or {}, detected, remaining, meal_time)

    def test_user_query_included(self):
        q = self._run("점심 추천")
        assert "점심 추천" in q

    def test_max_four_queries(self):
        q = self._run("점심", {"goal": "다이어트", "condition": "당뇨"}, ["비빔밥"], 800.0, "점심")
        assert len(q) <= 4

    def test_supplement_intent_returns_health_queries(self):
        q = self._run("비타민 추천해줘")
        assert any("건강기능식품" in item for item in q)

    def test_meal_time_combined_with_goal(self):
        q = self._run("뭐 먹지", {"goal": "다이어트"}, meal_time="점심")
        assert any("점심" in item for item in q)

    def test_condition_added_as_query(self):
        q = self._run("뭐 먹을까", {"condition": "당뇨"})
        assert any("당뇨" in item for item in q)

    def test_remaining_kcal_query_added(self):
        q = self._run("뭐 먹지", remaining=800.0)
        assert any("800" in item for item in q)

    def test_no_duplicate_queries(self):
        q = self._run("점심 추천")
        assert len(q) == len(set(q))


# ── _diversify_docs ────────────────────────────────────────────
class TestDiversifyDocs:
    def test_limits_same_category(self):
        docs = [
            "피자_마르게리타 | ...",
            "피자_페퍼로니 | ...",
            "피자_하와이안 | ...",  # 세 번째 피자 — 제거 대상
            "파스타_봉골레 | ...",
        ]
        result = _diversify_docs(docs, max_per_category=2)
        pizza_count = sum(1 for d in result if d.startswith("피자"))
        assert pizza_count <= 2

    def test_different_categories_all_kept(self):
        docs = [
            "비빔밥 | ...",
            "된장찌개 | ...",
            "닭가슴살 | ...",
        ]
        result = _diversify_docs(docs, max_per_category=2)
        assert len(result) == 3

    def test_empty_returns_empty(self):
        assert _diversify_docs([]) == []


# ── _format_context ────────────────────────────────────────────
class TestFormatContext:
    def test_empty_returns_fallback_message(self):
        result = _format_context([])
        assert "찾지 못" in result

    def test_numbered_output(self):
        result = _format_context(["비빔밥 | 칼로리 550kcal", "닭가슴살 | 칼로리 165kcal"])
        assert "1." in result
        assert "2." in result

    def test_pipe_replaced_with_comma(self):
        result = _format_context(["비빔밥 | 칼로리 550kcal"])
        assert "|" not in result
        assert "," in result


# ── _strip_think_streaming ────────────────────────────────────
class TestStripThinkStreaming:
    def test_no_think_tag_passthrough(self):
        out, buf, in_think = _strip_think_streaming("안녕하세요", False)
        assert out == "안녕하세요"
        assert in_think is False

    def test_complete_think_tag_removed(self):
        chunk = "텍스트 <think>내부 CoT</think> 결과"
        out, buf, in_think = _strip_think_streaming(chunk, False)
        assert "<think>" not in out
        assert "결과" in out
        assert in_think is False

    def test_partial_think_open_buffered(self):
        # <think> 열렸지만 닫히지 않은 경우 → 출력 없음
        out, buf, in_think = _strip_think_streaming("시작<think>생각중...", False)
        assert "<think>" not in out
        assert in_think is True

    def test_partial_think_close_completes(self):
        # 이전 청크에서 in_think=True 상태로 닫힘
        out, buf, in_think = _strip_think_streaming("</think> 결론", True)
        assert "결론" in out
        assert in_think is False


# ── _validate_kcal ────────────────────────────────────────────
class TestValidateKcal:
    def test_normal_kcal_no_warning(self):
        result = _validate_kcal("비빔밥 550kcal 추천합니다")
        assert "⚠️" not in result

    def test_too_low_kcal_flagged(self):
        result = _validate_kcal("이 음식은 30kcal입니다")
        assert "⚠️" in result

    def test_too_high_kcal_flagged(self):
        result = _validate_kcal("이 음식은 2500kcal입니다")
        assert "⚠️" in result

    def test_zero_kcal_not_flagged(self):
        # 영양성분 표기의 0kcal은 경고 없음
        result = _validate_kcal("당류 0kcal")
        assert "⚠️" not in result

    def test_remaining_kcal_exceeded_flagged(self):
        result = _validate_kcal("1000kcal 추천", remaining_kcal=500.0)
        assert "⚠️" in result
        assert "초과" in result

    def test_within_remaining_kcal_no_warning(self):
        result = _validate_kcal("400kcal 추천", remaining_kcal=500.0)
        assert "초과" not in result


# ── _build_allergen_warning ───────────────────────────────────
class TestBuildAllergenWarning:
    def test_no_allergen_in_name_lines_returns_empty(self):
        answer = "**비빔밥** (550kcal)\n추천 이유: 균형 잡힌 식사입니다."
        result = _build_allergen_warning(answer, ["우유", "치즈"])
        assert result == ""

    def test_allergen_in_name_line_returns_warning(self):
        answer = "**치즈버거** (600kcal)\n추천 이유: 단백질이 풍부합니다."
        result = _build_allergen_warning(answer, ["우유", "치즈"])
        assert "⚠️" in result
        assert "치즈" in result

    def test_allergen_mention_in_coaching_not_flagged(self):
        # 코칭 메시지에서 알레르기 언급은 정상 — **음식명** 줄만 검사
        answer = "**비빔밥** (550kcal)\n코칭: 유제품 알레르기가 있으시니 주의하세요."
        result = _build_allergen_warning(answer, ["우유"])
        assert result == ""

    def test_no_allergens_returns_empty(self):
        answer = "**된장찌개** (300kcal)"
        assert _build_allergen_warning(answer, []) == ""


# ── post_process ──────────────────────────────────────────────
class TestPostProcess:
    def test_think_tag_stripped(self):
        raw = "<think>내부 추론...</think>**비빔밥** 550kcal 추천합니다."
        result = post_process(raw, {})
        assert "<think>" not in result
        assert "비빔밥" in result

    def test_excessive_blank_lines_normalized(self):
        raw = "줄1\n\n\n\n\n줄2"
        result = post_process(raw, {})
        assert "\n\n\n" not in result

    def test_allergen_warning_prepended(self):
        raw = "**치즈피자** (800kcal)\n맛있습니다."
        result = post_process(raw, {"allergy": "유제품"})
        assert result.startswith("> ⚠️")

    def test_no_allergen_no_prepend(self):
        raw = "**비빔밥** (550kcal)\n맛있습니다."
        result = post_process(raw, {"allergy": "유제품"})
        assert not result.startswith("> ⚠️")


# ── _build_profile_str ─────────────────────────────────────────
class TestBuildProfileStr:
    def test_contains_user_info_header(self):
        result = _build_profile_str({"age": 30, "gender": "남"})
        assert "[사용자 정보]" in result

    def test_unknown_fields_show_default(self):
        result = _build_profile_str({})
        assert "미입력" in result

    def test_allergy_shown(self):
        result = _build_profile_str({"allergy": "견과류"})
        assert "견과류" in result


# ── _build_meal_status_str ─────────────────────────────────────
class TestBuildMealStatusStr:
    def test_no_history_shows_no_record(self):
        result = _build_meal_status_str({}, None)
        assert "기록 없음" in result

    def test_consumed_kcal_shown(self):
        meals = [{"meal_type": "아침", "total_kcal": 500, "foods": []}]
        result = _build_meal_status_str({}, meals)
        assert "500" in result

    def test_remaining_kcal_shown_when_target_set(self):
        meals = [{"meal_type": "아침", "total_kcal": 500, "foods": []}]
        result = _build_meal_status_str({"target_kcal": 2000}, meals)
        assert "1500" in result
