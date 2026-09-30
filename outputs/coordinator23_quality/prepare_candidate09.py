from pathlib import Path
import hashlib, json, shutil
root = Path(__file__).resolve().parents[2]
base = root / 'outputs/coordinator23_quality/candidate08'
target = root / 'outputs/coordinator23_quality/candidate09'
package = root / 'outputs/coordinator23_marks_prewarm09'
receipt = json.loads((package / 'RECEIPT.json').read_text(encoding='utf8'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
relative = receipt['file']
assert not target.exists()
assert sha(base / 'godot/mafiozi_walk' / relative) == receipt['before_sha256']
source = package / 'files' / relative
assert sha(source) == receipt['after_sha256']
shutil.copytree(base, target, ignore=shutil.ignore_patterns('exports'))
shutil.copyfile(source, target / 'godot/mafiozi_walk' / relative)
manifest_path = target / 'INTEGRATION.json'
manifest = json.loads(manifest_path.read_text(encoding='utf8'))
manifest['parent'] = 'candidate08'
manifest['changes'][relative]['parent_before'] = receipt['before_sha256']
manifest['changes'][relative]['after'] = receipt['after_sha256']
manifest['changes'][relative]['source'] = str(source.relative_to(root))
manifest['changes'][relative]['status'] = 'prepares exact pipeline during loading; cold GPU retest pending'
manifest['changes']['scripts/main.gd']['source'] = 'reviewed root wiring, default ON in acceptance candidate; same as compiled08'
manifest['status'] = 'HOLD until cold-rendered first-hit stall eliminated; isolated only'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
print('Guarded candidate09 ready: only marks startup preparation differs from08')
