from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
native=read(HERE/'runs/benches02/BENCHES58.json')
valid=[]
for sample in native['samples']:
    actor=sample['residents']['resident_5'];a=actor['ambient']
    if a.get('active') is True and a.get('kind')=='bench' and a.get('pose_frames',0)>8 and a.get('bench_slot',{}).get('body_id')==native['rows']['resident_5']['body_id']:
        valid.append({'elapsed_ms':sample['elapsed_ms'],'position':actor['position'],'phase':a['phase'],'pose_frames':a['pose_frames'],'bench_slot':a['bench_slot']})
assert valid
files=['PATCH_FOR_ROOT.json','BENCH_PATCH_FOR_ROOT.json','PATCH.json','runs/benches02/RUN.json','runs/benches02/SCHEDULER_RUN.json','runs/benches02/BENCHES58.json','runs/benches02/HARNESS.zip','runs/benches02/CONTROL_PINS.json','policy_projects/policy03/POLICY58.json']
report={
 'schema':'logical_routines58_handoff_v1','status':'SCOPED_NATIVE_PASS_READY_FOR_ROOT_MERGE','production_edited':False,'own_native_processes_active':False,
 'integration':{'core_manifest':'PATCH_FOR_ROOT.json','core_files':8,'bench_manifest':'BENCH_PATCH_FOR_ROOT.json','bench_files':1,'all_candidate_files_root':'patch','bench_native_input_root':'bench_patch','main_call':'load("res://scripts/homes/npc_home_benches58.gd").install(self, preview_homes58.current_sites()) after successful home prepare','base':'extended31/stage58_05/CANDIDATE58.json','base_manifest_sha256':'d5adfedbd8d1920b4544440928f8c5e2b0c52672e360d15be8ec1c3b3b28720d'},
 'behavior':['Existing 90 minute shared clock; manual N keeps same day, natural midnight advances day tickets.','Individual meal, supplies, home rest and sleep windows. Actual service controller still owns payment and physical entry/exit.','Scheduled purchase survives interruptions and overnight home; three venue failures defer 45 seconds without losing price/ticket.','Actual low energy, injury, threat and death retain priority; home keeps physical motion ownership until actual exit.','Random world roaming replaced by bounded selection of actual supported real benches; random ambient acts and pauses retained.','HOME/sleep and supported rest dispatched every physics tick, independent of paused game clock.','Four street benches use exact existing six mesh OriginalBench support and seat registry, 9 total below limit16.'],
 'verification':{'policy03':{'passed':True,'checks':26},'native_latest_parse':'All eight sealed routine scripts compile at original resource paths in benches02 entry.','benches02':read(HERE/'runs/benches02/RUN.json'),'resident5':{'travel_m':native['rows']['resident_5']['travel'],'max_physics_step_m':native['rows']['resident_5']['max_step'],'actual_bench':native['rows']['resident_5']['seated_bench_path'],'first_live_seated_sample':valid[0],'last_live_seated_sample':valid[-1]}},
 'preserved_failures':[{'run':'runs/parse01','reason':'Initial overlay lacked VFS entries for new preload resources; fixed by isolated resource pack.'},{'run':'runs/leisure01','reason':'Five old benches did not cover original night-walker spawn positions within unchanged120m; no actual leisure goal, reported FAIL.'},{'run':'runs/benches01','reason':'Observer called nonexistent SimpleHospital.snapshot during route; scheduler/RUN FAIL despite raw behavior checks. Fixed observer v2 uses supported accessors; old receipt preserved.'}],
 'pending':['Combined stage06 compile and runtime after root integrates player shop and character delta.','Full actual late resident2/7 sleep→physical exit→night bench cycle, to run on merged build per latest root request. Prepared night overlay remains unexecuted and pinned to obsolete stage05; adapt NEW merged runner before use.','Long ordinary merged behavior and comparable exclusive performance; current functional receipt is not FPS acceptance.'],
 'evidence_pins':{f:sha(HERE/f) for f in files}}
target=HERE/'ROOT_HANDOFF.json';assert not target.exists();target.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps({'handoff':str(target),'sha256':sha(target),'live_seated_samples':len(valid),'first_live_pose_frames':valid[0]['pose_frames'],'last_live_pose_frames':valid[-1]['pose_frames']}))
