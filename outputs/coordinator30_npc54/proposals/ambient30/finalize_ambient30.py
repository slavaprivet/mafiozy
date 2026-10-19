from pathlib import Path
import hashlib,json
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,value):(OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
suite=read(OUT/'CONTRACT_SUITE30.json');assert suite['passed']
names=['candidate03','visual01','visual02','full18_01']+[r['name'] for r in suite['runs']]
for name in names:
    run=OUT/'runs'/name;assert read(run/'RESULT.json')['passed'],name
    assert (run/'import/stderr.log').stat().st_size==0,name+' import stderr'
    assert (run/'native/stderr.log').stat().st_size==0,name+' native stderr'
pins=read(OUT/'BASE_AMBIENT30.json')
for name in ['visual02','full18_01']+[r['name'] for r in suite['runs']]:
    ready=read(OUT/'runs'/name/'PROJECT_READY_PINS.json')
    assert all(ready[k]==v['proposed_sha256']==sha(OUT/k) for k,v in pins.items()),name
full=read(OUT/'runs/full18_01/observed/AMBIENT_FIXTURE29.json')
counts={event:sum(r['event']==event for r in full['rows']) for event in ['begin','ended','walk_resumed']}
assert all(count==18 for count in counts.values())
assert not full['failures'] and full['max_bench_contact_error30']<.01 and full['max_dock_error30']<.01
slots=read(OUT/'runs/slots02/observed/BENCH_SLOTS29.json');assert slots['pass']
slot_count=sum('pass' in row for row in slots['checks'])
visual={
 'status':'RENDERED_SCOPED_PASS',
 'reviewed_images':['runs/visual01/observed/01_collar_front.png','runs/visual01/observed/01_collar_side.png','runs/visual02/observed/00_pocket_front.png','runs/visual02/observed/00_pocket_side.png','runs/visual02/observed/00_pocket_hands.png','runs/visual02/observed/01_phone_hands.png','runs/visual02/observed/01_phone_screen.png','runs/visual02/observed/01_phone_side.png','runs/visual02/observed/02_bench_front.png','runs/visual02/observed/02_bench_side.png'],
 'findings':['Collar hands and cuffs visible in front of jacket; no hand inside torso in front/side views.','Pocket palm placed at jacket pocket height using actual hip joints, outside torso in side/close views.','Phone held ahead of chest, screen faces actor and is visible over shoulder; right hand makes repeated 0.65-second tapping motion. Native prop ownership hides/releases after action.','Bench hips rest on front seat plank, knees forward, soles down, feet naturally hanging because canonical legs are short. No bench penetration visible.'],
 'limits':['Rendered resident_1 appearance only. Other 14 activities have native regression coverage, not new visual acceptance.','Collar images use visual01. The final visual02 change only adjusts pocket and phone targets; collar branch and palm/hand solvers are byte-identical.','Screenshots are sampled views; no claim of exact mesh collision testing for every interpolated vertex.','No full city or comparable performance acceptance.']}
save('VISUAL_REVIEW30.json',visual)
report={'status':'READY_SCOPED_NATIVE_AND_RENDERED','runtime_files':5,'host_changed':False,'population_changed':False,'actual_residents_in_pose_fixture':1,'activities':18,'completed_counts':counts,'bench_foot_target_error_m':full['max_bench_contact_error30'],'bench_hip_seat_error_m':full['max_dock_error30'],'max_physical_step_m':full['max_body_step30'],'standing_to_sitting_foot_travel_m':full['max_foot_error30'],'slot_contract_checks':slot_count,'contract_runs':suite['runs'],'passing_runs':names,'source_drift':False,'stderr_bytes':0,'graphical_review':'VISUAL_REVIEW30.json','native_seed_policy':'Fixture chooses real RNG seeds; production remains random. No forced runtime pose or teleport.','shared_game_modified':False,'performance_accepted':False,'integration_next':'Root apply under game54 write lease, city injury/death/ambient/route regression, comparable performance acceptance.'}
save('REVIEW_AMBIENT30.json',report)
files={}
for p in OUT.rglob('*'):
    if not p.is_file() or p.name=='MANIFEST_AMBIENT30.json' or '__pycache__' in p.parts:continue
    rel=p.relative_to(OUT)
    if 'runs' in rel.parts:
        if rel.parts[1] not in names or any(part in ['project','PREVIOUS_SOURCES','TESTED_SOURCES'] for part in rel.parts):continue
    files[rel.as_posix()]=sha(p)
save('MANIFEST_AMBIENT30.json',{'status':report['status'],'files':files,'runtime':pins,'freeze_scope':'Package sources and accepted receipts. Excludes reusable generated QA project and failed experiments; original failed receipts remain on disk.','old29_preserved':True})
print(json.dumps({'status':report['status'],'manifest_files':len(files),'slot_checks':slot_count,'counts':counts}))
