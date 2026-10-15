"""Bounded built-in Godot script-profiler diagnostic; not FPS acceptance."""
import argparse, hashlib, json, os, pathlib, re, shutil, subprocess, sys, time, zipfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PROJECT = ROOT / 'outputs/coordinator31_release57/game'
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease, ERRORS

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def save(path, value): path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def pins(): return {p.relative_to(PROJECT).as_posix():sha(p) for p in PROJECT.rglob('*') if p.is_file() and '.godot' not in p.parts}

def parse_profile(path):
    text = path.read_text(encoding='utf-8-sig', errors='replace')
    block = text.split('PROFILE31_ACCUMULATED_BEGIN\n')[-1].split('PROFILE31_MEASURE_END')[0]
    rx = re.compile(r'^\d+:(.+)\n\s*total: ([0-9.eE+-]+)/[^\n]*?self: ([0-9.eE+-]+)/[^\n]*?tcalls: (\d+)', re.M)
    rows = [dict(signature=m[0], total_s=float(m[1]), self_s=float(m[2]), calls=int(m[3])) for m in rx.findall(block)]
    total = re.search(r'ACCUMULATED: total: ([0-9.eE+-]+)', block)
    return {'accumulated_script_self_s':float(total[1]) if total else None,
            'functions':len(rows),'top_self':sorted(rows,key=lambda r:r['self_s'],reverse=True)[:40],
            'top_total':sorted(rows,key=lambda r:r['total_s'],reverse=True)[:40],
            'all_functions':rows,'inclusive_times_overlap':True}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name'); parser.add_argument('--mode',choices=['headless','graphical'],default='headless')
    parser.add_argument('--seconds',type=int,default=60); parser.add_argument('--go',action='store_true')
    args=parser.parse_args(); assert re.fullmatch(r'[A-Za-z0-9_-]+',args.name) and 10<=args.seconds<=90
    assembly=read(ROOT/'outputs/coordinator31_release57/ASSEMBLY.json')
    scheduler=ROOT/'tools/godot/test_scheduler.py'
    assert sha(scheduler)=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
    if not args.go: print(json.dumps({'prepared':True,'mode':args.mode,'seconds':args.seconds,'game_modified':False})); return 0
    run=HERE/'runs'/args.name; run.mkdir(parents=True,exist_ok=False)
    files=[HERE/'entry31.gd',HERE/'observer31.gd',HERE/'run31.py',scheduler,ROOT/'outputs/coordinator31_release57/ASSEMBLY.json']
    harness={p.relative_to(ROOT).as_posix():sha(p) for p in files}; save(run/'HARNESS.json',harness)
    with zipfile.ZipFile(run/'HARNESS.zip','w',compression=zipfile.ZIP_DEFLATED) as archive:
        for p in files: archive.write(p,p.relative_to(ROOT).as_posix())
    before=pins(); save(run/'SOURCE.json',before)
    controls={p:sha(ROOT/p) if (ROOT/p).exists() else None for p in ['godot/current_version.json','.vscode/launch.json']}
    save(run/'CONTROL_PINS.json',controls)
    result={'passed':False,'mode':args.mode,'game_modified':False,'performance_accepted':False,'user_processes_closed':False,'profile_overhead_present':True}
    try:
        assert before==assembly['source_pins'], 'Frozen source mismatch'
        exe=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
        assert sha(exe)==read(ROOT/'docs/godot/ENGINE_LOCK.json')['editor']['gui']['sha256']
        command=[str(exe)]+(['--headless'] if args.mode=='headless' else ['--resolution','640x480'])
        command+=['--debug','--profiling','--path',str(PROJECT),'--script',str(HERE/'entry31.gd'),'--',*assembly['launch_arguments'],'--qa-out='+str(run),'--profile-seconds='+str(args.seconds)]
        result['command']=command
        with Lease(args.mode,PROJECT,'read',60) as lease:
            assert pins()==before
            with (run/'stdout.log').open('wb') as stdout,(run/'stderr.log').open('wb') as stderr:
                started=time.monotonic()
                child=subprocess.Popen(command,cwd=PROJECT,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    result['child']=lease.register_child(child)
                    while child.poll() is None:
                        if time.monotonic()-started>args.seconds+110: raise TimeoutError('Owned profiling child deadline')
                        diagnostic=(run/'stderr.log').read_text(encoding='utf-8',errors='replace')
                        if any(ERRORS.search(line) for line in diagnostic.splitlines()): raise RuntimeError('Native error, see preserved log')
                        if sum(p.stat().st_size for p in run.iterdir() if p.is_file())>50*1024*1024: raise RuntimeError('50MiB output cap')
                        if shutil.disk_usage(ROOT).free<128*1024*1024: raise RuntimeError('Disk reserve reached')
                        time.sleep(.2)
                finally:
                    if child.poll() is None: child.terminate(); child.wait(timeout=10)
                result.update(exit_code=child.returncode,wall_s=time.monotonic()-started)
        native=read(run/'NATIVE.json'); profile=parse_profile(run/'stdout.log'); save(run/'PROFILE.json',profile)
        result.update(native_passed=native['passed'],native_reason=native['reason'],profile_functions=profile['functions'],top_self=profile['top_self'][:12],measure_s=native['measure_s'])
        result['errors']=[line for name in ['stdout.log','stderr.log'] for line in (run/name).read_text(encoding='utf-8-sig',errors='replace').splitlines() if ERRORS.search(line)]
        result['warnings']=[line for line in (run/'stderr.log').read_text(encoding='utf-8-sig',errors='replace').splitlines() if line.startswith('WARNING:')]
    except Exception as error: result['error']=type(error).__name__+': '+str(error)
    finally:
        after=pins();save(run/'SOURCE_AFTER.json',after)
        result['source_drift']=[k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)]
        result['harness_drift']=[k for k,v in harness.items() if sha(ROOT/k)!=v]
        result['control_drift']=[k for k,v in controls.items() if (sha(ROOT/k) if (ROOT/k).exists() else None)!=v]
        result['passed']=result.get('exit_code')==0 and result.get('native_passed') is True and result.get('profile_functions',0)>0 and not any(result.get(k) for k in ['error','errors','source_drift','harness_drift','control_drift'])
        save(run/'RESULT.json',result)
    print(json.dumps({k:result.get(k) for k in ['passed','error','wall_s','profile_functions','measure_s','top_self']},ensure_ascii=False));return 0 if result['passed'] else 1

if __name__=='__main__':sys.exit(main())
