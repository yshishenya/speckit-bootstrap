#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$REPO_ROOT/bin/speckit-bootstrap"
SPEC_KIT_VERSION="${SPEC_KIT_VERSION:-v1.0.1}"
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

grep -Fq 'MUST NOT skip clarify' "$PROJECT/.agents/skills/speckit-clarify/SKILL.md"
grep -Fq 'existing spec is updated in place' "$PROJECT/.agents/skills/speckit-specify/SKILL.md"
grep -Fq 'project canon' "$PROJECT/.agents/skills/speckit-taskstoissues/SKILL.md"
grep -Fq 'STOP with a blocking configuration error' "$PROJECT/.agents/skills/speckit-analyze/SKILL.md"
grep -Fq 'existing project files remain unstaged for review' "$PROJECT/.agents/skills/speckit-git-initialize/SKILL.md"
grep -Fq "commit_style is 'conventional'" "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py"
grep -Fq 'unresolvable file' "$PROJECT/.specify/scripts/bash/common.sh"

HARDENING_PROBE="$SANDBOX/hardening-probe"
mkdir -p "$HARDENING_PROBE"
cp -R "$PROJECT/.agents" "$HARDENING_PROBE/.agents"
cp -R "$PROJECT/.specify" "$HARDENING_PROBE/.specify"
(
  # shellcheck disable=SC1090,SC1091
  source "$BOOTSTRAP"
  # shellcheck disable=SC2034
  PROJECT_DIR="$HARDENING_PROBE"
  ensure_governed_generated_artifacts
) >/dev/null
python3 - \
  "$HARDENING_PROBE/.agents/skills/speckit-clarify/SKILL.md" \
  "$HARDENING_PROBE/.specify/templates/checklist-template.md" <<'PY'
import sys
from pathlib import Path

clarify = Path(sys.argv[1])
text = clarify.read_text(encoding="utf-8")
assert "MUST NOT skip clarify" in text
text = text.replace(
    "An explicit skip is allowed only when the selected project risk lane makes clarification optional. Capture, privacy, auth, backend, infrastructure, deletion, diagnostics, and high-risk UX lanes MUST NOT skip clarify; STOP until the required clarification is complete.",
    "If the user explicitly states they are skipping clarification (e.g., exploratory spike), you may proceed, but must warn that downstream rework risk increases.",
)
clarify.write_text(text, encoding="utf-8")

checklist = Path(sys.argv[2])
text = checklist.read_text(encoding="utf-8")
assert "Relevant constraints from plan.md, research.md, and contracts/ when present" in text
text = text.replace(
    "Relevant constraints from plan.md, research.md, and contracts/ when present",
    "Invalid late anchor fixture",
)
checklist.write_text(text, encoding="utf-8")
PY
CLARIFY_BEFORE="$(sha256sum "$HARDENING_PROBE/.agents/skills/speckit-clarify/SKILL.md" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$HARDENING_PROBE/.agents/skills/speckit-clarify/SKILL.md" | awk '{print $1}')"
if (
  # shellcheck disable=SC1090,SC1091
  source "$BOOTSTRAP"
  # shellcheck disable=SC2034
  PROJECT_DIR="$HARDENING_PROBE"
  ensure_governed_generated_artifacts
) >/dev/null 2>&1; then
  echo 'smoke-live: hardening accepted a missing late anchor' >&2
  exit 1
fi
CLARIFY_AFTER="$(sha256sum "$HARDENING_PROBE/.agents/skills/speckit-clarify/SKILL.md" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$HARDENING_PROBE/.agents/skills/speckit-clarify/SKILL.md" | awk '{print $1}')"
[[ "$CLARIFY_BEFORE" == "$CLARIFY_AFTER" ]]

HOOK_PROBE="$SANDBOX/hook-probe"
mkdir -p "$HOOK_PROBE"
cp -R "$PROJECT/.agents" "$HOOK_PROBE/.agents"
cp -R "$PROJECT/.specify" "$HOOK_PROBE/.specify"
python3 - "$HOOK_PROBE/.agents/skills" <<'PY'
import sys
from pathlib import Path

