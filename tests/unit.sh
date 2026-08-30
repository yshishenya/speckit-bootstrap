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
  [[ "$output" == "speckit-bootstrap 0.9.0" ]]
}

test_installer_reports_missing_path() (
  local sandbox="$TEST_ROOT/installer-path"
  local install_dir="$sandbox/bin"
  local checksum output
  mkdir -p "$sandbox/home"
  checksum="$(sha256_for_test "$BOOTSTRAP")"

  output="$(
    HOME="$sandbox/home" \
      PATH="/usr/bin:/bin" \
      SPECKIT_BOOTSTRAP_INSTALL_DIR="$install_dir" \
      SPECKIT_BOOTSTRAP_URL="file://$BOOTSTRAP" \
      SPECKIT_BOOTSTRAP_SHA256="$checksum" \
      bash "$REPO_ROOT/install.sh"
  )"

  [[ -x "$install_dir/speckit-bootstrap" ]] || return 1
  grep -Fq \
    "Add it to PATH for this shell: export PATH=\"$install_dir:\$PATH\"" \
    <<< "$output"
)

test_issue_canon_catalog_entry_requires_checksum() (
  local sandbox="$TEST_ROOT/catalog-entry"
  local catalog="$sandbox/catalog.json"
  mkdir -p "$sandbox"
  cat > "$catalog" <<'EOF'
{
  "extensions": {
    "github-issue-canon": {
      "version": "0.3.0",
      "download_url": "https://example.test/github-issue-canon-0.3.0.zip",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  }
}
EOF
  local entry
  entry="$(YAN_EXTENSION_CATALOG_URL="file://$catalog" resolve_issue_canon_catalog_entry)"
  [[ "$entry" == $'v0.3.0\thttps://example.test/github-issue-canon-0.3.0.zip\t'"$(printf 'a%.0s' {1..64})" ]] || return 1

  python3 - "$catalog" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["extensions"]["github-issue-canon"]["sha256"] = "missing"
path.write_text(json.dumps(data), encoding="utf-8")
PY
  if YAN_EXTENSION_CATALOG_URL="file://$catalog" \
    resolve_issue_canon_catalog_entry >/dev/null 2>&1; then
    return 1
  fi
)

test_pinned_issue_canon_uses_tagged_catalog() (
  local sandbox="$TEST_ROOT/pinned-catalog"
  local spec_ref canon_ref pinned_catalog
  mkdir -p "$sandbox/project"
  spec_ref="$(printf 'a%.0s' {1..40})"
  canon_ref="$(printf 'b%.0s' {1..40})"
  pinned_catalog="https://raw.githubusercontent.com/yshishenya/spec-kit-ext-github-issue-canon/$canon_ref/catalog.json"

  PROJECT_DIR="$sandbox/project"
  FROZEN=0
  SKIP_CLI_UPDATE=0
  SKIP_PONYTAIL=1
  export GITHUB_ISSUE_CANON_EXTENSION_URL=""
  export SPECKIT_GITHUB_ISSUE_CANON_VERSION="v0.3.1"
  unset SPECKIT_EXTENSION_CATALOG_URL

  # shellcheck disable=SC2317,SC2329
  resolve_spec_kit_version() { printf 'v0.15.2\n'; }
  # shellcheck disable=SC2317,SC2329
  resolve_tag_commit() {
    case "$1" in
      https://github.com/github/spec-kit.git) printf '%s\n' "$spec_ref" ;;
      *) printf '%s\n' "$canon_ref" ;;
    esac
  }
  # shellcheck disable=SC2317,SC2329
  require_remote_tag() { :; }
  # shellcheck disable=SC2317,SC2329
  resolve_issue_canon_catalog_entry() {
    printf '%s\n' "$YAN_EXTENSION_CATALOG_URL" >> "$sandbox/catalog-calls"
    [[ "$YAN_EXTENSION_CATALOG_URL" == "$pinned_catalog" ]] || return 1
    printf 'v0.3.1\thttps://example.test/github-issue-canon-v0.3.1.zip\t%s\n' \
      "$(printf 'c%.0s' {1..64})"
  }

  prepare_versions

  [[ "$(wc -l < "$sandbox/catalog-calls")" -eq 1 ]] || return 1
  [[ "$RESOLVED_ISSUE_CANON_CATALOG_URL" == "$pinned_catalog" ]] || return 1
  [[ "$ISSUE_CANON_INSTALL_FROM_CATALOG" -eq 1 ]]
)

