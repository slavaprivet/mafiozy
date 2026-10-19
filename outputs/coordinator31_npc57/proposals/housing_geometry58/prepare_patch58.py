"""Build a reviewable home geometry/main proposal without touching the candidate."""
from pathlib import Path
import hashlib,json,shutil
HERE=Path(__file__).resolve().parent
GAME=HERE.parents[1]/'game'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
def replace_once(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new)
text=(GAME/'scripts/main.gd').read_text(encoding='utf-8-sig')
text=replace_once(text,'var preview_service_sites29: Node\n','var preview_service_sites29: Node\nvar preview_homes58: Node\n')
old='\tif OS.get_cmdline_user_args().has("--city-venue-staff29=1"):\n'
new='''	if city_block_mode and city_town_active():
		preview_homes58 = load("res://scripts/homes/npc_home_host58.gd").new()
		preview_homes58.name = "ResidentHomes58"
		add_child(preview_homes58)
		var homes_result58: Dictionary = await preview_homes58.prepare(self, _block)
		print("HOME58_GEOMETRY ", homes_result58)
		if not homes_result58.get("ok", false):
			push_error("Residential geometry failed: " + str(homes_result58)); return
'''+old
text=replace_once(text,old,new)
old='\tif is_instance_valid(preview_service_sites29):\n\t\tprint("VENUE_SITES29_NATIVE_BINDING ", preview_service_sites29.bind_weapons())\n'
new=old+'''	if is_instance_valid(preview_homes58):
		var homes_binding58: Dictionary = preview_homes58.bind_weapons()
		print("HOME58_NATIVE_BINDING ", homes_binding58)
		if not homes_binding58.get("ok", false):
			push_error("Residential damage binding failed: " + str(homes_binding58)); return
'''
text=replace_once(text,old,new)
old='\tif is_instance_valid(preview_service_sites29): sites.append_array(preview_service_sites29.current_sites())\n'
text=replace_once(text,old,old+'\tif is_instance_valid(preview_homes58): sites.append_array(preview_homes58.current_sites())\n')
old='\tif is_instance_valid(preview_service_sites29): preview_service_sites29.dispose()\n'
text=replace_once(text,old,'\tif is_instance_valid(preview_homes58): preview_homes58.dispose()\n'+old)
p=HERE/'files/scripts/main.gd';p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8')
glazing='scripts/venues/npc_compact_glazing29.gd'
text=(GAME/glazing).read_text(encoding='utf-8-sig')
text=replace_once(text,'const MAX_HELPERS := 8','const MAX_HELPERS := 12 # Eight service sites plus four shared residential houses.')
text=replace_once(text,'# Separate compact-owner registry: eight sites, at most64 shard slots.','# Shared compact-owner registry: twelve sites, at most96 shard slots.')
p=HERE/'files'/glazing;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8')
manifest={}
for src in sorted((HERE/'files').rglob('*')):
    if not src.is_file():continue
    rel=src.relative_to(HERE/'files').as_posix(); dst=HERE/'patch'/rel
    dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    manifest[rel]={'base_sha256':sha(GAME/rel),'candidate_sha256':sha(dst)}
(HERE/'PATCH.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'paths':list(manifest),'production_edited':False}))
