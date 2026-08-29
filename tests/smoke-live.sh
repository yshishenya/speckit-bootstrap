#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$REPO_ROOT/bin/speckit-bootstrap"
SPEC_KIT_VERSION="${SPEC_KIT_VERSION:-v0.15.2}"
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

# Import an installed Python-backed command exactly as the generated command
# runner does. Runtime bytecode must not alter the locked extension tree.
(
  cd "$PROJECT/.specify/extensions/github-issue-canon/scripts"
  python3 -c 'import runpy; runpy.run_path("validate_issue_canon.py")'
)
"$BOOTSTRAP" "$PROJECT" --doctor

doctor_json="$("$BOOTSTRAP" "$PROJECT" --doctor --json)"
python3 - "$doctor_json" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
assert data["status"] == "ready"
PY

LOCK="$PROJECT/.specify/speckit-bootstrap.lock.json"
python3 - \
  "$LOCK" \
  "$PROJECT/.specify/workflows/workflow-registry.json" <<'PY'
import json
import sys
from pathlib import Path

lock = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
registry = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
source = registry["workflows"]["speckit"]["source"]
expected = (
    "https://raw.githubusercontent.com/github/spec-kit/"
    f"{lock['spec_kit']['ref']}/workflows/speckit/workflow.yml"
)
assert lock["schema_version"] == 3
assert source == expected
assert lock["workflow"]["source_url"] == expected
assert "/main/" not in source
assert lock["project_skills"]
PY

if compgen -G "$HOME/.agents/skills/speckit-*" >/dev/null; then
  echo 'smoke-live: bootstrap leaked project skills into the user scope' >&2
  exit 1
fi

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

PROJECT_SKILL="$PROJECT/.agents/skills/speckit-plan/SKILL.md"
PROJECT_SKILL_BACKUP="$SANDBOX/speckit-plan-SKILL.md"
cp -p "$PROJECT_SKILL" "$PROJECT_SKILL_BACKUP"
printf '\n<!-- project skill tamper probe -->\n' >> "$PROJECT_SKILL"
if "$BOOTSTRAP" "$PROJECT" --doctor >/dev/null 2>&1; then
  echo 'smoke-live: doctor accepted a project skill that differed from the lock' >&2
  exit 1
fi
mv "$PROJECT_SKILL_BACKUP" "$PROJECT_SKILL"
"$BOOTSTRAP" "$PROJECT" --doctor

git -C "$PROJECT" add -A
git -C "$PROJECT" commit -qm 'Bootstrap Spec Kit fixture'

for repeat in 1 2; do
  NORMAL_REPEAT_LOG="$SANDBOX/normal-repeat-$repeat.log"
  "$BOOTSTRAP" "$PROJECT" | tee "$NORMAL_REPEAT_LOG"
  if ! grep -Fq 'already matches' "$NORMAL_REPEAT_LOG"; then
    echo 'smoke-live: a matching CLI was force-reinstalled on normal repeat' >&2
    exit 1
  fi
  if [[ -n "$(git -C "$PROJECT" status --short)" ]]; then
    echo "smoke-live: normal repeat $repeat was not idempotent" >&2
    git -C "$PROJECT" status --short >&2
    exit 1
  fi
done

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
echo 'smoke-live: fresh install, command import, two stable repeats, immutable workflow, integrity probes, JSON doctor, frozen rerun, and audit mode passed'
