from pathlib import Path
import json,hashlib,subprocess,time
O=Path('outputs/coordinator23_head_merge07').resolve();S=O/'stage'
pins=json.loads((O/'STAGE_INPUTS.json').read_text());assert all(hashlib.sha256((S/p).read_bytes()).hexdigest()==h for p,h in pins.items())
engine=Path('C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe')
cmd=[str(engine),'--headless','--path',str(S),'--fixed-fps','60','--script',str(O/'active_head_followup.gd')]
start=time.monotonic()
with (O/'active_head01.log').open('w',encoding='utf8') as log:
 try:
  result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=45);status={'exit_code':result.returncode}
 except subprocess.TimeoutExpired:status={'timeout':45}
status.update(seconds=time.monotonic()-start,command=cmd,test_sha256=hashlib.sha256((O/'active_head_followup.gd').read_bytes()).hexdigest(),stage_pins_sha256=hashlib.sha256((O/'STAGE_INPUTS.json').read_bytes()).hexdigest())
(O/'ACTIVE_RUN01.json').write_text(json.dumps(status,indent=2)+'\n',encoding='utf8');print(json.dumps(status))
