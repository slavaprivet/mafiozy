extends "observer_death28.gd"
## Actual input, accepted shot, native owned projectile terminal and HP receipt.
## No HP edits, synthetic contact dictionaries, NPC relocation or route replacement.
const Focus30 = preload("res://scripts/npc_visual/npc_resident_focus29.gd")
const Budget30 = preload("res://scripts/hospital/npc_route_budget29.gd")
var _checks: Dictionary = {}
var _injury_position := Vector3.ZERO
var _injury_ms := 0
var _injury_frame := 0
var _focused_low_frames := 0
var _focused_low_held := 0
var _focused_low_moving := 0
var _unpaused_low_frames := 0
var _away_low_frames := 0
var _away_low_held := 0
var _low_hp := -1.0
var _hit_receipts: Array[Dictionary] = []
var _last_revision := -1
var _max_jobs := 0
var _max_nodes := 0
var _hospital_seen := false
var _treating_seen := false
var _healed_seen := false
var _completed_before := 0

func _bind(scene: Node3D) -> bool:
	if not super._bind(scene): return false
	_button(MOUSE_BUTTON_RIGHT,false)
	_weapons.equip("tt_pistol")
	_phase="aim_and_wound"; _deadline_ms=Time.get_ticks_msec()+160000
	_checks["initial_hp_full"]=float(_health._row.hp)==float(_health._row.max_hp)
	_completed_before=int(_life._completed.hospital)
	return true

func _torso_aim(away: bool=false) -> bool:
	var target: Vector3=_body.global_position+Vector3(0,1.05,0)
	var direction: Vector3=(target-_camera.global_position).normalized()
	var yaw: float=atan2(-direction.x,-direction.z)+(PI if away else 0.0)
	var pitch: float=asin(clampf(direction.y,-.98,.98))
	var motion:=InputEventMouseMotion.new()
	motion.position=get_viewport().get_visible_rect().size*.5;motion.global_position=motion.position
	motion.relative=Vector2(-wrapf(yaw-_player._camera_yaw,-PI,PI)*.35/_player.mouse_sensitivity,-(pitch-_player._camera_pitch)*.35/_player.mouse_sensitivity)
	get_viewport().push_input(motion,true)
	if away:return false
	var hit: Dictionary=_weapons._projectile_ray({"origin":_camera.global_position,"direction":-_camera.global_basis.z,"range":100.0})
	var muzzle: Dictionary=_weapons.presentation.current_muzzle()
	if not muzzle.get("ok",false) or not hit.has("point") or not _health._owns_collider(hit.get("collider")):return false
	var along: Vector3=(hit.point-muzzle.origin).normalized()
	var muzzle_hit: Dictionary=_weapons._projectile_ray({"origin":muzzle.origin,"direction":along,"range":muzzle.origin.distance_to(hit.point)+.03})
	return _health._owns_collider(muzzle_hit.get("collider")) and (-_camera.global_basis.z).angle_to(direction)<.006 and float(_weapons.fire_state.cooldown)<=0 and float(_weapons.fire_state.reloadRemaining)<=0 and int(_weapons.fire_state.magazine)>0