test_catalog_install_checks_expected_version_and_skill() (
  local sandbox="$TEST_ROOT/catalog-install"
  PROJECT_DIR="$sandbox/project"
  RESOLVED_ISSUE_CANON_CATALOG_URL="https://example.test/pinned/catalog.json"
  local skill=".agents/skills/speckit-github-issue-canon-ensure/SKILL.md"
  mkdir -p "$PROJECT_DIR/$(dirname "$skill")"
  printf 'skill\n' > "$PROJECT_DIR/$skill"

  # Invoked indirectly by ensure_extension_from_catalog.
  # shellcheck disable=SC2317,SC2329
  specify() {
    [[ "$SPECKIT_CATALOG_URL" == "$RESOLVED_ISSUE_CANON_CATALOG_URL" ]] || return 1
    [[ "$*" == "extension add github-issue-canon --force" ]]
  }
  # shellcheck disable=SC2317,SC2329
  extension_version() {
    printf '0.3.0\n'
  }

  ensure_extension_from_catalog github-issue-canon v0.3.0 "$skill"
)

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

make_fake_specify_cli() {
  local sandbox="$1"
  local commit="$2"
  local tool="$sandbox/home/.local/share/uv/tools/specify-cli"
  local bin="$sandbox/bin"
  local site="$tool/lib/python3.11/site-packages/specify_cli-9.9.9.dist-info"
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
    "$commit" > "$site/direct_url.json"
}

test_project_skill_manifest_detects_tampering() (
  local sandbox="$TEST_ROOT/skills"
  PROJECT_DIR="$sandbox/project"
  mkdir -p "$PROJECT_DIR/.agents/skills/speckit-plan"
  printf 'project plan\n' > "$PROJECT_DIR/.agents/skills/speckit-plan/SKILL.md"

  capture_project_skills_state
  verify_project_skills

  printf 'tampered\n' >> "$PROJECT_DIR/.agents/skills/speckit-plan/SKILL.md"
  if verify_project_skills 2>/dev/null; then
    return 1
  fi
  printf 'project plan\n' > "$PROJECT_DIR/.agents/skills/speckit-plan/SKILL.md"

  mkdir -p "$PROJECT_DIR/.agents/skills/speckit-unrecorded"
  printf 'unrecorded\n' > "$PROJECT_DIR/.agents/skills/speckit-unrecorded/SKILL.md"
  if verify_project_skills 2>/dev/null; then
    return 1
  fi
  rm -rf "$PROJECT_DIR/.agents/skills/speckit-unrecorded"

  ln -s speckit-plan "$PROJECT_DIR/.agents/skills/speckit-linked"
  ! verify_project_skills 2>/dev/null
)

test_schema_v2_migration_preserves_all_global_skills() (
  local sandbox="$TEST_ROOT/legacy-global-skills"
  local global_skills="$sandbox/home/.agents/skills"
  local lock="$sandbox/project/.specify/speckit-bootstrap.lock.json"
  local unchanged_digest modified_digest output
  # shellcheck disable=SC2030,SC2031
  export HOME="$sandbox/home"
  PROJECT_DIR="$sandbox/project"
  mkdir -p \
    "$global_skills/speckit-unchanged" \
    "$global_skills/speckit-modified" \
    "$(dirname "$lock")"
  printf 'unchanged\n' > "$global_skills/speckit-unchanged/SKILL.md"
  printf 'original\n' > "$global_skills/speckit-modified/SKILL.md"
  unchanged_digest="$(tree_sha256 "$global_skills/speckit-unchanged")"
  modified_digest="$(tree_sha256 "$global_skills/speckit-modified")"
  python3 - "$lock" "$unchanged_digest" "$modified_digest" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "schema_version": 2,
    "global_skills": {
        "speckit-modified": sys.argv[3],
        "speckit-unchanged": sys.argv[2],
    },
}) + "\n", encoding="utf-8")
PY
  printf 'user edit\n' >> "$global_skills/speckit-modified/SKILL.md"

  output="$(migrate_legacy_global_skills 2>&1)"

  [[ -f "$global_skills/speckit-unchanged/SKILL.md" ]] || return 1
  [[ -f "$global_skills/speckit-modified/SKILL.md" ]] || return 1
  grep -Fq 'preserved legacy user-level skills' <<< "$output" || return 1
  grep -Fq 'remove duplicates manually' <<< "$output"
)

