import argparse, hashlib, json, os, pathlib, subprocess, sys

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[1]
p = argparse.ArgumentParser()
p.add_argument('name')
p.add_argument('--game', default=str(OUT / 'game'))
p.add_argument('--hp', type=int, default=49)
p.add_argument('--duration', type=int, default=100)
p.add_argument('--graphical', action='store_true')
p.add_argument('--perf', action='store_true')
p.add_argument('--entry', default='entry28.gd')
p.add_argument('--extra', action='append', default=[])
a = p.parse_args()
if a.perf: a.graphical = True
game = pathlib.Path(a.game).resolve()
run = OUT / a.name
assert not run.exists(), 'Run directory must be new'
run.mkdir(parents=True)
def pins():
    return {str(f.relative_to(game)).replace('\\','/'): hashlib.sha256(f.read_bytes()).hexdigest()
            for f in game.rglob('*') if f.is_file() and '.godot' not in f.parts}
before = pins()
(run / 'SOURCE.json').write_text(json.dumps(before, indent=2), encoding='utf-8')
flags = ['--city-qa=1', '--city-resident-name=Житель', '--city-simple-hospital=1',
 '--city-plaza-support-plate=1', '--city-medical-threshold=0.5', '--city-energy-drain-per-m=0.05',
 '--city-energy-threshold=0.2', '--city-palazzo-clones=1', '--city-clone-step=22', '--city-town=1',
 '--city-door-free-entry=1', '--city-site-door-physics=1', '--city-clone-door-swing=1',
 '--city-needs=1', '--city-shop-release=1', '--city-nav-pump-budget-us=4000', '--city-nav-pump-every=1',
 '--city-daily-slice=286', '--city-sim-stride=1', '--city-sim-one-per-frame=0', '--city-walk-pose=1', '--city-pose-far-cap=512', '--city-clear-cache=1',
 '--city-timing=0', '--city-health-lease', '--city-resident-detail=1', '--city-hospital-marker=0', '--city-venue-sites29=1', '--city-venue-staff29=1',
 '--qa-duration='+str(a.duration), '--qa-out='+str(run), *a.extra]
if a.hp >= 0: flags.append('--city-hp='+str(a.hp))
engine = pathlib.Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
cmd = [sys.executable, '-B', str(ROOT/'tools/godot/test_scheduler.py'), 'run', '--mode',
 'perf' if a.perf else ('graphical' if a.graphical else 'headless'), '--project', str(game), '--wait-seconds', '60',
 '--timeout', str(a.duration+120), '--out', str(run/'engine'), '--', str(engine)]
if not a.graphical: cmd += ['--headless']
cmd += ['--path', str(game), '--script', str(OUT/'qa'/a.entry), '--', *flags]
result = subprocess.run(cmd, cwd=ROOT, capture_output=True)
(run/'runner.stdout.log').write_bytes(result.stdout)
(run/'runner.stderr.log').write_bytes(result.stderr)
after = pins()
summary = {'exit':result.returncode, 'source_drift':[k for k in before if before[k]!=after.get(k)],
           'flags':flags, 'visual_verified':False, 'performance_accepted':False}
(run/'RUN_CHECK.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(summary, ensure_ascii=True))
sys.exit(result.returncode or bool(summary['source_drift']))
