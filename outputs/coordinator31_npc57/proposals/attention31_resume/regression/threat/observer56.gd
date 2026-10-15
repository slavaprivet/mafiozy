extends "../injury30/observer_injury30.gd"
## Genuine viewport input and production daily logic; no NPC teleport/HP/route writes.
const Physical56=preload("res://scripts/hospital/npc_physical_route51.gd")
var _composition56: Dictionary={}
var _player_setup56: Array[Dictionary]=[]
var _hit_origin56:=Vector3.ZERO
var _hit_distance56:=0.0
var _normal_speed56:=0.0
var _target_id56:=""
var _actual_revision56:=-1
var _actual_hp_before56:=0.0
var _ordinary_before56:=0
var _world30: RefCounted
var _phase_at30 := 0
var _origin30 := Vector3.ZERO
var _walk_before30 := 0
var _quiet30 := 0.0
var _phone_frames30 := 0
var _report30: Dictionary={}
var _max_speed30 := 0.0
var _last_pos30 := Vector3.ZERO
var _phone_image30 := false
var _observed30: Dictionary={}
var _ambient_serial30 := -1

func _details31() -> Dictionary:
	var probe:=Physical56.new()
	var configured: bool=probe.configure(_body)
	var shapes: Array=[]
	for child: Node in _body.get_children():
		if child is CollisionShape3D:shapes.append({"name":child.name,"disabled":child.disabled,"shape":child.shape.get_class() if child.shape!=null else "null","shape_scale":child.global_basis.get_scale(),"up":child.global_basis.y,"offset":child.position,"height":child.shape.height if child.shape is CapsuleShape3D else null})
	return {"physical_configured":configured,"surface_ready":probe._surface.ready if probe._surface!=null else false,"body_scale":_body.scale,"body_basis":_body.basis,"shapes":shapes,"pending_needs":_life._dsh_task_queue,"energy":_life._energy,"roam_serial":_life._roam_serial,"simple_on":_life._dsh_simple_on(),"restaurant_retry_at":_life._restaurant28_retry_at,"economy":_life._economy28.snapshot() if _life._economy28!=null else {},"token_body_same":_life._token.body==_body,"scene_basis":get_tree().current_scene.global_basis}

func _ordinary_completed56() -> int:
	var total:=0
	for kind: String in ["walk","shop","bank","restaurant"]:
		total+=int(_life._completed.get(kind,0))
	return total

func _phone_photo30() -> void:
	# A temporary observer camera only frames the existing committed phone pose.
	# It does not move the NPC/player, change the body route or write any bones.
	var view30:=Camera3D.new();get_tree().current_scene.add_child(view30)
	view30.global_position=_body.global_position+_body.global_basis.x*2.3-_body.global_basis.z*2.3+Vector3.UP*1.55
	view30.look_at(_body.global_position+Vector3.UP*1.1,Vector3.UP);view30.make_current()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("PHONE30.png"))
	_camera.make_current();view30.queue_free()

func _bind(scene: Node3D) -> bool:
	_pop=scene.get("preview_population")
	if _pop==null or not _pop.city_ready or not _pop.city_stream_complete() or _pop.daily==null:return false
	_lifecycle=_pop._multi_lifecycle30 if is_instance_valid(_pop._multi_lifecycle30) else _pop._single_lifecycle28
	if not is_instance_valid(_lifecycle):_finish("production_lifecycle_missing");return false
	if _pop.hit_owners.size()!=10 or _pop.daily._lives.size()!=10:_finish("ten_resident_contract");return false
	_life=_pop.daily._lives.get("resident_1");_health=_pop.daily._health.get("resident_1")
	if _life==null or _health==null or _health._token.source_id!="resident_1":_finish("wrong_resident");return false
	_body=_health._token.body;_player=scene.get("_player");_weapons=scene.get("preview_weapons")
	if not is_instance_valid(_player) or not is_instance_valid(_weapons):_finish("player_weapon_owner_missing");return false
	var staff: Node=scene.get("preview_venue_staff29")
	var sites: Node=scene.get("preview_service_sites29")
	var staff_count:=0
	if is_instance_valid(staff):
		for staff_row: Dictionary in staff._rows.values():
			if is_instance_valid(staff_row.actor) and staff_row.actor.is_inside_tree():staff_count+=1
	if staff_count!=12 or not is_instance_valid(sites):return false
	var wanted: Array[String]=[]
	var packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc_city/session_packet.json"))
	for row: Dictionary in packet.rows:
		if wanted.size()>=10:break
		wanted.append(str(row.source_id))
	wanted.sort()
	var actual: Array=_pop.daily._lives.keys();actual.sort()
	if actual!=wanted or int(sites.report.get("built",0))!=8:_finish("original_roster_or_venues_missing");return false
	_composition56={"ids":actual,"staff":staff_count,"new_sites":int(sites.report.built)}
	_target_id56=str(_health._token.source_id)
	_camera=_player.get_preview_camera();_player.set_mouse_captured(true)
	if not _place_player56("initial_visibility"):_finish("qa_player_supported_view_unavailable");return false
	_weapons.shot_emitted.connect(_shot);_weapons.effects.projectile_resolved.connect(_terminal)
	_button(MOUSE_BUTTON_RIGHT,false)
	if not _weapons.equip("tt_pistol").get("ok",false):_finish("native_equip_refused");return false
	_ready_ms=Time.get_ticks_msec()
	_checks.initial_hp_full=float(_health._row.hp)==float(_health._row.max_hp)
	_world30=scene.get_meta("npc_threat_world30",null)
	if _world30==null:_finish("production_threat_world_missing");return false
	_origin30=_body.global_position;_last_pos30=_origin30
	_walk_before30=int(_life._completed.walk)
	_phase="visible";_phase_at30=Time.get_ticks_msec();_deadline_ms=_phase_at30+240000
	return true