test_managed_project_paths_reject_symlinks() (
  local sandbox="$TEST_ROOT/managed-path-symlink"
  PROJECT_DIR="$sandbox/project"
  mkdir -p "$PROJECT_DIR" "$sandbox/outside"
  printf 'outside\n' > "$sandbox/outside/AGENTS.md"
  ln -s "$sandbox/outside/AGENTS.md" "$PROJECT_DIR/AGENTS.md"

  if require_safe_managed_paths >/dev/null 2>&1; then
    return 1
  fi
  [[ "$(cat "$sandbox/outside/AGENTS.md")" == "outside" ]]
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

test_doctor_explains_hidden_metadata_drift() (
  local sandbox="$TEST_ROOT/hidden-drift"
  local output
  PROJECT_DIR="$sandbox/project"
  mkdir -p "$PROJECT_DIR/.specify/extensions"
  git -C "$PROJECT_DIR" init -q
  printf '{}\n' > "$PROJECT_DIR/.specify/extensions/.registry"
  git -C "$PROJECT_DIR" add .specify/extensions/.registry
  git -C "$PROJECT_DIR" update-index --skip-worktree .specify/extensions/.registry
  printf '{"drift":true}\n' > "$PROJECT_DIR/.specify/extensions/.registry"

  output="$(explain_hidden_install_metadata_drift 2>&1)"
  grep -Fq '.specify/extensions/.registry' <<< "$output" || return 1
  grep -Fq \
    'SPECKIT_TRACK_INSTALL_METADATA=1 speckit-bootstrap . --doctor' \
    <<< "$output"
)

test_integration_refresh_respects_local_changes() (
  local sandbox="$TEST_ROOT/integration-refresh"
  local calls="$sandbox/calls"
  local scenario="upgrade"
  mkdir -p "$sandbox/project"
  PROJECT_DIR="$sandbox/project"

  # shellcheck disable=SC2317,SC2329
  specify() {
    printf '%s\n' "$*" >> "$calls"
    if [[ "$1 $2" == "integration status" ]]; then
      if [[ "$scenario" == "missing" ]]; then
        printf 'No integration currently installed\n'
      else
        printf 'Integration: codex\n'
      fi
      return 0
    fi
    [[ "$scenario" != "upgrade" ]]
  }

  if ensure_codex_integration >/dev/null 2>&1; then
    return 1
  fi
  grep -Fxq 'integration upgrade codex --integration-options=--skills' "$calls" || return 1
  if grep -Fq -- '--force' "$calls" || grep -Fq 'integration install' "$calls"; then
    return 1
  fi

  : > "$calls"
  scenario="missing"
  ensure_codex_integration >/dev/null
  grep -Fxq 'integration install codex --integration-options=--skills' "$calls" || return 1
  ! grep -Fq -- '--force' "$calls"
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
    "schema_version": 3,
    "bootstrap_version": "0.8.1",
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
    "workflow": {
        "id": "speckit",
        "version": "9.9.9",
        "sha256": digest,
        "source_url": f"https://raw.githubusercontent.com/github/spec-kit/{sha}/workflows/speckit/workflow.yml",
    },
    "ponytail": {
        "enabled": True,
        "version": "v9.9.9",
        "ref": sha,
        "marketplace_sha256": digest,
    },
    "project_skills": {"speckit-plan": digest},
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

test_matching_cli_skips_force_reinstall() (
  local sandbox="$TEST_ROOT/cli-fast-path"
  local tool="$sandbox/home/.local/share/uv/tools/specify-cli"
  local bin="$sandbox/bin"
  local site="$tool/lib/python3.11/site-packages/specify_cli-9.9.9.dist-info"
  local calls="$sandbox/uv-calls"
  local expected_ref="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  local wrong_ref="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local output
  make_fake_specify_cli "$sandbox" "$expected_ref"

  # Invoked indirectly by install_cli.
  # shellcheck disable=SC2317,SC2329
  uv() {
    printf '%s\n' "$*" >> "$calls"
    if [[ "$*" == "tool dir --bin" ]]; then
      printf '%s\n' "$bin"
    fi
  }

  # shellcheck disable=SC2030,SC2031
  PATH="$bin:$PATH"
  export PATH
  # shellcheck disable=SC2030,SC2031
  SKIP_CLI_UPDATE=0
  # shellcheck disable=SC2030,SC2031
  FROZEN=0
  # shellcheck disable=SC2030,SC2031
  RESOLVED_SPEC_KIT_VERSION="v9.9.9"
  # shellcheck disable=SC2030,SC2031
  RESOLVED_SPEC_KIT_REF="$expected_ref"

  output="$(install_cli)"
  [[ "$output" == *"already matches"* ]] || return 1
  [[ ! -e "$calls" ]] || return 1

  printf '{"url":"https://github.com/github/spec-kit.git","vcs_info":{"commit_id":"%s"}}\n' \
    "$wrong_ref" > "$site/direct_url.json"
  install_cli >/dev/null
  grep -Fq \
    "tool install specify-cli --force --from git+https://github.com/github/spec-kit.git@$expected_ref" \
    "$calls"
)

test_frozen_skip_cli_update_requires_locked_commit() (
  local sandbox="$TEST_ROOT/cli-ref"
  local tool="$sandbox/home/.local/share/uv/tools/specify-cli"
  local bin="$sandbox/bin"
  local site="$tool/lib/python3.11/site-packages/specify_cli-9.9.9.dist-info"
  local expected_ref="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  local wrong_ref="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  make_fake_specify_cli "$sandbox" "$wrong_ref"

  # shellcheck disable=SC2030,SC2031
  PATH="$bin:$PATH"
  export PATH
  # shellcheck disable=SC2030,SC2031
  export FROZEN=1
  # shellcheck disable=SC2030,SC2031
  export SKIP_CLI_UPDATE=1
  # shellcheck disable=SC2030,SC2031
  export RESOLVED_SPEC_KIT_VERSION="v9.9.9"
  # shellcheck disable=SC2030,SC2031
  export RESOLVED_SPEC_KIT_REF="$expected_ref"
  if install_cli 2>/dev/null; then
    return 1
  fi

  printf '{"url":"https://github.com/github/spec-kit.git","vcs_info":{"commit_id":"%s"}}\n' \
    "$expected_ref" > "$site/direct_url.json"
  install_cli
)

test_ponytail_is_opt_in() (
  local sandbox="$TEST_ROOT/ponytail-opt-in"
  mkdir -p "$sandbox"

  PROJECT_DIR=""
  SKIP_PONYTAIL=1
  unset SPECKIT_PONYTAIL
  parse_args "$sandbox"
  [[ "$SKIP_PONYTAIL" -eq 1 ]] || return 1

  PROJECT_DIR=""
  SKIP_PONYTAIL=1
  parse_args "$sandbox" --with-ponytail
  [[ "$SKIP_PONYTAIL" -eq 0 ]]
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
package = text.split("  package:\n", 1)[1].split("\n  publish:\n", 1)[0]
publish = text.split("\n  publish:\n", 1)[1]
assert "push:" in text and "tags:" in text
assert "release:" not in text
assert "contents: write" not in package
assert "bash tests/unit.sh" not in text
assert "actions/upload-artifact@" in package
assert "git for-each-ref" in package
assert "%(contents:subject)%0a%0a%(contents:body)" in package
assert "--format='%(contents)'" not in package
assert "contents: write" in publish
assert "actions/download-artifact@" in publish
assert "actions/checkout@" not in publish
assert "bin/speckit-bootstrap" not in publish
assert '--repo "$GITHUB_REPOSITORY"' in publish
assert "--notes-file dist/release-notes.md" in publish
assert 'gh release verify "$RELEASE_TAG"' in publish
assert publish.count('gh release verify-asset "$RELEASE_TAG"') == 2
PY
}

test_ci_topology_avoids_duplicate_sha_runs() {
  python3 - \
    "$REPO_ROOT/.github/workflows/ci.yml" \
    "$REPO_ROOT/.github/workflows/upstream-canary.yml" \
    "$REPO_ROOT/.github/dependabot.yml" \
    "$BOOTSTRAP" \
    "$REPO_ROOT/tests/smoke-live.sh" <<'PY'
import sys
from pathlib import Path

ci = Path(sys.argv[1]).read_text(encoding="utf-8")
canary = Path(sys.argv[2]).read_text(encoding="utf-8")
dependabot = Path(sys.argv[3]).read_text(encoding="utf-8")
bootstrap = Path(sys.argv[4]).read_text(encoding="utf-8")
smoke = Path(sys.argv[5]).read_text(encoding="utf-8")
trigger_block = ci.split("permissions:", 1)[0]
assert "pull_request:" in trigger_block
assert "workflow_dispatch:" in trigger_block
assert "push:" not in trigger_block
assert "schedule:" not in trigger_block
assert "name: CI / required" in ci
assert "schedule:" in canary
assert "Current Codex and latest Ponytail" in canary
assert "npm ci --ignore-scripts --prefix tests/canary" in canary
assert canary.count("GITHUB_TOKEN: ${{ github.token }}") == 2
assert "GITHUB_TOKEN: ${{ github.token }}" in ci
assert "SPEC_KIT_VERSION: v1.0.1" in ci
assert "zizmor==1.29.0" in ci
assert "update-types:" in dependabot
assert "- major" not in dependabot
assert '\"token_env\": \"GITHUB_TOKEN\"' in smoke
assert '\"token\":' not in smoke
assert "--skip-ponytail" not in smoke
assert "--branch-numbering" not in bootstrap
PY
}

test_workflow_install_failure_is_fatal() (
  local sandbox="$TEST_ROOT/workflow-install-failure"
  local calls="$sandbox/calls"
  PROJECT_DIR="$sandbox/project"
  RESOLVED_SPEC_KIT_REF="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  mkdir -p "$PROJECT_DIR"

  # Invoked indirectly by refresh_speckit_workflow.
  # shellcheck disable=SC2317,SC2329
  specify() {
    printf '%s\n' "$*" >> "$calls"
    echo 'simulated workflow install failure'
    return 1
  }

  if refresh_speckit_workflow 2>/dev/null; then
    return 1
  fi
  [[ "$(cat "$calls")" == "workflow add speckit --from $(resolved_workflow_url)" ]]
)

test_workflow_install_uses_immutable_source_noninteractively() (
  local sandbox="$TEST_ROOT/workflow-install-confirm"
  local answer="$sandbox/answer"
  local expected_source
  PROJECT_DIR="$sandbox/project"
  RESOLVED_SPEC_KIT_REF="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  expected_source="$(resolved_workflow_url)"
  mkdir -p "$PROJECT_DIR/.specify/workflows/speckit"

  # Invoked indirectly by refresh_speckit_workflow.
  # shellcheck disable=SC2317,SC2329
  specify() {
    [[ "$*" == "workflow add speckit --from $expected_source" ]] || return 1
    IFS= read -r response
    printf '%s\n' "$response" > "$answer"
    printf 'workflow\n' > "$PROJECT_DIR/.specify/workflows/speckit/workflow.yml"
    python3 - "$PROJECT_DIR/.specify/workflows/workflow-registry.json" "$expected_source" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "workflows": {"speckit": {"version": "1.0.0", "source": sys.argv[2]}}
}) + "\n", encoding="utf-8")
PY
    echo 'Workflow installed'
  }

  refresh_speckit_workflow >/dev/null
  [[ "$(cat "$answer")" == "y" ]]
  [[ "$(workflow_source)" == "$expected_source" ]]
)

