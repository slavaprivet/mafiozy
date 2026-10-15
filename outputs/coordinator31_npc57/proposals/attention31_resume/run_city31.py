"""Read-only actual city validation on the root's merged candidate."""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, sys, time, zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease, probe, ERRORS

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p, v): p.write_text(json.dumps(v, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
def pins(game): return {p.relative_to(game).as_posix(): sha(p) for p in game.rglob('*') if p.is_file() and '.godot' not in p.parts}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('name')
    parser.add_argument('--kind', choices=['visual', 'threat'], default='threat')
    parser.add_argument('--game', type=Path, default=ROOT/'outputs/coordinator31_npc57/game')
    parser.add_argument('--overlay', action='store_true')
    parser.add_argument('--go', action='store_true')
    parser.add_argument('--mode', choices=['headless', 'graphical'], default='headless')
    args = parser.parse_args()
    game = args.game.resolve()
    out = HERE/'runs'/args.name
    launch = json.loads((ROOT/'outputs/coordinator30_release56/ASSEMBLY.json').read_text(encoding='utf-8-sig'))['launch_arguments']
    flags = [x for x in launch if not x.startswith(('--qa-', '--city-qa=', '--city-resident-name=', '--city-quit-after=', '--city-pose-far-cap='))]
    flags += ['--city-qa=10', '--city-pose-far-cap=512', '--qa-out='+str(out)]
    if args.overlay: flags += ['--candidate31=1']
    entry = HERE/'entry_visual31.gd' if args.kind == 'visual' else HERE/'regression/threat/entry56.gd'
    receipt = 'VISUAL31.json' if args.kind == 'visual' else 'CITY_THREAT56.json'
    exe = Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    command = [str(exe), *(['--headless'] if args.mode == 'headless' else ['--resolution','1280x720']), '--path', str(game), '--script', str(entry), '--', *flags]
    if not args.go:
        print(json.dumps({'prepared': True, 'command': command})); sys.exit(0)
    out.mkdir(parents=True, exist_ok=False)
    harness = {p.relative_to(HERE).as_posix(): sha(p) for p in HERE.rglob('*') if p.is_file() and 'runs' not in p.parts and p.suffix in ('.py', '.gd', '.json')}
    save(out/'HARNESS.json', harness)
    with zipfile.ZipFile(out/'HARNESS.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for rel in harness: archive.write(HERE/rel, rel)
    result = {'passed': False, 'kind': args.kind, 'command': command, 'project': str(game), 'access': 'read', 'performance_accepted': False}
    try:
        save(out/'PROBE.json', probe(args.mode, game, 'read'))
        with Lease(args.mode, game, 'read', 90) as lease:
            before = pins(game); save(out/'SOURCE.json', before)
            started = time.monotonic()
            with (out/'stdout.log').open('wb') as stdout, (out/'stderr.log').open('wb') as stderr:
                child = subprocess.Popen(command, cwd=game, stdout=stdout, stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    result['child'] = lease.register_child(child)
                    while child.poll() is None:
                        if time.monotonic()-started > (140 if args.kind == 'visual' else 350): raise TimeoutError('Owned actual-city child watchdog')
                        error = (out/'stderr.log').read_text(encoding='utf-8', errors='replace')
                        if 'SCRIPT ERROR:' in error or 'Parse Error:' in error: raise RuntimeError('Native script error')
                        time.sleep(.2)
                finally:
                    if child.poll() is None: child.terminate(); child.wait(timeout=10)
            result['exit_code'] = child.returncode; result['wall_s'] = time.monotonic()-started
            after = pins(game); save(out/'SOURCE_AFTER.json', after)
            result['source_drift'] = [k for k in set(before)|set(after) if before.get(k) != after.get(k)]
            result['harness_drift'] = [k for k,v in harness.items() if sha(HERE/k) != v]
            result['stderr_bytes'] = (out/'stderr.log').stat().st_size
            result['errors'] = [line for n in ['stdout.log','stderr.log'] for line in (out/n).read_text(encoding='utf-8', errors='replace').splitlines() if ERRORS.search(line)]
            native = json.loads((out/receipt).read_text(encoding='utf-8')) if (out/receipt).exists() else {}
            result['native_passed'] = native.get('passed',False); result['checks'] = native.get('checks',{}); result['reason'] = native.get('reason','native_receipt_missing')
            result['passed'] = child.returncode == 0 and result['native_passed'] and not result['errors'] and not result['stderr_bytes'] and not result['source_drift'] and not result['harness_drift']
    except Exception as error: result['error'] = type(error).__name__+': '+str(error)
    save(out/'RUN.json', result)
    print(json.dumps({k:v for k,v in result.items() if k not in ['command','child']}, ensure_ascii=False))
    sys.exit(0 if result['passed'] else 1)
