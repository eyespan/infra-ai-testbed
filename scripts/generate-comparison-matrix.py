#!/usr/bin/env python3

from pathlib import Path
from datetime import datetime
import re
import sys

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required.")
    print("Install with: pip install pyyaml")
    sys.exit(1)


# ============================================================
# Paths
# ============================================================

# Script:
#   ~/cguru/infra-ai-testbed/scripts/generate-comparison-matrix.py
#
# Repository root:
#   ~/cguru/infra-ai-testbed
ROOT = Path(__file__).resolve().parent.parent

COMPARISON_DIR = ROOT / "comparison"
TEMPLATE = ROOT / "evaluation" / "comparison-matrix.md"

DATE_STAMP = datetime.now().strftime("%d%m%Y")
OUTPUT = ROOT / f"comparison-matrix-{DATE_STAMP}.md"


# ============================================================
# Configuration
# ============================================================

TASK_NAMES = {
    "01": "Terraform EKS",
    "02": "Secure Kubernetes",
    "03": "CI/CD migration",
    "04": "Observability",
    "05": "Incident triage",
    "06": "Policy guardrails",
}

SCORE_FIELDS = [
    ("correctness", "Correct"),
    ("security", "Secure"),
    ("reliability", "Reliable"),
    ("edge_cases", "Edges"),
    ("judgment", "Judgment"),
    ("observability", "Ops"),
]

MERGE_NORMALIZATION = {
    "true": "yes",
    "false": "no",
    "yes": "yes",
    "no": "no",
    "yes with changes": "yes_with_changes",
    "yes_with_changes": "yes_with_changes",
    "yes-with-changes": "yes_with_changes",
}


# ============================================================
# Helpers
# ============================================================

def clean(value):
    """Return a safe string representation."""
    if value is None:
        return ""
    return str(value).strip()


def normalize_merge(value):
    value = clean(value).lower()
    return MERGE_NORMALIZATION.get(value, value or "no")


def normalize_score(value):
    """
    Normalize score values.

    Returns:
        string representation suitable for markdown,
        or empty string when no score exists.
    """
    if value is None or value == "":
        return ""

    try:
        number = float(value)

        if number.is_integer():
            return str(int(number))

        return f"{number:.2f}".rstrip("0").rstrip(".")
    except (TypeError, ValueError):
        return clean(value)


def severity_rank(severity):
    return {
        "critical": 0,
        "high": 1,
        "medium": 2,
        "low": 3,
        "note": 4,
    }.get(clean(severity).lower(), 99)


def mechanical_summary(data):
    """
    Summarize mechanical checks as passed/applicable.

    Example:
        4/5
        1/2
        N/A
    """

    mechanical = data.get("mechanical") or {}

    if not mechanical:
        return "N/A"

    applicable = 0
    passed = 0

    for value in mechanical.values():
        value = clean(value).lower()

        if value in ("pass", "fail"):
            applicable += 1

            if value == "pass":
                passed += 1

    if applicable == 0:
        return "N/A"

    return f"{passed}/{applicable}"


def model_display(data, model_dir):
    run = data.get("run") or {}

    model = clean(run.get("model"))
    version = clean(run.get("model_version"))

    if model and version:
        return f"{model} ({version})"

    if model:
        return model

    return model_dir


def task_id_from_path(task_dir, data):
    run = data.get("run") or {}

    task_id = clean(run.get("task_id"))

    if task_id:
        match = re.match(r"^(\d{1,2})", task_id)
        if match:
            return match.group(1).zfill(2)

    match = re.match(r"^(\d{1,2})", task_dir)

    if match:
        return match.group(1).zfill(2)

    return task_dir


def first_nonempty(values):
    for value in values:
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def get_list(data, key):
    value = data.get(key, [])

    if not value:
        return []

    if isinstance(value, list):
        return [clean(x) for x in value if clean(x)]

    return [clean(value)]


def best_finding(data):
    findings = data.get("findings") or []

    if not isinstance(findings, list):
        return None

    valid = [
        finding
        for finding in findings
        if isinstance(finding, dict)
    ]

    if not valid:
        return None

    return sorted(
        valid,
        key=lambda x: (
            severity_rank(x.get("severity")),
            clean(x.get("title")).lower(),
        ),
    )[0]


def top_bug_text(data):
    finding = best_finding(data)

    if not finding:
        return ""

    severity = clean(finding.get("severity")).lower()
    title = clean(finding.get("title"))

    if not severity:
        severity = "note"

    if not title:
        return ""

    return f"{severity}: {title}"


