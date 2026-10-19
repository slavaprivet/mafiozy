from pathlib import Path
import hashlib, importlib.util, json, subprocess, sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3];GAME=HERE.parent.parent/'game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
exitpatch=HERE.parent/'services_city56/exit_patch56'
threat=HERE.parent/'threat_order56'
assert read(exitpatch/'COMPONENT.json')['passed']
for mode in ['baseline04','candidate04']:
    run=threat/'runs'/mode
    assert read(run/'RESULT.json')['passed']
    receipt=read(run/'RUN_CHECK.json');engine=read(run/'engine/SCHEDULER_RUN.json')
    assert receipt['exit']==0 and not receipt['source_drift'] and not receipt['harness_drift']
    assert engine['exit_code']==0 and engine['stderr_bytes']==0 and not engine['errors']
    for file,h in read(run/'HARNESS.json').items():assert sha(threat/file)==h, 'Harness changed after native proof: '+file
record={'changes':{},'evidence':['services_city56/exit_patch56/COMPONENT.json','threat_order56/runs/candidate04/RESULT.json']}
with Lease('headless',GAME,'write',30):
    f=GAME/'scripts/hospital/npc_simple_hospital.gd';before=sha(f)
    subprocess.run([sys.executable,'-B',str(exitpatch/'apply.py'),'--project',str(GAME),'--apply'],cwd=ROOT,check=True)
    record['changes']['scripts/hospital/npc_simple_hospital.gd']={'before':before,'after':sha(f)}
    spec=importlib.util.spec_from_file_location('threat_order56_apply',threat/'apply56.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    f=GAME/'scripts/city/runtime/npc_threat_life30.gd';before=sha(f)
    module.apply_to(GAME)
    record['changes']['scripts/city/runtime/npc_threat_life30.gd']={'before':before,'after':sha(f)}
    assert sha(f)==read(threat/'runs/candidate04/SOURCE.json')['scripts/city/runtime/npc_threat_life30.gd']
(HERE/'BEHAVIOR_INTEGRATION.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(json.dumps(record))
