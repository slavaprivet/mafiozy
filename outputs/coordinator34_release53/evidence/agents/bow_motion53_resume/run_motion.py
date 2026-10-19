from pathlib import Path
import argparse, hashlib, json, subprocess, sys

parser = argparse.ArgumentParser()
parser.add_argument('--game', required=True, type=Path)
parser.add_argument('--run', required=True)
parser.add_argument('--weapon', required=True, choices=['bow', 'sword', 'spear'])
args = parser.parse_args()
workspace = Path.cwd()
out = Path('D:/MafioziCombat31/bow_motion53_resume') / args.run
out.mkdir(parents=True, exist_ok=False)
engine = Path.home()/'AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
script = Path('D:/MafioziCombat31/bow_motion53_resume/motion_regression.gd')
source_paths = ['scripts/preview_player.gd', 'scripts/weapons/bow_prototype.gd', 'scripts/weapons/sword_prototype.gd', 'scripts/city/castle_armory_storage.gd']
def pins():
    return {p: hashlib.sha256((args.game/p).read_bytes()).hexdigest() for p in source_paths}
before = pins()
command = [sys.executable, str(workspace/'tools/godot/test_scheduler.py'), 'run', '--mode', 'headless', '--project', str(args.game), '--wait-seconds', '240', '--timeout', '140', '--out', str(out/'native'), '--', str(engine), '--headless', '--max-fps', '90', '--path', str(args.game), '--script', str(script), '--', f'--qa-out={out}/result.json', f'--weapon={args.weapon}']
run = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')
(out/'runner_stdout.txt').write_text(run.stdout, encoding='utf-8')
(out/'runner_stderr.txt').write_text(run.stderr, encoding='utf-8')
after = pins()
result = json.loads((out/'result.json').read_text(encoding='utf-8-sig')) if (out/'result.json').exists() else {}
receipt = {'passed':run.returncode==0 and result.get('passed') is True and before==after,'game':str(args.game),'weapon':args.weapon,'harness_sha256':hashlib.sha256(script.read_bytes()).hexdigest(),'source_before':before,'source_after':after,'source_unchanged':before==after,'scheduler_exit_code':run.returncode,'checks':result.get('checks',[]),'errors':result.get('errors',[])}
(out/'RECEIPT.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps(receipt))
sys.exit(0 if receipt['passed'] else 2)
