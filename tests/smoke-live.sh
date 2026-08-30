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
# Keep live smoke isolated from the developer's Codex plugin state; production
# bootstrap runs enable Ponytail by default unless this explicit opt-out is set.
export SPECKIT_PONYTAIL="${SPECKIT_PONYTAIL:-0}"

"$BOOTSTRAP" "$PROJECT"

# The child bootstrap updates its own PATH. Export uv's bin directory here for
# subsequent frozen invocations from this parent smoke-test shell.
PATH="$(uv tool dir --bin):$PATH"
export PATH

"$BOOTSTRAP" "$PROJECT" --doctor

python3 - "$PROJECT/.agents/skills/speckit-git-initialize/SKILL.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
blocking = (
    "If the extension scripts are not found, STOP with a blocking installation error. "
    "Do not run an inline fallback: the managed scripts own the Git availability and "
    "existing-repository guards."
)
v091 = (
    "If the extension scripts are not found, fall back to:\n"
    '- **Bash**: `git init && git commit --allow-empty -m "Initial commit from Specify template"`\n'
    '- **PowerShell**: `git init; git commit --allow-empty -m "Initial commit from Specify template"`'
)
text = path.read_text(encoding="utf-8")
if blocking not in text:
    raise SystemExit("smoke-live: blocking Git-init fallback fixture is missing")
path.write_text(text.replace(blocking, v091, 1), encoding="utf-8")
PY
(
  # shellcheck disable=SC1090,SC1091
  source "$BOOTSTRAP"
  # shellcheck disable=SC2034
  PROJECT_DIR="$PROJECT"
  ensure_governed_generated_artifacts
)
grep -Fq 'blocking installation error' "$PROJECT/.agents/skills/speckit-git-initialize/SKILL.md"
cp "$PROJECT/.agents/skills/speckit-git-initialize/SKILL.md" "$SANDBOX/git-initialize-skill.backup"
python3 - "$PROJECT/.agents/skills/speckit-git-initialize/SKILL.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
unsafe = (
    "\n\nIf the extension scripts are not found, fall back to:\n"
    '- **Bash**: `git init && git add . && git commit -m "Initial commit from Specify template"`\n'
    '- **PowerShell**: `git init; git add .; git commit -m "Initial commit from Specify template"`'
)
path.write_text(path.read_text(encoding="utf-8") + unsafe, encoding="utf-8")
PY
if (
  # shellcheck disable=SC1090,SC1091
  source "$BOOTSTRAP"
  # shellcheck disable=SC2034
  PROJECT_DIR="$PROJECT"
  ensure_governed_generated_artifacts
) >/dev/null 2>&1; then
  echo 'smoke-live: mixed Git-init fallback forms were accepted' >&2
  exit 1
fi
mv "$SANDBOX/git-initialize-skill.backup" "$PROJECT/.agents/skills/speckit-git-initialize/SKILL.md"
"$BOOTSTRAP" "$PROJECT" --doctor

# v0.9.1 already carried partial hardening in these two files. A later patch
# must migrate that exact intermediate state without accepting mixed forms.
python3 - \
  "$PROJECT/.specify/scripts/bash/common.sh" \
  "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py" <<'PY'
import sys
from pathlib import Path

