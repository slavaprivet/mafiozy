"""Reads one owner58 run log and reports the four defects this pass targets.

Nothing is inferred from a PASS/FAIL string: every number comes from a line the game
itself printed. The report is written next to the log as AUDIT.json.
"""
from pathlib import Path
import argparse
import collections
import json
import re

LEISURE = re.compile(r'NPC_ROUTINE58 id=(\S+) stage=leisure_started bench=(\S+) target=\(([^)]*)\) seat_reserved=(\w+) seat_serial=(-?\d+)')
LINE = re.compile(r'^OWNER58_LINE (\{.*\})$')
SAMPLE = re.compile(r'^OWNER58_SAMPLE (\{.*\})$')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    args = parser.parse_args()
    run = args.run.resolve()
    log = run / 'stdout.log'
    text = log.read_text(encoding='utf-8', errors='replace')

    leisure = [LEISURE.match(m) for m in LEISURE.findall(text)] if False else []
    leisure = []
    for line in text.splitlines():
        found = LEISURE.search(line)
        if found:
            leisure.append({'id': found.group(1), 'bench': found.group(2),
                            'target': found.group(3), 'reserved': found.group(4),
                            'serial': int(found.group(5))})

    # Defect 1: one bench, one goal, one point - never two residents at the same time.
    per_bench = collections.defaultdict(list)
    for row in leisure:
        per_bench[row['bench']].append(row)
    duplicates = {}
    for bench, rows in per_bench.items():
        seats = collections.Counter(r['serial'] for r in rows)
        if any(count > 1 for count in seats.values()):
            duplicates[bench] = {str(serial): count for serial, count in seats.items() if count > 1}
    open_seats = sum(1 for row in leisure if row['reserved'] == 'false')

    # Defect 3: planner work spent on a goal that has no standing point.
    unsupported = text.count('goal_has_no_supported_standing_point')
    resolved = len(re.findall(r'"resolved":true', text))
    unresolved = len(re.findall(r'"resolved":false', text))

    lines = []
    samples = []
    for line in text.splitlines():
        found = LINE.search(line)
        if found:
            try:
                lines.append(json.loads(found.group(1)))
            except json.JSONDecodeError:
                pass
            continue
        found = SAMPLE.search(line)
        if found:
            try:
                samples.append(json.loads(found.group(1)))
            except json.JSONDecodeError:
                pass

    # Defect 4: how long a resident stands still, and why.
    worst = collections.defaultdict(float)
    worst_row = {}
    reason_seconds = collections.Counter()
    planner_queries = {}
    phase_seconds = collections.Counter()
    for row in lines:
        ident = row['id']
        if float(row.get('still_s', 0.0)) >= worst[ident]:
            worst[ident] = float(row.get('still_s', 0.0))
            worst_row[ident] = row
        if float(row.get('still_s', 0.0)) >= 3.0:
            reason = str(row.get('reason') or row.get('driver', {}).get('reason') or 'unstated')
            reason_seconds[reason] += 1
            phase_seconds[str(row.get('phase'))] += 1
        driver = row.get('driver') or {}
        if driver:
            planner_queries[ident] = max(planner_queries.get(ident, -1), int(driver.get('queries', -1)))

    # Defect 2: peer detours must stop being produced at all.
    peer_detour = len(re.findall(r'peer_yield|peer_detour_no_progress|right_pass', text))
    route_replans = len(re.findall(r'begin_detour', text))

    report = {
        'run': str(run),
        'stdout_bytes': log.stat().st_size,
        'seat_reservations': len(leisure),
        'seat_reservations_without_hold': open_seats,
        'benches_with_duplicate_serial': duplicates,
        'benches_used': len(per_bench),
        'goals_refused_without_standing_point': unsupported,
        'goals_resolved_to_nearby_supported_point': resolved,
        'goals_with_no_supported_point_anywhere': unresolved,
        'peer_yield_events': peer_detour,
        'route_detours': route_replans,
        'worst_still_seconds_per_resident': {k: round(v, 2) for k, v in sorted(worst.items())},
        'worst_still_row': worst_row,
        'still_ge_3s_reasons': dict(reason_seconds),
        'still_ge_3s_phases': dict(phase_seconds),
        'max_planner_queries_per_resident': planner_queries,
        'watch_lines': len(lines),
        'watch_samples': len(samples),
        'last_sample': samples[-1] if samples else None,
    }
    (run / 'AUDIT.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=True, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
