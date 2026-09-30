"""Freeze cargo-only24a from the exact accepted23h source receipt."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[2]
base=root/'outputs/coordinator23_quality/candidate16'
game0=base/'godot/mafiozi_walk'
dest=root/'outputs/coordinator24_quality/candidate20'
game=dest/'godot/mafiozi_walk'
sha=lambda b:hashlib.sha256(b).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
receipt_path=game0/'exports/win64/s01-20260930-quality23h/build_receipt.json'
assert sha(receipt_path.read_bytes())=='9e18c421b15422b667f3787b2fcc263a5ebd427402589a5c219ef107023e9472'
receipt=load(receipt_path)
assert not dest.exists()
source={}
for row in receipt['inputs']:
    name=row['path'];assert '..' not in Path(name).parts and not Path(name).is_absolute()
    data=(game0/name).read_bytes();assert sha(data)==row['sha256'] and len(data)==row['bytes'],name
    source[name]=data
assert len(source)==209
changes={}
def change(name,data,reason):
    before=source[name]
    assert before!=data,name
    changes[name]={'before':sha(before),'after':sha(data),'source':reason}
    source[name]=data
cargo='scripts/weapons/preview_weapon_cargo.gd'
movement=(root/'outputs/coordinator24_cargo_input/files'/cargo).read_bytes()
assert sha(movement)=='e647d6cf902097ef4b9e4c8eb993cc95c6e8b1fb1b42ab4fb8c17aefe556359b'
race=root/'outputs/coordinator24_cargo_aim_race/stage/godot/mafiozi_walk'
if not race.exists():race=root/'outputs/coordinator24_cargo_aim_race/stage'
weapons='scripts/weapons/preview_weapons.gd'
weapon_data=(race/weapons).read_bytes()
assert sha(weapon_data)=='48998eb4207d40ff3bf6c91ba19aa026f145c7bc083bd13a743b071044b1e97c'
text=movement.decode('utf8')
old='\t# or ownership changes. A later cancellation must not restore an old weapon.\n\tweapons.cancel_inputs()'
new='\t# or ownership changes. A later cancellation must not restore an old weapon.\n\t# Keep the displayed aim ray stable through the paired ownership checks.\n\t# The successful transfer resets the view only after committing this UID.\n\tweapons.cancel_inputs(false)'
if '\r\n' in text:old=old.replace('\n','\r\n');new=new.replace('\n','\r\n')
assert text.count(old)==1
change(cargo,text.replace(old,new).encode('utf8'),'Root24 compose proven held-movement return and stable pre-take aim; accepted16 base')
change(weapons,weapon_data,'Proven attached-RMB single-E transaction; default cancellation behavior preserved')
main='scripts/main.gd'
old=b'const PREVIEW_RUNTIME_REVISION := "s01-20260930-quality23h"'
new=b'const PREVIEW_RUNTIME_REVISION := "s01-20260930-quality24a"'
assert source[main].count(old)==1
change(main,source[main].replace(old,new),'Root24 truthful delivered cargo revision')
notes_name='data/preview_updates.json';notes=json.loads(source[notes_name])
notes.update(title='30.09 · Управление багажником · 24a',updated_at='2026-09-30T17:05:00+03:00',runtime_revision='s01-20260930-quality24a')
notes['items'][0]='E берёт подсвеченное оружие из багажника, в том числе во время прицеливания. Без выбранного оружия E открывает или закрывает крышку.'
notes['items'][1]='F — содержимое багажника. Карточка + E или «Взять» — в руки. Удерживаемая W/A/S/D продолжает движение после взятия; G — положить оружие.'
change(notes_name,(json.dumps(notes,ensure_ascii=False,indent=2)+'\n').encode('utf8'),'Only delivered cargo actions; RPG still without blast damage')
for name,data in source.items():
    p=game/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
for name,pin in [('docs/godot/ENGINE_LOCK.json','engineLockSha256'),('tools/godot/export_preview.ps1','exportScriptSha256')]:
    data=(base/name).read_bytes();assert sha(data)==receipt[pin]
    p=dest/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
for row in receipt['inputs']:assert sha((game0/row['path']).read_bytes())==row['sha256']
manifest={'status':'FROZEN20 cargo-only24a; combined compiled/rendered acceptance pending','base_accepted':'candidate16','parent_pack_sha256':'8051926d109704cb4f85eb46cd2af8dd5b9a84d9cc4e71480db22b699dce7741','changes':changes,'scope':'Two proved cargo defects; no RPG19 adoption, no focus-policy change, no claim all intermittent user freeze causes resolved.'}
(dest/'INTEGRATION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
(dest/'SOURCE.json').write_text(json.dumps({'inputs':[{'path':n,'sha256':sha(d),'bytes':len(d)} for n,d in source.items()]},indent=2)+'\n',encoding='utf8')
print(json.dumps({'stage':dest.relative_to(root).as_posix(),'source_inputs':len(source),'changes':changes},ensure_ascii=True))