common = Path(sys.argv[1])
auto_commit = Path(sys.argv[2])
final_case = '/*|..|../*|*/..|*/../*) manifest_file="" ;;'
v091_case = '/*|*../*|../*) manifest_file="" ;;'
final_cleanup = (
    "    event_name = argv[0]\n"
    "    generated_message = \"\"\n"
    "    message_file: Path | None = None\n"
    "    resolved_message_file: Path | None = None\n"
    "    if len(argv) == 3:\n"
    "        message_file = Path(argv[2]).absolute()\n"
    "        resolved_message_file = message_file.resolve()\n"
    "        try:\n"
    "            generated_message = message_file.read_text(encoding=\"utf-8\").strip()\n"
    "            # Caller owns and cleans up the transport file; never delete it here.\n"
    "        except (OSError, UnicodeDecodeError) as exc:\n"
    "            print(f\"[specify] Error: cannot read message file: {exc}\", file=sys.stderr)\n"
    "            return 1"
)
conventional_block = (
    "    commit_style = _read_commit_style(config_file)\n"
    "    if commit_style == \"conventional\":\n"
    "        if not generated_message:\n"
    "            print(\n"
    "                \"[specify] Error: commit_style is 'conventional' but no generated \"\n"
    "                \"commit message was supplied; pass --message-file <path>\",\n"
    "                file=sys.stderr,\n"
    "            )\n"
    "            return 1\n"
    "        commit_msg = generated_message\n"
)
final_conventional_anchor = (
    "    enabled, commit_msg = _parse_auto_commit_config(config_file, event_name)\n"
    "    if not enabled:\n"
    "        return 0\n\n"
    "    # Check if there are changes to commit"
)
intermediate_conventional_anchor = final_conventional_anchor.replace(
    "\n\n    # Check if there are changes to commit",
    "\n" + conventional_block + "\n    # Check if there are changes to commit",
)
v091_cleanup = (
    "    event_name = argv[0]\n"
    "    generated_message = \"\"\n"
    "    if len(argv) == 3:\n"
    "        message_file = Path(argv[2])\n"
    "        try:\n"
    "            generated_message = message_file.read_text(encoding=\"utf-8\").strip()\n"
    "            message_file.unlink()\n"
    "        except (OSError, UnicodeDecodeError) as exc:\n"
    "            print(f\"[specify] Error: cannot read message file: {exc}\", file=sys.stderr)\n"
    "            return 1"
)

common_text = common.read_text(encoding="utf-8")
auto_commit_text = auto_commit.read_text(encoding="utf-8")
assert common_text.count(final_case) == 1
assert auto_commit_text.count(final_cleanup) == 1
assert auto_commit_text.count(conventional_block) == 1
assert auto_commit_text.count(final_conventional_anchor) == 1
common.write_text(common_text.replace(final_case, v091_case, 1), encoding="utf-8")
auto_commit.write_text(
    auto_commit_text.replace(final_cleanup, v091_cleanup, 1).replace(
        final_conventional_anchor, intermediate_conventional_anchor, 1
    ),
    encoding="utf-8",
)
PY
(
  # shellcheck disable=SC1090,SC1091
  source "$BOOTSTRAP"
  # shellcheck disable=SC2034
  PROJECT_DIR="$PROJECT"
  ensure_governed_generated_artifacts
)
grep -Fq '/*|..|../*|*/..|*/../*) manifest_file="" ;;' \
  "$PROJECT/.specify/scripts/bash/common.sh"
grep -Fq 'Caller owns and cleans up the transport file' \
  "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py"
python3 - "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
block = '    commit_style = _read_commit_style(config_file)\n    if commit_style == "conventional":'
assert text.count(block) == 1
assert text.index("No changes to commit") < text.index(block)
PY

cp "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py" \
  "$SANDBOX/auto_commit.py.backup"
python3 - "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
guard = (
    "    commit_style = _read_commit_style(config_file)\n"
    "    if commit_style == \"conventional\":\n"
    "        if not generated_message:\n"
    "            print(\n"
    "                \"[specify] Error: commit_style is 'conventional' but no generated \"\n"
    "                \"commit message was supplied; pass --message-file <path>\",\n"
    "                file=sys.stderr,\n"
    "            )\n"
    "            return 1\n"
    "        commit_msg = generated_message\n"
)
mixed = (
    "    enabled, commit_msg = _parse_auto_commit_config(config_file, event_name)\n"
    "    if not enabled:\n"
    "        return 0\n"
    + guard
    + "\n    # Check if there are changes to commit"
)
path.write_text(text + "\n" + mixed + "\n", encoding="utf-8")
PY
if (
  # shellcheck disable=SC1090,SC1091
  source "$BOOTSTRAP"
  # shellcheck disable=SC2034
  PROJECT_DIR="$PROJECT"
  ensure_governed_generated_artifacts
) >/dev/null 2>&1; then
  echo 'smoke-live: mixed Python conventional-guard forms were accepted' >&2
  exit 1
fi
mv "$SANDBOX/auto_commit.py.backup" \
  "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py"

