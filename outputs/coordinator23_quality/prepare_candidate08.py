from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
base = root / 'outputs/coordinator23_quality/candidate07'
target = root / 'outputs/coordinator23_quality/candidate08'
package = root / 'outputs/coordinator23_head_merge07'
receipt = json.loads((package / 'RECEIPT.json').read_text(encoding='utf8'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
assert not target.exists(), 'Refuse to overwrite candidate08'
for path, row in receipt['changes'].items():
    assert sha(base / 'godot/mafiozi_walk' / path) == row['before'], path
    assert sha(package / 'files' / path) == row['after'], path
shutil.copytree(base, target, ignore=shutil.ignore_patterns('exports'))
project = target / 'godot/mafiozi_walk'
manifest_path = target / 'INTEGRATION.json'
manifest = json.loads(manifest_path.read_text(encoding='utf8'))
for path, row in receipt['changes'].items():
    shutil.copyfile(package / 'files' / path, project / path)
    original = manifest['changes'].get(path, {}).get('before', row['before'])
    manifest['changes'][path] = {'before': original, 'parent_before': row['before'], 'after': row['after'], 'source': str((package / 'files' / path).relative_to(root)), 'status': 'component800 + ACTIVE89; compiled rendered acceptance pending'}
preset = project / 'export_presets.cfg'
text = preset.read_text(encoding='utf8')
resource = 'res://scripts/npc_visual/npc_head_zone.gd'
assert resource not in text
text = text.replace('export_files=PackedStringArray(', 'export_files=PackedStringArray("' + resource + '", ')
preset.write_text(text, encoding='utf8', newline='\n')
manifest['changes']['export_presets.cfg']['after'] = sha(preset)
manifest['parent'] = 'candidate07'
manifest['head_receipt_sha256'] = sha(package / 'RECEIPT.json')
manifest['head_active_receipt_sha256'] = sha(package / 'ACTIVE_RECEIPT.json')
manifest['status'] = 'UNACCEPTED combined wounds/head/point/foot package; contact OFF until rendered performance acceptance'
manifest['limits'] = ['Source stage only; export/rendered performance pending', 'RPG blast damage and full source agendas/recovery still incomplete']
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
print('Candidate08 created; candidate07 unchanged; head tuple/ACTIVE evidence pinned')
