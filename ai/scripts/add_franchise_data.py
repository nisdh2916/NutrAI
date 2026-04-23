"""
프랜차이즈/편의점 영양 데이터를 가공식품 CSV에서 추출하여 ChromaDB에 추가하는 스크립트.
기존 음식 DB(247,770건)에 프랜차이즈 메뉴 데이터를 보강한다.
"""

import csv
import sys
from pathlib import Path

import chromadb
from sentence_transformers import SentenceTransformer

# ── 설정 ──
BASE_DIR = Path(__file__).resolve().parent.parent.parent
CHROMA_DIR = BASE_DIR / "ai" / "rag_engine" / "chroma_db"
CSV_PATH = BASE_DIR / "data" / "nutrition_db" / "식품의약품안전처_통합식품영양성분정보(가공식품)_20260402.csv"
EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"

# 프랜차이즈 키워드 (제조사명 or 식품명에서 매칭)
FRANCHISE_KEYWORDS = [
    # 패스트푸드
    "맥도날드", "버거킹", "롯데리아", "맘스터치", "서브웨이", "KFC",
    # 카페
    "스타벅스", "투썸", "메가커피", "컴포즈", "이디야", "배스킨", "던킨",
    "빽다방", "할리스", "카페베네", "폴바셋", "블루보틀",
    # 치킨
    "BBQ", "교촌", "BHC", "굽네", "네네", "호식이", "페리카나", "처갓집",
    # 피자
    "도미노", "피자헛", "파파존스", "미스터피자", "피자알볼로",
    # 편의점
    "CU", "GS25", "세븐일레븐", "이마트24", "미니스톱",
    # 분식/기타
    "김밥천국", "본죽", "놀부", "한솥", "명랑핫도그",
    # 배달/외식
    "떡볶이", "족발", "보쌈", "찜닭", "삼겹살", "김치찌개",
    "된장찌개", "비빔밥", "불고기", "갈비탕", "설렁탕", "냉면",
    "짜장면", "짬뽕", "탕수육", "볶음밥", "제육볶음", "돈까스",
    "라멘", "우동", "초밥", "카레", "쌀국수",
]


def is_franchise(row: dict) -> bool:
    """프랜차이즈/배달 관련 데이터인지 판별"""
    text = (
        row.get("식품명", "")
        + " "
        + row.get("제조사명", "")
        + " "
        + row.get("유통업체명", "")
        + " "
        + row.get("식품대분류명", "")
    )
    return any(kw in text for kw in FRANCHISE_KEYWORDS)


def safe_float(val: str) -> float | None:
    """안전한 float 변환"""
    try:
        return float(val) if val and val.strip() else None
    except ValueError:
        return None


def build_document(row: dict) -> str:
    """ChromaDB에 저장할 텍스트 문서 생성"""
    name = row.get("식품명", "").strip()
    category = row.get("식품대분류명", "").strip()
    maker = row.get("제조사명", "").strip()
    serving = row.get("1회 섭취참고량", "").strip()
    base_amount = row.get("영양성분함량기준량", "").strip()

    parts = [name]
    if maker:
        parts[0] = f"{maker} {name}"
    if category:
        parts.append(f"분류: {category}")

    kcal = safe_float(row.get("에너지(kcal)", ""))
    carb = safe_float(row.get("탄수화물(g)", ""))
    protein = safe_float(row.get("단백질(g)", ""))
    fat = safe_float(row.get("지방(g)", ""))
    sodium = safe_float(row.get("나트륨(mg)", ""))
    sugar = safe_float(row.get("당류(g)", ""))
    sat_fat = safe_float(row.get("포화지방산(g)", ""))
    cholesterol = safe_float(row.get("콜레스테롤(mg)", ""))

    if kcal is not None:
        parts.append(f"칼로리 {kcal}kcal")
    if carb is not None:
        parts.append(f"탄수화물 {carb}g")
    if protein is not None:
        parts.append(f"단백질 {protein}g")
    if fat is not None:
        parts.append(f"지방 {fat}g")
    if sodium is not None:
        parts.append(f"나트륨 {sodium}mg")
    if sugar is not None:
        parts.append(f"당류 {sugar}g")
    if sat_fat is not None:
        parts.append(f"포화지방산 {sat_fat}g")
    if cholesterol is not None:
        parts.append(f"콜레스테롤 {cholesterol}mg")

    basis = serving or base_amount
    if basis:
        parts.append(f"(기준: {basis})")

    return " , ".join(parts)  # gemma4 호환: | 대신 , 사용


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    print("📂 가공식품 CSV에서 프랜차이즈/배달 데이터 추출 중...")
    rows = []
    with open(CSV_PATH, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if is_franchise(row):
                doc = build_document(row)
                if doc:
                    rows.append((row.get("식품코드", ""), doc))

    print(f"✅ 추출 완료: {len(rows)}건")

    if not rows:
        print("추가할 데이터가 없습니다.")
        return

    # 임베딩 모델 로드
    print("🔄 임베딩 모델 로드 중...")
    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = SentenceTransformer(EMBED_MODEL, device=device)
    print(f"  → 디바이스: {device}")

    # ChromaDB 연결
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    collection = client.get_collection("nutrition")
    existing_count = collection.count()
    print(f"📊 현재 ChromaDB 문서 수: {existing_count}")

    # 배치 임베딩 및 추가
    BATCH_SIZE = 2000
    added = 0
    for i in range(0, len(rows), BATCH_SIZE):
        batch = rows[i : i + BATCH_SIZE]
        ids = [f"franchise_{r[0]}_{i+j}" for j, r in enumerate(batch)]
        documents = [r[1] for r in batch]

        embeddings = model.encode(documents, show_progress_bar=False, convert_to_numpy=True)

        collection.add(
            ids=ids,
            documents=documents,
            embeddings=embeddings.tolist(),
        )
        added += len(batch)
        print(f"  → {added}/{len(rows)} 추가 완료")

    final_count = collection.count()
    print(f"\n🎉 완료! ChromaDB 문서 수: {existing_count} → {final_count} (+{final_count - existing_count})")


if __name__ == "__main__":
    main()
