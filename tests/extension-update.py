"""Exercise the real updater adapter without network, input or installed tools."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
bootstrap = root / 'bin/speckit-bootstrap'
source = bootstrap.read_text()
calls = [line.strip() for line in source.splitlines()
         if line.strip().startswith('update_core_extension ')]
assert calls == ['update_core_extension agent-context', 'update_core_extension git'], calls

with tempfile.TemporaryDirectory() as sandbox:
    directory = Path(sandbox)
    cli = directory / 'specify'
    cli.write_text(f'#!{sys.executable}\n')
    cli.chmod(0o755)
    package = directory / 'specify_cli'
    package.mkdir()
    # Stub only external libraries; the actual shell/Python adapter is exercised.
    packaging = directory / 'packaging'
    packaging.mkdir()
    (packaging / '__init__.py').touch()
    (packaging / 'version.py').write_text('def Version(value):\n    return tuple(map(int, value.split(".")))\n')
    (package / 'extensions.py').write_text('''import json, os
from pathlib import Path
class ExtensionCatalog:
    def get_extension_info(self, name):
        info = dict(version='1.0.2', bundled=True,
                    repository='https://github.com/github/spec-kit')
        info.update(json.loads(os.environ['INFO_OVERRIDE']))
        return info
class ExtensionManifest:
    def __init__(self, path):
        assert path.name == 'extension.yml'
        self.version = '1.0.1'
def _locate_bundled_extension(name):
    return Path('/official/bundled')
''')
    (package / '__init__.py').write_text('''import os, sys
from .extensions import ExtensionCatalog

def main():
    assert sys.argv[1:3] == ['extension', 'update'], sys.argv
    info = ExtensionCatalog().get_extension_info(sys.argv[3])
    assert info['version'] == os.environ['EXPECTED_VERSION'], info
    if os.environ['UPDATE_TEST_MODE'] != 'current':
        assert input() == 'y'
        assert sys.stdin.read() == ''
    if os.environ['UPDATE_TEST_MODE'] == 'failure':
        return 23
    print('native update invoked')
''')
    policies = [({}, '1.0.1'),
                ({'version': '1.0.0'}, '1.0.1'),
                ({'_install_allowed': False}, '1.0.2'),
                ({'repository': 'https://example.invalid/other'}, '1.0.2'),
                ({'download_url': 'https://example.invalid/released.zip'}, '1.0.2'),
                ({'bundled': False}, '1.0.2')]
    for call in calls:
        for override, expected in policies:
            for mode, expected_code in [('update', 0), ('current', 0), ('failure', 23)]:
                env = dict(os.environ, PATH=f"{sandbox}:{os.environ['PATH']}",
                           PYTHONPATH=sandbox, UPDATE_TEST_MODE=mode,
                           INFO_OVERRIDE=json.dumps(override), EXPECTED_VERSION=expected)
                for closed_input in (False, True):
                    with subprocess.Popen(
                        ['/bin/bash', '-euo', 'pipefail', '-c',
                         'source "$1"; ' + call, '_', str(bootstrap)], env=env,
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    ) as process:
                        if closed_input:
                            process.stdin.close()
                        try:
                            code = process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()
                            raise AssertionError(f'update waited for caller input: {call}')
                        output = process.stdout.read().decode()
                        error = process.stderr.read().decode()
                        assert code == expected_code, (call, mode, code, output, error)
                        if not override:
                            assert 'latest available bundled release is 1.0.1' in output

print('extension updater: available bundle, catalog policy/source guards, finite input, failures OK')
