import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease

HERE = Path(__file__).resolve().parent
SOURCE = ROOT / 'outputs/coordinator31_npc57/game'
GAME = HERE / 'game'
ENGINE = Path.home() / 'AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
WEAPON = Path('scripts/weapons/sword_prototype.gd')

def run(label, args, mode='graphical', access='read', timeout=240):
    out = HERE / label
    out.mkdir(exist_ok=False)
    command = [str(ENGINE), '--path', str(GAME), *args]
    with Lease(mode=mode, project=GAME, access=access, wait_seconds=30) as lease:
        with (out/'stdout.log').open('wb') as stdout, (out/'stderr.log').open('wb') as stderr:
            proc = subprocess.Popen(command, stdout=stdout, stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
            identity = lease.register_child(proc)
            code = proc.wait(timeout=timeout)
    (out/'RUN.json').write_text(json.dumps({'command':command, 'exit':code, 'child':identity}, default=str, indent=2))
    print(label, 'exit', code, 'stderr', (out/'stderr.log').stat().st_size, flush=True)
    if code: raise RuntimeError(label)

def main():
    global GAME
    if '--production' in sys.argv:
        GAME = SOURCE
    stage = sys.argv[1]
    if stage == 'contacts':
        run('contact_checks', ['--headless','--script',str(HERE/'contact_checks.gd')], 'headless')
        return
    if stage == 'check':
        run('compile_check', ['--headless','--script','res://scripts/tests/dsh_sword_proto_check.gd'], 'headless')
        return
    if stage == 'stage':
        with Lease(mode='headless', project=GAME, access='write', wait_seconds=30):
            shutil.copytree(SOURCE, GAME, ignore=shutil.ignore_patterns('.godot', '.git'))
        digest = hashlib.sha256((GAME/WEAPON).read_bytes()).hexdigest()
        (HERE/'SOURCE.json').write_text(json.dumps({'commit':subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(), 'sword_sha256':digest}))
        run('import', ['--headless','--editor','--import','--quit'], 'headless', 'write')
        return
    flags = ['--city-player-shop=1']
    output = HERE/stage
    output.mkdir(exist_ok=False)
    fixture = 'display_probe.gd' if '--display' in sys.argv else 'castle_sword_probe.gd'
    run(stage+'_run', ['--resolution','1280x720','--script',str(HERE/fixture),'--', *flags, '--catapult=1','--sword-proto=1','--combat-out='+str(output)])

if __name__ == '__main__': main()
