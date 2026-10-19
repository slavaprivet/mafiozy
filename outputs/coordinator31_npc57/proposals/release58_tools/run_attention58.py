"""New provenance adapter around the unchanged actual-city31 runner.

Runs the old runner in this Python process so its scheduler/owned-child watchdog
remains authoritative. Original RUN/HARNESS bytes are preserved as *_NATIVE.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import runpy
import sys
import zipfile

from validators58 import ROOT, HERE, GAME, SCHEDULER_SHA, need, read, sha, save, pins, unchanged, city_flags

ATTENTION = ROOT / 'outputs/coordinator31_npc57/proposals/attention31_resume'
RUNNER = ATTENTION / 'run_city31.py'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('name')
    p.add_argument('--kind', choices=('threat', 'visual'), required=True)
    p.add_argument('--expected-source', type=Path, required=True)
    p.add_argument('--go', action='store_true')
    args = p.parse_args()
    need(re.fullmatch(r'merged58_[A-Za-z0-9_-]+', args.name), 'Use a unique merged58_* name')
    manifest = args.expected_source.resolve(); manifest.relative_to(ROOT)
    import_result = manifest.with_name('RESULT.json')
    expected = read(manifest)['source_pins']
    need(read(import_result).get('passed') is True and pins(GAME) == expected, 'Exact staged candidate58 required')
    frozen = ROOT / 'outputs/coordinator31_release57'
    need(read(frozen / 'ASSEMBLY.json')['source_pins'] == read(manifest)['baseline_source_pins'], 'Stage baseline differs from accepted57')
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    scheduler = ROOT / 'tools/godot/test_scheduler.py'; lock = ROOT / 'docs/godot/ENGINE_LOCK.json'
    need(sha(scheduler) == SCHEDULER_SHA and sha(engine) == read(lock)['editor']['gui']['sha256'], 'Engine/scheduler lock mismatch')
    # The unchanged runner derives ordinary flags from56. Verify same57 behavior.
    old_assembly = ROOT / 'outputs/coordinator30_release56/ASSEMBLY.json'
    need(city_flags(['engine', '--', *read(old_assembly)['launch_arguments']]) ==
         city_flags(['engine', '--', *read(frozen / 'ASSEMBLY.json')['launch_arguments']]), 'Historical runner gameplay flags differ from current57')
    out = ATTENTION / 'runs' / args.name
    stage = HERE / 'adapter_runs' / args.name
    need(not out.exists() and not stage.exists(), 'Preserve previous run evidence')
    argv = [str(RUNNER), args.name, '--kind', args.kind, '--game', str(GAME), '--mode', 'graphical', '--go']
    if not args.go:
        print(json.dumps({'prepared': True, 'engine_launched': False, 'runner': str(RUNNER),
                          'argv': argv, 'source_count': len(expected), 'output': str(out)})); return 0
    harness_files = [path for path in ATTENTION.rglob('*') if path.is_file() and 'runs' not in path.parts
                     and path.suffix in ('.py', '.gd', '.json')]
    control_files = set(harness_files + [Path(__file__), HERE / 'validators58.py', manifest, import_result,
        old_assembly, frozen / 'ASSEMBLY.json', ROOT / 'godot/current_version.json', scheduler, lock, engine])
    controls = {str(path.resolve()): sha(path) for path in sorted(control_files)}
    payloads = {path.relative_to(ROOT).as_posix(): path.read_bytes() for path in sorted(control_files) if path != engine}
    harness = {name: hashlib.sha256(data).hexdigest() for name, data in payloads.items()}
    stage.mkdir(parents=True, exist_ok=False)
    save(stage / 'CONTROL_PINS.json', controls)
    with zipfile.ZipFile(stage / 'INPUTS.zip', 'x', zipfile.ZIP_DEFLATED) as z:
        for name, data in payloads.items(): z.writestr(name, data)
    need(unchanged(controls) and pins(GAME) == expected, 'Inputs changed before existing runner')
    original_argv = sys.argv
    adapter_error = None
    try:
        sys.argv = argv
        try: runpy.run_path(str(RUNNER), run_name='__main__')
        except SystemExit as ended:
            if ended.code not in (0, 1, None): adapter_error = 'Unexpected runner exit: ' + str(ended.code)
    except Exception as error:
        adapter_error = type(error).__name__ + ': ' + str(error)
    finally:
        sys.argv = original_argv
    need(out.is_dir(), 'Runner failed before producing its unique directory; see adapter stage')
    raw_run = out / 'RUN.json'
    need(raw_run.is_file(), 'Runner produced no terminal RUN; preserve its evidence')
    raw_run.rename(out / 'RUN_NATIVE.json')
    result = read(out / 'RUN_NATIVE.json')
    native_harness = read(out / 'HARNESS.json')
    raw_harness = {name: payloads.get((ATTENTION / name).relative_to(ROOT).as_posix()) for name in native_harness}
    archive_ok = all(data is not None and hashlib.sha256(data).hexdigest() == native_harness[name]
                     for name, data in raw_harness.items())
    with zipfile.ZipFile(out / 'HARNESS.zip') as z:
        archive_ok = archive_ok and len(z.namelist()) == len(native_harness) and set(z.namelist()) == set(native_harness)
        archive_ok = archive_ok and all(z.read(name) == data for name, data in raw_harness.items())
    (out / 'HARNESS.json').rename(out / 'HARNESS_NATIVE.json')
    (out / 'HARNESS.zip').rename(out / 'HARNESS_NATIVE.zip')
    save(out / 'HARNESS.json', harness)
    with zipfile.ZipFile(out / 'HARNESS.zip', 'x', zipfile.ZIP_DEFLATED) as z:
        for name, data in payloads.items(): z.writestr(name, data)
    save(out / 'CONTROL_PINS.json', controls)
    after_controls = {name: sha(Path(name)) if Path(name).is_file() else None for name in controls}
    save(out / 'CONTROL_PINS_AFTER.json', after_controls)
    source_exact = (out / 'SOURCE.json').is_file() and (out / 'SOURCE_AFTER.json').is_file()
    source_exact = source_exact and read(out / 'SOURCE.json') == read(out / 'SOURCE_AFTER.json') == expected == pins(GAME)
    result.update(mode='graphical', engine_sha256=controls[str(engine.resolve())], scheduler_sha256=SCHEDULER_SHA,
        control_drift=[name for name in controls if controls[name] != after_controls[name]],
        exact_staged_source=bool(source_exact), stage_manifest=str(manifest), stage_manifest_sha256=sha(manifest),
        native_runner_unmodified=True, original_run_sha256=sha(out / 'RUN_NATIVE.json'),
        adapter_source_sha256=sha(Path(__file__)), archived_harness_matches_native=archive_ok,
        performance_accepted=False)
    if adapter_error: result['adapter_error'] = adapter_error
    result['passed'] = bool(result.get('passed') and not adapter_error and source_exact and archive_ok and not result['control_drift'])
    save(out / 'RUN.json', result)
    save(out / 'HARNESS_ARCHIVE.json', {'schema': 'mafiozi.soak31.harness-archive/v1', 'file': 'HARNESS.zip',
        'sha256': sha(out / 'HARNESS.zip'), 'files': harness, 'verified': archive_ok, 'engine_binary_included': False,
        'original_native_archive_sha256': sha(out / 'HARNESS_NATIVE.zip')})
    print(json.dumps({key: result.get(key) for key in ('passed', 'reason', 'exact_staged_source', 'control_drift', 'errors', 'stderr_bytes', 'wall_s')}))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    try: raise SystemExit(main())
    except Exception as error:
        print(json.dumps({'passed': False, 'error': str(error)})); raise SystemExit(1)
