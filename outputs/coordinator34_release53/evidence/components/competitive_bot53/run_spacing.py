from pathlib import Path
import subprocess,sys,json,hashlib,concurrent.futures
O=Path('D:/MafioziCombat31/competitive_bot53');G=O/'game';Q=O/'qa';R=Path('C:/Users/Слава/Desktop/Мафиози');E='C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
pins=json.loads((O/'BASE.json').read_text())['source_pins']
def run(job):
 name,script,mode,args,directory=job;out=O/name;out.mkdir(exist_ok=True);result=out/('RESULT.json' if name in ['spear_high','soil_graphical'] else 'result.json')
 cmd=[sys.executable,str(R/'tools/godot/test_scheduler.py'),'run','--mode',mode,'--project',str(G),'--timeout','180','--out',str(out/'native'),'--',E]+(['--headless'] if mode=='headless' else [])+['--path',str(G),'--script',str(Q/script),'--','--qa-out='+str(out if directory else result)]+args
 p=subprocess.run(cmd,capture_output=True);(out/'runner.log').write_bytes(p.stdout+p.stderr)
 raw=json.loads(result.read_text(encoding='utf-8-sig')) if result.exists() else {}
 scheduler=json.loads((out/'native/SCHEDULER_RUN.json').read_text(encoding='utf-8-sig'))
 drift=[r for r,h in pins.items() if hashlib.sha256((G/r).read_bytes()).hexdigest()!=h]
 row=dict(name=name,scheduler=scheduler.get('passed'),passed=raw.get('passed',raw.get('pass')),errors=raw.get('errors',[]),drift=drift,result=str(result));print(json.dumps(row),flush=True);return row

jobs=[('moving_spacing03','moving.gd','headless',[],True),('retreat_spacing03','chase.gd','headless',['--case=retreat'],True),('detour_spacing03','chase.gd','headless',['--case=detour'],True)]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool: rows=list(pool.map(run,jobs))
(O/'SPACING_SUITE.json').write_text(json.dumps(rows,indent=2))
