#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$REPO_ROOT/bin/speckit-bootstrap"

# The executable is intentionally sourceable so its stateful helpers can be
# exercised without reaching GitHub or mutating the developer's real home.
# shellcheck source=../bin/speckit-bootstrap
# shellcheck disable=SC1091
source "$BOOTSTRAP"

TEST_ROOT="$(mktemp -d)"
TESTS_RUN=0
TESTS_FAILED=0

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

run_test() {
  local name="$1"
  shift
  TESTS_RUN=$((TESTS_RUN + 1))
  if "$@"; then
    printf 'ok %s - %s\n' "$TESTS_RUN" "$name"
  else
    printf 'not ok %s - %s\n' "$TESTS_RUN" "$name" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_version_and_sourceability() {
  local output
  output="$("$BOOTSTRAP" --version)"
  [[ "$output" == "speckit-bootstrap 0.6.0" ]]
}

test_catalog_merge_is_additive_and_idempotent() (
  local sandbox="$TEST_ROOT/catalog"
  # shellcheck disable=SC2030
  export HOME="$sandbox/home"
  mkdir -p "$HOME/.specify" "$sandbox/bin"
  cat > "$HOME/.specify/extension-catalogs.yml" <<'EOF'
catalogs:
  - name: custom
    url: https://example.test/custom/catalog.json
    priority: 5
    install_allowed: false
EOF

  cat > "$sandbox/bin/specify" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "extension" && "$2" == "catalog" && "$3" == "add" ]]
url="$4"
shift 4
name=""
priority=""
description=""
install_allowed=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --priority) priority="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    --install-allowed) install_allowed=true; shift ;;
    *) exit 2 ;;
  esac
done
config="$HOME/.specify/extension-catalogs.yml"
{
  printf '  - name: %s\n' "$name"
  printf '    url: %s\n' "$url"
  printf '    priority: %s\n' "$priority"
  printf '    install_allowed: %s\n' "$install_allowed"
  printf '    description: %s\n' "$description"
} >> "$config"
EOF
  chmod +x "$sandbox/bin/specify"
  PATH="$sandbox/bin:$PATH"
  export PATH

  ensure_user_extension_catalog
  local first
  first="$(sha256_for_test "$HOME/.specify/extension-catalogs.yml")"
  ensure_user_extension_catalog
  local second
  second="$(sha256_for_test "$HOME/.specify/extension-catalogs.yml")"

  [[ "$first" == "$second" ]] || return 1
  grep -Fq 'https://example.test/custom/catalog.json' "$HOME/.specify/extension-catalogs.yml" || return 1
  grep -Fq "$YAN_EXTENSION_CATALOG_URL" "$HOME/.specify/extension-catalogs.yml" || return 1
  grep -Fq 'https://raw.githubusercontent.com/github/spec-kit/main/extensions/catalog.json' "$HOME/.specify/extension-catalogs.yml" || return 1
  grep -Fq 'https://raw.githubusercontent.com/github/spec-kit/main/extensions/catalog.community.json' "$HOME/.specify/extension-catalogs.yml"
)

sha256_for_test() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

test_atomic_global_skill_sync_preserves_user_content() (
  local sandbox="$TEST_ROOT/skills"
  # shellcheck disable=SC2031
  export HOME="$sandbox/home"
  PROJECT_DIR="$sandbox/project"
  mkdir -p \
    "$PROJECT_DIR/.agents/skills/speckit-plan" \
    "$HOME/.agents/skills/speckit-project-custom" \
    "$HOME/.agents/skills/unrelated-skill"
  printf 'new plan\n' > "$PROJECT_DIR/.agents/skills/speckit-plan/SKILL.md"
  printf 'keep custom\n' > "$HOME/.agents/skills/speckit-project-custom/SKILL.md"
  printf 'keep unrelated\n' > "$HOME/.agents/skills/unrelated-skill/SKILL.md"

  acquire_global_lock
  sync_global_skills
  release_global_lock

  grep -Fq 'new plan' "$HOME/.agents/skills/speckit-plan/SKILL.md" || return 1
  grep -Fq 'keep custom' "$HOME/.agents/skills/speckit-project-custom/SKILL.md" || return 1
  grep -Fq 'keep unrelated' "$HOME/.agents/skills/unrelated-skill/SKILL.md" || return 1
  [[ ! -e "$HOME/.agents/.speckit-bootstrap.lock" ]] || return 1

  mkdir "$HOME/.agents/.speckit-bootstrap.lock"
  printf '99999999\n' > "$HOME/.agents/.speckit-bootstrap.lock/pid"
  acquire_global_lock
  release_global_lock
  [[ ! -e "$HOME/.agents/.speckit-bootstrap.lock" ]]
)

