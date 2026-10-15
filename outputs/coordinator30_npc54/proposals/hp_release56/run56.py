"""Small native component, one reusable dependency-only project, scheduler only."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,zipfile
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE=ROOT/'outputs/coordinator30_release55/game'
PROJECT=HERE/'native_project'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
from apply56 import apply_to
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pins(p):return {f.relative_to(p).as_posix():sha(f) for f in p.rglob('*') if f.is_file() and '.godot' not in f.parts}
def stage(fixed):
    PROJECT.mkdir(parents=True,exist_ok=True)
    with Lease('headless',PROJECT,'write',30):
        todo=['scripts/npc_daily_life.gd','scripts/npc_visual/npc_resident_diag.gd'];seen=set()
        while todo:
            rel=todo.pop()
            if rel in seen:continue
            source=BASE/rel;seen.add(rel);dest=PROJECT/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
            if source.suffix=='.gd':
                text=source.read_text(encoding='utf-8-sig')
                for dep in re.findall(r'(?:preload|load)\("([^"]+)"\)',text)+re.findall(r'^extends\s+"([^"]+)"',text,re.M):
                    if dep.startswith('res://'):new=dep[6:]
                    elif not dep.startswith(('user://','uid://')):new=(Path(rel).parent/dep).as_posix()
                    else:continue
                    if new not in seen:todo.append(new)
        if fixed:apply_to(PROJECT)
        (PROJECT/'project.godot').write_text('[application]\nconfig/name="HP release56 native fixture"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
        return len(seen)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('name');p.add_argument('--baseline',action='store_true');a=p.parse_args()
    out=HERE/'runs'/a.name;out.mkdir(parents=True,exist_ok=False)
    dependencies=stage(not a.baseline);before=pins(PROJECT)
    harness={n:sha(HERE/n) for n in ['fixture56.gd','run56.py','PATCH56.json','apply56.py']}
    (out/'SOURCE.json').write_text(json.dumps(before,indent=2),encoding='utf-8');(out/'HARNESS.json').write_text(json.dumps(harness,indent=2),encoding='utf-8');shutil.copy2(HERE/'fixture56.gd',out/'fixture56.gd')
    with zipfile.ZipFile(out/'SOURCE.zip','w',zipfile.ZIP_DEFLATED) as z:
        for f in before:z.write(PROJECT/f,f)
    exe=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    cmd=[sys.executable,'-B',str(ROOT/'tools/godot/test_scheduler.py'),'run','--mode','headless','--project',str(PROJECT),'--wait-seconds','30','--timeout','40','--out',str(out/'engine'),'--',str(exe),'--headless','--path',str(PROJECT),'--script',str(HERE/'fixture56.gd'),'--','--qa-out='+str(out),'--city-simple-hospital=1']
    run=subprocess.run(cmd,cwd=ROOT,capture_output=True);(out/'scheduler.stdout.log').write_bytes(run.stdout);(out/'scheduler.stderr.log').write_bytes(run.stderr)
    after=pins(PROJECT);result={'exit':run.returncode,'dependencies':dependencies,'baseline':a.baseline,'source_drift':[k for k in set(before)|set(after) if before.get(k)!=after.get(k)],'harness_drift':[k for k,v in harness.items() if sha(HERE/k)!=v],'performance_accepted':False}
    (out/'RUN_CHECK.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result));sys.exit(run.returncode or bool(result['source_drift']) or bool(result['harness_drift']))
