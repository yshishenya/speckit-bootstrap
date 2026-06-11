# Changelog

All notable changes to this project are documented in this file.

## [0.3.0] - 2026-06-11

### Removed

- Removed Linear from the default Spec Kit tracking flow.
- Removed automatic installation of the retired `linear-sync` extension.
- Removed Linear key propagation from private bootstrap env files into project
  `.env` files.
- Removed generated Linear operating instructions from the active agent flow.

### Changed

- Standardized project tracking on `tasks.md` plus GitHub issues only.
- Bootstrap now cleans up old `linear-sync` extension files, generated
  `$speckit-linear-*` skills, managed Linear instruction blocks, and retired
  Linear env keys when refreshing an existing project.
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

- Added automatic installation of Yan's `linear-sync` Spec Kit extension.
- Added generated `AGENTS.md` Linear operating rules.
- Added Russian plain-language rules for all GitHub issues, Linear issues,
  comments, project updates, and sync notes.
- Added product-prefixed Linear Project guidance, for example
  `2brain Rec / 013 Federated Auth Foundation`.
- Added private env sync from `~/.codex/secrets/speckit.env` into project
  `.env`.
- Added `SPECKIT_LINEAR_SYNC_URL` for overriding the Linear Sync extension ZIP.
- Added `SPECKIT_PROJECT_ENV_FILE` for overriding the private env source file.

### Changed

- Updated the recommended Spec Kit flow to include `$speckit-linear-import` and
  `$speckit-linear-sync` after `$speckit-taskstoissues`.

### Security

- Ensured project `.env` is added to `.gitignore` when private env sync is used.
- Ensured project `.env` is written with local-only permissions where possible.
- Kept secrets out of generated agent instructions and tracked docs.
