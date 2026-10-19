from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys,time
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease,ERRORS
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pins(root):return {p.relative_to(root).as_posix():sha(p) for p in root.rglob('*') if p.is_file() and '.godot' not in p.parts and not p.name.endswith('.uid')}
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    p=argparse.ArgumentParser();p.add_argument('name');p.add_argument('--mode',choices=['headless','graphical'],default='headless');p.add_argument('--baseline',action='store_true');p.add_argument('--contracts',action='store_true');a=p.parse_args()
    run=OUT/'runs'/a.name;assert not run.exists();run.mkdir(parents=True)
    source=ROOT/'outputs/coordinator30_npc54/game';game=OUT.parent/'ambient30/runs/oracle01/project';assert game.exists()
    scheduler=ROOT/'tools/godot/test_scheduler.py';assert sha(scheduler)=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
    engine=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe';assert sha(engine)==json.loads((ROOT/'docs/godot/ENGINE_LOCK.json').read_text(encoding='utf-8'))['editor']['gui']['sha256']
    with Lease(mode='headless',project=source,access='read',wait_seconds=180) as reader:
        source_pins=pins(source);old=pins(game);changed={k:(source/k).read_bytes() for k,v in source_pins.items() if old.get(k)!=v}
        assert pins(source)==source_pins;save(run/'SOURCE_PINS.json',source_pins);save(run/'SOURCE_READ_LEASE.json',reader.request)
    with Lease(mode='headless',project=game,access='write',wait_seconds=180) as writer:
        for rel,raw in changed.items():
            dst=game/rel;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(raw)
        assert all(sha(game/k)==v for k,v in source_pins.items())
        for directory in (['qa'] if a.baseline else ['qa','scripts']):
            for src in (OUT/directory).rglob('*'):
                if not src.is_file():continue
                rel=src.relative_to(OUT);dst=game/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
                snap=run/'TESTED_SOURCES'/rel;snap.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,snap)
        save(run/'STAGE.json',{'lease':writer.request,'source_files_changed':list(changed),'changed_bytes':sum(len(raw) for raw in changed.values()),'reused_project':str(game)})
    before=pins(game);save(run/'PROJECT_PINS.json',before)
    cmd=[sys.executable,'-B',str(scheduler),'run','--mode','headless','--project',str(game),'--access','write','--wait-seconds','180','--timeout','180','--out',str(run/'import'),'--',str(engine),'--headless','--path',str(game),'--editor','--import','--quit']
    imported=subprocess.run(cmd,capture_output=True);(run/'import.runner.log').write_bytes(imported.stdout+imported.stderr)
    ready=pins(game);save(run/'PROJECT_READY_PINS.json',ready)
    flags=json.loads((ROOT/'outputs/coordinator30_npc54/staff_visual01/engine/SCHEDULER_RUN.json').read_text(encoding='utf-8'))['command'];flags=flags[flags.index('--')+1:];flags=[x for x in flags if not x.startswith('--qa-')]
    observed=run/'observed';observed.mkdir();native=run/'native';native.mkdir();marker=native/'REGISTERED.json'
    flags+=['--qa-out='+str(observed/'STAFF_CONTRACTS30.json' if a.contracts else observed),'--qa-ready='+str(marker)]
    entry='staff_world29_fixture.gd' if a.contracts else 'medic_visual30.gd'
    cmd=[str(engine)]+(['--headless'] if a.mode=='headless' else [])+['--path',str(game),'--resolution','1400x1000','--script',str(game/'qa'/entry),'--',*flags]
    record={'passed':False,'command':cmd,'mode':a.mode,'performance_accepted':False}
    if imported.returncode==0:
        try:
            with Lease(mode=a.mode,project=game,access='read',wait_seconds=180) as lease:
                record['lease']=lease.request
                with (native/'stdout.log').open('wb') as out,(native/'stderr.log').open('wb') as err:
                    process=subprocess.Popen(cmd,cwd=game,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW);started=time.monotonic();record['child']=lease.register_child(process);save(marker,{'registered':True});process.wait(timeout=max(1,150-(time.monotonic()-started)))
                record['exit_code']=process.returncode;record['elapsed_s']=time.monotonic()-started
                logs=[(native/n).read_text(encoding='utf-8-sig',errors='replace') for n in ['stdout.log','stderr.log']];record['errors']=[line for log in logs for line in log.splitlines() if ERRORS.search(line)];record['stderr_bytes']=(native/'stderr.log').stat().st_size
                record['passed']=process.returncode==0 and not record['errors'] and record['stderr_bytes']==0
        except Exception as error:record['error']=str(error)
    save(native/'SCHEDULER_RUN.json',record)
    after=pins(game);drift=[k for k in ready.keys()|after.keys() if ready.get(k)!=after.get(k)];drift += [k for k in before.keys()|ready.keys() if before.get(k)!=ready.get(k) and not k.endswith('.import')]
    result={'passed':imported.returncode==0 and record['passed'] and not drift,'baseline':a.baseline,'mode':a.mode,'drift':drift,'import_exit':imported.returncode,'native_exit':record.get('exit_code'),'native_error':record.get('error'),'visual_review_pending':True,'shared_game_modified':False,'performance_accepted':False};save(run/'RESULT.json',result);print(json.dumps(result));return 0 if result['passed'] else 1
if __name__=='__main__':sys.exit(main())