test_issue_canon_files_preserve_user_template() (
  local sandbox="$TEST_ROOT/canon"
  PROJECT_DIR="$sandbox/project"
  local extension="$PROJECT_DIR/.specify/extensions/github-issue-canon/templates"
  mkdir -p \
    "$extension/docs/agent-guidance" \
    "$extension/github/ISSUE_TEMPLATE" \
    "$PROJECT_DIR/.github"
  printf '<!-- managed-by: github-issue-canon -->\ncanon\n' > "$extension/docs/agent-guidance/github-issue-canon.md"
  printf 'blank_issues_enabled: false\n' > "$extension/github/ISSUE_TEMPLATE/config.yml"
  printf 'name: Spec Kit work item\n' > "$extension/github/ISSUE_TEMPLATE/spec-kit-work-item.yml"
  printf 'managed PR template\n' > "$extension/github/pull_request_template.md"
  printf 'user-owned PR template\n' > "$PROJECT_DIR/.github/pull_request_template.md"

  ensure_issue_canon_project_files

  grep -Fq 'canon' "$PROJECT_DIR/docs/agent-guidance/github-issue-canon.md" || return 1
  grep -Fq 'blank_issues_enabled' "$PROJECT_DIR/.github/ISSUE_TEMPLATE/config.yml" || return 1
  grep -Fq 'Spec Kit work item' "$PROJECT_DIR/.github/ISSUE_TEMPLATE/spec-kit-work-item.yml" || return 1
  grep -Fq 'user-owned PR template' "$PROJECT_DIR/.github/pull_request_template.md"
)

test_audit_mode_unhides_install_metadata() (
  local sandbox="$TEST_ROOT/metadata"
  mkdir -p "$sandbox"
  cd "$sandbox"
  git init -q
  local file
  for file in \
    .specify/init-options.json \
    .specify/integration.json \
    .specify/integrations/speckit.manifest.json \
    .specify/integrations/codex.manifest.json \
    .specify/extensions/.registry \
    .specify/workflows/workflow-registry.json
  do
    mkdir -p "$(dirname "$file")"
    printf '{}\n' > "$file"
  done
  git add .specify

  export TRACK_INSTALL_METADATA=0
  hide_install_metadata_diffs
  git ls-files -v .specify | grep -q '^S ' || return 1

  export TRACK_INSTALL_METADATA=1
  hide_install_metadata_diffs
  if git ls-files -v .specify | grep -q '^S '; then
    return 1
  fi
)

printf '1..5\n'
run_test 'version and sourceability' test_version_and_sourceability
run_test 'catalog merge is additive and idempotent' test_catalog_merge_is_additive_and_idempotent
run_test 'atomic global skill sync preserves user content' test_atomic_global_skill_sync_preserves_user_content
run_test 'issue canon files preserve user templates' test_issue_canon_files_preserve_user_template
run_test 'audit mode unhides install metadata' test_audit_mode_unhides_install_metadata

if [[ "$TESTS_FAILED" -ne 0 ]]; then
  printf '%s test(s) failed\n' "$TESTS_FAILED" >&2
  exit 1
fi
