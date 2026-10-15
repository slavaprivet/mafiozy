import hashlib,json,zipfile,math
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parents[3]
run=H.parent/'home_approach58/runs/native_cycle_candidate01'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
n=read(run/'HOME_CYCLE58.json');receipt=read(run/'RUN.json');stage=read(R/'outputs/coordinator31_npc57/extended31/stage58_06/CANDIDATE58.json')
cp=read(run/'CONTROL_PINS.json');archive={}
with zipfile.ZipFile(run/'HARNESS.zip') as z:
    for p in z.namelist():archive[str((R/p).resolve())]=hashlib.sha256(z.read(p)).hexdigest()
overlay=read(run/'OVERLAY.json')
with zipfile.ZipFile(run/'OVERLAY.zip') as z:overlay_ok={k:hashlib.sha256(z.read(k)).hexdigest()==v for k,v in overlay.items()}
last={};anchor={};since={};max_idle={};stale=[];six=[];ids=set()
for s in n['samples']:
    for a in s['actors']:
        key=a['source_id'];ids.add(key);t=s['t'];p=a['position']
        rest=a['phase'] in ['HOME_SETTLE','HOME_SLEEP','HOME_REST'] and a['support_current'] and a['claim_current'] and a['pose_committed_frame']>=s['frame']-1
        required=not rest and not a['actual_exit']
        if not required or key not in last or t-last[key]>2.5:anchor[key]=p;since[key]=t
        elif math.dist((p[0],p[2]),(anchor[key][0],anchor[key][2]))>=.1:anchor[key]=p;since[key]=t
        max_idle[key]=max(max_idle.get(key,0),t-since[key]);last[key]=t
        if a['phase']=='HOME_SLEEP' and not rest:stale.append({'id':key,'at':t})
        if key=='resident_6':six.append({'at_s':t,'frame':s['frame'],'phase':a['phase'],'position':p,'work_us':a['planning_service_us'],'travel_m':a['travel_m']})
final6=next(a for a in n['final'] if a['source_id']=='resident_6')
checks={'source_exact_stage06':read(run/'SOURCE.json')==read(run/'SOURCE_AFTER.json')==stage['source_pins'],'control_unchanged':cp==read(run/'CONTROL_PINS_AFTER.json'),'archived_control_bytes':all(archive.get(k)==v for k,v in cp.items()),'exact_two_overlay_files':len(overlay)==2 and all(overlay_ok.values()),'native55':len(n['checks'])==55 and all(x['ok'] for x in n['checks']),'ten_sleep_exit':len(ids)==10 and all(a['ever_sleep'] and a['actual_exit'] for a in n['final']),'motion10':all(v<=10 for v in max_idle.values()),'live_sleep_pose':not stale,'resident6_budget_monotonic':all(b['work_us']>=a['work_us'] for a,b in zip(six,six[1:])),'resident6_budget_bounded':final6['planning_service_us']<500000,'stderr0':(run/'stderr.log').stat().st_size==0}
result={'passed':all(checks.values()) and receipt['passed'],'checks':checks,'raw_sha256':sha(run/'HOME_CYCLE58.json'),'run_sha256':sha(run/'RUN.json'),'harness_sha256':sha(run/'HARNESS.zip'),'overlay_pins':overlay,'max_motion_idle_s':max_idle,'resident6_final':{k:final6[k] for k in ['start','position','travel_m','max_step_m','planning_service_us','ever_sleep','actual_exit']},'resident6_first_sleep_s':next((a['at_s'] for a in six if a['phase']=='HOME_SLEEP'),None),'resident6_work_history':six,'scope':'Independent exact stage06+twofile overlay all10 component. Does not replace merged07 natural acceptance.'}
out=H/'INDEPENDENT_HOME_APPROACH58.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ['resident6_work_history']},ensure_ascii=True))
