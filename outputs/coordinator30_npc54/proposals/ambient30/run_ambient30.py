import argparse,hashlib,json,os,pathlib,shutil,subprocess,sys,time
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[3]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease,ERRORS
RUN=None
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,value):p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def pins(game):return {p.relative_to(game).as_posix():sha(p) for p in game.rglob('*') if p.is_file() and '.godot' not in p.parts and not p.name.endswith('.uid')}
def main():
    global RUN
    p=argparse.ArgumentParser();p.add_argument('name');p.add_argument('--source',type=pathlib.Path,default=ROOT/'outputs/coordinator30_npc54/game');p.add_argument('--reuse-project',type=pathlib.Path);p.add_argument('--baseline',action='store_true');p.add_argument('--mode',choices=['headless','graphical'],default='headless');p.add_argument('--kinds',default='');p.add_argument('--cancel-phase',default='');p.add_argument('--cancel-kind',default='bench');p.add_argument('--slots',action='store_true');p.add_argument('--stale-life',action='store_true');a=p.parse_args()
    assert a.name and all(c.isalnum() or c in '-_' for c in a.name)
    run=OUT/'runs'/a.name;assert not run.exists();run.mkdir(parents=True);RUN=run;game=run/'project';source=a.source.resolve()
    scheduler=ROOT/'tools/godot/test_scheduler.py';assert sha(scheduler)=='adcb834390e476edd118f62d8e3e5b391c6ebc97925391e66beeb80430ba8373'
    engine=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe';lock=json.loads((ROOT/'docs/godot/ENGINE_LOCK.json').read_text(encoding='utf-8'));assert sha(engine)==lock['editor']['gui']['sha256']
    if a.reuse_project:
        game=a.reuse_project.resolve();assert game.is_relative_to(OUT/'runs') and game.name=='project' and game.is_dir()
        contents={}
    else:
        with Lease(mode='headless',project=source,access='read',wait_seconds=180) as reader:
            original=pins(source)
            contents={relative:(source/relative).read_bytes() for relative in original}
            assert pins(source)==original
            assert all(hashlib.sha256(raw).hexdigest()==original[relative] for relative,raw in contents.items())
            save(run/'SOURCE_PINS.json',original);save(run/'SOURCE_READ_LEASE.json',reader.request)
    # Sequential leases avoid consuming both functional lanes with nested
    # source/destination leases when independent agents stage concurrently.
    with Lease(mode='headless',project=game,access='write',wait_seconds=180) as writer:
        if a.reuse_project:
            save(run/'REUSED_PROJECT.json',{'path':str(game),'before_pins':pins(game)})
            for directory in ['scripts/npc_ambient','qa']:
                for src in (game/directory).rglob('*'):
                    if src.is_file():
                        dst=run/'PREVIOUS_SOURCES'/src.relative_to(game);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
        for relative,raw in contents.items():
            dst=game/relative;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(raw)
        if not a.reuse_project:assert pins(game)==original
        contents.clear()
        overrides=[]
        for directory in (['qa'] if a.baseline else ['scripts','qa']):
            for src in (OUT/directory).rglob('*'):
                if not src.is_file():continue
                relative=src.relative_to(OUT);dst=game/relative;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst);overrides.append(relative.as_posix())
                snapshot=run/'TESTED_SOURCES'/relative;snapshot.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,snapshot)
        save(run/'OVERRIDES.json',overrides);save(run/'STAGE_WRITE_LEASE.json',writer.request)
    before=pins(game);save(run/'PROJECT_PINS.json',before)
    def native(label,extra,mode,access,timeout):
        if label=='native':
            directory=run/label;directory.mkdir();marker=directory/'REGISTERED.json'
            cmd=[str(engine)]+(['--headless'] if mode=='headless' else [])+['--path',str(game),*extra,'--qa-ready='+str(marker)]
            record={'command':cmd,'mode':mode,'passed':False,'performance_accepted':False};started=time.monotonic()
            try:
                with Lease(mode=mode,project=game,access=access,wait_seconds=180) as lease:
                    record['lease']=lease.request
                    with (directory/'stdout.log').open('wb') as stdout,(directory/'stderr.log').open('wb') as stderr:
                        process=subprocess.Popen(cmd,cwd=game,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW);started=time.monotonic()
                        record['child']=lease.register_child(process)
                        save(marker,{'registered':True,'pid':process.pid})
                        process.wait(timeout=max(1,timeout-(time.monotonic()-started)))
                    record['exit_code']=process.returncode;record['elapsed_seconds']=time.monotonic()-started
                    logs=[(directory/name).read_text(encoding='utf-8-sig',errors='replace') for name in ['stdout.log','stderr.log']]
                    record['errors']=[line for log in logs for line in log.splitlines() if ERRORS.search(line)]
                    record['stderr_bytes']=(directory/'stderr.log').stat().st_size
                    record['passed']=process.returncode==0 and not record['errors'] and record['stderr_bytes']==0
            except Exception as error:record['error']=str(error)
            save(directory/'SCHEDULER_RUN.json',record)
            return 0 if record['passed'] else 2
        cmd=[sys.executable,'-B',str(scheduler),'run','--mode',mode,'--project',str(game),'--access',access,'--wait-seconds','180','--timeout',str(timeout),'--out',str(run/label),'--',str(engine)]
        if mode=='headless':cmd+=['--headless']
        cmd+=['--path',str(game),*extra]
        result=subprocess.run(cmd,cwd=ROOT,capture_output=True);(run/(label+'.runner.stdout.log')).write_bytes(result.stdout);(run/(label+'.runner.stderr.log')).write_bytes(result.stderr);return result.returncode
    imported=native('import',['--editor','--import','--quit'],'headless','write',180);ready=pins(game);save(run/'PROJECT_READY_PINS.json',ready)
    import_drift=[k for k in before.keys()|ready.keys() if before.get(k)!=ready.get(k) and not k.endswith('.import')]
    output=run/'observed';output.mkdir();flags=['--qa-out='+str(output)]
    if a.kinds:flags+=['--qa-kinds='+a.kinds]
    if a.cancel_phase:flags+=['--qa-cancel-phase='+a.cancel_phase,'--qa-kind='+a.cancel_kind]
    if a.stale_life:flags+=['--qa-stale-life']
    entry='entry_slots29.gd' if a.slots else 'entry_fixture30.gd';ex=None;semantic={}
    if imported==0:
        ex=native('native',['--resolution','1200x900','--script',str(game/'qa'/entry),'--',*flags],a.mode,'read',360)
        result_path=output/('BENCH_SLOTS29.json' if a.slots else 'AMBIENT_FIXTURE29.json')
        if result_path.exists():semantic=json.loads(result_path.read_text(encoding='utf-8'))
    after=pins(game);drift=sorted(set(import_drift)|{k for k in ready.keys()|after.keys() if ready.get(k)!=after.get(k)})
    result={'passed':imported==0 and ex==0 and not drift,'baseline':a.baseline,'mode':a.mode,'import_exit':imported,'native_exit':ex,'source_drift':drift,'reason':semantic.get('reason'),'failures':semantic.get('failures'),'max_foot_error30':semantic.get('max_foot_error30'),'max_body_step30':semantic.get('max_body_step30'),'visual_verified':False,'performance_accepted':False,'user_processes_closed':False}
    save(run/'RESULT.json',result);print(json.dumps(result));return 0 if result['passed'] else 1
if __name__=='__main__':
    try:sys.exit(main())
    except Exception as error:
        if RUN is not None:save(RUN/'RESULT.json',{'passed':False,'exception':type(error).__name__,'reason':str(error),'user_processes_closed':False})
        raise
