from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2]
base=root/'outputs/coordinator23_quality/candidate09'
target=root/'outputs/coordinator23_quality/candidate10'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
cargo=root/'outputs/coordinator23_trunk_window'
receipt=json.loads((cargo/'RECEIPT.json').read_text(encoding='utf8'))
assert not target.exists()
for path,row in receipt['changes'].items():
    assert sha(base/'godot/mafiozi_walk'/path)==row['before'],path
    assert sha(cargo/'files'/path)==row['after'],path
mark='scripts/npc_visual/npc_bullet_marks.gd'
art=root/'outputs/coordinator23_marks_fix10/files'/mark
assert sha(base/'godot/mafiozi_walk'/mark)=='3235343d64754b5a2711ec43f49d9c992112e0b7ba852937903ea6d17db399b6'
assert sha(art)=='14d769365d98603f2997ce2cf6dce40500a2a22198305fc3d15a8b7c2388c9e9'
shutil.copytree(base,target,ignore=shutil.ignore_patterns('exports'))
project=target/'godot/mafiozi_walk'
manifest=json.loads((target/'INTEGRATION.json').read_text(encoding='utf8'))
for path,row in receipt['changes'].items():
    shutil.copyfile(cargo/'files'/path,project/path)
    original=manifest['changes'].get(path,{}).get('before',row['before'])
    manifest['changes'][path]={'before':original,'parent_before':row['before'],'after':row['after'],'source':str((cargo/'files'/path).relative_to(root)),'status':'native143; compiled/rendered pending'}
shutil.copyfile(art,project/mark)
manifest['changes'][mark].update(parent_before='3235343d64754b5a2711ec43f49d9c992112e0b7ba852937903ea6d17db399b6',after=sha(art),source=str(art.relative_to(root)),status='art only; exposed face21PASS; no skin-filter changes')
main=project/'scripts/main.gd'
text=main.read_text(encoding='utf8');assert text.count('s01-20260930-quality23f')==1
main.write_text(text.replace('s01-20260930-quality23f','s01-20260930-quality23g'),encoding='utf8',newline='\n')
notes=project/'data/preview_updates.json'
value=json.loads(notes.read_text(encoding='utf8'))
value.update(title='30.09 · Окно багажника · 23g',runtime_revision='s01-20260930-quality23g',updated_at='2026-09-30T12:15:00+03:00')
value['items'][0]='У открытого багажника нажмите E: крупные карточки оружия, патроны и кнопка «Взять». Наводиться на маленькую модель не нужно.'
value['items'][1]='В окне багажника: «Положить» или G — убрать оружие из рук. Показаны занятое и свободное место. E/Q — закрыть окно.'
value['items'][2]='Q вне багажника — арсенал. ЛКМ — выстрел, ПКМ — прицел, R — перезарядка. Вдали от машины G/E — бросить/подобрать.'
value['items'][3]='Есть следы на одежде и коже. Попадание в голову смертельно; тело получает импульс пули и сдвигается от шага игрока.'
notes.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
preset=project/'export_presets.cfg'
text=preset.read_text(encoding='utf8');resource='res://scripts/weapons/walk_trunk_window.gd';assert resource not in text
preset.write_text(text.replace('export_files=PackedStringArray(','export_files=PackedStringArray("'+resource+'", '),encoding='utf8',newline='\n')
for path in ['scripts/main.gd','export_presets.cfg','data/preview_updates.json']:manifest['changes'][path]['after']=sha(project/path)
manifest.update(parent='candidate09',status='ISOLATED23g trunk window + polished marks; compiled/visual acceptance pending',runtime_revision=value['runtime_revision'])
(target/'INTEGRATION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Guarded23g candidate10 created without changing shared files')
