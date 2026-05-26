"""ai/rag_engine/rag_pipeline.py 순수 함수 단위 테스트. ChromaDB/LLM mock 없음."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from ai.rag_engine.rag_pipeline import (
    _add_serving_kcal,
    _build_allergen_warning,
    _build_direct_nutrition_answer,
    _build_meal_status_str,
    _build_profile_str,
    _calc_consumed_today,
    _calc_remaining_kcal,
    _detect_meal_time,
    _diversify_docs,
    _extract_food_keywords,
    _format_context,
    _NUTRITION_QUESTION_RE,
    _remove_format_artifacts,
    _rewrite_queries,
    _strip_think_streaming,
    _validate_kcal,
    post_process,
)


# ── _add_serving_kcal ─────────────────────────────────────────
class TestAddServingKcal:
    _찌개_doc = "된장찌개 | 분류: 찌개 및 전골류 | 칼로리 46.0kcal | 탄수화물 4.4g | 단백질 3.4g | (기준: 100g)"
    _밥_doc   = "흰쌀밥 | 분류: 밥류 | 칼로리 150.0kcal | 탄수화물 30.0g | (기준: 100g)"
    _국_doc   = "된장국_감자 | 분류: 국 및 탕류 | 칼로리 25.0kcal | 탄수화물 3.7g | (기준: 100g)"
    _unknown_doc = "특수음식 | 분류: 알수없는분류 | 칼로리 100.0kcal | (기준: 100g)"

    def test_찌개류_2_5배_환산(self):
        result = _add_serving_kcal(self._찌개_doc)
        assert "115kcal" in result          # 46 × 2.5 = 115

    def test_밥류_2_1배_환산(self):
        result = _add_serving_kcal(self._밥_doc)
        assert "315kcal" in result          # 150 × 2.1 = 315

    def test_국류_2_5배_환산(self):
        result = _add_serving_kcal(self._국_doc)
        assert "62kcal" in result           # 25 × 2.5 = 62.5 → 62

    def test_알수없는_카테고리_기본_1_0배(self):
        result = _add_serving_kcal(self._unknown_doc)
        assert "100kcal" in result          # 100 × 1.0 = 100

    def test_분류_없는_문서_원본_반환(self):
        doc = "된장 조리 시 소금을 줄이는 방법을 안내합니다."
        assert _add_serving_kcal(doc) == doc

    def test_칼로리_없는_문서_원본_반환(self):
        doc = "된장찌개 | 분류: 찌개 및 전골류 | 탄수화물 4.4g | (기준: 100g)"
        assert _add_serving_kcal(doc) == doc

    def test_1인분_기준_레이블_포함(self):
        result = _add_serving_kcal(self._찌개_doc)
        assert "1인분 기준" in result

    def test_배율_정보_포함(self):
        result = _add_serving_kcal(self._찌개_doc)
        assert "2.5배 환산" in result


# ── _extract_food_keywords ─────────────────────────────────────
class TestExtractFoodKeywords:
    def test_음식명_추출(self):
        kws = _extract_food_keywords("된장찌개 칼로리가 얼마야?")
        assert "된장찌개" in kws

    def test_불용어_제거(self):
        kws = _extract_food_keywords("칼로리 얼마야 추천 알려줘")
        assert len(kws) == 0

    def test_여러_단어_추출(self):
        kws = _extract_food_keywords("비빔밥이랑 된장찌개 둘 다 먹어도 돼?")
        assert "비빔밥" in kws or "된장찌개" in kws


# ── _NUTRITION_QUESTION_RE ─────────────────────────────────────
class TestNutritionQuestionRE:
    def test_칼로리_얼마_matches(self):
        assert _NUTRITION_QUESTION_RE.search("된장찌개 칼로리가 얼마야?")

    def test_영양_알려_matches(self):
        assert _NUTRITION_QUESTION_RE.search("김치찌개 영양 정보 알려줘")

    def test_추천_질문_no_match(self):
        assert not _NUTRITION_QUESTION_RE.search("오늘 점심 뭐 먹을까?")

    def test_다이어트_추천_no_match(self):
        assert not _NUTRITION_QUESTION_RE.search("다이어트 추천해줘")


# ── _build_direct_nutrition_answer ────────────────────────────
class TestBuildDirectNutritionAnswer:
    _docs = [
        "된장찌개 | 분류: 찌개 및 전골류 | 칼로리 46.0kcal | 탄수화물 4.4g | 단백질 3.4g | 지방 1.6g | 나트륨 318.0mg | (기준: 100g)",
        "비빔밥 | 분류: 밥류 | 칼로리 150.0kcal | 탄수화물 30.0g | (기준: 100g)",
    ]

    def test_음식명_매칭시_직접_답변_반환(self):
        result = _build_direct_nutrition_answer("된장찌개", self._docs)
        assert result is not None
        assert "46.0kcal" in result
        assert "115kcal" in result      # 46 × 2.5 = 115
        assert "1인분 기준" in result

    def test_없는_음식명_None_반환(self):
        result = _build_direct_nutrition_answer("돈까스", self._docs)
        assert result is None

    def test_영양소_정보_포함(self):
        result = _build_direct_nutrition_answer("된장찌개", self._docs)
        assert "탄수화물" in result
        assert "단백질" in result
        assert "지방" in result

    def test_출처_포함(self):
        result = _build_direct_nutrition_answer("된장찌개", self._docs)
        assert "출처" in result


# ── _remove_format_artifacts ──────────────────────────────────
class TestRemoveFormatArtifacts:
    def test_레이블_포함_변환(self):
        # **음식명** 현미밥 (칼로리: 315kcal) → **현미밥** (칼로리: 315kcal)
        result = _remove_format_artifacts("**음식명** 현미밥 (칼로리: 315kcal)")
        assert result == "**현미밥** (칼로리: 315kcal)"

    def test_레이블만_있는_줄_제거(self):
        # **음식명** (칼로리: Xkcal) → ""
        result = _remove_format_artifacts("**음식명** (칼로리: Xkcal)  ")
        assert "음식명" not in result

    def test_정상_음식명_유지(self):
        result = _remove_format_artifacts("**된장찌개** (칼로리: 115kcal)")
        assert result == "**된장찌개** (칼로리: 115kcal)"

    def test_음식이름_레이블_변환(self):
        result = _remove_format_artifacts("**음식 이름** 닭가슴살구이 (칼로리: 165kcal)")
        assert result == "**닭가슴살구이** (칼로리: 165kcal)"

    def test_공백포함_음식명_변환(self):
        result = _remove_format_artifacts("**음식명** 닭 가슴살 구이 (칼로리: 165kcal)")
        assert result == "**닭 가슴살 구이** (칼로리: 165kcal)"

    def test_부분청크_적용시_칼로리_잘림_재현(self):
        # 이 테스트는 _remove_format_artifacts를 부분 청크에 적용하면 칼로리가 잘린다는
        # 것을 문서화한다. stream_recommendation()은 전체 텍스트에 한 번만 적용해야 함.
        partial = "**음식명** 닭가슴살 샐러드 (칼"  # "(칼로리: 135kcal)" 중 일부만 도착
        result = _remove_format_artifacts(partial)
        # 부분 청크이면 "(칼"만 캡처되어 칼로리가 잘린 채로 반환된다
        assert result == "**닭가슴살 샐러드** (칼"

    def test_전체텍스트_적용시_칼로리_완전(self):
        # 전체 텍스트에 적용하면 칼로리가 완전히 포함된다
        full = "**음식명** 닭가슴살 샐러드 (칼로리: 135kcal)\n추천 이유: 고단백"
        result = _remove_format_artifacts(full)
        assert result == "**닭가슴살 샐러드** (칼로리: 135kcal)\n추천 이유: 고단백"


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

    def test_full_format_doc_includes_serving_kcal(self):
        doc = "된장찌개 | 분류: 찌개 및 전골류 | 칼로리 46.0kcal | 탄수화물 4.4g | (기준: 100g)"
        result = _format_context([doc])
        assert "1인분 기준" in result
        assert "115" in result              # 46 × 2.5 = 115


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
