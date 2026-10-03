"""Actual accepted48 Palazzo passage with exact step and short-dive candidates."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
load = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p, v): Path(p).write_bytes((json.dumps(v, ensure_ascii=True, indent=2)+'\n').encode())
BASE = ROOT/'outputs/coordinator27_release48/ACCEPTED_ASSEMBLY.json'
OWNER = ROOT/'outputs/buildings4_strength_foundation_native_20261003/ASSEMBLY.json'
GAME = HERE/'game'
ENGINE = Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
SCHEDULER = ROOT/'tools/godot/test_scheduler.py'
SCHEDULER_SHA = '0194f00db580f2c54e8f2c13cbbde1002cd2429ffdf970d9799328d072cfcdc4'
PATCHES = {
 'scripts/preview_player.gd': (ROOT/'outputs/coordinator27_step33/patch/scripts/preview_player.gd', 'b33505b2bbadcadb5754e474f1a9cbb7b218f0abcbfa7ea7b70db8facff19d6c'),
 'scripts/preview_dive.gd': (ROOT/'outputs/coordinator27_dive_cap48_patch/preview_dive.gd', '93a4e9fad1f5d91a57d3463ee51b7f1066a3e6dccc3acc1bfc3c61a5d11e2858'),
}
def verify(folder, pins):
    bad=[p for p,h in pins.items() if not (folder/p).is_file() or sha(folder/p)!=h]
    assert not bad, bad
def main():
    ap=argparse.ArgumentParser();ap.add_argument('mode',choices=['stage','import','run']);ap.add_argument('--label',default='native01');args=ap.parse_args()
    assert re.fullmatch(r'[a-zA-Z0-9_-]+',args.label)
    assert sha(BASE)=='51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7'
    assert sha(OWNER)=='9b97fc2a8a364e897020fe56b374b8275d41872bfd0b790abf45f0a97c16cfa1'
    assert sha(SCHEDULER)==SCHEDULER_SHA
    assert sha(ENGINE)=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
    base=load(BASE);owner=load(OWNER);source=Path(base['game']);verify(source,base['source_pins'])
    if args.mode=='stage':
        assert not GAME.exists()
        with Lease('headless',GAME,'write',120) as lease:
            pins=dict(base['source_pins']);qa_pins={p:h for p,h in owner['source_pins'].items() if p.startswith('tests/')}
            for name,h in base['source_pins'].items():
                origin=PATCHES[name][0] if name in PATCHES else source/name
                if name in PATCHES: assert sha(origin)==PATCHES[name][1]
                dst=GAME/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(origin,dst);pins[name]=sha(dst)
            for name,h in qa_pins.items():
                origin=Path(owner['game'])/name;assert sha(origin)==h
                dst=GAME/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(origin,dst);pins[name]=h
            # Same fixture, rebased source identity assertions only; no gameplay oracle changes.
            parent='tests/c4_strength1920/test_c4_passage_20261003.gd'
            p=GAME/parent;s=p.read_text(encoding='utf-8-sig');old='f0a39ff7e7c300164d5cc6ce0bbf87f3b269368675406c48ea49d52570b9f178'
            assert s.count(old)==1;s=s.replace(old,pins['scripts/destruction/palazzo/c4_equipment.gd']);p.write_bytes(s.encode());pins[parent]=sha(p)
            entry=owner['entry'].removeprefix('res://');p=GAME/entry;s=p.read_text(encoding='utf-8-sig')
            for name,old in owner['source_pins'].items():
                if name==entry or name not in pins:continue
                s=s.replace('"'+name+'": "'+old+'"','"'+name+'": "'+pins[name]+'"')
            p.write_bytes(s.encode());pins[entry]=sha(p)
            verify(GAME,pins);verify(source,base['source_pins'])
            save(HERE/'ASSEMBLY.json',{'accepted':False,'performance_accepted':False,'game':str(GAME),'base_sha256':sha(BASE),'owner_qa_sha256':sha(OWNER),'source_pins':pins,'source_count':len(pins),'runtime_delta':{p:h for p,(_,h) in PATCHES.items()},'qa_identity_only_rebase':[parent,entry],'entry':entry,'lease':lease.request})
        print('STAGED',len(pins));return
    manifest=load(HERE/'ASSEMBLY.json');pins=manifest['source_pins'];out=HERE/'runs'/args.label;out.mkdir(parents=True,exist_ok=False)
    record={'passed':False,'mode':args.mode,'assembly_sha256':sha(HERE/'ASSEMBLY.json'),'runner_sha256':sha(__file__),'scheduler_sha256':SCHEDULER_SHA,'performance_accepted':False,'production_accepted':False}
    started=time.monotonic()
    try:
        with Lease('headless',GAME,'write' if args.mode=='import' else 'read',120) as lease:
            verify(GAME,pins);verify(source,base['source_pins']);record['lease']=lease.request
            command=[str(ENGINE),'--headless','--path',str(GAME)]
            command += ['--editor','--import','--quit'] if args.mode=='import' else ['--script',str(GAME/manifest['entry']),'--','--out='+str(out/'RESULT.json'),'--qa-manifest='+str(HERE/'ASSEMBLY.json')]
            record['command']=command
            with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
                begun=time.monotonic();child=subprocess.Popen(command,cwd=GAME,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
                record['child']=lease.register_child(child);record['exit_code']=child.wait(timeout=max(.1,60-(time.monotonic()-begun)))
            verify(GAME,pins);verify(source,base['source_pins']);record['source_pins_before_after']=True
            record['stderr_bytes']=(out/'stderr.log').stat().st_size
            log=(out/'stdout.log').read_text(encoding='utf-8-sig',errors='replace');assert record['exit_code']==0 and record['stderr_bytes']==0 and 'ERROR:' not in log
            if args.mode=='run':
                report=load(out/'RESULT.json');record.update(checks=report.get('checks'),failures=report.get('failures'));assert report.get('status')=='PASS' and not report.get('failures')
            record['passed']=True
    except Exception as error:record['error']=str(error)
    finally:record['elapsed_seconds']=time.monotonic()-started;save(out/'RUN.json',record)
    print(json.dumps({k:v for k,v in record.items() if k not in ['command','lease','child']},ensure_ascii=True));raise SystemExit(0 if record['passed'] else 1)
if __name__=='__main__':main()
