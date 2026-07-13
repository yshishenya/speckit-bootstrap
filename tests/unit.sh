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
  [[ "$output" == "speckit-bootstrap 0.6.1" ]]
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
  # shellcheck disable=SC2030
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
  # shellcheck disable=SC2030,SC2031
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
  capture_managed_skills_state
  verify_global_skills
  release_global_lock

  grep -Fq 'new plan' "$HOME/.agents/skills/speckit-plan/SKILL.md" || return 1
  grep -Fq 'keep custom' "$HOME/.agents/skills/speckit-project-custom/SKILL.md" || return 1
  grep -Fq 'keep unrelated' "$HOME/.agents/skills/unrelated-skill/SKILL.md" || return 1
  [[ ! -e "$HOME/.agents/.speckit-bootstrap.lock" ]] || return 1

  printf 'tampered\n' >> "$HOME/.agents/skills/speckit-plan/SKILL.md"
  if verify_global_skills 2>/dev/null; then
    return 1
  fi
  sync_global_skills
  verify_global_skills

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

test_frozen_lock_is_immutable_when_ponytail_is_skipped() (
  local sandbox="$TEST_ROOT/frozen-lock"
  PROJECT_DIR="$sandbox/project"
  mkdir -p "$PROJECT_DIR/.specify"
  python3 - "$PROJECT_DIR/.specify/speckit-bootstrap.lock.json" <<'PY'
import json
import sys
from pathlib import Path

sha = "a" * 40
digest = "b" * 64
data = {
    "schema_version": 2,
    "bootstrap_version": "0.6.1",
    "spec_kit": {"version": "v9.9.9", "ref": sha},
    "github_issue_canon": {
        "version": "custom",
        "ref": "custom",
        "installed_version": "9.9.9",
        "source_url": "https://example.test/canon.zip",
        "manifest_hash": digest,
        "tree_sha256": digest,
    },
    "extensions": {
        "agent_context": {"version": "9.9.9", "manifest_hash": digest, "tree_sha256": digest},
        "git": {"version": "9.9.9", "manifest_hash": digest, "tree_sha256": digest},
    },
    "workflow": {"id": "speckit", "version": "9.9.9", "sha256": digest},
    "ponytail": {
        "enabled": True,
        "version": "v9.9.9",
        "ref": sha,
        "marketplace_sha256": digest,
    },
    "global_skills": {"speckit-plan": digest},
}
Path(sys.argv[1]).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

  # shellcheck disable=SC2030
  FROZEN=1
  SKIP_PONYTAIL=1
  local lock="$PROJECT_DIR/.specify/speckit-bootstrap.lock.json"
  local before after
  before="$(sha256_for_test "$lock")"
  prepare_versions
  [[ "$SKIP_PONYTAIL" -eq 1 ]] || return 1
  [[ "$RESOLVED_PONYTAIL_VERSION" == "v9.9.9" ]] || return 1
  write_lock_file >/dev/null
  after="$(sha256_for_test "$lock")"
  [[ "$before" == "$after" ]] || return 1
  [[ "$(read_lock_value "$lock" ponytail.enabled)" == "true" ]]
)

test_extension_tree_integrity_detects_payload_tampering() (
  local sandbox="$TEST_ROOT/extension-tree"
  PROJECT_DIR="$sandbox/project"
  local extension="$PROJECT_DIR/.specify/extensions/demo"
  mkdir -p "$extension/scripts"
  printf '#!/usr/bin/env bash\necho safe\n' > "$extension/scripts/run.sh"
  chmod +x "$extension/scripts/run.sh"
  printf '{"extensions":{"demo":{"version":"1.2.3","manifest_hash":"manifest"}}}\n' \
    > "$PROJECT_DIR/.specify/extensions/.registry"

  local expected_tree
  expected_tree="$(extension_tree_hash demo)"
  verify_locked_extension \
    demo 1.2.3 manifest "$expected_tree" ".specify/extensions/demo/scripts/run.sh"

  printf 'echo tampered\n' >> "$extension/scripts/run.sh"
  if verify_locked_extension \
    demo 1.2.3 manifest "$expected_tree" ".specify/extensions/demo/scripts/run.sh" 2>/dev/null; then
    return 1
  fi
)

test_frozen_skip_cli_update_requires_locked_commit() (
  local sandbox="$TEST_ROOT/cli-ref"
  local tool="$sandbox/home/.local/share/uv/tools/specify-cli"
  local bin="$sandbox/bin"
  local site="$tool/lib/python3.11/site-packages/specify_cli-9.9.9.dist-info"
  local expected_ref="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  local wrong_ref="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  mkdir -p "$tool/bin" "$site" "$bin"
  ln -s /bin/bash "$tool/bin/python"
  {
    printf '#!%s\n' "$tool/bin/python"
    # The literal positional parameter belongs to the generated fake launcher.
    # shellcheck disable=SC2016
    printf 'if [[ "${1:-}" == "--version" ]]; then echo "specify-cli 9.9.9"; exit 0; fi\n'
    printf 'exit 0\n'
  } > "$bin/specify"
  chmod +x "$bin/specify"
  printf '{"url":"https://github.com/github/spec-kit.git","vcs_info":{"commit_id":"%s"}}\n' \
    "$wrong_ref" > "$site/direct_url.json"

  # shellcheck disable=SC2031
  PATH="$bin:$PATH"
  export PATH
  # shellcheck disable=SC2031
  export FROZEN=1
  export SKIP_CLI_UPDATE=1
  export RESOLVED_SPEC_KIT_VERSION="v9.9.9"
  export RESOLVED_SPEC_KIT_REF="$expected_ref"
  if install_cli 2>/dev/null; then
    return 1
  fi

  printf '{"url":"https://github.com/github/spec-kit.git","vcs_info":{"commit_id":"%s"}}\n' \
    "$expected_ref" > "$site/direct_url.json"
  install_cli
)

