"""Freeze a minimal F/Escape return fix from accepted cargo24a."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[2]
base=root/'outputs/coordinator24_quality/candidate20'
game0=base/'godot/mafiozi_walk'
stage=root/'outputs/coordinator24_quality/candidate22'
game=stage/'godot/mafiozi_walk'
sha=lambda data:hashlib.sha256(data).hexdigest()
receipt_path=game0/'exports/win64/s01-20260930-quality24a/build_receipt.json'
assert sha(receipt_path.read_bytes())=='ce19b634175f77890b9e8de86675d10352316c09cb8bd81640799b9de7248e07'
receipt=json.loads(receipt_path.read_text(encoding='utf-8-sig'))
assert not stage.exists()
source={}
for row in receipt['inputs']:
    data=(game0/row['path']).read_bytes()
    assert sha(data)==row['sha256'] and len(data)==row['bytes']
    source[row['path']]=data
changes={}
def replace(name,before,after):
    assert source[name].count(before)==1,name
    old=source[name];source[name]=old.replace(before,after)
    changes[name]={'before':sha(old),'after':sha(source[name])}
replace('scripts/weapons/preview_weapon_cargo.gd',
    b'elif code==KEY_ESCAPE:close_window(false);weapons.player.set_mouse_captured(false)',
    b'elif code==KEY_ESCAPE:close_window()')
replace('scripts/main.gd',b'const PREVIEW_RUNTIME_REVISION := "s01-20260930-quality24a"',
    b'const PREVIEW_RUNTIME_REVISION := "s01-20260930-quality24b"')
name='data/preview_updates.json';old=source[name];notes=json.loads(old)
notes.update(title='30.09 · Esc из багажника · 24b',runtime_revision='s01-20260930-quality24b',updated_at='2026-09-30T17:40:00+03:00')
notes['items'][2]='Esc, Q или × закрывает содержимое багажника и сразу возвращает управление. Esc вне окна освобождает мышь. В окне также есть кнопка «Закрыть крышку».'
source[name]=(json.dumps(notes,ensure_ascii=False,indent=2)+'\n').encode('utf8')
changes[name]={'before':sha(old),'after':sha(source[name])}
for name,data in source.items():
    target=game/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
for name,key in [('docs/godot/ENGINE_LOCK.json','engineLockSha256'),('tools/godot/export_preview.ps1','exportScriptSha256')]:
    data=(base/name).read_bytes();assert sha(data)==receipt[key]
    target=stage/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
manifest={'status':'FROZEN22_ESCAPE_FIX_ACCEPTANCE_PENDING','base_accepted':'candidate20/cargo24a',
 'parent_pack_sha256':'634b9d3b48e4502538331da9b9e9efdb1641cfc83f04c40c65bd592bd4db7dd5',
 'changes':changes,'scope':'Explicit user request F contents then Escape returns focused gameplay without another click; normal gameplay Escape and real focus loss unchanged; NPC21 work remains isolated.'}
(stage/'INTEGRATION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'inputs':len(source),'changes':changes}))