cp "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py" \
  "$SANDBOX/auto_commit.py.backup"
python3 - "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
known = (
    '            generated_message = message_file.read_text(encoding="utf-8").strip()\n'
    "            # Caller owns and cleans up the transport file; never delete it here."
)
drifted = known.replace(
    "\n",
    "\n            # unknown surrounding drift\n",
    1,
)
assert text.count(known) == 1
path.write_text(text.replace(known, drifted, 1), encoding="utf-8")
PY
if (
  # shellcheck disable=SC1090,SC1091
  source "$BOOTSTRAP"
  # shellcheck disable=SC2034
  PROJECT_DIR="$PROJECT"
  ensure_governed_generated_artifacts
) >/dev/null 2>&1; then
  echo 'smoke-live: unknown Python auto-commit cleanup form was accepted' >&2
  exit 1
fi
mv "$SANDBOX/auto_commit.py.backup" \
  "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py"

cp "$PROJECT/.specify/scripts/bash/common.sh" "$SANDBOX/common.sh.backup"
python3 - "$PROJECT/.specify/scripts/bash/common.sh" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
start = text.index('                local candidate=""\n                local declared_file="$manifest_file"')
end_marker = '                if [ -z "$candidate" ] && [ "$manifest_declared" = false ]; then'
end = text.index(end_marker, start) + len(end_marker)
final_block = text[start:end]
v091_block = final_block.replace(
    '/*|..|../*|*/..|*/../*) manifest_file="" ;;',
    '/*|*../*|../*) manifest_file="" ;;',
)
assert final_block != v091_block
path.write_text(text + "\n" + v091_block + "\n", encoding="utf-8")
PY
if (
  # shellcheck disable=SC1090,SC1091
  source "$BOOTSTRAP"
  # shellcheck disable=SC2034
  PROJECT_DIR="$PROJECT"
  ensure_governed_generated_artifacts
) >/dev/null 2>&1; then
  echo 'smoke-live: mixed preset-manifest fallback forms were accepted' >&2
  exit 1
fi
mv "$SANDBOX/common.sh.backup" "$PROJECT/.specify/scripts/bash/common.sh"
"$BOOTSTRAP" "$PROJECT" --doctor

grep -Fq 'MUST NOT skip clarify' "$PROJECT/.agents/skills/speckit-clarify/SKILL.md"
grep -Fq 'existing spec is updated in place' "$PROJECT/.agents/skills/speckit-specify/SKILL.md"
grep -Fq 'project canon' "$PROJECT/.agents/skills/speckit-taskstoissues/SKILL.md"
grep -Fq 'STOP with a blocking configuration error' "$PROJECT/.agents/skills/speckit-analyze/SKILL.md"
grep -Fq 'existing project files remain unstaged for review' "$PROJECT/.agents/skills/speckit-git-initialize/SKILL.md"
grep -Fq "commit_style is 'conventional'" "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py"
grep -Fq 'unresolvable file' "$PROJECT/.specify/scripts/bash/common.sh"
grep -Fq 'Spec Kit task IDs: T001, T002' "$PROJECT/.agents/skills/speckit-taskstoissues/SKILL.md"
grep -Fq "run \`\$speckit-taskstoissues\` first" "$PROJECT/.agents/skills/speckit-converge/SKILL.md"
grep -Fq "Push-Location \$repoRoot" "$PROJECT/.specify/extensions/git/scripts/powershell/create-new-feature-branch.ps1"
grep -Fq 'sys.dont_write_bytecode = True' "$PROJECT/.specify/extensions/git/scripts/python/create_new_feature_branch.py"
grep -Fq 'Load minimal question context' "$PROJECT/.agents/skills/speckit-checklist/SKILL.md"
grep -Fq "documents listed in \`AVAILABLE_DOCS\`" "$PROJECT/.agents/skills/speckit-checklist/SKILL.md"
grep -Fq 'Deduplicate the task IDs before processing them' "$PROJECT/.agents/skills/speckit-taskstoissues/SKILL.md"
grep -Fq 'add a successfully created ID to the covered set' "$PROJECT/.agents/skills/speckit-taskstoissues/SKILL.md"
grep -Fq 'Never remove an existing checklist' "$PROJECT/.agents/skills/speckit-checklist/SKILL.md"
grep -Fq 'never auto-committed' "$PROJECT/.agents/skills/speckit-git-commit/SKILL.md"
grep -Fq 'native argument array/binding' "$PROJECT/.agents/skills/speckit-git-feature/SKILL.md"
grep -Fq 'blocking installation error' "$PROJECT/.agents/skills/speckit-git-initialize/SKILL.md"
grep -Fq 'Numbering is per-project only' "$PROJECT/.specify/extensions/git/commands/speckit.git.feature.md"
grep -Fq 'Caller owns and cleans up the transport file' "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py"
for script in \
  "$PROJECT/.specify/extensions/git/scripts/bash/auto-commit.sh" \
  "$PROJECT/.specify/extensions/git/scripts/powershell/auto-commit.ps1" \
  "$PROJECT/.specify/extensions/git/scripts/python/auto_commit.py"; do
  grep -Fq 'message file must be outside the Git worktree' "$script"
