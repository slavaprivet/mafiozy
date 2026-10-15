"""Owner-run native fixtures. Stages a tiny private project with a write Lease.

No existing game is edited; nothing is accepted into F5. Native run must be
explicitly authorized by root (authorization now granted). Examples:
  python -B .../run_fixtures29.py long01
  python -B .../run_fixtures29.py long02
"""
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[3]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease

p = argparse.ArgumentParser()
p.add_argument('name')
p.add_argument('--cases',choices=['all','proxies'],default='all')
p.set_defaults(variant='candidate')
p.set_defaults(guide='long02')
p.add_argument('--engine', type=pathlib.Path, default=pathlib.Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe')
a = p.parse_args()
assert a.name and all(c.isalnum() or c in '-_' for c in a.name), 'simple new run name required'
run = OUT / 'runs' / a.name
assert not run.exists(), 'fresh output directory required'
run.mkdir(parents=True)
game = run / 'project'
scheduler = ROOT / 'tools/godot/test_scheduler.py'
pins = json.loads((OUT / 'BASELINE.json').read_text(encoding='utf-8'))['files']
expected_scheduler = next(x['sha256'] for x in pins if x['path'] == 'tools/godot/test_scheduler.py')
assert hashlib.sha256(scheduler.read_bytes()).hexdigest() == expected_scheduler, 'scheduler drift: review adapter before running'

with Lease(mode='headless', project=game, access='write', wait_seconds=120) as lease:
    (game / 'scripts/hospital').mkdir(parents=True)
    (game / 'qa').mkdir()
    (game / 'scripts/navigation').mkdir()
    (game / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Navigation29 long fixture"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
    for source in (OUT/'baseline/scripts').rglob('*'):
        if not source.is_file() or '/npc_visual/' in str(source).replace('\\','/') or '/venues/' in str(source).replace('\\','/') or source.name=='npc_city_population.gd': continue
        target=game/'scripts'/source.relative_to(OUT/'baseline/scripts')
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,target)
    for source in (OUT/'scripts').rglob('*.gd'):
        target=game/'scripts'/source.relative_to(OUT/'scripts')
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,target)
    for source in (OUT/'qa').glob('*.gd'):
        shutil.copyfile(source,game/'qa'/source.name)
    (run / 'STAGE_LEASE.json').write_text(json.dumps(lease.request, indent=2), encoding='utf-8')


def source_pins():
    return {str(f.relative_to(game)).replace('\\', '/'): hashlib.sha256(f.read_bytes()).hexdigest()
            for f in game.rglob('*') if f.is_file() and '.godot' not in f.parts and not f.name.endswith('.uid')}


before = source_pins()
(run / 'SOURCE.json').write_text(json.dumps(before, indent=2), encoding='utf-8')
results = []


def native(name, arguments, timeout, access='read'):
    command = [sys.executable, '-B', str(scheduler), 'run', '--mode', 'headless', '--project', str(game),
               '--access', access, '--wait-seconds', '120', '--timeout', str(timeout), '--out', str(run / name), '--',
               str(a.engine), '--headless', '--path', str(game), *arguments]
    completed = subprocess.run(command, cwd=ROOT, capture_output=True)
    (run / (name + '.runner.stdout.log')).write_bytes(completed.stdout)
    (run / (name + '.runner.stderr.log')).write_bytes(completed.stderr)
    return completed.returncode


import_exit = native('import', ['--editor', '--import', '--quit'], 60, access='write')
if import_exit == 0:
    cases = ['proxies_fixture29'] if a.cases=='proxies' else ['proxies_fixture29', 'avoidance_fixture29']
    for case in cases:
        result_path = run / (case + '.json')
        flags = ['--qa-out=' + str(result_path)]
        if a.variant == 'baseline': flags.append('--qa-baseline=1')
        exit_code = native(case, ['--script', str(game / 'qa' / (case + '.gd')), '--', *flags], 120)
        semantic = json.loads(result_path.read_text(encoding='utf-8')) if result_path.exists() else {}
        results.append({'case': case, 'exit': exit_code, 'passed': exit_code == 0 and semantic.get('passed') is True})
        if not results[-1]['passed']: break
after = source_pins()
drift = sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))
summary = {'variant': a.variant, 'guide':a.guide, 'import_exit': import_exit, 'source_drift': drift, 'cases': results,
           'passed': import_exit == 0 and bool(results) and all(x['passed'] for x in results) and not drift,
           'gameplay_performance_accepted': False, 'user_processes_closed': False}
(run / 'RESULT.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
print(json.dumps(summary))
sys.exit(0 if summary['passed'] else 1)