func _place_player56(stage: String) -> bool:
	# Only the QA player is positioned; residents, their paths and HP are untouched.
	var probe:=Physical56.new()
	if not probe.configure(_player):return false
	var before: Vector3=_player.global_position
	var forward: Vector3=-_body.global_basis.z;forward.y=0.0;forward=forward.normalized()
	for radius: float in [6.0,8.0,10.0]:
		for angle: float in [0.0,.3,-.3,.6,-.6,.9,-.9]:
			var direction: Vector3=forward.rotated(Vector3.UP,angle)
			var at: Vector3=_body.global_position+direction*radius
			var floor: Variant=probe.floor_at(at,_body.global_position.y)
			if not floor is Vector3 or not probe.standing(floor):continue
			var ray:=PhysicsRayQueryParameters3D.create(floor+Vector3.UP*1.45,_body.global_position+Vector3.UP*1.05,0xffffffff,[_player.get_rid()])
			var hit: Dictionary=_player.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or not _health._owns_collider(hit.get("collider")):continue
			_player.set_preview_pose_authority(&"on_foot",true);_player.global_position=floor
			_player_setup56.append({"stage":stage,"from":str(before),"to":str(floor),"native_floor_capsule_los":true,"frame":Engine.get_physics_frames()})
			return true
	return false

func _aim_offset30(offset: Vector3) -> bool:
	var direction: Vector3=(_body.global_position+offset-_camera.global_position).normalized()
	var yaw: float=atan2(-direction.x,-direction.z)
	var pitch: float=asin(clampf(direction.y,-.98,.98))
	var motion:=InputEventMouseMotion.new()
	motion.position=get_viewport().get_visible_rect().size*.5;motion.global_position=motion.position
	motion.relative=Vector2(-wrapf(yaw-_player._camera_yaw,-PI,PI)*.35/_player.mouse_sensitivity,-(pitch-_player._camera_pitch)*.35/_player.mouse_sensitivity)
	get_viewport().push_input(motion,true)
	var muzzle: Dictionary=_weapons.presentation.current_muzzle()
	if (-_camera.global_basis.z).angle_to(direction)>=.006 or not muzzle.get("ok",false):return false
	var camera_hit: Dictionary=_weapons._projectile_ray({"origin":_camera.global_position,"direction":-_camera.global_basis.z,"range":100.0})
	if _health._owns_collider(camera_hit.get("collider")):return false
	var aim_point: Vector3=camera_hit.get("point",_camera.global_position-_camera.global_basis.z*100.0)
	var along: Vector3=(aim_point-muzzle.origin).normalized()
	var muzzle_hit: Dictionary=_weapons._projectile_ray({"origin":muzzle.origin,"direction":along,"range":100.0})
	return not _health._owns_collider(muzzle_hit.get("collider"))

