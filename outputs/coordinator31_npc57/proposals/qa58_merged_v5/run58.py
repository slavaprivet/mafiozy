"""Bounded ordinary-city run with exact source, transitive harness and binary pins."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import math
import os
import shutil
import re
import statistics
import subprocess
import sys
import time
from archive_harness31 import archive
from audit_spatial_liveness31 import audit as spatial_audit
from audit_routine58 import audit as routine_audit

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
GAME = ROOT / 'outputs/coordinator31_npc57/game'
SCHEDULER_SHA = 'adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def pins(project):
    return {p.relative_to(project).as_posix(): sha(p) for p in project.rglob('*')
            if p.is_file() and '.godot' not in p.relative_to(project).parts}


def drift(before, after):
    return sorted(k for k in set(before) | set(after) if before.get(k) != after.get(k))


def controls(files):
    return {str(p.resolve()): sha(p) if p.is_file() else None for p in files}


def ordinary_flags(assembly, count, extra):
    raw = assembly['launch_arguments']
    need(isinstance(raw, list) and all(isinstance(f, str) for f in raw), 'Invalid ordinary flags')
    result = {}
    forbidden = {'--city-sandbox-seed', '--city-resident-name', '--city-wallet-start',
                 '--city-energy-start', '--city-play-check', '--city-quit-after'}
    for flag in raw:
        key = flag.split('=', 1)[0]
        need('seed' not in key and key not in forbidden, 'Nonordinary base flag: ' + flag)
        need(re.fullmatch(r'--city-[a-z0-9-]+(?:=[^\s\"\';]+)?', flag), 'Invalid city flag')
        need(key not in result, 'Duplicate ordinary city option: ' + key)
        result[key] = flag
    result['--city-qa'] = '--city-qa=' + str(count)
    for flag in extra:
        key = flag.split('=', 1)[0]
        need(re.fullmatch(r'--city-[a-z0-9-]+(?:=[^\s\"\';]+)?', flag), '--extra accepts one city flag')
        need(key not in forbidden | {'--city-qa'} and 'seed' not in key, 'Forbidden QA override: ' + flag)
        # Explicit overrides have one resulting value; never pass ambiguous duplicates.
        result[key] = flag
    required = {'--city-venue-staff29=1', '--city-venue-sites29=1', '--city-hp=100',
                '--city-threat30=1', '--city-physical-dispatch30=1',
                '--city-multi-lifecycle30=1', '--city-simple-hospital=1'}
    need(required.issubset(result.values()), 'Ordinary population behavior was disabled')
    return list(result.values())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    parser.add_argument('--project', type=Path, default=GAME)
    parser.add_argument('--expected-source', type=Path, required=True)
    parser.add_argument('--residents', type=int, default=10, choices=list(range(10, 281, 10)) + [287])
    parser.add_argument('--seconds', type=int, default=1200)
    parser.add_argument('--warmup', type=int, default=30)
    parser.add_argument('--mode', choices=['headless'], default='headless')
    parser.add_argument('--extra', action='append', default=[])
    parser.add_argument('--max-motion-idle', type=float, default=10.0)
    parser.add_argument('--max-queue-idle', type=float, default=30.0)
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080'])
    parser.add_argument('--fixed-camera-from', type=Path, help='Pinned MASS30.json baseline camera')
    parser.add_argument('--slow-motion-threshold', type=float, default=5.0, help='Read-only detailed planner snapshot threshold;0 for diagnostic smoke')
    parser.add_argument('--ordinary-rng', action='store_true', help='Compatibility option; ordinary RNG is always used')
    args = parser.parse_args()
    need(re.fullmatch(r'[A-Za-z0-9_-]+', args.name), 'Use a unique simple run name')
    need(1 <= args.seconds <= 1200 and 0 <= args.warmup <= 120, 'Invalid observation duration')
    need(args.residents == 10, 'Soak31 requires exactly ten original residents')
    need(args.max_motion_idle > 0 and args.max_queue_idle > 0, 'Idle limits must be positive')
    need(0 <= args.slow_motion_threshold <= 600, 'Invalid slow diagnostic threshold')
    game = args.project.resolve()
    need((game / 'project.godot').is_file(), 'Project missing')
    need(game == GAME.resolve(), 'Merged QA requires the owned candidate project')
    need(not args.extra and args.resolution is None and args.fixed_camera_from is None, 'No extra behavior or presentation overrides')
    need(args.max_motion_idle == 10.0 and args.max_queue_idle == 30.0, 'Preserve exact10/30s liveness gates')
    need(shutil.disk_usage(ROOT).free >= 256 * 1024**2, 'Less than256MiB free before launch')
    scheduler = ROOT / 'tools/godot/test_scheduler.py'
    engine_lock = ROOT / 'docs/godot/ENGINE_LOCK.json'
    assembly_path = args.expected_source.resolve()
    engine = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    previous = ROOT / 'outputs/coordinator30_npc54/proposals'
    perf_path = previous / 'perf30/perf_pair30.py'
    harness_files = [Path(__file__), OUT / 'archive_harness31.py', OUT / 'entry_soak31_extended.gd', OUT / 'observer_soak58_v5.gd', OUT / 'observer_soak58_v4.gd', OUT / 'observer_soak31_v3.gd', OUT / 'observer_soak31_v2.gd',
                     OUT / 'observer_mass_extended.gd', OUT / 'observer_perf_extended.gd',
                     perf_path, scheduler, engine_lock, assembly_path]
    harness_files += [OUT / 'audit_routine58.py', OUT / 'audit_spatial_liveness31.py', args.expected_source.resolve()]
    control_files = [*harness_files, engine, ROOT / 'godot/current_version.json']
    camera = None
    if args.fixed_camera_from:
        camera_path = args.fixed_camera_from.resolve()
        camera = read(camera_path)['camera']
        control_files.append(camera_path)
    initial_controls = controls(control_files)
    need(all(initial_controls.values()), 'A transitive harness/control file is missing')
    need(initial_controls[str(scheduler.resolve())] == SCHEDULER_SHA, 'Scheduler source changed')
    engine_sha = initial_controls[str(engine.resolve())]
    need(engine_sha == read(engine_lock)['editor']['gui']['sha256'], 'Engine lock mismatch')
    sys.path.insert(0, str(ROOT))
    from tools.godot.test_scheduler import Lease, probe, ERRORS
    spec = importlib.util.spec_from_file_location('batch_perf56', perf_path)
    perf = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(perf)
    run = OUT / 'runs' / args.name
    flags = ordinary_flags(read(assembly_path), args.residents, args.extra)
    need('--city-player-shop=1' in flags, 'Final combined observer requires real player shop')
    flags += [f'--qa-warmup={args.warmup}', f'--qa-samples={args.seconds}',
              '--qa-expected-staff=12', f'--qa-residents={args.residents}', '--qa-out=' + str(run),
              f'--qa-max-motion-idle={args.max_motion_idle}', f'--qa-max-queue-idle={args.max_queue_idle}']
    flags.append(f'--qa-slow-motion-threshold={args.slow_motion_threshold}')
    command = [str(engine)] + (['--headless'] if args.mode == 'headless' else [])
    if args.resolution:
        command += ['--resolution', args.resolution]
    if camera:
        flags.append('--qa-fixed-camera-json=' + json.dumps(camera, separators=(',', ':')))
    command += ['--path', str(game), '--script', str(OUT / 'entry_soak31_extended.gd'), '--', *flags]
    run.mkdir(parents=True, exist_ok=False)
    harness = {p.relative_to(ROOT).as_posix(): initial_controls[str(p.resolve())] for p in harness_files}
    save(run / 'HARNESS.json', harness)
    save(run / 'CONTROL_PINS.json', initial_controls)
    archive(run)
    record = {'passed': False, 'mode': args.mode, 'performance_accepted': False, 'command': command,
              'requested_residents': args.residents, 'ordinary_rng': True,
              'requested_resolution': args.resolution, 'fixed_camera_from': str(args.fixed_camera_from) if args.fixed_camera_from else None,
              'engine_sha256': engine_sha, 'scheduler_sha256': SCHEDULER_SHA}
    memory = []
    before = {}
    try:
        if args.mode == 'perf':
            inventory = probe('perf', game)
            save(run / 'PROBE.json', inventory)
            need(inventory['eligible_snapshot'], 'Perf not eligible; do not wait on user game')
        with Lease(args.mode, game, 'read', 30) as lease:
            record['lease'] = lease.request
            need(controls(control_files) == initial_controls, 'Harness/control drift before launch')
            before = pins(game)
            expected = read(args.expected_source)
            need(before == expected.get('source_pins', expected), 'Exact reviewed candidate pins mismatch')
            record['candidate_source_matches_reviewed_pins'] = True
            save(run / 'SOURCE.json', before)
            try:
                with (run / 'stdout.log').open('wb') as stdout, (run / 'stderr.log').open('wb') as stderr:
                    process = subprocess.Popen(command, cwd=game, stdout=stdout, stderr=stderr,
                                               creationflags=subprocess.CREATE_NO_WINDOW)
                    try:
                        record['child'] = lease.register_child(process)
                        started = time.monotonic()
                        next_sample = started
                        while process.poll() is None:
                            need(time.monotonic() - started <= args.seconds + args.warmup + 120, 'Owned child bounded timeout')
                            if time.monotonic() >= next_sample:
                                output_bytes = sum(p.stat().st_size for p in run.iterdir() if p.is_file())
                                need(output_bytes <= 100 * 1024**2, 'Owned output exceeds100MiB cap')
                                need(shutil.disk_usage(ROOT).free >= 128 * 1024**2, 'Disk reserve below128MiB')
                                try:
                                    memory.append(perf.sample_memory(process))
                                except OSError:
                                    if process.poll() is None:
                                        raise
                                if args.mode == 'perf':
                                    need(lease.audit_perf(), 'PERF_CONTAMINATED')
                                error = (run / 'stderr.log').read_text(encoding='utf-8', errors='replace')
                                need('SCRIPT ERROR:' not in error and 'Parse Error:' not in error, 'Native script error')
                                next_sample = time.monotonic() + 1
                            time.sleep(.1)
                        record['exit_code'] = process.returncode
                        record['elapsed_seconds'] = time.monotonic() - started
                    finally:
                        if process.poll() is None:
                            process.terminate()
                            process.wait(timeout=10)
            finally:
                after = pins(game)
                after_controls = controls(control_files)
                save(run / 'SOURCE_AFTER.json', after)
                save(run / 'CONTROL_PINS_AFTER.json', after_controls)
                record['source_drift'] = drift(before, after)
                record['control_drift'] = drift(initial_controls, after_controls)
                record['harness_drift'] = [k for k in harness if after_controls.get(str((ROOT / k).resolve())) != harness[k]]
            record['errors'] = [line for name in ('stdout.log', 'stderr.log')
                                for line in (run / name).read_text(encoding='utf-8', errors='replace').splitlines()
                                if ERRORS.search(line)]
            record['stderr_bytes'] = (run / 'stderr.log').stat().st_size
            native = read(run / 'MASS30.json')
            soak = read(run / 'SOAK31.json')
            slow = read(run / 'SLOW_PLANNER31.json')
            spatial = spatial_audit(run / 'SOAK31.json')
            save(run / 'SPATIAL58.json', spatial)
            routine = routine_audit(run / 'SOAK31.json')
            save(run / 'ROUTINE58.json', routine)
            record['routine_liveness_passed'] = routine['passed']
            record['routine_unexplained_idle_failures'] = routine['failures']
            record['spatial_liveness_passed'] = spatial['passed']
            record['spatial_episodes'] = spatial['episodes']
            record['slow_planner_sample_count'] = len(slow['samples'])
            record['slow_planner_max_sample_us'] = slow['max_sample_us']
            record['soak_errors'] = soak['errors']
            record['resident_summaries'] = soak['resident_summaries']
            record['soak_sample_count'] = len(soak['samples'])
            record['physics_sample_count'] = soak['physics_sample_count']
            record['liveness_limits_s'] = {'motion': args.max_motion_idle, 'queue': args.max_queue_idle}
            frames = native['frame_ms']
            need(frames and all(isinstance(x, (int, float)) and math.isfinite(x) and x > 0 for x in frames), 'Invalid frame sample')
            record['native_ok'] = (native.get('ok') is True and not native.get('errors')
                and not soak['errors'] and len(soak['samples']) >= args.seconds - 3
                and soak['physics_sample_count'] == native['frame_count'])
            record['camera'] = native['camera']
            record['resolution_ok'] = (args.resolution is None or args.mode == 'headless'
                or native['camera']['render_size'] == [int(x) for x in args.resolution.split('x')])
            camera_keys = ['position', 'basis', 'fov', 'near', 'far', 'projection']
            record['camera_matches_baseline'] = (camera is None
                or all(native['camera'][key] == camera[key] for key in camera_keys))
            record['frame_ms'] = {f'p{q}': perf.pct(frames, q / 100) for q in (50, 95, 99)}
            record['headless_frame_frequency_descriptive_only'] = 1000 / statistics.mean(frames)
            record['physical_ticks_observed'] = sum(soak['physics_steps_per_render'])
            record['serialization_elapsed_s'] = native['actual_measurement_elapsed_s']
            record['native_frame_elapsed_s'] = native['frame_at_s'][-1]
            record['native_frame_duration_sum_s'] = sum(frames) / 1000.0
            record['actual_measurement_elapsed_s'] = record['native_frame_elapsed_s']
            record['physical_ticks_per_wall_second'] = record['physical_ticks_observed'] / record['native_frame_elapsed_s']
            record['functional_only_not_fps_acceptance'] = True
            record['moved_residents'] = native['moved_residents']
            record['logic_cost'] = native['snapshot'].get('logic_cost', {})
            wanted = sorted(str(row['source_id']) for row in read(game / 'assets/npc_city/session_packet.json')['rows'][:args.residents])
            record['composition_and_movement_ok'] = (native['expected_residents'] == args.residents
                and native['expected_staff'] == 12 and native['actual_ids'] == native['wanted_ids'] == wanted
                and native['moved_residents'] == args.residents
                and all(float(native['travel_metres'].get(key, 0)) > .5 for key in wanted))
            record['perf_environment_clean'] = lease.audit_perf() if args.mode == 'perf' else None
            record['passed'] = (record['exit_code'] == 0 and record['native_ok'] and record['composition_and_movement_ok']
                and record['resolution_ok'] and record['camera_matches_baseline'] and record['spatial_liveness_passed'] and record['routine_liveness_passed']
                and not record['source_drift'] and not record['control_drift'] and not record['harness_drift']
                and not record['errors'] and not record['stderr_bytes'] and record['perf_environment_clean'] is not False)
        # __exit__ performs the final contamination audit; failure must clear PASS.
        if args.mode == 'perf':
            record['perf_environment_clean'] = not lease.perf_contaminated
            record['passed'] = record['passed'] and record['perf_environment_clean']
        record['performance_gate'] = (record['passed'] and args.mode == 'perf'
            and record['mean_fps'] >= 60 and record['frame_ms']['p95'] <= 1000 / 60)
    except Exception as error:
        record.update(passed=False, performance_gate=False, error=str(error))
        if args.mode == 'perf' and 'lease' in locals() and lease.perf_contaminated:
            record['perf_environment_clean'] = False
    finally:
        save(run / 'OS_MEMORY.json', {'samples': memory})
        record['output_bytes_at_terminal'] = sum(p.stat().st_size for p in run.iterdir() if p.is_file())
        record['disk_free_bytes_at_terminal'] = shutil.disk_usage(ROOT).free
        save(run / 'RUN.json', record)
    print(json.dumps({k: v for k, v in record.items() if k not in ('command', 'child', 'lease', 'errors')}, ensure_ascii=True))
    return 0 if record['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
