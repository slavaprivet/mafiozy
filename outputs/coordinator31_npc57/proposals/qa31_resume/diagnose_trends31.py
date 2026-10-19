"""Descriptive planning/frame/memory analysis; never a clean-performance verdict."""
from bisect import bisect_left
from collections import Counter, defaultdict
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import statistics


def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))


def pct(values, q):
    values = sorted(values)
    return values[min(len(values)-1, int((len(values)-1)*q))] if values else None


def stats(values):
    return {'n': len(values), 'mean': statistics.mean(values), 'p50': pct(values, .50),
            'p95': pct(values, .95), 'p99': pct(values, .99), 'max': max(values)} if values else {}


def slope(points):
    if len(points) < 2:
        return None
    mx, my = (statistics.mean(p[i] for p in points) for i in (0, 1))
    den = sum((x-mx)**2 for x, _ in points)
    return 60*sum((x-mx)*(y-my) for x, y in points)/den if den else 0


def corr(points):
    if len(points) < 3:
        return None
    mx, my = (statistics.mean(p[i] for p in points) for i in (0, 1))
    xx = sum((x-mx)**2 for x, _ in points)
    yy = sum((y-my)**2 for _, y in points)
    return sum((x-mx)*(y-my) for x, y in points)/math.sqrt(xx*yy) if xx and yy else None