done
grep -Fq 'if args.json_mode' "$PROJECT/.specify/extensions/git/scripts/python/create_new_feature_branch.py"
grep -Fq 'unsupported_tokens = template' "$PROJECT/.specify/extensions/git/scripts/python/create_new_feature_branch.py"
grep -Fq "\$unsupportedTokens = \$Template" "$PROJECT/.specify/extensions/git/scripts/powershell/create-new-feature-branch.ps1"
grep -Fq 'failed to enumerate extensions' "$PROJECT/.specify/scripts/bash/common.sh"
grep -Fq "Resolve-ContextPath -Root \$ProjectRoot" "$PROJECT/.specify/extensions/agent-context/scripts/powershell/update-agent-context.ps1"
grep -Fq "\$linksResolved -gt 40" "$PROJECT/.specify/extensions/agent-context/scripts/powershell/update-agent-context.ps1"
grep -Fq "\$segments.Insert(0, \$targetSegments[\$i])" "$PROJECT/.specify/extensions/agent-context/scripts/powershell/update-agent-context.ps1"
grep -Fq 'cygpath -am' "$PROJECT/.specify/extensions/git/scripts/bash/auto-commit.sh"
if rg -q 'skip hook checking silently' "$PROJECT/.agents/skills"/speckit-*/SKILL.md; then
  echo 'smoke-live: a generated post-hook still fails open on malformed YAML' >&2
  exit 1
fi

REGISTRY="$PROJECT/.specify/extensions/.registry"
REGISTRY_BACKUP="$SANDBOX/extension-registry.json"
cp -p "$REGISTRY" "$REGISTRY_BACKUP"
python3 - "$REGISTRY" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["extensions"]["git"]["enabled"] = "false"
path.write_text(json.dumps(data), encoding="utf-8")
PY
if (
  # shellcheck disable=SC1090,SC1091
  source "$PROJECT/.specify/scripts/bash/common.sh"
  _sorted_extension_ids "$PROJECT/.specify/extensions"
) >/dev/null 2>&1; then
  echo 'smoke-live: malformed extension registry metadata was accepted' >&2
  exit 1
fi
mv "$REGISTRY_BACKUP" "$REGISTRY"

PRESET_PROBE="$SANDBOX/preset-probe"
mkdir -p \
  "$PRESET_PROBE/.specify/scripts/bash" \
  "$PRESET_PROBE/.specify/presets/example/templates" \
  "$PRESET_PROBE/.specify/templates"
cp "$PROJECT/.specify/scripts/bash/common.sh" "$PRESET_PROBE/.specify/scripts/bash/common.sh"
printf 'core\n' > "$PRESET_PROBE/.specify/templates/spec-template.md"
python3 - "$PRESET_PROBE/.specify/presets/.registry" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(
    json.dumps({"presets": {"example": {"enabled": "false"}}}),
    encoding="utf-8",
)
PY
if (
  # shellcheck disable=SC1090,SC1091
  source "$PRESET_PROBE/.specify/scripts/bash/common.sh"
  resolve_template spec-template "$PRESET_PROBE"
) >/dev/null 2>&1; then
  echo 'smoke-live: malformed preset registry metadata was accepted' >&2
  exit 1
