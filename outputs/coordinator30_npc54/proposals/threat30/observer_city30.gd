extends "../injury30/observer_injury30.gd"
## Genuine viewport input and production daily logic; no NPC teleport/HP/route writes.
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
	if _pop==null or not _pop.city_ready or _pop.daily==null:return false
	_lifecycle=_pop._multi_lifecycle30 if is_instance_valid(_pop._multi_lifecycle30) else _pop._single_lifecycle28
	if not is_instance_valid(_lifecycle):_finish("production_lifecycle_missing");return false
	if _pop.hit_owners.size()!=1:_finish("one_resident_contract");return false
	_life=_pop.daily._lives.get("resident_1");_health=_pop.hit_owners[0]
	if _life==null or _health._token.source_id!="resident_1":_finish("wrong_resident");return false
	_body=_health._token.body;_player=scene.get("_player");_weapons=scene.get("preview_weapons")
	if not is_instance_valid(_player) or not is_instance_valid(_weapons):_finish("player_weapon_owner_missing");return false
	_camera=_player.get_preview_camera();_player.set_mouse_captured(true)
	_weapons.shot_emitted.connect(_shot);_weapons.effects.projectile_resolved.connect(_terminal)
	_button(MOUSE_BUTTON_RIGHT,false)
	if not _weapons.equip("tt_pistol").get("ok",false):_finish("native_equip_refused");return false
	_ready_ms=Time.get_ticks_msec()
	_checks.initial_hp_full=float(_health._row.hp)==float(_health._row.max_hp)
	_world30=scene.get_meta("npc_threat_world30",null)
	if _world30==null:_finish("production_threat_world_missing");return false
	_origin30=_body.global_position;_last_pos30=_origin30
	_walk_before30=int(_life._completed.walk)
	_phase="visible";_phase_at30=Time.get_ticks_msec();_deadline_ms=_phase_at30+180000
	return true

func _aim_offset30(offset: Vector3) -> bool:
	var direction: Vector3=(_body.global_position+offset-_camera.global_position).normalized()
	var yaw: float=atan2(-direction.x,-direction.z)
	var pitch: float=asin(clampf(direction.y,-.98,.98))
	var motion:=InputEventMouseMotion.new()
	motion.position=get_viewport().get_visible_rect().size*.5;motion.global_position=motion.position
	motion.relative=Vector2(-wrapf(yaw-_player._camera_yaw,-PI,PI)*.35/_player.mouse_sensitivity,-(pitch-_player._camera_pitch)*.35/_player.mouse_sensitivity)
	get_viewport().push_input(motion,true)
	return (-_camera.global_basis.z).angle_to(direction)<.006 and _weapons.presentation.current_muzzle().get("ok",false)

func _physics_process(delta: float) -> void:
	var now: int=Time.get_ticks_msec()
	if _phase=="bootstrap":
		if now-_start_ms>90000:_finish("bootstrap_timeout");return
		_bind(get_tree().current_scene as Node3D);return
	if _phase=="finished":return
	if _fire_down:_button(MOUSE_BUTTON_LEFT,false);_fire_down=false
	if now>_deadline_ms:_finish("timeout:"+_phase);return
	if bool(_health._row.get("dead",false)):_finish("unexpected_death");return
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
		_stable=_stable+1 if _aim_offset30(Vector3(2.5,1.05,0)) else 0
		if _fired==0 and _stable>=4:
			_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired+=1;_last_fire=now
		if _observed30.has("near_shot"):
			_checks.native_near_shot=_shots.size()==1 and float(_health._row.hp)==60.0
			_weapons.equip("none");_phase="quiet_recovery";_phase_at30=now
		elif now-_phase_at30>6000:_finish("native_miss_shot_not_observed");return
	elif _phase=="quiet_recovery":
		_torso_aim(state.get("phase","")!="PHONE")
		if threat!=null and not threat.active():
			_checks.quiet_15_released=_world30._now>=_quiet30 and threat._reason=="quiet_15_seconds"
			_checks.real_flee=_body.global_position.distance_to(_origin30)>=2.0 and _max_speed30>1.8 and _max_speed30<2.05
			_checks.real_phone=_phone_frames30>=8 and not _report30.is_empty() and _report30.get("reason")=="dispatch_unavailable"
			_checks.no_fake_police_arrival=not _report30.get("accepted",false) and not _report30.get("police_arrival",false)
			_walk_before30=int(_life._completed.walk);_phase="ordinary_completion";_phase_at30=now
	elif _phase=="ordinary_completion":
		_torso_aim(true)
		var ordinary_done: bool=int(_life._completed.walk)>_walk_before30
		if _life._ambient29!=null:
			var ambient: Dictionary=_life._ambient29.snapshot()
			if ambient.active:_ambient_serial30=int(ambient.serial)
			ordinary_done=ordinary_done or (_ambient_serial30>=0 and int(ambient.serial)==_ambient_serial30 and ambient.reason=="finished" and int(ambient.pose_frames)>=8)
		if ordinary_done:
			_checks.production_ordinary_activity_completed=true
			_weapons.equip("tt_pistol");_phase="actual_hit";_phase_at30=now;_stable=0
	elif _phase=="actual_hit":
		_stable=_stable+1 if _torso_aim() else 0
		if _fired==1 and _stable>=5 and now-_last_fire>800:
			_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired+=1;_last_fire=now
		var receipt: Dictionary=_health.last_result
		if receipt.get("applied",false) and not receipt.get("hit",{}).is_empty():
			_hit_receipts.append(receipt.duplicate(true))
			var event_id: String=str(receipt.get("event_id",""))
			_checks.real_hit_chain=_terminals.any(func(t:Dictionary)->bool:return t.owned and t.status=="hit" and event_id.ends_with(":"+str(t.shot_id)) and _shots.any(func(s:Dictionary)->bool:return s.shot_id==t.shot_id))
			_checks.actual_hit_reaction=threat!=null and threat.active() and threat._event.kind=="actual_hit"
			_finish("complete");return
		if now-_phase_at30>15000:_finish("actual_nonfatal_hit_not_completed");return
	if now-_last_log>=500:
		_last_log=now
		_rows.append({"ms":now,"phase":_phase,"hp":_health._row.hp,"position":str(_body.global_position),"threat":state,"life":_life._phase,"goal":_life._goal.get("kind",""),"completed":_life._completed.duplicate(),"world":_world30.snapshot()})

func _finish(reason: String) -> void:
	if _phase=="finished":return
	_phase="finished";set_physics_process(false)
	if is_instance_valid(_weapons):_weapons.cancel_inputs();_weapons.equip("none")
	var passed: bool=reason=="complete" and not _checks.values().has(false)
	var result: Dictionary={"passed":passed,"reason":reason,"checks":_checks,"observed":_observed30,"max_flee_speed":_max_speed30,"phone_frames":_phone_frames30,"phone_report":_report30,"shots":_shots,"native_terminals":_terminals,"health_receipts":_hit_receipts,"samples":_rows,"synthetic_damage":false,"npc_relocated":false,"routes_replaced":false,"police_dispatch_accepted":false,"performance_accepted":false}
	if not _out.is_empty():
		var file:=FileAccess.open(_out.path_join("CITY_THREAT30.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("QA_CITY_THREAT30_FINISH ",JSON.stringify({"passed":passed,"reason":reason,"checks":_checks}))
	get_tree().quit(0 if passed else 1)
