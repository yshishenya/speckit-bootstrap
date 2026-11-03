"""Real CLI update from stale registry entries, with no caller input."""

import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


root = Path(__file__).resolve().parents[1]
source = (root / "bin/speckit-bootstrap").read_text()
calls = [line.strip() for line in source.splitlines()
         if line.strip().startswith("update_core_extension ")]
assert len(calls) == 2

with tempfile.TemporaryDirectory() as sandbox:
    project = Path(sandbox) / 'project'
    shutil.copytree(sys.argv[1], project)
    registry_path = project / '.specify/extensions/.registry'
    registry = json.loads(registry_path.read_text())
    versions = {name: registry['extensions'][name]['version'] for name in ('agent-context', 'git')}
    configs = {}
    for name in ('agent-context', 'git'):
        config = project / f'.specify/extensions/{name}/{name}-config.yml'
        configs[config] = config.read_bytes()
    # Both core extensions must actually update, including the bundled git
    # release below the catalog's currently unavailable announcement.
    registry['extensions']['agent-context']['version'] = '0.0.0'
    registry['extensions']['git']['version'] = '1.0.0' if versions['git'] != '1.0.0' else '0.0.0'
    registry_path.write_text(json.dumps(registry))
    # A file avoids filling stdout's pipe while the parent keeps stdin open.
    with tempfile.TemporaryFile() as log:
        with subprocess.Popen(
            ['/bin/bash', '-euo', 'pipefail', '-c', 'source "$1"; ' + '\n'.join(calls), '_', str(root / 'bin/speckit-bootstrap')],
            cwd=project, stdin=subprocess.PIPE, stdout=log,
            stderr=subprocess.STDOUT,
        ) as process:
            try:
                code = process.wait(timeout=120)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                raise AssertionError('real extension update timed out without user input')
        log.seek(0)
        output = log.read().decode()
        assert code == 0, output
    updated = json.loads(registry_path.read_text())
    for name in ('agent-context', 'git'):
        assert updated['extensions'][name]['version'] == versions[name], output
    for config, previous in configs.items():
        assert config.read_bytes() == previous, f'configuration changed: {config.name}'

print('real extension updates installed without caller input; configurations preserved')
