# Security Policy

## Supported versions

Security fixes are provided for the latest published minor release. Users
should update to the newest GitHub Release and refresh bootstrapped projects.

## Reporting a vulnerability

Report vulnerabilities privately through this repository's GitHub Security
Advisories **Report a vulnerability** flow. Do not open a public issue for a
suspected command-injection, supply-chain, credential, permission, or unsafe
filesystem finding.

Include the affected version, operating system, minimal reproduction, expected
impact, and whether the behavior requires a custom environment variable or
unverified installer mode. Remove credentials, tokens, private URLs, and
personal paths from all evidence.

Maintainers should acknowledge a complete report within seven days, validate
severity and supported versions, and coordinate disclosure after a fix or
documented mitigation is available.

## Trust boundaries

- `install.sh` verifies the published executable against the checksum asset
  from the same GitHub Release. Custom URLs require an explicit checksum unless
  emergency unverified mode is deliberately enabled.
- Bootstrap executes official `specify`, extension, and Codex plugin tooling.
  Review custom URLs and tags before overriding defaults.
- Release tags are resolved to commit SHAs. Ponytail uses a generated local
  marketplace descriptor whose checksum is locked and whose plugin source is
  the resolved commit, avoiding the upstream descriptor's mutable `main` ref.
- Generated project files and project-local skills are executable agent inputs.
  Review their diff before committing or relying on new upstream behavior.
- Managed project paths reject symlinks, and release publication verifies the
  immutable release attestation for both distributed assets.
