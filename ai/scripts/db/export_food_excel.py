"""
두 영양DB 합치기 → Excel 파일 내보내기

실행:
  python -m ai.scripts.db.export_food_excel
"""
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import pandas as pd

DATA_DIR   = REPO_ROOT / "data" / "nutrition_db"
XLSX_19495 = DATA_DIR / "20251229_음식DB 19495건.xlsx"
XLSX_400   = DATA_DIR / "음식분류_AI_데이터_영양DB.xlsx"
OUTPUT     = DATA_DIR / "음식DB_통합_15709건.xlsx"

CATEGORY_RULES = [
    ("밥류",             ["밥", "볶음밥", "비빔밥", "덮밥", "솥밥", "주먹밥", "김밥"]),
    ("면 및 만두류",      ["면", "라면", "국수", "파스타", "우동", "소면", "냉면", "만두", "떡볶이", "쫄면"]),
    ("국 및 탕류",        ["국", "탕", "곰탕", "설렁탕", "갈비탕", "육개장", "해장국", "삼계탕"]),
    ("찌개 및 전골류",    ["찌개", "전골", "된장찌개", "김치찌개", "순두부"]),
    ("구이류",            ["구이", "삼겹살", "갈비", "불고기", "바베큐", "바비큐", "BBQ", "스테이크"]),
    ("볶음류",            ["볶음", "볶은", "제육볶음", "낙지볶음", "오징어볶음"]),
    ("튀김류",            ["튀김", "치킨", "돈가스", "탕수육", "까스"]),
    ("찜류",              ["찜", "갈비찜", "아귀찜", "닭찜"]),
    ("전·적 및 부침류",   ["전", "부침", "전병", "부꾸미", "파전", "해물파전", "동그랑땡"]),
    ("생채·무침류",       ["무침", "생채", "겉절이", "냉채"]),
    ("나물·숙채류",       ["나물", "숙채", "시금치나물", "콩나물", "취나물"]),
    ("조림류",            ["조림", "졸임", "장조림", "생선조림"]),
    ("죽 및 스프류",      ["죽", "스프", "스튜", "포리지"]),
    ("김치류",            ["김치", "깍두기", "총각김치", "백김치"]),
    ("빵 및 과자류",      ["빵", "케이크", "쿠키", "과자", "크래커", "도넛", "마카롱", "머핀", "와플"]),
    ("음료 및 차류",      ["음료", "주스", "차", "커피", "라떼", "스무디", "쉐이크", "콜라", "사이다"]),
    ("유제품류 및 빙과류",["우유", "요거트", "치즈", "아이스크림", "빙과"]),
    ("장류, 양념류",      ["간장", "된장", "고추장", "쌈장", "소스", "드레싱"]),
    ("젓갈류",            ["젓갈", "명란", "오징어젓", "새우젓"]),
    ("과일류",            ["사과", "배", "수박", "딸기", "바나나", "오렌지", "포도", "복숭아", "망고"]),
    ("두류, 견과 및 종실류", ["두부", "콩", "견과", "아몬드", "호두", "땅콩", "잣"]),
    ("수·조·어·육류",    ["닭가슴살", "삼겹살", "생선", "연어", "참치", "고등어", "오징어", "새우"]),
]


def assign_category(food_name: str) -> str:
    name = food_name.lower()
    for category, keywords in CATEGORY_RULES:
        for kw in keywords:
            if kw in name:
                return category
    return "기타"


def fval(v, default: float = 0.0) -> float:
    try:
        return float(v) if v is not None and str(v).strip() not in ("", "-", "nan") else default
    except (TypeError, ValueError):
        return default


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    print("19,495건 DB 로드 중...")
    df_big = pd.read_excel(XLSX_19495, engine="openpyxl")
    df_big = df_big.dropna(subset=["식품명", "에너지(kcal)"])
    df_big = df_big.drop_duplicates(subset=["식품명"])
    df_big["식품대분류명"] = df_big["식품대분류명"].fillna("기타")
    print(f"  → {len(df_big):,}건")

    print("400건 DB 로드 중...")
    df_small = pd.read_excel(XLSX_400, engine="openpyxl")
    df_small.columns = df_small.columns.str.strip()
    df_small = df_small.rename(columns={"음 식 명": "식품명"})
    df_small = df_small.dropna(subset=["식품명", "에너지(kcal)"])
    df_small = df_small.drop_duplicates(subset=["식품명"])
    print(f"  → {len(df_small):,}건")

    big_names = set(df_big["식품명"].str.strip())
    rows = []

    # 19,495건
    for _, row in df_big.iterrows():
        rows.append({
            "번호":         len(rows) + 1,
            "음식명":        str(row["식품명"]).strip(),
            "카테고리":      str(row.get("식품대분류명", "기타")),
            "에너지(kcal)": fval(row.get("에너지(kcal)")),
            "탄수화물(g)":   fval(row.get("탄수화물(g)")),
            "당류(g)":       fval(row.get("당류(g)")),
            "지방(g)":       fval(row.get("지방(g)")),
            "단백질(g)":     fval(row.get("단백질(g)")),
            "나트륨(mg)":    fval(row.get("나트륨(mg)")),
            "콜레스테롤(mg)":fval(row.get("콜레스테롤(mg)")),
            "식이섬유(g)":   fval(row.get("식이섬유(g)")),
            "출처":          "식약처 식품영양성분DB",
        })

    # 400건 중 신규
    added = skipped = 0
    for _, row in df_small.iterrows():
        name = str(row["식품명"]).strip()
        if name in big_names:
            skipped += 1
            continue
        rows.append({
            "번호":          len(rows) + 1,
            "음식명":         name,
            "카테고리":       assign_category(name),
            "에너지(kcal)":  fval(row.get("에너지(kcal)")),
            "탄수화물(g)":    fval(row.get("탄수화물(g)")),
            "당류(g)":        fval(row.get("당류(g)")),
            "지방(g)":        fval(row.get("지방(g)")),
            "단백질(g)":      fval(row.get("단백질(g)")),
            "나트륨(mg)":     fval(row.get("나트륨(mg)")),
            "콜레스테롤(mg)": fval(row.get("콜레스테롤(mg)")),
            "식이섬유(g)":    fval(row.get("식이섬유(g)")),
            "출처":           "음식분류 AI 데이터 영양DB",
        })
        added += 1

    print(f"\n합치기 결과: 19,495건 전체 + 400건 중 {added}건 추가 (중복 {skipped}건 제외)")
    print(f"최종: {len(rows):,}건\n")

    df_out = pd.DataFrame(rows)

    with pd.ExcelWriter(OUTPUT, engine="openpyxl") as writer:
        df_out.to_excel(writer, index=False, sheet_name="음식DB_통합")

        # 카테고리별 시트
        for cat, grp in df_out.groupby("카테고리"):
            safe_name = str(cat)[:31]  # 시트명 31자 제한
            grp.reset_index(drop=True).to_excel(writer, index=False, sheet_name=safe_name)

    size_mb = OUTPUT.stat().st_size / 1024 / 1024
    print(f"저장 완료: {OUTPUT}")
    print(f"파일 크기: {size_mb:.1f} MB")
    print(f"시트 구성: 음식DB_통합 (전체) + 카테고리별 시트")


if __name__ == "__main__":
    main()
