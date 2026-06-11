# speckit-bootstrap

Yan's upstream-clean bootstrap wrapper for GitHub Spec Kit + Codex.

The script updates official Spec Kit from `github/spec-kit`, initializes or
refreshes the current project, installs bundled Spec Kit extensions, installs
Yan's reusable `github-issue-canon` and `linear-sync` extensions from GitHub,
and syncs generated Codex skills into `~/.agents/skills`.

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

If a private bootstrap env file exists at:

```text
~/.codex/secrets/speckit.env
```

`speckit-bootstrap` also refreshes the project `.env` from it and makes sure
`.env` is ignored by Git. This is intended for local Linear settings such as
`LINEAR_API_KEY`, `LINEAR_TEAM_KEY`, `LINEAR_PRODUCT_NAME`, and
`LINEAR_PROJECT_TEMPLATE`; the secret file itself is never committed.

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
- Yan's `linear-sync` extension from GitHub;
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
$speckit-linear-import
$speckit-linear-sync
$speckit-implement
```

When `$speckit-taskstoissues` runs, the `github-issue-canon` extension hooks are
registered automatically:

- `before_taskstoissues`: installs/refreshes issue canon files and labels;
- `after_taskstoissues`: validates open Spec Kit issues against the canon.

## Linear Project Tracking

Bootstrap also keeps Linear operating instructions in `AGENTS.md` when the file
exists. Linear is treated as the day-to-day project tracker on top of Spec Kit:

- `tasks.md` remains the implementation source of truth.
- GitHub issues remain the code and PR traceability layer.
- Linear issues are used for status, priority, cycle, assignee, blockers,
  relations, project updates, and daily work tracking.
- Each substantial Spec Kit feature should map to a Linear Project named with
  both product and feature context, for example
  `2brain Rec / 013 Federated Auth Foundation`.

Recommended feature flow:

```text
$speckit-tasks
$speckit-taskstoissues
$speckit-linear-sync
```

For existing feature work, run import/match mode before creating anything new:

```text
$speckit-linear-import
$speckit-linear-sync
```

Agent rules for Linear and issue text:

- all GitHub issues, Linear issues, comments, project updates, and sync notes
  must be written in Russian by default;
- write in simple, plain language that is understandable to non-technical
  teammates;
- do not duplicate existing Linear issues; match by feature number, task ID,
  GitHub issue URL, and title first;
- when `tasks.md` marks a task as `[X]`, close or move the matching GitHub and
  Linear issues to done and add a short evidence comment;
- if Linear says an issue is done but `tasks.md` is still open, verify the work
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
$speckit-linear-import       # import/match existing Linear issues before creating new ones
$speckit-linear-sync         # sync tasks and GitHub issues into Linear
$speckit-implement           # execute tasks
```

Rules for agents:

- only `speckit-bootstrap` is a shell executable in `~/.local/bin`
- all other Spec Kit entrypoints are Codex skills (`$speckit-*`)
- `$speckit-taskstoissues` requires a GitHub remote and active tasks; issue format is governed by `docs/github-issue-canon.md`
- `$speckit-linear-sync` uses Linear for project tracking while `tasks.md` remains the implementation source of truth
- all GitHub issues, Linear issues, comments, project updates, and sync notes must be written in Russian by default, in simple language

## What It Does

- installs/updates official `specify-cli` from `github/spec-kit`;
- initializes or updates project-local `.specify` state;
- installs the official `agent-context` and `git` extensions;
- installs `github-issue-canon` from Yan's GitHub extension catalog;
- installs `linear-sync` from Yan's GitHub extension catalog or fallback URL;
- registers `$speckit-github-issue-canon-*` skills;
- registers `$speckit-linear-*` skills;
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
- `linear-sync` is resolved from Yan's GitHub extension repository by default.
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
- `SPECKIT_LINEAR_SYNC_URL`: fallback ZIP URL for the Linear Sync extension.
- `SPECKIT_PROJECT_ENV_FILE`: private env file copied into project `.env`.
  Default: `~/.codex/secrets/speckit.env` when it exists.
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
