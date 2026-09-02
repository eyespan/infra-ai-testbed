#!/usr/bin/env python3

from __future__ import annotations

import datetime as dt
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required.")
    print("Install with: pip install pyyaml")
    sys.exit(1)


# ---------------------------------------------------------------------------
# Repository paths
# ---------------------------------------------------------------------------

ROOT = Path(__file__).resolve().parent.parent
COMPARISON_DIR = ROOT / "comparison"
TEMPLATE = ROOT / "evaluation" / "comparison-matrix.md"

DATE = dt.datetime.now().strftime("%d%m%Y")
OUTPUT = ROOT / f"comparison-matrix-{DATE}.md"


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

TASK_NAMES = {
    "01": "Terraform EKS",
    "02": "Secure Kubernetes",
    "03": "CI/CD migration",
    "04": "Observability",
    "05": "Incident triage",
    "06": "Policy guardrails",
}

SCORE_FIELDS = [
    "correct",
    "secure",
    "reliable",
    "edges",
    "judgment",
    "ops",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def clean(value: Any) -> str:
    """Convert arbitrary YAML values into short markdown-safe text."""

    if value is None:
        return ""

    if isinstance(value, bool):
        return "yes" if value else "no"

    if isinstance(value, (int, float)):
        return str(value)

    text = str(value).strip()

    # Collapse whitespace/newlines.
    text = re.sub(r"\s+", " ", text)

    # Markdown table safety.
    text = text.replace("|", "\\|")

    return text


def short_text(value: Any, max_len: int = 180) -> str:
    text = clean(value)

    if len(text) <= max_len:
        return text

    return text[: max_len - 3].rstrip() + "..."


def score_value(value: Any) -> str:
    """
    Extract numeric score from any of these forms:

      4.5
      {"score": 4.5, "evidence": [...]}
      {"value": 4.5}
      {"rating": 4.5}
    """

    if value is None:
        return ""

    if isinstance(value, (int, float)):
        return str(value)

    if isinstance(value, dict):
        for key in ("score", "value", "rating"):
            candidate = value.get(key)

            if isinstance(candidate, (int, float)):
                return str(candidate)

            if candidate is not None:
                try:
                    return str(float(candidate))
                except (TypeError, ValueError):
                    pass

    try:
        return str(float(value))
    except (TypeError, ValueError):
        return ""


def numeric_score(value: Any) -> float | None:
    text = score_value(value)

    if not text:
        return None

    try:
        return float(text)
    except ValueError:
        return None


def extract_evidence(value: Any) -> list[str]:
    """Extract evidence from nested score objects."""

    if not isinstance(value, dict):
        return []

    evidence = value.get("evidence", [])

    if not isinstance(evidence, list):
        return []

    return [
        clean(item)
        for item in evidence
        if item is not None and clean(item)
    ]


def get_nested(data: dict[str, Any], *keys: str) -> Any:
    """
    Return first matching key.

    Allows minor naming differences in score files.
    """

    for key in keys:
        if key in data:
            return data[key]

    return None


def normalize_model_name(name: str) -> str:
    """
    Keep meaningful model identity while removing obvious inconsistencies.
    """

    name = clean(name)

    aliases = {
        "claude-sonnet-4-5": "claude-code (Claude Sonnet 4.5)",
        "claude-sonnet-4.5": "claude-code (Claude Sonnet 4.5)",
        "claude-code": "claude-code (Claude Sonnet 4.5)",
        "kiro-qwen-3-coder-next": "kiro (Qwen3 Coder Next)",
        "kiro (qwen-3-coder-next)": "kiro (Qwen3 Coder Next)",
        "kiro-qwen-3-coder-next (Qwen 3 Coder Next)": (
            "kiro (Qwen3 Coder Next)"
        ),
        "codex-gpt-oss-1-20b": (
            "codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock)"
        ),
    }

    return aliases.get(name.lower(), name)


def task_from_path(path: Path) -> str | None:
    """
    Extract task number from directory such as:

      01-terraform-eks-module
      02-k8s-secure-deployment
    """

    match = re.match(r"^(\d{2})-", path.name)

    if match:
        return match.group(1)

    return None


# ---------------------------------------------------------------------------
# Score loading
# ---------------------------------------------------------------------------

def discover_score_files() -> list[Path]:
    """
    Discover both score.yaml and score.yml anywhere beneath comparison/.
    """

    if not COMPARISON_DIR.exists():
        raise FileNotFoundError(
            f"Missing comparison directory: {COMPARISON_DIR}"
        )

    files = []

    files.extend(COMPARISON_DIR.rglob("score.yaml"))
    files.extend(COMPARISON_DIR.rglob("score.yml"))

    return sorted(files)


def load_score(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as fh:
            data = yaml.safe_load(fh)
    except Exception as exc:
        print(f"WARNING: Could not parse {path}: {exc}")
        return {}

    if not isinstance(data, dict):
        print(f"WARNING: Ignoring non-object YAML: {path}")
        return {}

    return data


def infer_model(data: dict[str, Any], path: Path) -> str:
    """
    Find model name from the score file.

    Supports several common schemas.
    """

    candidates = [
        data.get("model"),
        data.get("model_name"),
        data.get("agent"),
        data.get("runner"),
        data.get("system"),
    ]

    metadata = data.get("metadata")

    if isinstance(metadata, dict):
        candidates.extend(
            [
                metadata.get("model"),
                metadata.get("model_name"),
                metadata.get("agent"),
            ]
        )

    for candidate in candidates:
        if candidate:
            if isinstance(candidate, dict):
                candidate = (
                    candidate.get("name")
                    or candidate.get("id")
                    or candidate.get("model")
                )

            if candidate:
                return normalize_model_name(str(candidate))

    # Last-resort inference from comparison directory.
    try:
        relative = path.relative_to(COMPARISON_DIR)
        if relative.parts:
            return normalize_model_name(relative.parts[0])
    except ValueError:
        pass

    return "unknown"


def infer_task(data: dict[str, Any], path: Path) -> str | None:
    candidates = [
        data.get("task"),
        data.get("task_id"),
        data.get("task_number"),
    ]

    for candidate in candidates:
        if candidate is None:
            continue

        match = re.search(r"\d{1,2}", str(candidate))

        if match:
            return f"{int(match.group()):02d}"

    # Search path components.
    for part in path.parts:
        task = task_from_path(Path(part))

        if task:
            return task

    return None


# ---------------------------------------------------------------------------
# Result normalization
# ---------------------------------------------------------------------------

def normalize_result(path: Path) -> dict[str, Any] | None:

    data = load_score(path)

    if not data:
        return None

    task = infer_task(data, path)

    if task not in TASK_NAMES:
        print(f"WARNING: Cannot determine task for {path}")
        return None

    model = infer_model(data, path)

    # Mechanical
    mechanical_raw = get_nested(
        data,
        "mechanical",
        "mechanical_checks",
        "mechanical_score",
    )

    mechanical = ""

    if isinstance(mechanical_raw, dict):
        passed = mechanical_raw.get("passed")
        total = mechanical_raw.get("total")

        if passed is not None and total is not None:
            mechanical = f"{passed}/{total}"
        else:
            mechanical = score_value(mechanical_raw)

    elif mechanical_raw is not None:
        mechanical = clean(mechanical_raw)

    # Dimension scores
    dimensions: dict[str, str] = {}

    for field in SCORE_FIELDS:
        raw = get_nested(
            data,
            field,
            field.capitalize(),
            f"{field}_score",
        )

        dimensions[field] = score_value(raw)

    # Overall
    overall_raw = get_nested(
        data,
        "overall",
        "overall_score",
        "score",
    )

    overall = score_value(overall_raw)

    # Merge
    merge_raw = get_nested(
        data,
        "merge",
        "merge_decision",
        "decision",
    )

    merge = ""

    if isinstance(merge_raw, dict):
        merge = (
            merge_raw.get("decision")
            or merge_raw.get("status")
            or merge_raw.get("result")
            or ""
        )
    else:
        merge = merge_raw or ""

    merge = clean(merge)

    # Top bug / finding
    finding_raw = get_nested(
        data,
        "top_bug",
        "top_finding",
        "critical_finding",
        "finding",
    )

    if isinstance(finding_raw, dict):
        finding = (
            finding_raw.get("description")
            or finding_raw.get("summary")
            or finding_raw.get("text")
            or ""
        )
    else:
        finding = finding_raw or ""

    # Some score files use security_fail / critical findings.
    if not finding:
        critical = data.get("critical_security_fail")

        if critical:
            finding = "critical security failure"

    finding = short_text(finding)

    # Strength
    strength_raw = get_nested(
        data,
        "strength",
        "strengths",
        "top_strength",
    )

    if isinstance(strength_raw, list):
        strength = strength_raw[0] if strength_raw else ""
    elif isinstance(strength_raw, dict):
        strength = (
            strength_raw.get("description")
            or strength_raw.get("summary")
            or ""
        )
    else:
        strength = strength_raw or ""

    strength = short_text(strength)

    # Evidence for narrative generation.
    evidence = {
        "correct": extract_evidence(data.get("correct")),
        "secure": extract_evidence(data.get("secure")),
        "reliable": extract_evidence(data.get("reliable")),
        "edges": extract_evidence(data.get("edges")),
        "judgment": extract_evidence(data.get("judgment")),
        "ops": extract_evidence(data.get("ops")),
    }

    # Overall nested object may itself contain pass information.
    passed = None
    critical_security_fail = False

    if isinstance(overall_raw, dict):
        passed = overall_raw.get("passed")
        critical_security_fail = bool(
            overall_raw.get("critical_security_fail", False)
        )

    return {
        "model": model,
        "task": task,
        "mechanical": mechanical,
        "correct": dimensions["correct"],
        "secure": dimensions["secure"],
        "reliable": dimensions["reliable"],
        "edges": dimensions["edges"],
        "judgment": dimensions["judgment"],
        "ops": dimensions["ops"],
        "overall": overall,
        "merge": merge,
        "top_bug": finding,
        "strength": strength,
        "evidence": evidence,
        "passed": passed,
        "critical_security_fail": critical_security_fail,
        "path": str(path.relative_to(ROOT)),
    }


# ---------------------------------------------------------------------------
# Narrative generation
# ---------------------------------------------------------------------------

def result_score(result: dict[str, Any]) -> float | None:
    return numeric_score(result.get("overall"))


def best_result(results: list[dict[str, Any]]) -> dict[str, Any] | None:
    valid = [
        r for r in results
        if result_score(r) is not None
    ]

    if not valid:
        return None

    return max(valid, key=lambda r: result_score(r) or -1)


def worst_result(results: list[dict[str, Any]]) -> dict[str, Any] | None:
    valid = [
        r for r in results
        if result_score(r) is not None
    ]

    if not valid:
        return None

    return min(valid, key=lambda r: result_score(r) or 999)


def unique_short(items: list[str], limit: int = 5) -> list[str]:
    """
    Preserve order while removing duplicates.
    """

    result = []
    seen = set()

    for item in items:
        item = clean(item)

        if not item:
            continue

        key = item.lower()

        if key in seen:
            continue

        seen.add(key)
        result.append(item)

        if len(result) >= limit:
            break

    return result


def narrative_for_task(
    task_id: str,
    task_results: list[dict[str, Any]],
) -> str:

    if len(task_results) < 2:
        return ""

    lines: list[str] = []

    # Sort highest score first.
    ordered = sorted(
        task_results,
        key=lambda r: result_score(r)
        if result_score(r) is not None
        else -1,
        reverse=True,
    )

    # ------------------------------------------------------------------
    # Model summaries
    # ------------------------------------------------------------------

    for result in ordered:
        model = result["model"]
        overall = result["overall"] or "N/A"
        strength = result["strength"]
        bug = result["top_bug"]

        sentence = f"- **{model}**; overall {overall}"

        if strength:
            sentence += f"; strength: {strength}"

        if bug:
            sentence += f"; top finding: {bug}"

        sentence += "."

        lines.append(sentence)

    # ------------------------------------------------------------------
    # Score differences
    # ------------------------------------------------------------------

    score_lines = []

    for field in SCORE_FIELDS:
        values = []

        for result in ordered:
            value = result.get(field)

            if not value:
                continue

            values.append(
                f"{result['model']} {value}"
            )

        # Only show dimensions where there are at least two values
        # and they are not all identical.
        if len(values) >= 2:
            distinct = {
                value.split()[-1]
                for value in values
            }

            if len(distinct) > 1:
                label = field.capitalize()
                score_lines.append(
                    f"{label}: " + "; ".join(values)
                )

    if score_lines:
        lines.append(
            "- **Score differences:** "
            + "; ".join(score_lines)
            + "."
        )

    # ------------------------------------------------------------------
    # Edge cases identified
    # ------------------------------------------------------------------

    identified: list[str] = []

    for result in ordered:
        identified.extend(
            result["evidence"].get("edges", [])
        )

    identified = unique_short(identified)

    if identified:
        lines.append(
            "- **Edge cases identified:** "
            + "; ".join(identified)
            + "."
        )

    # ------------------------------------------------------------------
    # Edge cases missed
    # ------------------------------------------------------------------

    missed: list[str] = []

    for result in ordered:
        # Some score schemas explicitly provide missed edge cases.
        data = result.get("raw", {})

        if isinstance(data, dict):
            for key in (
                "missed_edge_cases",
                "edge_cases_missed",
                "missed",
            ):
                value = data.get(key)

                if isinstance(value, list):
                    missed.extend(
                        clean(item)
                        for item in value
                    )

        # Also look for evidence that contains "missed".
        for evidence in result["evidence"].get("edges", []):
            if "miss" in evidence.lower():
                missed.append(evidence)

    missed = unique_short(missed)

    if missed:
        lines.append(
            "- **Edge cases missed:** "
            + "; ".join(missed)
            + "."
        )

    return "\n\n".join(lines)


def build_narrative(results: list[dict[str, Any]]) -> str:

    blocks = []

    for task_id in sorted(TASK_NAMES):
        task_results = [
            r for r in results
            if r["task"] == task_id
        ]

        if len(task_results) < 2:
            continue

        narrative = narrative_for_task(
            task_id,
            task_results,
        )

        if narrative:
            blocks.append(
                f"### Task {task_id} — {TASK_NAMES[task_id]}\n\n"
                + narrative
            )

    if not blocks:
        return (
            "No task has results from two or more models yet."
        )

    return "\n\n".join(blocks)


# ---------------------------------------------------------------------------
# Cross-cutting analysis
# ---------------------------------------------------------------------------

def build_cross_cutting(results: list[dict[str, Any]]) -> str:

    def findings_matching(patterns: list[str]) -> list[str]:
        found = []

        for result in results:
            text_parts = [
                result.get("top_bug", ""),
                result.get("strength", ""),
            ]

            for evidence_list in result["evidence"].values():
                text_parts.extend(evidence_list)

            text = " ".join(text_parts).lower()

            if any(pattern in text for pattern in patterns):
                if result.get("top_bug"):
                    found.append(result["top_bug"])

        return unique_short(found, 5)

    # IDE vs terminal
    ide_findings = findings_matching(
        [
            "ide",
            "terminal",
            "workflow",
            "tool",
            "evidence",
        ]
    )

    # Cloud-specific / portability
    cloud_findings = findings_matching(
        [
            "aws",
            "eks",
            "github",
            "kubernetes",
            "terraform",
            "portable",
            "cloud",
        ]
    )

    # Happy-path
    happy_path = findings_matching(
        [
            "edge",
            "assumption",
            "validation",
            "not verified",
            "not executed",
            "missing",
            "unsupported",
        ]
    )

    # Secret handling
    secret_findings = findings_matching(
        [
            "secret",
            "plaintext",
            "encryption",
            "credential",
            "oidc",
            "authentication",
        ]
    )

    def bullet(values: list[str], fallback: str) -> str:
        if not values:
            return fallback

        return "; ".join(values)

    return (
        "- **IDE-first vs terminal-native:** "
        + bullet(
            ide_findings,
            "No consistent pattern identified from the recorded evidence.",
        )
        + "\n\n"
        "- **Cloud-specific depth vs portability:** "
        + bullet(
            cloud_findings,
            "No consistent pattern identified from the recorded evidence.",
        )
        + "\n\n"
        "- **Happy-path bias:** "
        + bullet(
            happy_path,
            "No consistent pattern identified from the recorded evidence.",
        )
        + "\n\n"
        "- **Secret handling:** "
        + bullet(
            secret_findings,
            "No recurring secret-handling finding identified.",
        )
    )


# ---------------------------------------------------------------------------
# Matrix
# ---------------------------------------------------------------------------

def markdown_row(values: list[str]) -> str:
    return "| " + " | ".join(clean(v) for v in values) + " |"


def build_matrix(results: list[dict[str, Any]]) -> str:

    header = (
        "| Model | Task | Mechanical | Correct | Secure | Reliable | "
        "Edges | Judgment | Ops | Overall | Merge | Top bug | Strength |"
    )

    separator = (
        "|-------|------|------------|---------|--------|----------|"
        "-------|----------|-----|---------|-------|---------|---------|"
    )

    rows = [header, separator]

    ordered = sorted(
        results,
        key=lambda r: (
            r["task"],
            r["model"].lower(),
        ),
    )

    for result in ordered:

        row = [
            result["model"],
            result["task"],
            result["mechanical"],
            result["correct"],
            result["secure"],
            result["reliable"],
            result["edges"],
            result["judgment"],
            result["ops"],
            result["overall"],
            result["merge"],
            result["top_bug"],
            result["strength"],
        ]

        rows.append(markdown_row(row))

    return "\n".join(rows)


# ---------------------------------------------------------------------------
# Template handling
# ---------------------------------------------------------------------------

def build_document(results: list[dict[str, Any]]) -> str:

    matrix = build_matrix(results)
    narrative = build_narrative(results)
    cross_cutting = build_cross_cutting(results)

    generated = dt.datetime.now().strftime(
        "%Y-%m-%d %H:%M:%S"
    )

    document = f"""# Comparison matrix

Generated automatically from `comparison/**/score.yaml` and `comparison/**/score.yml`.

Generated: {generated}

Fill one row per (model, task). Keep evidence short.

{matrix}

## Narrative (after two or more models on the same task)

{narrative}

## Cross-cutting patterns

{cross_cutting}
"""

    return document


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:

    print("Generating comparison matrix...")
    print()
    print(f"Repository root : {ROOT}")
    print(f"Comparison dir  : {COMPARISON_DIR}")
    print(f"Template        : {TEMPLATE}")
    print(f"Output          : {OUTPUT}")
    print()

    if not COMPARISON_DIR.exists():
        print(
            f"ERROR: Missing comparison directory: "
            f"{COMPARISON_DIR}"
        )
        sys.exit(1)

    score_files = discover_score_files()

    print(f"Found {len(score_files)} score file(s).")
    print()

    results: list[dict[str, Any]] = []

    for path in score_files:

        result = normalize_result(path)

        if result is None:
            continue

        results.append(result)

        print(
            f"  Task {result['task']} | "
            f"{result['model']} | "
            f"{result['path']}"
        )

    print()

    if not results:
        print("ERROR: No usable score files found.")
        sys.exit(1)

    # Detect duplicate model/task combinations.
    seen: dict[tuple[str, str], dict[str, Any]] = {}
    duplicates = []

    for result in results:

        key = (
            result["model"].lower(),
            result["task"],
        )

        if key in seen:
            duplicates.append(
                (
                    result["model"],
                    result["task"],
                    seen[key]["path"],
                    result["path"],
                )
            )

        seen[key] = result

    if duplicates:
        print()
        print("WARNING: Duplicate model/task combinations found:")

        for model, task, first, second in duplicates:
            print(
                f"  Task {task} | {model}"
                f"\n    first : {first}"
                f"\n    second: {second}"
            )

        print()
        print(
            "The latest discovered score file will be used "
            "for each duplicate combination."
        )

        results = list(seen.values())

    document = build_document(results)

    OUTPUT.write_text(
        document,
        encoding="utf-8",
    )

    print()
    print(f"Generated: {OUTPUT}")
    print()
    print(
        f"Models/tasks represented: {len(results)}"
    )

    task_counts: dict[str, int] = {}

    for result in results:
        task_counts[result["task"]] = (
            task_counts.get(result["task"], 0) + 1
        )

    for task_id in sorted(task_counts):
        print(
            f"  Task {task_id}: "
            f"{task_counts[task_id]} model(s)"
        )


if __name__ == "__main__":
    main()