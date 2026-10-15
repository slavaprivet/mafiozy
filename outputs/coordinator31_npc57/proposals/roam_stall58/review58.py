"""Independent read-only audit of terminal final-source natural observation."""
import argparse
import bisect
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import zipfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
MANIFEST = ROOT / 'outputs/coordinator31_npc57/extended31/stage58_03/CANDIDATE58.json'
MANIFEST_SHA = '46a095bd14fdede78861d097cd5e69ad73a32c6cdf842b6944375101e84155a7'


def archive_matches(path, pins):
    with zipfile.ZipFile(path) as zipped:
        return set(zipped.namelist()) == set(pins) and all(
            hashlib.sha256(zipped.read(name)).hexdigest() == value for name, value in pins.items())


def independent_spatial(rows):
    """Use complete segments and binary-search windows rather than root's deque."""
    segments = []
    current = []
    previous = None
    for stamp, actor in rows:
        reset = (not actor['required_motion'] or actor.get('attention', False)
                 or previous is not None and
                 (stamp-previous[0] > 2.5 or actor['completed']['walk'] != previous[1]['completed']['walk']))
        previous = (stamp, actor)
        if reset:
            if current:
                segments.append(current)
                current = []
        else:
            current.append((stamp, actor))
    if current:
        segments.append(current)
    failures = []
    minimum = None
    windows = 0
    for segment in segments:
        stamps = [item[0] for item in segment]
        active = None
        for end, stamp in enumerate(stamps):
            start = bisect.bisect_right(stamps, stamp-30.0, 0, end+1)-1
            if start < 0:
                continue
            window = segment[start:end+1]
            xs = [row['position'][0] for _, row in window]
            zs = [row['position'][2] for _, row in window]
            diagonal = math.hypot(max(xs)-min(xs), max(zs)-min(zs))
            windows += 1
            minimum = diagonal if minimum is None else min(minimum, diagonal)
            if diagonal > 1.5:
                active = None
                continue
            if active is None:
                active = {'start_s': stamps[start], 'end_s': stamp,
                          'max_bbox_diagonal_m': diagonal, 'windows': 0}
                failures.append(active)
            active['end_s'] = stamp
            active['max_bbox_diagonal_m'] = max(active['max_bbox_diagonal_m'], diagonal)
            active['windows'] += 1
    return {'eligible_30s_windows': windows, 'minimum_30s_bbox_diagonal_m': minimum,
            'confined_motion_episodes': failures,
            'longest_required_motion_segment_s': max((s[-1][0]-s[0][0] for s in segments), default=0)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    args = parser.parse_args()
    run = args.run.resolve()
    assert run == (ROOT/'outputs/coordinator31_npc57/proposals/qa58_merged/runs/merged58_1200_02').resolve()
    assert sha(MANIFEST) == MANIFEST_SHA
    final = read(run/'FINAL_AUDIT58.json')  # Root's terminal audit is required first.
    receipt = read(run/'RUN.json')
    assert 'exit_code' in receipt
    target = OUT/'INDEPENDENT_SOAK58.json'
    assert not target.exists(), 'Preserve previous review'
    before = {p.name: sha(p) for p in run.iterdir() if p.is_file()}
    mass = read(run/'MASS30.json')
    soak = read(run/'SOAK31.json')
    spatial = read(run/'SPATIAL58.json')
    native_rows = soak['samples']
    expected = {f'resident_{i}' for i in range(1, 11)}
    histories = defaultdict(list)
    composition = True
    for sample in native_rows:
        actors = sample['actors'][:sample['count']]
        composition &= sample['count'] == 10 and len(actors) == 10 and {a['id'] for a in actors} == expected
        for actor in actors:
            histories[(actor['id'], actor['generation'])].append((sample['measure_ms']/1000, actor))
    per_life = []
    for (ident, generation), rows in sorted(histories.items()):
        first = rows[0][1]['position']
        displacement = max(math.hypot(a['position'][0]-first[0], a['position'][2]-first[2]) for _, a in rows)
        completed = {key: max(a['completed'].get(key, 0) for _, a in rows)-rows[0][1]['completed'].get(key, 0)
                     for key in rows[-1][1]['completed']}
        per_life.append({'id': ident, 'generation': generation, 'samples': len(rows),
            'first_s': rows[0][0], 'last_s': rows[-1][0],
            'max_displacement_from_first_m': displacement,
            'max_motion_idle_s': max(a['motion_idle_s'] for _, a in rows),
            'max_queue_idle_s': max(a['queue_idle_s'] for _, a in rows),
            'max_required_motion_physics_lag': max((a['physics_lag_frames'] for _, a in rows if a['required_motion']), default=0),
            'completion_deltas': completed, **independent_spatial(rows)})
    frame_at = mass['frame_at_s']
    frame_ms = mass['frame_ms']
    ticks = soak['physics_steps_per_render']
    times = [row['measure_ms']/1000 for row in native_rows]
    elapsed = frame_at[-1]
    frame_duration = sum(frame_ms)/1000
    completions = {key: sum(life['completion_deltas'].get(key, 0) for life in per_life)
                   for key in ['shop', 'restaurant', 'hospital', 'bank', 'walk']}
    harness = read(run/'HARNESS.json')
    gates = {
        'root_and_native_terminal_pass': final.get('passed') is True and receipt.get('passed') is True and receipt['exit_code'] == 0,
        'exact_source03_before_after': read(run/'SOURCE.json') == read(run/'SOURCE_AFTER.json') == read(MANIFEST)['source_pins'],
        'root_manifest_is_final_source03': final['source_manifest_sha256'] == MANIFEST_SHA,
        'all_root_raw_evidence_hashes_match': all(before[name] == value for name, value in final['raw_evidence_sha256'].items()),
        'archived_native_harness_matches': archive_matches(run/'HARNESS.zip', harness),
        'archived_root_analyzers_match': archive_matches(run/'ANALYZERS58.zip', final['analyzer_pins']) and before['ANALYZERS58.zip'] == final['analyzer_archive_sha256'],
        'controls_and_sources_unchanged': read(run/'CONTROL_PINS.json') == read(run/'CONTROL_PINS_AFTER.json') and all(receipt.get(k) == [] for k in ['source_drift', 'harness_drift', 'control_drift']),
        'native_errors_empty': receipt.get('errors') == [] and receipt.get('stderr_bytes') == 0 and not soak['errors'] and mass.get('ok') is True and not mass['errors'],
        'native1200_not_serialization': 1199.9 <= elapsed <= 1201 and 1199.9 <= frame_duration <= 1201,
        'valid_frame_clock': all(math.isfinite(x) and x >= 0 for x in frame_at) and all(b >= a for a, b in zip(frame_at, frame_at[1:])) and all(math.isfinite(x) and x > 0 for x in frame_ms),
        'complete_physics_and_render_arrays': len(ticks) == soak['physics_sample_count'] == mass['frame_count'] == len(frame_at) == len(frame_ms) and all(isinstance(t, int) and t >= 0 for t in ticks),
        'native60hz_physics': 59.5 <= sum(ticks)/elapsed <= 60.5,
        'whole_interval_1hz_coverage': len(times) >= 1197 and 0 <= times[0] <= 1.5 and 1198.5 <= times[-1] <= elapsed and all(0 < b-a <= 2.5 for a, b in zip(times, times[1:])),
        'ten_unique_expected_ids_each_sample': composition and set(mass['actual_ids']) == set(mass['wanted_ids']) == expected,
        'all_ten_have_real_sampled_displacement': mass['moved_residents'] == 10 and {p['id'] for p in per_life if p['max_displacement_from_first_m'] > .5} == expected,
        'unweakened10s_motion30s_queue': soak['motion_idle_limit_s'] == 10 and soak['queue_idle_limit_s'] == 30 and all(p['max_motion_idle_s'] <= 10 and p['max_queue_idle_s'] <= 30 for p in per_life),
        'independent_spatial_no_confinement': not any(p['confined_motion_episodes'] for p in per_life),
        'root_spatial_agrees': spatial['passed'] is True and spatial['episodes'] == [] and spatial['source_sha256'] == before['SOAK31.json'] and spatial['window_s'] == 30 and spatial['bbox_diagonal_limit_m'] == 1.5,
        'independent_completion_counts_match': completions == final['completion_deltas'],
        'ordinary_readonly_functional_run': receipt['ordinary_rng'] is True and mass['npc_or_hp_writes'] is False and receipt['mode'] == 'headless' and receipt['performance_accepted'] is False,
    }
    result = {'schema': 'mafiozi.qa58.independent-natural-soak/v1', 'passed': all(gates.values()),
        'gates': gates, 'source_manifest_sha256': MANIFEST_SHA, 'run': str(run),
        'native_timeline_seconds': elapsed, 'sampled_frame_duration_s': frame_duration,
        'reported_including_serialization_s': mass['actual_measurement_elapsed_s'],
        'physics_ticks': sum(ticks), 'render_records': len(frame_at), 'population_samples': len(times),
        'first_population_sample_s': times[0], 'last_population_sample_s': times[-1],
        'max_population_gap_s': max(b-a for a, b in zip(times, times[1:])),
        'completion_deltas': completions, 'per_life': per_life,
        'raw_sha256_before_review': before, 'reviewer_sha256': sha(Path(__file__)),
        'engine_launched': False, 'production_modified': False, 'native_evidence_modified': False,
        'performance_accepted': False, 'release_accepted': False,
        'limitations': ['1Hz position samples cannot exclude excursions between samples.',
                       'Intentional rest, attention, actual completed walks, lifecycle changes and gaps over2.5s split spatial windows; route retries do not.',
                       'Finite natural observation does not replace separate service/threat fixtures or comparable rendered performance.']}
    after = {p.name: sha(p) for p in run.iterdir() if p.is_file()}
    assert before == after, 'Root run evidence changed during read-only review'
    result['all_run_files_unchanged'] = True
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k: result[k] for k in ['passed', 'gates', 'native_timeline_seconds', 'sampled_frame_duration_s', 'physics_ticks', 'population_samples', 'completion_deltas']}))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
