"""Exact housing overlay, scheduler read lease, owned child, source/controls archived."""
import hashlib,json,os,subprocess,sys,time,zipfile
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
GAME=HERE.parents[1]/'game'
PACKAGE=HERE.parent/'housing_geometry58'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
save=lambda p,v:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def pins():return {p.relative_to(GAME).as_posix():sha(p) for p in GAME.rglob('*') if p.is_file() and '.godot' not in p.relative_to(GAME).parts}
def main():
    name=sys.argv[1];assert name and all(c.isalnum() or c in '_-' for c in name)
    manifest=ROOT/'outputs/coordinator31_npc57/extended31/stage58_04/CANDIDATE58.json'
    expected=read(manifest)['source_pins'];assert pins()==expected
    patch=read(PACKAGE/'PATCH.json');assert sha(PACKAGE/'PATCH.json')=='0c1c1f68c2a8a95c1436bb7e369c958a39f120ff65a2adf4dd7fcedbeec6b154'
    for rel,row in patch.items():
        assert expected.get(rel)==row['base_sha256'],rel
        assert sha(PACKAGE/'patch'/rel)==row['candidate_sha256'],rel
    run=HERE/'runs'/name;run.mkdir(parents=True,exist_ok=False)
    overlay={rel:row['candidate_sha256'] for rel,row in patch.items()}
    save(run/'OVERLAY.json',overlay)
    with zipfile.ZipFile(run/'OVERLAY.zip','x',zipfile.ZIP_DEFLATED) as archive:
        for rel in overlay:archive.write(PACKAGE/'patch'/rel,rel)
    scheduler=ROOT/'tools/godot/test_scheduler.py';assert sha(scheduler)=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
    sys.path.insert(0,str(ROOT));from tools.godot.test_scheduler import Lease,probe,ERRORS
    engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    lock=ROOT/'docs/godot/ENGINE_LOCK.json';assert sha(engine)==read(lock)['editor']['gui']['sha256']
    assembly=ROOT/'outputs/coordinator31_release57/ASSEMBLY.json'
    flags=[f for f in read(assembly)['launch_arguments'] if not f.startswith(('--qa-','--city-quit-after='))]
    controls=[manifest,scheduler,lock,assembly,ROOT/'godot/current_version.json',PACKAGE/'PATCH.json',HERE/'entry_geometry58.gd',Path(__file__),run/'OVERLAY.json',run/'OVERLAY.zip']
    cp={str(p):sha(p) for p in controls};save(run/'CONTROL_PINS.json',cp)
    with zipfile.ZipFile(run/'HARNESS.zip','x',zipfile.ZIP_DEFLATED) as archive:
        for p in controls:
            if p.suffix!='.zip':archive.write(p,p.relative_to(ROOT).as_posix())
        for rel in overlay:archive.write(PACKAGE/'patch'/rel,'overlay/'+rel)
    command=[str(engine),'--headless','--path',str(GAME),'--script',str(HERE/'entry_geometry58.gd'),'--',*flags,'--qa-out='+str(run)]
    result={'passed':False,'scope':'housing geometry/native support; not sleep, C4 blast or performance acceptance','production_changed':False,'engine_sha256':sha(engine),'command':command}
    child=None
    try:
        save(run/'PROBE.json',probe('headless',GAME,'read'))
        with Lease('headless',GAME,'read',60) as lease:
            result['lease']=lease.request;assert pins()==expected;save(run/'SOURCE.json',expected)
            start=time.monotonic()
            with (run/'stdout.log').open('wb') as out,(run/'stderr.log').open('wb') as err:
                child=subprocess.Popen(command,cwd=GAME,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    result['child']=lease.register_child(child)
                    while child.poll() is None:
                        if time.monotonic()-start>160:raise TimeoutError('owned startup+30s stability watchdog')
                        if (run/'stderr.log').stat().st_size:raise RuntimeError('native stderr')
                        if sum(p.stat().st_size for p in run.iterdir() if p.is_file())>30*1024**2:raise RuntimeError('30MiB cap')
                        time.sleep(.2)
                finally:
                    if child.poll() is None:child.terminate();child.wait(timeout=10)
            result['wall_s']=time.monotonic()-start;result['exit_code']=child.returncode
            after=pins();save(run/'SOURCE_AFTER.json',after)
            aftercp={str(p):sha(p) for p in controls};save(run/'CONTROL_PINS_AFTER.json',aftercp)
            result['source_drift']=expected!=after;result['control_drift']=cp!=aftercp
            result['errors']=[line for f in ['stdout.log','stderr.log'] for line in (run/f).read_text(encoding='utf-8-sig',errors='replace').splitlines() if ERRORS.search(line)]
            native=read(run/'GEOMETRY58.json') if (run/'GEOMETRY58.json').exists() else {}
            result['native_passed']=native.get('passed',False)
            result['passed']=child.returncode==0 and not result['source_drift'] and not result['control_drift'] and not result['errors'] and native.get('passed') is True
    except Exception as exc:result['error']=type(exc).__name__+': '+str(exc)
    finally:
        if not (run/'SOURCE_AFTER.json').exists():save(run/'SOURCE_AFTER.json',pins())
        save(run/'RUN.json',result)
    print(json.dumps({k:v for k,v in result.items() if k not in ['command','lease','child']},ensure_ascii=True))
    return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
