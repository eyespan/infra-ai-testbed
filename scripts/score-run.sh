#!/usr/bin/env bash
# Print a reminder of files a reviewer should have after a run.
set -euo pipefail
DIR="${1:-}"
if [[ -z "$DIR" || ! -d "$DIR" ]]; then
  echo "usage: $0 comparison/<model>/<task-id>" >&2
  exit 2
fi
echo "Run directory: $DIR"
echo
echo "Expected:"
echo "  - generated source files"
echo "  - transcript.md (optional but recommended)"
echo "  - score.yaml (copy from evaluation/scoring-template.yaml)"
echo
echo "Present:"
find "$DIR" -maxdepth 3 -type f | sort
if [[ ! -f "$DIR/score.yaml" ]]; then
  echo
  echo "MISSING score.yaml — copy evaluation/scoring-template.yaml"
  exit 1
fi
echo
echo "OK: score.yaml present"
