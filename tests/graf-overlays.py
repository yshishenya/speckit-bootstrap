"""Exercise the GRAF overlay with the real replacement helper, without network."""
import ast
from pathlib import Path
import tempfile

source = (Path(__file__).resolve().parents[1] / 'bin/speckit-bootstrap').read_text()
helper = source.split('ensure_governed_generated_artifacts() {', 1)[1].split("<<'PY' || return 1\n", 1)[1].split('\nPY\n', 1)[0]
start = helper.index('# Closeout is a separate, evidence-gated lifecycle stage.')
end = helper.index('# Preserve the repository-allocated identity', start)
block = helper[start:end]
setup = helper[:helper.index('invalid_yaml_skip =')]
replacements = [tuple(ast.literal_eval(arg) for arg in node.args[:3])
                for node in ast.walk(ast.parse(block))
                if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                and node.func.id in ('replace', 'replace_graf_workflow')]
assert len(replacements) == 3
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
    workflow_old = next(old for relative, old, _new in replacements if relative.endswith('workflow.yml'))
    workflow.write_text(workflow_old.replace('  version: "1.0.0"\n', '  version: "1.0.1"\n', 1).replace(
        '  scope:\n    type: string\n    default: "full"\n'
        '    enum: ["full", "backend-only", "frontend-only"]\n', '', 1,
    ))
    exec(compile(block, '<GRAF overlays 1.0.5>', 'exec'), scope)
    assert 'speckit.converge' in scope['pending'][workflow]
    assert 'id: tracker-closeout' in scope['pending'][workflow]
    workflow.write_text(scope['pending'][workflow])
    scope['pending'] = {}
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
                  and isinstance(node.args[0], ast.Constant)
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
    assert len(preserved) == 3
    for node in preserved:
        call = node.body[0].value
        relative, old, new = [ast.literal_eval(arg) for arg in call.args]
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        migration = compile(ast.Module(body=[node], type_ignores=[]), '<preserve GRAF>', 'exec')
        if relative == '.agents/skills/speckit-agent-context-update/SKILL.md':
            audited = (Path(__file__).parent / 'fixtures/graf-agent-context-update.md').read_text()
            path.write_text(audited)
            scope['pending'] = {}
            exec(migration, scope)
            assert not scope['pending'], 'audited pointer-only skill must remain byte-identical'
            path.write_text(audited.replace('  author: github-spec-kit\n', '  author: spec-kit-core\n', 1))
            exec(migration, scope)
            assert not scope['pending'], '1.0.6 author metadata must remain byte-identical'
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
    hook_block = helper[helper.index('invalid_yaml_skip ='):helper.index('\nreplace_regex(', helper.index('invalid_yaml_skip ='))]
    exec(compile(hook_block[:hook_block.index('skills =')], '<hook constants>', 'exec'), scope)
    warning = ('If the YAML cannot be parsed or is invalid, do not skip silently: tell the user that '
               '`.specify/extensions.yml` could not be read (include the parser error) and that no hooks '
               'were checked, including any mandatory (`optional: false`) hooks registered there, then continue')
    for message in (
        'If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally',
        warning + ' normally', warning + ' to the Completion Report.',
    ):
        path = root / '.agents/skills/speckit-plan/SKILL.md'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('.specify/extensions.yml\nEXECUTE_COMMAND\n' + message + '\n' + scope['mandatory_hook'] + '\n' + scope['condition_policy'])
        scope['pending'] = {}
        exec(compile(hook_block, '<hook guards>', 'exec'), scope)
        final = scope['pending'][path]
        assert scope['invalid_yaml_guard'] in final and 'then continue' not in final
        path.write_text(final)
        scope['pending'] = {}
        exec(compile(hook_block, '<repeat hook guards>', 'exec'), scope)
        assert not scope['pending']
        path.write_text(final + '\nIf the YAML cannot be parsed or is invalid, use an unknown fallback')
        try:
            exec(compile(hook_block, '<mixed hook guards>', 'exec'), scope)
        except SystemExit as error:
            assert 'upstream hook YAML guard changed' in str(error)
        else:
            raise AssertionError('mixed unknown YAML handling must fail closed')
print('GRAF overlays: PASS (workflow, idempotence, drift, commit policy, 1.0.6 author and hook guards)')

# Numbering has its own fixtures: several migrations share the same file/header.
numbering_start = helper.index('# Preserve the repository-allocated identity')
numbering = helper[numbering_start:helper.index('# Preserve the audited GRAF artifact', numbering_start)]
nodes = ast.parse(numbering).body
calls = []
for node in nodes:
    if isinstance(node, ast.Expr):
        calls.append(node.value)
    elif isinstance(node, ast.If):
        # Suggestions have old-installed and generic forms; start from upstream.
        calls.append((node.orelse or node.body)[0].value)
assert len(calls) == 14
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    initial = {}
    for call in calls:
        relative, old = [ast.literal_eval(arg) for arg in call.args[:2]]
        initial.setdefault(relative, []).append(old)
    for relative, fragments in initial.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        # The longer reservation block already includes the dry-run guard header.
        fragments = [part for part in fragments if not any(part != other and part in other for other in fragments)]
        path.write_text('\n'.join(fragments))
    scope = {}
    previous = sys.argv
    sys.argv = ['graf-overlays.py', str(root)]
    try:
        exec(compile(setup, '<bootstrap helper>', 'exec'), scope)
    finally:
        sys.argv = previous
    exec(compile(numbering, '<numbering>', 'exec'), scope)
    for path, content in scope['pending'].items():
        path.write_text(content)
    scope['pending'] = {}
    exec(compile(numbering, '<repeat numbering>', 'exec'), scope)
    assert not scope['pending'], 'numbering transformations must be idempotent'
    skill = (root / '.agents/skills/speckit-specify/SKILL.md').read_text()
    assert 'same reserved numeric identity' in skill and 'Preserve every field' in skill
    for relative in initial:
        if '/extensions/git/scripts/' in relative:
            text = (root / relative).read_text()
            assert '--check-feature-id' in text and '--allocate' in text
            assert 'feature-numbering.json' in text
    # Every previously generated reservation state migrates, then stays stable.
    for node in nodes:
        if isinstance(node, ast.Expr) and node.value.func.id == 'replace_chain':
            relative, *states = [ast.literal_eval(arg) for arg in node.value.args]
            path = root / relative
            for old in states:
                path.write_text(old)
                scope['pending'] = {}
                scope['replace_chain'](relative, *states)
                assert scope['pending'].get(path, path.read_text()) == states[-1]
            path.write_text('unknown reservation implementation')
            scope['pending'] = {}
            try:
                scope['replace_chain'](relative, *states)
            except SystemExit:
                pass
            else:
                raise AssertionError('unknown reservation implementation was accepted')
print('Numbering overlays: PASS (shared ID, policy guard, reservations, migrations, idempotence)')
