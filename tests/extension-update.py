"""Exercise the real update call sites with a waiting caller and finite input."""

import os
from pathlib import Path
import subprocess
import tempfile


root = Path(__file__).resolve().parents[1]
source = (root / "bin/speckit-bootstrap").read_text()
calls = [line.strip() for line in source.splitlines()
         if line.strip().startswith("specify extension update ")]
assert len(calls) == 2, calls

with tempfile.TemporaryDirectory() as sandbox:
    cli = Path(sandbox) / "specify"
    cli.write_text("""#!/usr/bin/env python3
import os
import sys
assert sys.argv[1:3] == ['extension', 'update'], sys.argv
assert sys.argv[3] in ('agent-context', 'git'), sys.argv
mode = os.environ['UPDATE_TEST_MODE']
if mode != 'current':
    print('Update these extensions? [y/N]:', flush=True)
    assert input() == 'y', 'update must be accepted'
    assert sys.stdin.read() == '', 'only one confirmation may be supplied'
if mode == 'failure':
    sys.exit(23)
print('up to date' if mode == 'current' else 'updated')
""")
    cli.chmod(0o755)
    for call in calls:
        for mode, expected_code in [('update', 0), ('current', 0), ('failure', 23)]:
            env = dict(os.environ, PATH=f"{sandbox}:{os.environ['PATH']}",
                       UPDATE_TEST_MODE=mode)
            for closed_input in (False, True):
                with subprocess.Popen(
                    ['/bin/bash', '-euo', 'pipefail', '-c', call], env=env,
                    stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                ) as process:
                    if closed_input:
                        process.stdin.close()
                    try:
                        # Do not communicate(): the parent's open pipe models
                        # a background setup runner that never sends input.
                        code = process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                        raise AssertionError(f'update waited for caller input: {call}')
                    output = process.stdout.read().decode()
                    error = process.stderr.read().decode()
                    assert code == expected_code, (call, mode, code, output, error)
                    assert ('up to date' if mode == 'current' else
                            'Update these extensions?') in output

print('extension updates: open/closed caller input, no update, failure propagation OK')
