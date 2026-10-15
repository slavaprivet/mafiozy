"""Native service interruption QA on unchanged shared sources; no city copy."""
import argparse,hashlib,json,os,pathlib,subprocess,sys,time,zipfile
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease,ERRORS
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,data):p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def pins(p):return {f.relative_to(p).as_posix():sha(f) for f in p.rglob('*') if f.is_file() and '.godot' not in f.parts}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('name');p.add_argument('--case',choices=['shop','restaurant'],required=True);p.add_argument('--game',type=pathlib.Path,default=ROOT/'outputs/coordinator30_npc54/game');p.add_argument('--go',action='store_true');p.add_argument('--source',type=pathlib.Path);p.add_argument('--wait',type=int,default=30);a=p.parse_args()
    game=a.game.resolve();assert a.name and all(x.isalnum() or x in '-_' for x in a.name)
    fixtures=[OUT/'entry30.gd',OUT/'observer30.gd',OUT/'run30.py',OUT.parent/'injury30/observer_death28.gd'];fixture_pins={str(f.relative_to(ROOT)):sha(f) for f in fixtures}
    if not a.go:print(json.dumps({'status':'READY_WAITING_ROOT_FINAL_SOURCE_GO','case':a.case,'fixture_pins':fixture_pins,'native_started':False}));return 0
    run=OUT/'runs'/a.name;run.mkdir(parents=True,exist_ok=False);save(run/'FIXTURE_PINS.json',fixture_pins)
    with zipfile.ZipFile(run/'FIXTURE_SOURCES.zip','w',compression=zipfile.ZIP_DEFLATED) as z:
        for f in fixtures:z.write(f,f.relative_to(ROOT).as_posix())
    result={'passed':False,'case':a.case,'project':str(game),'project_copied':False,'production_modified':False,'performance_accepted':False,'user_processes_closed':False}
    try:
        assert sha(ROOT/'tools/godot/test_scheduler.py')=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
        with Lease('headless',game,'read',a.wait) as lease:
            before=pins(game);save(run/'SOURCE.json',before)
            if a.source:assert before==read(a.source),'Expected final source pins differ; no child started'
            flags=read(OUT.parent/'staff30/runs/cycle03/FLAGS.json')
            flags=[f for f in flags if not f.startswith(('--qa-','--city-hp=','--city-energy-start=','--city-wallet-start=','--city-clear-cache='))]
            flags+=['--city-hp=100','--city-energy-start=100','--city-wallet-start=1000','--city-threat30=1','--city-physical-dispatch30=1','--city-local-avoidance29=1','--qa-service-kind='+a.case,'--qa-out='+str(run)]
            save(run/'FLAGS.json',flags)
            exe=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
            assert sha(exe)==read(ROOT/'docs/godot/ENGINE_LOCK.json')['editor']['gui']['sha256']
            command=[str(exe),'--headless','--path',str(game),'--script',str(OUT/'entry30.gd'),'--',*flags];result['command']=command
            started=time.monotonic()
            try:
                with (run/'stdout.log').open('wb') as stdout,(run/'stderr.log').open('wb') as stderr:
                    child=subprocess.Popen(command,cwd=game,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
                    try:
                        result['child']=lease.register_child(child)
                        while child.poll() is None:
                            if time.monotonic()-started>310:raise TimeoutError('Exact owned native child watchdog')
                            # Parse failures are terminal; stop only this registered child promptly.
                            if (run/'stderr.log').exists() and 'SCRIPT ERROR: Parse Error:' in (run/'stderr.log').read_text(encoding='utf-8',errors='replace'):raise RuntimeError('Native parse error')
                            time.sleep(.2)
                    finally:
                        if child.poll() is None:child.terminate();child.wait(timeout=10)
                    result.update(exit_code=child.returncode,elapsed_seconds=time.monotonic()-started)
            finally:
                after=pins(game);save(run/'SOURCE_AFTER.json',after);result['source_drift']=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
            semantic=read(run/'SERVICE_THREAT30.json') if (run/'SERVICE_THREAT30.json').exists() else {}
            errors=[line for f in [run/'stdout.log',run/'stderr.log'] for line in f.read_text(encoding='utf-8-sig',errors='replace').splitlines() if ERRORS.search(line)]
            result.update(errors=errors,stderr_bytes=(run/'stderr.log').stat().st_size,checks=semantic.get('checks',{}),semantic_reason=semantic.get('reason'),harness_drift=[k for k,v in fixture_pins.items() if sha(ROOT/k)!=v])
            result['passed']=result['exit_code']==0 and not errors and not result['stderr_bytes'] and not result['source_drift'] and not result['harness_drift'] and semantic.get('passed') is True
    except Exception as error:result.update(error=type(error).__name__+': '+str(error))
    save(run/'RESULT.json',result);print(json.dumps(result));return 0 if result['passed'] else 1
if __name__=='__main__':sys.exit(main())
