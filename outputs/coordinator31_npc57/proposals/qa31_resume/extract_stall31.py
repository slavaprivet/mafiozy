"""Extract exact observer samples for a venue without changing raw evidence."""
from pathlib import Path
import argparse
import hashlib
import json


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('run', type=Path)
    p.add_argument('--venue', required=True)
    a = p.parse_args()
    run = a.run.resolve()
    source = run / 'SOAK31.json'
    data = json.loads(source.read_text(encoding='utf-8'))
    selected = {actor['id'] for sample in data['samples'] for actor in sample['actors'][:sample['count']]
                if actor['venue'] == a.venue}
    history = {key: [] for key in sorted(selected)}
    transitions = []
    previous = {}
    for sample in data['samples']:
        for actor in sample['actors'][:sample['count']]:
            if actor['id'] not in selected:
                continue
            key = actor['id']
            row = {'measure_ms': sample['measure_ms'], 'physics_frame': sample['frame'], **actor}
            history[key].append(row)
            state = tuple(actor[k] for k in ('generation', 'venue', 'life_phase', 'economy_phase',
                                             'outer_phase', 'route_phase', 'route_reason',
                                             'queue_kind', 'queue_state', 'door_stage'))
            if previous.get(key) != state:
                transitions.append(row)
                previous[key] = state
    report = {
        'schema': 'mafiozi.soak31.venue-stall-trace/v1', 'venue': a.venue,
        'read_only_native_samples': True, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'source_pins_sha256': hashlib.sha256((run / 'SOURCE.json').read_bytes()).hexdigest(),
        'participants': sorted(selected), 'phase_transitions': transitions, 'per_id_history': history,
        'limitations': 'This venue-history artifact contains exact 1Hz position/phase/watch/queue samples. It does not include planner target/leg, collider names or geometry. If this run has SLOW_PLANNER31.json, consult that separate native artifact for those diagnostics; no such values are inferred here.',
    }
    target = run / ('VENUE_' + a.venue + '_TRACE.json')
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'output': str(target), 'participants': sorted(selected), 'transitions': len(transitions)}, ensure_ascii=True))


if __name__ == '__main__':
    main()
