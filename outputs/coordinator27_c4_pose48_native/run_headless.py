"""Bounded root-private headless import/functional runner. No graphical/perf mode."""
from pathlib import Path
import argparse, hashlib, json, os, re, subprocess, sys, time

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
ENGINE=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
ENGINE_SHA='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
SCHEDULER=ROOT/'tools/godot/test_scheduler.py'
SCHEDULER_SHA='6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9'

def sha(path):
    with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def pins(game):
    return {p.relative_to(game).as_posix():sha(p) for p in game.rglob('*') if p.is_file() and not any(x in ('.godot','.git','exports') for x in p.relative_to(game).parts)}

def main():
    p=argparse.ArgumentParser();p.add_argument('--assembly',required=True);p.add_argument('--run-id');p.add_argument('--kind',choices=['import','functional'],default='functional');p.add_argument('--run',action='store_true');a=p.parse_args()
    asm=Path(a.assembly).resolve();assert HERE in asm.parents
    manifest=read(asm);game=Path(manifest['game']).resolve();assert HERE in game.parents
    expected=manifest['source_pins'];assert pins(game)==expected,'Source inventory mismatch'
    assert sha(ENGINE)==ENGINE_SHA and sha(SCHEDULER)==SCHEDULER_SHA
    if not a.run:print(json.dumps({'status':'VERIFIED','pins':len(expected),'assembly_sha256':sha(asm)}));return 0
    assert a.run_id and re.fullmatch('[A-Za-z0-9_-]{1,64}',a.run_id)
    folder=asm.parent/'runs'/a.run_id;folder.mkdir(parents=True,exist_ok=False)
    timeout=90 if a.kind=='import' else 60
    command=[str(ENGINE),'--headless','--path',str(game)]
    if a.kind=='import':command+=['--editor','--import','--quit']
    else:command+=['--script','res://tests/c4_pose48/pose_test.gd','--','--palazzo-headless','--out='+str(folder/'RESULT.json')]
    sys.path.insert(0,str(SCHEDULER.parent));from test_scheduler import Lease,inventory,ERRORS
    receipt={'status':'STARTING','kind':a.kind,'assembly':str(asm),'assembly_sha256':sha(asm),'runner_sha256':sha(Path(__file__)),'engine_sha256':ENGINE_SHA,'scheduler_sha256':SCHEDULER_SHA,'source_pin_count':len(expected),'command':command,'hard_timeout_seconds':timeout,'inventory_before':inventory(),'external_processes_stopped':False,'performance_accepted':False,'gpu_used':False}
    def save(): (folder/'RUN.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    save();code=2
    try:
        with Lease('headless',game,'write' if a.kind=='import' else 'read',wait_seconds=180) as lease:
            receipt['lease']=lease.request;receipt['inventory_at_launch']=inventory()
            assert pins(game)==expected,'Source changed while queued'
            started=time.monotonic()
            with (folder/'stdout.log').open('wb') as out,(folder/'stderr.log').open('wb') as err:
                child=subprocess.Popen(command,cwd=game,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
                receipt['child']=lease.register_child(child);receipt['status']='RUNNING';save()
                while child.poll() is None:
                    if time.monotonic()-started>=timeout:raise TimeoutError('Owned child exceeded original deadline')
                    time.sleep(.1)
                receipt['exit_code']=child.returncode;receipt['elapsed_seconds']=time.monotonic()-started
            after=pins(game);changed=sorted(k for k,h in expected.items() if after.get(k)!=h);added=sorted(set(after)-set(expected))
            receipt['changed_source_files']=changed;receipt['added_source_files']=added
            receipt['stderr_bytes']=(folder/'stderr.log').stat().st_size
            logs=(folder/'stdout.log').read_text(encoding='utf-8-sig',errors='replace')+'\n'+(folder/'stderr.log').read_text(encoding='utf-8-sig',errors='replace')
            receipt['engine_errors']=[s for s in logs.splitlines() if ERRORS.search(s)]
            clean=child.returncode==0 and not changed and not receipt['engine_errors'] and receipt['stderr_bytes']==0
            if a.kind=='import':
                assert all(k.endswith(('.gd.uid','.gdshader.uid','.png.import')) for k in added),'Unexpected import additions'
                if clean:
                    imported=dict(manifest);imported.update(source_pins=after,status='IMPORTED_NATIVE_NOT_ACCEPTED',prior_assembly_sha256=sha(asm),generated_import_metadata=added,import_receipt=str(folder/'RUN.json'))
                    target=asm.parent/'ASSEMBLY_IMPORTED.json'
                    with target.open('x',encoding='utf-8') as f:f.write(json.dumps(imported,ensure_ascii=False,indent=2)+'\n')
                    receipt['imported_assembly_sha256']=sha(target)
            else:
                assert not added,'Runtime changed source inventory'
                result=read(folder/'RESULT.json') if (folder/'RESULT.json').exists() else {}
                receipt['result_sha256']=sha(folder/'RESULT.json') if result else None;receipt['result_status']=result.get('status');receipt['failures']=result.get('failures',[])
                clean=clean and bool(result) and result.get('status')=='PASS_WITH_LIMITATIONS' and not result.get('failures',[])
            receipt['status']='PASS' if clean else 'FAIL';code=0 if clean else 2
    except BaseException as error:
        receipt['status']='FAIL';receipt['error']=str(error)
    finally:
        receipt['inventory_after']=inventory();save()
    print(json.dumps({'status':receipt['status'],'run':str(folder),'error':receipt.get('error'),'failures':receipt.get('failures'),'engine_errors':receipt.get('engine_errors')},ensure_ascii=True));return code

if __name__=='__main__':raise SystemExit(main())
