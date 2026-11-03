"""Exercise the shipped hook with local Git and a fake checked installer."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
hook = root / 'integrations/codex-worktree.sh'
with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    home = base / 'home'
    tools = home / '.local/bin'
    tools.mkdir(parents=True)
    stub = base / 'bootstrap'
    stub.write_text('''#!/bin/bash
set -euo pipefail
source "$REAL_BOOTSTRAP"
parse_args "$@"
printf '%s %s\\n' "$MODE" "$SKIP_PONYTAIL" >> "$HOOK_CALLS"
''')
    curl = tools / 'curl'
    curl.write_text('''#!/bin/bash
set -euo pipefail
while [[ "$1" != --output ]]; do shift; done
cat > "$2" <<'INSTALLER'
mkdir -p "$SPECKIT_BOOTSTRAP_INSTALL_DIR"
install -m 0755 "$HOOK_STUB" "$SPECKIT_BOOTSTRAP_INSTALL_DIR/speckit-bootstrap"
INSTALLER
''')
    curl.chmod(0o755)
    repo = base / 'repo'
    repo.mkdir()
    def git(*args):
        return subprocess.run(['git', '-C', str(repo), *args], check=True,
                              capture_output=True, text=True)
    git('init', '-q')
    git('config', 'user.name', 'Hook test')
    git('config', 'user.email', 'test@example.invalid')
    git('remote', 'add', 'origin', 'https://github.com/yshishenya/graf.git')
    (repo / 'README.md').write_text('fixture\n')
    git('add', '.')
    git('commit', '-qm', 'fixture')
    for choice, expected in [(None, '0'), ('0', '1')]:
        project = base / ('default' if choice is None else 'opt-out')
        git('worktree', 'add', '--detach', str(project), 'HEAD')
        calls = base / f'{project.name}.calls'
        env = dict(os.environ, HOME=str(home), REAL_BOOTSTRAP=str(root / 'bin/speckit-bootstrap'),
                   HOOK_STUB=str(stub), HOOK_CALLS=str(calls))
        env.pop('SPECKIT_PONYTAIL', None)
        if choice is not None:
            env['SPECKIT_PONYTAIL'] = choice
        def run(path):
            return subprocess.run(['bash', str(hook), str(path)], env=env,
                                  capture_output=True, text=True)
        result = run(repo)
        assert result.returncode != 0 and 'outside a linked worktree' in result.stderr
        (project / 'README.md').write_text('user change\n')
        result = run(project)
        assert result.returncode != 0 and 'existing changes' in result.stderr
        assert not calls.exists()
        (project / 'README.md').write_text('fixture\n')
        result = run(project)
        assert result.returncode == 0, (result.stdout, result.stderr)
        assert calls.read_text().splitlines() == [f'apply {expected}', f'doctor {expected}']
        result = run(project)
        assert result.returncode == 0, (result.stdout, result.stderr)
        assert calls.read_text().splitlines() == [f'apply {expected}', f'doctor {expected}', f'doctor {expected}']

print('Codex hook: Ponytail default/opt-out, dirty/root guards, completed verification OK')
