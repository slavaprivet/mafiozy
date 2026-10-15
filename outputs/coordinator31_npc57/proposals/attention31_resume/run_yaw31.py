from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,time,zipfile
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('name');p.add_argument('--candidate',action='store_true');args=p.parse_args()
    project=ROOT/'outputs/coordinator31_npc57/game'
    run=HERE/'runs'/args.name;run.mkdir(parents=True,exist_ok=False)
    sources={str(p.relative_to(project)).replace('\\','/'):sha(p) for p in project.rglob('*') if p.is_file() and '.godot' not in p.parts}
    harness={str(p.relative_to(HERE)).replace('\\','/'):sha(p) for p in HERE.rglob('*') if p.is_file() and 'runs' not in p.parts and p.suffix in ['.gd','.py','.json']}
    save(run/'SOURCE.json',sources);save(run/'HARNESS.json',harness)
    with zipfile.ZipFile(run/'HARNESS.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for rel in harness:archive.write(HERE/rel,rel)
    exe=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    cmd=[str(exe),'--headless','--path',str(project),'--script',str(HERE/'entry_yaw31.gd'),'--','--candidate31='+str(int(args.candidate)),'--qa-out='+str(run)]
    result={'candidate':args.candidate,'project':str(project),'access':'read','command':cmd,'passed':False}
    try:
        with Lease('headless',project,'read',60) as lease:
            started=time.monotonic()
            with (run/'stdout.log').open('wb') as stdout,(run/'stderr.log').open('wb') as stderr:
                child=subprocess.Popen(cmd,cwd=project,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    result['child']=lease.register_child(child)
                    while child.poll() is None:
                        if time.monotonic()-started>120:raise TimeoutError('Owned native child timeout')
                        if (run/'stderr.log').stat().st_size:raise RuntimeError('Native script stderr')
                        time.sleep(.1)
                finally:
                    if child.poll() is None:child.terminate();child.wait(timeout=10)
                result['exit_code']=child.returncode;result['wall_s']=time.monotonic()-started
        result['source_drift']=[rel for rel,expected in sources.items() if sha(project/rel)!=expected]
        result['harness_drift']=[rel for rel,expected in harness.items() if sha(HERE/rel)!=expected]
        result['execution_clean']=child.returncode==0 and not result['source_drift'] and not result['harness_drift'] and not (run/'stderr.log').stat().st_size
        native=json.loads((run/'NATIVE31.json').read_text(encoding='utf-8'))
        result['native_checks']=native['checks'];result['passed']=result['execution_clean'] and all(native['checks'].values())
    except Exception as error:result['error']=type(error).__name__+': '+str(error)
    save(run/'RUN.json',result);print(json.dumps(result))