func _physics_process(delta: float) -> void:
	var now: int=Time.get_ticks_msec()
	if _phase=="bootstrap":
		if now-_start_ms>90000:_finish("bootstrap_timeout");return
		_bind(get_tree().current_scene as Node3D);return
	if _phase=="finished":return
	if _fire_down:_button(MOUSE_BUTTON_LEFT,false);_fire_down=false
	if now>_deadline_ms:_finish("timeout:"+_phase);return
	if bool(_health._row.get("dead",false)):_finish("unexpected_death");return
	if _pop.hit_owners.size()!=10 or _pop.daily._lives.size()!=10 or _pop.daily._lives.get(_target_id56)!=_life or _life._token.body!=_body:_finish("batch_or_target_identity_changed");return
	var threat: RefCounted=_life._threat30
	var state: Dictionary=threat.snapshot() if threat!=null else {}
	if threat!=null and threat.active():
		_observed30[str(state.kind)]=true
		_phone_frames30=maxi(_phone_frames30,int(state.pose_frames))
		if not state.report.is_empty():_report30=state.report.duplicate(true)
		_quiet30=maxf(_quiet30,float(state.quiet_until))
		if state.phase=="FLEE":_max_speed30=maxf(_max_speed30,Vector2(_body.global_position.x-_last_pos30.x,_body.global_position.z-_last_pos30.z).length()/delta)
		if state.phase=="PHONE" and _phone_frames30>=30 and not _phone_image30:
			_phone_image30=true
			if DisplayServer.get_name()!="headless":_phone_photo30.call_deferred()
	if _phase=="post_hit_quiet":_hit_distance56+=_body.global_position.distance_to(_last_pos30)
	if _phase=="post_hit_ordinary":_normal_speed56=maxf(_normal_speed56,Vector2(_body.global_position.x-_last_pos30.x,_body.global_position.z-_last_pos30.z).length()/delta)
	_last_pos30=_body.global_position
	if _phase=="visible":
		_torso_aim()
		if _observed30.has("visible_weapon"):
			_checks.visible_weapon=true;_button(MOUSE_BUTTON_RIGHT,true);_phase="aimed";_phase_at30=now
		elif now-_phase_at30>12000:_finish("visible_weapon_not_observed");return
	elif _phase=="aimed":
		_torso_aim()
		if _observed30.has("aimed_at"):
			_checks.aimed_at=true;_button(MOUSE_BUTTON_RIGHT,false);_phase="miss_shot";_phase_at30=now
		elif now-_phase_at30>6000:_finish("aim_not_observed");return
	elif _phase=="miss_shot":
		_stable=_stable+1 if _aim_offset30((_body.global_position-_camera.global_position).cross(Vector3.UP).normalized()*3.0+Vector3.UP*1.05) else 0
		if _fired==0 and _stable>=4:
			_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired+=1;_last_fire=now
		if _observed30.has("near_shot") and now-_last_fire>=500 and not _terminals.is_empty():
			_checks.native_near_shot=_shots.size()==1 and float(_health._row.hp)==60.0 and not _terminals.any(func(t:Dictionary)->bool:return t.owned)
			if not _checks.native_near_shot:_finish("expected_native_miss_hit_resident");return
			_weapons.equip("none");_phase="quiet_recovery";_phase_at30=now
		elif now-_phase_at30>6000:_finish("native_miss_shot_not_observed");return
	elif _phase=="quiet_recovery":
		_torso_aim(state.get("phase","")!="PHONE")
		if threat!=null and not threat.active():
			_checks.quiet_15_released=_world30._now>=_quiet30 and threat._reason=="quiet_15_seconds"
			_checks.real_flee=_body.global_position.distance_to(_origin30)>=2.0 and _max_speed30>1.8 and _max_speed30<2.05
			_checks.real_phone=_phone_frames30>=8 and not _report30.is_empty() and _report30.get("reason")=="dispatch_unavailable"
			_checks.no_fake_police_arrival=not _report30.get("accepted",false) and not _report30.get("police_arrival",false)
			_ordinary_before56=_ordinary_completed56();_phase="ordinary_completion";_phase_at30=now
	elif _phase=="ordinary_completion":
		_torso_aim(true)
		if now-_phase_at30>20000:_finish("ordinary_no_progress_after20s");return
		var ordinary_done: bool=_ordinary_completed56()>_ordinary_before56
		if _life._ambient29!=null:
			var ambient: Dictionary=_life._ambient29.snapshot()
			if ambient.active:_ambient_serial30=int(ambient.serial)
			ordinary_done=ordinary_done or (_ambient_serial30>=0 and int(ambient.serial)==_ambient_serial30 and ambient.reason=="finished" and int(ambient.pose_frames)>=8)
		if ordinary_done:
			_checks.production_ordinary_activity_completed=true
			if not _place_player56("actual_hit"):_finish("qa_player_hit_view_unavailable");return
			_actual_revision56=int(_health.last_result.get("revision",-1))
			_actual_hp_before56=float(_health._row.hp)
			_weapons.equip("tt_pistol");_phase="actual_hit";_phase_at30=now;_stable=0
	elif _phase=="actual_hit":
		_stable=_stable+1 if _torso_aim() else 0
		if _fired==1 and _stable>=5 and now-_last_fire>800:
			_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired+=1;_last_fire=now
		var receipt: Dictionary=_health.last_result
		if _fired==2 and _shots.size()==2 and int(receipt.get("revision",-1))>_actual_revision56 and receipt.get("applied",false) and not receipt.get("hit",{}).is_empty():
			_hit_receipts.append(receipt.duplicate(true))
			var event_id: String=str(receipt.get("event_id",""))
			_checks.real_hit_chain=_terminals.any(func(t:Dictionary)->bool:return t.owned and t.status=="hit" and t.shot_id==_shots[1].shot_id and event_id.ends_with(":"+str(t.shot_id)) and _shots.any(func(s:Dictionary)->bool:return s.shot_id==t.shot_id))
			_checks.actual_hit_reaction=threat!=null and threat.active() and threat._event.kind=="actual_hit"
			var damage56:=float(receipt.hit.get("damage",0.0))
			var hp56:=float(_health._row.hp)
			_checks.actual_nonfatal_hp_from_native_receipt=is_finite(damage56) and damage56>0.0 and damage56<_actual_hp_before56 and is_equal_approx(hp56,_actual_hp_before56-damage56) and is_equal_approx(hp56,float(receipt.get("row",{}).get("hp",-1.0))) and hp56>=float(_health._row.max_hp)*.5
			_hit_origin56=_body.global_position;_hit_distance56=0.0
			_weapons.equip("none");_phase="post_hit_quiet";_phase_at30=now
		if now-_phase_at30>15000:_finish("actual_nonfatal_hit_not_completed");return
	elif _phase=="post_hit_quiet":
		_torso_aim(true)
		if threat!=null and not threat.active():
			_checks.hit_quiet_15_released=_world30._now>=_quiet30 and threat._reason=="quiet_15_seconds"
			_checks.hit_physical_flee=_hit_distance56>=1.0 and _body.global_position.distance_to(_hit_origin56)>=.5
			_ordinary_before56=_ordinary_completed56();_ambient_serial30=-1;_normal_speed56=0.0
			_phase="post_hit_ordinary";_phase_at30=now
	elif _phase=="post_hit_ordinary":
		_torso_aim(true)
		var done: bool=_ordinary_completed56()>_ordinary_before56
		if _life._ambient29!=null:
			var ambient: Dictionary=_life._ambient29.snapshot()
			if ambient.active:_ambient_serial30=int(ambient.serial)
			done=done or (_ambient_serial30>=0 and int(ambient.serial)==_ambient_serial30 and ambient.reason=="finished" and int(ambient.pose_frames)>=8)
		if done:
			_checks.after_hit_ordinary_activity_completed=true
			_checks.after_hit_speed_not_accumulated=_normal_speed56<=1.85
			_finish("complete");return
	if now-_last_log>=500:
		_last_log=now
		_rows.append({"ms":now,"phase":_phase,"hp":_health._row.hp,"position":str(_body.global_position),"threat":state,"life":_life._phase,"goal":_life._goal.get("kind",""),"completed":_life._completed.duplicate(),"world":_world30.snapshot(),"diagnostics31":{"now":_life._now,"next_decision":str(_life._next_decision),"busy":_life._busy,"disposed":_life._disposed,"health_pause":_health.should_pause_walk(),"host_current":_life._host.target_current(_life._token),"attention_active":_life._attention29.active,"focused":Focus30.focused(_body),"player_distance":_body.global_position.distance_to(_player.global_position),"roam_active":_life._roam51_active,"economy_active":_life._economy28_active(),"restaurant_active":_life._restaurant28_active(),"simple_active":_life._dsh_simple_goal_active(),"decisions":_life._dsh_decisions,"health_now":_health._now()}})
		if _phase=="ordinary_completion":_rows.back()["details31"]=_details31()

func _finish(reason: String) -> void:
	if _phase=="finished":return
	_phase="finished";set_physics_process(false)
	if is_instance_valid(_weapons):_weapons.cancel_inputs();_weapons.equip("none")
	var passed: bool=reason=="complete" and not _checks.values().has(false)
	var result: Dictionary={"passed":passed,"reason":reason,"checks":_checks,"observed":_observed30,"max_flee_speed":_max_speed30,"phone_frames":_phone_frames30,"phone_report":_report30,"shots":_shots,"native_terminals":_terminals,"health_receipts":_hit_receipts,"samples":_rows,"batch_composition":_composition56,"target_id":_target_id56,"qa_player_positions":_player_setup56,"hit_flee_distance_m":_hit_distance56,"post_hit_normal_max_speed":_normal_speed56,"synthetic_damage":false,"npc_relocated":false,"routes_replaced":false,"police_dispatch_accepted":false,"performance_accepted":false}
	if not _out.is_empty():
		var file:=FileAccess.open(_out.path_join("CITY_THREAT56.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("QA_CITY_THREAT56_FINISH ",JSON.stringify({"passed":passed,"reason":reason,"checks":_checks}))
	get_tree().quit(0 if passed else 1)
