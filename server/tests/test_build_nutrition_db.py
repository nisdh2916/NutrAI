"""ai/scripts/build_nutrition_db.py — tag_row() 단위 테스트."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from ai.scripts.build_nutrition_db import tag_row


def _row(kcal=200, protein=10, fat=5, sodium=200, sugar=3, carb=20, fiber=2):
    return {
        "에너지(kcal)": kcal,
        "단백질(g)": protein,
        "지방(g)": fat,
        "나트륨(mg)": sodium,
        "당류(g)": sugar,
        "탄수화물(g)": carb,
        "식이섬유(g)": fiber,
    }


class TestMealTimeTags:
    def test_밥류_is_morning_lunch_dinner(self):
        t = tag_row(_row(), "밥류")
        assert t["is_morning"] is True
        assert t["is_lunch"] is True
        assert t["is_dinner"] is True
        assert t["is_snack"] is False

    def test_죽_is_morning_not_snack(self):
        t = tag_row(_row(), "죽 및 스프류")
        assert t["is_morning"] is True
        assert t["is_snack"] is False

    def test_빵과자_is_morning_snack(self):
        t = tag_row(_row(), "빵 및 과자류")
        assert t["is_morning"] is True
        assert t["is_snack"] is True

    def test_과일류_is_morning_snack(self):
        t = tag_row(_row(), "과일류")
        assert t["is_morning"] is True
        assert t["is_snack"] is True

    def test_구이류_is_lunch_dinner(self):
        t = tag_row(_row(), "구이류")
        assert t["is_lunch"] is True
        assert t["is_dinner"] is True
        assert t["is_morning"] is False

    def test_찌개_is_lunch_dinner(self):
        t = tag_row(_row(), "찌개 및 전골류")
        assert t["is_lunch"] is True
        assert t["is_dinner"] is True

    def test_면_is_lunch_dinner(self):
        t = tag_row(_row(), "면 및 만두류")
        assert t["is_lunch"] is True
        assert t["is_dinner"] is True

    def test_두류견과_is_snack(self):
        t = tag_row(_row(), "두류, 견과 및 종실류")
        assert t["is_snack"] is True


class TestDietTag:
    def test_저칼로리_채소류_is_diet(self):
        t = tag_row(_row(kcal=80), "채소, 해조류")
        assert t["is_diet"] is True

    def test_고칼로리_not_diet(self):
        t = tag_row(_row(kcal=500), "밥류")
        assert t["is_diet"] is False

    def test_고단백저지방_is_diet(self):
        # 단백질 20g, 지방 3g, 칼로리 200
        t = tag_row(_row(kcal=200, protein=20, fat=3), "수·조·어·육류")
        assert t["is_diet"] is True

    def test_빵과자_저칼로리도_not_diet(self):
        # 빵·과자류는 다이어트 비적합 카테고리
        t = tag_row(_row(kcal=150), "빵 및 과자류")
        assert t["is_diet"] is False

    def test_튀김류_not_diet(self):
        t = tag_row(_row(kcal=200), "튀김류")
        assert t["is_diet"] is False


class TestDiabetesTag:
    def test_저당저탄_is_diabetes(self):
        t = tag_row(_row(sugar=2, carb=15), "나물·숙채류")
        assert t["is_diabetes"] is True

    def test_고당_not_diabetes(self):
        t = tag_row(_row(sugar=20, carb=40), "음료 및 차류")
        assert t["is_diabetes"] is False

    def test_고탄수화물_not_diabetes(self):
        t = tag_row(_row(sugar=3, carb=50), "밥류")
        assert t["is_diabetes"] is False

    def test_음료차류_excluded(self):
        # 음료는 당류 낮아도 고당 카테고리로 제외
        t = tag_row(_row(sugar=1, carb=5), "음료 및 차류")
        assert t["is_diabetes"] is False


class TestHypertensionTag:
    def test_저나트륨_is_hypertension(self):
        t = tag_row(_row(sodium=150), "채소, 해조류")
        assert t["is_hypertension"] is True

    def test_고나트륨_not_hypertension(self):
        t = tag_row(_row(sodium=800), "국 및 탕류")
        assert t["is_hypertension"] is False

    def test_젓갈류_excluded(self):
        t = tag_row(_row(sodium=100), "젓갈류")
        assert t["is_hypertension"] is False

    def test_김치류_excluded(self):
        t = tag_row(_row(sodium=200), "김치류")
        assert t["is_hypertension"] is False

    def test_장류_excluded(self):
        t = tag_row(_row(sodium=100), "장류, 양념류")
        assert t["is_hypertension"] is False

    def test_zero_sodium_not_hypertension(self):
        # 나트륨 0은 데이터 누락으로 판단 → False
        t = tag_row(_row(sodium=0), "채소, 해조류")
        assert t["is_hypertension"] is False


class TestSupplementTag:
    def test_food_source_not_supplement(self):
        t = tag_row(_row(), "밥류", source="food")
        assert t["is_supplement"] is False

    def test_supplement_source_is_supplement(self):
        t = tag_row(_row(), "건강기능식품", source="supplement")
        assert t["is_supplement"] is True
