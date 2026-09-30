from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];base=root/'outputs/coordinator23_quality/candidate14';target=root/'outputs/coordinator23_quality/candidate15'
assert not target.exists();shutil.copytree(base,target,ignore=shutil.ignore_patterns('exports'))
game=target/'godot/mafiozi_walk';manifest=json.loads((target/'INTEGRATION.json').read_text(encoding='utf8'))
name='scripts/ui/walk_cursor.gd';p=game/name
s=p.read_text(encoding='utf8')+'''\nstatic func release() -> void:
\tif DisplayServer.get_name() == "headless": return
\t# Input owns cursor textures. Release them before RenderingServer shuts down.
\tInput.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
\tInput.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
'''
p.write_text(s,encoding='utf8',newline='');manifest['changes'][name]['after']=hashlib.sha256(p.read_bytes()).hexdigest()
name='scripts/main.gd';p=game/name;s=p.read_text(encoding='utf8')
if 'func _exit_tree() -> void:\n' in s:s=s.replace('func _exit_tree() -> void:\n','func _exit_tree() -> void:\n\tGameCursor.release()\n',1)
else:s+='\nfunc _exit_tree() -> void:\n\tGameCursor.release()\n'
p.write_text(s,encoding='utf8',newline='');manifest['changes'][name]['after']=hashlib.sha256(p.read_bytes()).hexdigest()
manifest.update(parent='candidate14',status='FROZEN23h15; release native cursor texture ownership on main exit; acceptance pending')
(target/'INTEGRATION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Candidate15 cursor shutdown ownership fixed')
