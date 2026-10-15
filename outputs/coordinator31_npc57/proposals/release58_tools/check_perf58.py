"""CPU-only checks of paired input identity/view guards. Never probes or launches."""
import copy
import hashlib
import json
from pathlib import Path
import run_perf58 as p


def rejected(call):
    try: call()
    except RuntimeError: return True
    return False


def main():
    manifest = p.ROOT / 'outputs/coordinator31_npc57/extended31/stage58_03/CANDIDATE58.json'
    baseline = p.prepare('baseline57_perf1080_01', 'baseline', manifest, p.DEFAULT_CAMERA)
    candidate = p.prepare('candidate58_perf1080_01', 'candidate', manifest, p.DEFAULT_CAMERA)
    checks = {
        'identical_full_harness_both_roles': baseline['harness'] == candidate['harness'],
        'identical_transitive_controls_both_roles': baseline['controls'] == candidate['controls'],
        'different_exact_source_projects': baseline['game'] == p.PREVIOUS / 'game' and candidate['game'] == p.GAME,
        'both_manifests_pinned_for_both_roles': all(name in baseline['harness'] for name in (
            (p.PREVIOUS / 'ASSEMBLY.json').relative_to(p.ROOT).as_posix(), manifest.relative_to(p.ROOT).as_posix())),
        'f5_control_pinned': 'godot/current_version.json' in baseline['harness'],
        'exact_reference_view_same': baseline['reference'] == candidate['reference'],
        'role_name_mismatch_rejected': rejected(lambda: p.prepare('candidate58_perf1080_wrong', 'baseline', manifest, p.DEFAULT_CAMERA)),
    }
    for value in (baseline, candidate):
        args = value['argv']
        checks['native_90plus20_1080p_' + value['role']] = all(args[args.index(flag) + 1] == expected
            for flag, expected in (('--seconds', '90'), ('--warmup', '20'), ('--resolution', '1920x1080'), ('--mode', 'perf')))
    correct = {'camera': baseline['reference'], 'final_camera': copy.deepcopy(baseline['reference'])}
    checks['full_reference_accepts_exact_view'] = p.full_view_matches(correct, baseline['reference'])
    wrong = copy.deepcopy(correct); wrong['camera']['viewport'] = [1280, 720]
    checks['initial_view_mismatch_rejected'] = not p.full_view_matches(wrong, baseline['reference'])
    wrong = copy.deepcopy(correct); wrong['final_camera']['position'][0] += .01
    checks['final_view_drift_rejected'] = not p.full_view_matches(wrong, baseline['reference'])
    wrong = copy.deepcopy(correct); wrong['camera']['window_protocol']['screen_scale'] = 1.25
    checks['full_window_metadata_mismatch_rejected'] = not p.full_view_matches(wrong, baseline['reference'])
    original_pins = p.pins
    try:
        p.pins = lambda project: {'wrong': 'source'}
        checks['source_drift_rejected_before_probe_or_launch'] = rejected(lambda: p.prepare('candidate58_perf1080_guard', 'candidate', manifest, p.DEFAULT_CAMERA))
    finally: p.pins = original_pins
    result = dict(passed=all(checks.values()), checks=checks, engine_launched=False, probe_called=False,
                  performance_accepted=False, source_counts={'baseline57': len(baseline['baseline']), 'candidate58': len(candidate['expected'])},
                  common_harness_sha256=hashlib.sha256(json.dumps(baseline['harness'], sort_keys=True).encode()).hexdigest(),
                  tool_pins={name: p.sha(p.HERE / name) for name in ('run_perf58.py', 'check_perf58.py', 'validators58.py')})
    p.save(p.HERE / 'PERF_CPU_CHECKS58.json', result)
    print(json.dumps({k: result[k] for k in ('passed', 'source_counts', 'common_harness_sha256', 'engine_launched', 'performance_accepted')}))
    return 0 if result['passed'] else 1


if __name__ == '__main__': raise SystemExit(main())
