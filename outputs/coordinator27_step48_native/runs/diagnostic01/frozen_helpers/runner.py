"""Isolated exact step33 on accepted48; no production mutations or GPU launches."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, sys, time
HOME = Path(__file__).resolve().parent
ROOT = HOME.parents[1]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease
SHA = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
LOAD = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p, data): p.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8')
BASE = ROOT/'outputs/coordinator27_release48/ACCEPTED_ASSEMBLY.json'
BASE_SHA = '51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7'
PATCH = ROOT/'outputs/coordinator27_step33/patch/scripts/preview_player.gd'
PATCH_SHA = 'b33505b2bbadcadb5754e474f1a9cbb7b218f0abcbfa7ea7b70db8facff19d6c'
ENGINE = Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
ENGINE_SHA = 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
GAME = HOME/'game'
def verify(folder, pins):
    errors = [name for name, digest in pins.items() if not (folder/name).is_file() or SHA(folder/name)!=digest]
    assert not errors, errors
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('mode',choices=['stage','import','boundary','corpse','diagnostic']); ap.add_argument('--label',default='run01'); a=ap.parse_args()
    assert SHA(BASE)==BASE_SHA and SHA(PATCH)==PATCH_SHA and SHA(ENGINE)==ENGINE_SHA
    base=LOAD(BASE); source=Path(base['game']); pins=base['source_pins']; assert len(pins)==486
    assert pins['scripts/preview_player.gd']=='64707b7c6d72d863651c3ce2d277af3ed2b14facbca6bb8801f41c95a2904e70'
    verify(source,pins)
    candidate=dict(pins); candidate['scripts/preview_player.gd']=PATCH_SHA
    if a.mode=='stage':
        assert not GAME.exists(), 'Fresh isolated stage required'
        with Lease(mode='headless', project=GAME, access='write', wait_seconds=120) as lease:
            verify(source,pins)
            GAME.mkdir(parents=True)
            for name in pins:
                dst=GAME/name; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(PATCH if name=='scripts/preview_player.gd' else source/name,dst)
            verify(GAME,candidate); verify(source,pins)
            save(HOME/'ASSEMBLY.json',{'accepted':False,'performance_accepted':False,'base':str(BASE),'base_sha256':BASE_SHA,'game':str(GAME),'source_count':486,'source_pins':candidate,'sole_runtime_patch':'scripts/preview_player.gd','stage_lease':lease.request})
        print('STAGED exact 486 source pins; sole player patch'); return
    out=HOME/'runs'/a.label
    assert out.parent==HOME/'runs' and not out.exists()
    out.mkdir(parents=True)
    frozen={str(p.relative_to(HOME)):SHA(p) for p in HOME.glob('*.gd')}
    frozen['runner.py']=SHA(__file__)
    frozen['ASSEMBLY.json']=SHA(HOME/'ASSEMBLY.json')
    scheduler=ROOT/'tools/godot/test_scheduler.py'; scheduler_sha=SHA(scheduler)
    frozen_dir=out/'frozen_helpers'; frozen_dir.mkdir()
    for name in frozen:
        dst=frozen_dir/name; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(HOME/name,dst)
    record={'mode':a.mode,'base_sha256':BASE_SHA,'engine':str(ENGINE),'engine_sha256':ENGINE_SHA,'source_pins':candidate,'helper_pins':frozen,'scheduler_sha256':scheduler_sha,'performance_accepted':False,'passed':False}
    start=time.monotonic()
    try:
        with Lease(mode='headless',project=GAME,access='write' if a.mode=='import' else 'read',wait_seconds=120) as lease:
            verify(GAME,candidate); verify(source,pins)
            for name,digest in frozen.items(): assert SHA(HOME/name)==digest
            command=[str(ENGINE),'--headless','--path',str(GAME)]
            if a.mode=='import': command+=['--editor','--import','--quit']
            else: command+=['--script',str(HOME/('boundary.gd' if a.mode=='boundary' else ('diagnostic.gd' if a.mode=='diagnostic' else 'test_corpse_receipt.gd'))),'--','--out='+str(out)]
            record.update(command=command,lease=lease.request)
            with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
                child=subprocess.Popen(command,cwd=GAME,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
                record['child_identity']=lease.register_child(child)
                record['exit_code']=child.wait(timeout=115 if a.mode=='boundary' else 100)
            verify(GAME,candidate); verify(source,pins)
            for name,digest in frozen.items(): assert SHA(HOME/name)==digest
            assert SHA(ENGINE)==ENGINE_SHA and SHA(scheduler)==scheduler_sha
            record['source_pins_before_after']=True
            record['stderr_bytes']=(out/'stderr.log').stat().st_size
            log=(out/'stdout.log').read_text(encoding='utf-8',errors='replace')
            assert record['exit_code']==0, 'Native child exit '+str(record['exit_code'])
            assert not record['stderr_bytes'] and 'SCRIPT ERROR' not in log and 'ERROR:' not in log
            if a.mode!='import':
                result=LOAD(out/'RESULT.json'); assert result.get('passed',result.get('valid',False)), result.get('errors')
            record['passed']=True
    except Exception as ex:
        record['error']=str(ex)
    finally:
        record['elapsed_seconds']=time.monotonic()-start
        save(out/'RUN.json',record)
    print(json.dumps({k:v for k,v in record.items() if k in ['mode','passed','error','elapsed_seconds','source_pins_before_after','stderr_bytes','exit_code']}))
    sys.exit(0 if record['passed'] else 1)
if __name__=='__main__': main()
