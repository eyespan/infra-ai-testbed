#!/usr/bin/env bash
# Validate Terraform under a comparison output directory.
# Usage: scripts/validate-terraform.sh comparison/<model>/01-terraform-eks-module
set -euo pipefail
DIR="${1:-}"
if [[ -z "$DIR" || ! -d "$DIR" ]]; then
  echo "usage: $0 <dir>" >&2
  exit 2
fi
if ! command -v terraform >/dev/null 2>&1; then
  echo "SKIP: terraform not installed"
  exit 0
fi
TARGET="$DIR"
if [[ ! -f "$DIR/main.tf" ]]; then
  FOUND=$(find "$DIR" -name '*.tf' -print -quit || true)
  if [[ -n "${FOUND}" ]]; then
    TARGET=$(dirname "$FOUND")
  fi
fi
echo "=== terraform fmt (check) in $TARGET ==="
terraform fmt -check -recursive "$TARGET" || true
echo "=== terraform init -backend=false ==="
(cd "$TARGET" && terraform init -backend=false -input=false)
echo "=== terraform validate ==="
(cd "$TARGET" && terraform validate)
echo "PASS: terraform validate"
