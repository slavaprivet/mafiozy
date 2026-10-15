"""Run only the recorded-data GDScript guard test, with a registered owned child."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
save = lambda p, v: p.write_text(json.dumps(v, indent=2) + '\n', encoding='utf-8')


def pins(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in folder.rglob('*')
            if p.is_file() and '.godot' not in p.parts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    args = parser.parse_args()
    assert args.name and all(c.isalnum() or c in '_-' for c in args.name)
    game = ROOT / 'outputs/coordinator31_npc57/game'
    manifest = ROOT / 'outputs/coordinator31_npc57/extended31/stage58_03/CANDIDATE58.json'
    assert sha(manifest) == '46a095bd14fdede78861d097cd5e69ad73a32c6cdf842b6944375101e84155a7'
    expected = read(manifest)['source_pins']
    assert pins(game) == expected
    rel = 'scripts/hospital/npc_simple_hospital.gd'
    patch = read(HERE / 'PATCH.json')[rel]
    candidate = HERE / 'patch' / rel
    assert sha(game / rel) == patch['base_sha256'] and sha(candidate) == patch['candidate_sha256']
    # Bind the recorded method proof to the actual changed invocation scope.
    old, new = (game / rel).read_text(encoding='utf-8-sig'), candidate.read_text(encoding='utf-8-sig')
    assert '_target_source in ["service_approach", "roam"] and _service_waypoint_stalled56' not in old
    assert new.count('_target_source in ["service_approach", "roam"] and _service_waypoint_stalled56') == 1
    assert new.count('_target_source == "roam" and _service_waypoint_stalled56') == 1
    scheduler = ROOT / 'tools/godot/test_scheduler.py'
    assert sha(scheduler) == 'adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
    lock = ROOT / 'docs/godot/ENGINE_LOCK.json'
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    assert sha(engine) == read(lock)['editor']['gui']['sha256']
    trace = read(HERE / 'RECORDED_INPUT58.json')
    assert sha(ROOT / trace['source']) == trace['source_sha256']
    payloads = [HERE / name for name in ['entry_guard58.gd', 'run_guard58.py', 'RECORDED_INPUT58.json', 'PATCH.json']]
    payloads.append(candidate)
    controls_files = [manifest, scheduler, lock, ROOT / 'godot/current_version.json', *payloads]
    controls = {str(p.resolve()): sha(p) for p in controls_files}
    run = HERE / 'runs' / args.name
    run.mkdir(parents=True, exist_ok=False)
    save(run / 'CONTROL_PINS.json', controls)
    save(run / 'HARNESS.json', {str(p.relative_to(HERE)): sha(p) for p in payloads})
    with zipfile.ZipFile(run / 'HARNESS.zip', 'x', zipfile.ZIP_DEFLATED) as archive:
        for path in controls_files:
            archive.write(path, path.relative_to(ROOT).as_posix())
    command = [str(engine), '--headless', '--path', str(game), '--script', str(HERE / 'entry_guard58.gd'), '--',
               '--candidate=' + str(candidate), '--trace=' + str(HERE / 'RECORDED_INPUT58.json'),
               '--out=' + str(run / 'RECORDED_GUARD58.json')]
    record = dict(passed=False, physics_simulation=False, performance_accepted=False,
                  production_modified=False, command=command, engine_sha256=sha(engine),
                  manifest_sha256=sha(manifest), scheduler_sha256=sha(scheduler))
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import Lease, probe, ERRORS
    try:
        save(run / 'PROBE.json', probe('headless', game, 'read'))
        with Lease('headless', game, 'read', 60) as lease:
            record['lease'] = lease.request
            assert pins(game) == expected and controls == {str(p.resolve()): sha(p) for p in controls_files}
            save(run / 'SOURCE.json', expected)
            start = time.monotonic()
            with (run / 'stdout.log').open('wb') as out, (run / 'stderr.log').open('wb') as err:
                child = subprocess.Popen(command, cwd=game, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    record['child'] = lease.register_child(child)
                    child.wait(timeout=45)
                finally:
                    if child.poll() is None:
                        child.terminate()
                        child.wait(timeout=10)
            record['exit_code'] = child.returncode
            record['wall_s'] = time.monotonic() - start
            after = pins(game)
            save(run / 'SOURCE_AFTER.json', after)
            record['source_drift'] = [k for k in expected.keys() | after.keys() if expected.get(k) != after.get(k)]
            after_controls = {str(p.resolve()): sha(p) for p in controls_files}
            save(run / 'CONTROL_PINS_AFTER.json', after_controls)
            record['control_drift'] = [k for k in controls if controls[k] != after_controls.get(k)]
            record['errors'] = [line for name in ['stdout.log', 'stderr.log']
                                for line in (run / name).read_text(encoding='utf-8-sig', errors='replace').splitlines()
                                if ERRORS.search(line)]
            record['stderr_bytes'] = (run / 'stderr.log').stat().st_size
            native = read(run / 'RECORDED_GUARD58.json')
            record['passed'] = native['passed'] and child.returncode == 0 and not record['source_drift'] and not record['control_drift'] and not record['errors'] and not record['stderr_bytes']
    except Exception as exc:
        record['error'] = type(exc).__name__ + ': ' + str(exc)
    finally:
        if not (run / 'SOURCE_AFTER.json').exists():
            save(run / 'SOURCE_AFTER.json', pins(game))
        save(run / 'RUN.json', record)
    print(json.dumps({k: v for k, v in record.items() if k not in ['command', 'lease', 'child']}))
    return 0 if record['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
