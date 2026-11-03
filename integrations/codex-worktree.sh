#!/usr/bin/env bash
# Local GRAF setup: latest stable at creation, isolated and locked afterwards.
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
root="$(git -C "${1:-$PWD}" rev-parse --show-toplevel)"
cd "$root"
git_dir="$(git rev-parse --absolute-git-dir)"
common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
[[ "$git_dir" != "$common_dir" ]] || { echo 'Refusing setup outside a linked worktree.' >&2; exit 1; }
case "$(git remote get-url origin)" in
  git@github.com:yshishenya/graf.git|https://github.com/yshishenya/graf.git) ;;
  *) echo 'This local environment is configured for GRAF only.' >&2; exit 1 ;;
esac
export UV_TOOL_DIR="$git_dir/speckit-tools/tools"
export UV_TOOL_BIN_DIR="$git_dir/speckit-tools/bin"
export PATH="$UV_TOOL_BIN_DIR:$PATH"
# New worktrees install the latest checksummed release into their isolated bin.
# Completed worktrees only verify their recorded toolchain.
bootstrap="$UV_TOOL_BIN_DIR/speckit-bootstrap"
if [[ -f "$git_dir/speckit-setup-complete" ]]; then
  [[ -x "$bootstrap" ]] || bootstrap="$HOME/.local/bin/speckit-bootstrap"
  [[ -x "$bootstrap" ]] || { echo 'Bootstrap is not installed.' >&2; exit 1; }
  exec "$bootstrap" . --doctor --frozen
fi
[[ -z "$(git status --porcelain --untracked-files=all -- . ':!.codex/environments/')" ]] || {
  echo 'Refusing to refresh a worktree with existing changes. No files were overwritten.' >&2; exit 1;
}
[[ ! -L .codex && ! -e .codex/config.toml && ! -L .codex/config.toml && ! -e .codex/.gitignore && ! -L .codex/.gitignore ]] || {
  echo 'Existing local Codex configuration needs an explicit merge.' >&2; exit 1;
}
mkdir "$git_dir/speckit-setup-running" || { echo 'Setup is already running.' >&2; exit 1; }
installer=""
cleanup() {
  [[ -z "$installer" ]] || rm -f "$installer"
  rmdir "$git_dir/speckit-setup-running"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$UV_TOOL_BIN_DIR"
installer="$(mktemp "$git_dir/speckit-tools/install.XXXXXX")"
curl --fail --location --silent --show-error \
  --connect-timeout 20 --max-time 120 \
  https://raw.githubusercontent.com/yshishenya/speckit-bootstrap/main/install.sh \
  --output "$installer"
SPECKIT_BOOTSTRAP_VERSION=latest SPECKIT_BOOTSTRAP_INSTALL_DIR="$UV_TOOL_BIN_DIR" \
  SPECKIT_BOOTSTRAP_URL='' SPECKIT_BOOTSTRAP_SHA256='' SPECKIT_BOOTSTRAP_ALLOW_UNVERIFIED=0 \
  bash "$installer"
rm -f "$installer"
installer=""

# Bootstrap verifies the old lock before updating and resolves latest to a SHA.
# New GRAF environments enable Ponytail by default; an explicit env opt-out wins.
SPEC_KIT_VERSION=latest SPECKIT_GITHUB_ISSUE_CANON_VERSION=latest \
  SPECKIT_PONYTAIL_VERSION=latest SPECKIT_TRACK_INSTALL_METADATA=1 \
  "$bootstrap" .
"$bootstrap" . --doctor --frozen

# Bind future Codex shells to this worktree's CLI; never change the global CLI.
python3 - "$git_dir" <<'PY'
import json
import os
import sys
from pathlib import Path

directory = Path('.codex')
directory.mkdir(exist_ok=True)
shell_dir = Path(sys.argv[1], 'speckit-tools', 'shell')
shell_dir.mkdir(exist_ok=True)
# Keep user shell variables, then restore the isolated CLI after ~/.zshenv.
(shell_dir / '.zshenv').write_text(
    '[[ ! -f "$HOME/.zshenv" ]] || source "$HOME/.zshenv"\n'
    'export PATH="$UV_TOOL_BIN_DIR:$PATH"\n'
)
config = 'allow_login_shell = false\n\n[shell_environment_policy.set]\n' + ''.join(
    f'{key} = {json.dumps(os.environ[key])}\n'
    for key in ('PATH', 'UV_TOOL_DIR', 'UV_TOOL_BIN_DIR')
)
config += f'ZDOTDIR = {json.dumps(str(shell_dir))}\n'
with (directory / 'config.toml').open('x') as output:
    output.write(config)
with (directory / '.gitignore').open('x') as output:
    output.write('/config.toml\n/.gitignore\n')
Path(sys.argv[1], 'speckit-setup-complete').touch()
PY
printf 'Spec Kit setup complete; subsequent setup runs only verify the lock.\n'
