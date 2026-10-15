"""Extract unchanged 1 Hz observed positions; no reconstructed physics samples."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT / 'outputs/coordinator31_npc57/proposals/qa58_merged/runs/merged58_1200_02/SOAK31.json'
data = json.loads(SOURCE.read_text(encoding='utf-8-sig'))
rows = []
last_waypoint = None
way_key = -1
previous_ms = None
for sample in data['samples']:
    if sample['measure_ms'] < 438384:
        continue
    actor = next(a for a in sample['actors'] if a['id'] == 'resident_7')
    assert actor['life_phase'] == 'WALKING' and actor['route_attempts'] == 0
    assert actor['threat']['phase'] == 'IDLE' and not actor['attention']
    waypoint = actor['driver_waypoint']
    if waypoint != last_waypoint:
        way_key += 1
        last_waypoint = waypoint
    ms = sample['measure_ms']
    rows.append(dict(measure_ms=ms, delta_s=0 if previous_ms is None else (ms-previous_ms)/1000,
                     position=actor['position'], waypoint=waypoint, way_key=way_key,
                     physics_frame=sample['physics_frame'] if 'physics_frame' in sample else actor['physics_last_frame']))
    previous_ms = ms
result = dict(source=str(SOURCE.relative_to(ROOT)).replace('\\', '/'),
              source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(), rows=rows,
              interpretation='Recorded 1 Hz samples and their actual elapsed deltas, not a reconstructed 60 Hz motion replay. Way key changes only when the observed waypoint changes. No replan/attention occurred in this episode.')
with (HERE / 'RECORDED_INPUT58.json').open('x', encoding='utf-8') as handle:
    json.dump(result, handle, indent=2)
print(json.dumps(dict(samples=len(rows), elapsed_s=(rows[-1]['measure_ms']-rows[0]['measure_ms'])/1000)))
