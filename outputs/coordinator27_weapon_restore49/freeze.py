from pathlib import Path
import hashlib,json,subprocess,sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
SHA=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,data):p.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
run=json.loads((HERE/'runs/native09/RUN.json').read_text(encoding='utf-8'))
assert run['passed'] and run['source_pins_before_after'] and run['parent_replay_rejected']
base=json.loads((ROOT/'outputs/coordinator27_release48/ACCEPTED_ASSEMBLY.json').read_text(encoding='utf-8'))
for n,d in base['source_pins'].items():assert SHA(Path(base['game'])/n)==d
for n,d in run['candidate_pins'].items():assert SHA(HERE/'game'/n)==d
for n,d in run['helper_pins'].items():assert SHA(HERE/n)==d
status=subprocess.check_output([sys.executable,'-B',str(ROOT/'tools/godot/test_scheduler.py'),'status'],cwd=ROOT)
(HERE/'FINAL_SCHEDULER_STATUS.json').write_bytes(status)
summary={'status':'PRIVATE_NATIVE_WEAPON_RESTORE_PASS','production_accepted':False,'performance_accepted':False,'checks':sum(c['result']['checks'] for c in run['children']),'items':14,'ammo_before_shots':896,'ammo_after_save_restore':894,'server_grants':0,'restored_item_uid_mints':0,'clock_policy':'LOCAL_OFFLINE_FREEZE','run':'runs/native09/RUN.json','run_sha256':SHA(HERE/'runs/native09/RUN.json'),'phases':[{'phase':c['phase'],'checks':c['result']['checks'],'pid':c['result']['process_id'],'queue_wait_seconds':c['lease']['queue_wait_seconds'],'stderr_bytes':c['stderr_bytes']} for c in run['children']],'scope':'weapon inventory+ground+cargo only; no full gameplay or server save adoption','base_sha256':run['base_sha256'],'engine_sha256':run['engine_sha256'],'scheduler_sha256':run['scheduler_sha256'],'checkpoint_v2_upstream_sha256':'217669b4fb6782e745e584dadf69aa6c7bff0af733c4924e8da6d6de4d4bb11b'}
save(HERE/'REVIEW.json',summary)
pins={}
for p in HERE.rglob('*'):
    if not p.is_file() or 'game' in p.relative_to(HERE).parts or p.name=='EVIDENCE_FREEZE.json':continue
    pins[str(p.relative_to(HERE)).replace('\\','/')]=SHA(p)
save(HERE/'EVIDENCE_FREEZE.json',{'scope':'private restore49; original failed runs retained','files':pins,'count':len(pins),'production_accepted':False})
print(json.dumps({'count':len(pins),'freeze_sha256':SHA(HERE/'EVIDENCE_FREEZE.json'),'review_sha256':SHA(HERE/'REVIEW.json')}))
