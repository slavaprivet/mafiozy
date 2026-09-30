from pathlib import Path
import subprocess,json,time,hashlib,sys
b=Path(__file__).resolve().parent;case=sys.argv[1];o=b/sys.argv[2];assert not o.exists();o.mkdir();engine=Path.home()/'AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();files=['scripts/npc_visual/npc_local_preview_hit_owner.gd','scripts/npc_visual/npc_blood_adapter.gd','scripts/npc_visual/npc_blood_renderer.gd'];before={n:sha(b/'stage'/n) for n in files};cmd=[str(engine),'--headless','--path',str(b/'stage'),'--script',str(b/'test_actual_blood.gd'),'--','--case='+case,'--qa-out='+str(o)];t=time.monotonic()
with (o/'engine.log').open('w',encoding='utf-8') as log:
 try:result={'exit_code':subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=30).returncode}
 except subprocess.TimeoutExpired:result={'timeout':30}
result.update(seconds=time.monotonic()-t,before=before,after={n:sha(b/'stage'/n) for n in files},command=cmd,harness_sha256=sha(b/'test_actual_blood.gd'));(o/'RUN.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8');print(json.dumps(result,ensure_ascii=True));print((o/'engine.log').read_text(encoding='utf-8-sig')[-2000:])
