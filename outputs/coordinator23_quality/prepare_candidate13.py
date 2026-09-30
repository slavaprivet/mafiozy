"""Correct native focus admission and cursor texture lifetime after rendered12 failure."""
from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];base=root/'outputs/coordinator23_quality/candidate12';target=root/'outputs/coordinator23_quality/candidate13'
assert not target.exists()
shutil.copytree(base,target,ignore=shutil.ignore_patterns('exports'))
game=target/'godot/mafiozi_walk';manifest=json.loads((target/'INTEGRATION.json').read_text(encoding='utf8'))
name='scripts/weapons/preview_weapon_cargo.gd';p=game/name;s=p.read_bytes()
old=b'if DisplayServer.get_name()=="headless" or get_window().has_focus():weapons.player.set_mouse_captured(true)'
assert s.count(old)==1
p.write_bytes(s.replace(old,b'if DisplayServer.get_name()=="headless" or (get_window().has_focus() and not get_window().unfocusable):weapons.player.set_mouse_captured(true)'))
manifest['changes'][name]['after']=hashlib.sha256(p.read_bytes()).hexdigest()
manifest['changes'][name]['additional_guard']='Explicit unfocusable flag: native Windows has_focus may remain cached true in a NO_FOCUS test window. Normal focused gameplay resumes; else suspend both controls.'
name='scripts/ui/walk_cursor.gd';p=game/name
p.write_text('''extends RefCounted
## Hardware cursors installed once; no per-frame drawing or retained GPU textures.
static func install() -> void:
\tif DisplayServer.get_name() == "headless": return
\tvar arrow: Texture2D = load("res://assets/ui/cursor_arrow.svg")
\tvar hand: Texture2D = load("res://assets/ui/cursor_hand.svg")
\tInput.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, Vector2(5, 3))
\tInput.set_custom_mouse_cursor(hand, Input.CURSOR_POINTING_HAND, Vector2(16, 3))
''',encoding='utf8',newline='')
manifest['changes'][name]['after']=hashlib.sha256(p.read_bytes()).hexdigest()
manifest['changes'][name]['source']='root local texture installation; removes static GPU resource lifetime on exit'
manifest.update(parent='candidate12',status='FROZEN23h13; fixes rendered12 focus guard and cursor lifetime; acceptance pending')
(target/'INTEGRATION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('candidate13 prepared; candidate12 failure preserved')
