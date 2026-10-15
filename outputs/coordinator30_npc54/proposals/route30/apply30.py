"""Check/apply the three scoped route30 patches, preserving unrelated target edits.

Default is read-only. Pass --apply only after reviewing APPLY_CHECK output.
All hunks must match exactly once. A conflict writes no target files.
"""
import argparse, hashlib, json, pathlib, re

HERE = pathlib.Path(__file__).resolve().parent
BASE = json.loads((HERE / 'BASELINE30.json').read_text(encoding='utf-8'))

def sha(data):
    return hashlib.sha256(data).hexdigest()

def patch_text(text, patch):
    hunks = re.split(r'^@@[^\n]*\n', patch, flags=re.M)[1:]
    for index, hunk in enumerate(hunks):
        old = ''.join(line[1:] for line in hunk.splitlines(keepends=True) if line.startswith((' ', '-')))
        new = ''.join(line[1:] for line in hunk.splitlines(keepends=True) if line.startswith((' ', '+')))
        # Diagnostic field is a fragment on an existing long JSON print line.
        # Preserve any sibling package fields added to that same line.
        if '"service_watch30":_service_watch30' in new and old.count('\n') <= 4:
            old = ',"roam_watch":_roam_watch29_state'
            new = old + ',"service_watch30":_service_watch30'
        if 'var _service_watch30: Dictionary' in new:
            old = 'var _roam_watch29_state: Dictionary = {}\n'
            new = old + 'var _service_watch30: Dictionary = {}\nvar _service_anchor30 := Vector3.ZERO\nvar _service_last_us30 := 0\n'
        if not old or text.count(old) != 1:
            raise ValueError(f'hunk {index + 1}: expected one exact context, found {text.count(old)}')
        text = text.replace(old, new, 1)
    return text

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--project', required=True, type=pathlib.Path)
p.add_argument('--apply', action='store_true')
a = p.parse_args()
project = a.project.resolve(strict=True)
if not (project / 'project.godot').is_file():
    raise SystemExit('Target must be a staged Godot project')
if not any(part.startswith('coordinator30') for part in project.parts):
    raise SystemExit('This apply helper may only target a coordinator30 candidate')
pending = []
report = {'project': str(project), 'mode': 'apply' if a.apply else 'check', 'files': []}
for relative, entry in BASE['files'].items():
    path = (project / relative).resolve(strict=True)
    assert path.is_relative_to(project)
    candidate = HERE / relative
    assert sha(candidate.read_bytes()) == entry['candidate_sha256'], f'Candidate drift: {relative}'
    raw = path.read_bytes()
    normalized = raw.decode('utf-8').replace('\r\n', '\n')
    patch = (HERE / (path.stem + '.patch')).read_text(encoding='utf-8')
    result = patch_text(normalized, patch)
    if sha(normalized.encode()) == entry['base_lf_sha256']:
        assert result == candidate.read_text(encoding='utf-8'), f'Patch/candidate mismatch: {relative}'
    encoded = result.replace('\n', '\r\n').encode() if b'\r\n' in raw else result.encode()
    pending.append((path, encoded))
    report['files'].append({'path': relative, 'before_sha256': sha(raw), 'after_sha256': sha(encoded),
                            'package_base_match': sha(normalized.encode()) == entry['base_lf_sha256']})
if a.apply:
    # All conflicts and hashes were checked before the first target write.
    for path, data in pending:
        path.write_bytes(data)
report['passed'] = True
print(json.dumps(report, indent=2))
