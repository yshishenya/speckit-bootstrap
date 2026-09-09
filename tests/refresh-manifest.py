"""Run the real refresh guard against tiny local projects; no network or CLI install."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

bootstrap = Path(__file__).resolve().parents[1] / 'bin/speckit-bootstrap'
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    skill = root / '.agents/skills/speckit-plan/SKILL.md'
    skill.parent.mkdir(parents=True)
    skill.write_text('known bootstrap overlay\n')
    manifest = root / '.specify/integrations/codex.manifest.json'
    manifest.parent.mkdir(parents=True)
    tracked = '.agents/skills/speckit-plan/SKILL.md'
    original = {'integration': 'codex', 'version': '1.0.1', 'files': {tracked: '0' * 64}}
    manifest.write_text(json.dumps(original))
    shared = root / '.specify/scripts/bash/common.sh'
    shared.parent.mkdir(parents=True)
    shared.write_text('project-owned allocator\n')

    def shell(command, *, frozen='0'):
        return subprocess.run(
            ['bash', '-c', 'source "$1"; PROJECT_DIR="$2"; FROZEN="$3"; ' + command,
             '_', str(bootstrap), str(root), frozen], text=True, capture_output=True,
            env={**os.environ, 'SPECKIT_PONYTAIL': '0'},
        )

    captured = shell('capture_project_skills_state; printf "%s" "$RESOLVED_PROJECT_SKILLS_MANIFEST"')
    assert captured.returncode == 0, captured.stderr
    lock = root / '.specify/speckit-bootstrap.lock.json'
    lock.write_text(json.dumps({'schema_version': 3, 'project_skills': json.loads(captured.stdout)}))
    baseline_lock = lock.read_bytes()
    result = shell('prepare_codex_skill_refresh')
    assert result.returncode == 0, result.stderr
    updated = json.loads(manifest.read_text())
    assert updated == {**original, 'files': {tracked: hashlib.sha256(skill.read_bytes()).hexdigest()}}
    assert shared.read_text() == 'project-owned allocator\n'
    assert lock.read_bytes() == baseline_lock
    baseline = manifest.read_bytes()
    assert shell('prepare_codex_skill_refresh').returncode == 0
    assert manifest.read_bytes() == baseline

    skill.write_text('user edit\n')
    result = shell('prepare_codex_skill_refresh')
    assert result.returncode != 0 and 'skill drift' in result.stderr
    assert manifest.read_bytes() == baseline and skill.read_text() == 'user edit\n'
    skill.write_text('known bootstrap overlay\n')
    for invalid in (
        {**original, 'files': {'../outside': '0' * 64}},
        {**original, 'files': {'.specify/scripts/bash/common.sh': '0' * 64}},
        {**original, 'files': {'.agents/skills/speckit-unowned/SKILL.md': '0' * 64}},
        {**original, 'files': {}}, [],
    ):
        manifest.write_text(json.dumps(invalid))
        before = manifest.read_bytes()
        assert shell('prepare_codex_skill_refresh').returncode != 0
        assert manifest.read_bytes() == before
    manifest.write_text(json.dumps(original))
    assert shell('prepare_codex_skill_refresh', frozen='1').returncode == 0
    assert json.loads(manifest.read_text()) == original
    manifest.unlink()
    outside = root / 'outside.json'
    outside.write_text(json.dumps(original))
    manifest.symlink_to(outside)
    assert shell('prepare_codex_skill_refresh').returncode != 0
    assert json.loads(outside.read_text()) == original
    manifest.unlink()
    assert shell('prepare_codex_skill_refresh').returncode == 0
print('Refresh manifest: PASS (known overlays, drift, ownership, symlink, idempotence, frozen)')
