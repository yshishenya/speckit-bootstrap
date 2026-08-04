#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

for command in shellcheck actionlint uvx; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ci-local: missing required command: $command" >&2
    echo "ci-local: on macOS run: brew install shellcheck actionlint" >&2
    exit 1
  fi
done

scripts=(
  bin/speckit-bootstrap
  install.sh
  tests/ci-local.sh
  tests/unit.sh
  tests/smoke-live.sh
)

bash -n "${scripts[@]}"
shellcheck "${scripts[@]}"
bash tests/unit.sh
actionlint
uvx --from zizmor==1.29.0 zizmor --pedantic .

echo "ci-local: quick quality gate passed"
