from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
baseline=HERE.parent/'service_threat58/runs/shop_calibration01'
old=read(baseline/'SERVICE_THREAT58.json')
baseline_run=read(baseline/'RUN.json')
evidence=[{'ms':row['ms'],'position':row['position'],'threat':row['threat']} for row in old['samples'] if row['threat'].get('phase') in ['FLEE','RECOVER']][:6]
result={
 'status':'PROPOSAL_NOT_INTEGRATED',
 'source_stage':'stage58_02',
 'source_count':1135,
 'candidate_sha256':'4a00c3c85b4d705ce917c60a7d0b92deb634d24eb57b41cff2664d24e2cfb70e',
 'patch':read(HERE/'PATCH.json'),
 'baseline_failure':{'path':str(baseline.relative_to(ROOT)),'run_sha256':sha(baseline/'RUN.json'),'native_sha256':sha(baseline/'SERVICE_THREAT58.json'),'failed_checks':[k for k,v in old['checks'].items() if not v],'flee_m':old['flee_m'],'max_flee_speed':old['max_flee_speed'],'source_drift':baseline_run['source_drift'],'evidence':evidence},
 'cause':[
  'The original 0/+0.75/-0.75 rad eight-metre goals all point behind the shop wall when the observed shooter is outside its door.',
  'The first unhelpful physical search consumes the intentional shared incident cap: observed service_us29=200935. Subsequent attempts receive zero new queries. This cap is intentional, not reset by this patch.',
  'No renewed observation follows the single shot because QA immediately unequips the pistol; existing RECOVER policy waits for the normal 15-second quiet deadline.'
 ],
 'change':[
  'Two files only; lifecycle selects escape through its existing physical driver.',
  'One candidate per physics frame, five angles at 8m then 4m, at most ten candidates per attempt. Require greater distance from the last observed threat, live floor, actual capsule standing and sweep.',
  'Existing incremental physical planner still verifies all intermediate support; native move_and_slide, masks/exclusions, player/world/door/debris collisions and 1.10 speed remain unchanged.',
  'No directly clear candidate does not prove no path: the original bounded goal remains a planner fallback.',
  'Selection work is charged in addition to monotonically accumulated route work against the same 200000us cap; neither retry nor cancel resets either counter.'
 ],
 'limitations':[
  'The work cap remains an admission bound plus one indivisible query/shared pump, not a hard real-time upper limit.',
  'Preselection executes outside the shared route pump, bounded to one candidate per actor/frame. Simultaneous ten-actor selection and clean FPS have not been measured.',
  'A straight capsule sweep is a route hint only. Moving obstacles can change; actual physical movement remains authoritative.',
  'The isolated unit fixture uses synthetic budget counters on its own driver only; city service tests use unchanged native observers and real purchases.'
 ],
 'production_modified':False,'frozen_release_modified':False,'integrated':False,'performance_accepted':False,
 'runs':{},
}
for name in ['budget01','shop_overlay01','restaurant_overlay01']:
 p=HERE/'runs'/name/'RUN.json'
 if p.exists():
  run=read(p);native=p.parent/('UNIT58.json' if run['case']=='budget' else 'SERVICE_THREAT58.json')
  row={k:run.get(k) for k in ['passed','case','checks','semantic_reason','error','elapsed_seconds','exit_code','stderr_bytes','source_drift','control_drift','harness_drift']}
  row.update(run_sha256=sha(p),native_sha256=sha(native) if native.exists() else None,path=str(p.parent.relative_to(ROOT)))
  if native.exists() and run['case']!='budget':
   data=read(native);row.update({k:data.get(k) for k in ['flee_m','max_flee_speed','max_step_m','fire_sent58','interruption','payment','other_nine_distance_m']})
   row['flee_samples']=[{'ms':s['ms'],'position':s['position'],'driver':s['threat']['driver']} for s in data['samples'] if s['threat'].get('phase')=='FLEE'][:5]
  result['runs'][name]=row
(HERE/'REPORT58.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps({'status':result['status'],'runs':{n:r['passed'] for n,r in result['runs'].items()}}))