test_workflow_refresh_skips_matching_immutable_source() (
  local sandbox="$TEST_ROOT/workflow-matching"
  local expected_source
  local digest
  PROJECT_DIR="$sandbox/project"
  RESOLVED_SPEC_KIT_REF="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  expected_source="$(resolved_workflow_url)"
  mkdir -p "$PROJECT_DIR/.specify/workflows/speckit"
  printf 'workflow\n' > "$PROJECT_DIR/.specify/workflows/speckit/workflow.yml"
  digest="$(sha256_for_test "$PROJECT_DIR/.specify/workflows/speckit/workflow.yml")"
  python3 - \
    "$PROJECT_DIR/.specify/workflows/workflow-registry.json" \
    "$PROJECT_DIR/.specify/speckit-bootstrap.lock.json" \
    "$expected_source" \
    "$digest" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "workflows": {"speckit": {"version": "1.0.0", "source": sys.argv[3]}}
}) + "\n", encoding="utf-8")
Path(sys.argv[2]).write_text(json.dumps({
    "workflow": {"sha256": sys.argv[4]}
}) + "\n", encoding="utf-8")
PY

  # Invoked only if refresh fails to recognize the immutable installed source.
  # shellcheck disable=SC2317,SC2329
  specify() { return 1; }

  refresh_speckit_workflow | grep -Fq 'already matches immutable source'
)

