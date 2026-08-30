# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

- No entries yet.

## [0.9.8] - 2026-08-31

### Fixed

- Preserve the analyze gate when the issue-sync gate is added to generated
  implementation guidance.
- Require reviewer-complete high-risk checklists before task generation and a
  current clean analysis before external issue synchronization.
- Save each accepted clarification before asking the next question and retain
  material ambiguities beyond the initial question limit.
- Reject unsupported or malformed branch-template placeholders before creating
  a Git branch.

## [0.9.7] - 2026-08-30

### Fixed

- Make direct planning and implementation fail closed on missing mandatory
  clarification, task-to-issue ownership, and unknown risk-lane evidence.
- Stop conditional mandatory hooks when HookExecutor is unavailable instead of
  silently skipping policy or validation work.
- Prevent convergence from turning pre-existing shared baseline code into
  removal tasks without current-slice provenance.
- Preserve a nested Spec Kit project root for numbering and configuration when
  its Git repository root is a parent directory.

## [0.9.6] - 2026-08-30

### Fixed

- Keep generated checklist and issue-sync guidance safe when optional feature
  documents are absent or task IDs repeat.
- Reject preset-template symlink escapes and malformed preset registries,
  canonicalize nested PowerShell links and Git Bash message-file paths, and
  preserve executable command syntax across skill and slash integrations.
- Normalize generated MDC frontmatter to the start of the file.

## [0.9.5] - 2026-08-30

### Fixed

- Migrate the exact `v0.9.4` intermediate Python auto-commit form so the
  conventional-message guard runs once, after the clean-worktree short circuit.

## [0.9.4] - 2026-08-30

### Fixed

- Migrate the remaining known `v0.9.1` Python auto-commit cleanup and preset
  manifest path forms while rejecting mixed, duplicate, or unknown states.

## [0.9.3] - 2026-08-30

### Fixed

- Migrate the known `v0.9.1` safe Git-initialization fallback to the `v0.9.2`
  blocking form while continuing to fail closed for unknown partial upstream
  states.

## [0.9.2] - 2026-08-30

### Changed

- Require generated checklist, Git feature, Git initialization, auto-commit and
  convergence guidance to preserve reviewer ownership, use structured arguments,
  and stop before unsafe or unrelated commits.

### Fixed

- Fail closed for malformed post-hook configuration, grade every convergence
  finding, preserve caller-owned external commit-message files while rejecting
  worktree-local ones, and keep clean-worktree conventional auto-commit behavior
  consistent across ports.
- Resolve PowerShell plan candidates through symlinks, remove duplicate Python
  persist hints, surface extension enumeration diagnostics, and reject every
  parent-path form in declared preset templates.

## [0.9.1] - 2026-08-30

### Changed

- Require explicit canonical task ownership when deduplicating issues, reconcile
  closed issue matches, and sync convergence-appended tasks before implementation.

### Fixed

- Validate every extension-registry entry fail-closed, probe PowerShell Git state
  in the resolved override root, and disable bytecode before dynamically loading
  managed Python helpers.
- Retry immutable release verification for up to 40 seconds while GitHub
  finishes publishing release attestations.

## [0.9.0] - 2026-08-30

### Added

- Harden generated Spec Kit skills and scripts with fail-closed gates for
  mandatory clarification, reviewer-owned checklists, analyze evidence,
  validation handoff, canonical issue sync, safe feature paths, hook parsing,
  template composition, and scoped ignore-file changes.

### Changed

- Validate the stable compatibility lane against Spec Kit v1.0.1 and
  `github-issue-canon` v0.3.2.
- Initialize new Git repositories with an empty initial commit so existing
  project files remain unstaged until explicitly reviewed.

### Fixed

- Recognize an unchanged locked generated state during repeat refreshes instead
  of treating bootstrap-owned hardening as a user integration conflict.
- Keep frozen replay mutation-free by applying generated hardening only during
  non-frozen refreshes before the new lock is captured.
