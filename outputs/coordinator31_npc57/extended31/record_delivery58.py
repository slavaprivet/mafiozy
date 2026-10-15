"""Record an already-opened, verified ordinary58 game. Never launch or close it."""
import argparse,ctypes,datetime,hashlib,json,pathlib,re,sys,zipfile
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2]
TOOLS=HERE.parent/'proposals/release58_tools';RELEASE=ROOT/'outputs/coordinator31_release58'
sys.path.insert(0,str(ROOT));sys.path.insert(0,str(TOOLS))
from tools.godot.test_scheduler import inventory,identity,command_project,canonical
from startup58 import validate_release

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write_new(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')

def filetime(iso):
    value=datetime.datetime.fromisoformat(iso)
    delta=value.astimezone(datetime.timezone.utc)-datetime.datetime(1601,1,1,tzinfo=datetime.timezone.utc)
    fraction=re.search(r'\.(\d+)',iso);tail=(fraction.group(1)+'0000000')[6] if fraction else '0'
    return str((delta.days*86400+delta.seconds)*10000000+delta.microseconds*10+int(tail))

def argv_windows(command):
    shell=ctypes.WinDLL('shell32',use_last_error=True);kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    shell.CommandLineToArgvW.argtypes=[ctypes.c_wchar_p,ctypes.POINTER(ctypes.c_int)]
    shell.CommandLineToArgvW.restype=ctypes.POINTER(ctypes.c_wchar_p)
    kernel.LocalFree.argtypes=[ctypes.c_void_p];kernel.LocalFree.restype=ctypes.c_void_p
    count=ctypes.c_int();values=shell.CommandLineToArgvW(command,ctypes.byref(count))
    assert values,'Cannot parse exact ordinary process command'
    try:return [values[i] for i in range(count.value)]
    finally:kernel.LocalFree(ctypes.cast(values,ctypes.c_void_p))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--startup',type=pathlib.Path,required=True)
    p.add_argument('--plan',type=pathlib.Path,required=True);p.add_argument('--go',action='store_true');a=p.parse_args()
    proposed,assembly,bootstrap,game,source,wanted=validate_release(RELEASE)
    assert read(ROOT/'godot/current_version.json')==proposed
    opened=read(ROOT/'outputs/current_game/OPENED.json');ordinary=pathlib.Path(opened['run_directory']).resolve()
    ordinary.relative_to(ROOT/'outputs/current_game/interactive')
    assert opened==read(ordinary/'OPENED.json') and opened['ready'] is True and opened['window_handle']!=0
    assert opened['revision']==proposed['revision']=='s01-20261015-residents58'
    assert opened['assembly_sha256']==sha(RELEASE/'ASSEMBLY.json')==proposed['assembly_sha256']
    assert read(ordinary/'RELEASE.json')==proposed
    ready=read(ordinary/'CURRENT_READY.json');startup=a.startup.resolve();startup.relative_to(TOOLS/'runs')
    assert ready['ok'] is True and ready['actual_revision']==ready['revision']==proposed['revision']
    assert ready['actual_ids']==wanted and ready['resident_count']==10 and ready['staff_count']==12
    assert ready['original_catalogue_count']==287 and ready['interactive'] is True
    assert (ordinary/'play.err').stat().st_size==0
    initial=read(startup/'RUN.json');activation=read(TOOLS/'ACTIVATION58.json')
    assert initial['passed'] is True and initial['ordinary_ready'] is True
    assert activation['activated'] is True and activation['startup_sha256']==sha(startup/'RUN.json')
    assert read(startup/'SOURCE.json')==read(startup/'SOURCE_AFTER.json')==source
    process_id=int(opened['pid']);current=inventory(process_id)
    assert len(current)==1 and current[0]['creation_filetime']==filetime(opened['started_at'])
    live=current[0];assert identity(process_id)=={k:live[k] for k in ['pid','creation_filetime']}
    assert command_project(live)==canonical(game) and proposed['title'] in live['title']
    command=argv_windows(live['command_line']);assert command.count('--path')==command.count('--script')==1
    assert pathlib.Path(command[command.index('--script')+1]).resolve()==bootstrap
    assert '--headless' not in command and '--editor' not in command and '--city-play-check=1' not in command
    extras=command[command.index('--')+1:]
    expected=assembly['launch_arguments']+['--receipt-dir='+str(ordinary),'--release-title='+proposed['title'],
        '--release-revision='+proposed['revision']]
    assert sorted(extras)==sorted(expected) and sha(pathlib.Path(live['executable']))==proposed['engine_sha256']
    plan_path=a.plan.resolve();plan_path.relative_to(ROOT);plan=read(plan_path)
    acceptance=read(RELEASE/'ACCEPTANCE.json')
    assert acceptance['evidence_file_pins'][str(plan_path)]==sha(plan_path)
    soak=ROOT/plan['evidence']['soak']['run'];audit_path=soak/'FINAL_AUDIT58.json'
    assert acceptance['evidence_file_pins'][str(audit_path.resolve())]==sha(audit_path)
    audit=read(audit_path)
    assert audit['passed'] is True and audit['seconds']>=1200
    metrics=acceptance['metrics']['candidate']
    result={'ordinary_ready':True,'revision':proposed['revision'],'resident_count':10,'staff_count':12,
        'catalogue_count':287,'assembly_sha256':proposed['assembly_sha256'],
        'ordinary_run':ordinary.relative_to(ROOT).as_posix(),'window_pid_at_delivery':process_id,
        'process_identity_at_delivery':live,'recorded_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'mean_fps':metrics['mean_fps'],'p95_ms':metrics['p95_ms'],'p99_ms':metrics['p99_ms'],
        'measurement_seconds':metrics['seconds'],'render_size':metrics['camera']['render_size'],
        'performance_gates':acceptance['metrics']['gates'],'soak_seconds':audit['seconds'],
        'soak_purchases':audit['completion_deltas']['shop'],'soak_walks':audit['completion_deltas']['walk'],
        'soak_max_motion_idle_seconds':audit['max_motion_idle_s'],'soak_max_queue_seconds':audit['max_queue_idle_s'],
        'spatial_liveness_accepted':acceptance['spatial_liveness_accepted'],
        'service_interruptions_accepted':acceptance['service_interruptions_accepted'],
        'service_interruption_gates':acceptance['service_interruption_gates'],
        'next_batch':20,'next_batch_activated':False,'full_city_performance_accepted':False,
        'fps_complaint_fully_resolved':False,
        'limitations':'Finite exact10+12 behavior/performance acceptance; no perpetual liveness or all287 performance claim.'}
    if not a.go:print(json.dumps({'verified':True,'would_record':result,'processes_modified':False},ensure_ascii=True));return
    assert not (RELEASE/'DELIVERY.json').exists() and not (RELEASE/'DELIVERY_EVIDENCE.zip').exists()
    members={f'startup58/{f.name}':f for f in startup.iterdir() if f.is_file()}
    members.update({f'ordinary58/{name}':ordinary/name for name in ['OPENED.json','STARTED.json','CURRENT_READY.json','RELEASE.json']})
    members.update({'ACTIVATION58.json':TOOLS/'ACTIVATION58.json','FINAL_AUDIT58.json':soak/'FINAL_AUDIT58.json',
        'record_delivery58.py':pathlib.Path(__file__),'RELEASE_PLAN58.json':plan_path})
    data={name:f.read_bytes() for name,f in members.items()}
    with zipfile.ZipFile(RELEASE/'DELIVERY_EVIDENCE.zip','x',zipfile.ZIP_DEFLATED) as z:
        for name,body in data.items():z.writestr(name,body)
    with zipfile.ZipFile(RELEASE/'DELIVERY_EVIDENCE.zip') as z:
        assert set(z.namelist())==set(data) and all(z.read(name)==body for name,body in data.items())
    assert identity(process_id)=={k:live[k] for k in ['pid','creation_filetime']}
    result.update(delivery_evidence='DELIVERY_EVIDENCE.zip',delivery_evidence_sha256=sha(RELEASE/'DELIVERY_EVIDENCE.zip'))
    write_new(RELEASE/'DELIVERY.json',result)
    print(json.dumps({'delivered':True,'revision':result['revision'],'pid':process_id,'mean_fps':result['mean_fps']}))

if __name__=='__main__':main()
