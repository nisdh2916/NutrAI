"""Run a deterministic ChromaDB ablation for NutrAI recommendation safety.

This experiment uses the real local ChromaDB nutrition collection and the same
KR-SBERT embedding model as the RAG pipeline. It evaluates recommendation
candidate quality without calling the LLM, so the reported numbers are
reproducible and can be traced back to retrieved food documents.

Conditions:
  C1 Baseline: no allergen retrieval filter, no calorie validator.
  C2 Retrieval allergen filter only.
  C3 Calorie post-validator only.
  C4 Full: retrieval allergen filter + calorie post-validator.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

import chromadb
from sentence_transformers import SentenceTransformer

from ai.rag_engine.rag_pipeline import (
    CHROMA_DIR,
    EMBED_MODEL,
    _calc_remaining_kcal,
    _detect_meal_time,
    _diversify_docs,
    _rewrite_queries,
)
from server.common.allergens import extract_allergen_keywords


KCAL_TOLERANCE = 50.0
DEFAULT_K = 5
DEFAULT_FETCH_MULTIPLIER = 10
DEFAULT_OUTPUT_DIR = REPO_ROOT / "docs" / "research" / "ablation"

_KCAL_RE = re.compile(r"칼로리\s*([0-9]+(?:\.[0-9]+)?)\s*kcal", re.IGNORECASE)
_PROTEIN_RE = re.compile(r"단백질\s*([0-9]+(?:\.[0-9]+)?)\s*g", re.IGNORECASE)
_SODIUM_RE = re.compile(r"나트륨\s*([0-9]+(?:\.[0-9]+)?)\s*mg", re.IGNORECASE)
_SUGAR_RE = re.compile(r"당류\s*([0-9]+(?:\.[0-9]+)?)\s*g", re.IGNORECASE)
_CARB_RE = re.compile(r"탄수화물\s*([0-9]+(?:\.[0-9]+)?)\s*g", re.IGNORECASE)


@dataclass(frozen=True)
class Condition:
    code: str
    label: str
    retrieval_allergen_filter: bool
    calorie_post_validator: bool


@dataclass(frozen=True)
class Scenario:
    scenario_id: str
    query: str
    profile: dict[str, Any]
    meal_history: list[dict[str, Any]]
    detected_foods: list[str]
    expected_focus: str


@dataclass
class Candidate:
    doc: str
    distance: float
    metadata: dict[str, Any]
    queries: list[str]

    @property
    def name(self) -> str:
        raw = self.metadata.get("name")
        if raw:
            return str(raw)
        return self.doc.split("|", 1)[0].strip()

    @property
    def category(self) -> str:
        return str(self.metadata.get("category") or "")

    @property
    def source(self) -> str:
        return str(self.metadata.get("source") or "")


CONDITIONS = [
    Condition("C1", "Baseline", False, False),
    Condition("C2", "Retrieval allergen filter only", True, False),
    Condition("C3", "Calorie post-validator only", False, True),
    Condition("C4", "Full", True, True),
]


def _meal_history_for_remaining(remaining_kcal: float, target_kcal: float = 2000.0) -> list[dict[str, Any]]:
    consumed = max(0.0, target_kcal - remaining_kcal)
    return [
        {
            "meal_type": "이전 식사",
            "total_kcal": consumed,
            "foods": [{"name": "기록된 식사", "kcal": consumed}],
        }
    ]


SCENARIOS = [
    Scenario(
        "S01_dairy_high_protein_breakfast",
        "고단백 아침 추천",
        {"goal": "근육 증가", "condition": "", "allergy": "유제품", "target_kcal": 2000},
        _meal_history_for_remaining(500),
        [],
        "유제품 알레르기와 아침 고단백 후보 충돌",
    ),
    Scenario(
        "S02_dairy_snack",
        "건강한 간식 추천",
        {"goal": "일반 건강 관리", "condition": "", "allergy": "유제품", "target_kcal": 2000},
        _meal_history_for_remaining(250),
        [],
        "유제품 알레르기와 저칼로리 간식",
    ),
    Scenario(
        "S03_nuts_snack",
        "견과류가 들어간 간식 대신 안전한 간식 추천",
        {"goal": "일반 건강 관리", "condition": "", "allergy": "견과류", "target_kcal": 2000},
        _meal_history_for_remaining(300),
        [],
        "견과류 알레르기 필터",
    ),
    Scenario(
        "S04_shellfish_dinner",
        "해산물 저녁 추천",
        {"goal": "일반 건강 관리", "condition": "", "allergy": "갑각류", "target_kcal": 2000},
        _meal_history_for_remaining(650),
        [],
        "갑각류 알레르기와 해산물 검색",
    ),
    Scenario(
        "S05_wheat_lunch",
        "면 요리 점심 추천",
        {"goal": "일반 건강 관리", "condition": "", "allergy": "밀", "target_kcal": 2000},
        _meal_history_for_remaining(600),
        [],
        "밀 알레르기와 면류 검색",
    ),
    Scenario(
        "S06_egg_breakfast",
        "아침 단백질 메뉴 추천",
        {"goal": "근육 증가", "condition": "", "allergy": "계란", "target_kcal": 2000},
        _meal_history_for_remaining(450),
        [],
        "계란 알레르기와 아침 단백질 후보",
    ),
    Scenario(
        "S07_soy_dinner",
        "두부 중심 저녁 추천",
        {"goal": "일반 건강 관리", "condition": "", "allergy": "대두", "target_kcal": 2000},
        _meal_history_for_remaining(550),
        [],
        "대두 알레르기와 두부 검색",
    ),
    Scenario(
        "S08_mackerel_dinner",
        "생선구이 저녁 추천",
        {"goal": "일반 건강 관리", "condition": "", "allergy": "고등어", "target_kcal": 2000},
        _meal_history_for_remaining(600),
        [],
        "고등어 알레르기와 생선 검색",
    ),
    Scenario(
        "S09_diabetes_lunch",
        "당뇨 점심 추천",
        {"goal": "일반 건강 관리", "condition": "당뇨", "allergy": "", "target_kcal": 2000},
        _meal_history_for_remaining(650),
        [],
        "당뇨 조건에서 저당/저탄수 후보",
    ),
    Scenario(
        "S10_diabetes_snack",
        "당뇨 간식 추천",
        {"goal": "일반 건강 관리", "condition": "당뇨", "allergy": "", "target_kcal": 2000},
        _meal_history_for_remaining(250),
        [],
        "당뇨 조건에서 간식 후보",
    ),
    Scenario(
        "S11_hypertension_dinner",
        "고혈압 저녁 추천",
        {"goal": "일반 건강 관리", "condition": "고혈압", "allergy": "", "target_kcal": 2000},
        _meal_history_for_remaining(600),
        [],
        "고혈압 조건에서 저나트륨 후보",
    ),
    Scenario(
        "S12_hypertension_soup",
        "국물 있는 저녁 추천",
        {"goal": "일반 건강 관리", "condition": "고혈압", "allergy": "", "target_kcal": 2000},
        _meal_history_for_remaining(500),
        [],
        "고혈압 조건과 국물류 나트륨 위험",
    ),
    Scenario(
        "S13_weight_loss_lunch",
        "다이어트 점심 추천",
        {"goal": "다이어트", "condition": "", "allergy": "", "target_kcal": 1800},
        _meal_history_for_remaining(450, target_kcal=1800),
        [],
        "체중 감량 목표와 점심 후보",
    ),
    Scenario(
        "S14_weight_loss_snack",
        "다이어트 간식 추천",
        {"goal": "다이어트", "condition": "", "allergy": "", "target_kcal": 1800},
        _meal_history_for_remaining(180, target_kcal=1800),
        [],
        "체중 감량 목표와 매우 낮은 잔여 칼로리",
    ),
    Scenario(
        "S15_low_remaining_dinner",
        "저녁 추천",
        {"goal": "일반 건강 관리", "condition": "", "allergy": "", "target_kcal": 1600},
        _meal_history_for_remaining(300, target_kcal=1600),
        [],
        "잔여 칼로리 300kcal 제한",
    ),
    Scenario(
        "S16_post_workout_protein",
        "운동 후 단백질 간식 추천",
        {"goal": "근육 증가", "condition": "", "allergy": "", "target_kcal": 2400},
        _meal_history_for_remaining(700, target_kcal=2400),
        [],
        "운동 후 고단백 후보",
    ),
]


def _float_from_regex(pattern: re.Pattern[str], text: str) -> float | None:
    match = pattern.search(text)
    if not match:
        return None
    try:
        return float(match.group(1))
    except ValueError:
        return None


def _nutrition(candidate: Candidate) -> dict[str, float | None]:
    return {
        "kcal": _float_from_regex(_KCAL_RE, candidate.doc),
        "protein": _float_from_regex(_PROTEIN_RE, candidate.doc),
        "sodium": _float_from_regex(_SODIUM_RE, candidate.doc),
        "sugar": _float_from_regex(_SUGAR_RE, candidate.doc),
        "carb": _float_from_regex(_CARB_RE, candidate.doc),
    }


def _is_food_candidate(candidate: Candidate) -> bool:
    if candidate.category == "가이드라인":
        return False
    return _float_from_regex(_KCAL_RE, candidate.doc) is not None


def _bool_meta(candidate: Candidate, key: str) -> bool:
    return bool(candidate.metadata.get(key))


def _queries_for(scenario: Scenario) -> tuple[list[str], float | None]:
    remaining = _calc_remaining_kcal(scenario.profile, scenario.meal_history)
    meal_time = _detect_meal_time(scenario.query)
    queries = _rewrite_queries(
        scenario.query,
        scenario.profile,
        scenario.detected_foods,
        remaining,
        meal_time,
    )
    return queries or [scenario.query], remaining


def _retrieve_pool(
    *,
    collection,
    model: SentenceTransformer,
    scenario: Scenario,
    k: int,
    fetch_multiplier: int,
) -> tuple[list[Candidate], list[str], float | None]:
    queries, remaining = _queries_for(scenario)
    best: dict[str, Candidate] = {}
    n_results = min(max(k * fetch_multiplier, k), collection.count())

    for query in queries:
        query_embedding = model.encode(query, convert_to_numpy=True).tolist()
        results = collection.query(
            query_embeddings=[query_embedding],
            n_results=n_results,
            include=["documents", "distances", "metadatas"],
        )
        docs = results["documents"][0] if results["documents"] else []
        distances = results["distances"][0] if results["distances"] else []
        metadatas = results["metadatas"][0] if results["metadatas"] else []
        for doc, distance, metadata in zip(docs, distances, metadatas):
            if not doc:
                continue
            current = best.get(doc)
            if current is None:
                best[doc] = Candidate(doc, float(distance), dict(metadata or {}), [query])
            elif distance < current.distance:
                current.distance = float(distance)
                current.queries = [query]
            elif query not in current.queries:
                current.queries.append(query)

    ordered = sorted(best.values(), key=lambda item: item.distance)
    return [candidate for candidate in ordered if _is_food_candidate(candidate)], queries, remaining


def _has_allergen(candidate: Candidate, scenario: Scenario) -> bool:
    keywords = extract_allergen_keywords(scenario.profile.get("allergy"))
    if not keywords:
        return False
    text = f"{candidate.name} {candidate.doc}"
    return any(keyword in text for keyword in keywords)


def _calorie_violation(candidate: Candidate, remaining_kcal: float | None) -> bool:
    kcal = _nutrition(candidate)["kcal"]
    if kcal is None:
        return True
    if kcal > 2000:
        return True
    if remaining_kcal is not None and remaining_kcal > 0:
        return kcal > remaining_kcal + KCAL_TOLERANCE
    return False


def _constraint_fit(candidate: Candidate, scenario: Scenario) -> bool:
    profile = scenario.profile
    condition = str(profile.get("condition") or "")
    goal = str(profile.get("goal") or "")
    nutrients = _nutrition(candidate)
    required: list[bool] = []

    if "당뇨" in condition:
        required.append(
            _bool_meta(candidate, "is_diabetes")
            or (
                (nutrients["sugar"] is not None and nutrients["sugar"] <= 5)
                and (nutrients["carb"] is not None and nutrients["carb"] <= 30)
            )
        )
    if "고혈압" in condition:
        required.append(
            _bool_meta(candidate, "is_hypertension")
            or (nutrients["sodium"] is not None and nutrients["sodium"] <= 300)
        )
    if "다이어트" in goal or "감량" in goal:
        required.append(
            _bool_meta(candidate, "is_diet")
            or (nutrients["kcal"] is not None and nutrients["kcal"] <= 350)
        )
    if "근육" in goal or "증가" in goal:
        required.append(nutrients["protein"] is not None and nutrients["protein"] >= 12)

    return all(required) if required else True


def _select_candidates(
    pool: list[Candidate],
    *,
    scenario: Scenario,
    condition: Condition,
    remaining_kcal: float | None,
    k: int,
) -> list[Candidate]:
    filtered: list[Candidate] = []
    for candidate in pool:
        if condition.retrieval_allergen_filter and _has_allergen(candidate, scenario):
            continue
        if condition.calorie_post_validator and _calorie_violation(candidate, remaining_kcal):
            continue
        filtered.append(candidate)

    diversified_docs = _diversify_docs([item.doc for item in filtered], max_per_category=2)
    doc_to_candidate = {item.doc: item for item in filtered}
    diversified = [doc_to_candidate[doc] for doc in diversified_docs if doc in doc_to_candidate]
    if len(diversified) < k:
        already = {item.doc for item in diversified}
        diversified.extend(item for item in filtered if item.doc not in already)
    return diversified[:k]


def _safe_div(num: float, den: float) -> float:
    return num / den if den else 0.0


def _summarize_trial(
    *,
    scenario: Scenario,
    condition: Condition,
    candidates: list[Candidate],
    queries: list[str],
    remaining_kcal: float | None,
    k: int,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    rows = []
    for rank, candidate in enumerate(candidates, 1):
        nutrients = _nutrition(candidate)
        allergen_violation = _has_allergen(candidate, scenario)
        calorie_violation = _calorie_violation(candidate, remaining_kcal)
        constraint_fit = _constraint_fit(candidate, scenario)
        rows.append(
            {
                "scenario_id": scenario.scenario_id,
                "condition": condition.code,
                "condition_label": condition.label,
                "rank": rank,
                "query": scenario.query,
                "expanded_queries": " || ".join(queries),
                "remaining_kcal": remaining_kcal,
                "name": candidate.name,
                "category": candidate.category,
                "distance": round(candidate.distance, 6),
                "kcal": nutrients["kcal"],
                "protein": nutrients["protein"],
                "sodium": nutrients["sodium"],
                "sugar": nutrients["sugar"],
                "carb": nutrients["carb"],
                "allergen_violation": allergen_violation,
                "calorie_violation": calorie_violation,
                "constraint_fit": constraint_fit,
                "source": candidate.source,
                "doc": candidate.doc,
            }
        )

    count = len(rows)
    allergen_violations = sum(1 for row in rows if row["allergen_violation"])
    calorie_violations = sum(1 for row in rows if row["calorie_violation"])
    constraint_fits = sum(1 for row in rows if row["constraint_fit"])
    safe_items = sum(
        1
        for row in rows
        if not row["allergen_violation"] and not row["calorie_violation"]
    )
    mean_distance = _safe_div(sum(float(row["distance"]) for row in rows), count)
    mean_kcal = _safe_div(sum(float(row["kcal"] or 0.0) for row in rows), count)
    coverage = _safe_div(count, k)
    safety_pass_rate = _safe_div(safe_items, count)
    constraint_fit_rate = _safe_div(constraint_fits, count)
    quality_score = 100.0 * (
        0.45 * safety_pass_rate
        + 0.35 * constraint_fit_rate
        + 0.20 * coverage
    )

    trial = {
        "scenario_id": scenario.scenario_id,
        "condition": condition.code,
        "condition_label": condition.label,
        "query": scenario.query,
        "expected_focus": scenario.expected_focus,
        "remaining_kcal": remaining_kcal,
        "recommended_count": count,
        "coverage": round(coverage, 4),
        "allergen_violation_rate": round(_safe_div(allergen_violations, count), 4),
        "calorie_violation_rate": round(_safe_div(calorie_violations, count), 4),
        "safety_pass_rate": round(safety_pass_rate, 4),
        "constraint_fit_rate": round(constraint_fit_rate, 4),
        "scenario_safe": count > 0 and allergen_violations == 0 and calorie_violations == 0,
        "mean_distance": round(mean_distance, 6),
        "mean_kcal": round(mean_kcal, 4),
        "quality_score": round(quality_score, 4),
        "expanded_queries": queries,
    }
    return trial, rows


def _aggregate(trials: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_condition: dict[str, list[dict[str, Any]]] = {}
    for trial in trials:
        by_condition.setdefault(str(trial["condition"]), []).append(trial)

    summary = []
    for condition in CONDITIONS:
        items = by_condition.get(condition.code, [])
        n = len(items)
        if not n:
            continue
        summary.append(
            {
                "condition": condition.code,
                "condition_label": condition.label,
                "scenarios": n,
                "avg_recommended_count": round(_safe_div(sum(i["recommended_count"] for i in items), n), 4),
                "avg_coverage": round(_safe_div(sum(i["coverage"] for i in items), n), 4),
                "avg_allergen_violation_rate": round(_safe_div(sum(i["allergen_violation_rate"] for i in items), n), 4),
                "avg_calorie_violation_rate": round(_safe_div(sum(i["calorie_violation_rate"] for i in items), n), 4),
                "avg_safety_pass_rate": round(_safe_div(sum(i["safety_pass_rate"] for i in items), n), 4),
                "avg_constraint_fit_rate": round(_safe_div(sum(i["constraint_fit_rate"] for i in items), n), 4),
                "scenario_safe_rate": round(_safe_div(sum(1 for i in items if i["scenario_safe"]), n), 4),
                "avg_mean_distance": round(_safe_div(sum(i["mean_distance"] for i in items), n), 6),
                "avg_mean_kcal": round(_safe_div(sum(i["mean_kcal"] for i in items), n), 4),
                "avg_quality_score": round(_safe_div(sum(i["quality_score"] for i in items), n), 4),
            }
        )
    return summary


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def run_experiment(args: argparse.Namespace) -> dict[str, Any]:
    if not CHROMA_DIR.exists():
        raise FileNotFoundError(f"ChromaDB directory not found: {CHROMA_DIR}")

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    model = SentenceTransformer(EMBED_MODEL)
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    collection = client.get_collection("nutrition")

    scenarios = SCENARIOS[: args.max_scenarios] if args.max_scenarios else SCENARIOS
    trials: list[dict[str, Any]] = []
    detail_rows: list[dict[str, Any]] = []

    for scenario in scenarios:
        pool, queries, remaining_kcal = _retrieve_pool(
            collection=collection,
            model=model,
            scenario=scenario,
            k=args.k,
            fetch_multiplier=args.fetch_multiplier,
        )
        for condition in CONDITIONS:
            candidates = _select_candidates(
                pool,
                scenario=scenario,
                condition=condition,
                remaining_kcal=remaining_kcal,
                k=args.k,
            )
            trial, rows = _summarize_trial(
                scenario=scenario,
                condition=condition,
                candidates=candidates,
                queries=queries,
                remaining_kcal=remaining_kcal,
                k=args.k,
            )
            trials.append(trial)
            detail_rows.extend(rows)

    summary = _aggregate(trials)
    result = {
        "run": {
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "repo_root": str(REPO_ROOT),
            "chroma_dir": str(CHROMA_DIR),
            "collection": "nutrition",
            "collection_count": collection.count(),
            "embedding_model": EMBED_MODEL,
            "k": args.k,
            "fetch_multiplier": args.fetch_multiplier,
            "scenario_count": len(scenarios),
            "notes": [
                "LLM generation is intentionally excluded to keep the ablation deterministic.",
                "Candidates are retrieved from the real ChromaDB nutrition collection.",
                "The retrieval pool is wider than the runtime RAG top-k because food and guideline documents share one collection.",
                "Calories are evaluated against remaining_kcal + 50 kcal tolerance.",
                "quality_score = 45% safety pass + 35% constraint fit + 20% coverage.",
            ],
        },
        "conditions": [condition.__dict__ for condition in CONDITIONS],
        "summary": summary,
        "trials": trials,
    }

    json_path = output_dir / "ablation_results.json"
    summary_path = output_dir / "ablation_summary.csv"
    trials_path = output_dir / "ablation_trials.csv"
    details_path = output_dir / "ablation_candidates.csv"

    json_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    _write_csv(summary_path, summary)
    _write_csv(trials_path, trials)
    _write_csv(details_path, detail_rows)

    return {
        "json_path": json_path,
        "summary_path": summary_path,
        "trials_path": trials_path,
        "details_path": details_path,
        "result": result,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--k", type=int, default=DEFAULT_K, help="Number of candidates per scenario/condition.")
    parser.add_argument(
        "--fetch-multiplier",
        type=int,
        default=DEFAULT_FETCH_MULTIPLIER,
        help="Number of Chroma results per query as k * fetch_multiplier.",
    )
    parser.add_argument(
        "--max-scenarios",
        type=int,
        default=0,
        help="Run only the first N scenarios for a quick smoke test.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help="Directory for JSON/CSV outputs.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    outputs = run_experiment(args)
    summary = outputs["result"]["summary"]

    print(f"Saved JSON: {outputs['json_path']}")
    print(f"Saved summary CSV: {outputs['summary_path']}")
    print(f"Saved trials CSV: {outputs['trials_path']}")
    print(f"Saved candidate CSV: {outputs['details_path']}")
    print()
    for row in summary:
        print(
            "{condition} {condition_label}: quality={avg_quality_score:.2f}, "
            "safety={avg_safety_pass_rate:.2f}, allergen_v={avg_allergen_violation_rate:.2f}, "
            "calorie_v={avg_calorie_violation_rate:.2f}, coverage={avg_coverage:.2f}".format(**row)
        )


if __name__ == "__main__":
    main()