- Validate every generated hardening anchor before writing any transformed file,
  propagate transformation failures explicitly, and reject locked issue-canon
  registry metadata drift instead of blessing it.
- Bring the Python auto-commit port in line with the documented conventional
  message-file contract and parse a valid final config line without requiring a
  trailing newline.

## [0.8.1] - 2026-08-30

### Fixed

- Add a live regression gate that imports the installed Python-backed
  issue-canon command and then re-runs `--doctor`, preventing runtime bytecode
  from silently invalidating a healthy extension lock.
- Validate the bootstrap compatibility lane against `github-issue-canon`
  v0.3.2, whose commands no longer write bytecode into the locked payload.

## [0.8.0] - 2026-08-04

### Added

- Record and verify every project-local Spec Kit skill in lock schema v3.
- Record the immutable commit-addressed source URL for the installed `speckit`
  workflow and reject source drift in `--doctor` and `--frozen` modes.
- Add `--with-ponytail` as the explicit opt-in for user-level Ponytail setup.

### Changed

- Keep generated Codex skills in the repository's `.agents/skills` scope,
  matching Codex's repository-skill model and preventing one project from
  changing the skills used by another project.
- During schema v2 migration, preserve all user-level skills and warn about
  manual duplicate cleanup; project lock files never authorize home-directory
  deletion.
- Make Ponytail installation opt-in; project bootstrap no longer changes the
  user's plugin environment unless explicitly requested.
- Update the pinned compatibility baseline to Spec Kit v0.15.2 and GitHub
  Actions to `actions/checkout` v7.0.1 and `setup-uv` v9.0.0.
- Keep Dependabot patch/minor updates grouped while isolating future major
  upgrades for independent review.

### Fixed

- Converge a fresh install in one run by refreshing the workflow on both init
  and update paths and regenerating the Codex integration only after all
  extensions are installed.
- Preserve locally modified integration files by using Spec Kit's diff-aware
  upgrade guard instead of forcing or silently reinstalling the integration.
- Install the official workflow from the immutable Spec Kit release commit
  instead of the catalog's mutable `main` payload URL.
- Resolve explicitly pinned issue-canon versions directly from their tagged
  catalog and retry bounded transient catalog failures, removing stable CI's
  dependency on the mutable `main` catalog.
- Extend live smoke coverage to a fresh run plus two normal repeats, project
  skill tampering, immutable workflow provenance, frozen replay, and audit mode.

### Security

- Replace yanked `zizmor` 1.27.0 (`GHSA-f42p-wjw5-97qh`) with 1.29.0 in local
  and hosted workflow audits.
- Reject symlinked managed project paths and unrecorded `speckit-*` skills.
- Verify the immutable GitHub Release and both published asset attestations.
- Pin the documented first-stage installer URL to the immutable release tag.

## [0.7.1] - 2026-07-20

### Added

- Explain when `skip-worktree` hides install-metadata drift from normal Git
  status and print the exact audit command from a failed doctor run.
- Print an actionable `PATH` command when the installer target isn't currently
  executable by name.

### Changed

- Reuse an installed Spec Kit CLI when both its version and immutable upstream
  commit match, avoiding an unnecessary forced `uv` reinstall.
- Update the pinned compatibility baseline to Spec Kit v0.13.0 after fresh,
  update, integrity, frozen, and audit smoke coverage passed.
- Document the risk-aware `implement -> converge` closeout loop in both English
  and Russian without making it mandatory for tiny or documentation-only work.

## [0.7.0] - 2026-07-14

### Added

- Added a fast local quality gate (`tests/ci-local.sh`) that runs syntax,
  ShellCheck, unit, actionlint, and zizmor checks before push.
- Added a separate weekly/manual upstream canary with independent core and real
  Ponytail lanes, including the current Codex CLI.
- Recorded the catalog-declared `github-issue-canon` archive SHA-256 in new
  reproducibility locks.

### Changed

- Run full CI only for pull requests and manual dispatches; the stable
  `CI / required` context is reused for merge protection, so an unchanged merge
  SHA is not tested a second time.
