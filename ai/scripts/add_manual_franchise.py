"""수동 작성한 프랜차이즈 메뉴 CSV를 ChromaDB에 추가"""

import csv
import sys
from pathlib import Path

import chromadb
from sentence_transformers import SentenceTransformer

BASE_DIR = Path(__file__).resolve().parent.parent.parent
CHROMA_DIR = BASE_DIR / "ai" / "rag_engine" / "chroma_db"
CSV_PATH = BASE_DIR / "data" / "nutrition_db" / "franchise_manual.csv"
EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    rows = []
    with open(CSV_PATH, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            brand = row["브랜드"].strip()
            menu = row["메뉴명"].strip()
            parts = [f"{brand} {menu}"]

            for col, unit in [
                ("칼로리(kcal)", "kcal"),
                ("탄수화물(g)", "g"),
                ("단백질(g)", "g"),
                ("지방(g)", "g"),
                ("나트륨(mg)", "mg"),
                ("당류(g)", "g"),
            ]:
                label = col.split("(")[0]
                val = row.get(col, "").strip()
                if val:
                    parts.append(f"{label} {val}{unit}")

            serving = row.get("1회제공량", "").strip()
            if serving:
                parts.append(f"(기준: {serving})")

            doc = " , ".join(parts)
            rows.append((f"manual_{brand}_{menu}", doc))

    print(f"📂 수동 프랜차이즈 데이터: {len(rows)}건")

    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = SentenceTransformer(EMBED_MODEL, device=device)

    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    collection = client.get_collection("nutrition")
    before = collection.count()

    documents = [r[1] for r in rows]
    ids = [r[0] for r in rows]
    embeddings = model.encode(documents, convert_to_numpy=True)

    collection.add(ids=ids, documents=documents, embeddings=embeddings.tolist())

    after = collection.count()
    print(f"✅ ChromaDB: {before} → {after} (+{after - before})")


if __name__ == "__main__":
    main()