def first_strength(data):
    strengths = get_list(data, "strengths")

    if strengths:
        return strengths[0]

    return ""


def overall_score(data):
    scores = data.get("scores") or {}

    value = scores.get("overall")

    # The canonical template stores overall at the root,
    # but tolerate a nested value too.
    if value is None:
        value = data.get("overall")

    if value is not None and value != "":
        return normalize_score(value)

    # Calculate it if the score file did not provide one.
    numbers = []

    for field, _ in SCORE_FIELDS:
        value = scores.get(field)

        if value is None or value == "":
            continue

        try:
            numbers.append(float(value))
        except (TypeError, ValueError):
            pass

    if not numbers:
        return ""

    return normalize_score(sum(numbers) / len(numbers))


def passed_value(data):
    value = data.get("passed")

    if value is None:
        value = (data.get("run") or {}).get("passed")

    if isinstance(value, bool):
        return value

    value = clean(value).lower()

    if value in ("true", "yes", "pass", "passed"):
        return True

    if value in ("false", "no", "fail", "failed"):
        return False

    return None


# ============================================================
# Load score files
# ============================================================

def load_scores():
    if not COMPARISON_DIR.exists():
        print(f"ERROR: Missing comparison directory: {COMPARISON_DIR}")
        sys.exit(1)

    score_files = sorted(COMPARISON_DIR.glob("**/score.yaml"))

    # Also support score.yml because some earlier benchmark
    # runs may have used that filename.
    score_files += sorted(COMPARISON_DIR.glob("**/score.yml"))

    # Remove duplicates while preserving order.
    score_files = list(dict.fromkeys(score_files))

    if not score_files:
        print(f"ERROR: No score.yaml or score.yml files found under:")
        print(f"  {COMPARISON_DIR}")
        sys.exit(1)

    results = []

    for path in score_files:
        try:
            with path.open("r", encoding="utf-8") as handle:
                data = yaml.safe_load(handle) or {}
        except Exception as exc:
            print(f"WARNING: Could not read {path}: {exc}")
            continue

        model_dir = path.parent.parent.name
        task_dir = path.parent.name

        task_id = task_id_from_path(task_dir, data)

        results.append(
            {
                "path": path,
                "data": data,
                "model_dir": model_dir,
                "task_dir": task_dir,
                "task_id": task_id,
                "model": model_display(data, model_dir),
            }
        )

    return results


# ============================================================
# Table
# ============================================================

def build_table_rows(results):
    rows = []

    results = sorted(
        results,
        key=lambda x: (
            x["task_id"],
            x["model"].lower(),
        ),
    )

    for item in results:
        data = item["data"]
        scores = data.get("scores") or {}

        score_values = []

        for field, _ in SCORE_FIELDS:
            score_values.append(normalize_score(scores.get(field)))

        row = [
            item["model"],
            item["task_id"],
            mechanical_summary(data),
            *score_values,
            overall_score(data),
            normalize_merge(data.get("merge_decision")),
            top_bug_text(data),
            first_strength(data),
        ]

        # Escape markdown table characters.
        row = [
            clean(value).replace("|", "\\|").replace("\n", " ")
            for value in row
        ]

        rows.append("| " + " | ".join(row) + " |")

    return rows


# ============================================================
# Narrative
# ============================================================

