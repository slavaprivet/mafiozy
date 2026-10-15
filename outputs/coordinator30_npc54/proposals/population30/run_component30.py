"""Small component QA on our existing private reusable stage. Never shared54."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess, sys, time, zipfile
OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[3]
GAME=OUT.parent/'route30/runs/city05/project'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease, probe, ERRORS
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,data):p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def pins():return {p.relative_to(GAME).as_posix():sha(p) for p in GAME.rglob('*') if p.is_file() and '.godot' not in p.parts}
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('name');args=parser.parse_args()
assert args.name and all(c.isalnum() or c in '-_' for c in args.name)
assert sha(ROOT/'tools/godot/test_scheduler.py')=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
run=OUT/'runs'/args.name;run.mkdir(parents=True,exist_ok=False)
result={'passed':False,'project':str(GAME),'project_copied':False,'shared_modified':False,'performance_accepted':False}
try:
    eligible=probe('headless',GAME,'write');save(run/'PROBE.json',eligible)
    if not eligible['eligible_snapshot']:raise RuntimeError('NOT_STARTED: '+json.dumps(eligible))
    source=json.loads((OUT/'BASELINE30.json').read_text(encoding='utf-8'))['files']
    with Lease('headless',GAME,'write',20) as lease:
        save(run/'STAGE_LEASE.json',lease.request)
        with zipfile.ZipFile(run/'CHANGED_SOURCES.zip','w',compression=zipfile.ZIP_DEFLATED) as archive:
            for rel in source:
                shutil.copy2(OUT/rel,GAME/rel);archive.write(OUT/rel,rel)
            archive.write(OUT/'qa/population_component30.gd','qa/population_component30.gd')
            archive.write(OUT/'run_component30.py','run_component30.py')
    with Lease('headless',GAME,'read',20) as lease:
        before=pins();save(run/'SOURCE.json',before);result['lease']=lease.request
        engine=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
        assert sha(engine)==json.loads((ROOT/'docs/godot/ENGINE_LOCK.json').read_text(encoding='utf-8-sig'))['editor']['gui']['sha256']
        command=[str(engine),'--headless','--path',str(GAME),'--script',str(OUT/'qa/population_component30.gd'),'--','--qa-out='+str(run/'NATIVE.json'),'--city-simple-hospital=1','--city-physical-dispatch30=1','--city-local-avoidance29=1']
        result['command']=command;started=time.monotonic()
        with (run/'stdout.log').open('wb') as out,(run/'stderr.log').open('wb') as err:
            child=subprocess.Popen(command,cwd=GAME,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                result['child']=lease.register_child(child)
                while child.poll() is None:
                    if time.monotonic()-started>65:raise TimeoutError('Owned component child watchdog')
                    time.sleep(.1)
            finally:
                if child.poll() is None:child.terminate();child.wait(timeout=10)
            result['exit_code']=child.returncode;result['elapsed_seconds']=time.monotonic()-started
        after=pins();save(run/'SOURCE_AFTER.json',after)
        result['drift']=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
        result['stderr_bytes']=(run/'stderr.log').stat().st_size
        result['errors']=[line for p in ['stdout.log','stderr.log'] for line in (run/p).read_text(encoding='utf-8-sig',errors='replace').splitlines() if ERRORS.search(line)]
        semantic=json.loads((run/'NATIVE.json').read_text(encoding='utf-8')) if (run/'NATIVE.json').exists() else {}
        result['native_checks']=len(semantic.get('checks',[]));result['failed_checks']=[r for r in semantic.get('checks',[]) if not r['passed']]
        result['passed']=result['exit_code']==0 and result['stderr_bytes']==0 and not result['errors'] and not result['drift'] and semantic.get('passed') is True
except Exception as error:result['error']=type(error).__name__+': '+str(error)
save(run/'RESULT.json',result);print(json.dumps(result));sys.exit(0 if result['passed'] else 1)