- Updated the pinned baseline to Spec Kit v0.12.15, issue-canon v0.3.1, and uv
  0.11.28, with safe uv caches enabled in CI.
- Use Spec Kit's catalog installation path so v0.12.15 verifies the extension
  archive against the catalog's SHA-256 before installation.
- Refresh existing workflows with `specify workflow update` and fall back to
  installation only when no updatable workflow exists.
- Publish from annotated `v*` tags: the read-only job packages once and the
  checkout-free write job publishes that exact artifact.

### Fixed

- Removed the obsolete `--branch-numbering sequential` retry, which repeated a
  failed initialization even though current Spec Kit treats the option as a
  deprecated no-op.
- Remove Spec Kit's completed workflow-install lock during cache cleanup so a
  catalog migration does not leave an otherwise unchanged project dirty.
- Fail closed when a workflow update command errors instead of treating every
  failure as a legacy bundled-workflow migration signal.
- Confirm catalog workflow updates noninteractively so the new v0.12.15 update
  command cannot block an unattended bootstrap when an update is available.
- Let the Ponytail canary exercise the real plugin path instead of inheriting a
  smoke-test flag that always skipped it.
- Authenticate Spec Kit release downloads in CI through a temporary
  environment-backed auth config, avoiding shared-runner API rate-limit flakes
  without persisting the token.

### Security

- Release publication now validates annotated tags and `main` ancestry before
  granting the isolated publish job `contents: write`.
- Upstream workflow syntax and permissions remain guarded by pinned actionlint
  and zizmor checks, while repository rulesets require only the stable aggregate
  context.

## [0.6.1] - 2026-07-13

### Fixed

- Pass the repository explicitly to `gh release upload` so the isolated
  publishing job can attach verified assets without requiring a source checkout.

## [0.6.0] - 2026-07-13

### Added

- Added `--doctor`, `--dry-run`, `--frozen`, `--json`, and `--version` modes.
- Added `.specify/speckit-bootstrap.lock.json` with exact Spec Kit,
  `github-issue-canon`, Ponytail, immutable commit refs, source metadata,
  marketplace/extension hashes, and the installed workflow checksum for
  reproducible refreshes.
- Added isolated unit tests, macOS/Ubuntu live smoke tests, scheduled upstream
  compatibility checks, Dependabot configuration, and release-asset automation.
- Added project-local issue canon docs, issue forms, and PR template installation
  even when no GitHub remote is configured.

### Changed

- `github-issue-canon` now installs from a resolved release tag instead of a
  mutable `main` archive; the actual download URL is pinned to the tag's commit.
- Ponytail now uses a versioned managed local marketplace descriptor that pins
  the plugin source to the tag's commit SHA. Installed versions/refs are
  verified, and guidance comes from the installed plugin cache.
- Spec Kit installation now uses the commit SHA behind the selected release
  tag while retaining the tag as the human-readable version.
- User extension catalogs are merged additively, and extension refreshes no
  longer remove the previous installation before replacement.
- Global Spec Kit skills are staged, validated, and atomically swapped under a
  process lock while preserving unrelated and user-owned skills.
- The installer now consumes GitHub Release assets and verifies SHA-256 before
  installing the executable.
- Frozen runs now preserve the locked catalog-backed workflow/core extensions
  and fail on version or hash drift instead of refreshing mutable catalog state.
- The pinned compatibility baseline now uses `github-issue-canon` v0.2.6,
  whose catalog and manual install path resolve to an immutable release tag.

### Fixed

- Fresh `uv tool install` runs now expose uv's tool bin directory to the current
  bootstrap process, including isolated CI homes.
- Audit mode now removes existing `skip-worktree` bits instead of merely
  refraining from adding new ones.
- Managed risk-lane template changes now fail closed when upstream template
  anchors drift, rather than silently claiming success.
- Agent-context refresh now discovers the actual `specify` interpreter from its
  launcher before falling back to conventional uv paths.
