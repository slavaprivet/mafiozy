"""Exact private lifecycle native runs through scheduler; no project copy."""
import argparse,hashlib,json,os,pathlib,subprocess,sys,zipfile
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3];GAME=OUT.parent/'injury30/game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import probe
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,data):p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def pins():return {p.relative_to(GAME).as_posix():sha(p) for p in GAME.rglob('*') if p.is_file() and '.godot' not in p.parts}
p=argparse.ArgumentParser();p.add_argument('name');p.add_argument('--case',choices=['import','single','multi'],required=True);p.add_argument('--graphical',action='store_true');a=p.parse_args()
assert a.name and all(c.isalnum() or c in '-_' for c in a.name)
mode='graphical' if a.graphical else 'headless';access='write' if a.case=='import' else 'read'
run=OUT/'runs'/a.name;run.mkdir(parents=True,exist_ok=False);admission=probe(mode,GAME,access);save(run/'PROBE.json',admission)
if not admission['eligible_snapshot']:print(json.dumps({'not_started':True,'probe':admission}));sys.exit(3)
engine=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
assert sha(engine)==json.loads((ROOT/'docs/godot/ENGINE_LOCK.json').read_text(encoding='utf-8-sig'))['editor']['gui']['sha256']
assert sha(ROOT/'tools/godot/test_scheduler.py')=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
flags=json.loads((ROOT/'outputs/coordinator29_npc53/death53_02/RUN_CHECK.json').read_text(encoding='utf-8'))['flags']
flags=[f for f in flags if not f.startswith(('--city-qa=','--city-hp=','--city-energy-start=','--city-wallet-start=','--qa-out=','--qa-duration=','--city-respawn-seconds='))]
flags+=['--city-qa='+('1' if a.case=='single' else '3'),'--city-hp=100','--city-physical-dispatch30=1','--city-venue-sites29=1','--city-venue-staff29=1','--city-respawn-seconds=3','--qa-out='+str(run)]
if a.case=='multi':flags+=['--city-multi-lifecycle30=1']
script=OUT/'qa'/('entry_single30.gd' if a.case=='single' else 'entry_multi30.gd')
before=pins();save(run/'SOURCE.json',before);save(run/'FLAGS.json',flags)
with zipfile.ZipFile(run/'CHANGED_SOURCES.zip','w',compression=zipfile.ZIP_DEFLATED) as z:
    for folder in ['scripts','qa']:
        for f in (OUT/folder).rglob('*.gd'):z.write(f,f.relative_to(OUT).as_posix())
    for f in ['run30.py','build30.py','stage30.py']:z.write(OUT/f,f)
command=[sys.executable,'-B',str(ROOT/'tools/godot/test_scheduler.py'),'run','--mode',mode,'--project',str(GAME),'--access',access,'--wait-seconds','30','--timeout','240' if a.case!='import' else '180','--out',str(run/'engine'),'--',str(engine)]
if not a.graphical:command+=['--headless']
command+=['--path',str(GAME)]
command+=['--editor','--import','--quit'] if a.case=='import' else ['--script',str(script),'--',*flags]
done=subprocess.run(command,cwd=ROOT,capture_output=True);(run/'runner.stdout.log').write_bytes(done.stdout);(run/'runner.stderr.log').write_bytes(done.stderr)
after=pins();save(run/'SOURCE_AFTER.json',after);drift=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
semantic=run/('DEATH28.json' if a.case=='single' else 'MULTILIFE30.json')
data=json.loads(semantic.read_text(encoding='utf-8')) if semantic.exists() else {}
result={'case':a.case,'exit':done.returncode,'source_drift':drift,'performance_accepted':False,'passed':done.returncode==0 and (not drift or a.case=='import' and all(k.endswith('.uid') for k in drift)) and (a.case=='import' or data.get('passed') is True)}
save(run/'RESULT.json',result);print(json.dumps(result));sys.exit(0 if result['passed'] else 1)
