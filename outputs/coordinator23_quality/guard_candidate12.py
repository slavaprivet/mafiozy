from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[2]
stage=root/'outputs/coordinator23_quality/candidate12'
game=stage/'godot/mafiozi_walk'
manifest=json.loads((stage/'INTEGRATION.json').read_text(encoding='utf8'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
name='scripts/weapons/preview_weapons.gd';p=game/name
before=sha(p);assert before=='cdf590013e5808a32b529fd75f3cd42c03f9dc6c3526560dc01e36f6f7c51c38'
s=p.read_text(encoding='utf8');old='\t\tif cargo_menu_active(): cargo_menu_owner.close_window(false)'
assert s.count(old)==1
s=s.replace(old,'\t\tif cargo_menu_active():\n\t\t\tcargo_menu_owner.close_window(false)\n\t\t\tplayer.set_mouse_captured(false)')
p.write_text(s,encoding='utf8',newline='')
manifest['changes'][name]={'before':before,'after':sha(p),'source':'independent scheduled pose invalidation before/after18 PASS patch'}
name='scripts/weapons/preview_weapon_cargo.gd';p=game/name
assert sha(p)=='7a2e75fd95c53a056eb89db6c8c468cd907291c1cfc4097514bb11fbd157ec84'
s=p.read_text(encoding='utf8').replace('# not steal the desktop cursor; logical gameplay is already active there.','# not steal the desktop cursor; losing focus also suspends logical controls.')
old='if DisplayServer.get_name()=="headless" or get_window().has_focus():weapons.player.set_mouse_captured(true)'
assert s.count(old)==1
s=s.replace(old,old+'\n\telse:weapons.player.set_mouse_captured(false)')
p.write_text(s,encoding='utf8',newline='')
manifest['changes'][name]['after']=sha(p)
manifest['changes'][name]['additional_guard']='explicit no-focus suspension; headless/focused return unchanged'
(stage/'INTEGRATION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Candidate12 invalidation guards applied',[(n,manifest['changes'][n]['after']) for n in ['scripts/weapons/preview_weapons.gd',name]])