- Frozen runs no longer rewrite the lock when Ponytail is skipped, and
  `--skip-cli-update` now verifies the installed CLI's exact locked source
  commit rather than accepting a matching display version alone.
- Signal handling now releases the global-skill lock and terminates with the
  conventional signal status instead of continuing without mutual exclusion.
- Ponytail marketplace paths are canonicalized so macOS `/var` and
  `/private/var` aliases compare as the same managed source.
- `--json` now reserves stdout for one machine-readable document and sends
  human diagnostics to stderr.

### Security

- Added checksum-verified release installation and explicit opt-in for legacy
  unverified sources.
- Pinned third-party GitHub Actions by full commit SHA and reduced workflow
  permissions to the minimum required per workflow.
- Lock schema v2 records complete extension trees and every managed global
  skill, so doctor rejects executable payload or skill drift even when registry
  metadata is unchanged.
- Release assets are built and tested in a read-only job; the separate
  `contents: write` publishing job only downloads and uploads the verified
  artifact and never executes repository code.

## [0.5.2] - 2026-07-08

### Changed

- Bootstrap now uses `SPECIFY_INIT_DIR` when running official Spec Kit init so
  newer Spec Kit project resolution stays explicit.
- Managed `AGENTS.md` blocks are normalized to a single trailing newline so
  repeated refreshes do not create blank-line-only diffs.
- Managed GitHub issue guidance now states the same Spec Kit task-backed title
  canon as the reusable extension:
  `[<feature>][<priority>][<area>] T###: <русский результат>`.

### Added

- Added git diff hygiene for existing projects: refresh-only Spec Kit install
  metadata is marked `skip-worktree` by default, with
  `SPECKIT_TRACK_INSTALL_METADATA=1` available for release/audit runs that need
  to inspect metadata drift.

## [0.5.1] - 2026-06-26

### Changed

- Updated managed Ponytail-in-Spec-Kit guidance to be risk-lane aware:
  Ponytail must not weaken the selected risk/validation lane, while low-risk
  lanes can remain scoped and significant/high-risk lanes keep full Spec Kit
  evidence.
- Clarified README guidance so `$speckit-taskstoissues` is required for tracked
  Spec Kit feature slices, not for read-only, docs-only, or tiny low-risk direct
  changes.

## [0.5.0] - 2026-06-25

### Added

- Added Ponytail bootstrap integration: `speckit-bootstrap` now installs or
  updates the `DietrichGebert/ponytail` Codex plugin through Codex's plugin
  manager, refreshes a managed Ponytail guidance block in `AGENTS.md`, and
  keeps Ponytail-owned hooks/skills out of this repository.
- Added `--skip-ponytail` plus `SPECKIT_PONYTAIL=0` for environments that
  should not install plugins.
- Added generated Ponytail upstream guidance sync:
  `docs/agent-guidance/ponytail-upstream.md` is refreshed from Ponytail's
  upstream `AGENTS.md`, while the root `AGENTS.md` only links to it from the
  managed Spec Kit Ponytail block.

## [0.4.1] - 2026-06-18

### Added

- Added release/versioning guidance for bootstrapped projects: product apps and
  services use CalVer `vYYYY.MM.DD.N`, reusable tooling uses SemVer
  `vMAJOR.MINOR.PATCH`, and human-readable release postfixes belong in GitHub
  Release titles rather than stable tags.

## [0.4.0] - 2026-06-18

### Changed

- Updated GitHub issue and PR guidance to require Russian PR descriptions,
  precise closing keywords, and detailed Russian closure comments before issue
  closeout.
- Updated the managed `AGENTS.md` block generated by `speckit-bootstrap` so new
  and refreshed projects no longer ask for a brief evidence-only note. They now
  require a full Russian closeout comment with the completed work, user/project
  impact, validation evidence, out-of-scope notes, PR link, and Spec Kit task.
- Documented the GitHub closing-keyword boundary: `Fixes`, `Closes`, and
  `Resolves` are only for issues fully closed by the PR, while partial or
  related work must use `Refs` or `Part of`.
