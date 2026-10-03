"""Private actual48 save->exit->fresh restore, scheduler0194, no real saves."""
from pathlib import Path
import argparse, hashlib, json, os, secrets, shutil, subprocess, sys, time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
SHA=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
LOAD=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,data):p.write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding='utf-8')
BASE=ROOT/'outputs/coordinator27_release48/ACCEPTED_ASSEMBLY.json'
BASE_SHA='51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7'
ENGINE=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
ENGINE_SHA='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
SCHEDULER=ROOT/'tools/godot/test_scheduler.py'
SCHEDULER_SHA='0194f00db580f2c54e8f2c13cbbde1002cd2429ffdf970d9799328d072cfcdc4'
GAME=HERE/'game'
def verify(folder,pins):
    bad=[n for n,d in pins.items() if not (folder/n).is_file() or SHA(folder/n)!=d]
    assert not bad,bad
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('mode',choices=['stage','sync','import','run'])
    ap.add_argument('--label',default='run01')
    a=ap.parse_args()
    assert SHA(BASE)==BASE_SHA and SHA(ENGINE)==ENGINE_SHA and SHA(SCHEDULER)==SCHEDULER_SHA
    base=LOAD(BASE);source=Path(base['game']);pins=base['source_pins']
    assert len(pins)==486
    verify(source,pins)
    patches={str(p.relative_to(HERE/'patches')).replace('\\','/'):SHA(p) for p in (HERE/'patches').rglob('*') if p.is_file()}
    candidate={**pins,**patches}
    if a.mode in ['stage','sync']:
        assert not GAME.exists() if a.mode=='stage' else GAME.is_dir()
        with Lease(mode='headless',project=GAME,access='write',wait_seconds=120) as lease:
            GAME.mkdir(parents=True,exist_ok=True)
            for name in pins:
                dst=GAME/name;dst.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(HERE/'patches'/name if name in patches else source/name,dst)
            verify(GAME,candidate);verify(source,pins)
            save(HERE/'ASSEMBLY.json',{'accepted':False,'base_sha256':BASE_SHA,'source_pins':pins,'candidate_pins':candidate,'patches':patches,'game':str(GAME),'lease':lease.request})
        print('STAGE PASS: 481 unchanged + 5 explicit private owner/startup patches');return
    out=HERE/'runs'/a.label
    assert out.parent==HERE/'runs' and not out.exists()
    out.mkdir(parents=True)
    helper_names=[p for p in HERE.glob('*') if p.suffix in ['.gd','.py','.json','.md']]
    helpers={p.name:SHA(p) for p in helper_names}
    frozen=out/'frozen_helpers';frozen.mkdir()
    for p in helper_names:shutil.copyfile(p,frozen/p.name)
    shutil.copytree(HERE/'patches',frozen/'patches')
    def verify_all():
        verify(source,pins);verify(GAME,candidate);verify(HERE,helpers)
        assert SHA(ENGINE)==ENGINE_SHA and SHA(SCHEDULER)==SCHEDULER_SHA
    record={'passed':False,'base_sha256':BASE_SHA,'engine_sha256':ENGINE_SHA,'scheduler_sha256':SCHEDULER_SHA,'helper_pins':helpers,'candidate_pins':candidate,'children':[],'performance_accepted':False}
    began=time.monotonic()
    try:
        def child(phase,extra=None):
            target=out/phase;target.mkdir()
            with Lease(mode='headless',project=GAME,access='write' if phase=='import' else 'read',wait_seconds=120) as lease:
                verify_all()
                cmd=[str(ENGINE),'--headless','--path',str(GAME)]
                if phase=='import':cmd+=['--editor','--import','--quit']
                else:cmd+=['--script',str(HERE/'test_restore.gd'),'--','--phase='+phase,'--out='+str(target)]+(extra or [])
                row={'phase':phase,'command':cmd,'lease':lease.request};record['children'].append(row)
                with (target/'stdout.log').open('wb') as stdout,(target/'stderr.log').open('wb') as stderr:
                    proc=subprocess.Popen(cmd,cwd=GAME,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
                    row['identity']=lease.register_child(proc)
                    row['exit_code']=proc.wait(timeout=85)
                verify_all()
                log=(target/'stdout.log').read_text(encoding='utf-8',errors='replace')
                row['stderr_bytes']=(target/'stderr.log').stat().st_size
                assert row['exit_code']==0 and not row['stderr_bytes'] and 'SCRIPT ERROR' not in log and 'ERROR:' not in log,row
                if phase!='import':
                    data=LOAD(target/'RESULT.json');row['result']=data
                    assert data['passed'],data
                return target
        if a.mode=='import':child('import')
        else:
            saved=child('save')
            source_file=saved/'save.json'
            digest=SHA(source_file)
            assert LOAD(saved/'RESULT.json')['save_sha256']==digest
            grant=secrets.token_hex(32)
            ledger={'save_sha256':digest,'grant':grant,'consumed':False,'source_process':record['children'][0]['identity']}
            save(out/'PARENT_GRANT.json',ledger)
            def consume():
                assert not ledger['consumed'],'REPLAY_PARENT'
                assert SHA(source_file)==digest
                ledger['consumed']=True;save(out/'PARENT_GRANT.json',ledger)
                return ['--save='+str(source_file),'--trusted-digest='+digest,'--grant='+grant]
            child('restore',consume())
            try:consume()
            except AssertionError as error:record['parent_replay_rejected']=str(error)=='REPLAY_PARENT'
            assert record.get('parent_replay_rejected')
            assert record['children'][0]['result']['process_id']!=record['children'][1]['result']['process_id']
            record['save_sha256']=digest
        record.update(passed=True,source_pins_before_after=True)
    except Exception as exc:record['error']=str(exc)
    finally:
        record['elapsed_seconds']=time.monotonic()-began
        save(out/'RUN.json',record)
    print(json.dumps({k:v for k,v in record.items() if k not in ['candidate_pins','helper_pins','children']}))
    sys.exit(0 if record['passed'] else 1)
if __name__=='__main__':main()
