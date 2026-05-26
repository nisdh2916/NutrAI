"""의학 가이드라인 → ChromaDB 추가 스크립트

기존 nutrition_collection에 가이드라인 문서를 추가한다.
(별도 컬렉션 없이 동일 컬렉션에 넣어 RAG 검색에 통합)

실행:
    .venv\\Scripts\\python ai\\scripts\\db\\build_guidelines_db.py
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import chromadb
from sentence_transformers import SentenceTransformer

CHROMA_DIR  = REPO_ROOT / "ai" / "rag_engine" / "chroma_db"
GUIDE_DIR   = REPO_ROOT / "data" / "guidelines"
EMBED_MODEL = "snunlp/KR-SBERT-V40K-klueNLI-augSTS"
COLLECTION  = "nutrition"

# ── 가이드라인 파일 메타데이터 정의 ──────────────────────────────
GUIDELINE_FILES = [
    {
        "file": "diabetes_kda.txt",
        "source": "대한당뇨병학회",
        "condition": "당뇨",
        "is_diabetes": True,
        "is_hypertension": False,
        "is_diet": False,
    },
    {
        "file": "hypertension_ksh.txt",
        "source": "대한고혈압학회",
        "condition": "고혈압",
        "is_diabetes": False,
        "is_hypertension": True,
        "is_diet": False,
    },
    # ── KDRI 2025 전권 (기존 kdri_2025.txt 대체) ──
    {
        "file": "kdri_2025_vol1.txt",
        "source": "보건복지부/한국영양학회 KDRI2025 1권",
        "condition": "일반",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": True,
    },
    {
        "file": "kdri_2025_vol2.txt",
        "source": "보건복지부/한국영양학회 KDRI2025 2권",
        "condition": "일반",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": True,
    },
    {
        "file": "kdri_2025_vol3.txt",
        "source": "보건복지부/한국영양학회 KDRI2025 3권",
        "condition": "일반",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": True,
    },
    {
        "file": "kdri_2025_summary.txt",
        "source": "보건복지부/한국영양학회 KDRI2025 국문요약",
        "condition": "일반",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": True,
    },
    # ── 영양사도우미 (kdclub.com) 식사요법 ──
    {
        "file": "kdclub_general_diet.txt",
        "source": "영양사도우미(kdclub.com)",
        "condition": "일반치료식",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": True,
    },
    {
        "file": "kdclub_gastric.txt",
        "source": "영양사도우미(kdclub.com)",
        "condition": "소화기",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": False,
    },
    {
        "file": "kdclub_liver.txt",
        "source": "영양사도우미(kdclub.com)",
        "condition": "간질환",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": False,
    },
    {
        "file": "kdclub_cardiovascular.txt",
        "source": "영양사도우미(kdclub.com)",
        "condition": "심혈관",
        "is_diabetes": False,
        "is_hypertension": True,
        "is_diet": False,
    },
    {
        "file": "kdclub_kidney.txt",
        "source": "영양사도우미(kdclub.com)",
        "condition": "신장질환",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": False,
    },
    {
        "file": "kdclub_neuro.txt",
        "source": "영양사도우미(kdclub.com)",
        "condition": "뇌신경",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": False,
    },
    {
        "file": "kdclub_eating_disorder.txt",
        "source": "영양사도우미(kdclub.com)",
        "condition": "섭식장애",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": False,
    },
    {
        "file": "kdclub_cancer.txt",
        "source": "영양사도우미(kdclub.com)",
        "condition": "암",
        "is_diabetes": False,
        "is_hypertension": False,
        "is_diet": False,
    },
]


def chunk_text(text: str, max_chars: int = 400) -> list[str]:
    """단락 단위로 청킹. 빈 줄 기준으로 분리 후 max_chars 초과 시 추가 분할."""
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    chunks = []
    for para in paragraphs:
        lines = para.splitlines()
        content_lines = [ln for ln in lines if not ln.startswith("#")]
        para = "\n".join(content_lines).strip()
        if not para:
            continue
        if len(para) <= max_chars:
            chunks.append(para)
        else:
            sentences = [s.strip() for s in para.replace(". ", ".\n").split("\n") if s.strip()]
            buf = ""
            for sent in sentences:
                if len(buf) + len(sent) + 1 <= max_chars:
                    buf = (buf + " " + sent).strip()
                else:
                    if buf:
                        chunks.append(buf)
                    buf = sent
            if buf:
                chunks.append(buf)
    return chunks


def load_guideline_docs(cfg: dict) -> tuple[list[str], list[dict], list[str]]:
    path = GUIDE_DIR / cfg["file"]
    text = path.read_text(encoding="utf-8")
    chunks = chunk_text(text)

    # 파일 stem을 ID prefix로 사용 → 같은 condition이어도 고유 ID 보장
    file_stem = Path(cfg["file"]).stem

    docs, metas, ids = [], [], []
    for i, chunk in enumerate(chunks):
        doc_id = f"guide_{file_stem}_{i:04d}"
        meta = {
            "category":        "가이드라인",
            "source":          cfg["source"],
            "condition":       cfg["condition"],
            "file_id":         file_stem,   # 파일별 고유 식별자 (삭제 시 사용)
            "is_diet":         cfg["is_diet"],
            "is_diabetes":     cfg["is_diabetes"],
            "is_hypertension": cfg["is_hypertension"],
            "is_morning":      False,
            "is_lunch":        False,
            "is_dinner":       False,
            "is_snack":        False,
            "is_supplement":   False,
        }
        docs.append(chunk)
        metas.append(meta)
        ids.append(doc_id)

    return docs, metas, ids


def main() -> None:
    print(f"\n{'='*60}")
    print("  NutrAI 의학 가이드라인 → ChromaDB 추가")
    print(f"{'='*60}\n")

    print("모델 로딩 중...")
    model = SentenceTransformer(EMBED_MODEL)

    client = chromadb.PersistentClient(path=str(CHROMA_DIR))

    # 잘못 생성된 nutrition_collection 정리
    try:
        client.delete_collection("nutrition_collection")
        print("nutrition_collection (오생성) 삭제")
    except Exception:
        pass

    collection = client.get_or_create_collection(
        name=COLLECTION,
        metadata={"hnsw:space": "l2"},
    )

    total_added = 0

    for cfg in GUIDELINE_FILES:
        file_stem = Path(cfg["file"]).stem
        print(f"\n[{file_stem}] {cfg['source']} 처리 중...")

        docs, metas, ids = load_guideline_docs(cfg)

        # file_id 기준으로 기존 문서 삭제 후 재삽입 (source 공유 파일 충돌 방지)
        existing = collection.get(
            where={"$and": [
                {"category": {"$eq": "가이드라인"}},
                {"file_id":  {"$eq": file_stem}},
            ]},
            include=[],
        )
        if existing["ids"]:
            collection.delete(ids=existing["ids"])
            print(f"  기존 {len(existing['ids'])}개 삭제")

        embeddings = model.encode(docs, batch_size=64, show_progress_bar=False).tolist()
        collection.add(documents=docs, embeddings=embeddings, metadatas=metas, ids=ids)
        print(f"  {len(docs)}개 청크 추가 완료")
        total_added += len(docs)

    total = collection.count()
    general_count = collection.get(
        where={"$and": [
            {"category":  {"$eq": "가이드라인"}},
            {"condition": {"$eq": "일반"}},
        ]},
        include=[],
    )
    print(f"\n총 {total_added}개 가이드라인 청크 추가")
    print(f"컬렉션 전체 문서 수: {total:,}건")
    print(f"condition='일반' 청크 수: {len(general_count['ids']):,}건")
    print(f"\n{'='*60}\n")


if __name__ == "__main__":
    main()
