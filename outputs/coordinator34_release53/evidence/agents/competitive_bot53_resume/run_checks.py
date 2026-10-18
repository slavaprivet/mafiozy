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
jobs=[('mobility04',G,'mobility.gd',[]),('chase04',G,'chase.gd',['--case=chase']),('retreat04',G,'chase.gd',['--case=retreat']),('detour04',G,'chase.gd',['--case=detour'])]
for scenario in ['weave','rush','diagonal']:
 for label,project in [('52',Path('D:/MafioziCombat31/coordinator33/game')),('04',G)]:
  jobs.append(('moving_'+scenario+'_'+label,project,'moving.gd',['--scenario='+scenario]))
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(run,jobs))
(O/'SUITE.json').write_text(json.dumps(rows,indent=2))
assert hashlib.sha256((G/'scripts/weapons/sword_prototype.gd').read_bytes()).hexdigest()==PIN
