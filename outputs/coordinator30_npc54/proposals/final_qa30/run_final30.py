"""Read-only final54 native acceptance. No import, source writes or project copies."""
import argparse, hashlib, json, os, pathlib, subprocess, sys, time, zipfile
from accept_cycle14 import accept_cycle

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[3]
GAME = ROOT / 'outputs/coordinator30_npc54/game'
STAFF = OUT.parent / 'staff30'
OLD = ROOT / 'outputs/coordinator29_npc53/proposals'
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease, probe, ERRORS

SCHEDULER_SHA = 'adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        while data := handle.read(1024 * 1024): digest.update(data)
    return digest.hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def save(path, data): path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
def pins(project):
    return {p.relative_to(project).as_posix(): sha(p) for p in project.rglob('*') if p.is_file() and '.godot' not in p.parts}
def drift(a, b): return sorted(k for k in a.keys() | b.keys() if a.get(k) != b.get(k))

def cycle_checks(data, stdout):
    checks = accept_cycle(data, stdout)  # Exact original staff30 acceptance: 14 checks.
    rows = data.get('samples', [])
    composition = data.get('composition30', {})
    kinds = composition.get('activity_kinds', [])
    service = data.get('physical_service_evidence', {})
    checks.update({
        'composition_one_resident_body': bool(rows) and all(x.get('resident_body_count30') == 1 for x in rows),
        'composition_twelve_live_staff': bool(rows) and all(x.get('live_staff30') == 12 for x in rows),
        'composition_eight_new_sites': bool(rows) and all(x.get('new_venue_count30') == 8 for x in rows),
        'composition_eighteen_unique_activities': len(kinds) == len(set(kinds)) == 18 and all(x.get('activity_count30') == 18 for x in rows),
        'new_sites_native_binding': composition.get('new_sites', {}).get('native_binding') is True,
        'staff_placements_without_failures': composition.get('staff_report', {}).get('ok') is True and not composition.get('staff_report', {}).get('failures', ['missing']),
        'hospital_then_bank_then_restaurant': all(k in service for k in ['hospital', 'bank', 'restaurant']) and service['hospital']['frame'] < service['bank']['frame'] < service['restaurant']['frame'],
        'observer_only_no_relocation_or_settlement': data.get('observer_read_only') is True and data.get('observer_relocations') == data.get('observer_settlements') == 0,
    })
    return checks

def definition(name, duration):
    if name == 'cycle':
        flags = read(STAFF / 'runs/cycle03/FLAGS.json')
        flags = [x for x in flags if not x.startswith(('--qa-out=', '--qa-duration='))]
        return OUT / 'staff_cycle_final30.gd', flags + ['--qa-duration=' + str(duration)], duration + 120
    if name == 'staff_world':
        flags = [x for x in read(STAFF / 'runs/fixture01/FLAGS.json') if not x.startswith('--qa-out=')]
        return OLD / 'venues29_staff/qa/staff_world29_fixture.gd', flags, 180
    paths = {
        'service_guard': OUT.parent / 'route30/qa/service_guard30.gd',
        'integration': OLD / 'navigation29_integration/qa/integration_fixture29.gd',
        'daily_policy': OLD / 'navigation29_integration/qa/daily_policy_fixture29.gd',
        'avoidance': OLD / 'navigation29_avoidance/qa/avoidance_fixture29.gd',
        'proxies': OLD / 'navigation29_avoidance/qa/proxies_fixture29.gd',
    }
    return paths[name], [], 120

def semantic_checks(name, semantic, stdout):
    if name == 'cycle': return cycle_checks(semantic, stdout)
    if name == 'staff_world':
        return {'fixture_pass': semantic.get('status') == 'PASS', 'at_least_original_637_checks': semantic.get('checks', 0) >= 637, 'no_failures': not semantic.get('failures', ['missing'])}
    return {'fixture_pass': semantic.get('passed') is True}

