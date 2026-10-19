"""Compare two completed, exclusive v2 soak runs with the same view/resolution."""
from pathlib import Path
import argparse
import json
import statistics


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def pct(values, q):
    values = sorted(values)
    return values[min(len(values) - 1, int((len(values) - 1) * q))]


def summarize(path):
    run = read(path / 'RUN.json')
    native = read(path / 'MASS30.json')
    duration = native['measurement_seconds']
    early = [x for x, t in zip(native['frame_ms'], native['frame_at_s']) if t < duration / 3]
    late = [x for x, t in zip(native['frame_ms'], native['frame_at_s']) if t >= duration * 2 / 3]
    return {
        'path': str(path), 'passed': run['passed'], 'mode': run['mode'],
        'clean': run.get('perf_environment_clean') is True,
        'camera': native['camera'], 'editors': run['lease']['editor_identities'],
        'seconds': duration, 'warmup': native['warmup_seconds'],
        'mean_fps': 1000 / statistics.mean(native['frame_ms']),
        'p95_ms': pct(native['frame_ms'], .95), 'p99_ms': pct(native['frame_ms'], .99),
        'early_third_p95_ms': pct(early, .95), 'late_third_p95_ms': pct(late, .95),
        'resident_count': native['expected_residents'], 'staff_count': native['expected_staff'],
        'movement_count': native['moved_residents'], 'soak_errors': run['soak_errors'],
        'harness': read(path / 'HARNESS.json'),
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('baseline', type=Path)
    p.add_argument('candidate', type=Path)
    args = p.parse_args()
    base, candidate = (summarize(path.resolve()) for path in (args.baseline, args.candidate))
    gates = {
        'both_native_and_liveness_passed': base['passed'] and candidate['passed'],
        'both_exclusive_perf': all(x['mode'] == 'perf' and x['clean'] for x in (base, candidate)),
        'same_camera_and_resolution': base['camera'] == candidate['camera'],
        'same_harness': base['harness'] == candidate['harness'],
        'same_editor_environment': base['editors'] == candidate['editors'],
        'same_timing': base['seconds'] == candidate['seconds'] and base['warmup'] == candidate['warmup'],
        'both_ten_residents_and_twelve_staff': all(x['resident_count'] == x['movement_count'] == 10 and x['staff_count'] == 12 for x in (base, candidate)),
        'p95_no_material_regression': candidate['p95_ms'] <= max(base['p95_ms'] * 1.10, base['p95_ms'] + 1.0),
        'p99_no_material_regression': candidate['p99_ms'] <= max(base['p99_ms'] * 1.15, base['p99_ms'] + 2.0),
        'p95_within_60fps_budget': candidate['p95_ms'] <= 1000 / 60,
        'mean_fps_preserved': candidate['mean_fps'] >= max(60, base['mean_fps'] * .90),
        'no_material_late_slowdown': candidate['late_third_p95_ms'] <= max(candidate['early_third_p95_ms'] * 1.15, candidate['early_third_p95_ms'] + 2.0),
    }
    result = {'schema': 'mafiozi.soak31.perf-pair/v1', 'baseline': base, 'candidate': candidate,
              'gates': gates, 'measured_timing_gates_passed': all(gates.values()),
              'performance_accepted': False,
              'limitations': 'Natural RNG, fixed matched camera. Review ANALYSIS.json memory trends and behavior coverage separately; this finite pair does not establish absence of leaks or all service scenarios.'}
    output = args.candidate.resolve() / 'PERF_COMPARISON.json'
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'output': str(output), 'measured_timing_gates_passed': result['measured_timing_gates_passed'], 'gates': gates}, ensure_ascii=True))


if __name__ == '__main__':
    main()
