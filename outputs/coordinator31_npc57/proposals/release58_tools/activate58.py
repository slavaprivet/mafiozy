"""Root-only pointer activation after exact startup58; default read-only.

Does not launch, restart or close any game. Ordinary visible delivery remains a
separate root action with fresh process identity and its own native ready proof.
"""
from pathlib import Path
import argparse
from datetime import datetime, timezone
import json

from validators58 import ROOT, HERE, RELEASE, REVISION, need, read, sha, save, pins, inside, unchanged
from startup58 import validate_release


def validate(startup):
    startup = inside(startup)
    startup.relative_to(HERE / 'runs')
    proposed, assembly, bootstrap, game, expected, wanted = validate_release(RELEASE)
    result = read(startup / 'RUN.json')
    need(result.get('passed') is True and result.get('ordinary_ready') is True, 'Exact startup58 must pass')
    need(result.get('resident_count') == 10 and result.get('staff_count') == 12 and result.get('revision') == REVISION,
         'Startup cohort/revision mismatch')
    need(result.get('source_drift') == result.get('control_drift') == result.get('errors') == [] and
         result.get('stderr_bytes') == 0 and result.get('exit_code') == 0 and not result.get('error'), 'Startup not clean')
    need(result.get('checks') and all(value is True for value in result['checks'].values()), 'Startup checks incomplete')
    need(sha(startup / 'CURRENT_READY.json') == result.get('native_sha256'), 'Native ready evidence changed')
    ready = read(startup / 'CURRENT_READY.json')
    need(ready.get('ok') is True and ready.get('actual_revision') == ready.get('revision') == REVISION and
         ready.get('actual_ids') == wanted and ready.get('staff_count') == 12, 'Native ready identity/cohort mismatch')
    controls = read(startup / 'CONTROL_PINS.json')
    need(controls == read(startup / 'CONTROL_PINS_AFTER.json') and unchanged(controls), 'Startup control drift')
    for path in (Path(__file__), HERE / 'startup58.py', HERE / 'freeze58.py', HERE / 'validators58.py',
                 RELEASE / 'PREVIOUS_CURRENT.json', RELEASE / 'PROPOSED_CURRENT.json', bootstrap,
                 RELEASE / 'ASSEMBLY.json', RELEASE / 'ACCEPTANCE.json'):
        need(controls.get(str(path.resolve())) == sha(path), 'Startup missing required control pin: ' + str(path))
    need(expected == read(startup / 'SOURCE.json') == read(startup / 'SOURCE_AFTER.json') == pins(game), 'Exact startup source mismatch')
    command = result.get('command', [])
    need(command.count('--path') == command.count('--script') == 1 and
         Path(command[command.index('--path') + 1]).resolve() == game and
         Path(command[command.index('--script') + 1]).resolve() == bootstrap,
         'Startup ran an unexpected project/bootstrap')
    need(result.get('child', {}).get('command') == command, 'Registered startup child missing')
    pointer = ROOT / 'godot/current_version.json'
    need(read(pointer) == read(RELEASE / 'PREVIOUS_CURRENT.json') and read(pointer).get('revision') == 's01-20261015-residents57',
         'Current pointer is no longer preserved57')
    need((startup / 'stderr.log').stat().st_size == 0, 'Startup stderr changed')
    return dict(validated=True, activated=False, revision=REVISION,
                startup_run=str(startup.relative_to(ROOT)), startup_sha256=sha(startup / 'RUN.json'),
                old_pointer_sha256=sha(pointer), new_pointer_sha256=sha(RELEASE / 'PROPOSED_CURRENT.json'),
                engine_launched=False, game_processes_modified=False)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('startup_run', type=Path)
    p.add_argument('--go', action='store_true', help='Root only: atomically update pointer, never restart game')
    args = p.parse_args(); value = validate(args.startup_run)
    if args.go:
        output = HERE / 'ACTIVATION58.json'; need(not output.exists(), 'Preserve previous activation receipt')
        pointer = ROOT / 'godot/current_version.json'
        proposed = RELEASE / 'PROPOSED_CURRENT.json'
        temporary = pointer.with_name('current_version.prepared58.json')
        need(not temporary.exists(), 'Preserve existing prepared pointer; root must inspect it')
        with temporary.open('xb') as stream: stream.write(proposed.read_bytes())
        need(sha(pointer) == value['old_pointer_sha256'] and sha(temporary) == value['new_pointer_sha256'], 'Pointer changed before activation')
        temporary.replace(pointer)
        need(sha(pointer) == value['new_pointer_sha256'], 'Pointer activation verification failed')
        value.update(activated=True, utc=datetime.now(timezone.utc).isoformat())
        with output.open('x', encoding='utf-8') as stream:
            stream.write(json.dumps(value, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps(value, ensure_ascii=True)); return 0


if __name__ == '__main__':
    try: raise SystemExit(main())
    except Exception as error:
        print(json.dumps({'passed': False, 'error': str(error), 'engine_launched': False})); raise SystemExit(1)
