"""
KDRI 2025 PDF 4종 → txt 변환 스크립트

실행:
    python ai/scripts/db/parse_kdri_pdfs.py

출력:
    data/guidelines/kdri_2025_vol1.txt  (1권 에너지와 다량영양소)
    data/guidelines/kdri_2025_vol2.txt  (2권 비타민)
    data/guidelines/kdri_2025_vol3.txt  (3권 무기질)
    data/guidelines/kdri_2025_summary.txt (국문요약본)
"""

import re
import sys
from pathlib import Path

try:
    import pdfplumber
except ImportError:
    print("pdfplumber 미설치. 실행: pip install pdfplumber")
    sys.exit(1)

REPO_ROOT  = Path(__file__).parent.parent.parent.parent
GUIDE_DIR  = REPO_ROOT / "data" / "guidelines"

PDF_MAP = [
    ("1권_에너지와 다량영양소.pdf", "kdri_2025_vol1.txt"),
    ("2권_비타민.pdf",              "kdri_2025_vol2.txt"),
    ("3권_무기질.pdf",              "kdri_2025_vol3.txt"),
    ("국문요약본.pdf",              "kdri_2025_summary.txt"),
]

# 제거할 노이즈 패턴 (표 캡션, 그림 캡션, 페이지 번호 등)
_NOISE_PATTERNS = [
    re.compile(r'^(표|그림|Figure|Table)\s*\d+[-.]', re.MULTILINE),  # 표/그림 캡션
    re.compile(r'^\s*\d+\s*$', re.MULTILINE),                         # 단독 페이지 번호
    re.compile(r'^={3,}|-{3,}$', re.MULTILINE),                       # 구분선
    re.compile(r'\s{3,}', re.DOTALL),                                  # 과도한 공백 → 단일 공백
]

# 섹션 헤더 정규화 패턴
_SECTION_PATTERN = re.compile(
    r'^(제\s*\d+\s*장|제\s*\d+\s*절|\d+\.\s+\S|\[[^\]]+\])',
    re.MULTILINE,
)


def clean_text(raw: str) -> str:
    text = raw

    # 1) 표·그림 캡션 줄 제거
    lines = text.splitlines()
    cleaned_lines = []
    for line in lines:
        stripped = line.strip()
        # 표/그림/Figure/Table 캡션 줄 스킵
        if re.match(r'^(표|그림|Figure|Table)\s*\d+', stripped):
            continue
        # 단독 숫자(페이지 번호) 스킵
        if re.match(r'^\d{1,4}$', stripped):
            continue
        # 구분선 스킵
        if re.match(r'^[=\-]{3,}$', stripped):
            continue
        cleaned_lines.append(line)

    text = "\n".join(cleaned_lines)

    # 2) 연속 공백·빈줄 정리
    text = re.sub(r'[ \t]+', ' ', text)          # 가로 공백 정규화
    text = re.sub(r'\n{3,}', '\n\n', text)        # 빈줄 최대 2개

    # 3) 섹션 헤더 앞에 빈줄 삽입 (청킹 품질 향상)
    text = _SECTION_PATTERN.sub(r'\n\n\g<0>', text)

    return text.strip()


def extract_pdf(pdf_path: Path) -> str:
    """pdfplumber로 PDF 텍스트 추출"""
    parts = []
    with pdfplumber.open(pdf_path) as pdf:
        total = len(pdf.pages)
        for i, page in enumerate(pdf.pages, 1):
            if i % 20 == 0 or i == total:
                print(f"    페이지 {i}/{total}...", flush=True)

            # 표 영역을 bbox로 제외하고 텍스트만 추출
            text = page.extract_text(x_tolerance=2, y_tolerance=3) or ""
            if text.strip():
                parts.append(text)

    return "\n\n".join(parts)


def main() -> None:
    print(f"\n{'='*60}")
    print("  KDRI 2025 PDF → TXT 변환")
    print(f"{'='*60}\n")

    for pdf_name, txt_name in PDF_MAP:
        pdf_path = GUIDE_DIR / pdf_name
        txt_path = GUIDE_DIR / txt_name

        if not pdf_path.exists():
            print(f"[SKIP] {pdf_name} 없음 → {pdf_path}")
            continue

        print(f"[{pdf_name}] 파싱 중...")
        raw = extract_pdf(pdf_path)
        cleaned = clean_text(raw)

        txt_path.write_text(cleaned, encoding="utf-8")
        chars = len(cleaned)
        lines = cleaned.count("\n")
        print(f"  -> {txt_name} 저장 완료 ({chars:,}자, {lines:,}줄)\n")

    print("변환 완료!")


if __name__ == "__main__":
    main()