def run_case(name, path, script, flags, timeout, pinned, wait):
    path.mkdir()
    native = {'case': name, 'passed': False, 'performance_accepted': False, 'project': str(GAME), 'access': 'read'}
    try:
        admission = probe('headless', GAME, 'read')
        save(path / 'PROBE.json', admission)
        if not admission['eligible_snapshot']: raise RuntimeError('NOT_STARTED: ' + json.dumps(admission))
        with Lease('headless', GAME, 'read', wait) as lease:
            native['lease'] = lease.request
            before = pins(GAME)
            if pinned is None:
                pinned = before
                save(path.parent / 'SOURCE.json', pinned)
            before_drift = drift(pinned, before)
            native['source_drift_before'] = before_drift
            if before_drift: raise RuntimeError('Source changed between final cases; no child started: ' + repr(before_drift))
            result_path = path / 'NATIVE.json'
            engine = pathlib.Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
            assert sha(engine) == read(ROOT / 'docs/godot/ENGINE_LOCK.json')['editor']['gui']['sha256']
            assert sha(script) == FIXTURE_PINS[str(script)], 'External fixture drift'
            command = [str(engine), '--headless', '--path', str(GAME), '--script', str(script), '--', *flags, '--qa-out=' + str(result_path)]
            native['command'] = command
            save(path / 'FLAGS.json', command[command.index('--') + 1:])
            started = time.monotonic()
            try:
                with (path / 'stdout.log').open('wb') as out, (path / 'stderr.log').open('wb') as err:
                    child = subprocess.Popen(command, cwd=GAME, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
                    try:
                        native['child'] = lease.register_child(child)
                        while child.poll() is None:
                            if time.monotonic() - started >= timeout: raise TimeoutError('Exact owned child watchdog deadline')
                            time.sleep(.1)
                    finally:
                        if child.poll() is None: child.terminate(); child.wait(timeout=10)
                    native['exit_code'] = child.returncode
                    native['elapsed_seconds'] = time.monotonic() - started
            finally:
                after = pins(GAME)
                native['source_drift_after'] = drift(pinned, after)
                save(path / 'SOURCE_AFTER.json', after)
            stdout = (path / 'stdout.log').read_text(encoding='utf-8-sig', errors='replace')
            stderr = (path / 'stderr.log').read_text(encoding='utf-8-sig', errors='replace')
            native['stderr_bytes'] = (path / 'stderr.log').stat().st_size
            native['errors'] = [x for text in (stdout, stderr) for x in text.splitlines() if ERRORS.search(x)]
            semantic = read(result_path) if result_path.exists() else {}
            checks = semantic_checks(name, semantic, stdout)
            native['checks'] = checks
            native['native_check_count'] = semantic.get('checks', len(semantic.get('cases', [])))
            if isinstance(native['native_check_count'], list): native['native_check_count'] = len(native['native_check_count'])
            native['passed'] = native['exit_code'] == 0 and not native['errors'] and not native['stderr_bytes'] and not native['source_drift_after'] and bool(checks) and all(checks.values())
    except Exception as error:
        native.update(passed=False, error=type(error).__name__ + ': ' + str(error))
    finally:
        save(path / 'RESULT.json', native)
    return native, pinned

FIXTURE_PINS = {}
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    parser.add_argument('--go', action='store_true', help='Root GO after medic merge/import; required to launch')
    parser.add_argument('--cases', choices=['all', 'cycle', 'relevant'], default='all')
    parser.add_argument('--duration', type=int, default=240)
    parser.add_argument('--wait-seconds', type=int, default=30)
    args = parser.parse_args()
    assert args.name and all(c.isalnum() or c in '-_' for c in args.name)
    assert 120 <= args.duration <= 420
    assert sha(ROOT / 'tools/godot/test_scheduler.py') == SCHEDULER_SHA
    names = ['cycle', 'service_guard', 'integration', 'daily_policy', 'staff_world', 'proxies', 'avoidance']
    if args.cases == 'cycle': names = ['cycle']
    if args.cases == 'relevant': names.remove('cycle')
    sources = [(name, *definition(name, args.duration)) for name in names]
    for _, script, _, _ in sources: FIXTURE_PINS[str(script)] = sha(script)
    if not args.go:
        print(json.dumps({'status': 'PREPARED_WAITING_ROOT_GO', 'project': str(GAME), 'cases': names, 'fixture_pins': FIXTURE_PINS, 'native_launched': False})); return 0
    run = OUT / 'runs' / args.name
    run.mkdir(parents=True, exist_ok=False)
    save(run / 'FIXTURE_PINS.json', FIXTURE_PINS)
    with zipfile.ZipFile(run / 'FIXTURE_SOURCES.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for source, expected in FIXTURE_PINS.items():
            script = pathlib.Path(source); assert sha(script) == expected
            archive.write(script, script.relative_to(ROOT).as_posix())
        for name in ['run_final30.py', 'accept_cycle14.py', 'PROVENANCE.json']: archive.write(OUT / name, 'adapter/' + name)
    results = []; pinned = None
    for name, script, flags, timeout in sources:
        result, pinned = run_case(name, run / name, script, flags, timeout, pinned, args.wait_seconds)
        results.append({'case': name, 'passed': result['passed'], 'checks': result.get('checks', {}), 'error': result.get('error'),
                        'source_drift_before': result.get('source_drift_before'), 'source_drift_after': result.get('source_drift_after')})
        print(json.dumps(results[-1]), flush=True)
        if not result['passed']: break
    summary = {'passed': len(results) == len(names) and all(x['passed'] for x in results), 'cases': results,
               'same_source_pins': bool(pinned) and all(x['source_drift_before'] == [] and x['source_drift_after'] == [] for x in results),
               'source_pin_count': len(pinned or {}), 'project': str(GAME), 'read_leases_only': True,
               'source_sha256': sha(run / 'SOURCE.json') if (run / 'SOURCE.json').exists() else None,
               'fixture_archive_sha256': sha(run / 'FIXTURE_SOURCES.zip'), 'performance_accepted': False,
               'visual_verified': False, 'project_copied': False, 'production_modified': False, 'user_processes_closed': False}
    save(run / 'RESULT.json', summary); print(json.dumps(summary)); return 0 if summary['passed'] else 1

if __name__ == '__main__': sys.exit(main())
