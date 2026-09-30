"""Promote only reviewed sources and copy the exact accepted export; never whole-tree copy."""
from pathlib import Path
import hashlib, json, shutil
root = Path(__file__).resolve().parents[2]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
target = root/'outputs/coordinator23_quality/candidate11/godot/mafiozi_walk'
export = target/'exports/win64/s01-20260930-quality23g'
dest = root/'godot/mafiozi_walk/exports/win64/s01-20260930-quality23g-play'
evidence = root/'outputs/coordinator23_delivery23g'
pack_sha = 'ae82e44c46cf3d5f420897c7e91d8a631691dbf4180d27c45342ff428916209e'
assert sha(export/'MafioziPreview.pck') == pack_sha
gui = load(root/'outputs/coordinator23_trunk_visual10/gpu11/RESULT.json')
assert gui['valid'] and gui['checks'] == 120 and gui['pack_sha256'] == pack_sha
assert '"checks":233,"errors":[]' in (root/'outputs/coordinator23_trunk_layout11/compiled11.log').read_text(encoding='utf-8-sig')
assert not dest.exists() and not evidence.exists(), 'Do not overwrite a delivery'
plan = load(root/'outputs/coordinator23_adoption11_guards/GUARDED_PROMOTION.json')
overlay = load(root/'outputs/coordinator23_trunk_layout11/RECEIPT.json')
changes = {r['path']:r for r in overlay['files']}
guards = plan['guards']
prior = load(root/'outputs/coordinator23_adoption09_guards/VERIFY_AND_GUARDS.json')
excluded = {r['path']:sha(root/'godot/mafiozi_walk'/r['path']) for r in prior['unscoped_shared_differences']}
for item in guards:
    rel = item['relative_path']
    expected = changes[rel]['after_sha256'] if rel in changes else item['target_current10_sha256']
    assert sha(root/item['path']) == item['expected_current_sha256'], 'Shared changed: '+rel
    assert sha(target/rel) == expected, 'Target changed: '+rel
    item['accepted11_sha256'] = expected
receipt = load(export/'build_receipt.json')
for artifact in receipt['artifacts']:
    assert sha(export/artifact['filename']) == artifact['sha256'], artifact['filename']
evidence.mkdir()
for item in guards:
    source = root/item['path']; rel = item['relative_path']
    assert sha(source) == item['expected_current_sha256'], 'Concurrent shared change: '+rel
    if source.exists():
        backup = evidence/'before'/rel; backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_bytes(source.read_bytes())
    source.parent.mkdir(parents=True, exist_ok=True)
    if sha(source) != item['accepted11_sha256']: source.write_bytes((target/rel).read_bytes())
    assert sha(source) == item['accepted11_sha256']
for rel, expected in excluded.items():
    assert sha(root/'godot/mafiozi_walk'/rel) == expected, 'Foreign file changed during promotion: '+rel
dest.mkdir(parents=True)
for name in ['MafioziPreview.exe','MafioziPreview.pck','build_receipt.json']:
    shutil.copyfile(export/name, dest/name)
    assert sha(dest/name) == sha(export/name)
report = {'status':'ACCEPTED_SCOPED_SOURCES_AND_EXACT_EXPORT_COPIED', 'revision':'s01-20260930-quality23g',
    'pack_sha256':pack_sha, 'guarded_paths':guards, 'preserved_unscoped_hashes':excluded,
    'export_path':str(dest.relative_to(root)), 'user_process':'not launched by this script',
    'limits':'The measured export excludes preserved foreign shared transport/palette WIP. Shared startup has a separate test. Full migration and RPG blast damage remain incomplete.'}
(evidence/'PROMOTION.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
print('PROMOTED', len(guards), 'scoped files; copied exact accepted PCK', pack_sha)