test_signal_handler_releases_lock_and_exits() (
  local sandbox="$TEST_ROOT/signal"
  local output status
  mkdir -p "$sandbox/home"
  set +e
  output="$(HOME="$sandbox/home" /bin/bash -c '
    set -euo pipefail
    source "$1"
    acquire_global_lock
    install_global_lock_traps
    kill -TERM "$$"
    echo continued
  ' _ "$BOOTSTRAP" 2>&1)"
  status=$?
  set -e

  [[ "$status" -eq 143 ]] || return 1
  [[ "$output" != *continued* ]] || return 1
  [[ ! -e "$sandbox/home/.agents/.speckit-bootstrap.lock" ]]
)

test_ponytail_marketplace_path_is_canonical() (
  local sandbox="$TEST_ROOT/ponytail-path"
  local real_home="$sandbox/private-home"
  local linked_home="$sandbox/linked-home"
  mkdir -p "$real_home"
  ln -s "$real_home" "$linked_home"
  # shellcheck disable=SC2031
  export HOME="$linked_home"
  RESOLVED_PONYTAIL_VERSION="v9.9.9"

  local canonical_home
  canonical_home="$(canonical_path "$real_home")"

  [[ "$(ponytail_managed_marketplace_path)" == \
     "$canonical_home/.codex/speckit-bootstrap/marketplaces/ponytail/v9.9.9" ]]
)

test_json_mode_keeps_stdout_machine_readable() (
  local sandbox="$TEST_ROOT/json-output"
  local stdout="$sandbox/stdout.json"
  local stderr="$sandbox/stderr.log"
  mkdir -p "$sandbox"

  /bin/bash -c '
    set -euo pipefail
    source "$1"
    OUTPUT_JSON=1
    PROJECT_DIR="$2"
    RESOLVED_SPEC_KIT_VERSION="v9.9.9"
    RESOLVED_SPEC_KIT_REF="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    RESOLVED_ISSUE_CANON_VERSION="v9.9.9"
    RESOLVED_ISSUE_CANON_REF="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    configure_machine_output
    echo "human diagnostic"
    print_final_summary ready
  ' _ "$BOOTSTRAP" "$sandbox/project" > "$stdout" 2> "$stderr"

  python3 - "$stdout" <<'PY'
import json
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
assert len(lines) == 1
assert json.loads(lines[0])["status"] == "ready"
PY
  grep -Fq 'human diagnostic' "$stderr"
)

test_release_publish_job_does_not_execute_repository_code() {
  python3 - "$REPO_ROOT/.github/workflows/release-assets.yml" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
build = text.split("  build:\n", 1)[1].split("\n  publish:\n", 1)[0]
publish = text.split("\n  publish:\n", 1)[1]
assert "contents: write" not in build
assert "bash tests/unit.sh" in build
assert "actions/upload-artifact@" in build
assert "contents: write" in publish
assert "actions/download-artifact@" in publish
assert "actions/checkout@" not in publish
assert "bash tests/unit.sh" not in publish
assert "bin/speckit-bootstrap" not in publish
assert '--repo "$GITHUB_REPOSITORY"' in publish
PY
}

printf '1..12\n'
run_test 'version and sourceability' test_version_and_sourceability
run_test 'catalog merge is additive and idempotent' test_catalog_merge_is_additive_and_idempotent
run_test 'global skill sync preserves user content and detects tampering' test_atomic_global_skill_sync_preserves_user_content
run_test 'issue canon files preserve user templates' test_issue_canon_files_preserve_user_template
run_test 'audit mode unhides install metadata' test_audit_mode_unhides_install_metadata
run_test 'frozen lock stays immutable when Ponytail is skipped' test_frozen_lock_is_immutable_when_ponytail_is_skipped
run_test 'extension tree integrity detects payload tampering' test_extension_tree_integrity_detects_payload_tampering
run_test 'frozen skipped CLI requires the locked commit' test_frozen_skip_cli_update_requires_locked_commit
run_test 'signal handler releases the lock and exits' test_signal_handler_releases_lock_and_exits
run_test 'Ponytail marketplace path is canonical' test_ponytail_marketplace_path_is_canonical
run_test 'JSON mode keeps stdout machine-readable' test_json_mode_keeps_stdout_machine_readable
run_test 'release publish job does not execute repository code' test_release_publish_job_does_not_execute_repository_code

if [[ "$TESTS_FAILED" -ne 0 ]]; then
  printf '%s test(s) failed\n' "$TESTS_FAILED" >&2
  exit 1
fi
