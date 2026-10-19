"""Bounded, pinned actual-city cohort run; functional timings are not FPS acceptance."""
import argparse,importlib.util,json,os,pathlib,subprocess,sys,time
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3];GAME=OUT.parent.parent/'game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease,probe,ERRORS
spec=importlib.util.spec_from_file_location('perf',OUT.parent/'perf30/perf_pair30.py');perf=importlib.util.module_from_spec(spec);spec.loader.exec_module(perf)
p=argparse.ArgumentParser();p.add_argument('name');p.add_argument('--project',type=pathlib.Path,default=GAME);p.add_argument('--residents',type=int,default=10,choices=list(range(10,281,10))+[287]);p.add_argument('--seconds',type=int,default=60);p.add_argument('--warmup',type=int,default=15);p.add_argument('--mode',choices=['headless','graphical','perf'],default='headless');p.add_argument('--extra',action='append',default=[]);a=p.parse_args()
run=OUT/'runs'/a.name;run.mkdir(parents=True,exist_ok=False);GAME=a.project.resolve()
flags=[f for f in perf.common_flags(a.warmup,a.seconds,53) if not f.startswith(('--city-qa=','--city-resident-name='))]
flags += [f'--city-qa={a.residents}','--city-physical-dispatch30=1','--city-multi-lifecycle30=1','--qa-expected-staff=12',f'--qa-residents={a.residents}','--qa-out='+str(run),*a.extra]
engine=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
cmd=[str(engine)]+(['--headless'] if a.mode=='headless' else [])+['--path',str(GAME),'--script',str(OUT/'entry_batch56.gd'),'--',*flags]
record={'passed':False,'mode':a.mode,'performance_accepted':False,'command':cmd};memory=[]
try:
    if a.mode=='perf':
        inventory=probe('perf',GAME);perf.write(run/'PROBE.json',inventory)
        if not inventory['eligible_snapshot']:raise RuntimeError('Perf not eligible; do not wait on user game')
    with Lease(a.mode,GAME,'read',180) as lease:
        before=perf.pins(GAME);perf.write(run/'SOURCE.json',before)
        harness={f.name:perf.sha(f) for f in OUT.iterdir() if f.suffix in ('.gd','.py')};perf.write(run/'HARNESS.json',harness)
        with (run/'stdout.log').open('wb') as stdout,(run/'stderr.log').open('wb') as stderr:
            process=subprocess.Popen(cmd,cwd=GAME,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
            record['child']=lease.register_child(process);started=time.monotonic();next_sample=started
            while process.poll() is None:
                if time.monotonic()-started>a.seconds+a.warmup+120:raise TimeoutError('Owned child bounded timeout')
                if time.monotonic()>=next_sample:
                    try:memory.append(perf.sample_memory(process))
                    except OSError:
                        if process.poll() is None:raise
                    if a.mode=='perf' and not lease.audit_perf():raise RuntimeError('PERF_CONTAMINATED')
                    if (run/'stderr.log').stat().st_size:
                        error=(run/'stderr.log').read_text(encoding='utf-8',errors='replace')
                        if 'SCRIPT ERROR:' in error or 'Parse Error:' in error:raise RuntimeError('Native script error; owned child stopped')
                    next_sample=time.monotonic()+1
                time.sleep(.1)
            record['exit_code']=process.returncode;record['elapsed_seconds']=time.monotonic()-started
        after=perf.pins(GAME);record['source_drift']=[f for f in set(before)|set(after) if before.get(f)!=after.get(f)]
        record['harness_drift']=[f for f,h in harness.items() if perf.sha(OUT/f)!=h]
        record['errors']=[line for f in ['stdout.log','stderr.log'] for line in (run/f).read_text(encoding='utf-8',errors='replace').splitlines() if ERRORS.search(line)]
        record['stderr_bytes']=(run/'stderr.log').stat().st_size
        native=json.loads((run/'MASS30.json').read_text(encoding='utf-8'))
        record['native_ok']=native['ok'];record['perf_environment_clean']=lease.audit_perf() if a.mode=='perf' else None
        record['passed']=process.returncode==0 and native['ok'] and not record['source_drift'] and not record['harness_drift'] and not record['errors'] and not record['stderr_bytes'] and record['perf_environment_clean'] is not False
        frames=native['frame_ms'];record['frame_ms']={f'p{p}':perf.pct(frames,p/100) for p in [50,95,99]};record['moved_residents']=native['moved_residents'];record['logic_cost']=native['snapshot'].get('logic_cost',{})
except Exception as e:record['error']=str(e)
finally:
    perf.write(run/'OS_MEMORY.json',{'samples':memory});perf.write(run/'RUN.json',record)
print(json.dumps({k:v for k,v in record.items() if k not in ['command','child','errors']},ensure_ascii=True));sys.exit(0 if record['passed'] else 1)
