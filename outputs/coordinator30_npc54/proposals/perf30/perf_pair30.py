"""Exclusive, bounded 1-resident performance pair. Only the owned child is sampled/stopped."""
import argparse, ctypes, hashlib, json, math, os, pathlib, statistics, subprocess, sys, time
from ctypes import wintypes

OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[3]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease, probe, ERRORS
SCHEDULER_SHA='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
MIB=1024*1024
POLICY={
    'warmup_seconds':20,'measurement_seconds':180,'seed':53,
    'p95_relative_limit':1.10,'p95_absolute_allowance_ms':1.0,
    'p99_relative_limit':1.15,'p99_absolute_allowance_ms':2.0,
    'p95_frame_budget_ms':1000/60,'mean_fps_relative_floor':.90,
    'late_vs_early_p95_relative_limit':1.15,'late_vs_early_p95_allowance_ms':2.0,
    'rss_private_growth_review_mib':32,'rss_private_slope_review_mib_per_min':8,
    'static_growth_review_mib':16,'static_slope_review_mib_per_min':4,
    'object_growth_review':128,'node_growth_review':8,'resource_growth_review':16,
    'leak_claim':'Finite-window signals only; no proof of absence of all leaks.'}

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def pins(game):
    return {p.relative_to(game).as_posix():sha(p) for p in game.rglob('*') if p.is_file() and '.godot' not in p.parts}
def harness_pins():return {p.name:sha(p) for p in OUT.iterdir() if p.is_file() and p.suffix in ('.py','.gd')}

