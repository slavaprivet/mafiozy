import hashlib, json, os, pathlib, subprocess, sys, time

HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[3]
PROJECT=HERE/'project'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def pins(): return {p.relative_to(PROJECT).as_posix():sha(p) for p in PROJECT.rglob('*') if p.is_file() and '.godot' not in p.parts and not p.name.endswith('.uid') and not p.name.endswith('.import')}
def save(p,x): p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
    run=HERE/'runs'/sys.argv[1]
    run.mkdir(parents=True,exist_ok=False)
    exe=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    lock=json.loads((ROOT/'docs/godot/ENGINE_LOCK.json').read_text(encoding='utf-8-sig'))
    assert sha(exe)==lock['editor']['gui']['sha256']
    scheduler=ROOT/'tools/godot/test_scheduler.py'
    assert sha(scheduler)=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
    sources=pins(); controls={r:sha(ROOT/r) for r in ['godot/current_version.json','.vscode/launch.json'] if (ROOT/r).exists()}
    record={'source':sources,'control':controls,'engine_sha256':sha(exe),'scheduler_sha256':sha(scheduler),'harness_sha256':sha(pathlib.Path(__file__)),'runs':[],'passed':False}
    save(run/'BEFORE.json',record)
    try:
        for label,access,extra in [('import','write',['--editor','--import','--quit']),('native','read',['--script',str(PROJECT/'proof31.gd'),'--','--out='+str(run/'NATIVE.json')])]:
            command=[str(exe),'--headless','--path',str(PROJECT)]+extra
            child=None
            with Lease('headless',PROJECT,access,60) as lease:
                assert pins()==sources
                one={'label':label,'command':command,'lease':lease.request}
                with (run/(label+'.stdout.log')).open('wb') as out, (run/(label+'.stderr.log')).open('wb') as err:
                    start=time.monotonic()
                    child=subprocess.Popen(command,cwd=PROJECT,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
                    try:
                        one['child']=lease.register_child(child)
                        child.wait(timeout=30)
                    finally:
                        if child.poll() is None: child.terminate();child.wait(timeout=10)
                    one['exit_code']=child.returncode; one['seconds']=time.monotonic()-start
                record['runs'].append(one)
                assert child.returncode==0
                assert (run/(label+'.stderr.log')).stat().st_size==0
        native=json.loads((run/'NATIVE.json').read_text(encoding='utf-8'))
        record['native_sha256']=sha(run/'NATIVE.json');record['checks']=native['checks']
        record['passed']=native['passed']
    except Exception as exc: record['error']=repr(exc)
    finally:
        record['source_drift']=pins()!=sources
        record['control_drift']={r:sha(ROOT/r) for r in controls}!=controls
        record['passed']=record['passed'] and not record['source_drift'] and not record['control_drift']
        save(run/'RUN.json',record)
    print(json.dumps({k:record.get(k) for k in ['passed','checks','error','source_drift','control_drift']}))

if __name__=='__main__': main()
