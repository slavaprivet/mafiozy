"""Atomically activate the frozen release only after its exact bootstrap has passed."""
from pathlib import Path
import argparse
import hashlib
import json
from datetime import datetime, timezone

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RELEASE = ROOT / 'outputs/coordinator31_release57'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('startup_run', type=Path)
    parser.add_argument('--go', action='store_true')
    args = parser.parse_args()
    startup = args.startup_run.resolve()
    assert startup.is_relative_to(HERE / 'proposals/services31_resume/release_tools/runs')
    result = read(startup / 'RUN.json')
    assert result['passed'] is True and result['ordinary_ready'] is True
    assert result['resident_count'] == 10 and result['staff_count'] == 12
    assert result['revision'] == 's01-20261015-residents57'
    assert result['source_drift'] == result['control_drift'] == result['errors'] == []
    assert result['stderr_bytes'] == 0 and result['exit_code'] == 0
    controls = read(startup / 'CONTROL_PINS.json')
    assert controls == read(startup / 'CONTROL_PINS_AFTER.json')
    assert all(Path(name).is_file() and sha(Path(name)) == digest for name, digest in controls.items())
    assert sha(startup / 'CURRENT_READY.json') == result['native_sha256']
    pointer = ROOT / 'godot/current_version.json'
    old_sha = sha(pointer)
    assert read(pointer) == read(RELEASE / 'PREVIOUS_CURRENT.json')
    proposed_path = RELEASE / 'PROPOSED_CURRENT.json'
    proposed = read(proposed_path)
    assert proposed['assembly'] == 'outputs/coordinator31_release57/ASSEMBLY.json'
    assert proposed['bootstrap'] == 'outputs/coordinator31_release57/bootstrap_play57.gd'
    assert proposed['revision'] == result['revision']
    assert sha(ROOT / proposed['assembly']) == proposed['assembly_sha256']
    assert sha(ROOT / proposed['bootstrap']) == proposed['bootstrap_sha256']
    manifest = read(ROOT / proposed['assembly'])
    expected = manifest['source_pins']
    assert expected == read(startup / 'SOURCE.json') == read(startup / 'SOURCE_AFTER.json')
    game = RELEASE / 'game'
    actual = {path.relative_to(game).as_posix(): sha(path) for path in game.rglob('*')
              if path.is_file() and '.godot' not in path.relative_to(game).parts}
    assert actual == expected
    value = {'validated': True, 'activated': False, 'revision': proposed['revision'],
             'startup_run': str(startup.relative_to(ROOT)), 'startup_sha256': sha(startup / 'RUN.json'),
             'old_pointer_sha256': old_sha, 'new_pointer_sha256': sha(proposed_path)}
    if args.go:
        output = HERE / 'ACTIVATION57.json'
        assert not output.exists()
        temporary = pointer.with_name('current_version.prepared57.json')
        with temporary.open('xb') as stream:
            stream.write(proposed_path.read_bytes())
        assert sha(pointer) == old_sha and sha(temporary) == sha(proposed_path)
        temporary.replace(pointer)
        assert read(pointer) == proposed
        value.update(activated=True, utc=datetime.now(timezone.utc).isoformat())
        output.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(value, ensure_ascii=True))
