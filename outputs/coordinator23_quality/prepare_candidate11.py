"""Build an isolated responsive trunk fix from immutable candidate10."""
from pathlib import Path
import hashlib, json, shutil
root = Path(__file__).resolve().parents[2]
base = root/'outputs/coordinator23_quality/candidate10'
target = root/'outputs/coordinator23_quality/candidate11'
proposal = root/'outputs/coordinator23_trunk_layout11'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
receipt = json.loads((proposal/'RECEIPT.json').read_text(encoding='utf-8-sig'))
changes = receipt.get('changes') or {r['path']: {'before': r['before_sha256'], 'after': r['after_sha256']} for r in receipt['files']}
assert not target.exists(), 'Never overwrite an existing candidate'
for name, change in changes.items():
    assert sha(base/'godot/mafiozi_walk'/name) == change['before'], name
    assert sha(proposal/'files'/name) == change['after'], name
shutil.copytree(base, target, ignore=shutil.ignore_patterns('exports'))
manifest = json.loads((target/'INTEGRATION.json').read_text(encoding='utf8'))
for name, change in changes.items():
    shutil.copyfile(proposal/'files'/name, target/'godot/mafiozi_walk'/name)
    original = manifest['changes'].get(name, {}).get('before', change['before'])
    manifest['changes'][name] = dict(before=original, parent_before=change['before'],
        after=change['after'], source=str((proposal/'files'/name).relative_to(root)),
        status='responsive fix; compiled GUI acceptance pending')
manifest.update(parent='candidate10', status='ISOLATED23g responsive trunk; acceptance pending')
(target/'INTEGRATION.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
print('Guarded candidate11 created; shared source unchanged')
