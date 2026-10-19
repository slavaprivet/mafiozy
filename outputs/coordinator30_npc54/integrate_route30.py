"""Apply the reviewed, native-tested route package under the shared write lease."""
import json, pathlib, subprocess, sys

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[1]
sys.path.insert(0, str(ROOT))
from tools.godot.test_scheduler import Lease

with Lease(mode='headless', project=OUT/'game', access='write', wait_seconds=120):
    command = [sys.executable, '-B', str(OUT/'proposals/route30/apply30.py'),
               '--project', str(OUT/'game')]
    check = subprocess.run(command, capture_output=True, check=True)
    checked = json.loads(check.stdout)
    applied = subprocess.run(command + ['--apply'], capture_output=True, check=True)
    report = json.loads(applied.stdout)
    assert checked['files'] == report['files']
    report['native_proof'] = ['proposals/route30/runs/hospital08', 'proposals/route30/runs/local09']
    (OUT/'ROUTE_INTEGRATION.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'integrated': len(report['files']), 'passed': report['passed']}))
