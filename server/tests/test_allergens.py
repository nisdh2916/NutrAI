"""server/common/allergens.py 순수 함수 단위 테스트."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from server.common.allergens import (
    ALLERGEN_KEYWORDS,
    check_allergen,
    extract_allergen_keywords,
)


class TestCheckAllergen:
    def test_no_allergy_no_warning(self):
        found, names = check_allergen("비빔밥", None)
        assert found is False
        assert names == []

    def test_empty_allergy_str_no_warning(self):
        found, names = check_allergen("우유", "")
        assert found is False

    def test_none_keyword_ignored(self):
        found, names = check_allergen("비빔밥", "없음")
        assert found is False

    def test_dairy_matches_milk(self):
        found, names = check_allergen("우유 라떼", "유제품")
        assert found is True
        assert "유제품" in names

    def test_dairy_matches_cheese(self):
        found, names = check_allergen("치즈버거", "유제품")
        assert found is True

    def test_nut_matches_almond(self):
        found, names = check_allergen("아몬드 과자", "견과류")
        assert found is True
        assert "견과류" in names

    def test_egg_matches_mayonnaise(self):
        found, names = check_allergen("마요네즈 샐러드", "계란")
        assert found is True

    def test_multiple_allergens_matched(self):
        found, names = check_allergen("치즈 계란 토스트", "유제품, 계란")
        assert found is True
        assert "유제품" in names
        assert "계란" in names

    def test_partial_match_not_triggered(self):
        # "새우" is in 갑각류 but "왕새우볶음밥" should still match
        found, names = check_allergen("왕새우볶음밥", "갑각류")
        assert found is True

    def test_no_match_returns_empty_list(self):
        found, names = check_allergen("불고기", "갑각류")
        assert found is False
        assert names == []

    def test_unknown_allergen_uses_itself_as_keyword(self):
        # 알레르겐 딕셔너리에 없는 항목은 이름 자체로 키워드 검사
        found, names = check_allergen("망고 주스", "망고")
        assert found is True
        assert "망고" in names

    def test_slash_separated_allergens(self):
        found, names = check_allergen("두부조림", "대두/계란")
        assert found is True
        assert "대두" in names

    def test_food_name_not_containing_allergen(self):
        found, names = check_allergen("사과", "유제품")
        assert found is False


class TestExtractAllergenKeywords:
    def test_none_returns_empty(self):
        assert extract_allergen_keywords(None) == []

    def test_empty_returns_empty(self):
        assert extract_allergen_keywords("") == []

    def test_none_keyword_returns_empty(self):
        assert extract_allergen_keywords("없음") == []

    def test_dairy_expands_to_keywords(self):
        kws = extract_allergen_keywords("유제품")
        assert "우유" in kws
        assert "치즈" in kws
        assert "버터" in kws

    def test_multiple_categories_combined(self):
        kws = extract_allergen_keywords("유제품, 견과류")
        assert "우유" in kws
        assert "아몬드" in kws

    def test_no_duplicates(self):
        # 밀과 글루텐은 키워드 겹침 — 중복 제거 확인
        kws = extract_allergen_keywords("밀, 글루텐")
        assert len(kws) == len(set(kws))

    def test_unknown_allergen_returns_itself(self):
        kws = extract_allergen_keywords("망고")
        assert kws == ["망고"]


class TestAllergenKeywordsDict:
    def test_all_categories_have_keywords(self):
        for category, keywords in ALLERGEN_KEYWORDS.items():
            assert len(keywords) > 0, f"{category} 키워드 없음"

    def test_known_categories_present(self):
        for expected in ("유제품", "견과류", "갑각류", "밀", "계란", "대두"):
            assert expected in ALLERGEN_KEYWORDS
