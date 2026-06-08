"""
두 영양DB 합치기 + 카테고리 분류 + ChromaDB 구축

1. 19,495건 DB (식약처): 카테고리 있음, 상세 영양소
2. 400건 DB (외식메뉴): 카테고리 없음, 기본 영양소
   - 247개: 이름 매칭으로 카테고리 확보
   - 153개: 키워드 기반 카테고리 자동 분류

실행:
  python -m ai.scripts.db.build_combined_db
"""

import sys
import time
import json
from pathlib import Path

REPO_ROOT  = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import pandas as pd
import chromadb
from sentence_transformers import SentenceTransformer

DATA_DIR   = REPO_ROOT / "data" / "nutrition_db"
CHROMA_DIR = REPO_ROOT / "ai" / "rag_engine" / "chroma_db"
CHECKPOINT = REPO_ROOT / "ai" / "rag_engine" / "build_checkpoint.json"

XLSX_19495 = DATA_DIR / "20251229_음식DB 19495건.xlsx"
XLSX_400   = DATA_DIR / "음식분류_AI_데이터_영양DB.xlsx"
EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"
BATCH_SIZE  = 256

# ── 키워드 기반 카테고리 분류 규칙 ────────────────────────────
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


def load_19495() -> pd.DataFrame:
    print(f"19,495건 DB 로드 중...")
    df = pd.read_excel(XLSX_19495, engine="openpyxl")
    df = df.dropna(subset=["식품명", "에너지(kcal)"])
    df = df.drop_duplicates(subset=["식품명"])
    df["식품대분류명"] = df["식품대분류명"].fillna("기타")
    print(f"  → {len(df):,}건")
    return df


def load_400() -> pd.DataFrame:
    print(f"400건 DB 로드 중...")
    df = pd.read_excel(XLSX_400, engine="openpyxl")
    df.columns = df.columns.str.strip()
    df = df.rename(columns={"음 식 명": "식품명"})
    df = df.dropna(subset=["식품명", "에너지(kcal)"])
    df = df.drop_duplicates(subset=["식품명"])
    print(f"  → {len(df):,}건")
    return df


def build_combined(df_big: pd.DataFrame, df_small: pd.DataFrame) -> list[dict]:
    """
    두 DB 합치기:
    - 19,495건은 전부 포함 (카테고리 있음)
    - 400건 중 19,495에 없는 153건만 추가 (카테고리 자동 분류)
    """
    big_names = set(df_big["식품명"].str.strip())
    records = []

    # 1. 19,495건 전부
    for _, row in df_big.iterrows():
        records.append({
            "name":     str(row["식품명"]).strip(),
            "category": str(row.get("식품대분류명", "기타")),
            "kcal":     fval(row.get("에너지(kcal)")),
            "carb":     fval(row.get("탄수화물(g)")),
            "protein":  fval(row.get("단백질(g)")),
            "fat":      fval(row.get("지방(g)")),
            "sodium":   fval(row.get("나트륨(mg)")),
            "sugar":    fval(row.get("당류(g)")),
            "source":   "식약처 식품영양성분DB",
        })

    # 2. 400건 중 중복 아닌 것만 추가
    added = skipped = 0
    for _, row in df_small.iterrows():
        name = str(row["식품명"]).strip()
        if name in big_names:
            skipped += 1
            continue
        records.append({
            "name":     name,
            "category": assign_category(name),
            "kcal":     fval(row.get("에너지(kcal)")),
            "carb":     fval(row.get("탄수화물(g)")),
            "protein":  fval(row.get("단백질(g)")),
            "fat":      fval(row.get("지방(g)")),
            "sodium":   fval(row.get("나트륨(mg)")),
            "sugar":    fval(row.get("당류(g)")),
            "source":   "음식분류 AI 데이터 영양DB",
        })
        added += 1

    print(f"\n합치기 결과:")
    print(f"  19,495건 전체 포함")
    print(f"  400건 중 중복 제외 {skipped}건 스킵, {added}건 추가")
    print(f"  최종: {len(records):,}건")
    return records


