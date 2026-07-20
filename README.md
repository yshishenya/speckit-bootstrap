<h1 align="center">speckit-bootstrap</h1>

<p align="center">
  <strong>Reproducible Spec-Driven Development for Codex — in one command.</strong>
</p>

<p align="center">
  Turn any Git repository into a tested GitHub Spec Kit + Codex workspace
  with pinned inputs, reusable skills, GitHub issue automation, and a lockfile
  you can replay.
</p>

<p align="center">
  <strong>Language:</strong>
  <a href="README.md">English</a> · <a href="README.ru.md">Русский</a>
</p>

<p align="center">
  <a href="https://github.com/yshishenya/speckit-bootstrap/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/yshishenya/speckit-bootstrap/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/yshishenya/speckit-bootstrap/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/yshishenya/speckit-bootstrap?display_name=tag&sort=semver"></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <img alt="Tested on macOS and Ubuntu" src="https://img.shields.io/badge/tested-macOS%20%2B%20Ubuntu-2ea44f">
  <img alt="Bash 3.2 and later" src="https://img.shields.io/badge/Bash-3.2%2B-4EAA25?logo=gnubash&logoColor=white">
</p>

> [!NOTE]
> `speckit-bootstrap` is a community project. It builds on the official
> [GitHub Spec Kit](https://github.com/github/spec-kit), but it isn't affiliated
> with or endorsed by GitHub.

## Why speckit-bootstrap?

Spec-Driven Development is powerful. Keeping its CLI, workflows, extensions,
agent skills, project policy, and tracker integration aligned by hand isn't.

`speckit-bootstrap` turns that moving toolchain into one idempotent command:

```sh
speckit-bootstrap .
```

| Without bootstrap | With `speckit-bootstrap` |
| --- | --- |
| Install and wire every component manually | One command installs or refreshes the complete stack |
| “Latest” changes underneath you | Every resolved tag, commit, source, and payload digest is locked |
| Drift appears during implementation | `--doctor` detects drift before work starts |
| Upgrades leave noisy or partial state | Changes are staged, validated, and applied atomically |
| Agent and GitHub conventions vary by project | Reusable Codex skills and issue canon are installed consistently |
| Rollback means reconstructing an old setup | `--frozen` replays and verifies the recorded dependency set |

## Quick start

You need macOS or Ubuntu with `git`, `curl`, `python3`, and
[`uv`](https://docs.astral.sh/uv/). You also need the `codex` CLI unless you run
bootstrap with `--skip-ponytail`.

### 1. Install or update

```sh
curl -fsSL https://raw.githubusercontent.com/yshishenya/speckit-bootstrap/main/install.sh | bash
```

The installer resolves the latest GitHub Release, downloads the executable and
its SHA-256 file, verifies the checksum and shell syntax, and installs it
atomically at:

```text
~/.local/bin/speckit-bootstrap
```

Make sure `~/.local/bin` is on your `PATH`, then verify the installation:

```sh
export PATH="$HOME/.local/bin:$PATH"
speckit-bootstrap --version
```

Re-run the installer at any time to update. To install a specific release:

```sh
curl -fsSL https://raw.githubusercontent.com/yshishenya/speckit-bootstrap/main/install.sh |
  SPECKIT_BOOTSTRAP_VERSION=v0.7.1 bash
```

> [!TIP]
> Prefer to inspect scripts before running them? Download
> [`install.sh`](install.sh), review it locally, and run it with `bash`.

### 2. Bootstrap a project

For a new repository:

```sh
mkdir my-project
cd my-project
git init
speckit-bootstrap .
```

For an existing repository:

```sh
cd /path/to/project
speckit-bootstrap .
```

The first successful run creates or refreshes:

```text
.specify/
.specify/speckit-bootstrap.lock.json
AGENTS.md
docs/agent-guidance/
.github/ISSUE_TEMPLATE/
.github/pull_request_template.md
~/.agents/skills/speckit-*
```

Review the diff before committing the generated project baseline.

### 3. Verify the result

```sh
speckit-bootstrap . --doctor
```

`--doctor` is read-only. It checks the installed CLI source, locked workflow,
extension payloads, Ponytail state, project guidance, and every managed global
skill digest. A healthy installation reports `speckit-bootstrap: doctor OK`.

## What you get

- **Official Spec Kit, pinned.** The latest official `v*` tag is resolved to
  its immutable commit SHA before installation.
- **Fast repeat refreshes.** An installed CLI with the exact requested version
  and source commit is reused without a forced reinstall.
- **Codex-native workflows.** Generated `speckit-*` skills are synchronized to
  `~/.agents/skills` and project-local duplicates are removed by default.
- **Reproducible refreshes.** The lock records versions, commit refs, source
  URLs, workflow hashes, extension trees, and managed skill digests.
- **Safe GitHub tracking.** The bundled
  [`github-issue-canon`](https://github.com/yshishenya/spec-kit-ext-github-issue-canon)
  installs structured issue forms, a pull request template, validation hooks,
  and closeout rules.
- **Ponytail integration.** Codex owns the
  [`Ponytail`](https://github.com/DietrichGebert/ponytail) plugin lifecycle while
  bootstrap pins its source and keeps project guidance current.
- **Respect for user-owned state.** Existing catalogs, unrelated skills,
  guidance, and GitHub templates are preserved.
- **Fail-closed validation.** Version drift, checksum drift, missing managed
  files, and tampered executable agent inputs stop the run.
- **Clean Git diffs.** Refresh-only Spec Kit install metadata is hidden from
  normal diffs while behavioral project changes stay visible.

## How it works

```mermaid
flowchart LR
    A["speckit-bootstrap ."] --> B["Official GitHub Spec Kit<br/>tag resolved to commit SHA"]
    A --> C["Codex skills<br/>~/.agents/skills"]
    A --> D["GitHub issue canon<br/>templates + hooks"]
    A --> E["Ponytail plugin<br/>pinned source + guidance"]
    B --> F["Reproducibility lock"]
    C --> F
    D --> F
    E --> F
    F --> G["Post-install verification"]
```

The bootstrap never changes upstream repositories. It applies explicit,
reviewable managed sections to generated project files, stages global skill
updates before swapping them, and restores the previous state when a managed
replacement fails.

### Latest first, locked afterward

The default non-frozen run intentionally starts from current stable releases:

1. Resolve the latest approved release tags.
2. Resolve each tag to an immutable commit.
3. Install and validate the workflow, extensions, plugin, and skills.
4. Record exact sources and payload digests in
   `.specify/speckit-bootstrap.lock.json`.
5. Verify the completed installation before reporting success.

Later, replay that contract without resolving new versions:

```sh
speckit-bootstrap . --frozen
```

Frozen mode preserves the lock and fails if locked executable inputs have
drifted.

## Daily workflow

Use the fast path when you start work or want to refresh integrations:

```sh
# Preview versions and planned mutations.
speckit-bootstrap . --dry-run --json

# Apply the refresh.
speckit-bootstrap .

# Verify the result without writing.
speckit-bootstrap . --doctor
```

Then use the normal Spec Kit skills in Codex:

```text
$speckit-specify
$speckit-clarify
$speckit-plan
$speckit-checklist
$speckit-tasks
$speckit-analyze
$speckit-taskstoissues
$speckit-implement
$speckit-converge
```

`$speckit-clarify`, `$speckit-checklist`, and `$speckit-analyze` are quality
gates you can apply according to risk. Use `$speckit-taskstoissues` for tracked
feature work with a GitHub remote; skip it for read-only, documentation-only,
or tiny direct changes.

For significant or high-risk work, run `$speckit-converge` after implementation.
If it appends tasks, run `$speckit-implement` and `$speckit-converge` again
before opening the pull request. Skip convergence for read-only,
documentation-only, or tiny direct changes.

When task-to-issue synchronization runs, the installed extension automatically:

- ensures the repository's issue canon files and labels before sync;
- validates open Spec Kit issues after sync;
- keeps `tasks.md` as the implementation source of truth;
- links implementation, pull request, validation, and closeout evidence.

> [!IMPORTANT]
> The bundled GitHub issue and pull request governance is Russian-first by
> default. This is an intentional project convention and is documented in the
> generated agent guidance.

## Opinionated defaults

This project is deliberately more than a package installer. It installs a
reviewable development policy intended to keep agents, repository artifacts,
and external tracking aligned:

- Git auto-commit is enabled after completed documentation stages:
  `constitution`, `specify`, `clarify`, `plan`, `checklist`, `tasks`, and
  `analyze`.
- Every `before_*` hook, `after_implement`, and `after_taskstoissues` stays
  disabled. Implementation code and external tracker changes remain explicit.
- `tasks.md` is the implementation source of truth. GitHub Issues are the
  external execution, review, and closeout tracker.
- Tracked issue titles follow
  `[<feature>][<priority>][<area>] T###: <Russian outcome>`.
- Generated plan and task templates require an explicit risk and validation
  lane before implementation.
- Product applications and deployed services use CalVer; reusable tools and
  libraries use SemVer.
- Ponytail shapes implementation behavior but doesn't weaken the selected
  validation lane. Review installed hooks with `/hooks` after installation or
  upgrade.

Managed policy sections remain visible in the project diff. User-owned content
outside those sections is preserved.

## CLI reference

```text
speckit-bootstrap [PROJECT_DIR] [OPTIONS]
```

| Option | Effect |
| --- | --- |
| `--doctor` | Verify project and user state without changing it |
| `--dry-run` | Resolve inputs and print the mutation plan only |
| `--version` | Print the bootstrap version and exit |
| `--frozen` | Use and verify versions from the project lock |
| `--json` | Reserve stdout for one machine-readable result |
| `--keep-local-skills` | Keep generated project-local skill duplicates |
| `--skip-cli-update` | Use the currently installed `specify` CLI |
| `--skip-ponytail` | Skip Ponytail plugin and guidance updates |
| `-h`, `--help` | Show complete command help |

Useful recipes:

```sh
# Keep the currently installed specify-cli without resolving another version.
speckit-bootstrap . --skip-cli-update

# Pin or roll back official Spec Kit, then write a new lock.
SPEC_KIT_VERSION=vX.Y.Z speckit-bootstrap .

# Try the current official Spec Kit main branch.
SPEC_KIT_VERSION=main speckit-bootstrap .

# Keep refresh-only install metadata visible for an audit or release.
SPECKIT_TRACK_INSTALL_METADATA=1 speckit-bootstrap .

# Run in a headless environment without Codex/Ponytail.
speckit-bootstrap . --skip-ponytail
```

### Environment variables

| Variable | Purpose |
| --- | --- |
| `SPEC_KIT_VERSION` | Spec Kit tag or ref; defaults to the latest `v*` tag |
| `SPECKIT_EXTENSION_CATALOG_URL` | Override the approved extension catalog |
| `SPECKIT_GITHUB_ISSUE_CANON_VERSION` | Pin the issue-canon release tag |
| `SPECKIT_GITHUB_ISSUE_CANON_URL` | Use an explicitly reviewed custom ZIP |
| `SPECKIT_PONYTAIL_VERSION` | Pin the Ponytail release tag |
| `SPECKIT_PONYTAIL=0` | Disable Ponytail plugin and guidance operations |
| `SPECKIT_TRACK_INSTALL_METADATA=1` | Expose refresh-only metadata in Git diffs |
| `SPECKIT_BOOTSTRAP_INSTALL_DIR` | Installer target; defaults to `~/.local/bin` |
| `SPECKIT_BOOTSTRAP_VERSION` | Bootstrap release tag; defaults to `latest` |
| `SPECKIT_BOOTSTRAP_URL` | Use a custom installer payload source |
| `SPECKIT_BOOTSTRAP_SHA256` | Required checksum for a custom payload source |
| `SPECKIT_BOOTSTRAP_ALLOW_UNVERIFIED=1` | Emergency opt-in for a reviewed unverified source |

Run `speckit-bootstrap --help` for the authoritative interface.

## Prerequisites and compatibility

Required:

- `git`
- `curl`
- `python3`
- [`uv`](https://docs.astral.sh/uv/)

The `codex` CLI is required when Ponytail is enabled. Use `--skip-ponytail` in
headless environments.

The maintained compatibility matrix is:

- macOS with the system Bash 3.2;
- Ubuntu with Bash 5.

Other Unix-like environments may work but aren't part of the current CI gate.

## Verification and trust model

The project treats generated agent instructions as executable supply-chain
inputs, not harmless documentation.

- Release installation verifies the executable against its published SHA-256.
- External release tags are resolved to immutable commits.
- The issue-canon release asset is verified against the catalog checksum.
- Ponytail's managed marketplace descriptor pins its plugin source to a commit.
- Lock schema v2 captures complete extension and managed-skill trees.
- GitHub Actions are pinned by full commit SHA and audited with `zizmor`.
- CI tests Bash syntax, ShellCheck, isolated units, workflow security, and live
  bootstrap behavior on macOS and Ubuntu.

See [SECURITY.md](SECURITY.md) for private vulnerability reporting and complete
trust boundaries.

## Development

Run the fast local gate:

```sh
bash tests/ci-local.sh
```

Run the pinned end-to-end bootstrap smoke test:

```sh
SPEC_KIT_VERSION=v0.13.0 \
  SPECKIT_GITHUB_ISSUE_CANON_VERSION=v0.3.1 \
  bash tests/smoke-live.sh
```

GitHub runs the full functional gate once on each pull request, across macOS
and Ubuntu. Merging unchanged code doesn't repeat the same CI. Tag-driven
releases package the exact tested commit without rerunning functional CI, while
a separate weekly canary detects new upstream incompatibilities.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request and check
[CHANGELOG.md](CHANGELOG.md) for release history.

## Help the project grow

If `speckit-bootstrap` saves you setup time:

- [star the repository](https://github.com/yshishenya/speckit-bootstrap)
  so other Spec Kit and Codex users can find it;
- share the quick-start link with teams adopting Spec-Driven Development;
- [open an issue](https://github.com/yshishenya/speckit-bootstrap/issues/new)
  with a reproducible bug or a concrete workflow improvement;
- contribute a focused pull request with validation evidence.

The most useful contribution is a real project story: what you bootstrapped,
what manual work disappeared, and where the workflow still got in your way.

## License

Released under the [MIT License](LICENSE).
