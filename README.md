# speckit-bootstrap

Yan's upstream-clean bootstrap wrapper for GitHub Spec Kit + Codex.

The script updates official Spec Kit from `github/spec-kit`, initializes or
refreshes the current project, installs bundled Spec Kit extensions, installs
Yan's reusable `github-issue-canon` extension from GitHub, removes retired
Linear sync wiring, and syncs generated Codex skills into `~/.agents/skills`.

No upstream Spec Kit files are patched.

## Install Or Update

```sh
curl -fsSL https://raw.githubusercontent.com/yshishenya/speckit-bootstrap/main/install.sh | bash
```

This installs:

```text
~/.local/bin/speckit-bootstrap
```

Make sure `~/.local/bin` is on your `PATH`.
`speckit-bootstrap` is the only standalone executable installed there.
All other `speckit-*` entries are Codex skills, not shell binaries.

Re-run the same command any time you want to update the local
`speckit-bootstrap` wrapper from this repository's latest `main`.

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
AGENTS.md
docs/github-issue-canon.md
.github/ISSUE_TEMPLATE/
```

And global Codex skills should exist under:

```text
~/.agents/skills/speckit-*
```

For a fresh project, commit the generated baseline after reviewing it:

```sh
git add .specify AGENTS.md docs/github-issue-canon.md .github/ISSUE_TEMPLATE
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
- Yan's `github-issue-canon` extension from GitHub;
- removal of retired Linear sync extension/skills/instructions when present;
- generated `speckit-*` skills in `~/.agents/skills`.

Use this before starting a new Spec Kit slice, after upstream Spec Kit updates,
or when you want to refresh the shared issue-canon automation.

## Daily Usage

```sh
speckit-bootstrap .
```

Or from anywhere:

```sh
speckit-bootstrap /path/to/project
```

Then use the normal Spec Kit skill flow in Codex (repo convention here uses `$`-prefixed skill names):

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
- Linear is not part of the default flow anymore. Bootstrap removes the retired
  `linear-sync` extension, generated Linear skills, and managed Linear agent
  instructions when it finds them.

Recommended feature flow:

```text
$speckit-tasks
$speckit-taskstoissues
$speckit-implement
```

Agent rules for GitHub issue text:

- all GitHub issues and comments must be written in Russian by default;
- write in simple, plain language that is understandable to non-technical
  teammates;
- do not duplicate existing GitHub issues; match by feature number, task ID,
  issue URL, and title first;
- when `tasks.md` marks a task as `[X]`, close the matching GitHub issue and add
  a short evidence comment;
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

## Agent Quick Reference (concise)

Use this when running Spec Kit from Codex:

```text
$speckit-bootstrap .         # one-time install/refresh in project
$speckit-specify             # write/refresh spec
$speckit-clarify             # clarify requirements
$speckit-plan                # make implementation plan
$speckit-checklist           # create requirement quality gate
$speckit-tasks               # generate task list
$speckit-analyze             # validate spec/plan/tasks consistency
$speckit-taskstoissues       # sync tasks to GitHub issues (required for implementation)
$speckit-implement           # execute tasks
```

Rules for agents:

- only `speckit-bootstrap` is a shell executable in `~/.local/bin`
- all other Spec Kit entrypoints are Codex skills (`$speckit-*`)
- `$speckit-taskstoissues` requires a GitHub remote and active tasks; issue format is governed by `docs/github-issue-canon.md`
- `tasks.md` remains the implementation source of truth; GitHub issues are the external tracker
- all GitHub issues and comments must be written in Russian by default, in simple language

## What It Does

- installs/updates official `specify-cli` from `github/spec-kit`;
- initializes or updates project-local `.specify` state;
- installs the official `agent-context` and `git` extensions;
- installs `github-issue-canon` from Yan's GitHub extension catalog;
- removes retired `linear-sync` extension files and generated skills when present;
- registers `$speckit-github-issue-canon-*` skills;
- configures safe Spec Kit git auto-commit defaults for documentation stages;
- syncs generated `speckit-*` skills to `~/.agents/skills`;
- removes project-local duplicate skills by default.

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

## Latest-From-Git Policy

The default behavior is not pinned to a local archive.

- Official Spec Kit is resolved from the latest upstream Git tag by default.
- `github-issue-canon` is resolved through Yan's extension catalog, whose
  `download_url` tracks the extension repository's `main` branch.
- `speckit-bootstrap` itself is installed from this repository's `main` branch.

To update everything to the latest default state:

```sh
curl -fsSL https://raw.githubusercontent.com/yshishenya/speckit-bootstrap/main/install.sh | bash
speckit-bootstrap /path/to/project
```

For controlled rollback, set:

```sh
SPEC_KIT_VERSION=vX.Y.Z speckit-bootstrap .
```

For bleeding-edge official Spec Kit, set:

```sh
SPEC_KIT_VERSION=main speckit-bootstrap .
```

## Options

```text
speckit-bootstrap [PROJECT_DIR] [--keep-local-skills] [--skip-cli-update]
```

Environment:

- `SPEC_KIT_VERSION`: `latest` by default; resolves the latest `v*` upstream
  tag. Can be `main` or any git ref.
- `SPECKIT_EXTENSION_CATALOG_URL`: override Yan's extension catalog URL.
- `SPECKIT_GITHUB_ISSUE_CANON_URL`: fallback ZIP URL if catalog install fails.
- `SPECKIT_BOOTSTRAP_INSTALL_DIR`: installer target, default `~/.local/bin`.
- `SPECKIT_BOOTSTRAP_URL`: installer source URL.

Useful examples:

```sh
# Fast refresh without reinstalling specify-cli
speckit-bootstrap . --skip-cli-update

# Keep project-local generated skills instead of only syncing global skills
speckit-bootstrap . --keep-local-skills

# Use official Spec Kit main instead of the latest release tag
SPEC_KIT_VERSION=main speckit-bootstrap .
```

## Verification

After bootstrap, run:

```sh
specify self check
specify extension list
ls ~/.agents/skills | grep speckit
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