def record_to_doc(r: dict) -> str:
    parts = [r["name"], f"카테고리: {r['category']}"]
    if r["kcal"]:  parts.append(f"칼로리 {r['kcal']}kcal")
    if r["carb"]:  parts.append(f"탄수화물 {r['carb']}g")
    if r["sugar"]: parts.append(f"당류 {r['sugar']}g")
    if r["fat"]:   parts.append(f"지방 {r['fat']}g")
    if r["protein"]: parts.append(f"단백질 {r['protein']}g")
    if r["sodium"]:  parts.append(f"나트륨 {r['sodium']}mg")
    parts.append(f"(출처: {r['source']})")
    return " | ".join(parts)


def tag_record(r: dict) -> dict:
    kcal, carb, sugar, fat, sodium, protein = (
        r["kcal"], r["carb"], r["sugar"], r["fat"], r["sodium"], r["protein"]
    )
    return {
        "is_diet":         (0 < kcal <= 400) or (protein >= 15 and fat <= 8 and 0 < kcal <= 500),
        "is_diabetes":     sugar <= 5 and carb <= 40 and kcal > 0,
        "is_hypertension": 0 < sodium <= 400,
    }


def load_checkpoint() -> int:
    if CHECKPOINT.exists():
        return json.loads(CHECKPOINT.read_text(encoding="utf-8")).get("done", 0)
    return 0


def save_checkpoint(done: int):
    CHECKPOINT.write_text(json.dumps({"done": done}), encoding="utf-8")


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"디바이스: {device.upper()}\n")

    df_big   = load_19495()
    df_small = load_400()
    records  = build_combined(df_big, df_small)

    texts = [record_to_doc(r) for r in records]
    metas = [{
        "source":   r["source"],
        "name":     r["name"],
        "category": r["category"],
        "kcal":     r["kcal"],
        "protein":  r["protein"],
        "fat":      r["fat"],
        "sodium":   r["sodium"],
        **tag_record(r),
    } for r in records]

    total = len(texts)
    start_from = load_checkpoint()
    if start_from > 0:
        print(f"\n체크포인트 발견: {start_from:,}건부터 이어서 시작")
    else:
        import shutil
        if CHROMA_DIR.exists():
            print("\n기존 ChromaDB 삭제 중...")
            shutil.rmtree(CHROMA_DIR)

    print(f"\n임베딩 모델 로드 중: {EMBED_MODEL}")
    model = SentenceTransformer(EMBED_MODEL, device=device)

    CHROMA_DIR.mkdir(parents=True, exist_ok=True)
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    collection = client.get_or_create_collection(
        name="nutrition",
        metadata={"hnsw:space": "l2"},
    )

    print(f"\nEmbedding 시작 (총 {total:,}건, 배치 {BATCH_SIZE}건씩)\n")
    start = time.time()

    for i in range(start_from, total, BATCH_SIZE):
        batch_texts = texts[i: i + BATCH_SIZE]
        batch_metas = metas[i: i + BATCH_SIZE]
        batch_ids   = [f"food_{j}" for j in range(i, i + len(batch_texts))]

        embeddings = model.encode(
            batch_texts,
            batch_size=64,
            show_progress_bar=False,
            convert_to_numpy=True,
        ).tolist()

        collection.add(
            ids=batch_ids,
            embeddings=embeddings,
            documents=batch_texts,
            metadatas=batch_metas,
        )

        done    = i + len(batch_texts)
        elapsed = time.time() - start
        speed   = (done - start_from) / elapsed if elapsed > 0 else 0
        pct     = done * 100 // total
        save_checkpoint(done)
        print(f"  [{pct:3d}%] {done:,}/{total:,}건  경과: {elapsed:.0f}초  속도: {speed:.0f}건/초", flush=True)

    CHECKPOINT.unlink(missing_ok=True)
    print(f"\n완료! 총 소요: {time.time() - start:.0f}초")
    print(f"ChromaDB 저장 위치: {CHROMA_DIR}")
    print(f"총 문서 수: {collection.count():,}건")
    print("서버를 재시작하면 새 데이터가 적용됩니다.")


if __name__ == "__main__":
    main()
