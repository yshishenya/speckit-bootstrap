# speckit-bootstrap

Yan's reproducible bootstrap wrapper for GitHub Spec Kit + Codex.

The script updates official Spec Kit from `github/spec-kit`, initializes or
refreshes the current project, installs bundled Spec Kit extensions, installs
Yan's reusable `github-issue-canon` extension from GitHub, and syncs generated
Codex skills into `~/.agents/skills`. It also installs/updates the Ponytail
Codex plugin and project guidance. Every successful non-frozen refresh records
the exact resolved inputs and managed payload digests in
`.specify/speckit-bootstrap.lock.json`.

The bootstrap never changes upstream repositories. It does apply managed,
project-local policy overlays to generated Spec Kit templates and `AGENTS.md`;
those changes remain visible and reviewable in the project diff.

## Install Or Update

```sh
curl -fsSL https://raw.githubusercontent.com/yshishenya/speckit-bootstrap/main/install.sh | bash
```

The installer resolves the latest GitHub Release, downloads the
`speckit-bootstrap` release asset and its `.sha256` file, validates the
checksum and shell syntax, then installs atomically with executable mode. To
install a specific release:

```sh
curl -fsSL https://raw.githubusercontent.com/yshishenya/speckit-bootstrap/main/install.sh |
  SPECKIT_BOOTSTRAP_VERSION=v0.6.1 bash
```

This installs:

```text
~/.local/bin/speckit-bootstrap
```

Make sure `~/.local/bin` is on your `PATH`.
`speckit-bootstrap` is the only standalone executable installed there.
All other `speckit-*` entries are Codex skills, not shell binaries.

Re-run the same command any time you want to update the local wrapper to the
latest published release.

