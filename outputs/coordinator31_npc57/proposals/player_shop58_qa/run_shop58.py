from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,zipfile
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
GAME=HERE.parents[1]/'game'
CASES={'modules':('test_player_shop.gd','headless',35),'defaults':('test_player_shop_defaults.gd','headless',35),'ui':('test_player_shop_ui.gd','headless',45),'city':('test_shop_city57.gd','headless',180),'pose':('test_player_pose57.gd','graphical',180)}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def pins():return {p.relative_to(GAME).as_posix():sha(p) for p in GAME.rglob('*') if p.is_file() and '.godot' not in p.relative_to(GAME).parts}
def save(p,v):p.write_text(json.dumps(v,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
parser=argparse.ArgumentParser();parser.add_argument('case',choices=CASES);parser.add_argument('name');parser.add_argument('--expected-source',required=True,type=Path);parser.add_argument('--expected-sha256',required=True);parser.add_argument('--go',action='store_true');args=parser.parse_args()
assert args.name.replace('_','').isalnum()
manifest=args.expected_source.resolve();assert sha(manifest)==args.expected_sha256
expected=read(manifest);before=pins();assert expected['source_pins']==before
flags=expected['launch_arguments'];assert '--city-player-shop=1' in flags
fixture,mode,timeout=CASES[args.case]
entry=HERE/('entry_'+args.case+'58.gd')
native_test=GAME/'scripts/shop/tests'/fixture
assert entry.is_file() and native_test.is_file()
run=HERE/'runs'/args.name;assert not run.exists()
engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
assert sha(engine)==read(ROOT/'docs/godot/ENGINE_LOCK.json')['editor']['gui']['sha256']
controls=[Path(__file__),HERE/'prepare_wrappers58.py',entry,native_test,manifest,ROOT/'tools/godot/test_scheduler.py',ROOT/'docs/godot/ENGINE_LOCK.json',ROOT/'godot/current_version.json']
cp={str(p):sha(p) for p in controls}
if not args.go:
    print(json.dumps({'dry_run':True,'case':args.case,'source_count':len(before),'source_manifest_sha256':args.expected_sha256,'mode':mode,'native_test_sha256':sha(native_test)}));sys.exit(0)
command=[sys.executable,str(ROOT/'tools/godot/test_scheduler.py'),'run','--mode',mode,'--project',str(GAME),'--access','read','--wait-seconds','600','--timeout',str(timeout),'--out',str(run),'--',str(engine),*(['--headless'] if mode=='headless' else []),'--path',str(GAME),'--script',str(entry),'--','--qa-out='+str(run),*flags]
result=subprocess.run(command,capture_output=True,timeout=timeout+660)
run.mkdir(parents=True,exist_ok=True)
after=pins();after_cp={str(p):sha(p) for p in controls}
save(run/'SOURCE.json',before);save(run/'SOURCE_AFTER.json',after);save(run/'CONTROL_PINS.json',cp);save(run/'CONTROL_PINS_AFTER.json',after_cp)
with zipfile.ZipFile(run/'HARNESS.zip','x',zipfile.ZIP_DEFLATED) as archive:
    for path in controls:archive.write(path,path.relative_to(ROOT).as_posix())
stdout=(run/'stdout.log').read_text(encoding='utf-8-sig',errors='replace') if (run/'stdout.log').exists() else ''
stderr=(run/'stderr.log').read_text(encoding='utf-8-sig',errors='replace') if (run/'stderr.log').exists() else ''
native={}
decoder=json.JSONDecoder()
for index,char in enumerate(stdout):
    if char!='{':continue
    try: candidate,_=decoder.raw_decode(stdout[index:])
    except ValueError:continue
    if isinstance(candidate,dict) and isinstance(candidate.get('checks'),int) and isinstance(candidate.get('failures'),list) and ('passed' in candidate or 'ok' in candidate):native=candidate
engine_clean=not any(marker in stderr for marker in ['SCRIPT ERROR:','ERROR:','Parse Error:'])
passed=result.returncode==0 and engine_clean and before==after and cp==after_cp and bool(native.get('passed',native.get('ok',False))) and native.get('failures')==[]
report={'passed':passed,'case':args.case,'native':native,'source_count':len(before),'source_drift':before!=after,'control_drift':cp!=after_cp,'engine_clean':engine_clean,'source_manifest':str(manifest),'source_manifest_sha256':args.expected_sha256,'native_test_sha256':sha(native_test),'engine_sha256':sha(engine),'production_changed':False,'original_fixture_unchanged':True,'scope':'Existing exact shop fixture with only delayed startup wrapper. City test calls live purchase/projectile ports; it does not prove physical walk-in/E, native mouse windup, NPC/home lifecycle, or performance.'}
save(run/'RUN.json',report);print(json.dumps({k:v for k,v in report.items() if k!='native'},ensure_ascii=True));print(json.dumps({'checks':native.get('checks'),'failures':native.get('failures')}))
sys.exit(0 if passed else 1)