func _physics_process(_delta: float) -> void:
	var now: int=Time.get_ticks_msec()
	var frame: int=Engine.get_physics_frames()
	if _phase=="bootstrap":
		if now-_start_ms>90000:_finish("bootstrap_timeout");return
		_bind(get_tree().current_scene as Node3D);return
	if _phase=="finished":return
	if _fire_down:_button(MOUSE_BUTTON_LEFT,false);_fire_down=false
	if now>_deadline_ms:_finish("timeout:"+_phase);return
	if bool(_health._row.get("dead",false)) or float(_health._row.hp)<=0 or bool(_health._row.get("_medicalDowned",false)):_finish("nonfatal_regression_became_fatal");return
	var receipt: Dictionary=_health.last_result
	if int(receipt.get("revision",-1))>_last_revision:
		_last_revision=int(receipt.get("revision",-1))
		if receipt.get("applied",false) and not receipt.get("hit",{}).is_empty():_hit_receipts.append(receipt.duplicate(true))
	var low: bool=float(_health._row.hp)<float(_health._row.max_hp)*.5
	var focused: bool=Focus30.focused(_body)
	var held: bool=_life._attention29.active
	if _phase=="aim_and_wound":
		if low:
			_injury_position=_body.global_position;_injury_ms=now;_injury_frame=frame;_low_hp=float(_health._row.hp)
			_phase="focused_injured";_button(MOUSE_BUTTON_RIGHT,false)
		else:
			_stable=_stable+1 if _torso_aim() else 0
			if _fired<2 and _stable>=5 and now-_last_fire>800:
				_button(MOUSE_BUTTON_LEFT,true);_fire_down=true;_fired+=1;_last_fire=now;_stable=0
			if now-_ready_ms>25000:_finish("native_nonfatal_hits_not_completed");return
	if _phase=="focused_injured":
		_torso_aim()
		if not _health.should_pause_walk():_unpaused_low_frames+=1
		if low and focused:
			_focused_low_frames+=1
			if held:_focused_low_held+=1
			if Vector2(_body.velocity.x,_body.velocity.z).length()>.1:_focused_low_moving+=1
		if now-_injury_ms>5000 and _unpaused_low_frames>=90:
			_checks["focused_low_health_never_held"]=_focused_low_held==0
			_checks["focused_low_health_moved"]=_focused_low_moving>=5 and _body.global_position.distance_to(_injury_position)>.5
			_checks["focused_low_health_observed"]=_focused_low_frames>=5
			if not _checks.focused_low_health_observed:_finish("gaze_not_observed_in_this_viewport");return
			if not _checks.focused_low_health_never_held or not _checks.focused_low_health_moved:_finish("injured_gaze_freeze");return
			_phase="away_injured"
	elif _phase=="away_injured":
		_torso_aim(true)
		if low and not focused:
			_away_low_frames+=1
			if held:_away_low_held+=1
		if now-_injury_ms>8000:_phase="hospital_completion"
	elif _phase=="hospital_completion":
		# Keep looking at the resident throughout treatment/exit when it is visible.
		_torso_aim()
	var kind: String=str(_life._goal.get("kind",""))
	if kind=="hospital":_hospital_seen=true
	if _life._hospital_stage=="TREATING":_treating_seen=true
	if _hospital_seen and float(_health._row.hp)==float(_health._row.max_hp):_healed_seen=true
	var budget: Dictionary=Budget30.diagnostics()
	_max_jobs=maxi(_max_jobs,int(budget.jobs));_max_nodes=maxi(_max_nodes,int(budget.nodes))
	if int(_life._completed.hospital)>_completed_before:
		_checks["native_nonfatal_hit_receipts"]=_hit_receipts.size()>=1 and _low_hp>0 and _low_hp<30
		_checks["native_owned_projectile_hits"]=_terminals.filter(func(t:Dictionary)->bool:return t.status=="hit" and t.owned).size()>=1
		var chain_complete: bool=not _hit_receipts.is_empty()
		for hit: Dictionary in _hit_receipts:
			var event_id: String=str(hit.get("event_id",""))
			var matched: bool=false
			for terminal: Dictionary in _terminals:
				var shot_id: String=str(terminal.shot_id)
				if not shot_id.is_empty() and event_id.ends_with(":"+shot_id) and terminal.status=="hit" and terminal.owned and _shots.any(func(s:Dictionary)->bool:return s.shot_id==shot_id):matched=true
			chain_complete=chain_complete and matched
		_checks["authenticated_shot_terminal_health_chain"]=chain_complete
		_checks["away_low_health_observed"]=_away_low_frames>=5 and _away_low_held==0
		_checks["hospital_treated_and_physically_exited"]=_hospital_seen and _treating_seen and _healed_seen
		_checks["route_jobs_bounded"]=_max_jobs<=2 and _max_nodes<=65536
		_finish("complete");return
	if now-_last_log>500:
		_last_log=now
		var sample: Dictionary={"frame":frame,"ms":now,"phase":_phase,"hp":_health._row.hp,"held":held,"focused":focused,"life":_life._phase,"goal":kind,"hospital":_life._hospital_stage,"position":str(_body.global_position),"distance_from_hit":_body.global_position.distance_to(_injury_position) if _injury_ms>0 else 0,"health_pause":_health.should_pause_walk(),"budget":budget}
		_rows.append(sample);print("QA_INJURY30 ",JSON.stringify(sample))

func _finish(reason: String) -> void:
	if _phase=="finished":return
	_phase="finished";set_physics_process(false)
	if is_instance_valid(_weapons):_weapons.cancel_inputs()
	var passed: bool=reason=="complete" and not _checks.values().has(false)
	var result: Dictionary={"passed":passed,"reason":reason,"checks":_checks,"hp_after_native_hits":_low_hp,"focused_low_frames":_focused_low_frames,"focused_low_held":_focused_low_held,"focused_low_moving":_focused_low_moving,"unpaused_low_frames":_unpaused_low_frames,"away_low_frames":_away_low_frames,"shots":_shots,"native_terminals":_terminals,"health_receipts":_hit_receipts,"max_route_jobs":_max_jobs,"max_route_nodes":_max_nodes,"samples":_rows,"synthetic_damage":false,"npc_relocated":false,"performance_accepted":false}
	if not _out.is_empty():
		var file:=FileAccess.open(_out.path_join("INJURY30.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("QA_INJURY30_FINISH ",JSON.stringify({"passed":passed,"reason":reason,"checks":_checks}))
	get_tree().quit(0 if passed else 1)
