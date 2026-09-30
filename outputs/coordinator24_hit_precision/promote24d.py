"""Deliver the exact tested three-file precision change; preserve unrelated work."""
from pathlib import Path
import hashlib, json, shutil

root = Path(__file__).resolve().parents[2]
here = Path(__file__).resolve().parent
game = root/'outputs/coordinator24_quality/candidate27/godot/mafiozi_walk'
shared = root/'godot/mafiozi_walk'
export = game/'exports/win64/s01-20260930-quality24d'
out = root/'outputs/coordinator24_delivery24d'
dest = shared/'exports/win64/s01-20260930-quality24d-play'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
save = lambda p,v: p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
assert not out.exists() and not dest.exists()
assert sha(here/'ASSEMBLY27.json') == '06e899c3dc9d77472931bb6f4bd323f691734b925b7d1fa5e7250fe46bda750a'
assembly = load(here/'ASSEMBLY27.json')
receipt = load(export/'build_receipt.json')
after = {i['path']:i['sha256'] for i in receipt['inputs']}
before = {i['path']:i['sha256'] for i in load(root/'outputs/coordinator24_delivery24c/build_receipt.json')['inputs']}
assert len(after) == len(before) == 224 and after == assembly['source_pins']
assert receipt['sourceInputsUnchangedDuringExport']
for n,h in after.items(): assert sha(game/n) == h, n
for i in receipt['artifacts']: assert sha(export/i['filename']) == i['sha256'], i['filename']
pack = '21c0c2799589fe19b3c506fe8b3d0fc304f4a3f1701ec43013e8c9a3c506e63f'
assert sha(export/'MafioziPreview.pck') == pack
run = load(here/'compiled27_uzi01/RUN.json')
result = load(here/'compiled27_uzi01/RESULT.json')
assert run['passed'] and run['exit_code'] == 0 and not run['native_errors'] and not run['changed']
assert run['checks'] == 75 and run['pack_sha256'] == run['pack_after_sha256'] == pack
assert result['passed'] and not result['errors'] and len(result['precision']) == 3
assert all(p['maximum_lateral_error_m'] <= .0001 and p['minimum_signed_axial_m'] >= 0 for p in result['precision'])
scope = {n for n in after if before[n] != after[n]}
assert scope == {'scripts/main.gd','data/preview_updates.json','scripts/npc_visual/npc_postmortem_bullet_marks.gd'}
for n in scope: assert sha(shared/n) == before[n], 'Concurrent scoped edit: '+n
def untouched():
    return {p.relative_to(shared).as_posix():sha(p) for p in shared.rglob('*') if p.is_file() and not any(x in ('.godot','exports') for x in p.relative_to(shared).parts) and p.relative_to(shared).as_posix() not in scope}
preserved = untouched()
out.mkdir()
for n in scope:
    p = out/'before'/n; p.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(shared/n,p)
assert untouched() == preserved
for n in scope:
    assert sha(shared/n) == before[n] and sha(game/n) == after[n]
    shutil.copyfile(game/n,shared/n)
    assert sha(shared/n) == after[n]
assert untouched() == preserved
dest.mkdir(parents=True)
for n in ('MafioziPreview.exe','MafioziPreview.pck','build_receipt.json'):
    shutil.copyfile(export/n,dest/n)
    assert sha(dest/n) == sha(export/n)
shutil.copyfile(export/'build_receipt.json',out/'build_receipt.json')
save(out/'PROMOTION.json',{'status':'ACCEPTED_SCOPED_PROMOTION','revision':'s01-20260930-quality24d','changes':{n:{'before':before[n],'after':after[n]} for n in sorted(scope)},'preserved_unscoped':preserved,'pack_sha256':pack,'export':dest.relative_to(root).as_posix(),'gpu_checks':75,'native_precision':result['precision'],'limits':'Actual compiled Uzi input and contacts, original three-resident scene; not physical OS input or whole-city FPS acceptance. Synthetic bent/skinned geometry reproduces prior120mm defect. Weapon spread, proxy grazing rules, HP and ragdoll physics unchanged. Buildings and physical corpse blocking remain pending.'})
print(json.dumps({'promoted':len(scope),'preserved':len(preserved),'pack':pack,'export':str(dest)},ensure_ascii=False))
