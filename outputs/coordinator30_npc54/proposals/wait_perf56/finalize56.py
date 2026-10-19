from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
spec=json.loads((HERE/'PATCH56.json').read_text(encoding='utf-8'))
for file,expected in spec['baseline_sha256'].items():assert sha(ROOT/'outputs/coordinator30_release55/game'/file)==expected
proof={}
for name in ['baseline01','candidate02']:
    p=HERE/'runs'/name
    result=json.loads((p/'RESULT.json').read_text(encoding='utf-8'))
    check=json.loads((p/'RUN_CHECK.json').read_text(encoding='utf-8'))
    engine=json.loads((p/'engine/SCHEDULER_RUN.json').read_text(encoding='utf-8'))
    assert result['passed'] and engine['passed'] and check['exit']==0 and not check['source_drift'] and not check['harness_drift']
    proof[name]={'fixed':result['fixed'],'checks':len(result['checks']),'details':result['details'],'pins':{str(f.relative_to(HERE)):sha(f) for f in [p/'RESULT.json',p/'RUN_CHECK.json',p/'HARNESS.json',p/'SOURCE.json',p/'SOURCE.zip',p/'fixture56.gd',p/'engine/SCHEDULER_RUN.json',p/'engine/stdout.log',p/'engine/stderr.log']}}
assert proof['baseline01']['fixed']==False and proof['candidate02']['fixed']==True
assert (HERE/'runs/baseline01/HARNESS.json').read_bytes()==(HERE/'runs/candidate02/HARNESS.json').read_bytes()
assert (HERE/'runs/baseline01/SOURCE.json').read_bytes()==(HERE/'runs/candidate02/SOURCE.json').read_bytes()
result={'status':'COMPONENT_PASS_FULL_CITY_PENDING','proof':proof,'frozen55_changed':False,'full_city_performance_accepted':False,'full_city_services_accepted':False,'leak_absence_claimed':False,'package_pins':{str(p.relative_to(HERE)):sha(p) for p in [HERE/'PATCH56.json',HERE/'apply56.py',HERE/'build56.py',HERE/'fixture56.gd',HERE/'run56.py',HERE/'HANDOFF56.md',HERE/'patch/scripts/city/runtime/npc_wait_cohort56.gd']}}
(HERE/'ACCEPTANCE56.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'patch_sha256':sha(HERE/'PATCH56.json'),'helper_sha256':sha(HERE/'patch/scripts/city/runtime/npc_wait_cohort56.gd'),'acceptance_sha256':sha(HERE/'ACCEPTANCE56.json')}))
