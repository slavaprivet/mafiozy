from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, zipfile
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE=ROOT/'outputs/coordinator30_release55/game'
PROJECT=HERE/'native_project'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
from apply56 import apply_to

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def pins(path):return {p.relative_to(path).as_posix():sha(p) for p in path.rglob('*') if p.is_file() and '.godot' not in p.parts}
def stage(fixed):
    PROJECT.mkdir(parents=True,exist_ok=True)
    with Lease('headless',PROJECT,'write',30):
        todo=['scripts/shop/npc_local_account.gd','scripts/npc_daily_life.gd','scripts/npc_city_daily.gd']
        seen=set()
        while todo:
            rel=todo.pop()
            if rel in seen:continue
            source=BASE/rel
            if not source.is_file():raise RuntimeError('Missing dependency '+rel)
            seen.add(rel);dest=PROJECT/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
            if source.suffix=='.gd':
                text=source.read_text(encoding='utf-8-sig')
                deps=re.findall(r'(?:preload|load)\("([^"]+)"\)',text)+re.findall(r'^extends\s+"([^"]+)"',text,re.M)
                for dep in deps:
                    if dep.startswith('res://'):new=dep[6:]
                    elif not dep.startswith(('user://','uid://')):new=(Path(rel).parent/dep).as_posix()
                    else:continue
                    if new not in seen:todo.append(new)
        if fixed:apply_to(PROJECT)
        (PROJECT/'project.godot').write_text('[application]\nconfig/name="Stalls56 contract fixture"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
        return len(seen)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('name');parser.add_argument('--fixed',action='store_true');args=parser.parse_args()
    out=HERE/'runs'/args.name;out.mkdir(parents=True,exist_ok=False)
    dependencies=stage(args.fixed);before=pins(PROJECT);harness={p.name:sha(p) for p in [HERE/'fixture56.gd',HERE/'run56.py',HERE/'PATCH56.json',HERE/'apply56.py']}
    (out/'SOURCE.json').write_text(json.dumps(before,indent=2),encoding='utf-8');(out/'HARNESS.json').write_text(json.dumps(harness,indent=2),encoding='utf-8')
    shutil.copy2(HERE/'fixture56.gd',out/'fixture56.gd')
    with zipfile.ZipFile(out/'SOURCE.zip','w',zipfile.ZIP_DEFLATED) as z:
        for f in before:z.write(PROJECT/f,f)
    exe=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    cmd=[sys.executable,'-B',str(ROOT/'tools/godot/test_scheduler.py'),'run','--mode','headless','--project',str(PROJECT),'--wait-seconds','30','--timeout','30','--out',str(out/'engine'),'--',str(exe),'--headless','--path',str(PROJECT),'--script',str(HERE/'fixture56.gd'),'--','--city-simple-hospital=1','--qa-out='+str(out),'--expect-fixed='+str(int(args.fixed))]
    run=subprocess.run(cmd,cwd=ROOT,capture_output=True);(out/'scheduler.stdout.log').write_bytes(run.stdout);(out/'scheduler.stderr.log').write_bytes(run.stderr)
    after=pins(PROJECT);result={'exit':run.returncode,'dependencies':dependencies,'source_drift':[k for k in set(before)|set(after) if before.get(k)!=after.get(k)],'harness_drift':[k for k,v in harness.items() if sha(HERE/k)!=v],'performance_accepted':False}
    (out/'RUN_CHECK.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result))
    sys.exit(run.returncode or bool(result['source_drift']) or bool(result['harness_drift']))
