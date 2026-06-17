# Changelog

All notable changes to this project are documented in this file.

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
