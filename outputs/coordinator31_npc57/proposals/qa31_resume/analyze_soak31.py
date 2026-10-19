"""Summarize observational soak evidence without modifying native evidence files."""
from pathlib import Path
import argparse
from collections import Counter
import hashlib
import json
import statistics


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def trend(rows, key):
    values = [float(r[key]) for r in rows if key in r]
    if not values:
        return {}
    size = max(1, len(values) // 4)
    quarters = [values[i * size:(i + 1) * size] for i in range(3)] + [values[3 * size:]]
    medians = [statistics.median(q) for q in quarters if q]
    return {'first': values[0], 'last': values[-1], 'min': min(values), 'max': max(values),
            'median': statistics.median(values), 'quarter_medians': medians,
            'last_minus_first_quarter_median': medians[-1] - medians[0]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    args = parser.parse_args()
    run = args.run.resolve()
    mass = read(run / 'MASS30.json')
    soak = read(run / 'SOAK31.json')
    receipt = read(run / 'RUN.json')
    native = [r for r in mass['samples'] if r['measure_ms'] >= 0]
    memory = [r for r in read(run / 'OS_MEMORY.json')['samples']
              if mass['measurement_start_unix_ms'] <= r['unix_ms'] <= mass['measurement_end_unix_ms']]
    event_counts = Counter()
    for line in (run / 'stdout.log').read_text(encoding='utf-8', errors='replace').splitlines():
        if line.startswith('SOAK31_LIVE '):
            continue
        for name in ('exit_blocked', 'exit_retry', 'service_planning_work_limit30',
                     'service_local_wait_limit30', 'service_motion_stalled30'):
            if name in line:
                event_counts[name] += 1
    summaries = []
    for summary in soak['resident_summaries']:
        rows = [actor for sample in soak['samples'] for actor in sample['actors'][:sample['count']]
                if actor['id'] == summary['id'] and actor['generation'] == summary['generation']]
        idle = max(rows, key=lambda r: r['motion_idle_s']) if rows else {}
        raw_idle = max(rows, key=lambda r: r['no_progress_s']) if rows else {}
        queue_idle = max(rows, key=lambda r: r['queue_idle_s']) if rows else {}
        completed = {key: max(r['completed'].get(key, 0) for r in rows) - rows[0]['completed'].get(key, 0)
                     for key in rows[-1]['completed']} if rows else {}
        summaries.append({**summary, 'travel_m': mass['travel_metres'].get(summary['id'], 0),
                          'completion_deltas_within_measurement': completed,
                          'worst_motion_idle_state': idle,
                          'worst_raw_idle_state': raw_idle, 'worst_queue_idle_state': queue_idle,
                          'required_motion_max_physics_lag_frames': max((r.get('physics_lag_frames', 0) for r in rows if r['required_motion']), default=0),
                          'threat_phase_samples': dict(Counter(r.get('threat', {}).get('phase', 'unobserved_v1') for r in rows)),
                          'observed_outer_phases': dict(Counter(r['outer_phase'] for r in rows)),
                          'observed_venues': dict(Counter(r['venue'] for r in rows if r['venue']))})
    frames = mass['frame_ms']
    steps = soak['physics_steps_per_render']
    report = {
        'schema': 'mafiozi.soak31.analysis/v1', 'run': str(run),
        'passed': receipt['passed'], 'performance_accepted': False,
        'source_drift': receipt.get('source_drift'), 'control_drift': receipt.get('control_drift'),
        'seconds': mass['measurement_seconds'], 'sample_count': len(soak['samples']),
        'moved_residents': mass['moved_residents'], 'soak_errors': soak['errors'],
        'per_id': summaries, 'matching_log_line_counts': dict(event_counts),
        'physics_steps_per_render_histogram': dict(sorted(Counter(steps).items())),
        'physics_steps': sum(steps), 'render_frames': len(frames),
        'physics_steps_per_second': sum(steps) / mass['measurement_seconds'],
        'headless_frame_timing_descriptive_only': receipt.get('frame_ms'),
        'native_trends': {k: trend(native, k) for k in
            ('static_memory', 'objects', 'nodes', 'orphans', 'resources', 'draw_calls',
             'primitives', 'video_memory', 'texture_memory', 'buffer_memory', 'process_ms', 'physics_ms',
             'route_jobs', 'route_nodes', 'route_heap', 'nav_pending', 'nav_guides', 'registry_entries', 'service_keys')},
        'os_trends': {k: trend(memory, k) for k in ('rss_bytes', 'private_bytes')},
        'observer_max_sample_us': soak['max_sample_us'],
        'evidence_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
            [run / 'MASS30.json', run / 'SOAK31.json', run / 'RUN.json', run / 'OS_MEMORY.json', run / 'stdout.log']},
        'limitations': [
            'Natural ordinary RNG differs across runs; observations are not matched scripted traffic.',
            'Full HP may mean no natural hospital cycle within this window.',
            'Headless alongside user game does not establish rendered FPS or clean performance.',
            'Finite memory trends include bounded observer records and do not establish a leak.',
            'Positions are sampled once per second; 10 cm progress resets accumulated inactivity.',
        ],
    }
    (run / 'ANALYSIS.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: report[k] for k in ('run', 'passed', 'sample_count', 'moved_residents',
                                         'soak_errors', 'matching_log_line_counts', 'physics_steps_per_second')}, ensure_ascii=True))


if __name__ == '__main__':
    main()
