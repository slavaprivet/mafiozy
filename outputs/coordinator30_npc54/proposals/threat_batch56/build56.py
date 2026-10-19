"""Adapt the proven threat30 city observer for the authorized ten-resident trial."""
from pathlib import Path
HERE=Path(__file__).resolve().parent
old=HERE.parent/'threat30'
s=(old/'observer_city30.gd').read_text(encoding='utf-8-sig')
s=s.replace('var _world30: RefCounted','const Physical56=preload("res://scripts/hospital/npc_physical_route51.gd")\nvar _composition56: Dictionary={}\nvar _player_setup56: Array[Dictionary]=[]\nvar _hit_origin56:=Vector3.ZERO\nvar _hit_distance56:=0.0\nvar _normal_speed56:=0.0\nvar _target_id56:=""\nvar _world30: RefCounted')
s=s.replace('if _pop==null or not _pop.city_ready or _pop.daily==null:return false','if _pop==null or not _pop.city_ready or not _pop.city_stream_complete() or _pop.daily==null:return false')
s=s.replace('if _pop.hit_owners.size()!=1:_finish("one_resident_contract");return false','if _pop.hit_owners.size()!=10 or _pop.daily._lives.size()!=10:_finish("ten_resident_contract");return false')
s=s.replace('_life=_pop.daily._lives.get("resident_1");_health=_pop.hit_owners[0]','_life=_pop.daily._lives.get("resident_1");_health=_pop.daily._health.get("resident_1")')
s=s.replace('if _life==null or _health._token.source_id!="resident_1"','if _life==null or _health==null or _health._token.source_id!="resident_1"')
anchor='\t_camera=_player.get_preview_camera();_player.set_mouse_captured(true)'
replacement='''\tvar staff: Node=scene.get("preview_venue_staff29")
\tvar sites: Node=scene.get("preview_service_sites29")
\tvar staff_count:=0
\tif is_instance_valid(staff):
\t\tfor staff_row: Dictionary in staff._rows.values():
\t\t\tif is_instance_valid(staff_row.actor) and staff_row.actor.is_inside_tree():staff_count+=1
\tif staff_count!=12 or not is_instance_valid(sites):return false
\tvar wanted: Array[String]=[]
\tvar packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc_city/session_packet.json"))
\tfor row: Dictionary in packet.rows:
\t\tif wanted.size()>=10:break
\t\twanted.append(str(row.source_id))
\twanted.sort()
\tvar actual: Array=_pop.daily._lives.keys();actual.sort()
\tif actual!=wanted or int(sites.report.get("built",0))!=8:_finish("original_roster_or_venues_missing");return false
\t_composition56={"ids":actual,"staff":staff_count,"new_sites":int(sites.report.built)}
\t_target_id56=str(_health._token.source_id)
\t_camera=_player.get_preview_camera();_player.set_mouse_captured(true)
\tif not _place_player56("initial_visibility"):_finish("qa_player_supported_view_unavailable");return false'''
assert s.count(anchor)==1;s=s.replace(anchor,replacement)
s=s.replace('_phase_at30+180000','_phase_at30+240000')
anchor='func _aim_offset30(offset: Vector3) -> bool:'
helper='''func _place_player56(stage: String) -> bool:
\t# Only the QA player is positioned; residents, their paths and HP are untouched.
\tvar probe:=Physical56.new()
\tif not probe.configure(_player):return false
\tvar before: Vector3=_player.global_position
\tvar forward: Vector3=-_body.global_basis.z;forward.y=0.0;forward=forward.normalized()
\tfor radius: float in [6.0,8.0,10.0]:
\t\tfor angle: float in [0.0,.3,-.3,.6,-.6,.9,-.9]:
\t\t\tvar direction: Vector3=forward.rotated(Vector3.UP,angle)
\t\t\tvar at: Vector3=_body.global_position+direction*radius
\t\t\tvar floor: Variant=probe.floor_at(at,_body.global_position.y)
\t\t\tif not floor is Vector3 or not probe.standing(floor):continue
\t\t\tvar ray:=PhysicsRayQueryParameters3D.create(floor+Vector3.UP*1.45,_body.global_position+Vector3.UP*1.05,0xffffffff,[_player.get_rid()])
\t\t\tvar hit: Dictionary=_player.get_world_3d().direct_space_state.intersect_ray(ray)
\t\t\tif hit.is_empty() or not _health._owns_collider(hit.get("collider")):continue
\t\t\t_player.set_preview_pose_authority(&"on_foot",true);_player.global_position=floor
\t\t\t_player_setup56.append({"stage":stage,"from":str(before),"to":str(floor),"native_floor_capsule_los":true,"frame":Engine.get_physics_frames()})
\t\t\treturn true
\treturn false

'''
s=s.replace(anchor,helper+anchor)
anchor='\tif bool(_health._row.get("dead",false)):_finish("unexpected_death");return'
s=s.replace(anchor,anchor+'\n\tif _pop.hit_owners.size()!=10 or _pop.daily._lives.size()!=10 or _pop.daily._lives.get(_target_id56)!=_life or _life._token.body!=_body:_finish("batch_or_target_identity_changed");return')
s=s.replace('\t_last_pos30=_body.global_position','\tif _phase=="post_hit_quiet":_hit_distance56+=_body.global_position.distance_to(_last_pos30)\n\tif _phase=="post_hit_ordinary":_normal_speed56=maxf(_normal_speed56,Vector2(_body.global_position.x-_last_pos30.x,_body.global_position.z-_last_pos30.z).length()/delta)\n\t_last_pos30=_body.global_position')
anchor='\t\t\t_weapons.equip("tt_pistol");_phase="actual_hit";_phase_at30=now;_stable=0'
s=s.replace(anchor,'\t\t\tif not _place_player56("actual_hit"):_finish("qa_player_hit_view_unavailable");return\n'+anchor)
anchor='\t\t\t_finish("complete");return\n\t\tif now-_phase_at30>15000:'
replacement='''\t\t\t_checks.actual_hp_36=float(_health._row.hp)==36.0
\t\t\t_hit_origin56=_body.global_position;_hit_distance56=0.0
\t\t\t_weapons.equip("none");_phase="post_hit_quiet";_phase_at30=now
\t\tif now-_phase_at30>15000:'''
assert s.count(anchor)==1;s=s.replace(anchor,replacement)
anchor='\tif now-_last_log>=500:'
extra='''\telif _phase=="post_hit_quiet":
\t\t_torso_aim(true)
\t\tif threat!=null and not threat.active():
\t\t\t_checks.hit_quiet_15_released=_world30._now>=_quiet30 and threat._reason=="quiet_15_seconds"
\t\t\t_checks.hit_physical_flee=_hit_distance56>=1.0 and _body.global_position.distance_to(_hit_origin56)>=.5
\t\t\t_walk_before30=int(_life._completed.walk);_ambient_serial30=-1;_normal_speed56=0.0
\t\t\t_phase="post_hit_ordinary";_phase_at30=now
\telif _phase=="post_hit_ordinary":
\t\t_torso_aim(true)
\t\tvar done: bool=int(_life._completed.walk)>_walk_before30
\t\tif _life._ambient29!=null:
\t\t\tvar ambient: Dictionary=_life._ambient29.snapshot()
\t\t\tif ambient.active:_ambient_serial30=int(ambient.serial)
\t\t\tdone=done or (_ambient_serial30>=0 and int(ambient.serial)==_ambient_serial30 and ambient.reason=="finished" and int(ambient.pose_frames)>=8)
\t\tif done:
\t\t\t_checks.after_hit_ordinary_activity_completed=true
\t\t\t_checks.after_hit_speed_not_accumulated=_normal_speed56<=1.85
\t\t\t_finish("complete");return
'''
s=s.replace(anchor,extra+anchor)
s=s.replace('"synthetic_damage":false','"batch_composition":_composition56,"target_id":_target_id56,"qa_player_positions":_player_setup56,"hit_flee_distance_m":_hit_distance56,"post_hit_normal_max_speed":_normal_speed56,"synthetic_damage":false')
s=s.replace('CITY_THREAT30','CITY_THREAT56')
s=s.replace('var _target_id56:=""','var _target_id56:=""\nvar _actual_revision56:=-1')
s=s.replace('\treturn (-_camera.global_basis.z).angle_to(direction)<.006 and _weapons.presentation.current_muzzle().get("ok",false)', '''\tvar muzzle: Dictionary=_weapons.presentation.current_muzzle()
\tif (-_camera.global_basis.z).angle_to(direction)>=.006 or not muzzle.get("ok",false):return false
\tvar camera_hit: Dictionary=_weapons._projectile_ray({"origin":_camera.global_position,"direction":-_camera.global_basis.z,"range":100.0})
\tif _health._owns_collider(camera_hit.get("collider")):return false
\tvar aim_point: Vector3=camera_hit.get("point",_camera.global_position-_camera.global_basis.z*100.0)
\tvar along: Vector3=(aim_point-muzzle.origin).normalized()
\tvar muzzle_hit: Dictionary=_weapons._projectile_ray({"origin":muzzle.origin,"direction":along,"range":100.0})
\treturn not _health._owns_collider(muzzle_hit.get("collider"))''')
s=s.replace('_aim_offset30(Vector3(2.5,1.05,0))','_aim_offset30((_body.global_position-_camera.global_position).cross(Vector3.UP).normalized()*3.0+Vector3.UP*1.05)')
s=s.replace('if _observed30.has("near_shot"):', 'if _observed30.has("near_shot") and now-_last_fire>=500 and not _terminals.is_empty():')
s=s.replace('_checks.native_near_shot=_shots.size()==1 and float(_health._row.hp)==60.0','_checks.native_near_shot=_shots.size()==1 and float(_health._row.hp)==60.0 and not _terminals.any(func(t:Dictionary)->bool:return t.owned)\n\t\t\tif not _checks.native_near_shot:_finish("expected_native_miss_hit_resident");return')
s=s.replace('\t\t\t_weapons.equip("tt_pistol");_phase="actual_hit";', '\t\t\t_actual_revision56=int(_health.last_result.get("revision",-1))\n\t\t\t_weapons.equip("tt_pistol");_phase="actual_hit";')
s=s.replace('if receipt.get("applied",false) and not receipt.get("hit",{}).is_empty():','if _fired==2 and _shots.size()==2 and int(receipt.get("revision",-1))>_actual_revision56 and receipt.get("applied",false) and not receipt.get("hit",{}).is_empty():')
s=s.replace('t.owned and t.status=="hit" and event_id.ends_with', 't.owned and t.status=="hit" and t.shot_id==_shots[1].shot_id and event_id.ends_with')
(HERE/'observer56.gd').write_text(s,encoding='utf-8')
entry=(old/'entry_city30.gd').read_text(encoding='utf-8-sig').replace('observer_city30.gd','observer56.gd')
(HERE/'entry56.gd').write_text(entry,encoding='utf-8')
print('Prepared actual10 threat observer; no engine run')
