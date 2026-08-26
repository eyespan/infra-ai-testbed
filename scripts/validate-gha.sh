#!/usr/bin/env bash
# Validate GitHub Actions YAML if actionlint is present.
set -euo pipefail
DIR="${1:-}"
if [[ -z "$DIR" || ! -d "$DIR" ]]; then
  echo "usage: $0 <dir>" >&2
  exit 2
fi
if command -v actionlint >/dev/null 2>&1; then
  mapfile -t FILES < <(find "$DIR" -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)
  actionlint "${FILES[@]}"
  echo "PASS: actionlint"
else
  echo "SKIP: actionlint not installed; checking YAML parse with python"
  python3 - "$DIR" <<'PY'
import sys
from pathlib import Path
ok = True
root = Path(sys.argv[1])
try:
    import yaml
except ImportError:
    print("SKIP: PyYAML not installed")
    sys.exit(0)
for p in root.rglob("*"):
    if p.suffix in {".yml", ".yaml"}:
        try:
            list(__import__("yaml").safe_load_all(p.read_text()))
            print("ok", p)
        except Exception as e:
            ok = False
            print("FAIL", p, e)
sys.exit(0 if ok else 1)
PY
fi