fi
python3 - "$PRESET_PROBE/.specify/presets/.registry" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(
    json.dumps({"presets": {"example": {"enabled": True}}}),
    encoding="utf-8",
)
PY
if missing_python_output="$(
  # shellcheck disable=SC1090,SC1091
  source "$PRESET_PROBE/.specify/scripts/bash/common.sh"
  # shellcheck disable=SC2317,SC2329
  _python3_command() { return 1; }
  resolve_template spec-template "$PRESET_PROBE" 2>&1
  )"; then
  echo 'smoke-live: preset registry unexpectedly resolved without Python 3' >&2
  exit 1
fi
grep -Fq \
  "Error: Python 3 is required to read $PRESET_PROBE/.specify/presets/.registry" \
  <<< "$missing_python_output"
printf 'outside\n' > "$PRESET_PROBE/outside.md"
ln -s "$PRESET_PROBE/outside.md" "$PRESET_PROBE/.specify/presets/example/templates/spec-template.md"
if (
  # shellcheck disable=SC1090,SC1091
  source "$PRESET_PROBE/.specify/scripts/bash/common.sh"
  resolve_template spec-template "$PRESET_PROBE"
) >/dev/null 2>&1; then
  echo 'smoke-live: preset template symlink escape was accepted' >&2
  exit 1
fi
if (
  # shellcheck disable=SC1090,SC1091
  source "$PRESET_PROBE/.specify/scripts/bash/common.sh"
  resolve_template_content spec-template "$PRESET_PROBE"
) >/dev/null 2>&1; then
  echo 'smoke-live: composed preset template symlink escape was accepted' >&2
  exit 1
fi

python3 - "$PROJECT/.specify/extensions/agent-context/scripts/python/update_agent_context.py" <<'PY'
import importlib.util
import sys
from pathlib import Path

sys.dont_write_bytecode = True
path = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("agent_context_probe", path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
result = module.ensure_mdc_frontmatter(" \n---\nalwaysApply: true\n---\nbody\n")
assert result.startswith("---\n"), repr(result)
assert not result.startswith((" ", "\n")), repr(result)
PY

COMMAND_PROBE="$SANDBOX/command-probe"
mkdir -p "$COMMAND_PROBE/.specify/scripts/bash"
cp "$PROJECT/.specify/scripts/bash/common.sh" "$COMMAND_PROBE/.specify/scripts/bash/common.sh"
python3 - "$COMMAND_PROBE/.specify/integration.json" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "default_integration": "codex",
    "integration_settings": {
        "codex": {
            "invoke_separator": "-",
            "parsed_options": {"skills": True},
        }
    },
}), encoding="utf-8")
PY
(
  # shellcheck disable=SC1090,SC1091
  source "$COMMAND_PROBE/.specify/scripts/bash/common.sh"
  [[ "$(format_speckit_command plan "$COMMAND_PROBE")" == "\$speckit-plan" ]]
)
python3 - "$COMMAND_PROBE/.specify/integration.json" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "default_integration": "claude",
    "integration_settings": {
        "claude": {
            "invoke_separator": ".",
            "parsed_options": {"skills": False},
        }
    },
}), encoding="utf-8")
PY
(
  # shellcheck disable=SC1090,SC1091
  source "$COMMAND_PROBE/.specify/scripts/bash/common.sh"
  [[ "$(format_speckit_command plan "$COMMAND_PROBE")" == '/speckit.plan' ]]
)

BRANCH_SCRIPT="$PROJECT/.specify/extensions/git/scripts/python/create_new_feature_branch.py"
CORE_HELPER="$PROJECT/.specify/scripts/python/common.py"
mkdir -p "$(dirname "$CORE_HELPER")"
python3 - "$CORE_HELPER" "$PROJECT" <<'PY'
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(
    "from pathlib import Path\n\n"
    f"def get_repo_root(script_file=None):\n    return Path({sys.argv[2]!r})\n",
    encoding="utf-8",
)
PY
python3 "$BRANCH_SCRIPT" --dry-run --number 999 --short-name bytecode-probe 'bytecode probe' >/dev/null
if find "$PROJECT/.specify/scripts/python" -type d -name __pycache__ -print -quit | grep -q .; then
  echo 'smoke-live: feature-branch helper wrote bytecode into the managed tree' >&2
  exit 1
