"""Exercise the GRAF overlay with the real replacement helper, without network."""
import ast
from pathlib import Path
import tempfile

source = (Path(__file__).resolve().parents[1] / 'bin/speckit-bootstrap').read_text()
helper = source.split('ensure_governed_generated_artifacts() {', 1)[1].split("<<'PY' || return 1\n", 1)[1].split('\nPY\n', 1)[0]
start = helper.index('# Closeout is a separate, evidence-gated lifecycle stage.')
end = helper.index('replace(\n    ".specify/extensions/agent-context/scripts/powershell/update-agent-context.ps1",', start)
block = helper[start:end]
setup = helper[:helper.index('def replace_chain(')]
replacements = [tuple(ast.literal_eval(arg) for arg in node.args[:3])
                for node in ast.walk(ast.parse(block))
                if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                and node.func.id == 'replace']
assert len(replacements) == 6
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    for relative, old, _new in replacements:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(old)
    scope = {}
    # Use the actual helper prelude with an isolated project argument.
    import sys
    previous = sys.argv
    sys.argv = ['graf-overlays.py', str(root)]
    try:
        exec(compile(setup, '<bootstrap helper>', 'exec'), scope)
    finally:
        sys.argv = previous
    exec(compile(block, '<GRAF overlays>', 'exec'), scope)
    workflow = root / '.specify/workflows/speckit/workflow.yml'
    assert workflow not in scope['pending'], 'generic workflow must be preserved'
    (root / 'scripts').mkdir()
    (root / 'scripts/validate-issue-closeout.py').touch()
    exec(compile(block, '<GRAF overlays>', 'exec'), scope)
    for relative, _old, new in replacements:
        assert scope['pending'][root / relative] == new
    for path, content in scope['pending'].items():
        path.write_text(content)
    scope['pending'] = {}
    exec(compile(block, '<GRAF overlays>', 'exec'), scope)
    assert not scope['pending'], 'second application must make no changes'
    path = root / replacements[0][0]
    path.write_text('unknown upstream state')
    try:
        exec(compile(block, '<GRAF overlays>', 'exec'), scope)
    except SystemExit as error:
        assert 'upstream artifact changed' in str(error)
    else:
        raise AssertionError('unknown upstream state must fail closed')
print('GRAF overlays: PASS (six replacements, generic workflow, idempotence, drift)')