def score_as_float(data, field):
    scores = data.get("scores") or {}

    value = scores.get(field)

    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def narrative_for_task(task_id, task_results):
    """
    Generate evidence-based comparison bullets.

    This does not invent findings. It only uses information
    contained in score.yaml.
    """

    task_name = TASK_NAMES.get(task_id, f"Task {task_id}")

    if not task_results:
        return [
            f"- No score files found for Task {task_id}."
        ]

    if len(task_results) == 1:
        item = task_results[0]
        data = item["data"]

        overall = overall_score(data)
        strength = first_strength(data)
        bug = top_bug_text(data)

        bullet = f"- **{item['model']}**"

        if overall:
            bullet += f" scored **{overall} overall**"

        if strength:
            bullet += f"; strength: {strength}"

        if bug:
            bullet += f"; top finding: {bug}"

        bullet += "."

        return [bullet, "- Comparative analysis requires two or more model runs for this task."]

    bullets = []

    # One bullet per model.
    for item in task_results:
        data = item["data"]

        overall = overall_score(data)
        strength = first_strength(data)
        bug = top_bug_text(data)

        parts = [f"**{item['model']}**"]

        if overall:
            parts.append(f"overall {overall}")

        if strength:
            parts.append(f"strength: {strength}")

        if bug:
            parts.append(f"top finding: {bug}")

        bullets.append("- " + "; ".join(parts) + ".")

    # Identify strongest / weakest dimensions from actual scores.
    dimension_comparisons = []

    for field, label in SCORE_FIELDS:
        scored = []

        for item in task_results:
            value = score_as_float(item["data"], field)

            if value is not None:
                scored.append((value, item["model"]))

        if len(scored) < 2:
            continue

        highest = max(value for value, _ in scored)
        lowest = min(value for value, _ in scored)

        if highest != lowest:
            high_models = [
                model for value, model in scored
                if value == highest
            ]

            low_models = [
                model for value, model in scored
                if value == lowest
            ]

            dimension_comparisons.append(
                f"{label}: {', '.join(high_models)} {highest:g}; "
                f"{', '.join(low_models)} {lowest:g}"
            )

    if dimension_comparisons:
        bullets.append(
            "- **Score differences:** "
            + "; ".join(dimension_comparisons[:3])
            + "."
        )

    # Aggregate edge-case evidence.
    identified = []
    missed = []

    for item in task_results:
        data = item["data"]

        identified.extend(
            get_list(data, "edge_cases_identified")
        )
        missed.extend(
            get_list(data, "edge_cases_missed")
        )

    if identified:
        bullets.append(
            "- **Edge cases identified:** "
            + "; ".join(list(dict.fromkeys(identified))[:5])
            + "."
        )

    if missed:
        bullets.append(
            "- **Edge cases missed:** "
            + "; ".join(list(dict.fromkeys(missed))[:5])
            + "."
        )

    return bullets


def build_narrative(results):
    sections = []

    by_task = {}

    for item in results:
        by_task.setdefault(item["task_id"], []).append(item)

    for task_id in sorted(TASK_NAMES):
        task_results = by_task.get(task_id, [])

        sections.append(
            f"### Task {task_id} — {TASK_NAMES[task_id]}"
        )

        sections.extend(
            narrative_for_task(task_id, task_results)
        )

        sections.append("")

    return "\n".join(sections).rstrip()


# ============================================================
# Cross-cutting analysis
# ============================================================

def build_cross_cutting(results):
    """
    Generate cross-cutting observations strictly from the
    evidence fields present in score.yaml.
    """

    all_strengths = []
    all_weaknesses = []
    all_findings = []
    all_identified = []
    all_missed = []

    for item in results:
        data = item["data"]

        all_strengths.extend(get_list(data, "strengths"))
        all_weaknesses.extend(get_list(data, "weaknesses"))
        all_identified.extend(
            get_list(data, "edge_cases_identified")
        )
        all_missed.extend(
            get_list(data, "edge_cases_missed")
        )

        findings = data.get("findings") or []

        if isinstance(findings, list):
            for finding in findings:
                if isinstance(finding, dict):
                    title = clean(finding.get("title"))
                    severity = clean(finding.get("severity")).lower()

                    if title:
                        all_findings.append(
                            (severity, title)
                        )

    def unique(values, limit=5):
        output = []

        for value in values:
            if value and value not in output:
                output.append(value)

            if len(output) >= limit:
                break

        return output

    high_findings = [
        title
        for severity, title in sorted(
            all_findings,
            key=lambda x: severity_rank(x[0]),
        )
        if severity in ("critical", "high")
    ]

    medium_findings = [
        title
        for severity, title in sorted(
            all_findings,
            key=lambda x: severity_rank(x[0]),
        )
        if severity == "medium"
    ]

    sections = []

    if all_strengths:
        sections.append(
            "- **IDE-first vs terminal-native:** "
            + "Recurring strengths recorded across the runs include "
            + "; ".join(unique(all_strengths, 4))
            + "."
        )
    else:
        sections.append(
            "- **IDE-first vs terminal-native:** "
            "No explicit cross-run evidence is recorded in the score files."
        )

    if all_weaknesses:
        sections.append(
            "- **Cloud-specific depth vs portability:** "
            "Recorded weaknesses include "
            + "; ".join(unique(all_weaknesses, 4))
            + "."
        )
    else:
        sections.append(
            "- **Cloud-specific depth vs portability:** "
            "No explicit cross-run weakness evidence is recorded."
        )

    if all_missed or all_identified:
        text = "- **Happy-path bias:** "

        if all_missed:
            text += (
                "missed edge cases recorded include "
                + "; ".join(unique(all_missed, 5))
                + "."
            )
        elif all_identified:
            text += (
                "identified edge cases include "
                + "; ".join(unique(all_identified, 5))
                + "."
            )

        sections.append(text)
    else:
        sections.append(
            "- **Happy-path bias:** "
            "No explicit edge-case evidence is recorded across the score files."
        )

    if high_findings:
        sections.append(
            "- **Secret handling:** "
            "Higher-severity findings recorded across the benchmark include "
            + "; ".join(unique(high_findings, 4))
            + "."
        )
    elif medium_findings:
        sections.append(
            "- **Secret handling:** "
            "No critical/high finding is recorded under the available score files; "
            "medium findings include "
            + "; ".join(unique(medium_findings, 4))
            + "."
        )
    else:
        sections.append(
            "- **Secret handling:** "
            "No explicit secret-handling findings are recorded."
        )

    return "\n".join(sections)


