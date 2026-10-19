"""Read-only extraction of the preserved final1200 resident7 treadmill."""
from pathlib import Path
import collections
import hashlib
import json
import math

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
RUN = ROOT / 'outputs/coordinator31_npc57/proposals/qa58_merged/runs/merged58_1200_02'
GAME = ROOT / 'outputs/coordinator31_npc57/game'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    samples = read(RUN / 'SOAK31.json')['samples']
    rows = []
    for sample in samples:
        for actor in sample['actors']:
            if actor['id'] == 'resident_7' and sample['measure_ms'] >= 438384:
                rows.append(dict(ms=sample['measure_ms'], actor=actor))
    points = [row['actor']['position'] for row in rows]
    bounds = [[min(point[i] for point in points), max(point[i] for point in points)] for i in (0, 2)]
    flat = lambda a, b: math.hypot(a[0]-b[0], a[2]-b[2])
    slow = [sample for sample in read(RUN / 'SLOW_PLANNER31.json')['samples'] if sample['actor']['id'] == 'resident_7']
    files = ['scripts/hospital/npc_simple_hospital.gd', 'scripts/hospital/npc_roam_wait29.gd',
             'scripts/hospital/npc_physical_route51.gd', 'scripts/npc_daily_life.gd']
    result = dict(source_run=RUN.relative_to(ROOT).as_posix(), resident='resident_7',
        start_ms=rows[0]['ms'], end_ms=rows[-1]['ms'], samples=len(rows), bounds_xz=bounds,
        bbox_diagonal_m=math.hypot(*(maximum-minimum for minimum, maximum in bounds)),
        sampled_travel_m=sum(flat(a,b) for a,b in zip(points, points[1:])),
        sampled_net_displacement_m=flat(points[0], points[-1]),
        phases=dict(collections.Counter(row['actor']['life_phase'] for row in rows)),
        targets=dict(collections.Counter(json.dumps(row['actor']['driver_target']) for row in rows)),
        waypoints=dict(collections.Counter(json.dumps(row['actor']['driver_waypoint']) for row in rows)),
        completed_walk_values=sorted(set(row['actor']['completed']['walk'] for row in rows)),
        route_attempt_values=sorted(set(row['actor']['route_attempts'] for row in rows)),
        slow_planner=[dict(ms=row['measure_ms'], ready_frame=row['planner']['ready_frame'],
            service_us=row['planner']['service_us29'], queries=row['planner']['queries'],
            collider=row['planner']['last_collider'], failure=row['planner']['last_query_failure']) for row in slow],
        raw_pins={name:sha(RUN/name) for name in ('SOAK31.json','SLOW_PLANNER31.json','SPATIAL58.json','FINAL_AUDIT58.json')},
        source_pins={name:sha(GAME/name) for name in files},
        confirmed_code_gap='Roam resets motion-idle after any 5mm step; the existing monotonic waypoint guard applies only to service_approach.',
        physical_cause='Pending precise native slide/sweep reproduction; planner last_collider may be historical.',
        behavior_modified=False, source_modified=False, engine_launched=False)
    with (HERE/'RAW_TREADMILL58.json').open('x',encoding='utf-8') as stream:
        stream.write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({key:result[key] for key in ('samples','bbox_diagonal_m','sampled_travel_m','sampled_net_displacement_m','route_attempt_values','completed_walk_values')}))


if __name__ == '__main__':
    main()
