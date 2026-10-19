"""Stage manifest ordinary flags, exact source, scheduler read lease, owned watchdog."""
import argparse,hashlib,json,os,subprocess,sys,time,zipfile
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
GAME=HERE.parents[1]/'game'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def pins():return {p.relative_to(GAME).as_posix():sha(p) for p in GAME.rglob('*') if p.is_file() and '.godot' not in p.relative_to(GAME).parts}
def main():
    ap=argparse.ArgumentParser();ap.add_argument('name');ap.add_argument('--expected-source',type=Path,required=True);ap.add_argument('--case',choices=['startup','clock'],default='startup');a=ap.parse_args()
    assert a.name and all(c.isalnum() or c in '_-' for c in a.name)
    manifest=a.expected_source.resolve();stage=read(manifest);expected=stage['source_pins'];assert pins()==expected
    flags=stage['launch_arguments'];assert '--city-player-shop=1' in flags and '--city-qa=10' in flags
    assert all(f.startswith('--city-') and 'seed' not in f and not f.startswith('--city-quit-after=') for f in flags)
    run=HERE/'runs'/a.name;run.mkdir(parents=True,exist_ok=False)
    scheduler=ROOT/'tools/godot/test_scheduler.py';assert sha(scheduler)=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
    sys.path.insert(0,str(ROOT));from tools.godot.test_scheduler import Lease,probe,ERRORS
    engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    lock=ROOT/'docs/godot/ENGINE_LOCK.json';assert sha(engine)==read(lock)['editor']['gui']['sha256']
    controls=[manifest,scheduler,lock,ROOT/'godot/current_version.json',Path(__file__),HERE/'entry_native58.gd']
    cp={str(p):sha(p) for p in controls};save(run/'CONTROL_PINS.json',cp)
    with zipfile.ZipFile(run/'HARNESS.zip','x',zipfile.ZIP_DEFLATED) as archive:
        for p in controls:archive.write(p,p.relative_to(ROOT).as_posix())
    command=[str(engine),'--headless','--path',str(GAME),'--script',str(HERE/'entry_native58.gd'),'--',*flags,'--qa-out='+str(run),'--qa-case='+a.case]
    result={'passed':False,'scope':'Short ordinary READY/clock coverage, not full behavior or performance acceptance','case':a.case,'production_changed':False,'engine_sha256':sha(engine),'command':command}
    child=None
    try:
        save(run/'PROBE.json',probe('headless',GAME,'read'))
        with Lease('headless',GAME,'read',90) as lease:
            result['lease']=lease.request;assert pins()==expected;save(run/'SOURCE.json',expected)
            start=time.monotonic()
            with (run/'stdout.log').open('wb') as out,(run/'stderr.log').open('wb') as err:
                child=subprocess.Popen(command,cwd=GAME,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    result['child']=lease.register_child(child)
                    while child.poll() is None:
                        if time.monotonic()-start>160:raise TimeoutError('owned startup/clock watchdog160s')
                        if (run/'stderr.log').stat().st_size:raise RuntimeError('native stderr')
                        if sum(p.stat().st_size for p in run.iterdir() if p.is_file())>25*1024**2:raise RuntimeError('25MiB cap')
                        time.sleep(.2)
                finally:
                    if child.poll() is None:child.terminate();child.wait(timeout=10)
            result['wall_s']=time.monotonic()-start;result['exit_code']=child.returncode
            after=pins();save(run/'SOURCE_AFTER.json',after);aftercp={str(p):sha(p) for p in controls};save(run/'CONTROL_PINS_AFTER.json',aftercp)
            result['source_drift']=expected!=after;result['control_drift']=cp!=aftercp
            result['errors']=[line for f in ['stdout.log','stderr.log'] for line in (run/f).read_text(encoding='utf-8-sig',errors='replace').splitlines() if ERRORS.search(line)]
            native=read(run/'NATIVE58.json') if (run/'NATIVE58.json').exists() else {};result['native_passed']=native.get('passed',False)
            result['passed']=child.returncode==0 and not result['source_drift'] and not result['control_drift'] and not result['errors'] and native.get('passed') is True
    except Exception as exc:result['error']=type(exc).__name__+': '+str(exc)
    finally:
        if not (run/'SOURCE_AFTER.json').exists():save(run/'SOURCE_AFTER.json',pins())
        if not (run/'CONTROL_PINS_AFTER.json').exists():save(run/'CONTROL_PINS_AFTER.json',{str(p):sha(p) for p in controls})
        save(run/'RUN.json',result)
    print(json.dumps({k:v for k,v in result.items() if k not in ['command','lease','child']},ensure_ascii=True))
    return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
