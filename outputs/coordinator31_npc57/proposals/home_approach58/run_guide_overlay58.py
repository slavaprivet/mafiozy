"""Exact merged source, ordinary native scene; component home intents only."""
import argparse, hashlib, json, os, subprocess, sys, time, zipfile
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
GAME = HERE.parents[1] / 'game'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p, v): p.write_text(json.dumps(v, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def pins(): return {p.relative_to(GAME).as_posix():sha(p) for p in GAME.rglob('*') if p.is_file() and '.godot' not in p.relative_to(GAME).parts}
def main():
    ap=argparse.ArgumentParser();ap.add_argument('name');ap.add_argument('--manifest', required=True);ap.add_argument('--expected-sha256', required=True);ap.add_argument('--mode', choices=['headless','graphical'], default='headless');ap.add_argument('--go',action='store_true');args=ap.parse_args()
    assert args.name and all(c.isalnum() or c in '_-' for c in args.name)
    manifest=Path(args.manifest).resolve();assert manifest.is_relative_to(ROOT) and sha(manifest)==args.expected_sha256
    doc=read(manifest);expected=doc['source_pins'];assert pins()==expected
    import_receipt=Path(doc['import_receipt']);assert read(import_receipt)['passed'] is True
    scheduler=ROOT/'tools/godot/test_scheduler.py';assert sha(scheduler)=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
    sys.path.insert(0,str(ROOT));from tools.godot.test_scheduler import Lease, probe, ERRORS
    engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    lock=ROOT/'docs/godot/ENGINE_LOCK.json';assert sha(engine)==read(lock)['editor']['gui']['sha256']
    assembly=ROOT/'outputs/coordinator31_release57/ASSEMBLY.json'
    flags=[f for f in doc['launch_arguments'] if not f.startswith(('--qa-','--city-quit-after='))]
    assert '--city-player-shop=1' in flags
    controls=[manifest,import_receipt,scheduler,lock,assembly,ROOT/'godot/current_version.json',HERE/'entry_guide_overlay58.gd',HERE/'observer_guide_overlay58.gd',HERE.parent/'homes58/observer_cycle58_v2.gd',Path(__file__)]
    patch=read(HERE/'PATCH.json')
    assert len(patch)==2
    for rel,row in patch.items():
        assert expected.get(rel)==row['base_sha256']
        assert sha(HERE/'patch'/rel)==row['candidate_sha256']
    controls += [HERE/'PATCH.json', *[HERE/'patch'/rel for rel in patch]]
    cp={str(p):sha(p) for p in controls}
    if not args.go:
        print(json.dumps({'prepared':True,'source_count':len(expected),'source_manifest_sha256':sha(manifest),'mode':args.mode,'launch':False}));return 0
    run=HERE/'runs'/args.name;run.mkdir(parents=True,exist_ok=False)
    overlay={rel:row['candidate_sha256'] for rel,row in patch.items()}
    save(run/'OVERLAY.json',overlay)
    with zipfile.ZipFile(run/'OVERLAY.zip','x',zipfile.ZIP_DEFLATED) as archive:
        for rel in overlay:archive.write(HERE/'patch'/rel,rel)
    save(run/'CONTROL_PINS.json',cp)
    inventory={p.relative_to(ROOT).as_posix():sha(p) for p in controls}
    save(run/'HARNESS.json',inventory)
    with zipfile.ZipFile(run/'HARNESS.zip','x',zipfile.ZIP_DEFLATED) as archive:
        for p in controls:archive.write(p,p.relative_to(ROOT).as_posix())
    command=[str(engine),*(['--headless'] if args.mode=='headless' else []),'--path',str(GAME),'--script',str(HERE/'entry_guide_overlay58.gd'),'--',*flags,'--qa-out='+str(run)]
    result={'passed':False,'scope':'isolated overlay guide repair only; full merged physical cycle still required','overlay':True,'production_changed':False,'overlay_only':True,'mode':args.mode,'engine_sha256':sha(engine),'source_manifest_sha256':sha(manifest),'command':command}
    child=None
    try:
        save(run/'PROBE.json',probe(args.mode,GAME,'read'))
        with Lease(args.mode,GAME,'read',60) as lease:
            result['lease']=lease.request;assert pins()==expected;save(run/'SOURCE.json',expected)
            start=time.monotonic()
            with (run/'stdout.log').open('wb') as out,(run/'stderr.log').open('wb') as err:
                child=subprocess.Popen(command,cwd=GAME,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    result['child']=lease.register_child(child)
                    while child.poll() is None:
                        if time.monotonic()-start>150:raise TimeoutError('full native startup plus15s guide watchdog')
                        if (run/'stderr.log').stat().st_size:raise RuntimeError('native stderr')
                        if sum(p.stat().st_size for p in run.iterdir() if p.is_file())>100*1024**2:raise RuntimeError('100MiB output cap')
                        time.sleep(.2)
                finally:
                    if child.poll() is None:child.terminate();child.wait(timeout=10)
            result['wall_s']=time.monotonic()-start;result['exit_code']=child.returncode
            after=pins();save(run/'SOURCE_AFTER.json',after)
            aftercp={str(p):sha(p) for p in controls};save(run/'CONTROL_PINS_AFTER.json',aftercp)
            result['source_drift']=[k for k in set(expected)|set(after) if expected.get(k)!=after.get(k)]
            result['control_drift']=[k for k in set(cp)|set(aftercp) if cp.get(k)!=aftercp.get(k)]
            result['errors']=[line for f in ['stdout.log','stderr.log'] for line in (run/f).read_text(encoding='utf-8-sig',errors='replace').splitlines() if ERRORS.search(line)]
            result['stderr_bytes']=(run/'stderr.log').stat().st_size
            native=read(run/'GUIDE58.json') if (run/'GUIDE58.json').exists() else {}
            result['native_passed']=native.get('passed',False)
            result['passed']=child.returncode==0 and not result['source_drift'] and not result['control_drift'] and not result['errors'] and result['stderr_bytes']==0 and native.get('passed') is True
    except Exception as exc:result['error']=type(exc).__name__+': '+str(exc)
    finally:
        if not (run/'SOURCE_AFTER.json').exists():save(run/'SOURCE_AFTER.json',pins())
        save(run/'RUN.json',result)
    print(json.dumps({k:v for k,v in result.items() if k not in ['command','lease','child']},ensure_ascii=True))
    return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
