# Changelog

All notable changes to this project are documented in this file.

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