fi
rm -f "$CORE_HELPER"
rmdir "$(dirname "$CORE_HELPER")"

MONOREPO="$SANDBOX/monorepo"
NESTED_PROJECT="$MONOREPO/apps/nested"
mkdir -p "$NESTED_PROJECT/.specify/extensions/git/scripts/python" \
  "$NESTED_PROJECT/.specify/extensions/git" \
  "$NESTED_PROJECT/specs/007-nested" \
  "$MONOREPO/specs/999-parent"
git -C "$MONOREPO" init -q
cp "$BRANCH_SCRIPT" \
  "$NESTED_PROJECT/.specify/extensions/git/scripts/python/create_new_feature_branch.py"
printf 'branch_prefix: nested\n' > \
  "$NESTED_PROJECT/.specify/extensions/git/git-config.yml"
NESTED_BRANCH_JSON="$(
  cd "$MONOREPO"
  python3 "$NESTED_PROJECT/.specify/extensions/git/scripts/python/create_new_feature_branch.py" \
    --json --dry-run --short-name nested-root 'nested root'
)"
python3 - "$NESTED_BRANCH_JSON" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["BRANCH_NAME"] == "nested/008-nested-root", payload
assert payload["FEATURE_NUM"] == "008", payload
PY

UPGRADE_PROBE="$SANDBOX/upgrade-probe"
mkdir -p "$UPGRADE_PROBE"
cp -R "$PROJECT/.agents" "$UPGRADE_PROBE/.agents"
cp -R "$PROJECT/.specify" "$UPGRADE_PROBE/.specify"
python3 - \
  "$UPGRADE_PROBE/.agents/skills/speckit-taskstoissues/SKILL.md" \
  "$UPGRADE_PROBE/.agents/skills/speckit-implement/SKILL.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
current = (
    "For each issue, establish task ownership only from a canonical title containing `T###:` or an explicit body "
    "field such as `Spec Kit task IDs: T001, T002`; ordinary dependency, context, or link mentions do not establish "
    "ownership. Mark open ownership matches as covered. Track closed ownership matches separately: when `tasks.md` "
    "still has that task unchecked, verify closure and implementation evidence, then either reopen the issue with a "
    "Russian reconciliation comment or STOP and report the `tasks.md` mismatch when the closure is valid. Never "
    "create a duplicate while a closed match is unresolved. Deduplicate the task IDs before processing them. Stop "
    "paginating only when every unique task ID has an open owner or a reconciled closed owner, or when there are no "
    "more pages."
)
previous = (
    "For each issue, establish task ownership only from a canonical title containing `T###:` or an explicit body "
    "field such as `Spec Kit task IDs: T001, T002`; ordinary dependency, context, or link mentions do not establish "
    "ownership. Mark open ownership matches as covered. Track closed ownership matches separately: when `tasks.md` "
    "still has that task unchecked, verify closure and implementation evidence, then either reopen the issue with a "
    "Russian reconciliation comment or STOP and report the `tasks.md` mismatch when the closure is valid. Never "
    "create a duplicate while a closed match is unresolved. Stop paginating only when every task has an open owner "
    "or a reconciled closed owner, or when there are no more pages."
)
assert current in text
path.write_text(text.replace(current, previous), encoding="utf-8")