class PROCESS_MEMORY_COUNTERS_EX(ctypes.Structure):
    _fields_=[('cb',wintypes.DWORD),('PageFaultCount',wintypes.DWORD)]+[(name,ctypes.c_size_t) for name in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage','PrivateUsage']]

def sample_memory(process):
    counters=PROCESS_MEMORY_COUNTERS_EX();counters.cb=ctypes.sizeof(counters)
    function=ctypes.WinDLL('psapi',use_last_error=True).GetProcessMemoryInfo
    function.argtypes=[wintypes.HANDLE,ctypes.POINTER(PROCESS_MEMORY_COUNTERS_EX),wintypes.DWORD]
    function.restype=wintypes.BOOL
    if not function(wintypes.HANDLE(int(process._handle)),ctypes.byref(counters),counters.cb):
        raise ctypes.WinError(ctypes.get_last_error())
    return {'unix_ms':time.time()*1000,'pid':process.pid,'rss_bytes':int(counters.WorkingSetSize),'private_bytes':int(counters.PrivateUsage),'peak_rss_bytes':int(counters.PeakWorkingSetSize),'pagefile_bytes':int(counters.PagefileUsage),'page_faults':int(counters.PageFaultCount)}

def common_flags(warmup,samples,seed):
    assembly=json.loads((ROOT/'outputs/coordinator29_release53a/ASSEMBLY.json').read_text(encoding='utf-8'))
    # Actual ordinary53a flags, including full HP and all eight new sites. Staff is enabled
    # in both commands; the old build has no staff implementation to remove.
    flags=[f for f in assembly['launch_arguments'] if not f.startswith(('--city-sandbox-seed=','--city-venue-staff29=','--qa-'))]
    flags+=['--city-venue-staff29=1',f'--city-sandbox-seed={seed}',f'--qa-warmup={warmup}',f'--qa-samples={samples}']
    assert '--city-hp=100' in flags and '--city-venue-sites29=1' in flags
    return flags

def run_one(name,game,run,staff,flags):
    game=game.resolve();run.mkdir(parents=True,exist_ok=False)
    engine=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    lock=json.loads((ROOT/'docs/godot/ENGINE_LOCK.json').read_text(encoding='utf-8-sig'))
    assert sha(engine)==lock['editor']['gui']['sha256'],'Engine lock mismatch'
    assert sha(ROOT/'tools/godot/test_scheduler.py')==SCHEDULER_SHA,'Scheduler source changed'
    available=probe('perf',game)
    write(run/'PROBE.json',available)
    if not available['eligible_snapshot']:
        write(run/'RUN.json',{'passed':False,'reason':'perf_not_eligible_snapshot','probe':available})
        return False
    command=[str(engine),'--path',str(game),'--script',str(OUT/'entry_perf30.gd'),'--',*flags,'--qa-out='+str(run),'--qa-expected-staff='+str(staff)]
    record={'name':name,'mode':'perf','project':str(game),'command':command,'passed':False,'performance_accepted':False,'policy':POLICY,'engine_sha256':sha(engine),'scheduler_sha256':SCHEDULER_SHA}
    memory=[];lease=None;process=None;before={};harness=harness_pins();write(run/'HARNESS_PINS.json',harness)
    try:
        with Lease('perf',game,'read',10) as lease:
            record['lease']=lease.request
            before=pins(game);write(run/'SOURCE.json',before)
            with (run/'stdout.log').open('wb') as stdout,(run/'stderr.log').open('wb') as stderr:
                process=subprocess.Popen(command,cwd=game,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
                record['child']=lease.register_child(process)
                started=time.monotonic();next_sample=started
                timeout=float(next(f.split('=',1)[1] for f in flags if f.startswith('--qa-samples=')))+float(next(f.split('=',1)[1] for f in flags if f.startswith('--qa-warmup=')))+115
                while process.poll() is None:
                    if time.monotonic()-started>timeout:raise TimeoutError('Owned child watchdog timeout')
                    if time.monotonic()>=next_sample:
                        sample_started=time.monotonic()
                        try:memory.append(sample_memory(process))
                        except OSError:
                            if process.poll() is None:raise
                        if not lease.audit_perf():raise RuntimeError('PERF_CONTAMINATED during observation')
                        record['max_sampler_audit_ms']=max(record.get('max_sampler_audit_ms',0),(time.monotonic()-sample_started)*1000)
                        next_sample=time.monotonic()+1.0
                    time.sleep(.1)
                record['exit_code']=process.returncode;record['elapsed_seconds']=time.monotonic()-started
            after=pins(game);record['source_drift']=[k for k in set(before)|set(after) if before.get(k)!=after.get(k)]
            record['harness_drift']=[k for k,v in harness.items() if sha(OUT/k)!=v]
            errors=[]
            for filename in ['stdout.log','stderr.log']:
                errors.extend(line for line in (run/filename).read_text(encoding='utf-8-sig',errors='replace').splitlines() if ERRORS.search(line))
            record['errors']=errors;record['stderr_bytes']=(run/'stderr.log').stat().st_size
            record['perf_environment_clean']=lease.audit_perf()
            native=json.loads((run/'PERF30.json').read_text(encoding='utf-8'))
            record['native_ok']=native.get('ok',False)
            record['passed']=process.returncode==0 and record['native_ok'] and not errors and record['stderr_bytes']==0 and not record['source_drift'] and not record['harness_drift'] and record['perf_environment_clean']
        record['perf_environment_clean']=not lease.perf_contaminated
        record['passed']=record['passed'] and record['perf_environment_clean']
    except Exception as error:
        record.update(passed=False,error=str(error))
    finally:
        # Lease context owns exact Popen child cleanup, including exceptional exit.
        write(run/'OS_MEMORY.json',{'scope':'Owned process working set and private committed bytes; excludes dedicated GPU allocation','samples':memory})
        write(run/'RUN.json',record)
    return record['passed']

def pct(values,p):
    values=sorted(values)
    return values[min(len(values)-1,int((len(values)-1)*p))] if values else None

def trend(rows,key,time_key):
    values=[(float(row[time_key])/1000,float(row[key])) for row in rows if key in row]
    if not values:return {}
    n=min(30,max(1,len(values)//3))
    first=statistics.mean(y for _,y in values[:n]);last=statistics.mean(y for _,y in values[-n:])
    mx=statistics.mean(x for x,_ in values);my=statistics.mean(y for _,y in values)
    den=sum((x-mx)**2 for x,_ in values)
    slope=60*sum((x-mx)*(y-my) for x,y in values)/den if den else 0
    return {'first_sample':values[0][1],'last_sample':values[-1][1],'first_window_mean':first,'last_window_mean':last,'window_samples':n,'delta':last-first,'slope_per_minute':slope,'min':min(y for _,y in values),'max':max(y for _,y in values)}

def summarize(run):
    native=json.loads((run/'PERF30.json').read_text(encoding='utf-8'))
    receipt=json.loads((run/'RUN.json').read_text(encoding='utf-8'))
    game=[r for r in native['samples'] if r['measure_ms']>=0]
    os_rows=json.loads((run/'OS_MEMORY.json').read_text(encoding='utf-8'))['samples']
    os_rows=[r for r in os_rows if native['measurement_start_unix_ms']<=r['unix_ms']<=native['measurement_end_unix_ms']]
    frames=native['frame_ms'];times=native['frame_at_s']
    early=[v for v,t in zip(frames,times) if t<60]
    late=[v for v,t in zip(frames,times) if t>=native['measurement_seconds']-60]
    memory={key:trend(os_rows,key,'unix_ms') for key in ['rss_bytes','private_bytes']}
    memory.update({key:trend(game,key,'measure_ms') for key in ['static_memory','objects','nodes','resources','orphans','video_memory','texture_memory','buffer_memory']})
    work={key:trend(game,key,'measure_ms') for key in ['route_jobs','route_nodes','route_heap','nav_pending','nav_guides','nav_maps','registry_entries','registry_actors','service_keys']}
    warnings=[]
    for key in ['rss_bytes','private_bytes','static_memory']:
        value=memory[key];is_static=key=='static_memory'
        if value and value['delta']>POLICY['static_growth_review_mib' if is_static else 'rss_private_growth_review_mib']*MIB and value['slope_per_minute']>POLICY['static_slope_review_mib_per_min' if is_static else 'rss_private_slope_review_mib_per_min']*MIB:warnings.append('sustained_'+key+'_growth')
    for key,limit in [('objects',POLICY['object_growth_review']),('nodes',POLICY['node_growth_review']),('resources',POLICY['resource_growth_review']),('orphans',0)]:
        if memory[key] and memory[key]['delta']>limit:warnings.append(key+'_growth_requires_review')
    if not os_rows:warnings.append('no_os_samples_in_measurement')
    if work['route_jobs']['max']>2 or work['nav_pending']['max']>1:warnings.append('unexpected_work_queue_size')
    return {'run_ok':receipt['passed'],'p50_ms':pct(frames,.5),'p95_ms':pct(frames,.95),'p99_ms':pct(frames,.99),'mean_fps':1000/statistics.mean(frames),'early60_p95_ms':pct(early,.95),'late60_p95_ms':pct(late,.95),'frames_over_33ms':sum(x>33.333 for x in frames),'memory':memory,'work':work,'review_flags':warnings,'camera':native['camera'],'moved_m':native['moved_m'],'coverage':native['coverage'],'staff':native['expected_staff'],'os_samples':len(os_rows),'samples':len(game),'max_sample_us':native['max_sample_us'],'max_observer_us':native['max_observer_us'],'editors':receipt['lease']['editor_identities'],'source_pin_sha256':sha(run/'SOURCE.json')}

def compare(pair):
    base=summarize(pair/'baseline53a');candidate=summarize(pair/'candidate54')
    camera_ok=base['camera']==candidate['camera']
    gates={'runs_native_and_exclusive_clean':base['run_ok'] and candidate['run_ok'],'identical_camera_and_viewport':camera_ok,'identical_editor_environment':base['editors']==candidate['editors'],'candidate_staff_preserved':candidate['staff']==12,'p95_no_material_regression':candidate['p95_ms']<=max(base['p95_ms']*POLICY['p95_relative_limit'],base['p95_ms']+POLICY['p95_absolute_allowance_ms']),'p99_no_material_regression':candidate['p99_ms']<=max(base['p99_ms']*POLICY['p99_relative_limit'],base['p99_ms']+POLICY['p99_absolute_allowance_ms']),'p95_within_60fps_frame_budget':candidate['p95_ms']<=POLICY['p95_frame_budget_ms'],'mean_fps_preserved':candidate['mean_fps']>=base['mean_fps']*POLICY['mean_fps_relative_floor'],'no_material_late_slowdown':candidate['late60_p95_ms']<=max(candidate['early60_p95_ms']*POLICY['late_vs_early_p95_relative_limit'],candidate['early60_p95_ms']+POLICY['late_vs_early_p95_allowance_ms']),'no_unreviewed_growth_signal':not candidate['review_flags']}
    result={'schema':'mafiozi.perf30.pair/v1','measured_gates_passed':all(gates.values()),'gates':gates,'policy':POLICY,'baseline':base,'candidate':candidate,'performance_accepted':False,'population286_performance_accepted':False,'scope':'1 resident and 12 venues (4 existing plus 8 new); candidate retains 12 staff actors. Report flags finite-window growth, never establishes global absence of leaks.'}
    write(pair/'COMPARISON.json',result)
    lines=['# Performance30 — ограниченная парная проверка','',f"Измеренные условия: {'PASS' if result['measured_gates_passed'] else 'REVIEW / FAIL'}. Окончательная приёмка остаётся у координатора.",'','| Метрика | 53a | 54 |','|---|---:|---:|']
    for title,key in [('Кадр p50, мс','p50_ms'),('Кадр p95, мс','p95_ms'),('Кадр p99, мс','p99_ms'),('Средний FPS','mean_fps'),('Первые 60 с: p95, мс','early60_p95_ms'),('Последние 60 с: p95, мс','late60_p95_ms')]:lines.append(f'| {title} | {base[key]:.3f} | {candidate[key]:.3f} |')
    lines+=['','| Память версии 54 | Начало | Конец | Δ | Тренд / мин |','|---|---:|---:|---:|---:|']
    for key in ['rss_bytes','private_bytes','static_memory']:
        m=candidate['memory'][key]
        if m:lines.append(f"| {key},MiB | {m['first_window_mean']/MIB:.2f} | {m['last_window_mean']/MIB:.2f} | {m['delta']/MIB:+.2f} | {m['slope_per_minute']/MIB:+.2f} |")
    lines+=['',f"Сигналы для разбора: {', '.join(candidate['review_flags']) or 'пороговые сигналы в этом окне не обнаружены'}.",'','Полные диапазоны числа узлов, ресурсов и задач, положение камеры, покрытие поведения и критерии находятся в COMPARISON.json. Рост RSS сам по себе не доказывает утечку; короткое наблюдение не доказывает её отсутствие. Проверен один житель; восемь новых и четыре прежних заведения сохранены, в новой сборке работают 12 сотрудников. Это не проверка 286 жителей.']
    (pair/'REPORT.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','run','compare']);p.add_argument('name');p.add_argument('--baseline',type=pathlib.Path,default=ROOT/'outputs/coordinator29_release53a/game');p.add_argument('--candidate',type=pathlib.Path,default=ROOT/'outputs/coordinator30_npc54/game');p.add_argument('--samples',type=int,default=180);p.add_argument('--warmup',type=int,default=20);p.add_argument('--seed',type=int,default=53);a=p.parse_args()
    assert 20<=a.warmup<=120 and 150<=a.samples<=600
    POLICY.update(warmup_seconds=a.warmup,measurement_seconds=a.samples,seed=a.seed)
    pair=OUT/'runs'/a.name;flags=common_flags(a.warmup,a.samples,a.seed)
    if a.action=='prepare':
        pair.mkdir(parents=True,exist_ok=False);write(pair/'PLAN.json',{'baseline':str(a.baseline.resolve()),'candidate':str(a.candidate.resolve()),'flags':flags,'policy':POLICY,'runs_not_started':True,'baseline_staff':0,'candidate_staff':12});print(str(pair/'PLAN.json'))
    elif a.action=='run':
        pair.mkdir(parents=True,exist_ok=True)
        write(pair/'PLAN.json',{'baseline':str(a.baseline.resolve()),'candidate':str(a.candidate.resolve()),'flags':flags,'policy':POLICY,'baseline_staff':0,'candidate_staff':12})
        if not run_one('baseline53a',a.baseline,pair/'baseline53a',0,flags):sys.exit(2)
        baseline_camera=json.loads((pair/'baseline53a/PERF30.json').read_text(encoding='utf-8'))['camera']
        candidate_flags=flags+['--qa-fixed-camera-json='+json.dumps(baseline_camera,separators=(',',':'))]
        if not run_one('candidate54',a.candidate,pair/'candidate54',12,candidate_flags):sys.exit(2)
        result=compare(pair);print(json.dumps({'comparison':str(pair/'COMPARISON.json'),'measured_gates_passed':result['measured_gates_passed']}));sys.exit(0 if result['measured_gates_passed'] else 3)
    else:print(json.dumps(compare(pair),ensure_ascii=True))
