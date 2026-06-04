# speckit-bootstrap

Yan's upstream-clean bootstrap wrapper for GitHub Spec Kit + Codex.

The script updates official Spec Kit from `github/spec-kit`, initializes or
refreshes the current project, installs bundled Spec Kit extensions, installs
Yan's reusable `github-issue-canon` extension from GitHub, and syncs generated
Codex skills into `~/.agents/skills`.

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

## Usage

From any project:

```sh
speckit-bootstrap .
```

Or:

```sh
speckit-bootstrap /path/to/project
```

## What It Does

- installs/updates official `specify-cli` from `github/spec-kit`;
- initializes or updates project-local `.specify` state;
- installs the official `agent-context` and `git` extensions;
- installs `github-issue-canon` from Yan's GitHub extension catalog;
- registers `$speckit-github-issue-canon-*` skills;
- syncs generated `speckit-*` skills to `~/.agents/skills`;
- removes project-local duplicate skills by default.

## Latest-From-Git Policy

The default behavior is not pinned to a local archive.

- Official Spec Kit is resolved from upstream Git tags by default.
- `github-issue-canon` is resolved through Yan's extension catalog, whose
  `download_url` tracks the extension repository's `main` branch.
- `speckit-bootstrap` itself is installed from this repository's `main` branch.

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