skills = Path(sys.argv[1])
guard_start = "After emitting the block above you MUST actually invoke the hook"
guard_end = "without confirmation, STOP instead of executing them."
for path in sorted(skills.glob("speckit-*/SKILL.md")):
    text = path.read_text(encoding="utf-8")
    if ".specify/extensions.yml" not in text or "EXECUTE_COMMAND" not in text:
        continue
    updated = text
    removed = 0
    while (start := updated.find(guard_start)) >= 0:
        end = updated.find(guard_end, start)
        if end < 0:
            raise SystemExit("smoke-live: incomplete mandatory hook guard fixture")
        updated = updated[:start] + updated[end + len(guard_end):]
        removed += 1
    if removed:
        path.write_text(updated, encoding="utf-8")
        break
else:
    raise SystemExit("smoke-live: no hook-bearing skill with a mandatory guard found")
PY
if (
  # shellcheck disable=SC1090,SC1091
  source "$BOOTSTRAP"
  # shellcheck disable=SC2034
  PROJECT_DIR="$HOOK_PROBE"
  ensure_governed_generated_artifacts
) >/dev/null 2>&1; then
  echo 'smoke-live: hardening accepted a hook-bearing skill without a mandatory guard' >&2
  exit 1
fi

GIT_PROBE="$SANDBOX/git-probe"
mkdir -p "$GIT_PROBE/.specify/extensions"
cp -R "$PROJECT/.specify/extensions/git" "$GIT_PROBE/.specify/extensions/git"
printf 'must stay untracked\n' > "$GIT_PROBE/local-secret.env"
GIT_AUTHOR_NAME='speckit-bootstrap CI' \
GIT_AUTHOR_EMAIL='ci@example.invalid' \
GIT_COMMITTER_NAME='speckit-bootstrap CI' \
GIT_COMMITTER_EMAIL='ci@example.invalid' \
  python3 "$GIT_PROBE/.specify/extensions/git/scripts/python/initialize_repo.py"
[[ -z "$(git -C "$GIT_PROBE" ls-files)" ]]
[[ "$(git -C "$GIT_PROBE" status --short -- local-secret.env)" == '?? local-secret.env' ]]
rm "$GIT_PROBE/local-secret.env"

printf '%s\n' \
  'commit_style: conventional' \
  'auto_commit:' \
  '  default: false' \
  '  after_specify:' > "$GIT_PROBE/.specify/extensions/git/git-config.yml"
printf '    enabled: true' >> "$GIT_PROBE/.specify/extensions/git/git-config.yml"
printf 'fixture\n' > "$GIT_PROBE/tracked.txt"
AUTO_COMMIT="$GIT_PROBE/.specify/extensions/git/scripts/python/auto_commit.py"
if python3 "$AUTO_COMMIT" after_specify >/dev/null 2>&1; then
  echo 'smoke-live: conventional Python auto-commit accepted a missing message' >&2
  exit 1
fi
git -C "$GIT_PROBE" config user.name 'speckit-bootstrap CI'
git -C "$GIT_PROBE" config user.email 'ci@example.invalid'
printf 'chore: validate generated git guards\n' > "$SANDBOX/commit-message.txt"
python3 "$AUTO_COMMIT" after_specify --message-file "$SANDBOX/commit-message.txt"
[[ "$(git -C "$GIT_PROBE" log -1 --format=%s)" == 'chore: validate generated git guards' ]]
[[ ! -e "$SANDBOX/commit-message.txt" ]]

if "$PROJECT/.specify/scripts/bash/check-prerequisites.sh" \
  --json --paths-only --template spec-template >/dev/null 2>&1; then
  echo 'smoke-live: --template with --paths-only did not fail closed' >&2
  exit 1
fi

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