test_cache_cleanup_removes_completed_workflow_lock() (
  local sandbox="$TEST_ROOT/cache-cleanup"
  PROJECT_DIR="$sandbox/project"
  mkdir -p \
    "$PROJECT_DIR/.specify/extensions/.cache" \
    "$PROJECT_DIR/.specify/integrations/.cache" \
    "$PROJECT_DIR/.specify/workflows/.cache"
  touch "$PROJECT_DIR/.specify/.workflow-install.lock"

  clean_caches

  [[ ! -e "$PROJECT_DIR/.specify/.workflow-install.lock" ]]
  [[ ! -e "$PROJECT_DIR/.specify/extensions/.cache" ]]
  [[ ! -e "$PROJECT_DIR/.specify/integrations/.cache" ]]
  [[ ! -e "$PROJECT_DIR/.specify/workflows/.cache" ]]
)

test_generated_hardening_contract_is_installed_before_lock_capture() {
  python3 - "$BOOTSTRAP" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
call = "  ensure_governed_generated_artifacts\n"
capture = "    capture_project_dependency_state\n"
assert text.count(call) == 1
assert text.index(call) < text.index(capture)
assert 'if [[ "$FROZEN" -eq 0 ]]; then\n    ensure_governed_generated_artifacts' in text
for marker in (
    "MUST NOT skip clarify",
    "existing spec is updated in place",
    "project canon",
    "STOP with a blocking configuration error",
    "--template cannot be combined with --paths-only",
    "unresolvable file",
    "commit_style is 'conventional'",
    "existing project files remain unstaged for review",
    "upstream mandatory hook guard changed",
    "updated.count(mandatory_hook_guard) == 0",
    "pending.items()",
):
    assert marker in text, marker
PY
}

