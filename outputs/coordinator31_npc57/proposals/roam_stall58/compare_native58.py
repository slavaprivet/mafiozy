"""Read-only native component comparison, distinct from natural acceptance."""
from collections import Counter
from pathlib import Path
import hashlib
import json
import math

OUT=Path(__file__).resolve().parent
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
names=['native_replay04','native_obstacle_baseline01','native_obstacle_candidate01','native_legal_candidate01']
data={name:read(OUT/'runs'/name/'NATIVE58.json') for name in names}
receipts={name:read(OUT/'runs'/name/'RUN.json') for name in names}
inputs={str(p.relative_to(OUT)):sha(p) for name in names for p in
        [OUT/'runs'/name/f for f in ['NATIVE58.json','RUN.json','HARNESS.json','HARNESS.zip','SOURCE.json','SOURCE_AFTER.json']]}

def dist(a,b):return math.hypot(a[0]-b[0],a[2]-b[2])
def brief(d):
    rows=d['rows'];motion=[dist(r['before'],r['after']) for r in rows]
    late=[r for r in rows if r['elapsed_s']>=10]
    x=[r['after'][0] for r in late];z=[r['after'][2] for r in late]
    route_us=[r['native_diagnostics']['service_us29'] for r in rows]
    return {'terminal':d['reason'],'elapsed_s':d['elapsed_s'],'physics_frames':d['native_physics_frames'],
            'actual_native_motion_m':sum(motion),'end_position':rows[-1]['after'],'goal':d['goal'],
            'end_goal_distance_xz_m':dist(rows[-1]['after'],d['goal']),
            'treadmill_bbox_after10s_m':math.hypot(max(x)-min(x),max(z)-min(z)) if late else None,
            'max_native_motion_per_second_m':max(m/r['delta'] for m,r in zip(motion,rows)),
            'route_service_us_monotonic':all(a<=b for a,b in zip(route_us,route_us[1:])),
            'route_service_us_final':route_us[-1],
            'reasons':dict(Counter(r.get('last_reason','') for r in rows)),
            'reason_transitions':[{'frame':r['frame'],'elapsed_s':r['elapsed_s'],'reason':r.get('last_reason',''),
                                   'attempts':r['attempts'],'service_us':r['native_diagnostics']['service_us29']}
                                  for i,r in enumerate(rows) if i==0 or r.get('last_reason','')!=rows[i-1].get('last_reason','')],
            'ready_routes':[{'ready_frame':p['ready_frame'],'points':len(p['points'])} for p in d['paths'] if p['ready_frame']>=0],
            'slides':dict(Counter(h['path'] for r in rows for h in r['slide_after'])),
            'debris512_blocked_samples':sum(bool(r['debris_overlap']) or r['debris_cast_fraction'][0]<.999 for r in rows),
            'all_diagnostic_memberships_valid':all(r['diagnostic_snapshot_member'] and 'no_current_snapshot' not in r['avoidance'] for r in rows)}

summaries={name:brief(d) for name,d in data.items()}
b=data['native_obstacle_baseline01'];c=data['native_obstacle_candidate01'];legal=data['native_legal_candidate01']
path=lambda d:next(p['points'] for p in d['paths'] if p['ready_frame']>=0)
checks={
 'all_component_execution_receipts_clean':all(r['passed'] and not r['source_drift'] and not r['control_drift'] and not r['harness_drift'] and not r['errors'] and r['stderr_bytes']==0 for r in receipts.values()),
 'all_snapshot_memberships_valid':all(s['all_diagnostic_memberships_valid'] for s in summaries.values()),
 'controlled_pair_harness_identical':read(OUT/'runs/native_obstacle_baseline01/HARNESS.json')==read(OUT/'runs/native_obstacle_candidate01/HARNESS.json'),
 'controlled_pair_first_route_identical':path(b)==path(c),
 'controlled_baseline_stays45s_without_replan':b['reason']=='bounded45s_end' and b['native_physics_frames']==2700 and max(r['attempts'] for r in b['rows'])==0,
 'controlled_baseline_confined_after10s':summaries['native_obstacle_baseline01']['treadmill_bbox_after10s_m']<1.5,
 'candidate_guard_actually_triggers':any(r.get('last_reason')=='roam_waypoint_no_progress58' for r in c['rows']),
 'candidate_physically_arrives_under30s':c['reason']=='arrived' and c['elapsed_s']<30 and dist(c['rows'][-1]['after'],c['goal'])<.31,
 'candidate_goal_preserved_each_frame':all(r['final_target']==c['goal'] for r in c['rows']),
 'candidate_cumulative_route_budget_preserved':summaries['native_obstacle_candidate01']['route_service_us_monotonic'],
 'legal_route_unchanged':path(data['native_replay04'])==path(legal),
 'legal_candidate_arrives_under5s_without_retry':legal['reason']=='arrived' and legal['elapsed_s']<5 and max(r['attempts'] for r in legal['rows'])==0,
 'native_physics_60hz_normal_time':all(d['physics_hz']==60 and d['time_scale']==1 for d in data.values()),
 'source_identical_all_runs':len({sha(OUT/'runs'/name/'SOURCE.json') for name in names})==1,
}
result={'schema':'mafiozi.roam58.controlled-native-comparison/v1','passed':all(checks.values()),
        'checks':checks,'runs':summaries,'inputs':inputs,
        'candidate_driver_sha256':sha(OUT/'candidate_driver58.gd'),
        'natural_failure_exact_collider_established':False,'natural_acceptance_passed':False,
        'scope':'Controlled world obstacle inserted once after a real route is accepted. Actual native capsule movement, collisions, avoidance and planner; no actor position/velocity/route/goal manipulation after initial placement. This reproduces the stale-route treadmill class, not the exact collider of the original761s incident.',
        'historical_harness_failures':{'native_replay01':'Extra actor missing global avoidance snapshot;15s planning timeout is invalid reproduction.',
                                       'native_replay02':'Second snapshot in same frame returned true without including extra actor; invalid reproduction.',
                                       'native_replay03':'Adapter appended to shared active_records array; host owner-key error. Exact source unchanged. Fixed by duplicate before append.'},
        'production_source_modified':False,'raw_evidence_modified':False}
assert inputs=={rel:sha(OUT/rel) for rel in inputs}
target=OUT/'NATIVE_COMPARISON58.json';assert not target.exists()
target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'passed':result['passed'],'checks':checks,'runs':{name:{k:s[k] for k in ['terminal','elapsed_s','physics_frames','route_service_us_final','reason_transitions']} for name,s in summaries.items()}}))
