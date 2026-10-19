"""Read-lease shared-city acceptance. Default prepares only; --go starts after root coordination."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import zipfile

from accept_services56 import accept

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease, probe, ERRORS

SCHEDULER_SHA = 'adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'

def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        while data := stream.read(1024 * 1024):
            digest.update(data)
    return digest.hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')

def pins(project):
    return {p.relative_to(project).as_posix(): sha(p) for p in project.rglob('*') if p.is_file() and '.godot' not in p.parts}

def drift(before, after):
    return sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    parser.add_argument('--project', type=Path, default=OUT.parent.parent / 'game')
    parser.add_argument('--flags-json', type=Path, help='Current optimized launch flags array or ASSEMBLY.json')
    parser.add_argument('--mode', choices=['headless', 'graphical'], default='headless')
    parser.add_argument('--seconds', type=int, default=240)
    parser.add_argument('--residents', type=int, choices=list(range(10, 281, 10)), default=10)
    parser.add_argument('--wait-seconds', type=int, default=30)
    parser.add_argument('--go', action='store_true', help='Use only after root exclusive perf finishes')
    args = parser.parse_args()
    assert args.name and all(c.isalnum() or c in '_-' for c in args.name)
    assert 180 <= args.seconds <= 420
    project = args.project.resolve()
    assert (project / 'project.godot').is_file()
    flag_source = args.flags_json or ROOT / 'outputs/coordinator30_release55/ASSEMBLY.json'
    raw_flags = read(flag_source)
    flags = raw_flags['launch_arguments'] if isinstance(raw_flags, dict) else raw_flags
    assert isinstance(flags, list) and all(isinstance(f, str) for f in flags)
    flags = [f for f in flags if not f.startswith(('--qa-', '--city-quit-after=', '--city-resident-name=', '--city-qa='))]
    flags.append('--city-qa=' + str(args.residents))
    required = ['--city-qa=' + str(args.residents), '--city-physical-dispatch30=1', '--city-multi-lifecycle30=1', '--city-simple-hospital=1', '--city-venue-sites29=1', '--city-venue-staff29=1', '--city-hp=100', '--city-threat30=1']
    assert all(f in flags for f in required), 'Full ordinary population/behavior flags must be preserved'
    assert not any(f.startswith(('--city-wallet-start=', '--city-energy-start=')) for f in flags), 'Only three selected local QA initializations are allowed'
    assert len([f for f in flags if f.startswith('--city-qa=')]) == 1
    harness = {p.name: sha(p) for p in OUT.iterdir() if p.is_file() and p.suffix in ('.gd', '.py')}
    assert sha(ROOT / 'tools/godot/test_scheduler.py') == SCHEDULER_SHA
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    assert sha(engine) == read(ROOT / 'docs/godot/ENGINE_LOCK.json')['editor']['gui']['sha256']
    run = OUT / 'runs' / args.name
    command = [str(engine)] + (['--headless'] if args.mode == 'headless' else []) + ['--path', str(project), '--script', str(OUT / 'entry_services56.gd'), '--', *flags, '--qa-duration=' + str(args.seconds), '--qa-residents=' + str(args.residents), '--qa-out=' + str(run)]
    if not args.go:
        print(json.dumps({'status': 'PREPARED_NOT_NATIVE_TESTED', 'engine_launched': False, 'project': str(project), 'command': command, 'harness_pins': harness}, ensure_ascii=True))
        return 0
    run.mkdir(parents=True, exist_ok=False)
    save(run / 'HARNESS_PINS.json', harness)
    save(run / 'FLAGS.json', flags)
    with zipfile.ZipFile(run / 'HARNESS_SOURCES.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, expected in harness.items():
            assert sha(OUT / name) == expected
            archive.write(OUT / name, name)
    record = {'passed': False, 'project': str(project), 'mode': args.mode, 'command': command, 'performance_accepted': False, 'project_copied': False, 'production_modified': False, 'access': 'read', 'requested_residents': args.residents}
    before = {}
    child = None
    try:
        save(run / 'PROBE.json', probe(args.mode, project, 'read'))
        with Lease(args.mode, project, 'read', args.wait_seconds) as lease:
            record['lease'] = lease.request
            before = pins(project)
            save(run / 'SOURCE.json', before)
            started = time.monotonic()
            try:
                with (run / 'stdout.log').open('wb') as out, (run / 'stderr.log').open('wb') as err:
                    child = subprocess.Popen(command, cwd=project, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
                    try:
                        record['child'] = lease.register_child(child)
                        next_error_scan = started
                        while child.poll() is None:
                            if time.monotonic()-started > args.seconds+135:
                                raise TimeoutError('Owned child startup + service watchdog')
                            if time.monotonic() >= next_error_scan:
                                next_error_scan = time.monotonic()+1
                                error = (run / 'stderr.log').read_text(encoding='utf-8', errors='replace')
                                if 'SCRIPT ERROR:' in error or 'Parse Error:' in error:
                                    raise RuntimeError('Native script error; stopping exact owned child')
                            time.sleep(.1)
                    finally:
                        if child.poll() is None:
                            child.terminate()
                            child.wait(timeout=10)
                    record['exit_code'] = child.returncode
                    record['wall_s'] = time.monotonic()-started
            finally:
                after = pins(project)
                save(run / 'SOURCE_AFTER.json', after)
                record['source_drift'] = drift(before, after)
                record['harness_drift'] = [name for name, expected in harness.items() if sha(OUT / name) != expected]
            record['errors'] = [line for name in ['stdout.log', 'stderr.log'] for line in (run / name).read_text(encoding='utf-8-sig', errors='replace').splitlines() if ERRORS.search(line)]
            record['stderr_bytes'] = (run / 'stderr.log').stat().st_size
            native = read(run / 'SERVICES56.json') if (run / 'SERVICES56.json').exists() else {}
            checks = accept(native)
            record['checks'] = checks
            record['failed_checks'] = [key for key, value in checks.items() if not value]
            record['passed'] = record['exit_code'] == 0 and not record['errors'] and not record['stderr_bytes'] and not record['source_drift'] and not record['harness_drift'] and all(checks.values())
    except Exception as error:
        record['error'] = type(error).__name__ + ': ' + str(error)
    finally:
        save(run / 'RUN.json', record)
    print(json.dumps({k: v for k, v in record.items() if k not in ['command', 'child', 'lease']}, ensure_ascii=True))
    return 0 if record['passed'] else 1

if __name__ == '__main__':
    sys.exit(main())
