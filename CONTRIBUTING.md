# Contributing

## Local checks

Use Bash-compatible changes and preserve macOS system Bash 3.2 support. Before
opening a pull request, run:

```sh
bash -n bin/speckit-bootstrap install.sh tests/unit.sh tests/smoke-live.sh
shellcheck bin/speckit-bootstrap install.sh tests/unit.sh tests/smoke-live.sh
bash tests/unit.sh
SPEC_KIT_VERSION=v0.12.11 \
  SPECKIT_GITHUB_ISSUE_CANON_VERSION=v0.2.6 \
  bash tests/smoke-live.sh
```

The smoke test uses temporary project and home directories. It must not depend
on a developer's installed Spec Kit, catalogs, skills, or Git configuration.

## Change expectations

- Preserve user-owned catalogs, skills, guidance, and GitHub templates.
- Keep a failed refresh recoverable; stage and validate before replacing state.
- Pin new external automation by immutable revision.
- Update `README.md` and `CHANGELOG.md` whenever the public CLI, generated
  state, compatibility contract, or installer behavior changes.
- Do not include credentials, tokens, private repository URLs, or local paths in
  fixtures and logs.

## Release checklist

1. Confirm CI passes on macOS and Ubuntu, including the pinned live smoke test.
2. Run the latest-upstream compatibility workflow manually.
3. Set `BOOTSTRAP_VERSION` and add a dated changelog entry.
4. Create a SemVer tag whose value is exactly `v$(bin/speckit-bootstrap
   --version | awk '{print $2}')`.
5. Publish the GitHub Release with compatibility notes and validation evidence.
6. Confirm the release workflow uploaded `speckit-bootstrap` and
   `speckit-bootstrap.sha256`.
7. Run a clean installer smoke test against the published tag.

The release workflow rejects a tag/version mismatch and does not publish from
an arbitrary branch head.
