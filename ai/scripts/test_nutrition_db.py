"""
빠른 테스트용 (100건만 처리)
실행: .venv\Scripts\python ai\scripts\test_nutrition_db.py
"""
import sys
import pandas as pd
from pathlib import Path
from langchain.schema import Document
from langchain_community.vectorstores import Chroma
from langchain_community.embeddings import OllamaEmbeddings

REPO_ROOT = Path(__file__).parent.parent.parent
DATA_DIR = REPO_ROOT / "data" / "nutrition_db"
CHROMA_DIR = REPO_ROOT / "ai" / "rag_engine" / "chroma_db_test"
FOOD_CSV = DATA_DIR / "식품의약품안전처_통합식품영양성분정보(음식)_20251229 (1).csv"
OLLAMA_BASE_URL = "http://localhost:11434"
EMBED_MODEL = "qwen2.5:7b"


def safe(val, unit=""):
    if pd.isna(val): return ""
    return f"{round(float(val),1)}{unit}"


def row_to_doc(row, category="") -> str:
    name  = str(row.get("식품명", "")).strip()
    kcal  = safe(row.get("에너지(kcal)"), "kcal")
    carb  = safe(row.get("탄수화물(g)"), "g")
    prot  = safe(row.get("단백질(g)"), "g")
    fat   = safe(row.get("지방(g)"), "g")
    sod   = safe(row.get("나트륨(mg)"), "mg")
    fiber = safe(row.get("식이섬유(g)"), "g")

    parts = [name]
    if category: parts.append(f"분류: {category}")
    if kcal:  parts.append(f"칼로리 {kcal}")
    if carb:  parts.append(f"탄수화물 {carb}")
    if prot:  parts.append(f"단백질 {prot}")
    if fat:   parts.append(f"지방 {fat}")
    if sod:   parts.append(f"나트륨 {sod}")
    if fiber: parts.append(f"식이섬유 {fiber}")
    return " | ".join(parts)


def main():
    print("=== 테스트: 100건만 처리 ===")
    df = pd.read_csv(FOOD_CSV, encoding="utf-8", low_memory=False)
    df = df.dropna(subset=["식품명", "에너지(kcal)"]).drop_duplicates(subset=["식품명"], keep="first")
    df = df.head(100)

    docs = []
    for _, row in df.iterrows():
        cat = str(row.get("식품대분류명", ""))
        docs.append(Document(
            page_content=row_to_doc(row, cat),
            metadata={"source": "음식DB", "name": str(row.get("식품명", ""))}
        ))

    print(f"{len(docs)}개 문서 → embedding 시작...")

    if CHROMA_DIR.exists():
        import shutil
        shutil.rmtree(CHROMA_DIR)

    embeddings = OllamaEmbeddings(model=EMBED_MODEL, base_url=OLLAMA_BASE_URL)
    vectorstore = Chroma.from_documents(
        documents=docs,
        embedding=embeddings,
        persist_directory=str(CHROMA_DIR),
    )
    print("완료!")

    # 검색 테스트
    print("\n=== 검색 테스트: '다이어트에 좋은 밥' ===")
    results = vectorstore.similarity_search("다이어트에 좋은 밥", k=3)
    for r in results:
        print(f"  - {r.page_content[:80]}")


if __name__ == "__main__":
    main()
