"""Read-only actual-city ten-resident threat cycle, scheduler headless only."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,time,zipfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease,probe,ERRORS
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pins(p):return {f.relative_to(p).as_posix():sha(f) for f in p.rglob('*') if f.is_file() and '.godot' not in f.parts}
def save(p,value):p.write_text(json.dumps(value,indent=2,ensure_ascii=False),encoding='utf-8')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('name');p.add_argument('--game',type=Path,default=HERE.parent.parent/'game');p.add_argument('--go',action='store_true');a=p.parse_args()
    game=a.game.resolve();out=HERE/'runs'/a.name
    flags=json.loads((ROOT/'outputs/coordinator30_release55/ASSEMBLY.json').read_text(encoding='utf-8-sig'))['launch_arguments']
    flags=[f for f in flags if not f.startswith(('--qa-','--city-qa=','--city-resident-name=','--city-quit-after=','--city-pose-far-cap='))]
    flags+=['--city-qa=10','--city-pose-far-cap=512','--qa-out='+str(out)]
    required=['--city-simple-hospital=1','--city-venue-sites29=1','--city-venue-staff29=1','--city-hp=100','--city-threat30=1','--city-physical-dispatch30=1','--city-multi-lifecycle30=1']
    assert all(f in flags for f in required)
    exe=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    command=[str(exe),'--headless','--path',str(game),'--script',str(HERE/'entry56.gd'),'--',*flags]
    if not a.go:print(json.dumps({'prepared':True,'engine_launched':False,'command':command}));sys.exit(0)
    out.mkdir(parents=True,exist_ok=False)
    harness_files=[HERE/'run56.py',HERE/'build56.py',HERE/'entry56.gd',HERE/'observer56.gd',HERE.parent/'injury30/observer_injury30.gd',HERE.parent/'injury30/observer_death28.gd']
    harness={f.relative_to(HERE.parent).as_posix():sha(f) for f in harness_files};save(out/'HARNESS_PINS.json',harness)
    with zipfile.ZipFile(out/'HARNESS.zip','w',zipfile.ZIP_DEFLATED) as z:
        for rel in harness:z.write(HERE.parent/rel,rel)
    record={'passed':False,'command':command,'access':'read','mode':'headless','performance_accepted':False,'project_copied':False,'requested_residents':10};before={}
    try:
        save(out/'PROBE.json',probe('headless',game,'read'))
        with Lease('headless',game,'read',45) as lease:
            record['lease']=lease.request;before=pins(game);save(out/'SOURCE.json',before);started=time.monotonic()
            try:
                with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
                    child=subprocess.Popen(command,cwd=game,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
                    try:
                        record['child']=lease.register_child(child)
                        while child.poll() is None:
                            if time.monotonic()-started>350:raise TimeoutError('Threat actual10 startup + cycle watchdog')
                            error=(out/'stderr.log').read_text(encoding='utf-8',errors='replace')
                            if 'SCRIPT ERROR:' in error or 'Parse Error:' in error:raise RuntimeError('Native error; stopping exact owned child')
                            time.sleep(.2)
                    finally:
                        if child.poll() is None:child.terminate();child.wait(timeout=10)
                    record['exit_code']=child.returncode;record['wall_s']=time.monotonic()-started
            finally:
                after=pins(game);save(out/'SOURCE_AFTER.json',after);record['source_drift']=[k for k in set(before)|set(after) if before.get(k)!=after.get(k)];record['harness_drift']=[k for k,v in harness.items() if sha(HERE.parent/k)!=v]
            native=json.loads((out/'CITY_THREAT56.json').read_text(encoding='utf-8-sig')) if (out/'CITY_THREAT56.json').exists() else {}
            record['native_passed']=native.get('passed',False);record['checks']=native.get('checks',{});record['reason']=native.get('reason','missing_native_receipt')
            record['stderr_bytes']=(out/'stderr.log').stat().st_size;record['errors']=[line for n in ['stdout.log','stderr.log'] for line in (out/n).read_text(encoding='utf-8',errors='replace').splitlines() if ERRORS.search(line)]
            record['passed']=record['exit_code']==0 and record['native_passed'] and not record['stderr_bytes'] and not record['errors'] and not record['source_drift'] and not record['harness_drift']
    except Exception as e:record['error']=str(e)
    finally:save(out/'RUN.json',record)
    print(json.dumps({k:v for k,v in record.items() if k not in ['command','child','lease']},ensure_ascii=True));sys.exit(0 if record['passed'] else 1)
