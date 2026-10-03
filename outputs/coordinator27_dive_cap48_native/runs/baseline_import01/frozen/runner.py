"""Pinned current48 native-input QA; only this isolated directory is writable."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, sys, time
AREA = Path(__file__).resolve().parent
ROOT = AREA.parents[1]
sys.path.insert(0, str(ROOT))
from tools.godot import test_scheduler as schedule
BASE = ROOT / 'outputs/coordinator27_release48/ACCEPTED_ASSEMBLY.json'
BASE_SHA = '51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7'
PATCH = ROOT / 'outputs/astra_dispatch_20261003/a3/preview_dive_patched_r12.gd'
PATCH_SHA = '93a4e9fad1f5d91a57d3463ee51b7f1066a3e6dccc3acc1bfc3c61a5d11e2858'
SCHEDULER_SHA = '6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9'
ENGINE = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
ENGINE_SHA = 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
load = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p, value):
    Path(p).write_text(json.dumps(value, ensure_ascii=True, indent=2)+'\n', encoding='utf-8')
def verify(folder, pins):
    bad = [p for p,h in pins.items() if not (folder/p).is_file() or sha(folder/p)!=h]
    assert not bad, bad
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('mode',choices=['stage','import','run']); ap.add_argument('variant',choices=['baseline','candidate']); ap.add_argument('--label',default='run01'); args=ap.parse_args()
    assert sha(BASE)==BASE_SHA and sha(PATCH)==PATCH_SHA and sha(ENGINE)==ENGINE_SHA
    assert sha(ROOT/'tools/godot/test_scheduler.py')==SCHEDULER_SHA
    base=load(BASE); source=Path(base['game']); pins=dict(base['source_pins']); assert len(pins)==486
    verify(source,pins)
    rel='scripts/preview_dive.gd'; old=(source/rel).read_bytes(); replacement=PATCH.read_bytes()
    anchor=b'minf(elapsed, CINEMATIC_FLIGHT) - minf(previous, CINEMATIC_FLIGHT)'
    assert old.count(anchor)==1 and old.replace(anchor,anchor.replace(b'CINEMATIC_FLIGHT',b'FLIGHT'),1)==replacement
    if args.variant=='candidate': pins[rel]=PATCH_SHA
    game=AREA/args.variant/'game'; manifest=AREA/args.variant/'ASSEMBLY.json'
    if args.mode=='stage':
        assert not game.exists(), 'Fresh stage required'
        with schedule.Lease(mode='headless',project=game,access='write',wait_seconds=120) as lease:
            verify(source,base['source_pins']); game.mkdir(parents=True)
            for p in pins:
                target=game/p; target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(PATCH if args.variant=='candidate' and p==rel else source/p,target)
            verify(game,pins); verify(source,base['source_pins'])
            save(manifest,dict(schema='dive-cap48.isolated-source/v1',variant=args.variant,game=str(game),base_sha256=BASE_SHA,source_count=486,source_pins=pins,accepted=False,performance_accepted=False,stage_lease=lease.request))
        print('STAGED',args.variant,sha(manifest)); return
    assert load(manifest)['source_pins']==pins
    out=AREA/'runs'/args.label; assert out.parent==AREA/'runs' and not out.exists(); out.mkdir(parents=True)
    fixture=AREA/'qa/test_dive_cap48.gd'
    frozen={'runner.py':sha(__file__),'qa/test_dive_cap48.gd':sha(fixture),args.variant+'/ASSEMBLY.json':sha(manifest)}
    for p in frozen:
        target=out/'frozen'/p; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(AREA/p,target)
    record=dict(schema='dive-cap48.native-run/v1',variant=args.variant,mode=args.mode,passed=False,performance_accepted=False,engine_sha256=ENGINE_SHA,scheduler_sha256=SCHEDULER_SHA,base_sha256=BASE_SHA,fixture_pins=frozen,source_pins=pins)
    started=time.monotonic()
    try:
        record['inventory_before']=schedule.inventory()
        with schedule.Lease(mode='headless',project=game,access='write' if args.mode=='import' else 'read',wait_seconds=120) as lease:
            verify(game,pins); verify(source,base['source_pins'])
            assert all(sha(AREA/p)==h for p,h in frozen.items())
            command=[str(ENGINE),'--headless','--path',str(game)]
            command += ['--editor','--import','--quit'] if args.mode=='import' else ['--script',str(fixture),'--','--out='+str(out),'--variant='+args.variant]
            record.update(command=command,lease=lease.request)
            with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
                child_started=time.monotonic()
                child=subprocess.Popen(command,cwd=game,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
                record['child_identity']=lease.register_child(child)
                record['exit_code']=child.wait(timeout=max(1,100-(time.monotonic()-child_started)))
            record['child_wall_seconds']=time.monotonic()-child_started
            verify(game,pins); verify(source,base['source_pins'])
            assert all(sha(AREA/p)==h for p,h in frozen.items())
            assert sha(ENGINE)==ENGINE_SHA and sha(ROOT/'tools/godot/test_scheduler.py')==SCHEDULER_SHA
            record['source_pins_before_after']=True
            record['stderr_bytes']=(out/'stderr.log').stat().st_size
            log=(out/'stdout.log').read_text(encoding='utf-8',errors='replace')
            assert record['exit_code']==0, f"Native exit {record['exit_code']}"
            assert record['stderr_bytes']==0 and not schedule.ERRORS.search(log), 'Native log errors'
            if args.mode=='run':
                result=load(out/'RESULT.json'); assert result['passed'], result.get('errors')
            record['passed']=True
    except Exception as e: record['error']=str(e)
    finally:
        record['elapsed_seconds']=time.monotonic()-started; save(out/'RUN.json',record)
    print(json.dumps({k:v for k,v in record.items() if k in ('mode','variant','passed','error','exit_code','stderr_bytes','child_wall_seconds','source_pins_before_after')}))
    sys.exit(0 if record['passed'] else 1)
if __name__=='__main__': main()