- Clarified that PR descriptions, issue bodies, issue comments, closure
  comments, and sync notes all default to Russian plain language.

### Added

- Documented the PR template role in the bootstrap tracking model: PRs should
  capture Russian summaries, validation evidence, issue links, and closeout
  checklists before merge.

### Breaking

- This release aligns bootstrap guidance with the Russian-only issue canon
  `v0.2.0`. Projects that still depend on English issue sections or short
  evidence-only closeout comments should refresh their issue canon and normalize
  open Spec Kit issues.

## [0.3.6] - 2026-06-18

### Changed

- Updated bootstrap documentation and managed GitHub issue guidance to point at
  `docs/agent-guidance/github-issue-canon.md`.

## [0.3.5] - 2026-06-17

### Removed

- Removed the temporary retired external tracker cleanup path from the bootstrap
  wrapper and docs.
- Removed the follow-up backlog entry for that cleanup now that active projects
  are expected to keep GitHub issues as the only external tracking surface.

## [0.3.4] - 2026-06-15

### Fixed

- Fixed fresh project initialization with Spec Kit `v0.10.2`, which removed the
  `specify init --branch-numbering` option.
- Added a legacy fallback so older Spec Kit CLI versions can still initialize
  with the previous branch-numbering argument if needed.

## [0.3.3] - 2026-06-11

### Added

- Added a managed GitHub issue instruction block for `AGENTS.md` that preserves
  the `tasks.md` plus GitHub issue flow independently of retired tracker cleanup.
- Reaffirmed that GitHub issue titles, bodies, comments, and sync notes should
  be written in simple Russian by default.

## [0.3.2] - 2026-06-11

### Added

- Added `BACKLOG.md` with the follow-up to remove temporary retired tracker cleanup code
  after old projects and worktrees have been refreshed.

### Changed

- Documented the retired external tracker cleanup as a temporary migration step: keep it
  now to remove installed remnants everywhere, then remove the cleanup code in a
  later release.

## [0.3.1] - 2026-06-11

### Fixed

- Extended retired tracker skill cleanup to remove canonical generated skill
  directories as well as older names.

## [0.3.0] - 2026-06-11

### Removed

- Removed the retired external tracker from the default Spec Kit tracking flow.
- Removed automatic installation of the retired tracker extension.
- Removed retired tracker key propagation from private bootstrap env files into project
  `.env` files.
- Removed generated retired tracker operating instructions from the active agent flow.

### Changed

- Standardized project tracking on `tasks.md` plus GitHub issues only.
- Bootstrap now cleans up old retired tracker extension files, generated
  skills, managed instruction blocks, and retired env keys when refreshing an
  existing project.
- Updated documentation so `$speckit-taskstoissues` is the only external issue
  sync step before implementation.

## [0.2.1] - 2026-06-11

### Fixed

- Run the agent-context update through the `specify-cli` tool Python when
  available, so bootstrap does not depend on system `python3` having PyYAML.
- Fall back to the uv-managed `specify-cli` Python path when `specify` itself is
  a wrapper in `~/.local/bin`.

## [0.2.0] - 2026-06-11

### Added

- Added automatic installation of Yan's retired external tracker Spec Kit extension.
- Added generated `AGENTS.md` retired tracker operating rules.
- Added Russian plain-language rules for all GitHub issues, external tracker issues,
  comments, project updates, and sync notes.
- Added product-prefixed external tracker project guidance, for example
  `2brain Rec / 013 Federated Auth Foundation`.
- Added private env sync from `~/.codex/secrets/speckit.env` into project
  `.env`.
- Added an override URL for the retired external tracker extension ZIP.
- Added `SPECKIT_PROJECT_ENV_FILE` for overriding the private env source file.

### Changed

- Updated the recommended Spec Kit flow to include retired external tracker
  import/sync after `$speckit-taskstoissues`.

### Security

- Ensured project `.env` is added to `.gitignore` when private env sync is used.
- Ensured project `.env` is written with local-only permissions where possible.
- Kept secrets out of generated agent instructions and tracked docs.
