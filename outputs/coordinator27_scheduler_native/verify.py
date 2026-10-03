"""Two actual bounded headless engines plus the real F5 identity predicate."""
from pathlib import Path
import concurrent.futures
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import threading
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('scheduler', ROOT / 'tools/godot/test_scheduler.py')
scheduler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scheduler)
ENGINE = Path(os.environ['LOCALAPPDATA']) / 'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
assert hashlib.sha256(ENGINE.read_bytes()).hexdigest() == 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
OUT = HERE / time.strftime('run_%Y%m%d_%H%M%S')
OUT.mkdir(exist_ok=False)
barrier = threading.Barrier(3, timeout=100)
children = []

def run(index):
    project = OUT / str(index)
    project.mkdir()
    (project / 'project.godot').write_text('config_version=5\n\n[application]\nconfig/name="Scheduler native verification"\n', encoding='utf-8')
    shutil.copy2(HERE / 'qa.gd', project / 'qa.gd')
    command = [str(ENGINE), '--headless', '--path', str(project), '--script', str(project / 'qa.gd')]
    with scheduler.Lease('headless', project, wait_seconds=90) as lease:
        with (project / 'out.log').open('wb') as out, (project / 'err.log').open('wb') as err:
            started = time.time()
            child = subprocess.Popen(command, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                registered = lease.register_child(child)
                children.append(registered)
                barrier.wait()
                code = child.wait(timeout=35)
                ended = time.time()
            finally:
                if child.poll() is None:
                    child.terminate()
                    child.wait(timeout=10)
        assert code == 0 and (project / 'err.log').stat().st_size == 0
        text = (project / 'out.log').read_text(encoding='utf-8-sig')
        assert 'SCHEDULER_NATIVE_READY' in text and 'SCHEDULER_NATIVE_DONE' in text
        return dict(index=index, started=started, ended=ended, child=registered, exit_code=code)

result = {'passed': False, 'user_processes_closed': False}
try:
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(run, i) for i in (1, 2)]
        barrier.wait()
        live = scheduler.status()
        ids = [x['pid'] for x in children]
        assert len(ids) == 2 and all(pid in live['coexist_pids'] for pid in ids)
        assert sum(x['mode'] == 'headless' for x in live['active']) == 2
        # Use PowerShell's array argument syntax so both live identities are checked.
        ps_script = str(HERE / 'check_live_f5.ps1').replace("'", "''")
        ps_command = "& '" + ps_script + "' -ExpectedPid " + ','.join(str(x) for x in ids)
        check = subprocess.run(['pwsh', '-NoProfile', '-Command', ps_command], capture_output=True, timeout=15,
                               creationflags=subprocess.CREATE_NO_WINDOW)
        result['f5_predicate'] = {'exit_code': check.returncode, 'stdout': check.stdout.decode('utf-8-sig', errors='replace'),
                                  'stderr': check.stderr.decode('utf-8-sig', errors='replace')}
        assert check.returncode == 0, result['f5_predicate']
        rows = [f.result() for f in futures]
        overlap = min(x['ended'] for x in rows) - max(x['started'] for x in rows)
        assert overlap > 3
        result.update(passed=True, overlap_seconds=overlap, runs=rows, status_during=live,
                      scheduler_sha256=hashlib.sha256((ROOT / 'tools/godot/test_scheduler.py').read_bytes()).hexdigest())
except Exception as error:
    result['error'] = str(error)
finally:
    (OUT / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ('runs','status_during')}, ensure_ascii=True))
raise SystemExit(0 if result['passed'] else 1)