def analyze(path):
    mass, soak, memory = (read(path/name) for name in ('MASS30.json', 'SOAK31.json', 'OS_MEMORY.json'))
    duration = mass['measurement_seconds']
    samples = [r for r in mass['samples'] if r['measure_ms'] >= 0]
    frame_axis = [r['frame'] for r in samples]

    def seconds_for_frame(frame):
        i = max(1, min(len(samples)-1, bisect_left(frame_axis, frame)))
        left, right = samples[i-1], samples[i]
        fraction = (frame-left['frame'])/(right['frame']-left['frame'])
        return (left['measure_ms']+fraction*(right['measure_ms']-left['measure_ms']))/1000

    daily, printed_fps, exit_blocked = [], [], []
    for line in (path/'stdout.log').read_text(encoding='utf-8', errors='replace').splitlines():
        if line.startswith(('DSH_DAILY ', 'DSH_RESID ')):
            fields = {k: float(v) for k, v in re.findall(r'\b([a-zA-Z_0-9]+)=(-?\d+(?:\.\d+)?)', line)}
            if 'f' not in fields:
                continue
            second = seconds_for_frame(fields['f'])
            if not 0 <= second < duration:
                continue
            fields['second'] = second
            (daily if line.startswith('DSH_DAILY ') else printed_fps).append(fields)
        if line.startswith('NPC_ECONOMY28 ') and 'stage=exit_blocked ' in line:
            fields = dict(re.findall(r'\b([a-zA-Z_0-9]+)=([^\s]+)', line))
            fields['second'] = seconds_for_frame(int(fields['frame']))
            exit_blocked.append(fields)

    persecond = defaultdict(list)
    for value, second in zip(mass['frame_ms'], mass['frame_at_s']):
        persecond[int(second)].append(value)
    workbysecond = defaultdict(list)
    for row in daily:
        workbysecond[int(row['second'])].append(row['physical_us30']/1000)

    slices = [(f'quarter_{i+1}', duration*i/4, duration*(i+1)/4) for i in range(4)]
    slices += [('first_180', 0, min(duration, 180))]
    if duration > 335:
        slices += [('before_stall_0_335', 0, 335), ('after_stall_335_end', 335, duration)]
    windows = {}
    for name, start, end in slices:
        frames = [v for v, t in zip(mass['frame_ms'], mass['frame_at_s']) if start <= t < end]
        costs = [r for r in daily if start <= r['second'] < end]
        native = [r for r in samples if start <= r['measure_ms']/1000 < end]
        windows[name] = {'seconds': [start, end], 'frame_ms': stats(frames),
            'mean_headless_frame_frequency': 1000/statistics.mean(frames),
            'printed_fps': stats([r['fps'] for r in printed_fps if start <= r['second'] < end]),
            'sampled_physical_ms': stats([r['physical_us30']/1000 for r in costs]),
            'sampled_daily_total_ms': stats([r['total_us']/1000 for r in costs]),
            'native_route_service_us': stats([r['route_service_us'] for r in native]),
            'native_physics_ms': stats([r['physics_ms'] for r in native]),
            'native_process_ms': stats([r['process_ms'] for r in native]),
            'native_objects': stats([r['objects'] for r in native]),
            'native_static_bytes': stats([r['static_memory'] for r in native])}

    actors = [dict(second=sample['measure_ms']/1000, **actor)
              for sample in soak['samples'] for actor in sample['actors'][:sample['count']]]
    planning = sorted(actors, key=lambda a: a['service_watch']['planning_service_us'], reverse=True)
    keys = ('second','id','venue','position','life_phase','economy_phase','outer_phase','route_phase',
            'route_reason','route_status','guide_status','required_motion','motion_idle_s','queue_idle_s','service_watch')
    perid = {}
    for ident in sorted({a['id'] for a in actors}):
        rows = [a for a in actors if a['id'] == ident]
        maximum = max(rows, key=lambda a: a['service_watch']['planning_service_us'])
        perid[ident] = {k: maximum[k] for k in keys}
    groups = defaultdict(list)
    for ms, steps in zip(mass['frame_ms'], soak['physics_steps_per_render']):
        groups[str(steps)].append(ms)
    osrows = [r for r in memory['samples'] if mass['measurement_start_unix_ms'] <= r['unix_ms'] <= mass['measurement_end_unix_ms']]
    trends = {}
    for key in ('static_memory', 'objects', 'nodes', 'resources', 'orphans'):
        trends[key] = {'slope_per_minute': slope([(r['measure_ms']/1000, r[key]) for r in samples]),
                       'first': samples[0][key], 'last': samples[-1][key], 'max': max(r[key] for r in samples)}
    for key in ('rss_bytes', 'private_bytes'):
        trends[key] = {'slope_per_minute': slope([(r['unix_ms']/1000, r[key]) for r in osrows]),
                       'first': osrows[0][key], 'last': osrows[-1][key], 'max': max(r[key] for r in osrows)}

    return {'path': str(path), 'mode': read(path/'RUN.json')['mode'], 'performance_accepted': False,
        'duration': duration, 'windows': windows, 'memory_trends': trends,
        'mean_frame_ms_slope_per_minute': slope([(s, statistics.mean(v)) for s, v in persecond.items() if len(v) > 10]),
        'frame_p95_vs_sampled_physical_cost_correlation': corr([(pct(v, .95), statistics.mean(workbysecond[s])) for s, v in persecond.items() if s in workbysecond and len(v) > 10]),
        'frames_grouped_by_physics_steps': {k: stats(v) for k,v in sorted(groups.items())},
        'top_20_sampled_physical_ticks': sorted(daily,key=lambda r:r['physical_us30'],reverse=True)[:20],
        'top_20_accumulated_planning_samples': [{k:r[k] for k in keys} for r in planning[:20]],
        'maximum_accumulated_planning_per_id': perid,
        'exit_blocked_events': exit_blocked,
        'terminal_logic_ring': mass['snapshot']['logic_cost'],
        'terminal_logic_ring_frames': {'oldest': min(mass['snapshot']['logic_frame_trace']['frames']),
                                       'newest': max(mass['snapshot']['logic_frame_trace']['frames']),
                                       'capacity': mass['snapshot']['logic_frame_trace']['capacity']},
        'evidence_sha256': {name: hashlib.sha256((path/name).read_bytes()).hexdigest() for name in ('RUN.json','MASS30.json','SOAK31.json','OS_MEMORY.json','stdout.log')},
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('baseline', type=Path)
    p.add_argument('candidate', type=Path)
    args = p.parse_args()
    report = {'schema':'mafiozi.soak31.planning-cost-comparison/v1',
              'baseline':analyze(args.baseline.resolve()), 'candidate':analyze(args.candidate.resolve()),
              'limitations':[
                  'Both runs are headless and may overlap other scheduled functional work; no rendered FPS or exclusive performance verdict follows.',
                  'Durations, natural RNG activity and observer revisions differ. The first180s window is descriptive, not a controlled A/B.',
                  'Daily physical costs are sampled every15 physics ticks; maxima between printed samples can be absent.',
                  'Planning watch values are accumulated CPU microseconds across route work, not a single frame spike. They reset on progress/retry.',
                  'Log-frame alignment uses exact native physics-frame anchors with interpolation within1Hz observation intervals.',
                  'Terminal logic p50/p95 describe a2048-entry rolling buffer, not the entire600s history.',
                  'Observer allocations and ordinary asset/route activity contribute to object/static-memory growth; finite trends are not a leak diagnosis.'
              ]}
    output = args.candidate.resolve()/'PLANNING_COST_COMPARISON.json'
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(str(output))


if __name__ == '__main__':
    main()
