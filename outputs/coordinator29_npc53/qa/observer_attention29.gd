extends "observer_death28.gd"
var _attention_checks: Dictionary = {}
var _held_at := Vector3.ZERO
var _saved_target := Vector3.ZERO
var _saved_driver: RefCounted
var _hold_frame := 0
var _release_frame := 0
var _turned_frame := 0
var _initial_error := 0.0
var _max_yaw_step := 0.0
var _previous_yaw := 0.0
var _hold_drift := 0.0
var _release_position := Vector3.ZERO

func _look(away: bool = false) -> void:
	var target: Vector3 = _body.global_position + Vector3(0, 1.25, 0)
	var direction: Vector3 = (target - _camera.global_position).normalized()
	var yaw: float = atan2(-direction.x, -direction.z) + (PI if away else 0.0)
	var pitch: float = asin(clampf(direction.y, -.98, .98))
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_visible_rect().size * .5; motion.global_position = motion.position
	var blend: float = 1.0 if away else .35
	motion.relative = Vector2(-wrapf(yaw - _player._camera_yaw, -PI, PI) * blend / _player.mouse_sensitivity, -(pitch - _player._camera_pitch) * blend / _player.mouse_sensitivity)
	get_viewport().push_input(motion, true)

func _face_error() -> float:
	var facing: Vector3 = _player.global_position - _body.global_position
	return absf(wrapf(_body.rotation.y - atan2(-facing.x, -facing.z), -PI, PI))

func _bind(scene: Node3D) -> bool:
	if not super._bind(scene): return false
	_button(MOUSE_BUTTON_RIGHT, false); _weapons.equip("none")
	_look(true); _phase = "wait_walking"; _deadline_ms = Time.get_ticks_msec() + 45000
	return true

func _physics_process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	var frame: int = Engine.get_physics_frames()
	if _phase == "bootstrap":
		if now - _start_ms > 90000: _done("bootstrap_timeout"); return
		_bind(get_tree().current_scene as Node3D); return
	if _phase == "finished": return
	if now > _deadline_ms: _done("timeout:" + _phase); return
	var held: bool = bool(_life._attention29.active)
	if _phase == "wait_walking":
		if _life._roam51_active and Vector2(_body.velocity.x, _body.velocity.z).length() > .1:
			_saved_driver = _life._roam51; _saved_target = _saved_driver.get("_target")
			_previous_yaw = _body.rotation.y; _initial_error = _face_error()
			_phase = "aim"; _look()
	elif _phase == "aim":
		_look()
		if held:
			_held_at = _body.global_position; _hold_frame = frame; _phase = "hold"
	elif _phase == "hold":
		_look()
		_max_yaw_step = maxf(_max_yaw_step, absf(wrapf(_body.rotation.y - _previous_yaw, -PI, PI)))
		_previous_yaw = _body.rotation.y
		_hold_drift = maxf(_hold_drift, _body.global_position.distance_to(_held_at))
		if not held: _done("attention_lost_during_gaze"); return
		if frame - _hold_frame > 90:
			_attention_checks["holds_position"] = _hold_drift < .025
			_attention_checks["faces_player"] = _face_error() < .05
			_attention_checks["smooth_turn"] = _max_yaw_step < .65
			_attention_checks["same_goal_while_held"] = _life._roam51 == _saved_driver and _saved_driver.get("_target") == _saved_target
			_capture.call_deferred("facing_player.png")
			_turned_frame = frame; _look(true); _phase = "release"
	elif _phase == "release":
		if not held:
			_attention_checks["immediate_release"] = frame - _turned_frame <= 2
			_release_frame = frame; _release_position = _body.global_position; _phase = "resume"
	elif _phase == "resume":
		var moved: float = _body.global_position.distance_to(_release_position)
		if moved > .005:
			_attention_checks["next_frame_motion"] = frame - _release_frame <= 1
			_attention_checks["same_route_after_release"] = _life._roam51 == _saved_driver and _saved_driver.get("_target") == _saved_target
			_done("complete"); return
		if frame - _release_frame > 30: _done("resume_no_motion"); return
	if now - _last_log > 500 or _phase in ["aim", "hold", "release", "resume"]:
		_last_log = now
		var row := {"frame":frame,"phase":_phase,"held":held,"life":_life._phase,"distance":_body.global_position.distance_to(_player.global_position),"target":str(_saved_target),"position":str(_body.global_position)}
		_rows.append(row); print("QA_ATTENTION29 ", JSON.stringify(row))

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name))

func _done(reason: String) -> void:
	_phase = "finished"
	var passed: bool = reason == "complete" and not _attention_checks.values().has(false)
	var result := {"passed":passed,"reason":reason,"checks":_attention_checks,"initial_face_error":_initial_error,"max_yaw_step":_max_yaw_step,"hold_drift":_hold_drift,"turn_input_frame":_turned_frame,"release_frame":_release_frame,"finished_frame":Engine.get_physics_frames(),"rows":_rows,"npc_relocated":false,"native_camera_input":true,"population":_active_ids() if _pop != null else []}
	var file := FileAccess.open(_out.path_join("ATTENTION29.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print("ATTENTION29 ",JSON.stringify(result)); get_tree().quit(0 if passed else 1)
