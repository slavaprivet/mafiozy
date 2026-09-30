"""Save verified outputs and review evidence, without staging NPC/runtime WIP."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
out = root / 'outputs/coordinator23_point_checkpoint'
out.mkdir(exist_ok=True)
def git(*args, data=None):
    p = subprocess.run(['git', *args], cwd=root, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode: raise RuntimeError(p.stderr.decode('utf8', errors='replace'))
    return p.stdout
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
assert git('rev-parse', 'HEAD').decode().strip() == '9f86f3216beba96009c7ded1216368b863ad1ec4'
assert not git('diff', '--cached', '--name-only').strip(), 'Occupied index'
audit = root / 'outputs/coordinator23_point_impulse_audit'
for name, prefix in [('FOLLOWUP_PINS.json', audit), ('closure/MANIFEST.json', audit / 'closure')]:
    pin = json.loads((audit / name).read_text(encoding='utf-8-sig'))
    for path, value in pin['files'].items():
        expected = value if isinstance(value, str) else value['sha256']
        assert sha(prefix / path) == expected, path
for name in ['frozen834_comparison.json', 'limb_contacts02_comparison.json']:
    result = json.loads((audit / name).read_text(encoding='utf8'))
    assert not result.get('comparison_errors'), name
files = {}
for directory in ['outputs/coordinator23_point_impulse_audit', 'outputs/coordinator23_head_marks_review', 'outputs/coordinator23_contact_port_review']:
    for p in sorted((root / directory).rglob('*')):
        if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ['.pyc', '.uid']:
            files[p.relative_to(root).as_posix()] = p.read_bytes()
for name in ['docs/ai/COORDINATOR_23_MEMORY.md',
             'outputs/coordinator23_quality/candidate06_input01.log',
             'outputs/coordinator23_quality/candidate06_input01/RESULT.json',
             'outputs/coordinator23_quality/candidate06_standing.log',
             'outputs/coordinator23_quality/candidate06_off_startup.log',
             'outputs/coordinator23_quality/checkpoint_point23.py']:
    files[name] = (root / name).read_bytes()
manifest = {'schema': 'coordinator23.evidence-checkpoint/v1', 'base': '9f86f3216beba96009c7ded1216368b863ad1ec4',
            'scope': 'Exact corrected point proposal/native evidence and explicit HOLD reviews. No accepted runtime change, foot enable, candidate06 export, or shared NPC edits.',
            'files': [{'path': p, 'bytes': len(b), 'sha256': hashlib.sha256(b).hexdigest()} for p, b in files.items()]}
manifest_name = 'outputs/coordinator23_point_checkpoint/MANIFEST.json'
files[manifest_name] = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode('utf8')
for p, data in files.items():
    frozen = out / 'frozen' / p
    frozen.parent.mkdir(parents=True, exist_ok=True)
    frozen.write_bytes(data)
(root / manifest_name).write_bytes(files[manifest_name])
print(json.dumps({'files': len(files), 'bytes': sum(map(len, files.values())), 'scope': manifest['scope']}))
if '--stage' in sys.argv:
    assert not git('diff', '--cached', '--name-only').strip()
    assert git('rev-parse', 'HEAD').decode().strip() == manifest['base']
    lines = []
    for p, data in files.items():
        blob = git('hash-object', '-w', '--stdin', data=data).decode().strip()
        lines.append(f'100644 {blob}\t{p}\n')
    git('update-index', '--index-info', data=''.join(lines).encode('utf8'))
    staged = set(git('diff', '--cached', '--name-only', '-z').decode('utf8').split('\0')) - {''}
    assert staged == set(files), staged ^ set(files)
    print('STAGED_EXACT_POINT_EVIDENCE')
