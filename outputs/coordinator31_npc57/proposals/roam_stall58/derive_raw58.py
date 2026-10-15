"""Preserve the complete actual resident7 history and causal native diagnostics."""
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
OUT=Path(__file__).resolve().parent
RUN=OUT.parent/'qa58_merged/runs/merged58_1200_02'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sources=['SOAK31.json','MASS30.json','SLOW_PLANNER31.json','stdout.log','RUN.json','SOURCE.json','SOURCE_AFTER.json','FINAL_AUDIT58.json']
pins={name:sha(RUN/name) for name in sources}
soak=read(RUN/'SOAK31.json');slow=read(RUN/'SLOW_PLANNER31.json')
history=[];near=[]
for sample in soak['samples']:
    actors=sample['actors'][:sample['count']]
    row=next(a for a in actors if a['id']=='resident_7')
    time_s=sample['measure_ms']/1000
    history.append({'time_s':time_s,'sample_frame':sample['frame'],**row})
    if time_s>=438.384:
        nearest=min((math.hypot(a['position'][0]-row['position'][0],a['position'][2]-row['position'][2]),a) for a in actors if a['id']!='resident_7')
        near.append({'time_s':time_s,'nearest_id':nearest[1]['id'],'nearest_distance_m':nearest[0],'nearest_position':nearest[1]['position']})
episode=[r for r in history if r['time_s']>=438.384]
xs=[r['position'][0] for r in episode];zs=[r['position'][2] for r in episode]
sampled_travel=sum(math.hypot(b['position'][0]-a['position'][0],b['position'][2]-a['position'][2]) for a,b in zip(episode,episode[1:]))
slow_rows=[r for r in slow['samples'] if r['actor']['id']=='resident_7']
stdout=[]
for number,line in enumerate((RUN/'stdout.log').read_text(encoding='utf-8-sig').splitlines(),1):
    if 'id=resident_7 ' in line and line.startswith(('NPC_ROAM51','DSH_SIMPLEHOSP','DSH_ENERGY','NPC_ECONOMY28')):
        stdout.append({'line':number,'text':line})
result={'schema':'mafiozi.roam58.actual-native-cause/v1','source_run':str(RUN.resolve()),'source_sha256':pins,
    'resident':'resident_7','start_s':episode[0]['time_s'],'end_s':episode[-1]['time_s'],'duration_s':episode[-1]['time_s']-episode[0]['time_s'],
    'episode_samples':len(episode),'bbox_diagonal_m':math.hypot(max(xs)-min(xs),max(zs)-min(zs)),
    'sampled_travel_m':sampled_travel,'net_displacement_m':math.hypot(xs[-1]-xs[0],zs[-1]-zs[0]),
    'targets':dict(Counter(str(r['driver_target']) for r in episode)),
    'waypoints':dict(Counter(str(r['driver_waypoint']) for r in episode)),
    'phases':dict(Counter(r['life_phase'] for r in episode)),'route_phases':dict(Counter(r['route_phase'] for r in episode)),
    'max_motion_idle_s':max(r['motion_idle_s'] for r in episode),'walk_completed_values':sorted(set(r['completed']['walk'] for r in episode)),
    'full_actor_history':history,'slow_native_snapshots':slow_rows,'nearest_other_originals':near,'stdout_history':stdout,
    'established':['The same roam goal and ready waypoint remain active while the actual actor oscillates for761seconds.',
                   'Physical callbacks continue, attention/threat are absent, shared planner jobs are empty in detailed snapshots.',
                   'Planner last_collider reports LobbyTable96, but the field may describe an earlier query; actual slide collider needs a targeted native replay.'],
    'production_modified':False,'native_evidence_modified':False,'performance_accepted':False}
assert pins=={name:sha(RUN/name) for name in sources}
p=OUT/'ACTUAL_TRACE58.json';assert not p.exists();p.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:result[k] for k in ['resident','duration_s','episode_samples','bbox_diagonal_m','sampled_travel_m','net_displacement_m','targets','waypoints','max_motion_idle_s','walk_completed_values']}))