implement = Path(sys.argv[2])
text = implement.read_text(encoding="utf-8")
final = (
    "3. Verify the analyze gate before implementation: confirm `$speckit-analyze` ran after the current `tasks.md` "
    "and met the feature threshold (default: no unresolved critical/high findings). If current evidence is absent or "
    "stale, STOP and run `$speckit-analyze` before continuing.\n\n"
    "4. Verify the issue-sync gate before implementation: when the repository has a GitHub remote and project "
    "guidance requires implementation tracking, confirm every unique executable task has an open or reconciled "
    "owner and current evidence. If ownership is absent, incomplete, or stale, STOP and run "
    "`$speckit-taskstoissues`.\n\n"
    "5. Load and analyze the implementation context:"
)
previous = (
    "4. Verify the issue-sync gate before implementation: when the repository has a GitHub remote and project "
    "guidance requires implementation tracking, confirm every unique executable task has an open or reconciled "
    "owner and current evidence. If ownership is absent, incomplete, or stale, STOP and run "
    "`$speckit-taskstoissues`.\n\n"
    "5. Load and analyze the implementation context:"
)
assert final in text
implement.write_text(text.replace(final, previous), encoding="utf-8")
PY
(
  # shellcheck disable=SC1090,SC1091
  source "$BOOTSTRAP"
  # shellcheck disable=SC2034
  PROJECT_DIR="$UPGRADE_PROBE"
  ensure_governed_generated_artifacts
) >/dev/null
grep -Fq 'Spec Kit task IDs: T001, T002' "$UPGRADE_PROBE/.agents/skills/speckit-taskstoissues/SKILL.md"
grep -Fq 'Deduplicate the task IDs before processing them' "$UPGRADE_PROBE/.agents/skills/speckit-taskstoissues/SKILL.md"
grep -Fq 'Verify the analyze gate before implementation' "$UPGRADE_PROBE/.agents/skills/speckit-implement/SKILL.md"
grep -Fq 'Verify the issue-sync gate before implementation' "$UPGRADE_PROBE/.agents/skills/speckit-implement/SKILL.md"

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
grep -Fq 'immediately integrate the accepted answer' \
  "$HARDENING_PROBE/.agents/skills/speckit-clarify/SKILL.md"
grep -Fq 'Verify the checklist gate before task generation' \
  "$HARDENING_PROBE/.agents/skills/speckit-tasks/SKILL.md"
grep -Fq 'Verify the analyze gate before external issue sync' \
  "$HARDENING_PROBE/.agents/skills/speckit-taskstoissues/SKILL.md"
grep -Fq 'do not guess or discard material decisions' \
  "$HARDENING_PROBE/.agents/skills/speckit-specify/SKILL.md"
python3 - "$HARDENING_PROBE/.agents/skills/speckit-specify/SKILL.md" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
assert "ready for `$speckit-clarify`, not planning" in text
PY

BRANCH_ERROR="$SANDBOX/unsupported-branch-template.txt"
for invalid_template in \
  'features/{number}-{slgu}' \
  'features/{slug{author}}/{number}-{slug}'; do
  printf 'branch_template: %s\n' "$invalid_template" > \
    "$HARDENING_PROBE/.specify/extensions/git/git-config.yml"
  if (
    cd "$HARDENING_PROBE"
    bash .specify/extensions/git/scripts/bash/create-new-feature-branch.sh \
      --dry-run --number 999 --short-name placeholder-probe 'placeholder probe'
  ) >"$BRANCH_ERROR" 2>&1; then
    echo 'smoke-live: unsupported branch-template placeholder was accepted' >&2
    exit 1
  fi
  grep -Fq 'unsupported or malformed placeholder' "$BRANCH_ERROR"
  if (
    cd "$HARDENING_PROBE"
    python3 .specify/extensions/git/scripts/python/create_new_feature_branch.py \
      --dry-run --number 999 --short-name placeholder-probe 'placeholder probe'
  ) >"$BRANCH_ERROR" 2>&1; then
    echo 'smoke-live: Python accepted an unsupported branch-template placeholder' >&2
    exit 1
  fi
  grep -Fq 'unsupported or malformed placeholder' "$BRANCH_ERROR"
  if command -v pwsh >/dev/null 2>&1; then
    if (
      cd "$HARDENING_PROBE"
      pwsh -NoProfile -File .specify/extensions/git/scripts/powershell/create-new-feature-branch.ps1 \
        -DryRun -Number 999 -ShortName placeholder-probe 'placeholder probe'
    ) >"$BRANCH_ERROR" 2>&1; then
      echo 'smoke-live: PowerShell accepted an unsupported branch-template placeholder' >&2
      exit 1
    fi
    grep -Fq 'unsupported or malformed placeholder' "$BRANCH_ERROR"
  fi
