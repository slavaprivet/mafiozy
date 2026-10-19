"""Independent read-only audit of immutable stage05 component receipts."""
import hashlib,json,math,zipfile
from pathlib import Path
H=Path(__file__).resolve().parent
R=H.parents[3]
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):
    assert not p.exists(),p
    p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def proof(run):
    receipt=read(run/'RUN.json');before=read(run/'CONTROL_PINS.json');after=read(run/'CONTROL_PINS_AFTER.json')
    stage=read(R/'outputs/coordinator31_npc57/extended31/stage58_05/CANDIDATE58.json')['source_pins']
    zipped={}
    with zipfile.ZipFile(run/'HARNESS.zip') as z:
        for name in z.namelist():zipped[str((R/name).resolve())]=hashlib.sha256(z.read(name)).hexdigest()
    return {'receipt_passed':receipt['passed'],'source_exact_stage05':read(run/'SOURCE.json')==read(run/'SOURCE_AFTER.json')==stage,'controls_before_after_equal':before==after,'archived_control_bytes_match':all(zipped.get(k)==v for k,v in before.items()),'stderr_empty':(run/'stderr.log').stat().st_size==0,'wall_s':receipt.get('wall_s'),'run_sha256':sha(run/'RUN.json'),'harness_zip_sha256':sha(run/'HARNESS.zip')}
damage=H/'runs/home_damage02';d=read(damage/'GEOMETRY58.json');c=d['component'];b=d['c4_blast'];event=b['snapshot']['events'][0]
summary={'proof':proof(damage),'checks_passed':sum(x['ok'] for x in d['checks']),'checks_total':len(d['checks']),'real_input_lmb_frames':d['c4_placed']['physics_frames'],'physical_charge_consumed':event['physical_charge_consumed'],'released_sections':len(event['released']),'bed_detached':b['bed_detached'],'bed_layer':b['bed_layer'],'bed_travel_m':b['bed_travel_m'],'sleep_cancel_ticks':c['sleep_cancel_frame']-c['damage_trigger_frame'],'exit_ticks_after_trigger':c['exit_frame']-c['damage_trigger_frame'],'max_required_idle_s':c['max_required_idle_s'],'final_home':c['home'],'native_png_companion':str(H/'runs/home_damage01/sleep_resident3_native.png'),'png_sha256':sha(H/'runs/home_damage01/sleep_resident3_native.png'),'boundary':'Native component intent for original resident3, no NPC teleport. PNG is separate exact stage05 graphical01; actual C4 destruction02 is headless. No threat/injury/death or ordinary whole-day claim.'}
save(H/'AUDIT_HOME_DAMAGE02.json',summary)
cycle=H.parent/'homes58/runs/native_cycle02';data=read(cycle/'HOME_CYCLE58.json');prior=read(H.parent/'homes58/audits/native_cycle02/AUDIT58.json')
anchors={};start={};previous={};maxidle={};stale_rest=[];all_ids=set();phases={};timing=[]
for sample in data['samples']:
    now=sample['t'];frame=sample['frame'];timing.append((now,frame))
    for row in sample['actors']:
        ident=row['source_id'];all_ids.add(ident);p=row['position'];phase=row['phase'];phases[phase]=phases.get(phase,0)+1
        # This fixture samples pre-host: the valid previous pose is one tick old.
        committed=row['pose_committed_frame']>=frame-1
        rest=phase in ['HOME_SLEEP','HOME_REST','HOME_SETTLE'] and row['claim_current'] and row['support_current'] and committed
        if phase in ['HOME_SLEEP','HOME_REST'] and row['support_current'] and row['claim_current'] and not committed:stale_rest.append({'id':ident,'frame':frame,'pose':row['pose_committed_frame']})
        required=not rest and not row['actual_exit']
        if not required or ident not in previous or now-previous[ident]>2.5:anchors[ident]=p;start[ident]=now
        elif math.dist((p[0],p[2]),(anchors[ident][0],anchors[ident][2]))>=.1:anchors[ident]=p;start[ident]=now
        maxidle[ident]=max(maxidle.get(ident,0),now-start[ident]);previous[ident]=now
summary={'proof':proof(cycle),'raw_sha256':sha(cycle/'HOME_CYCLE58.json'),'source_ids':sorted(all_ids),'native_physics_rate':(timing[-1][1]-timing[0][1])/(timing[-1][0]-timing[0][0]),'native_checks_passed':sum(x['ok'] for x in data['checks']),'native_checks_count':len(data['checks']),'sleep_count':sum(x['ever_sleep'] for x in data['final']),'exit_count':sum(x['actual_exit'] for x in data['final']),'max_motion_idle_s_with_pose_commit_gate':maxidle,'motion_failure_ids':[k for k,v in maxidle.items() if v>10],'stale_sleep_commit_samples':stale_rest,'spatial_prior_audit_passed':prior['spatial_passed'],'independent_conclusion':'FAIL resident6 still independently confirmed; other9 actual sleep/exit, no pose exemption with stale sleep commits in raw. Source/control proof valid. Not ordinary routine acceptance.','future_gate_requirement':'Always require current pose commit as well as support/claim for SLEEP/REST exemption. Existing derived audit omits commit field, but current raw has no stale SLEEP/REST commits. Nested V2 service_watch/avoidance aliases cannot establish historical causes.'}
save(H/'INDEPENDENT_CYCLE02.json',summary)
print(json.dumps({'damage':summary['proof'],'cycle_motion_failure_ids':summary['motion_failure_ids'],'stale_rest_count':len(stale_rest),'native_physics_rate':summary['native_physics_rate']},ensure_ascii=True))
