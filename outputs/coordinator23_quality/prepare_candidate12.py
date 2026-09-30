"""Guarded cargo/return/cursor candidate; no RPG damage changes or shared writes."""
from pathlib import Path
import hashlib, json, shutil
root=Path(__file__).resolve().parents[2]
base=root/'outputs/coordinator23_quality/candidate11'
target=root/'outputs/coordinator23_quality/candidate12'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
assert not target.exists()
shutil.copytree(base,target,ignore=shutil.ignore_patterns('exports','.godot'))
game=target/'godot/mafiozi_walk'
changes={}
def save(name,data,source):
    p=game/name;p.parent.mkdir(parents=True,exist_ok=True)
    before=sha(base/'godot/mafiozi_walk'/name)
    p.write_bytes(data)
    changes[name]={'before':before,'after':sha(p),'source':source}
for package in ['coordinator23_cargo_controls13','coordinator23_cargo_hover12']:
    proposal=root/'outputs'/package
    receipt=json.loads((proposal/'RECEIPT.json').read_text(encoding='utf-8-sig'))
    rows=receipt['files']
    if isinstance(rows,dict):rows=[dict(path=k,**v) for k,v in rows.items()]
    for row in rows:
        name=row['path'];p=proposal/'files'/name
        assert sha(game/name)==row['before_sha256'],name
        assert sha(p)==row['after_sha256'],name
        save(name,p.read_bytes(),str(p.relative_to(root)))
for p in (root/'outputs/coordinator23_cursor12/files').rglob('*'):
    if p.is_file():save(p.relative_to(root/'outputs/coordinator23_cursor12/files').as_posix(),p.read_bytes(),str(p.relative_to(root)))
name='scripts/main.gd';s=(game/name).read_text(encoding='utf8')
s=s.replace('const PlayerController =','const GameCursor = preload("res://scripts/ui/walk_cursor.gd")\nconst PlayerController =',1)
s=s.replace('func _ready() -> void:\n','func _ready() -> void:\n\tGameCursor.install()\n',1).replace('s01-20260930-quality23g','s01-20260930-quality23h')
save(name,s.encode('utf8'),'root cursor installation and revision')
name='scripts/weapons/walk_weapon_ui.gd';s=(game/name).read_text(encoding='utf8')
for variable in ['launcher','close','choice']:
    s=s.replace(variable+' = Button.new();',variable+' = Button.new(); '+variable+'.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND;',1)
    s=s.replace(variable+' := Button.new();',variable+' := Button.new(); '+variable+'.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND;',1)
save(name,s.encode('utf8'),'root pointer-hand controls')
name='export_presets.cfg';s=(game/name).read_text(encoding='utf8')
s=s.replace('export_files=PackedStringArray(','export_files=PackedStringArray("res://scripts/ui/walk_cursor.gd", "res://assets/ui/cursor_arrow.svg", "res://assets/ui/cursor_hand.svg", ',1)
save(name,s.encode('utf8'),'root cursor export inclusion')
notes={
 'title':'30.09 · Удобный багажник · 23h',
 'items':[
  'Наведите камеру на оружие в открытом багажнике: оно подсвечивается, E — взять. Без наведения на оружие E открывает или закрывает крышку.',
  'F — содержимое багажника. Наведите мышь на карточку и нажмите E или «Взять»: управление вернётся сразу. G — положить оружие.',
  'Q или × закрывает окно и возвращает в игру; Esc освобождает мышь. В окне также есть кнопка «Закрыть багажник».',
  'Q — арсенал. ЛКМ — выстрел, ПКМ — прицел, R — перезарядка. Вдали от машины G/E — бросить/подобрать. C/Z — присесть/лечь.',
  'Три жителя тестового квартала, следы попаданий и физика тел доступны. РПГ пока без урона взрывом.'
 ],'updated_at':'2026-09-30T13:00:00+03:00','runtime_revision':'s01-20260930-quality23h'}
save('data/preview_updates.json',(json.dumps(notes,ensure_ascii=False,indent=2)+'\n').encode('utf8'),'root actual controls')
(target/'INTEGRATION.json').write_text(json.dumps({'parent':'candidate11','status':'ISOLATED23h cargo/cursor acceptance pending','changes':changes},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Guarded candidate12 created',len(changes))