# ============================================================
# Template handling
# ============================================================

def replace_table(template, table_rows):
    """
    Replace the template's matrix table while preserving the
    surrounding document.
    """

    lines = template.splitlines()

    header_index = None

    for index, line in enumerate(lines):
        if line.startswith("| Model | Task |"):
            header_index = index
            break

    if header_index is None:
        raise RuntimeError(
            "Could not find the comparison matrix table in the template."
        )

    # Find the table's final row.
    end_index = header_index + 1

    while end_index < len(lines):
        line = lines[end_index]

        if line.startswith("|"):
            end_index += 1
        else:
            break

    new_table = [
        lines[header_index],
        lines[header_index + 1],
        *table_rows,
    ]

    return "\n".join(
        lines[:header_index]
        + new_table
        + lines[end_index:]
    )


def replace_section(document, heading, replacement):
    """
    Replace everything after a heading until the next same-level
    heading.
    """

    pattern = rf"(?ms)^({re.escape(heading)}\n)(.*?)(?=^## |\Z)"

    match = re.search(pattern, document)

    if not match:
        raise RuntimeError(
            f"Could not find section '{heading}' in template."
        )

    return (
        document[:match.start()]
        + match.group(1)
        + replacement.strip()
        + "\n\n"
        + document[match.end():]
    )


# ============================================================
# Main
# ============================================================

def main():
    print("Generating comparison matrix...")
    print()
    print(f"Repository root : {ROOT}")
    print(f"Comparison dir  : {COMPARISON_DIR}")
    print(f"Template        : {TEMPLATE}")
    print(f"Output          : {OUTPUT}")
    print()

    if not TEMPLATE.exists():
        print(f"ERROR: Template does not exist:")
        print(f"  {TEMPLATE}")
        sys.exit(1)

    results = load_scores()

    print(f"Found {len(results)} score file(s).")
    print()

    for item in results:
        print(
            f"  Task {item['task_id']} | "
            f"{item['model']} | "
            f"{item['path'].relative_to(ROOT)}"
        )

    print()

    with TEMPLATE.open("r", encoding="utf-8") as handle:
        template = handle.read()

    # Table.
    table_rows = build_table_rows(results)

    document = replace_table(
        template,
        table_rows,
    )

    # Narrative.
    narrative = build_narrative(results)

    document = replace_section(
        document,
        "## Narrative (after two or more models on the same task)",
        narrative,
    )

    # Cross-cutting.
    cross_cutting = build_cross_cutting(results)

    document = replace_section(
        document,
        "## Cross-cutting patterns",
        cross_cutting,
    )

    # Add generation metadata immediately after the title.
    generated = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    document = re.sub(
        r"(?m)^# Comparison matrix\s*$",
        f"# Comparison matrix\n\n"
        f"Generated automatically from `comparison/**/score.yaml` "
        f"and `comparison/**/score.yml`.\n\n"
        f"Generated: {generated}",
        document,
        count=1,
    )

    with OUTPUT.open("w", encoding="utf-8") as handle:
        handle.write(document.rstrip() + "\n")

    print(f"SUCCESS: Generated:")
    print(f"  {OUTPUT}")
    print()
    print("Template was read only; it was not modified.")


if __name__ == "__main__":
    main()