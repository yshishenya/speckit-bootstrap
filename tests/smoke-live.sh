#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$REPO_ROOT/bin/speckit-bootstrap"
SPEC_KIT_VERSION="${SPEC_KIT_VERSION:-v0.12.11}"
SPECKIT_GITHUB_ISSUE_CANON_VERSION="${SPECKIT_GITHUB_ISSUE_CANON_VERSION:-latest}"

SANDBOX="$(mktemp -d)"
export HOME="$SANDBOX/home"
PROJECT="$SANDBOX/project"
mkdir -p "$HOME" "$PROJECT"

cleanup() {
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

git -C "$PROJECT" init -q
git -C "$PROJECT" config user.name 'speckit-bootstrap CI'
git -C "$PROJECT" config user.email 'ci@example.invalid'
printf '# smoke fixture\n' > "$PROJECT/README.md"
git -C "$PROJECT" add README.md
git -C "$PROJECT" commit -qm 'Initialize smoke fixture'

export SPEC_KIT_VERSION SPECKIT_GITHUB_ISSUE_CANON_VERSION
export SPECKIT_PONYTAIL=0

"$BOOTSTRAP" "$PROJECT" --skip-ponytail

# The child bootstrap updates its own PATH. Export uv's bin directory here for
# subsequent frozen invocations from this parent smoke-test shell.
PATH="$(uv tool dir --bin):$PATH"
export PATH

"$BOOTSTRAP" "$PROJECT" --doctor

WORKFLOW="$PROJECT/.specify/workflows/speckit/workflow.yml"
WORKFLOW_BACKUP="$SANDBOX/workflow.yml"
cp "$WORKFLOW" "$WORKFLOW_BACKUP"
printf '\n# smoke tamper probe\n' >> "$WORKFLOW"
if "$BOOTSTRAP" "$PROJECT" --doctor >/dev/null 2>&1; then
  echo 'smoke-live: doctor accepted a workflow that differed from the lock' >&2
  exit 1
fi
mv "$WORKFLOW_BACKUP" "$WORKFLOW"
"$BOOTSTRAP" "$PROJECT" --doctor

git -C "$PROJECT" add -A
git -C "$PROJECT" commit -qm 'Bootstrap Spec Kit fixture'

"$BOOTSTRAP" "$PROJECT" --skip-cli-update --skip-ponytail --frozen
if [[ -n "$(git -C "$PROJECT" status --short)" ]]; then
  echo 'smoke-live: a frozen repeat bootstrap was not idempotent' >&2
  git -C "$PROJECT" status --short >&2
  exit 1
fi

SPECKIT_TRACK_INSTALL_METADATA=1 \
  "$BOOTSTRAP" "$PROJECT" --skip-cli-update --skip-ponytail --frozen
if git -C "$PROJECT" ls-files -v .specify | grep -q '^S '; then
  echo 'smoke-live: audit mode left Spec Kit metadata hidden' >&2
  exit 1
fi

SPECKIT_TRACK_INSTALL_METADATA=1 "$BOOTSTRAP" "$PROJECT" --doctor
echo 'smoke-live: fresh install, doctor, frozen rerun, and audit mode passed'
