"""Deliver the reviewed modal Escape fix, preserving every unscoped source byte."""
from pathlib import Path
import hashlib, json, shutil

root = Path(__file__).resolve().parents[2]
stage = root/'outputs/coordinator24_quality/candidate22'
game = stage/'godot/mafiozi_walk'
shared = root/'godot/mafiozi_walk'
export = game/'exports/win64/s01-20260930-quality24b'
out = root/'outputs/coordinator24_delivery24b'
dest = shared/'exports/win64/s01-20260930-quality24b-play'
pin = 'becb595b967ca70fe31660e137a9e591a17abb2418259733fa707342ddc7a749'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
assert not out.exists() and not dest.exists()
assert sha(export/'MafioziPreview.pck') == pin
for folder, fixed, gpu in [('baseline01',False,False),('candidate01',True,False),('focused01',True,True)]:
    run = load(root/'outputs/coordinator24_cargo_escape'/folder/'RUN.json')
    result = run['result']
    assert run['exit_code'] == 0 and run['pack_unchanged'] and not run['native_errors']
    assert result['valid'] and not result['errors'] and result['expect_fixed'] == fixed and result['gpu'] == gpu
    assert result['evidence']['clicks_to_resume'] == (0 if fixed else 1)
    if fixed:
        assert result['pack_sha256'] == pin and result['evidence']['after_escape_release']['free']
        if gpu: assert result['evidence']['after_escape_release']['mouse_mode'] == 2
        assert result['evidence']['movement_m'] > 0 and result['evidence']['final']['mouse_mode'] == 0
receipt = load(export/'build_receipt.json')
assert len(receipt['inputs']) == 209 and receipt['sourceInputsUnchangedDuringExport']
for item in receipt['inputs']: assert sha(game/item['path']) == item['sha256'], item['path']
for item in receipt['artifacts']: assert sha(export/item['filename']) == item['sha256'], item['filename']
manifest = load(stage/'INTEGRATION.json')
assert set(manifest['changes']) == {'scripts/weapons/preview_weapon_cargo.gd','scripts/main.gd','data/preview_updates.json'}
for name, change in manifest['changes'].items():
    assert sha(shared/name) == change['before'], 'Concurrent source edit: '+name
    assert sha(game/name) == change['after'], 'Frozen source changed: '+name
preserved = {}
for p in shared.rglob('*'):
    if not p.is_file() or any(s in ['.godot','exports'] for s in p.parts): continue
    rel = p.relative_to(shared).as_posix()
    if rel not in manifest['changes']: preserved[rel] = sha(p)
out.mkdir()
for name, change in manifest['changes'].items():
    assert sha(shared/name) == change['before']
    backup = out/'before'/name
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(shared/name, backup)
    shutil.copyfile(game/name, shared/name)
    assert sha(shared/name) == change['after']
for name, expected in preserved.items(): assert sha(shared/name) == expected, name
dest.mkdir(parents=True)
for name in ['MafioziPreview.exe','MafioziPreview.pck','build_receipt.json']:
    shutil.copyfile(export/name, dest/name)
    assert sha(dest/name) == sha(export/name)
shutil.copyfile(export/'build_receipt.json', out/'build_receipt.json')
record = {'status':'ACCEPTED_SCOPED_PROMOTION','revision':'s01-20260930-quality24b','candidate':'candidate22',
 'pack_sha256':pin,'changes':manifest['changes'],'preserved_unscoped':preserved,
 'export_path':dest.relative_to(root).as_posix(),
 'limits':'Exact compiled-pack native F/Escape input regression, focused GPU window and image inspected. Injected keys, not manual OS-input proof. One modal key-routing line; existing close path, no new per-frame cost. No new whole-city performance claim. NPC visit and corpse upgrades remain isolated.'}
(out/'PROMOTION.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'promoted':3,'preserved_unscoped':len(preserved),'pack_sha256':pin,'export':record['export_path']}))
