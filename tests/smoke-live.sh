#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$REPO_ROOT/bin/speckit-bootstrap"
SPEC_KIT_VERSION="${SPEC_KIT_VERSION:-v0.12.15}"
SPECKIT_GITHUB_ISSUE_CANON_VERSION="${SPECKIT_GITHUB_ISSUE_CANON_VERSION:-latest}"

SANDBOX="$(mktemp -d)"
export HOME="$SANDBOX/home"
PROJECT="$SANDBOX/project"
mkdir -p "$HOME" "$PROJECT"

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  mkdir -p "$HOME/.specify"
  umask 077
  printf '%s\n' \
    '{' \
    '  "providers": [' \
    '    {' \
    '      "hosts": ["github.com", "api.github.com", "raw.githubusercontent.com", "codeload.github.com"],' \
    '      "provider": "github",' \
    '      "auth": "bearer",' \
    '      "token_env": "GITHUB_TOKEN"' \
    '    }' \
    '  ]' \
    '}' > "$HOME/.specify/auth.json"
fi

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
export SPECKIT_PONYTAIL="${SPECKIT_PONYTAIL:-0}"

"$BOOTSTRAP" "$PROJECT"

# The child bootstrap updates its own PATH. Export uv's bin directory here for
# subsequent frozen invocations from this parent smoke-test shell.
PATH="$(uv tool dir --bin):$PATH"
export PATH

"$BOOTSTRAP" "$PROJECT" --doctor

doctor_json="$("$BOOTSTRAP" "$PROJECT" --doctor --json)"
python3 - "$doctor_json" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
assert data["status"] == "ready"
PY

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

EXTENSION_SCRIPT="$PROJECT/.specify/extensions/agent-context/scripts/bash/update-agent-context.sh"
EXTENSION_BACKUP="$SANDBOX/update-agent-context.sh"
cp -p "$EXTENSION_SCRIPT" "$EXTENSION_BACKUP"
printf '\n# extension tamper probe\n' >> "$EXTENSION_SCRIPT"
if "$BOOTSTRAP" "$PROJECT" --doctor >/dev/null 2>&1; then
  echo 'smoke-live: doctor accepted an extension payload that differed from the lock' >&2
  exit 1
fi
mv "$EXTENSION_BACKUP" "$EXTENSION_SCRIPT"
"$BOOTSTRAP" "$PROJECT" --doctor

GLOBAL_SKILL="$HOME/.agents/skills/speckit-plan/SKILL.md"
GLOBAL_SKILL_BACKUP="$SANDBOX/speckit-plan-SKILL.md"
cp -p "$GLOBAL_SKILL" "$GLOBAL_SKILL_BACKUP"
printf '\n<!-- global skill tamper probe -->\n' >> "$GLOBAL_SKILL"
if "$BOOTSTRAP" "$PROJECT" --doctor >/dev/null 2>&1; then
  echo 'smoke-live: doctor accepted a managed global skill that differed from the lock' >&2
  exit 1
fi
mv "$GLOBAL_SKILL_BACKUP" "$GLOBAL_SKILL"
"$BOOTSTRAP" "$PROJECT" --doctor

git -C "$PROJECT" add -A
git -C "$PROJECT" commit -qm 'Bootstrap Spec Kit fixture'

LOCK="$PROJECT/.specify/speckit-bootstrap.lock.json"
"$BOOTSTRAP" "$PROJECT" --skip-cli-update
if [[ -n "$(git -C "$PROJECT" status --short)" ]]; then
  echo 'smoke-live: a normal repeat bootstrap was not idempotent' >&2
  git -C "$PROJECT" status --short >&2
  exit 1
fi

LOCK_BEFORE="$(sha256sum "$LOCK" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$LOCK" | awk '{print $1}')"
"$BOOTSTRAP" "$PROJECT" --skip-cli-update --frozen
LOCK_AFTER="$(sha256sum "$LOCK" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$LOCK" | awk '{print $1}')"
if [[ "$LOCK_BEFORE" != "$LOCK_AFTER" ]]; then
  echo 'smoke-live: frozen bootstrap rewrote the reproducibility lock' >&2
  exit 1
fi
if [[ -n "$(git -C "$PROJECT" status --short)" ]]; then
  echo 'smoke-live: a frozen repeat bootstrap was not idempotent' >&2
  git -C "$PROJECT" status --short >&2
  exit 1
fi

SPECKIT_TRACK_INSTALL_METADATA=1 \
  "$BOOTSTRAP" "$PROJECT" --skip-cli-update --frozen
if git -C "$PROJECT" ls-files -v .specify | grep -q '^S '; then
  echo 'smoke-live: audit mode left Spec Kit metadata hidden' >&2
  exit 1
fi

SPECKIT_TRACK_INSTALL_METADATA=1 "$BOOTSTRAP" "$PROJECT" --doctor
echo 'smoke-live: fresh install, update path, integrity probes, JSON doctor, frozen rerun, and audit mode passed'
