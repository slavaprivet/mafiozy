from pathlib import Path
import subprocess,sys,json,hashlib,concurrent.futures
O=Path('D:/MafioziCombat31/competitive_bot53_resume');G=O/'game';Q=O/'qa';R=Path('C:/Users/Слава/Desktop/Мафиози');E='C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
PIN=hashlib.sha256((G/'scripts/weapons/sword_prototype.gd').read_bytes()).hexdigest()
def run(job):
 name,project,script,args=job;out=O/name;out.mkdir(exist_ok=False);result=out/'result.json'
 cmd=[sys.executable,str(R/'tools/godot/test_scheduler.py'),'run','--mode','headless','--project',str(project),'--timeout','110','--out',str(out/'native'),'--',E,'--headless','--path',str(project),'--script',str(Q/script),'--','--qa-out='+str(out)]+args
 p=subprocess.run(cmd,capture_output=True);(out/'runner.log').write_bytes(p.stdout+p.stderr)
 raw=json.loads(result.read_text(encoding='utf-8-sig')) if result.exists() else {}
 scheduler=json.loads((out/'native/SCHEDULER_RUN.json').read_text(encoding='utf-8-sig'))
 row=dict(name=name,scheduler=scheduler.get('passed'),passed=raw.get('passed'),errors=raw.get('errors',[]),source_pin=hashlib.sha256((project/'scripts/weapons/sword_prototype.gd').read_bytes()).hexdigest(),result=str(result))
 print(json.dumps(row),flush=True);return row
rows=[run(('mobility_diag04',G,'mobility_diag.gd',[]))]
