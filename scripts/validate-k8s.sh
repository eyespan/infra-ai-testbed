#!/usr/bin/env bash
# Best-effort Kubernetes YAML checks.
# Usage: scripts/validate-k8s.sh comparison/<model>/02-k8s-secure-deployment
set -euo pipefail
DIR="${1:-}"
if [[ -z "$DIR" || ! -d "$DIR" ]]; then
  echo "usage: $0 <dir>" >&2
  exit 2
fi
mapfile -t FILES < <(find "$DIR" -type f \( -name '*.yaml' -o -name '*.yml' \) | sort)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "FAIL: no YAML files"
  exit 1
fi
ERRORS=0
if command -v kubeconform >/dev/null 2>&1; then
  echo "=== kubeconform ==="
  kubeconform -strict -ignore-missing-schemas "${FILES[@]}" || ERRORS=$((ERRORS+1))
elif command -v kubectl >/dev/null 2>&1; then
  echo "=== kubectl --dry-run=client ==="
  kubectl apply --dry-run=client -f "$DIR" || ERRORS=$((ERRORS+1))
else
  echo "SKIP: neither kubeconform nor kubectl installed"
fi
echo "=== secret anti-pattern scan ==="
if grep -RInE 'value:.*(supersecret|password|AKIA)' "$DIR" --include='*.yaml' --include='*.yml'; then
  echo "FAIL: possible plaintext secret"
  ERRORS=$((ERRORS+1))
else
  echo "no obvious plaintext secrets"
fi
echo "=== privileged / runAsRoot scan (informational) ==="
grep -RInE 'privileged:[[:space:]]*true|runAsUser:[[:space:]]*0' "$DIR" --include='*.yaml' --include='*.yml' || true
if [[ "$ERRORS" -gt 0 ]]; then
  echo "FAIL with $ERRORS error group(s)"
  exit 1
fi
echo "PASS"
