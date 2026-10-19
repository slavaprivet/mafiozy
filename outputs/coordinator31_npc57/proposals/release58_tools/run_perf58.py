"""Dry-run first: exact57/58 paired90+20s rendered measurement via unchanged V4.

No game is ever closed. Both roles pin both manifests, F5, same reference camera
and identical harness. A fresh ineligible perf probe returns before running V4.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import sys
import zipfile

from validators58 import ROOT, HERE, GAME, PREVIOUS, SCHEDULER_SHA, need, read, sha, save, pins, unchanged, city_flags, validate_window_protocol

QA = ROOT / 'outputs/coordinator31_npc57/proposals/qa31_resume'
RUNNER = QA / 'run_soak31_v4.py'
DEFAULT_CAMERA = QA / 'runs/baseline56_perf1080_03/MASS30.json'


def payload_inventory(manifest, camera):
    old = ROOT / 'outputs/coordinator30_npc54/proposals'
    # Exact dependencies declared by unchanged V4 plus the same outer controls in
    # BOTH roles. Role/run names never enter this inventory or alter these bytes.
    files = [RUNNER, QA / 'archive_harness31.py', QA / 'entry_soak31_v4.gd',
        QA / 'observer_soak31_v4.gd', QA / 'observer_soak31_v3.gd', QA / 'observer_soak31_v2.gd',
        old / 'mass30/observer_mass30.gd', old / 'perf30/observer_perf30.gd', old / 'perf30/perf_pair30.py',
        ROOT / 'tools/godot/test_scheduler.py', ROOT / 'docs/godot/ENGINE_LOCK.json',
        ROOT / 'outputs/coordinator30_release56/ASSEMBLY.json', PREVIOUS / 'ASSEMBLY.json',
        manifest, manifest.with_name('RESULT.json'), manifest.with_name('SOURCE_BEFORE.json'),
        manifest.with_name('SOURCE_AFTER.json'), ROOT / 'godot/current_version.json', camera,
        Path(__file__), HERE / 'validators58.py']
    return {path.relative_to(ROOT).as_posix(): path.read_bytes() for path in sorted(set(files))}


def full_view_matches(native, reference):
    return native.get('camera') == native.get('final_camera') == reference


def arguments(name, role, camera):
    game = PREVIOUS / 'game' if role == 'baseline' else GAME
    return [str(RUNNER), name, '--project', str(game), '--residents', '10', '--seconds', '90',
        '--warmup', '20', '--mode', 'perf', '--resolution', '1920x1080', '--fixed-camera-from', str(camera),
        '--max-motion-idle', '10', '--max-queue-idle', '30', '--ordinary-rng']


def prepare(name, role, manifest, camera):
    need(re.fullmatch(r'(?:baseline57|candidate58)_perf1080_[A-Za-z0-9_-]+', name), 'Use unique explicit57/58 perf name')
    need(name.startswith('baseline57_' if role == 'baseline' else 'candidate58_'), 'Run name must match its baseline/candidate role')
    manifest.relative_to(ROOT); camera.relative_to(ROOT)
    expected = read(manifest)['source_pins']; baseline = read(PREVIOUS / 'ASSEMBLY.json')['source_pins']
    need(read(manifest.with_name('RESULT.json')).get('passed') is True, 'Candidate stage not passed')
    need(read(manifest).get('baseline_source_pins') == baseline, 'Candidate baseline is not exact57')
    need(pins(GAME) == expected and pins(PREVIOUS / 'game') == baseline, 'One of the exact pair source inventories changed')
    pointer = read(ROOT / 'godot/current_version.json')
    need(pointer.get('revision') == 's01-20261015-residents57' and
         pointer.get('assembly_sha256') == sha(PREVIOUS / 'ASSEMBLY.json'), 'Preserve current57 during pair')
    old_assembly = ROOT / 'outputs/coordinator30_release56/ASSEMBLY.json'
    need(city_flags(['engine', '--', *read(old_assembly)['launch_arguments']]) ==
         city_flags(['engine', '--', *read(PREVIOUS / 'ASSEMBLY.json')['launch_arguments']]), 'V4 ordinary flags differ from baseline57')
    reference = read(camera)
    need(full_view_matches(reference, reference['camera']), 'Reference view moved during its measurement')
    reference_run = read(camera.with_name('RUN.json')); reference_window = read(camera.with_name('WINDOW31.json'))
    validate_window_protocol(reference_run, reference, reference_window, 'reference-camera')
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    need(sha(ROOT / 'tools/godot/test_scheduler.py') == SCHEDULER_SHA and
         sha(engine) == read(ROOT / 'docs/godot/ENGINE_LOCK.json')['editor']['gui']['sha256'], 'Engine/scheduler lock mismatch')
    payloads = payload_inventory(manifest, camera)
    harness = {name: hashlib.sha256(data).hexdigest() for name, data in payloads.items()}
    controls = {str((ROOT / name).resolve()): digest for name, digest in harness.items()}
    controls[str(engine)] = sha(engine)
    # Pin proof of the reference dimensions too, equally for both roles.
    for path in (camera.with_name('RUN.json'), camera.with_name('WINDOW31.json')):
        data = path.read_bytes(); rel = path.relative_to(ROOT).as_posix()
        payloads[rel] = data; harness[rel] = hashlib.sha256(data).hexdigest(); controls[str(path)] = harness[rel]
    out = QA / 'runs' / name
    stage = HERE / 'perf_adapter_runs' / name
    need(not out.exists() and not stage.exists(), 'Previous measurements are immutable')
    return dict(role=role, expected=expected, baseline=baseline, game=PREVIOUS / 'game' if role == 'baseline' else GAME,
                engine=engine, argv=arguments(name, role, camera), out=out, stage=stage,
                controls=controls, payloads=payloads, harness=harness, reference=reference['camera'])


def run_prepared(value):
    out = value['out']; stage = value['stage']; controls = value['controls']; harness = value['harness']
    need(unchanged(controls) and pins(GAME) == value['expected'] and pins(PREVIOUS / 'game') == value['baseline'], 'Pair inputs changed')
    stage.mkdir(parents=True, exist_ok=False)
    save(stage / 'CONTROL_PINS.json', controls)
    with zipfile.ZipFile(stage / 'INPUTS.zip', 'x', zipfile.ZIP_DEFLATED) as z:
        for name, data in value['payloads'].items(): z.writestr(name, data)
    # Only import the unchanged runner after --go + eligible probe. Its own main
    # performs another fresh probe before authoritative Lease/acquisition/audits.
    old_argv = sys.argv; old_path = list(sys.path)
    error = None
    try:
        sys.path.insert(0, str(QA)); sys.argv = value['argv']
        spec = importlib.util.spec_from_file_location('unchanged_v4_perf58', RUNNER)
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        module.main()
    except Exception as caught: error = type(caught).__name__ + ': ' + str(caught)
    finally: sys.argv = old_argv; sys.path[:] = old_path
    need((out / 'RUN.json').is_file(), 'V4 produced no terminal receipt; preserve adapter stage')
    (out / 'RUN.json').rename(out / 'RUN_NATIVE.json')
    result = read(out / 'RUN_NATIVE.json')
    original = read(out / 'HARNESS.json')
    archive_ok = all(harness.get(name) == digest for name, digest in original.items())
    with zipfile.ZipFile(out / 'HARNESS.zip') as z:
        archive_ok = archive_ok and len(z.namelist()) == len(original) and set(z.namelist()) == set(original)
        archive_ok = archive_ok and all(z.read(name) == value['payloads'].get(name) for name in original)
    for name in ('HARNESS.json', 'HARNESS.zip', 'HARNESS_ARCHIVE.json', 'CONTROL_PINS.json', 'CONTROL_PINS_AFTER.json'):
        path = out / name
        if path.exists(): path.rename(out / (path.stem + '_NATIVE' + path.suffix))
    save(out / 'HARNESS.json', harness)
    with zipfile.ZipFile(out / 'HARNESS.zip', 'x', zipfile.ZIP_DEFLATED) as z:
        for name, data in value['payloads'].items(): z.writestr(name, data)
    save(out / 'CONTROL_PINS.json', controls)
    after = {name: sha(Path(name)) if Path(name).is_file() else None for name in controls}
    save(out / 'CONTROL_PINS_AFTER.json', after)
    expected = value['baseline'] if value['role'] == 'baseline' else value['expected']
    exact = (out / 'SOURCE.json').is_file() and (out / 'SOURCE_AFTER.json').is_file()
    exact = exact and read(out / 'SOURCE.json') == read(out / 'SOURCE_AFTER.json') == expected
    exact = exact and pins(GAME) == value['expected'] and pins(PREVIOUS / 'game') == value['baseline']
    view = False
    if (out / 'MASS30.json').exists() and (out / 'WINDOW31.json').exists():
        native = read(out / 'MASS30.json')
        view = full_view_matches(native, value['reference'])
        try: validate_window_protocol(result, native, read(out / 'WINDOW31.json'), 'perf58')
        except Exception as caught: view = False; error = error or str(caught)
    result.update(control_drift=[name for name in controls if controls[name] != after[name]],
        exact_pair_sources=bool(exact), exact_reference_full_camera=view,
        native_runner_unmodified=True, original_run_sha256=sha(out / 'RUN_NATIVE.json'),
        common_harness_sha256=hashlib.sha256(json.dumps(harness, sort_keys=True).encode()).hexdigest(),
        archived_harness_matches_native=archive_ok, performance_accepted=False)
    if error: result['adapter_error'] = error
    result['passed'] = bool(result.get('passed') and exact and view and archive_ok and not error and not result['control_drift'])
    result['performance_gate'] = bool(result.get('performance_gate') and result['passed'])
    save(out / 'RUN.json', result)
    save(out / 'HARNESS_ARCHIVE.json', {'schema': 'mafiozi.soak31.harness-archive/v1', 'file': 'HARNESS.zip',
        'sha256': sha(out / 'HARNESS.zip'), 'files': harness, 'verified': archive_ok, 'engine_binary_included': False})
    print(json.dumps({key: result.get(key) for key in ('passed', 'exact_pair_sources', 'exact_reference_full_camera',
                      'mean_fps', 'frame_ms', 'control_drift', 'adapter_error', 'performance_accepted')}))
    return 0 if result['passed'] else 1


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('name'); p.add_argument('--role', choices=('baseline', 'candidate'), required=True)
    p.add_argument('--candidate-manifest', type=Path, required=True)
    p.add_argument('--camera', type=Path, default=DEFAULT_CAMERA)
    p.add_argument('--go', action='store_true')
    args = p.parse_args()
    value = prepare(args.name, args.role, args.candidate_manifest.resolve(), args.camera.resolve())
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import probe
    inventory = probe('perf', value['game'], 'read')
    plan = dict(prepared=True, engine_launched=False, argv=value['argv'], probe=inventory,
                common_harness_sha256=hashlib.sha256(json.dumps(value['harness'], sort_keys=True).encode()).hexdigest(),
                source_count=len(value['baseline'] if args.role == 'baseline' else value['expected']),
                exact_reference_view_required=True, performance_accepted=False)
    if not args.go or not inventory['eligible_snapshot']:
        print(json.dumps(plan, ensure_ascii=True))
        return 0 if not args.go else 2
    return run_prepared(value)


if __name__ == '__main__':
    try: raise SystemExit(main())
    except Exception as error:
        print(json.dumps({'passed': False, 'error': str(error), 'performance_accepted': False})); raise SystemExit(1)
