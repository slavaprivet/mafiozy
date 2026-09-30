from pathlib import Path
import hashlib,json,os,subprocess,time
here=Path(__file__).resolve().parent
root=here.parents[1]
assembly=root/'outputs/coordinator24_npc_delivery/combined25/ASSEMBLY25.json'
manifest=json.loads(assembly.read_text(encoding='utf-8-sig'));game=Path(manifest['game'])
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
expected=manifest['source_pins']
pins=lambda:{p:sha(game/p) for p in expected}
assert pins()==expected
base=game/'scripts/npc_visual/npc_postmortem_bullet_marks.gd'
overlay=here/'files/scripts/npc_visual/npc_postmortem_bullet_marks.gd'
test=here/'test_projection.gd'
out=here/'geometry01';assert not out.exists();out.mkdir()
before={str(p):sha(p) for p in [base,overlay,test]}
engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
cmd=[str(engine),'--headless','--path',str(here),'--script',str(test),'--','--baseline='+str(base),'--proposed='+str(overlay),'--out='+str(out)]
started=time.monotonic()
with (out/'engine.log').open('w',encoding='utf-8') as log:
    proc=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    print(json.dumps({'own_pid':proc.pid,'out':str(out)}),flush=True)
    try:code=proc.wait(timeout=20)
    except subprocess.TimeoutExpired:proc.kill();proc.wait(timeout=5);code=-999
logs=(out/'engine.log').read_text(encoding='utf-8',errors='replace')
record={'exit_code':code,'seconds':time.monotonic()-started,'own_pid':proc.pid,'headless':True,'game_instantiated':False,'GPU_runs':0,'pins_before':before,'pins_after':{str(p):sha(p) for p in [base,overlay,test]},'frozen224_unchanged':pins()==expected,'native_errors':any(s in logs for s in ['SCRIPT ERROR','ERROR:','Parse Error'])}
if (out/'RESULT.json').exists():record['result']=json.loads((out/'RESULT.json').read_text(encoding='utf-8-sig'))
record['passed']=code==0 and not record['native_errors'] and record['frozen224_unchanged'] and record['pins_before']==record['pins_after'] and record.get('result',{}).get('passed',False)
(out/'RUN.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(record,ensure_ascii=False),flush=True)
raise SystemExit(0 if record['passed'] else 1)
