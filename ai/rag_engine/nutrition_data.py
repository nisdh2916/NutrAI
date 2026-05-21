# 한국식품영양성분표 기반 샘플 데이터 + 질환별 식단 가이드라인
# 빌드: ai/scripts/build_sample_db.py 실행

from __future__ import annotations

NUTRITION_ITEMS: list[dict] = [
    # ── 아침 식품 ──────────────────────────────────────────────────────
    {
        "text": "쌀죽 | 분류: 한식 | 칼로리 150kcal | 탄수화물 32g | 단백질 3g | 지방 0.5g | 나트륨 200mg | (기준: 1인분 300g)",
        "metadata": {"name": "쌀죽", "category": "한식", "meal_time": "아침", "goal_tag": "일반,당뇨,고혈압", "source": "sample"},
    },
    {
        "text": "오트밀 | 분류: 간식 | 칼로리 300kcal | 탄수화물 54g | 단백질 11g | 지방 5g | 식이섬유 8g | (기준: 1인분 80g+우유)",
        "metadata": {"name": "오트밀", "category": "간식", "meal_time": "아침,간식", "goal_tag": "일반,다이어트,당뇨", "source": "sample"},
    },
    {
        "text": "그릭요거트 | 분류: 유제품 | 칼로리 100kcal | 탄수화물 6g | 단백질 10g | 지방 2g | (기준: 100g)",
        "metadata": {"name": "그릭요거트", "category": "유제품", "meal_time": "아침,간식", "goal_tag": "일반,다이어트,근육증가", "source": "sample"},
    },
    {
        "text": "토스트+계란 아침 세트 | 분류: 양식 | 칼로리 380kcal | 탄수화물 38g | 단백질 18g | 지방 16g | (기준: 식빵 2장+계란 2개)",
        "metadata": {"name": "토스트+계란", "category": "양식", "meal_time": "아침", "goal_tag": "일반,근육증가", "source": "sample"},
    },
    {
        "text": "바나나+그릭요거트 아침 조합 | 분류: 간식 | 칼로리 200kcal | 탄수화물 33g | 단백질 11g | 지방 2g | (기준: 바나나 1개+요거트 100g)",
        "metadata": {"name": "바나나+그릭요거트", "category": "간식", "meal_time": "아침,간식", "goal_tag": "일반,다이어트", "source": "sample"},
    },
    {
        "text": "잡곡죽 | 분류: 한식 | 칼로리 180kcal | 탄수화물 36g | 단백질 4g | 지방 1g | 식이섬유 2g | (기준: 1인분 300g)",
        "metadata": {"name": "잡곡죽", "category": "한식", "meal_time": "아침", "goal_tag": "일반,당뇨", "source": "sample"},
    },

    # ── 밥류 ──────────────────────────────────────────────────────────
    {
        "text": "쌀밥 | 분류: 한식 | 칼로리 313kcal | 탄수화물 68g | 단백질 5g | 지방 0.5g | (기준: 한 공기 210g)",
        "metadata": {"name": "쌀밥", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반", "source": "sample"},
    },
    {
        "text": "잡곡밥 | 분류: 한식 | 칼로리 290kcal | 탄수화물 60g | 단백질 7g | 지방 1.5g | 식이섬유 3g | (기준: 한 공기 210g)",
        "metadata": {"name": "잡곡밥", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트,당뇨", "source": "sample"},
    },
    {
        "text": "현미밥 | 분류: 한식 | 칼로리 280kcal | 탄수화물 58g | 단백질 6g | 지방 2g | 식이섬유 4g | (기준: 한 공기 210g)",
        "metadata": {"name": "현미밥", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트,당뇨", "source": "sample"},
    },
    {
        "text": "비빔밥 | 분류: 한식 | 칼로리 560kcal | 탄수화물 90g | 단백질 18g | 지방 12g | 나트륨 800mg | (기준: 1인분)",
        "metadata": {"name": "비빔밥", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반", "source": "sample"},
    },
    {
        "text": "볶음밥 | 분류: 한식 | 칼로리 480kcal | 탄수화물 72g | 단백질 15g | 지방 14g | 나트륨 900mg | (기준: 1인분)",
        "metadata": {"name": "볶음밥", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반", "source": "sample"},
    },

    # ── 국/찌개 ───────────────────────────────────────────────────────
    {
        "text": "된장찌개 | 분류: 한식 | 칼로리 180kcal | 탄수화물 12g | 단백질 14g | 지방 7g | 나트륨 1200mg | (기준: 1인분)",
        "metadata": {"name": "된장찌개", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반", "source": "sample"},
    },
    {
        "text": "김치찌개 | 분류: 한식 | 칼로리 200kcal | 탄수화물 8g | 단백질 15g | 지방 10g | 나트륨 1400mg | (기준: 1인분)",
        "metadata": {"name": "김치찌개", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반", "source": "sample"},
    },
    {
        "text": "순두부찌개 | 분류: 한식 | 칼로리 180kcal | 탄수화물 6g | 단백질 14g | 지방 9g | 나트륨 1100mg | (기준: 1인분)",
        "metadata": {"name": "순두부찌개", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트", "source": "sample"},
    },
    {
        "text": "미역국 | 분류: 한식 | 칼로리 60kcal | 탄수화물 5g | 단백질 4g | 지방 2g | 나트륨 600mg | (기준: 1인분)",
        "metadata": {"name": "미역국", "category": "한식", "meal_time": "아침,점심,저녁", "goal_tag": "일반,다이어트", "source": "sample"},
    },
    {
        "text": "갈비탕 | 분류: 한식 | 칼로리 450kcal | 탄수화물 10g | 단백질 40g | 지방 25g | 나트륨 900mg | (기준: 1인분)",
        "metadata": {"name": "갈비탕", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반,근육증가", "source": "sample"},
    },
    {
        "text": "설렁탕 | 분류: 한식 | 칼로리 380kcal | 탄수화물 15g | 단백질 35g | 지방 18g | 나트륨 800mg | (기준: 1인분)",
        "metadata": {"name": "설렁탕", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반,근육증가", "source": "sample"},
    },
    {
        "text": "삼계탕 | 분류: 한식 | 칼로리 480kcal | 탄수화물 30g | 단백질 42g | 지방 18g | 나트륨 700mg | (기준: 1인분)",
        "metadata": {"name": "삼계탕", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반,근육증가", "source": "sample"},
    },
    {
        "text": "콩나물국 | 분류: 한식 | 칼로리 40kcal | 탄수화물 4g | 단백질 3g | 지방 1g | 나트륨 500mg | (기준: 1인분)",
        "metadata": {"name": "콩나물국", "category": "한식", "meal_time": "아침,점심,저녁", "goal_tag": "일반,다이어트,고혈압", "source": "sample"},
    },
    {
        "text": "북어국 | 분류: 한식 | 칼로리 90kcal | 탄수화물 3g | 단백질 14g | 지방 2g | 나트륨 700mg | (기준: 1인분)",
        "metadata": {"name": "북어국", "category": "한식", "meal_time": "아침,점심", "goal_tag": "일반,다이어트", "source": "sample"},
    },

    # ── 육류 반찬 ─────────────────────────────────────────────────────
    {
        "text": "닭가슴살 100g | 분류: 단백질식품 | 칼로리 165kcal | 탄수화물 0g | 단백질 31g | 지방 3.6g | (기준: 100g)",
        "metadata": {"name": "닭가슴살", "category": "단백질식품", "meal_time": "점심,저녁", "goal_tag": "다이어트,근육증가", "source": "sample"},
    },
    {
        "text": "삼겹살 200g | 분류: 육류 | 칼로리 680kcal | 탄수화물 0g | 단백질 34g | 지방 60g | (기준: 200g)",
        "metadata": {"name": "삼겹살", "category": "육류", "meal_time": "저녁", "goal_tag": "일반,근육증가", "source": "sample"},
    },
    {
        "text": "불고기 | 분류: 한식 | 칼로리 300kcal | 탄수화물 15g | 단백질 28g | 지방 14g | 나트륨 600mg | (기준: 1인분 150g)",
        "metadata": {"name": "불고기", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반,근육증가", "source": "sample"},
    },
    {
        "text": "제육볶음 | 분류: 한식 | 칼로리 380kcal | 탄수화물 10g | 단백질 28g | 지방 25g | 나트륨 900mg | (기준: 1인분 150g)",
        "metadata": {"name": "제육볶음", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반", "source": "sample"},
    },
    {
        "text": "닭볶음탕 | 분류: 한식 | 칼로리 350kcal | 탄수화물 12g | 단백질 32g | 지방 18g | 나트륨 1000mg | (기준: 1인분)",
        "metadata": {"name": "닭볶음탕", "category": "한식", "meal_time": "점심,저녁", "goal_tag": "일반", "source": "sample"},
    },
    {
        "text": "돼지갈비 | 분류: 육류 | 칼로리 550kcal | 탄수화물 20g | 단백질 35g | 지방 35g | (기준: 1인분 200g)",
        "metadata": {"name": "돼지갈비", "category": "육류", "meal_time": "저녁", "goal_tag": "일반,근육증가", "source": "sample"},
    },
    {
        "text": "소고기 등심 스테이크 150g | 분류: 육류 | 칼로리 400kcal | 탄수화물 0g | 단백질 40g | 지방 25g | (기준: 150g)",
        "metadata": {"name": "소고기스테이크", "category": "육류", "meal_time": "저녁", "goal_tag": "일반,근육증가", "source": "sample"},
    },
    {
        "text": "닭가슴살 샐러드 | 분류: 샐러드 | 칼로리 250kcal | 탄수화물 10g | 단백질 35g | 지방 5g | (기준: 1인분)",
        "metadata": {"name": "닭가슴살샐러드", "category": "샐러드", "meal_time": "점심,저녁", "goal_tag": "다이어트,근육증가", "source": "sample"},
    },

    # ── 생선/해산물 ───────────────────────────────────────────────────
    {
        "text": "연어 100g | 분류: 생선 | 칼로리 208kcal | 탄수화물 0g | 단백질 20g | 지방 13g | (기준: 100g)",
        "metadata": {"name": "연어", "category": "생선", "meal_time": "점심,저녁", "goal_tag": "일반,고혈압,근육증가", "source": "sample"},
    },
    {
        "text": "고등어구이 | 분류: 생선 | 칼로리 220kcal | 탄수화물 0g | 단백질 22g | 지방 14g | (기준: 1토막 100g)",
        "metadata": {"name": "고등어구이", "category": "생선", "meal_time": "점심,저녁", "goal_tag": "일반,고혈압", "source": "sample"},
    },
    {
        "text": "갈치구이 | 분류: 생선 | 칼로리 180kcal | 탄수화물 0g | 단백질 22g | 지방 9g | (기준: 1토막 100g)",
        "metadata": {"name": "갈치구이", "category": "생선", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트", "source": "sample"},
    },
    {
        "text": "참치통조림 100g | 분류: 생선 | 칼로리 130kcal | 탄수화물 0g | 단백질 28g | 지방 1g | 나트륨 400mg | (기준: 100g)",
        "metadata": {"name": "참치통조림", "category": "생선", "meal_time": "아침,점심,저녁", "goal_tag": "다이어트,근육증가", "source": "sample"},
    },
    {
        "text": "새우 100g | 분류: 해산물 | 칼로리 85kcal | 탄수화물 0g | 단백질 18g | 지방 1g | (기준: 100g)",
        "metadata": {"name": "새우", "category": "해산물", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트,근육증가", "source": "sample"},
    },

    # ── 면류 ──────────────────────────────────────────────────────────
    {
        "text": "냉면 | 분류: 한식 | 칼로리 520kcal | 탄수화물 90g | 단백질 15g | 지방 5g | 나트륨 1300mg | (기준: 1인분)",
        "metadata": {"name": "냉면", "category": "한식", "meal_time": "점심", "goal_tag": "일반", "source": "sample"},
    },
    {
        "text": "잔치국수 | 분류: 한식 | 칼로리 400kcal | 탄수화물 72g | 단백질 12g | 지방 5g | 나트륨 1000mg | (기준: 1인분)",
        "metadata": {"name": "잔치국수", "category": "한식", "meal_time": "점심", "goal_tag": "일반", "source": "sample"},
    },
    {
        "text": "라면 | 분류: 한식 | 칼로리 480kcal | 탄수화물 72g | 단백질 10g | 지방 16g | 나트륨 2000mg | (기준: 1봉지)",
        "metadata": {"name": "라면", "category": "한식", "meal_time": "점심,저녁,간식", "goal_tag": "일반", "source": "sample"},
    },
    {
        "text": "쌀국수 | 분류: 동남아 | 칼로리 380kcal | 탄수화물 68g | 단백질 14g | 지방 5g | 나트륨 900mg | (기준: 1인분)",
        "metadata": {"name": "쌀국수", "category": "동남아", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트", "source": "sample"},
    },
    {
        "text": "우동 | 분류: 일식 | 칼로리 420kcal | 탄수화물 76g | 단백질 14g | 지방 5g | 나트륨 1200mg | (기준: 1인분)",
        "metadata": {"name": "우동", "category": "일식", "meal_time": "점심,저녁", "goal_tag": "일반", "source": "sample"},
    },

    # ── 두부/채소 반찬 ───────────────────────────────────────────────
    {
        "text": "두부 100g | 분류: 두부/콩류 | 칼로리 76kcal | 탄수화물 2g | 단백질 8g | 지방 4g | (기준: 100g)",
        "metadata": {"name": "두부", "category": "두부/콩류", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트,당뇨", "source": "sample"},
    },
    {
        "text": "두부구이 | 분류: 두부/콩류 | 칼로리 150kcal | 탄수화물 3g | 단백질 12g | 지방 9g | (기준: 1인분 150g)",
        "metadata": {"name": "두부구이", "category": "두부/콩류", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트", "source": "sample"},
    },
    {
        "text": "시금치나물 | 분류: 나물 | 칼로리 50kcal | 탄수화물 3g | 단백질 3g | 지방 2g | 나트륨 300mg | (기준: 1인분 80g)",
        "metadata": {"name": "시금치나물", "category": "나물", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트,고혈압", "source": "sample"},
    },
    {
        "text": "콩나물무침 | 분류: 나물 | 칼로리 30kcal | 탄수화물 3g | 단백질 2g | 지방 1g | 나트륨 200mg | (기준: 1인분 80g)",
        "metadata": {"name": "콩나물무침", "category": "나물", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트,고혈압", "source": "sample"},
    },
    {
        "text": "브로콜리 100g | 분류: 채소 | 칼로리 55kcal | 탄수화물 11g | 단백질 4g | 지방 0.5g | 식이섬유 5g | 비타민C 90mg | (기준: 100g)",
        "metadata": {"name": "브로콜리", "category": "채소", "meal_time": "점심,저녁", "goal_tag": "일반,다이어트,당뇨,고혈압", "source": "sample"},
    },
    {
        "text": "김치 100g | 분류: 발효식품 | 칼로리 15kcal | 탄수화물 2g | 단백질 1g | 지방 0.3g | 나트륨 700mg | (기준: 100g)",
        "metadata": {"name": "김치", "category": "발효식품", "meal_time": "점심,저녁", "goal_tag": "일반", "source": "sample"},
    },
    {
        "text": "채소 샐러드 | 분류: 샐러드 | 칼로리 80kcal | 탄수화물 12g | 단백질 3g | 지방 2g | (기준: 1인분 200g)",
        "metadata": {"name": "채소샐러드", "category": "샐러드", "meal_time": "아침,점심,저녁", "goal_tag": "일반,다이어트", "source": "sample"},
    },

    # ── 계란/유제품 ───────────────────────────────────────────────────
    {
        "text": "계란 1개 | 분류: 계란 | 칼로리 90kcal | 탄수화물 0.6g | 단백질 7.5g | 지방 6g | (기준: 60g)",
        "metadata": {"name": "계란", "category": "계란", "meal_time": "아침,점심,저녁,간식", "goal_tag": "일반,다이어트,근육증가", "source": "sample"},
    },
    {
        "text": "삶은달걀 2개 | 분류: 계란 | 칼로리 155kcal | 탄수화물 1g | 단백질 13g | 지방 11g | (기준: 120g)",
        "metadata": {"name": "삶은달걀", "category": "계란", "meal_time": "아침,간식", "goal_tag": "다이어트,근육증가", "source": "sample"},
    },
    {
        "text": "스크램블에그 | 분류: 계란 | 칼로리 200kcal | 탄수화물 2g | 단백질 14g | 지방 15g | (기준: 계란 2개+버터)",
        "metadata": {"name": "스크램블에그", "category": "계란", "meal_time": "아침", "goal_tag": "일반,근육증가", "source": "sample"},
    },
    {
        "text": "우유 200ml | 분류: 유제품 | 칼로리 130kcal | 탄수화물 10g | 단백질 6.5g | 지방 7g | 칼슘 240mg | (기준: 200ml)",
        "metadata": {"name": "우유", "category": "유제품", "meal_time": "아침,간식", "goal_tag": "일반", "source": "sample"},
    },

    # ── 과일 ──────────────────────────────────────────────────────────
    {
        "text": "바나나 1개 | 분류: 과일 | 칼로리 107kcal | 탄수화물 27g | 단백질 1.3g | 지방 0.4g | 칼륨 390mg | (기준: 120g)",
        "metadata": {"name": "바나나", "category": "과일", "meal_time": "아침,간식", "goal_tag": "일반,고혈압", "source": "sample"},
    },
    {
        "text": "사과 1개 | 분류: 과일 | 칼로리 80kcal | 탄수화물 21g | 단백질 0.3g | 지방 0.2g | 식이섬유 4g | (기준: 중간 크기 150g)",
        "metadata": {"name": "사과", "category": "과일", "meal_time": "아침,간식", "goal_tag": "일반,다이어트", "source": "sample"},
    },
    {
        "text": "블루베리 100g | 분류: 과일 | 칼로리 57kcal | 탄수화물 14g | 단백질 0.7g | 지방 0.3g | 식이섬유 2.4g | (기준: 100g)",
        "metadata": {"name": "블루베리", "category": "과일", "meal_time": "아침,간식", "goal_tag": "일반,다이어트,당뇨", "source": "sample"},
    },
    {
        "text": "아보카도 100g | 분류: 과일 | 칼로리 160kcal | 탄수화물 9g | 단백질 2g | 지방 15g | 식이섬유 7g | (기준: 100g)",
        "metadata": {"name": "아보카도", "category": "과일", "meal_time": "아침,간식", "goal_tag": "일반,고혈압", "source": "sample"},
    },
    {
        "text": "딸기 100g | 분류: 과일 | 칼로리 33kcal | 탄수화물 8g | 단백질 0.7g | 지방 0.3g | 비타민C 60mg | (기준: 100g)",
        "metadata": {"name": "딸기", "category": "과일", "meal_time": "아침,간식", "goal_tag": "일반,다이어트", "source": "sample"},
    },

    # ── 간식 ──────────────────────────────────────────────────────────
    {
        "text": "고구마 100g | 분류: 간식 | 칼로리 128kcal | 탄수화물 30g | 단백질 1.5g | 지방 0.1g | 식이섬유 3g | (기준: 100g)",
        "metadata": {"name": "고구마", "category": "간식", "meal_time": "아침,간식", "goal_tag": "일반,다이어트", "source": "sample"},
    },
    {
        "text": "아몬드 30g | 분류: 견과류 | 칼로리 174kcal | 탄수화물 6g | 단백질 6g | 지방 15g | (기준: 30g, 약 23알)",
        "metadata": {"name": "아몬드", "category": "견과류", "meal_time": "간식", "goal_tag": "일반,다이어트,고혈압", "source": "sample"},
    },
    {
        "text": "호두 30g | 분류: 견과류 | 칼로리 196kcal | 탄수화물 4g | 단백질 4.6g | 지방 19g | (기준: 30g)",
        "metadata": {"name": "호두", "category": "견과류", "meal_time": "간식", "goal_tag": "일반,고혈압", "source": "sample"},
    },
    {
        "text": "프로틴바 | 분류: 건강식 | 칼로리 250kcal | 탄수화물 25g | 단백질 20g | 지방 8g | (기준: 1개 60g)",
        "metadata": {"name": "프로틴바", "category": "건강식", "meal_time": "간식", "goal_tag": "근육증가,다이어트", "source": "sample"},
    },
    {
        "text": "단백질 쉐이크 | 분류: 건강식 | 칼로리 150kcal | 탄수화물 10g | 단백질 25g | 지방 2g | (기준: 1스쿱+물 300ml)",
        "metadata": {"name": "단백질쉐이크", "category": "건강식", "meal_time": "간식", "goal_tag": "근육증가", "source": "sample"},
    },

    # ── 건강기능식품 ──────────────────────────────────────────────────
    {
        "text": "오메가3 | 분류: 건강기능식품 | EPA/DHA 지방산 보충. 혈중 중성지방 감소, 심혈관 건강 개선 효과. 하루 1~2캡슐 권장. 혈압약 복용자는 의사 상담 필요.",
        "metadata": {"name": "오메가3", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품,고혈압", "source": "sample"},
    },
    {
        "text": "비타민C | 분류: 건강기능식품 | 항산화 작용, 면역력 강화, 콜라겐 합성 촉진. 하루 500~1000mg 권장. 과다 복용 시 소화장애 주의.",
        "metadata": {"name": "비타민C", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품", "source": "sample"},
    },
    {
        "text": "비타민D | 분류: 건강기능식품 | 칼슘 흡수 촉진, 뼈 건강, 면역 기능 강화. 하루 1000~2000IU 권장. 야외활동 부족 시 보충 권장.",
        "metadata": {"name": "비타민D", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품", "source": "sample"},
    },
    {
        "text": "마그네슘 | 분류: 건강기능식품 | 근육 이완, 신경 안정, 수면 개선 효과. 운동 후 근육 회복 보조. 하루 300~400mg 권장.",
        "metadata": {"name": "마그네슘", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품,근육증가", "source": "sample"},
    },
    {
        "text": "칼슘 | 분류: 건강기능식품 | 뼈와 치아 건강 유지, 골다공증 예방. 하루 1000mg 권장. 비타민D와 함께 복용 시 흡수율 향상.",
        "metadata": {"name": "칼슘", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품", "source": "sample"},
    },
    {
        "text": "철분 | 분류: 건강기능식품 | 빈혈 예방, 산소 운반 기능 보조. 여성·채식주의자 보충 권장. 하루 8~18mg. 비타민C와 함께 복용 시 흡수율 향상.",
        "metadata": {"name": "철분", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품", "source": "sample"},
    },
    {
        "text": "프로바이오틱스 | 분류: 건강기능식품 | 유익균 증식, 장 건강 개선, 면역력 향상. 아침 공복 또는 식후 복용. 유산균 100억~1000억 CFU 권장.",
        "metadata": {"name": "프로바이오틱스", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품", "source": "sample"},
    },
    {
        "text": "루테인 | 분류: 건강기능식품 | 눈 건강 보호, 황반변성 예방, 청색광 차단 효과. 하루 20mg 권장. 컴퓨터 사용이 많은 경우 권장.",
        "metadata": {"name": "루테인", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품", "source": "sample"},
    },
    {
        "text": "코엔자임Q10 | 분류: 건강기능식품 | 세포 에너지 생산, 항산화, 심장 건강 보조. 하루 100~200mg 권장. 스타틴 계열 약 복용자에게 특히 권장.",
        "metadata": {"name": "코엔자임Q10", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품,고혈압", "source": "sample"},
    },
    {
        "text": "콜라겐 | 분류: 건강기능식품 | 관절 건강, 피부 탄력 개선, 뼈 밀도 유지. 하루 5~10g 권장. 비타민C와 함께 복용 시 합성 촉진.",
        "metadata": {"name": "콜라겐", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품", "source": "sample"},
    },
    {
        "text": "글루코사민 | 분류: 건강기능식품 | 연골 보호, 관절염 증상 완화. 하루 1500mg 권장. 효과가 나타나는 데 2~3개월 소요.",
        "metadata": {"name": "글루코사민", "category": "건강기능식품", "meal_time": "all", "goal_tag": "건강기능식품", "source": "sample"},
    },

    # ── 질환별 식단 가이드라인 ────────────────────────────────────────
    {
        "text": "당뇨 식단 가이드라인 | 분류: 가이드라인 | 혈당지수(GI)가 낮은 식품 선택 권장. 쌀밥 대신 잡곡밥, 흰 빵 대신 통밀빵. 1회 탄수화물 45~60g 이하. 식이섬유 하루 25g 이상. 단 음료·과자·흰쌀밥 제한.",
        "metadata": {"name": "당뇨식단가이드", "category": "가이드라인", "meal_time": "all", "goal_tag": "당뇨", "source": "sample"},
    },
    {
        "text": "당뇨 추천 식품 | 분류: 가이드라인 | 잡곡밥, 귀리, 통밀, 채소류, 두부, 닭가슴살, 생선, 견과류, 블루베리. 피해야 할 식품: 흰쌀밥, 흰빵, 설탕, 과자, 음료수, 과일주스.",
        "metadata": {"name": "당뇨추천식품", "category": "가이드라인", "meal_time": "all", "goal_tag": "당뇨", "source": "sample"},
    },
    {
        "text": "고혈압 식단 가이드라인 | 분류: 가이드라인 | 나트륨 하루 2000mg 이하(소금 5g). 칼륨 풍부 식품(바나나, 감자, 채소) 섭취. 포화지방 줄이기. DASH 식단(채소, 과일, 저지방 유제품) 권장.",
        "metadata": {"name": "고혈압식단가이드", "category": "가이드라인", "meal_time": "all", "goal_tag": "고혈압", "source": "sample"},
    },
    {
        "text": "고혈압 주의·권장 식품 | 분류: 가이드라인 | 주의: 라면(나트륨 2000mg 이상), 김치(과다), 된장찌개, 가공육. 권장: 바나나, 시금치, 아보카도, 연어, 귀리, 저지방 유제품.",
        "metadata": {"name": "고혈압식품목록", "category": "가이드라인", "meal_time": "all", "goal_tag": "고혈압", "source": "sample"},
    },
    {
        "text": "다이어트 식단 가이드라인 | 분류: 가이드라인 | 하루 칼로리 결핍 500~750kcal 권장. 단백질 체중 1kg당 1.2~1.6g으로 근육 유지. 식이섬유 풍부한 채소로 포만감 유지. 가공식품·당류·포화지방 제한.",
        "metadata": {"name": "다이어트가이드", "category": "가이드라인", "meal_time": "all", "goal_tag": "다이어트", "source": "sample"},
    },
    {
        "text": "저염식 가이드라인 | 분류: 가이드라인 | 나트륨 하루 1500mg 이하. 국물 줄이기, 외식 시 소스 별도. 허브·레몬즙으로 맛 보완. 가공식품 라벨 확인 필수.",
        "metadata": {"name": "저염식가이드", "category": "가이드라인", "meal_time": "all", "goal_tag": "고혈압,저염식", "source": "sample"},
    },
    {
        "text": "운동 후 회복 식단 | 분류: 가이드라인 | 운동 30분~1시간 내 단백질 20~40g + 탄수화물 40~80g 섭취. 근육 회복과 글리코겐 보충 목적. 추천 조합: 닭가슴살+고구마, 계란+바나나, 그릭요거트+오트밀.",
        "metadata": {"name": "운동후회복식단", "category": "가이드라인", "meal_time": "간식", "goal_tag": "근육증가", "source": "sample"},
    },
    {
        "text": "근육 증가 식단 가이드라인 | 분류: 가이드라인 | 단백질 체중 1kg당 1.6~2.2g. 칼로리 잉여 200~300kcal 유지. 탄수화물로 운동 에너지 공급. 매 3~4시간마다 단백질 섭취 권장.",
        "metadata": {"name": "근육증가가이드", "category": "가이드라인", "meal_time": "all", "goal_tag": "근육증가", "source": "sample"},
    },
    {
        "text": "심혈관 건강 식단 | 분류: 가이드라인 | 오메가3 풍부한 등푸른 생선 주 2회 이상. 포화지방 줄이고 불포화지방(올리브유, 견과류) 늘리기. 채소·과일·통곡물 중심. 트랜스지방 완전 제거.",
        "metadata": {"name": "심혈관건강가이드", "category": "가이드라인", "meal_time": "all", "goal_tag": "고혈압,일반", "source": "sample"},
    },
    {
        "text": "고단백 저칼로리 식품 목록 | 분류: 가이드라인 | 닭가슴살(165kcal/100g), 참치통조림(130kcal/100g), 새우(85kcal/100g), 그릭요거트(100kcal/100g), 두부(76kcal/100g), 달걀흰자(52kcal/100g). 다이어트·근육증가 모두 적합.",
        "metadata": {"name": "고단백저칼로리목록", "category": "가이드라인", "meal_time": "all", "goal_tag": "다이어트,근육증가", "source": "sample"},
    },
    {
        "text": "식이섬유 풍부 식품 | 분류: 가이드라인 | 귀리(10g/100g), 아보카도(7g/100g), 브로콜리(5g/100g), 고구마(3g/100g), 잡곡밥(3g/100g), 블루베리(2.4g/100g). 하루 25~30g 목표.",
        "metadata": {"name": "식이섬유식품목록", "category": "가이드라인", "meal_time": "all", "goal_tag": "당뇨,다이어트,일반", "source": "sample"},
    },

    # ── 추천 식단 조합 ────────────────────────────────────────────────
    {
        "text": "다이어트 1일 식단 예시 | 분류: 식단조합 | 아침: 계란 2개+고구마 100g+채소샐러드(400kcal), 점심: 닭가슴살 150g+잡곡밥 반공기+미역국(500kcal), 저녁: 두부구이+채소볶음+잡곡밥 반공기(400kcal). 총 1300kcal.",
        "metadata": {"name": "다이어트1일식단", "category": "식단조합", "meal_time": "all", "goal_tag": "다이어트", "source": "sample"},
    },
    {
        "text": "당뇨 1일 식단 예시 | 분류: 식단조합 | 아침: 잡곡밥+두부된장찌개+나물(탄수화물 50g), 점심: 잡곡밥+닭가슴살구이+채소(탄수화물 55g), 저녁: 잡곡밥+생선구이+채소볶음(탄수화물 50g). 규칙적인 식사 간격 유지.",
        "metadata": {"name": "당뇨1일식단", "category": "식단조합", "meal_time": "all", "goal_tag": "당뇨", "source": "sample"},
    },
    {
        "text": "고혈압 저염 1일 식단 예시 | 분류: 식단조합 | 아침: 오트밀+바나나+저지방우유(나트륨 200mg), 점심: 잡곡밥+닭가슴살+채소샐러드(나트륨 500mg), 저녁: 연어구이+고구마+채소(나트륨 400mg). 총 나트륨 1100mg.",
        "metadata": {"name": "고혈압저염식단", "category": "식단조합", "meal_time": "all", "goal_tag": "고혈압", "source": "sample"},
    },
    {
        "text": "근육증가 1일 식단 예시 | 분류: 식단조합 | 아침: 스크램블에그+오트밀+바나나(550kcal), 점심: 닭가슴살 200g+쌀밥+채소(650kcal), 운동후간식: 단백질쉐이크+바나나(250kcal), 저녁: 연어+현미밥+채소(500kcal). 총 약 1950kcal.",
        "metadata": {"name": "근육증가1일식단", "category": "식단조합", "meal_time": "all", "goal_tag": "근육증가", "source": "sample"},
    },
    {
        "text": "저칼로리 아침 식단 옵션 | 분류: 식단조합 | 옵션A: 그릭요거트+블루베리(157kcal). 옵션B: 삶은달걀 2개+채소샐러드(235kcal). 옵션C: 오트밀+아몬드 10g(358kcal). 모두 단백질 충분, 포만감 유지.",
        "metadata": {"name": "저칼로리아침옵션", "category": "식단조합", "meal_time": "아침", "goal_tag": "다이어트", "source": "sample"},
    },
    {
        "text": "운동 전 식사 추천 | 분류: 식단조합 | 운동 1~2시간 전: 바나나+오트밀(약 400kcal, 탄수화물 중심). 운동 30분 전: 바나나 1개(107kcal). 소화하기 쉬운 탄수화물로 에너지 공급. 지방·고섬유 식품은 운동 직전 피하기.",
        "metadata": {"name": "운동전식사", "category": "식단조합", "meal_time": "간식", "goal_tag": "근육증가,일반", "source": "sample"},
    },
]


def get_all_docs() -> list[str]:
    return [item["text"] for item in NUTRITION_ITEMS]


def get_all_items() -> list[tuple[str, dict]]:
    """(텍스트, 메타데이터) 쌍 반환 — ChromaDB 빌드용"""
    return [(item["text"], item["metadata"]) for item in NUTRITION_ITEMS]
