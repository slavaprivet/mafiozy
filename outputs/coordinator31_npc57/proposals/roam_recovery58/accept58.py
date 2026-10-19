"""Read-only integration acceptance of recorded and controlled native proof."""
from pathlib import Path
import hashlib
import json
import math
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
QA = ROOT / 'outputs/coordinator31_npc57/proposals/roam_stall58/runs'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
flat = lambda a, b: math.hypot(a[0]-b[0], a[2]-b[2])


def main():
    checks, evidence, metrics = {}, {}, {}
    manifest = ROOT / 'outputs/coordinator31_npc57/extended31/stage58_03/CANDIDATE58.json'
    expected = read(manifest)['source_pins']
    rel = 'scripts/hospital/npc_simple_hospital.gd'
    patch = read(HERE / 'PATCH.json')[rel]
    checks['patch_matches_exact_stage03'] = expected[rel] == patch['base_sha256']
    checks['candidate_sha_matches_patch'] = sha(HERE / 'patch' / rel) == patch['candidate_sha256']
    runs = {}
    for role, name in [('baseline_obstacle', 'native_obstacle_baseline01'),
                       ('candidate_obstacle', 'native_obstacle_candidate01'),
                       ('baseline_legal', 'native_replay04'),
                       ('candidate_legal', 'native_legal_candidate01')]:
        folder = QA / name
        run, native = read(folder / 'RUN.json'), read(folder / 'NATIVE58.json')
        runs[role] = native
        clean = run['passed'] and run['exit_code'] == 0 and run['stderr_bytes'] == 0
        clean = clean and all(run.get(k) == [] for k in ['source_drift', 'control_drift', 'harness_drift', 'errors'])
        checks[role + '_clean_owned_native'] = clean and bool(run['child']) and bool(run['lease'])
        checks[role + '_exact_source'] = read(folder / 'SOURCE.json') == expected == read(folder / 'SOURCE_AFTER.json')
        checks[role + '_controls_preserved'] = read(folder / 'CONTROL_PINS.json') == read(folder / 'CONTROL_PINS_AFTER.json')
        harness = read(folder / 'HARNESS.json')
        with zipfile.ZipFile(folder / 'HARNESS.zip') as archive:
            archive_ok = set(archive.namelist()) == set(harness)
            archive_ok = archive_ok and all(hashlib.sha256(archive.read(k)).hexdigest() == v for k, v in harness.items())
        checks[role + '_exact_archive'] = archive_ok
        checks[role + '_60hz'] = native['physics_hz'] == 60 and native['time_scale'] == 1 and all(abs(r['delta']-1/60) < 1e-8 for r in native['rows'])
        checks[role + '_native_collision_contract'] = native['contract']['collision_layer'] == '1' and native['contract']['collision_mask'] == '1' and abs(native['contract']['capsule']['radius']-.36) < 1e-6
        evidence[role] = {name: {'path': str((folder / name).relative_to(ROOT)).replace('\\', '/'), 'sha256': sha(folder / name)}
                          for name in ['RUN.json', 'NATIVE58.json', 'SOURCE.json', 'SOURCE_AFTER.json', 'HARNESS.json', 'HARNESS.zip', 'CONTROL_PINS.json', 'CONTROL_PINS_AFTER.json']}
    base, candidate = runs['baseline_obstacle'], runs['candidate_obstacle']
    base_harness, candidate_harness = (read(QA / name / 'HARNESS.json') for name in ['native_obstacle_baseline01', 'native_obstacle_candidate01'])
    checks['paired_obstacle_harness_exact'] = base_harness == candidate_harness
    checks['tested_candidate_byte_exact'] = candidate_harness['candidate_driver58.gd'] == patch['candidate_sha256']
    checks['same_obstacle_geometry'] = all(base['controlled_new_obstacle'][k] == candidate['controlled_new_obstacle'][k] for k in ['position', 'size', 'layer', 'mask'])
    checks['baseline_treadmill_no_replan'] = base['reason'] == 'bounded45s_end' and base['native_physics_frames'] == 2700 and all(r['attempts'] == 0 for r in base['rows'])
    checks['candidate_actual_arrival_under30'] = candidate['reason'] == 'arrived' and candidate['elapsed_s'] < 30 and candidate['rows'][-1]['on_floor'] and flat(candidate['rows'][-1]['after'], candidate['goal']) < .30
    replans = [r for i, r in enumerate(candidate['rows']) if i and r['attempts'] > candidate['rows'][i-1]['attempts']]
    checks['monotonic_guard_really_replanned'] = any(r['last_reason'] == 'roam_waypoint_no_progress58' for r in replans)
    checks['original_goal_preserved'] = base['goal'] == candidate['goal'] and all(r['final_target'] == candidate['goal'] for r in candidate['rows'])
    service = [r['native_diagnostics']['service_us29'] for r in candidate['rows']]
    checks['cumulative_work_never_reset'] = all(b >= a for a, b in zip(service, service[1:])) and service[-1] < 250000
    checks['work_counter_preserved_at_replan'] = all(r['native_diagnostics']['service_us29'] > 0 for r in replans)
    speeds = [flat(r['after'], r['before']) / r['delta'] for r in candidate['rows']]
    checks['native_speed_bound'] = max(speeds) < 1.81
    path = lambda n: next(item['points'] for item in n['paths'] if item['points'])
    legal, old_legal = runs['candidate_legal'], runs['baseline_legal']
    checks['legal_original12point_route_unchanged'] = len(path(legal)) == 12 and path(legal) == path(old_legal) == path(base)
    checks['legal_candidate_arrives_without_replan'] = legal['reason'] == 'arrived' and legal['elapsed_s'] < 5 and all(r['attempts'] == 0 for r in legal['rows'])
    checks['physical_scenario_scope_explicit'] = candidate['natural_failure_reproduction_claimed'] is False and candidate['full_city_acceptance'] is False and candidate['production_source_modified'] is False
    guard_folder = HERE / 'runs/recorded_guard01'
    guard_run, guard = read(guard_folder / 'RUN.json'), read(guard_folder / 'RECORDED_GUARD58.json')
    checks['native_recorded_guard_clean'] = guard_run['passed'] and guard_run['stderr_bytes'] == 0 and not guard_run['errors'] and not guard_run['source_drift'] and not guard_run['control_drift']
    checks.update({'recorded_' + key: value for key, value in guard['checks'].items()})
    for name in ['RUN.json', 'RECORDED_GUARD58.json', 'HARNESS.zip']:
        evidence['recorded_' + name] = {'path': str((guard_folder / name).relative_to(ROOT)).replace('\\', '/'), 'sha256': sha(guard_folder / name)}
    metrics.update(baseline_treadmill_s=base['elapsed_s'], candidate_arrival_s=candidate['elapsed_s'],
                   candidate_physics_frames=candidate['native_physics_frames'], candidate_max_native_speed_mps=max(speeds),
                   candidate_final_service_us=service[-1], candidate_replans=[dict(at_s=r['elapsed_s'], reason=r['last_reason'], work_us=r['native_diagnostics']['service_us29']) for r in replans],
                   legal_candidate_arrival_s=legal['elapsed_s'], recorded_first_guard_s=guard['first_recorded_trigger_after_s'])
    result = dict(schema='mafiozi.roam-recovery58.acceptance/v1', passed=all(checks.values()),
                  ready_for_integration=all(checks.values()), full_city_acceptance=False, performance_accepted=False,
                  production_modified=False, checks=checks, metrics=metrics, evidence=evidence,
                  required_next='Root integrates and stages/smokes this one file. Per latest user direction, defer full natural1200 and release regressions/performance until the logical routines model is merged into the final source.',
                  limitation='The original 761s natural physical cause was not reconstructed: fresh exact scene arrived in3.028s. Recorded data proves the watchdog gap; a controlled new world obstacle proves real stale-route recovery, and the ordinary12point route remains unchanged.')
    with (HERE / 'ACCEPTANCE.json').open('x', encoding='utf-8') as handle:
        json.dump(result, handle, indent=2)
    print(json.dumps(dict(passed=result['passed'], count=len(checks), failed=[k for k, v in checks.items() if not v], metrics=metrics)))


if __name__ == '__main__':
    main()
