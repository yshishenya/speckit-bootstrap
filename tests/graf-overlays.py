"""Exercise the GRAF overlay with the real replacement helper, without network."""
import ast
from pathlib import Path
import tempfile

source = (Path(__file__).resolve().parents[1] / 'bin/speckit-bootstrap').read_text()
helper = source.split('ensure_governed_generated_artifacts() {', 1)[1].split("<<'PY' || return 1\n", 1)[1].split('\nPY\n', 1)[0]
start = helper.index('# Closeout is a separate, evidence-gated lifecycle stage.')
end = helper.index('# Preserve the audited GRAF artifact', start)
block = helper[start:end]
setup = helper[:helper.index('invalid_yaml_skip =')]
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
    migrations = [node for node in ast.walk(ast.parse(helper))
                  if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                  and node.func.id == 'replace_variants'
                  and ast.literal_eval(node.args[0]) == '.agents/skills/speckit-git-commit/SKILL.md']
    assert len(migrations) == 2
    for node in migrations:
        relative, *states = [ast.literal_eval(arg) for arg in node.args]
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        for initial in states:
            path.write_text(initial)
            scope['pending'] = {}
            scope['replace_variants'](relative, *states)
            assert scope['pending'].get(path, path.read_text()) == states[-1]
        for unknown in ('unknown commit policy', states[1] + '\n' + states[-1]):
            path.write_text(unknown)
            scope['pending'] = {}
            try:
                scope['replace_variants'](relative, *states)
            except SystemExit:
                pass
            else:
                raise AssertionError('unknown or mixed commit policy must fail closed')
    preserved = [node for node in ast.parse(helper).body
                 if isinstance(node, ast.If)
                 and 'hashlib.sha256(required(' in ast.get_source_segment(helper, node.test)]
    assert len(preserved) == 2
    for node in preserved:
        call = node.body[0].value
        relative, old, new = [ast.literal_eval(arg) for arg in call.args]
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        migration = compile(ast.Module(body=[node], type_ignores=[]), '<preserve GRAF>', 'exec')
        for initial in (old, new):
            path.write_text(initial)
            scope['pending'] = {}
            exec(migration, scope)
            assert scope['pending'].get(path, path.read_text()) == new
        path.write_text('unknown modified artifact')
        scope['pending'] = {}
        try:
            exec(migration, scope)
        except SystemExit:
            pass
        else:
            raise AssertionError('unrecognized fingerprint must not bypass the guard')
print('GRAF overlays: PASS (replacements, generic workflow, idempotence, drift, commit-policy migrations)')
