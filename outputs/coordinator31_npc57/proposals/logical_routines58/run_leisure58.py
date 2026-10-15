from pathlib import Path
import hashlib,json,os,subprocess,sys,zipfile
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
GAME=HERE.parents[1]/'game'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def pins():return {p.relative_to(GAME).as_posix():sha(p) for p in GAME.rglob('*') if p.is_file() and '.godot' not in p.relative_to(GAME).parts}
def save(p,v):p.write_text(json.dumps(v,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
name=sys.argv[1]
run=HERE/'runs'/name
assert not run.exists()
before=pins();patch=read(HERE/'PATCH.json')
for row in patch['files']:
    assert before.get(row['path'])==row['base_sha256'],row['path']
    assert sha(HERE/'patch'/row['path'])==row['sha256']
controls=[HERE/'NEW_RESOURCES58.zip',HERE/'prepare_leisure58.py',HERE/'observer_leisure58.gd',HERE/'economy_additions58.txt',HERE/'leisure_begin58.txt',HERE/'PATCH.json',HERE/'entry_leisure58.gd',Path(__file__),HERE/'build_patch58.py',HERE/'daily_additions58.txt',ROOT/'tools/godot/test_scheduler.py',ROOT/'docs/godot/ENGINE_LOCK.json',ROOT/'godot/current_version.json']+[HERE/'patch'/r['path'] for r in patch['files']]
with zipfile.ZipFile(HERE/'NEW_RESOURCES58.zip','w',zipfile.ZIP_DEFLATED) as z:
    for row in patch['files']:
        if row['base_sha256'] is None:z.write(HERE/'patch'/row['path'],row['path'])
cp={str(p):sha(p) for p in controls}
engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
assert sha(engine)==read(ROOT/'docs/godot/ENGINE_LOCK.json')['editor']['gui']['sha256']
assembly=ROOT/'outputs/coordinator31_release57/ASSEMBLY.json'
candidate=ROOT/'outputs/coordinator31_npc57/extended31/stage58_04/CANDIDATE58.json'
assert read(candidate)['source_pins']==before
flags=read(assembly)['launch_arguments']
controls += [assembly,candidate]
cp={str(p):sha(p) for p in controls}
command=[sys.executable,str(ROOT/'tools/godot/test_scheduler.py'),'run','--mode','headless','--project',str(GAME),'--access','read','--wait-seconds','60','--timeout','180','--out',str(run),'--',str(engine),'--headless','--path',str(GAME),'--script',str(HERE/'entry_leisure58.gd'),'--','--qa-out='+str(run),*flags]
result=subprocess.run(command,capture_output=True,timeout=250)
after=pins();after_cp={str(p):sha(p) for p in controls}
save(run/'SOURCE.json',before);save(run/'SOURCE_AFTER.json',after);save(run/'CONTROL_PINS.json',cp);save(run/'CONTROL_PINS_AFTER.json',after_cp)
with zipfile.ZipFile(run/'HARNESS.zip','x',zipfile.ZIP_DEFLATED) as z:
    for p in controls:z.write(p,p.relative_to(ROOT).as_posix())
native=read(run/'LEISURE58.json') if (run/'LEISURE58.json').exists() else {}
report={'passed':result.returncode==0 and before==after and cp==after_cp and native.get('passed') is True,'source_count':len(before),'source_drift':before!=after,'control_drift':cp!=after_cp,'native':native,'engine_sha256':sha(engine),'overlay_only':True,'production_changed':False}
save(run/'RUN.json',report);print(json.dumps(report,ensure_ascii=True))
sys.exit(0 if report['passed'] else 1)
