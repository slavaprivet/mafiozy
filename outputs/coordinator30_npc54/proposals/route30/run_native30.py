"""Stage the pinned53a snapshot and run bounded native regressions through scheduler."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess, sys, zipfile

OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[3]
BASE=ROOT/'outputs/coordinator29_release53a/game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease, probe

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pins(game):return {p.relative_to(game).as_posix():sha(p) for p in game.rglob('*') if p.is_file() and '.godot' not in p.parts}

p=argparse.ArgumentParser()
p.add_argument('name')
p.add_argument('--cases',choices=['all','local','guard','city','regression','points','hospital'],default='all')
p.add_argument('--staged-project',type=pathlib.Path,help='Reuse this private project after checking every immutable donor pin')
a=p.parse_args()
assert a.name and all(c.isalnum() or c in '-_' for c in a.name)
run=OUT/'runs'/a.name;game=a.staged_project.resolve() if a.staged_project else run/'project'
assert game.resolve().is_relative_to((OUT/'runs').resolve()),'Only route30 private staged projects may be reused'
assert not run.exists(),'Use a new run directory'
baseline=json.loads((OUT/'BASELINE30.json').read_text(encoding='utf-8'))
integrated=json.loads((OUT/'INTEGRATION_BASE30.json').read_text(encoding='utf-8')) if (OUT/'INTEGRATION_BASE30.json').exists() else None
if integrated:assert sha(OUT/'INTEGRATION_BASE30.zip')==integrated['zip_sha256']
scheduler=ROOT/'tools/godot/test_scheduler.py'
assert sha(scheduler)==baseline['scheduler_sha256'],'Review fresh adapter after scheduler change'
admission=probe('headless',game,'write')
if not admission['eligible_snapshot']:
    print(json.dumps({'status':'NOT_STARTED','probe':admission},ensure_ascii=True));sys.exit(3)
run.mkdir(parents=True)
(run/'PROBE.json').write_text(json.dumps(admission,indent=2),encoding='utf-8')
# Frozen donor is immutable and verified; only staged target needs a write lease.
with Lease('headless',game,'write',5) as write:
    manifest=json.loads((BASE.parent/'ASSEMBLY.json').read_text(encoding='utf-8'))
    for rel,expected in manifest['source_pins'].items():assert sha(BASE/rel)==expected,rel
    if not game.exists():shutil.copytree(BASE,game,ignore=shutil.ignore_patterns('.godot'))
    else:
        assert a.staged_project is not None
        for rel,expected in manifest['source_pins'].items():
            if rel not in baseline['files'] and (not integrated or rel not in integrated['changed_sources']):assert sha(game/rel)==expected,rel
    if integrated:
        with zipfile.ZipFile(OUT/'INTEGRATION_BASE30.zip') as archive:
            for rel,expected in integrated['changed_sources'].items():
                data=archive.read(rel);assert hashlib.sha256(data).hexdigest()==expected
                target=(game/rel).resolve();assert target.is_relative_to(game.resolve())
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        for rel in baseline['files']:
            if rel not in integrated['changed_sources']:shutil.copy2(BASE/rel,game/rel)
        applied=subprocess.run([sys.executable,'-B',str(OUT/'apply30.py'),'--project',str(game),'--apply'],capture_output=True)
        (run/'APPLY.json').write_bytes(applied.stdout);assert applied.returncode==0,applied.stderr.decode(errors='replace')
    else:
        for rel,entry in baseline['files'].items():
            if a.staged_project is None:assert sha(game/rel)==entry['base_sha256'],rel
            shutil.copy2(OUT/rel,game/rel)
    (game/'qa_route30').mkdir(exist_ok=True)
    for source in (OUT/'qa').glob('*.gd'):shutil.copy2(source,game/'qa_route30'/source.name)
    for name in ['integration_fixture29.gd','daily_policy_fixture29.gd']:
        shutil.copy2(ROOT/'outputs/coordinator29_npc53/proposals/navigation29_integration/qa'/name,game/'qa_route30'/name)
    (run/'STAGE_LEASE.json').write_text(json.dumps({'immutable_donor':str(BASE),'write':write.request},indent=2),encoding='utf-8')
before=pins(game);(run/'SOURCE_BEFORE_IMPORT.json').write_text(json.dumps(before,indent=2),encoding='utf-8')
engine=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
results=[]
def native(name,args,timeout,access='read'):
    cmd=[sys.executable,'-B',str(scheduler),'run','--mode','headless','--project',str(game),'--access',access,'--wait-seconds','30','--timeout',str(timeout),'--out',str(run/name),'--',str(engine),'--headless','--path',str(game),*args]
    done=subprocess.run(cmd,cwd=ROOT,capture_output=True)
    (run/(name+'.runner.stdout.log')).write_bytes(done.stdout);(run/(name+'.runner.stderr.log')).write_bytes(done.stderr)
    return done.returncode

import_exit=native('import',['--editor','--import','--quit'],240,'write')
ready=pins(game);(run/'SOURCE.json').write_text(json.dumps(ready,indent=2),encoding='utf-8')
import_changes=[k for k in before.keys()|ready.keys() if before.get(k)!=ready.get(k)]
if import_exit==0:
    cases=[]
    if a.cases in ('all','local','guard'):cases.append(('service_guard30',70,[]))
    if a.cases in ('all','local','regression'):cases += [('integration_fixture29',120,[]),('daily_policy_fixture29',120,[])]
    if a.cases in ('all','city'):
        flags=json.loads((BASE.parent/'ASSEMBLY.json').read_text(encoding='utf-8'))['launch_arguments']
        cases.append(('actual_city_route30',280,flags))
    if a.cases in ('all','hospital'):
        flags=json.loads((BASE.parent/'ASSEMBLY.json').read_text(encoding='utf-8'))['launch_arguments']
        flags=[flag for flag in flags if not flag.startswith('--city-hp=')]+['--city-hp=20','--city-venue-staff29=1']
        cases.append(('real_hospital30',300,flags))
    if a.cases=='points':
        flags=json.loads((BASE.parent/'ASSEMBLY.json').read_text(encoding='utf-8'))['launch_arguments']
        cases.append(('guide_points30',150,flags))
    for name,timeout,flags in cases:
        result=run/(name+'.json')
        code=native(name,['--script',str(game/'qa_route30'/(name+'.gd')),'--','--qa-out='+str(result),*flags],timeout)
        data=json.loads(result.read_text(encoding='utf-8')) if result.exists() else {}
        results.append({'case':name,'exit':code,'passed':code==0 and data.get('passed') is True})
        if not results[-1]['passed']:break
after=pins(game);drift=[k for k in ready.keys()|after.keys() if ready.get(k)!=after.get(k)]
donor=json.loads((BASE.parent/'ASSEMBLY.json').read_text(encoding='utf-8'))['source_pins']
changed={k:v for k,v in ready.items() if donor.get(k)!=v}
with zipfile.ZipFile(run/'CHANGED_SOURCES.zip','w',compression=zipfile.ZIP_DEFLATED) as archive:
    for rel,expected in changed.items():
        data=(game/rel).read_bytes();assert hashlib.sha256(data).hexdigest()==expected
        archive.writestr(rel,data)
(run/'RECONSTRUCTION.json').write_text(json.dumps({'frozen_donor':str(BASE),'frozen_assembly_sha256':sha(BASE.parent/'ASSEMBLY.json'),'changed_sources':changed,'archive_sha256':sha(run/'CHANGED_SOURCES.zip'),'staged_project':str(game),'reconstruct':'Copy pinned frozen donor without .godot, overlay CHANGED_SOURCES.zip; verify SOURCE.json. Imported cache is disposable.'},indent=2)+'\n',encoding='utf-8')
summary={'import_exit':import_exit,'import_generated_changes':import_changes,'cases':results,'source_drift':drift,'passed':import_exit==0 and bool(results) and all(x['passed'] for x in results) and not drift,'performance_accepted':False,'production_modified':False,'user_processes_closed':False}
(run/'RESULT.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8');print(json.dumps(summary));sys.exit(0 if summary['passed'] else 1)
