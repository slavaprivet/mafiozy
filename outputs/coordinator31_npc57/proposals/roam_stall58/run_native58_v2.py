"""Bounded native replay on exact candidate58, with scheduler and immutable proof."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import zipfile

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
save=lambda p,v:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def pins(folder):return {p.relative_to(folder).as_posix():sha(p) for p in folder.rglob('*') if p.is_file() and '.godot' not in p.parts}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('name');a=p.parse_args()
    assert a.name and all(c.isalnum() or c in '_-' for c in a.name)
    project=ROOT/'outputs/coordinator31_npc57/game'
    manifest=ROOT/'outputs/coordinator31_npc57/extended31/stage58_03/CANDIDATE58.json'
    assert sha(manifest)=='46a095bd14fdede78861d097cd5e69ad73a32c6cdf842b6944375101e84155a7'
    expected=read(manifest)['source_pins'];assert pins(project)==expected
    scheduler=ROOT/'tools/godot/test_scheduler.py'
    assert sha(scheduler)=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
    sys.path.insert(0,str(ROOT));from tools.godot.test_scheduler import Lease,probe,ERRORS
    engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    lock=ROOT/'docs/godot/ENGINE_LOCK.json';assert sha(engine)==read(lock)['editor']['gui']['sha256']
    assembly=ROOT/'outputs/coordinator31_release57/ASSEMBLY.json'
    flags=[f for f in read(assembly)['launch_arguments'] if not f.startswith(('--qa-','--city-quit-after='))]
    assert '--city-qa=10' in flags
    run=OUT/'runs'/a.name;run.mkdir(parents=True,exist_ok=False)
    harness={name:sha(OUT/name) for name in ['entry_v2.gd','fixture_v2.gd','run_native58_v2.py']}
    control_files=[manifest,scheduler,engine,lock,assembly,ROOT/'godot/current_version.json',*[OUT/name for name in harness]]
    controls={str(p.resolve()):sha(p) for p in control_files}
    save(run/'HARNESS.json',harness);save(run/'CONTROL_PINS.json',controls)
    with zipfile.ZipFile(run/'HARNESS.zip','x',zipfile.ZIP_DEFLATED) as z:
        for name in harness:z.write(OUT/name,name)
    command=[str(engine),'--headless','--path',str(project),'--script',str(OUT/'entry_v2.gd'),'--',*flags,'--qa-out='+str(run)]
    record={'passed':False,'diagnostic_only':True,'performance_accepted':False,'production_modified':False,'command':command,'engine_sha256':sha(engine),'scheduler_sha256':sha(scheduler),'manifest_sha256':sha(manifest)}
    child=None
    try:
        save(run/'PROBE.json',probe('headless',project,'read'))
        with Lease('headless',project,'read',60) as lease:
            record['lease']=lease.request
            assert pins(project)==expected and controls=={str(p.resolve()):sha(p) for p in control_files}
            save(run/'SOURCE.json',expected)
            start=time.monotonic()
            with (run/'stdout.log').open('wb') as out,(run/'stderr.log').open('wb') as err:
                child=subprocess.Popen(command,cwd=project,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    record['child']=lease.register_child(child)
                    while child.poll() is None:
                        if time.monotonic()-start>180:raise TimeoutError('Owned replay startup+45s watchdog')
                        if (run/'stderr.log').stat().st_size:raise RuntimeError('Native stderr')
                        if sum(p.stat().st_size for p in run.iterdir() if p.is_file())>100*1024**2:raise RuntimeError('Diagnostic output cap100MiB')
                        time.sleep(.2)
                finally:
                    if child.poll() is None:child.terminate();child.wait(timeout=10)
            record['exit_code']=child.returncode;record['wall_s']=time.monotonic()-start
            after=pins(project);save(run/'SOURCE_AFTER.json',after)
            record['source_drift']=[k for k in expected.keys()|after.keys() if expected.get(k)!=after.get(k)]
            after_controls={str(p.resolve()):sha(p) for p in control_files};save(run/'CONTROL_PINS_AFTER.json',after_controls)
            record['control_drift']=[k for k in controls if controls[k]!=after_controls.get(k)]
            record['harness_drift']=[k for k,v in harness.items() if sha(OUT/k)!=v]
            record['errors']=[line for name in ['stdout.log','stderr.log'] for line in (run/name).read_text(encoding='utf-8-sig',errors='replace').splitlines() if ERRORS.search(line)]
            record['stderr_bytes']=(run/'stderr.log').stat().st_size
            native=read(run/'NATIVE58.json');record['native_reason']=native['reason'];record['native_rows']=len(native['rows'])
            record['passed']=record['exit_code']==0 and not record['errors'] and not record['stderr_bytes'] and not record['source_drift'] and not record['control_drift'] and not record['harness_drift']
    except Exception as e:record['error']=type(e).__name__+': '+str(e)
    finally:
        # Preserve source-after evidence even for a script parse failure.
        if not (run/'SOURCE_AFTER.json').exists():save(run/'SOURCE_AFTER.json',pins(project))
        save(run/'RUN.json',record)
    print(json.dumps({k:v for k,v in record.items() if k not in ['command','child','lease']}))
    return 0 if record['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
