"""
알레르기 관련 공통 상수 및 유틸 함수.

server/services/recommendation_pipeline.py 와 ai/rag_engine/rag_pipeline.py 두 곳에서
동일하게 import하여 중복 정의를 제거한다.
"""

from __future__ import annotations

import re

# 알레르겐 카테고리 → 관련 식재료 키워드
# rag_pipeline의 더 포괄적인 목록을 기준으로 통합
ALLERGEN_KEYWORDS: dict[str, list[str]] = {
    "유제품":  ["우유", "치즈", "버터", "요거트", "크림", "유청", "밀크", "라떼", "카푸치노", "아이스크림"],
    "견과류":  ["아몬드", "호두", "캐슈", "땅콩", "잣", "피스타치오", "마카다미아", "헤이즐넛", "피넛", "견과"],
    "갑각류":  ["새우", "게", "랍스터", "크랩", "대게"],
    "밀":      ["빵", "파스타", "면", "국수", "라면", "우동", "스파게티", "밀가루", "만두", "냉면", "소면"],
    "글루텐":  ["빵", "파스타", "면", "국수", "라면", "우동", "밀가루"],
    "계란":    ["계란", "달걀", "에그", "오믈렛", "마요네즈"],
    "대두":    ["두부", "된장", "간장", "두유", "콩국수", "낫토", "청국장"],
    "복숭아":  ["복숭아", "피치"],
    "토마토":  ["토마토", "케첩"],
    "고등어":  ["고등어"],
    "조개류":  ["조개", "홍합", "굴", "전복", "바지락", "오징어", "낙지", "문어"],
}

_SPLIT_RE = re.compile(r"[,/\s，]+")


def _split_allergen_str(allergy_str: str | None) -> list[str]:
    if not allergy_str:
        return []
    return [
        part.strip()
        for part in _SPLIT_RE.split(allergy_str)
        if part.strip() and part.strip().lower() not in ("none", "없음")
    ]


def check_allergen(food_name: str, allergy_str: str | None) -> tuple[bool, list[str]]:
    """
    음식 이름에 사용자 알레르기 성분이 포함되는지 검사한다.

    Returns:
        (경고 여부, 매칭된 알레르겐 카테고리 목록)
    """
    allergens = _split_allergen_str(allergy_str)
    matched: list[str] = []
    for allergen in allergens:
        keywords = ALLERGEN_KEYWORDS.get(allergen, [allergen])
        if any(kw and kw in food_name for kw in keywords):
            matched.append(allergen)
    return bool(matched), matched


def extract_allergen_keywords(allergy_str: str | None) -> list[str]:
    """
    알레르기 카테고리 문자열을 실제 식재료 키워드 목록으로 변환한다.
    rag_pipeline의 _extract_allergens() 로직을 통합.
    """
    keywords: list[str] = []
    for allergen in _split_allergen_str(allergy_str):
        keywords.extend(ALLERGEN_KEYWORDS.get(allergen, [allergen]))
    return list(dict.fromkeys(keywords))