done
DOLLAR='$'
for shell_placeholder in "${DOLLAR}{author}" "${DOLLAR}slgu" "${DOLLAR}1" "${DOLLAR}?"; do
  printf 'branch_template: %s\n' "features/${shell_placeholder}/{number}-{slug}" > \
    "$HARDENING_PROBE/.specify/extensions/git/git-config.yml"
  if (
    cd "$HARDENING_PROBE"
    bash .specify/extensions/git/scripts/bash/create-new-feature-branch.sh \
      --dry-run --number 999 --short-name shell-placeholder-probe 'shell placeholder probe'
  ) >"$BRANCH_ERROR" 2>&1; then
    echo 'smoke-live: dollar-style branch-template placeholder was accepted' >&2
    exit 1
  fi
  grep -Fq 'shell-style placeholder' "$BRANCH_ERROR"
  if (
    cd "$HARDENING_PROBE"
    python3 .specify/extensions/git/scripts/python/create_new_feature_branch.py \
      --dry-run --number 999 --short-name shell-placeholder-probe 'shell placeholder probe'
  ) >"$BRANCH_ERROR" 2>&1; then
    echo 'smoke-live: Python accepted a dollar-style placeholder' >&2
    exit 1
  fi
  grep -Fq 'shell-style placeholder' "$BRANCH_ERROR"
  if command -v pwsh >/dev/null 2>&1; then
    if (
      cd "$HARDENING_PROBE"
      pwsh -NoProfile -File .specify/extensions/git/scripts/powershell/create-new-feature-branch.ps1 \
        -DryRun -Number 999 -ShortName shell-placeholder-probe 'shell placeholder probe'
    ) >"$BRANCH_ERROR" 2>&1; then
      echo 'smoke-live: PowerShell accepted a dollar-style placeholder' >&2
      exit 1
    fi
    grep -Fq 'shell-style placeholder' "$BRANCH_ERROR"
  fi
done
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
printf 'chore: must not be committed\n' > "$GIT_PROBE/commit-message.txt"
if python3 "$AUTO_COMMIT" after_specify --message-file "$GIT_PROBE/commit-message.txt" >/dev/null 2>&1; then
  echo 'smoke-live: Python auto-commit accepted a worktree message file' >&2
  exit 1
fi
[[ -e "$GIT_PROBE/commit-message.txt" ]]
[[ -z "$(git -C "$GIT_PROBE" log --format=%s --grep='must not be committed')" ]]
rm "$GIT_PROBE/commit-message.txt"
printf 'chore: must not be committed by Bash\n' > "$GIT_PROBE/commit-message.txt"
if "$GIT_PROBE/.specify/extensions/git/scripts/bash/auto-commit.sh" \
  after_specify --message-file "$GIT_PROBE/commit-message.txt" >/dev/null 2>&1; then
  echo 'smoke-live: Bash auto-commit accepted a worktree message file' >&2
  exit 1
fi
[[ -e "$GIT_PROBE/commit-message.txt" ]]
rm "$GIT_PROBE/commit-message.txt"
printf 'chore: must not follow a worktree symlink target\n' > "$GIT_PROBE/commit-message.txt"
ln -s "$GIT_PROBE/commit-message.txt" "$SANDBOX/worktree-message-link.txt"
if "$GIT_PROBE/.specify/extensions/git/scripts/bash/auto-commit.sh" \
  after_specify --message-file "$SANDBOX/worktree-message-link.txt" >/dev/null 2>&1; then
  echo 'smoke-live: Bash auto-commit accepted an external symlink into the worktree' >&2
  exit 1
fi
[[ -e "$GIT_PROBE/commit-message.txt" ]]
rm "$SANDBOX/worktree-message-link.txt" "$GIT_PROBE/commit-message.txt"
printf 'chore: validate generated git guards\n' > "$SANDBOX/commit-message.txt"
python3 "$AUTO_COMMIT" after_specify --message-file "$SANDBOX/commit-message.txt"
[[ "$(git -C "$GIT_PROBE" log -1 --format=%s)" == 'chore: validate generated git guards' ]]
[[ -e "$SANDBOX/commit-message.txt" ]]
python3 "$AUTO_COMMIT" after_specify

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
