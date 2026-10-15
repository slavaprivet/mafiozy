"""Private native regression. Does not alter frozen53a or the shared54 project."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess, sys

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[3]
SOURCE = ROOT / 'outputs/coordinator29_release53a/game'
GAME = OUT / 'game'
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def pins(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in folder.rglob('*')
            if p.is_file() and '.godot' not in p.parts}

def stage():
    assert not GAME.exists()
    source_pins = {}
    with Lease(mode='headless', project=GAME, access='write', wait_seconds=60):
        for item in SOURCE.rglob('*'):
            rel = item.relative_to(SOURCE)
            if '.godot' in rel.parts or not item.is_file(): continue
            dest = GAME / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, dest)
            source_pins[rel.as_posix()] = sha(dest)
    assert not [k for k,v in source_pins.items() if sha(SOURCE/k)!=v]
    (OUT/'SOURCE_PINS.json').write_text(json.dumps(source_pins,indent=2),encoding='utf-8')
    shutil.copy2(ROOT/'outputs/coordinator29_npc53/qa/observer_death28.gd',OUT/'observer_death28.gd')
    print(json.dumps({'staged_files':len(source_pins),'frozen_source_unchanged':True}))

def patch():
    rel='scripts/npc_visual/npc_attention29.gd'
    content=(SOURCE/rel).read_text(encoding='utf-8')
    before='\t\tallowed = life._host.target_current(life._token) and not life._health.should_pause_walk()\n'
    after=before+'''\t\t# Damage clears attention synchronously, but gaze is evaluated again next frame.
\t\t# Medical need (including retry cooldown) and the complete hospital visit own
\t\t# movement until the resident has healed and physically left the building.
\t\tallowed = allowed and not life._hospital51_below_threshold(row) and not life._needs_hospital(row) and str(life._goal.get("kind", "")) != "hospital"
'''
    assert content.count(before)==1
    content=content.replace(before,after,1)
    dest=OUT/'patch'/rel
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(content,encoding='utf-8')
    if GAME.exists():
        with Lease(mode='headless',project=GAME,access='write',wait_seconds=60):
            (GAME/rel).write_text(content,encoding='utf-8')
    (OUT/'PATCH.json').write_text(json.dumps({'base':str(SOURCE),'changes':{rel:{'before':sha(SOURCE/rel),'after':sha(dest)}}},indent=2),encoding='utf-8')
    print('Medical priority guard staged.')

def run(name, importing=False, graphical=False, final=False):
    run=OUT/'runs'/name
    assert not run.exists()
    run.mkdir(parents=True)
    before=pins(GAME)
    (run/'SOURCE.json').write_text(json.dumps(before,indent=2),encoding='utf-8')
    harness={p.name:sha(p) for p in OUT.glob('*.gd')}
    harness[pathlib.Path(__file__).name]=sha(pathlib.Path(__file__))
    (run/'HARNESS_PINS.json').write_text(json.dumps(harness,indent=2),encoding='utf-8')
    engine=pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    flags=json.loads((ROOT/'outputs/coordinator29_npc53/death53_02/RUN_CHECK.json').read_text(encoding='utf-8'))['flags']
    flags=[f for f in flags if not f.startswith(('--city-hp=','--city-energy-start=','--city-wallet-start=','--qa-out=','--qa-duration='))]
    if final:
        flags=[f for f in flags if not f.startswith(('--city-venue-sites29=','--city-venue-staff29=','--city-sandbox-seed='))]
        flags+=['--city-venue-sites29=1','--city-venue-staff29=1','--city-sandbox-seed=53','--city-hp=100']
    flags += ['--qa-out='+str(run),'--qa-duration=160']
    cmd=[sys.executable,'-B',str(ROOT/'tools/godot/test_scheduler.py'),'run','--mode','graphical' if graphical else 'headless','--project',str(GAME),'--wait-seconds','60','--timeout','250','--out',str(run/'engine')]
    if importing: cmd += ['--access','write']
    cmd += ['--',str(engine)]
    if not graphical: cmd += ['--headless']
    cmd += ['--path',str(GAME)]
    if importing: cmd += ['--editor','--import','--quit']
    else: cmd += ['--script',str(OUT/('entry_final_injury30.gd' if final else 'entry_injury30.gd')),'--',*flags]
    completed=subprocess.run(cmd,cwd=ROOT,capture_output=True)
    (run/'runner.stdout.log').write_bytes(completed.stdout)
    (run/'runner.stderr.log').write_bytes(completed.stderr)
    after=pins(GAME)
    drift=[k for k in set(before)|set(after) if before.get(k)!=after.get(k)]
    harness_drift=[k for k,v in harness.items() if sha(OUT/k)!=v]
    summary={'exit':completed.returncode,'source_drift':drift,'harness_drift':harness_drift,'flags':flags,'graphical':graphical,'final_content':final,'performance_accepted':False}
    (run/'RUN_CHECK.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps(summary))
    return completed.returncode or bool(drift) or bool(harness_drift)

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('action',choices=['stage','patch','run','import']); p.add_argument('name',nargs='?',default='native01'); p.add_argument('--graphical',action='store_true'); p.add_argument('--game',type=pathlib.Path); a=p.parse_args()
    if a.game:
        assert a.action=='run', 'Only read-only final verification can target another project'
        GAME=a.game.resolve()
    if a.action=='stage': stage()
    elif a.action=='patch': patch()
    else: sys.exit(run(a.name,a.action=='import',a.graphical,a.game is not None))