Prerequisites are `git`, `curl`, `python3`, and
[`uv`](https://docs.astral.sh/uv/). The `codex` CLI is required for Ponytail;
headless environments can use `--skip-ponytail`.

## New Project Quickstart

Create or open a project directory:

```sh
mkdir -p ~/Documents/my-project
cd ~/Documents/my-project
git init
```

Run bootstrap:

```sh
speckit-bootstrap .
```

After it finishes, the project should have:

```text
.specify/
.specify/speckit-bootstrap.lock.json
AGENTS.md
docs/agent-guidance/github-issue-canon.md
docs/agent-guidance/ponytail-upstream.md
.github/ISSUE_TEMPLATE/
.github/pull_request_template.md
```

And global Codex skills should exist under:

```text
~/.agents/skills/speckit-*
```

For a fresh project, commit the generated baseline after reviewing it:

```sh
git add .specify AGENTS.md docs/agent-guidance .github
git commit -m "chore: bootstrap spec kit"
```

## Existing Project Refresh

From an existing Spec Kit project:

```sh
cd /path/to/project
speckit-bootstrap .
```

This refreshes:

- official `specify-cli` from upstream `github/spec-kit`;
- Codex Spec Kit integration files;
- official `agent-context` and `git` extensions;
- a tagged `github-issue-canon` extension archive from GitHub;
- generated `speckit-*` skills in `~/.agents/skills`;
- the Ponytail Codex plugin via Codex's plugin marketplace;
- Ponytail's upstream `AGENTS.md` fallback in
  `docs/agent-guidance/ponytail-upstream.md`;
- the reproducibility lock and project-local issue/PR templates.

Use this before starting a new Spec Kit slice, after upstream Spec Kit updates,
or when you want to refresh the shared issue-canon automation.

## Daily Usage

```sh
speckit-bootstrap .
```

For an exact replay of the recorded dependency set:

```sh
speckit-bootstrap . --frozen
```

For a read-only health check:

```sh
speckit-bootstrap . --doctor
```

Or from anywhere:

```sh
speckit-bootstrap /path/to/project
```

If the project defines risk/validation lanes in `AGENTS.md` or
`docs/agent-guidance/spec-kit-flow.md`, choose that lane before starting work.
For tracked Spec Kit feature slices, use the normal Spec Kit skill flow in Codex
(repo convention here uses `$`-prefixed skill names):

```text
$speckit-specify
$speckit-clarify
$speckit-plan
$speckit-checklist
$speckit-tasks
$speckit-analyze
$speckit-taskstoissues
$speckit-implement
```

When `$speckit-taskstoissues` runs, the `github-issue-canon` extension hooks are
registered automatically:

- `before_taskstoissues`: installs/refreshes issue canon files and labels;
- `after_taskstoissues`: validates open Spec Kit issues against the canon.

## Project Tracking

The active tracking model is intentionally simple:

- `tasks.md` is the implementation source of truth inside the repo.
- GitHub issues are the external tracker for execution, review, PR links, and
  closure evidence.
- GitHub pull request templates capture the Russian PR summary, validation
  evidence, issue links, and closeout checklist.

Recommended feature flow:

```text
$speckit-tasks
$speckit-taskstoissues
$speckit-implement
```

Agent rules for GitHub issue text:

- all GitHub issues, PR descriptions, comments, closure comments, and sync notes
  must be written in Russian by default;
- write in simple, plain language that is understandable to non-technical
  teammates;
- Spec Kit task-backed GitHub issue titles must use one shape:
  `[<feature>][<priority>][<area>] T###: <русский результат>`;
- bare `T###: ...` titles are fallback-only for repositories without the
  project canon and should not be used after bootstrap installs
  `github-issue-canon`;
- do not duplicate existing GitHub issues; match by feature number, task ID,
  issue URL, and title first;
- when `tasks.md` marks a task as `[X]`, close the matching GitHub issue and add
  a detailed Russian closure comment explaining what changed, why it matters,
  how it was checked, what is out of scope, and which PR and Spec Kit task it
  closes;
- use `Fixes #...`, `Closes #...`, or `Resolves #...` only when the PR fully
  closes the issue; use `Refs #...` or `Part of #...` for partial work;
- if a GitHub issue is closed but `tasks.md` is still open, verify the work
  before marking the task complete.

If validation reports old non-canonical issues, normalize them:

```text
$speckit-github-issue-canon-normalize
```

Then re-run:

```text
$speckit-github-issue-canon-validate
```

## Release And Versioning

Use one versioning policy per repository and document it in project guidance:

- product apps, deployed services, and release-train bundles use CalVer tags:
  `vYYYY.MM.DD.N`, where `N` increments for multiple releases on the same day;
- libraries, CLI tools, reusable Spec Kit extensions, bootstrap wrappers, and
  dependency-like packages use SemVer tags: `vMAJOR.MINOR.PATCH`;
- descriptive release postfixes belong in the GitHub Release title, not in the
  stable tag, for example `v2026.06.18.1 - release-rules`;
- prerelease suffixes are only for real prereleases:
  `-alpha.N`, `-beta.N`, or `-rc.N`;
- every release must have a GitHub Release with Russian release notes,
  validation evidence, compatibility or migration notes, known limitations, and
  PR/issue links when available.

## Agent Quick Reference (concise)

Use this when running Spec Kit from Codex:

```text
speckit-bootstrap .          # one-time install/refresh in project
$speckit-specify             # write/refresh spec
$speckit-clarify             # clarify requirements
$speckit-plan                # make implementation plan
$speckit-checklist           # create requirement quality gate
$speckit-tasks               # generate task list
$speckit-analyze             # validate spec/plan/tasks consistency
$speckit-taskstoissues       # sync tracked feature tasks to GitHub issues
$speckit-implement           # execute tasks
```

Rules for agents:

- only `speckit-bootstrap` is a shell executable in `~/.local/bin`
- all other Spec Kit entrypoints are Codex skills (`$speckit-*`)
- `$speckit-taskstoissues` requires a GitHub remote and active tasks; use it for
  tracked Spec Kit feature slices, not read-only/docs-only/tiny direct lanes
- issue format is governed by `docs/agent-guidance/github-issue-canon.md`
- Spec Kit task-backed issue titles use
  `[<feature>][<priority>][<area>] T###: <русский результат>`
- `tasks.md` remains the implementation source of truth; GitHub issues are the external tracker
- all GitHub issues, PR descriptions, and comments must be written in Russian by default, in simple language
- Ponytail controls implementation shape, not the selected risk/validation lane:
  low-risk lanes can stay scoped, while significant/high-risk lanes keep specs,
  plans, task sync, evidence, release notes, and closeout.

## What It Does

- installs/updates official `specify-cli` from `github/spec-kit`;
- initializes or updates project-local `.specify` state;
- installs the official `agent-context` and `git` extensions;
- installs `github-issue-canon` from a resolved tagged GitHub archive;
- registers `$speckit-github-issue-canon-*` skills;
- installs/updates the Ponytail Codex plugin through `codex plugin`;
- adds a managed Ponytail-in-Spec-Kit block to `AGENTS.md`;
- refreshes Ponytail's upstream `AGENTS.md` fallback into
  `docs/agent-guidance/ponytail-upstream.md`;
- applies and validates managed risk/validation lane prompts in generated
  Spec Kit plan/tasks templates;
- configures safe Spec Kit git auto-commit defaults for documentation stages;
- atomically syncs generated `speckit-*` skills to `~/.agents/skills` while
  preserving unrelated and project-owned skills;
- removes project-local duplicate skills by default;
- installs project-local issue canon docs and GitHub templates without
  overwriting user-owned templates;
- writes a version/source lock with full extension-tree and managed global-skill
  digests, then runs post-install verification;
- hides refresh-only Spec Kit install metadata from normal `git diff`, with an
  explicit audit mode that unhides it again.

## Ponytail Integration

Bootstrap keeps Ponytail owned by Codex's plugin manager: it adds a new
versioned managed marketplace descriptor under
`~/.codex/speckit-bootstrap/marketplaces/ponytail/`, pins the descriptor's
plugin source to the tag's commit SHA, and runs
`codex plugin add ponytail@ponytail`. It refreshes
`docs/agent-guidance/ponytail-upstream.md`, and updates the root `AGENTS.md`
managed block. It does not vendor Ponytail hooks or skills into the project;
Codex still owns plugin installation and cache lifecycle.

After the first install or any Ponytail update, review hooks in Codex:

```text
/hooks
```

Ponytail controls implementation shape, not the selected risk/validation lane:
low-risk lanes can stay scoped, while significant/high-risk lanes keep specs,
plans, task sync, validation evidence, release notes, and closeout.

## Git Auto-Commit Defaults

Bootstrap keeps Spec Kit's git extension installed from upstream, then applies a
safe project policy after each refresh.

Enabled by default:

- `after_constitution`
- `after_specify`
- `after_clarify`
- `after_plan`
- `after_checklist`
- `after_tasks`
- `after_analyze`

Disabled by default:

- all `before_*` hooks;
- `after_implement`;
- `after_taskstoissues`.

This captures completed Spec Kit documentation artifacts while keeping
implementation code, generated build outputs, unrelated working tree changes,
and external issue synchronization under explicit user control.

## Latest-First, Reproducible Policy

The first non-frozen run is latest-first; every completed run is reproducible.

- Official Spec Kit selects the latest upstream `v*` Git tag by default, then
  installs the commit SHA behind that tag.
- `github-issue-canon` selects the latest `v*` tag and installs the immutable
  commit archive behind it, not a mutable `main` ZIP.
- Ponytail selects a tag, generates a versioned local marketplace descriptor
  whose plugin source is the tag's commit SHA, and verifies both installed
  version and ref before recording success.
- The installer resolves the latest published `speckit-bootstrap` release and
  verifies its release asset checksum.
- Exact versions, commit refs, source URLs, Ponytail marketplace checksum,
  complete core-extension tree digests, managed global-skill tree digests, and
  the installed workflow SHA-256 are written to
  `.specify/speckit-bootstrap.lock.json`.

To resolve current upstream releases and refresh the lock:

```sh
curl -fsSL https://raw.githubusercontent.com/yshishenya/speckit-bootstrap/main/install.sh | bash
speckit-bootstrap /path/to/project
```

To replay the recorded set without resolving mutable upstream state:

```sh
speckit-bootstrap /path/to/project --frozen
```

Frozen mode verifies both the version and exact source commit of an
already-installed `specify` when combined with `--skip-cli-update`, and verifies
the installed Ponytail version when Ponytail is enabled in the lock. Missing
user-local Ponytail state is rebuilt only when the generated descriptor matches
the locked checksum. Frozen mode regenerates Codex integration files with the
commit-pinned Spec Kit CLI, but does not update the locked workflow or core
extensions from mutable catalogs; version or payload drift fails the run. The
lock itself is immutable during a frozen run, including when `--skip-ponytail`
is used only to suppress the local plugin operation.

For a controlled Spec Kit pin or rollback, refresh once with:

```sh
SPEC_KIT_VERSION=vX.Y.Z speckit-bootstrap .
```

The resulting lock becomes the replay contract for later `--frozen` runs.

For bleeding-edge official Spec Kit, set:

```sh
SPEC_KIT_VERSION=main speckit-bootstrap .
```

## Git Diff Hygiene

On an existing Spec Kit project, upstream refreshes may rewrite version and
manifest files such as:

```text
.specify/init-options.json
.specify/integration.json
.specify/integrations/*.manifest.json
.specify/extensions/.registry
.specify/workflows/workflow-registry.json
```

Those files describe the local install state, not project behavior. By default
`speckit-bootstrap` marks that volatile metadata as `skip-worktree` after a
refresh so routine updates do not leave a noisy git diff.

Real project changes still remain visible, including `AGENTS.md`,
`docs/agent-guidance/`, `.specify/templates/`, extension files, specs, plans,
tasks, source code, and tests.

For a release or audit where you want to see and commit metadata drift too:

```sh
SPECKIT_TRACK_INSTALL_METADATA=1 speckit-bootstrap .
```

For a brand-new project, the first bootstrap still creates files that should be
reviewed and committed as the initial Spec Kit baseline.

## Options

```text
speckit-bootstrap [PROJECT_DIR] [OPTIONS]

Modes:
  --doctor              Verify without changing project or user state
  --dry-run             Resolve inputs and show the mutation plan only
  --version             Print the bootstrap version

Options:
  --frozen              Read exact inputs from the project lock
  --json                Emit only the plan/final JSON on stdout; logs use stderr
  --keep-local-skills   Keep generated project-local skill duplicates
  --skip-cli-update     Use the installed specify CLI
  --skip-ponytail       Do not install/update Ponytail or its guidance
```

Environment:

- `SPEC_KIT_VERSION`: `latest` by default; resolves the latest `v*` upstream
  tag. Can be `main` or any git ref.
- `SPECKIT_EXTENSION_CATALOG_URL`: override Yan's extension catalog URL.
- `SPECKIT_GITHUB_ISSUE_CANON_VERSION`: `latest` by default; accepts a tag.
- `SPECKIT_GITHUB_ISSUE_CANON_URL`: use an explicitly reviewed custom ZIP.
- `SPECKIT_PONYTAIL_VERSION`: `latest` by default; accepts a Ponytail tag.
- `SPECKIT_TRACK_INSTALL_METADATA`: set to `1` to keep Spec Kit install/version
  metadata visible in git instead of marking it `skip-worktree`.
- `SPECKIT_PONYTAIL`: set to `0`, `false`, `no`, or `off` to skip Ponytail.
- `SPECKIT_BOOTSTRAP_INSTALL_DIR`: installer target, default `~/.local/bin`.
- `SPECKIT_BOOTSTRAP_VERSION`: release tag for the installer, default `latest`.
- `SPECKIT_BOOTSTRAP_URL`: custom installer source; requires
  `SPECKIT_BOOTSTRAP_SHA256` unless unverified mode is explicitly enabled.
- `SPECKIT_BOOTSTRAP_SHA256`: expected checksum for a custom source.
- `SPECKIT_BOOTSTRAP_ALLOW_UNVERIFIED=1`: emergency opt-in for a reviewed local
  source or a legacy release that has no checksum assets.

Useful examples:

```sh
# Fast refresh without reinstalling specify-cli
speckit-bootstrap . --skip-cli-update

# Preview resolved versions and mutations without writing anything
speckit-bootstrap . --dry-run --json

# Replay the exact dependency set recorded by the previous successful run
speckit-bootstrap . --frozen

# Check project/global postconditions without mutating state
speckit-bootstrap . --doctor

# Keep project-local generated skills instead of only syncing global skills
speckit-bootstrap . --keep-local-skills

# Skip Ponytail plugin updates and AGENTS.md Ponytail guidance
speckit-bootstrap . --skip-ponytail

# Use official Spec Kit main instead of the latest release tag
SPEC_KIT_VERSION=main speckit-bootstrap .

# Show refresh-only Spec Kit metadata changes in git
SPECKIT_TRACK_INSTALL_METADATA=1 speckit-bootstrap .
```

## Verification

The bootstrap runs `specify self check` and its own postcondition checks before
reporting success. Doctor verifies the installed CLI source commit, complete
locked extension payloads, the workflow checksum, and every managed global
skill digest. Re-run the read-only checks at any time:

```sh
speckit-bootstrap . --doctor
specify self check
specify extension list
ls ~/.agents/skills | grep speckit
codex plugin list --json --available | grep ponytail
test -f docs/agent-guidance/ponytail-upstream.md
```

For the issue canon extension:

```sh
python3 .specify/extensions/github-issue-canon/scripts/ensure_issue_canon.py
python3 .specify/extensions/github-issue-canon/scripts/validate_issue_canon.py
```

Expected validation output:

```text
github-issue-canon: OK (... Spec Kit issue(s) checked)
```

## Development And Release

The maintained compatibility targets are macOS with the system Bash 3.2 and
Ubuntu with Bash 5. The live smoke test installs the pinned Spec Kit baseline
in an isolated `HOME`, validates JSON output, repeats in frozen mode, checks
lock immutability and idempotence, rejects deliberately tampered workflow,
extension, and global-skill payloads, and verifies audit visibility.

```sh
bash -n bin/speckit-bootstrap install.sh tests/unit.sh tests/smoke-live.sh
bash tests/unit.sh
SPEC_KIT_VERSION=v0.12.11 \
  SPECKIT_GITHUB_ISSUE_CANON_VERSION=v0.2.6 \
  bash tests/smoke-live.sh
```

GitHub Actions runs static/unit checks and pinned live smoke tests on macOS and
Ubuntu. A scheduled job tests current upstream tags so upstream drift is found
before users hit it. Release assets are built and tested in a read-only job;
only a separate publishing job receives `contents: write`, and it never checks
out or executes repository code. Publishing a SemVer GitHub Release uploads the
executable and checksum assets consumed by `install.sh`; the release tag must
match `speckit-bootstrap --version`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the release checklist and
[SECURITY.md](SECURITY.md) for private vulnerability reporting.
