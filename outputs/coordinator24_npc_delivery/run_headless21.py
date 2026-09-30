"""Bounded, serialized NPC24c source import/ordinary observer. Never GPU/export."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, os, re, shlex, subprocess, time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT / 'outputs/coordinator24_quality/candidate21/godot/mafiozi_walk'
ENGINE_DIR = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2'
FLAGS = subprocess.CREATE_NO_WINDOW
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
load = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
now = lambda: datetime.now(timezone.utc).isoformat()
args = argparse.ArgumentParser()
args.add_argument('--out', required=True)
args.add_argument('--game25', action='store_true', help='Use immutable merged candidate25 and its exact 224 source pins')
args.add_argument('--mode', choices=['both','import','observer'], default='both')
args.add_argument('--plan-detour', action='store_true')
args.add_argument('--require-clearance-wait', action='store_true')
args.add_argument('--trace-252', action='store_true')
args.add_argument('--require-floor-recovery', action='store_true')
args.add_argument('--allow-live24b', action='store_true', help='Root-authorized functional-only coexistence with exact quick_controls game command; never performance')
args.add_argument('--allow-live25-pack', help='Root-authorized ordinary user game using this exact candidate25 PCK; GUI main-pack or its sibling release executable only')
args.add_argument('--allow-combat24-headless', action='store_true', help='Root-authorized isolated candidate24 combat CPU test; never performance')
a = args.parse_args()
if a.game25:
    GAME = ROOT / 'outputs/coordinator24_quality/candidate25/godot/mafiozi_walk'
out = Path(a.out).resolve()
assert out.is_relative_to(HERE) and not out.exists()
out.mkdir()
report = {'started_utc':now(),'mode':a.mode,'headless':True,'gpu':False,'engine_timeout_seconds':100,'production_changed':False,'children':[],'functional_only_with_live24b':a.allow_live24b,'authorized_parallel_combat24_cpu':a.allow_combat24_headless,'performance_acceptance':False}

def save(): (out / 'RUN.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def inventory():
    script = "[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new(); $ErrorActionPreference='Stop'; $rows=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|MafioziPreview' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine); ConvertTo-Json -InputObject $rows -Depth 3 -Compress"
    cmd = ['powershell.exe','-NoProfile','-NonInteractive','-Command',script]
    p = subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=20,creationflags=FLAGS)
    assert p.returncode == 0, p.stderr.decode('utf-8','replace')
    value = json.loads(p.stdout.decode('utf-8-sig','replace'))
    return value if isinstance(value,list) else [value]
def permit_idle(rows):
    expected_live='"'+str(ENGINE_DIR/'Godot_v4.7.2-stable_win64.exe')+'" --main-pack "'+str(ROOT/'godot/mafiozi_walk/exports/win64/s01-20260930-quality24b-play/MafioziPreview.pck')+'" --script "'+str(ROOT/'outputs/quick_controls_20260930/play.gd')+'"'
    def allowed(row):
        if row['ProcessId']==45268 and row['Name']=='Godot_v4.6.3-stable_win64.exe' and '--headless' not in (row['CommandLine'] or '') and '--path' not in (row['CommandLine'] or ''): return True
        if a.allow_live25_pack:
            tokens=[x.strip('"') for x in shlex.split(row['CommandLine'] or '',posix=False)]
            live_pack=Path(a.allow_live25_pack).resolve()
            if row['Name']=='Godot_v4.7.2-stable_win64.exe' and tokens==[str(ENGINE_DIR/'Godot_v4.7.2-stable_win64.exe'),'--main-pack',str(live_pack)]: return True
            if row['Name']=='MafioziPreview.exe' and tokens==[str(live_pack.with_suffix('.exe'))]: return True
        if a.allow_combat24_headless and row['Name']=='Godot_v4.7.2-stable_win64.exe':
            tokens=[x.strip('"') for x in shlex.split(row['CommandLine'] or '',posix=False)]
            if '--headless' in tokens and '--path' in tokens:
                index=tokens.index('--path')
                if index+1<len(tokens) and tokens[index+1]==str(ROOT/'outputs/coordinator24_quality/candidate24/godot/mafiozi_walk'): return True
        return a.allow_live24b and row['Name']=='Godot_v4.7.2-stable_win64.exe' and (row['CommandLine'] or '').strip()==expected_live
    busy = [row for row in rows if not allowed(row)]
    assert not busy, 'Foreign engine active; did not kill it: '+json.dumps(busy,ensure_ascii=False)
def check_pins():
    errors=[]
    for row in pins['inputs']:
        path=GAME / row['path']
        if not path.is_file() or path.stat().st_size!=row['bytes'] or sha(path)!=row['sha256']: errors.append(row['path'])
    return errors
def run_child(label, command):
    before=inventory(); permit_idle(before)
    record={'label':label,'command':command,'inventory_before':before,'started_utc':now(),'timeout':False}
    report['children'].append(record); save()
    started=time.monotonic()
    with (out / (label+'.log')).open('w',encoding='utf-8') as log:
        process=subprocess.Popen(command,cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=FLAGS)
        record['pid']=process.pid; save()
        print(json.dumps({'started':label,'pid':process.pid}),flush=True)
        try: record['exit_code']=process.wait(timeout=100)
        except subprocess.TimeoutExpired:
            record['timeout']=True
            process.kill()  # Only the child launched above; never a foreign engine.
            record['exit_code']=process.wait(timeout=10)
    record['seconds']=time.monotonic()-started
    record['finished_utc']=now()
    text=(out / (label+'.log')).read_text(encoding='utf-8',errors='replace')
    record['engine_error_lines']=[line for line in text.splitlines() if re.match(r'^(SCRIPT ERROR:|SHADER ERROR:|ERROR:)',line)]
    record['native_errors']=bool(record['engine_error_lines']) or 'Parse Error:' in text
    record['pins_changed']=check_pins()
    record['harness_unchanged']=sha(harness)==report['harness_sha256']
    record['inventory_after']=inventory()
    record['own_child_stopped']=all(row['ProcessId']!=record['pid'] for row in record['inventory_after'])
    record['ok']=record['exit_code']==0 and not record['timeout'] and not record['native_errors'] and not record['pins_changed'] and record['harness_unchanged'] and record['own_child_stopped']
    save()
    print(json.dumps({key:record[key] for key in ['label','pid','exit_code','seconds','ok','native_errors','pins_changed','own_child_stopped']}),flush=True)
    return record['ok']

try:
    pins_path=HERE / ('combined25/ASSEMBLY25.json' if a.game25 else 'ASSEMBLY24C.json'); pins=load(pins_path)
    input_count=224 if a.game25 else 218
    assert len(pins['inputs'])==input_count
    pins_copy=out / ('PINS'+str(input_count)+'.json')
    report['pins_sha256']=sha(pins_path); report['input_count']=input_count
    pins_copy.write_bytes(pins_path.read_bytes())
    assert not check_pins(), 'Stage no longer matches assembly'
    harness=HERE / 'test_normal_scene.gd'
    report['harness_sha256']=sha(harness)
    (out / 'observer_executed.gd').write_bytes(harness.read_bytes())
    lock_path=GAME.parents[1] / 'docs/godot/ENGINE_LOCK.json'
    lock=load(lock_path)
    engine=ENGINE_DIR / lock['editor']['gui']['filename']
    for variant in ['gui','console']:
        locked=lock['editor'][variant]; path=ENGINE_DIR / locked['filename']
        assert path.stat().st_size==locked['bytes'] and sha(path)==locked['sha256'], variant+' engine lock'
    report['engine_sha256']=sha(engine); report['engine_version_lock']=lock['versionString']; report['engine_lock_sha256']=sha(lock_path)
    if a.allow_live25_pack:
        live_pack=Path(a.allow_live25_pack).resolve()
        assert a.game25 and live_pack.name=='MafioziPreview.pck'
        assert sha(live_pack)=='fa1504583eefd212211a87ced7c2fc7805885213aa71d9211c63447f4ac74863'
        assert sha(live_pack.with_suffix('.exe'))=='d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'
        report['allowed_live25']={'pack':str(live_pack),'pck_sha256':sha(live_pack),'commands':'Exact GUI --main-pack path or sibling release executable with no other arguments','authorization':'Root explicit functional headless beside already opened exact25 user game; no GPU/performance acceptance'}
    if a.allow_live24b:
        live_pack=ROOT/'godot/mafiozi_walk/exports/win64/s01-20260930-quality24b-play/MafioziPreview.pck'
        assert sha(live_pack)=='becb595b967ca70fe31660e137a9e591a17abb2418259733fa707342ddc7a749'
        report['allowed_user_game']={'pid':'fresh inventory; exact full non-headless quick_controls command only','pck_sha256':sha(live_pack),'script_sha256':sha(ROOT/'outputs/quick_controls_20260930/play.gd'),'authorization':'Root explicit latest: quick_controls user game does not block functional headless, preserve it; foreign heavy headless must block; no performance conclusions'}
    report['inventory_before']=inventory(); permit_idle(report['inventory_before']); save()
    passed=True
    if a.mode in ['both','import']:
        passed=run_child('import',[str(engine),'--headless','--path',str(GAME),'--editor','--import'])
    if passed and a.mode in ['both','observer']:
        observer_out=out / 'observer'; observer_out.mkdir()
        main_sha=next(row['sha256'] for row in pins['inputs'] if row['path']=='scripts/main.gd')
        command=[str(engine),'--headless','--fixed-fps','60','--path',str(GAME),'--script',str(harness),'--','--out='+str(observer_out),'--revision=s01-20260930-quality24c','--pins='+str(pins_copy),'--source-root='+str(GAME),'--expected-sha='+main_sha]
        if a.plan_detour: command.append('--plan-detour')
        if a.require_clearance_wait: command.append('--require-clearance-wait')
        if a.trace_252: command.append('--trace-252')
        if a.require_floor_recovery: command.append('--require-floor-recovery')
        passed=run_child('observer',command)
        result_path=observer_out / 'RESULT.json'
        if result_path.is_file():
            result=load(result_path)
            report['observer_result']={'sha256':sha(result_path),'valid':result.get('valid'),'checks':result.get('checks'),'errors':result.get('errors'),'phase':result.get('visit',{}).get('phase'),'frames':result.get('observed_physics_frames'),'post_completion_travel_m':result.get('post_completion_travel_m')}
            passed=passed and result.get('valid') is True
        else: passed=False; report['missing_observer_result']=True
    report['valid']=bool(passed)
except Exception as error:
    report['valid']=False; report['runner_error']=str(error)
finally:
    report['finished_utc']=now()
    try: report['inventory_final']=inventory()
    except Exception as error: report['final_inventory_error']=str(error)
    report['runner_sha256']=sha(Path(__file__).resolve())
    save()
print(json.dumps({key:report.get(key) for key in ['valid','runner_error','observer_result','inventory_final']}),flush=True)
raise SystemExit(0 if report.get('valid') else 1)
