"""Deliver four reviewed cargo-only files and immutable compiled export, with SHA guards."""
from pathlib import Path
import argparse, hashlib, json, shutil

p = argparse.ArgumentParser()
p.add_argument('--focused-run', required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[2]
stage = root / 'outputs/coordinator24_quality/candidate20'
game = stage / 'godot/mafiozi_walk'
shared = root / 'godot/mafiozi_walk'
export = game / 'exports/win64/s01-20260930-quality24a'
out = root / 'outputs/coordinator24_delivery24a'
dest = shared / 'exports/win64/s01-20260930-quality24a-play'
expected = '634b9d3b48e4502538331da9b9e9efdb1641cfc83f04c40c65bd592bd4db7dd5'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
load = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
assert not out.exists() and not dest.exists(), 'Existing delivery must be reviewed, never overwritten'
assert sha(export/'MafioziPreview.pck') == expected
focused = load(root/a.focused_run/'RUN.json')
assert focused['passed'] and focused['result']['valid'] and focused['result']['gpu']
assert focused['result']['pack_sha256'] == expected and not focused['result']['errors']
headless = load(root/'outputs/coordinator24_cargo_input/compiled20_headless01/RUN.json')
assert headless['passed'] and headless['result']['pack_sha256'] == expected
aim = load(root/'outputs/coordinator24_cargo_aim_race/compiled20/RESULT.json')
assert aim['valid'] and not aim['errors']
perf = load(root/'outputs/coordinator24_cargo_input/COMPARISON20.json')
assert perf['comparable'] and not perf['errors'] and perf['candidate_sha'] == expected
audit = load(root/'outputs/coordinator24_takeover/rpg_audit/CARGO20_FINAL_AUDIT.json')
assert audit['pack_sha256'] == expected and not audit['errors']
assert audit['source_inputs_verified'] == 209 and audit['embedded_payload_md5_verified'] == 316
# Root reviewed raw tails: wall p95 improves in all three comparable phases;
# maximum GPU p95 increase is 0.070ms, unchanged content and equal drawcall p95.
# This is limited to the existing three-NPC preview, not whole-city acceptance.
receipt = load(export/'build_receipt.json')
assert len(receipt['inputs']) == 209 and receipt['sourceInputsUnchangedDuringExport']
for item in receipt['inputs']:
    assert sha(game/item['path']) == item['sha256'], item['path']
for item in receipt['artifacts']:
    assert sha(export/item['filename']) == item['sha256'], item['filename']
manifest = load(stage/'INTEGRATION.json')
assert set(manifest['changes']) == {'scripts/weapons/preview_weapon_cargo.gd', 'scripts/weapons/preview_weapons.gd', 'scripts/main.gd', 'data/preview_updates.json'}
for name, change in manifest['changes'].items():
    assert sha(shared/name) == change['before'], 'Concurrent source edit: '+name
    assert sha(game/name) == change['after'], 'Changed frozen source: '+name
preserved = {}
for path in shared.rglob('*'):
    if not path.is_file() or any(x in ['.godot','exports'] for x in path.parts):
        continue
    rel = path.relative_to(shared).as_posix()
    if rel not in manifest['changes']:
        preserved[rel] = sha(path)
out.mkdir()
for name, change in manifest['changes'].items():
    assert sha(shared/name) == change['before']
    backup = out/'before'/name
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(shared/name, backup)
    shutil.copyfile(game/name, shared/name)
    assert sha(shared/name) == change['after']
for rel, expected_sha in preserved.items():
    assert sha(shared/rel) == expected_sha, 'Concurrent unscoped change: '+rel
dest.mkdir(parents=True)
for name in ['MafioziPreview.exe', 'MafioziPreview.pck', 'build_receipt.json']:
    shutil.copyfile(export/name, dest/name)
    assert sha(dest/name) == sha(export/name)
record = {'status':'ACCEPTED_SCOPED_PROMOTION', 'revision':'s01-20260930-quality24a',
    'candidate':'candidate20', 'pack_sha256':expected, 'changes':manifest['changes'],
    'preserved_unscoped':preserved, 'focused_run':a.focused_run,
    'export_path':dest.relative_to(root).as_posix(),
    'limits':'Two proven cargo fixes only. Native injected-input and focused capture verified, no manual Windows input proof; offscreen performance is conditional, not whole-city FPS. Intermittent extra-click complaint not fully closed. RPG19 remains isolated; foreign NPC/transport/palette shared changes retained.'}
(out/'PROMOTION.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
print(json.dumps({'promoted':len(manifest['changes']), 'preserved_unscoped':len(preserved), 'pack_sha256':expected, 'export':record['export_path']}))
