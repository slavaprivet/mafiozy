"""Read-only summary of a bounded prefix of the ordinary user game's native log."""
from pathlib import Path
from collections import Counter, defaultdict
from datetime import datetime, timezone
import argparse
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    args = parser.parse_args()
    assert re.fullmatch('[a-z0-9_]+', args.name)
    opened = read(ROOT / 'outputs/current_game/OPENED.json')
    assert opened['revision'] == 's01-20261015-residents57' and opened['ready'] is True
    run = Path(opened['run_directory'])
    assert run.is_relative_to(ROOT / 'outputs/current_game/interactive')
    log = run / 'play.log'
    size = log.stat().st_size
    assert size <= 100 * 1024 * 1024, 'Bounded read exceeded100MiB'
    with log.open('rb') as stream:
        raw = stream.read(size)
    raw = raw[:raw.rfind(b'\n') + 1]
    residents = defaultdict(lambda: {'walks_completed': 0, 'purchases_paid': 0,
        'services_completed': Counter(), 'ambient_completed': Counter(),
        'ambient_blocked': Counter(), 'last_economy': {}, 'last_ambient': {}})
    counts = Counter()
    alerts = []
    frame = 0
    first_frame = None
    energy = {}
    for line_number, line in enumerate(raw.decode('utf-8', errors='replace').splitlines(), 1):
        frame_match = re.search(r'(?:\bf=|\bframe=)(\d+)', line)
        if frame_match:
            frame = max(frame, int(frame_match[1]))
            if first_frame is None:
                first_frame = frame
        if line.startswith('NPC_AMBIENT28 '):
            event = json.loads(line[len('NPC_AMBIENT28 '):])
            frame = max(frame, int(event.get('frame', 0)))
            row = residents[event['id']]
            row['last_ambient'] = event
            if event['event'] in ('completed', 'blocked'):
                row['ambient_' + event['event']][event['kind']] += 1
            counts['ambient_' + event['event']] += 1
        elif line.startswith('NPC_ECONOMY28 '):
            values = dict(re.findall(r'\b(id|kind|stage|cash|serial|frame)=(\S+)', line))
            if 'id' not in values:
                continue
            row = residents[values['id']]
            values['reason'] = line.split(' reason=', 1)[1].rsplit(' frame=', 1)[0] if ' reason=' in line else ''
            row['last_economy'] = values
            stage = values.get('stage', '')
            counts['economy_' + stage] += 1
            if stage == 'roam_arrived':
                row['walks_completed'] += 1
            elif stage == 'paid':
                row['purchases_paid'] += 1
            elif stage == 'complete':
                row['services_completed'][values['kind']] += 1
        elif line.startswith('DSH_ENERGY '):
            values = dict(re.findall(r'\b(id|energy|walked_m|frame)=(\S+)', line))
            if 'id' in values:
                energy[values['id']] = values
        if any(pattern in line for pattern in ('exit_blocked', 'SCRIPT ERROR', 'ERROR:', 'stage=blocked', 'result=blocked')):
            counts['diagnostic_lines'] += 1
            if len(alerts) < 100:
                alerts.append({'line': line_number, 'text': line})
    result = {
        'schema': 'mafiozi.live-log-audit31/v1',
        'recorded_at': datetime.now(timezone.utc).isoformat(),
        'run': run.relative_to(ROOT).as_posix(), 'revision': opened['revision'],
        'pid_at_launch': opened['pid'], 'read_bytes': len(raw),
        'read_prefix_sha256': hashlib.sha256(raw).hexdigest(),
        'stderr_bytes_at_read': (run / 'play.err').stat().st_size,
        'first_frame': first_frame, 'last_frame': frame,
        'counts': dict(counts), 'residents': dict(residents), 'last_energy': energy,
        'diagnostic_lines_first100': alerts,
        'limits': 'Native log summary only: no position samples, no maximum motion-idle proof, no FPS or complete behavior acceptance. Ordinary user process is read only and preserved.',
    }
    output = HERE / (args.name + '.json')
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    print(json.dumps({'path': str(output), 'counts': dict(counts),
        'residents_with_completed_walks': sum(row['walks_completed'] > 0 for row in residents.values()),
        'distinct_completed_ambient': sorted({kind for row in residents.values() for kind in row['ambient_completed']}),
        'last_frame': frame, 'stderr_bytes': result['stderr_bytes_at_read']}, ensure_ascii=True))
