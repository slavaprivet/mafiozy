"""Create scoped lifecycle changes from the immutable acceptance candidate54.

This script only writes proposal files and diffs, never the shared game.
"""
import difflib,hashlib,json,pathlib
OUT=pathlib.Path(__file__).resolve().parent
BASE=OUT.parents[1]/'game'
POPULATION=OUT.parent/'population30'
changes={}
def donor(rel):return POPULATION/rel if (POPULATION/rel).is_file() else BASE/rel
def take(rel):return donor(rel).read_text(encoding='utf-8')
def replace(text,old,new):
    assert text.count(old)==1,(old[:90],text.count(old))
    return text.replace(old,new,1)
def save(rel,text):
    original=take(rel);path=OUT/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text,encoding='utf-8')
    patch=''.join(difflib.unified_diff(original.splitlines(True),text.splitlines(True),'a/'+rel,'b/'+rel))
    (OUT/(path.stem+'.patch')).write_text(patch,encoding='utf-8')
    baseline=OUT/'baseline'/rel;baseline.parent.mkdir(parents=True,exist_ok=True);baseline.write_bytes(donor(rel).read_bytes())
    changes[rel]={'base_sha256':hashlib.sha256(donor(rel).read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

rel='scripts/hospital/npc_single_lifecycle28.gd';s=take(rel)
s=replace(s,'const ID := "resident_1"','const ID := "resident_1"\nvar source_id30 := ID\nvar _mass_manager30: WeakRef')
start=s.index('\t_population=weakref(population);_scene=weakref(scene);')
end=s.index('\nfunc _pop()',start)
s=s[:start]+'''\treturn configure_resident30(scene,population,packet,trust,health,null)

func configure_resident30(scene: Node3D, population: RefCounted, packet: PackedByteArray, trust: Dictionary, health: RefCounted, manager: Node) -> bool:
\tset_process(false);set_physics_process(false)
\tif _phase!="unbound" or not Simple.enabled() or not is_instance_valid(scene) or population.daily==null or not is_instance_valid(health):return false
\tvar token: Dictionary=health.get("_token")
\tsource_id30=str(token.get("source_id",""))
\tif source_id30.is_empty() or not population.residents.target_current(token) or not population.daily._lives.has(source_id30):return false
\tif manager==null and (source_id30!=ID or population.hit_owners.size()!=1):return false
\t_mass_manager30=weakref(manager) if manager!=null else null
\t_population=weakref(population);_scene=weakref(scene);_packet=packet;_trust=trust.duplicate(true)
\tif manager==null:population.daily._track_single28=true
\t_health=health;_token=token.duplicate();_generation=int(token.life_generation)
\t_spawn=population.residents._records[source_id30].origin
\tfor arg: String in OS.get_cmdline_user_args():
\t\tif arg.begins_with("--city-respawn-seconds="):_corpse_s=clampf(float(arg.trim_prefix("--city-respawn-seconds=")),1.0,30.0)
\tif not population.residents.bind_single_lifecycle28(self) or not health.bind_single_lifecycle28(self):return false
\t_phase="alive"
\treturn true

func _schedule30(seconds: float) -> void:
\tif not is_instance_valid(_timer):
\t\t_timer=Timer.new();_timer.one_shot=true;_timer.process_callback=Timer.TIMER_PROCESS_PHYSICS
\t\tadd_child(_timer);_timer.timeout.connect(_on_timer)
\t_timer.start(seconds)
''' + s[end:]
# The old one-resident configure still validates ID; the runtime uses the bound identity.
start=s.index('\nfunc _pop()')
tail=s[start:].replace('[ID]','[source_id30]').replace('.get(ID)','.get(source_id30)').replace('.has(ID)','.has(source_id30)').replace('.erase(ID)','.erase(source_id30)').replace('Queue.Owner.new(ID,','Queue.Owner.new(source_id30,').replace('_stream_register_daily(ID,','_stream_register_daily(source_id30,').replace('"id":ID','"id":source_id30')
tail=tail.replace('_timer.start(', '_schedule30(')
tail=replace(tail,'\tif _phase=="corpse":\n','''\tvar manager: Node=_mass_manager30.get_ref() if _mass_manager30!=null else null
\tif _mass_manager30!=null:
\t\tif not is_instance_valid(manager):dispose();return
\t\tif not manager.admit_respawn30(self):_schedule30(.06);return
\tif _phase=="corpse":
''')
tail=replace(tail,'\t\t\tif pop.daily._lives.has(source_id30):pop.daily._lives[source_id30].dispose()','\t\t\tif pop.daily.has_method("forget_physical30") and pop.daily._lives.has(source_id30):pop.daily.forget_physical30(source_id30,pop.daily._lives[source_id30])\n\t\t\tif pop.daily._lives.has(source_id30):pop.daily._lives[source_id30].dispose()')
tail=replace(tail,'\t_health=null;_population=null;_scene=null;_packet.clear();_trust.clear();_token.clear()','\t_health=null;_population=null;_scene=null;_mass_manager30=null;_packet=PackedByteArray();_trust.clear();_token.clear()')
s=s[:start]+tail;save(rel,s)

rel='scripts/npc_visual/preview_resident_host.gd';s=take(rel)
s=replace(s,'var _single_lifecycle28: WeakRef','var _single_lifecycle28: WeakRef\nvar _lifecycles30: Dictionary = {}')
s=replace(s,'\tif _single_lifecycle28!=null or not is_instance_valid(owner) or not owner.is_inside_tree()', '\tif not is_instance_valid(owner) or not owner.is_inside_tree()')
s=replace(s,'\t_single_lifecycle28=weakref(owner)\n\treturn true','''\tvar id: String=str(owner.get("source_id30"))
\tif not _records.has(id) or _lifecycles30.has(id):return false
\t_lifecycles30[id]=weakref(owner)
\tif owner.get("_mass_manager30")==null:_single_lifecycle28=weakref(owner)
\treturn true''')
s=replace(s,'\treturn not _disposed and not _dispose_requested and _scene_alive() and _single_lifecycle28!=null and is_instance_valid(owner) and _single_lifecycle28.get_ref()==owner','''\tif _disposed or _dispose_requested or not _scene_alive() or not is_instance_valid(owner):return false
\tvar reference: WeakRef=_lifecycles30.get(str(owner.get("source_id30")))
\treturn reference!=null and reference.get_ref()==owner''')
start=s.index('\nfunc stop_single_dead28');end=s.index('\nfunc _living',start)
block=s[start:end].replace('token.get("source_id")!="resident_1"','token.get("source_id")!=owner.get("source_id30")')
block=block.replace('"resident_1"','str(owner.get("source_id30"))')
block=block.replace('_single_respawn28_shape','old["respawn_shape30"]').replace('_single_respawn28_local','old["respawn_local30"]')
block=replace(block,'\tvar body: CharacterBody3D=old.body\n','\told["respawn_shape30"]=null;old["respawn_local30"]=Transform3D.IDENTITY\n\tvar body: CharacterBody3D=old.body\n')
block=replace(block,'"single_respawn28_floor_y":point.y}', '"single_respawn28_floor_y":point.y,"respawn_shape30":old["respawn_shape30"],"respawn_local30":old["respawn_local30"]}')
block=replace(block,'\t_leave_busy()\n\treturn result\n','\t_leave_busy()\n\tif result.get("status")=="IDLE":record.erase("single_successor28")\n\treturn result\n')
s=s[:start]+block+s[end:]
s=replace(s,'\t_active30.clear();_active_rows30.clear();_active_dirty30=false','\t_active30.clear();_active_rows30.clear();_active_dirty30=false\n\t_lifecycles30.clear();_single_lifecycle28=null')
s=replace(s,'\tif not body is CharacterBody3D or not is_instance_valid(body): return false','\tif not is_instance_valid(body) or not body is CharacterBody3D: return false')
s=replace(s,'\tbody.set_meta("dsh_test_resident_name", _dsh_tr_name)\n','\tbody.set_meta("dsh_test_resident_name", _dsh_tr_name)\n\t# The historical single-resident inspection spawn must never relocate a\n\t# labelled population or overwrite a freshly validated respawn location.\n\tif not OS.get_cmdline_user_args().has("--city-qa=1") or record.get("single_respawn28",false):return\n')
save(rel,s)

rel='scripts/npc_visual/npc_local_preview_hit_owner.gd';s=take(rel)
s=replace(s,'\tif _token.get("source_id")!="resident_1" or not _host.single_lifecycle28_current(owner)','\tif _token.get("source_id")!=owner.get("source_id30") or not _host.single_lifecycle28_current(owner)');save(rel,s)

rel='scripts/npc_city_daily.gd';s=take(rel)
s=replace(s,'\tif id!="resident_1" or _health.get(id)!=health or not _lives.has(id):return false','\tif id!=str(owner.get("source_id30")) or _health.get(id)!=health or not _lives.has(id):return false')
save(rel,s)

rel='scripts/city/runtime/npc_city_world_policy.gd';s=take(rel)
s=replace(s,'var _respawn28_owner: WeakRef','var _respawn28_owner: WeakRef\nvar _respawn_owners30: Dictionary = {}')
start=s.index('\nfunc replace_single_dead_owner28');end=s.index('\nfunc _owner_allowed',start)
block=s[start:end];block=block.replace('\n\tif _disposed','\n\tvar id: String=str(lifecycle.get("source_id30"))\n\tif _disposed',1).replace('"resident_1"','id')
block=block.replace('_respawn28_owner=weakref(successor)','_respawn_owners30[id]=weakref(successor)')
s=s[:start]+block+s[end:]
s=replace(s,'\tif generation!=1 and (id!="resident_1" or _respawn28_owner==null or _respawn28_owner.get_ref()!=owner):return false','\tif generation!=1 and (not _respawn_owners30.has(id) or _respawn_owners30[id].get_ref()!=owner):return false');save(rel,s)

rel='scripts/npc_city_population.gd';s=take(rel)
s=replace(s,'var _single_lifecycle28: Node','var _single_lifecycle28: Node\nconst MultiLife30=preload("res://scripts/hospital/npc_population_lifecycle30.gd")\nvar _multi_lifecycle30: Node')
old='\t(health as Dictionary)[id]=owner\n\treturn true'
new='\t(health as Dictionary)[id]=owner\n\tif daily.has_method("wake_physical30"):daily.call("wake_physical30",id)\n\tif is_instance_valid(_multi_lifecycle30) and not _multi_lifecycle30.bind_health30(owner):return false\n\treturn true'
s=replace(s,old,new)
s=replace(s,'\tif not _configure_daily(scene, sites, true): return false','\tif not _configure_daily(scene, sites, true): return false\n\tif MultiLife30.enabled30() and not _configure_multi_lifecycle30(scene,packet,trust):return false')
s=replace(s,'\tif SingleLifecycle28.enabled() and qa_source_ids==["resident_1"]:','\tif MultiLife30.enabled30():\n\t\tif not _configure_multi_lifecycle30(scene,packet,trust):return false\n\telif SingleLifecycle28.enabled() and qa_source_ids==["resident_1"]:')
s=replace(s,'hit_owners.duplicate() if _single_lifecycle28!=null else hit_owners','hit_owners.duplicate() if _single_lifecycle28!=null or _multi_lifecycle30!=null else hit_owners')
s=replace(s,'\tif is_instance_valid(_single_lifecycle28):_single_lifecycle28.dispose();_single_lifecycle28=null','\tif is_instance_valid(_multi_lifecycle30):_multi_lifecycle30.dispose();_multi_lifecycle30=null\n\tif is_instance_valid(_single_lifecycle28):_single_lifecycle28.dispose();_single_lifecycle28=null')
s+='''
func _configure_multi_lifecycle30(scene: Node3D, packet: PackedByteArray, trust: Dictionary) -> bool:
\tif is_instance_valid(_multi_lifecycle30):return true
\t_multi_lifecycle30=MultiLife30.new();scene.add_child(_multi_lifecycle30)
\tif not _multi_lifecycle30.configure30(scene,self,packet,trust):return _fail("multi_lifecycle30_configure")
\treturn true
'''
save(rel,s)
(OUT/'BASE30.json').write_text(json.dumps(changes,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'changed_files':len(changes),'shared_game_modified':False,'native_verified':False}))