printf '1..27\n'
run_test 'version and sourceability' test_version_and_sourceability
run_test 'installer reports a missing PATH entry' test_installer_reports_missing_path
run_test 'issue canon catalog entry requires SHA-256' test_issue_canon_catalog_entry_requires_checksum
run_test 'pinned issue canon uses its tagged catalog' test_pinned_issue_canon_uses_tagged_catalog
run_test 'catalog install verifies version and skill' test_catalog_install_checks_expected_version_and_skill
run_test 'catalog merge is additive and idempotent' test_catalog_merge_is_additive_and_idempotent
run_test 'project skill manifest detects tampering' test_project_skill_manifest_detects_tampering
run_test 'schema v2 migration preserves all global skills' test_schema_v2_migration_preserves_all_global_skills
run_test 'managed project paths reject symlinks' test_managed_project_paths_reject_symlinks
run_test 'issue canon files preserve user templates' test_issue_canon_files_preserve_user_template
run_test 'audit mode unhides install metadata' test_audit_mode_unhides_install_metadata
run_test 'doctor explains hidden metadata drift' test_doctor_explains_hidden_metadata_drift
run_test 'integration refresh respects local changes' test_integration_refresh_respects_local_changes
run_test 'frozen lock stays immutable when Ponytail is skipped' test_frozen_lock_is_immutable_when_ponytail_is_skipped
run_test 'extension tree integrity detects payload tampering' test_extension_tree_integrity_detects_payload_tampering
run_test 'matching CLI skips force reinstall' test_matching_cli_skips_force_reinstall
run_test 'frozen skipped CLI requires the locked commit' test_frozen_skip_cli_update_requires_locked_commit
run_test 'Ponytail is opt-in' test_ponytail_is_opt_in
run_test 'Ponytail marketplace path is canonical' test_ponytail_marketplace_path_is_canonical
run_test 'JSON mode keeps stdout machine-readable' test_json_mode_keeps_stdout_machine_readable
run_test 'release publish job does not execute repository code' test_release_publish_job_does_not_execute_repository_code
run_test 'CI topology avoids duplicate SHA runs' test_ci_topology_avoids_duplicate_sha_runs
run_test 'workflow install failure is fatal' test_workflow_install_failure_is_fatal
run_test 'workflow install uses immutable source noninteractively' test_workflow_install_uses_immutable_source_noninteractively
run_test 'workflow refresh skips matching immutable source' test_workflow_refresh_skips_matching_immutable_source
run_test 'cache cleanup removes completed workflow lock' test_cache_cleanup_removes_completed_workflow_lock
run_test 'generated hardening is installed before lock capture' test_generated_hardening_contract_is_installed_before_lock_capture

if [[ "$TESTS_FAILED" -ne 0 ]]; then
  printf '%s test(s) failed\n' "$TESTS_FAILED" >&2
  exit 1
fi
