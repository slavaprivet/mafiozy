extends Node
## DSH_SURRENDER58 observer (read-only for residents): aim -> hands up -> lower, no shot.
## Input goes through the real viewport (synthetic mouse motion + right button), the same
## path the existing threat harness uses. No HP, route or transform of a resident is written.
const Physical = preload("res://scripts/hospital/npc_physical_route51.gd")
const TARGET := "resident_1"
var out_dir := ""
var _scene: Node
var _pop: RefCounted
var _life: RefCounted
var _health: RefCounted
var _body: CharacterBody3D
var _player: Node
var _camera: Camera3D
var _weapons: Node
var _threat: RefCounted
var _shots := 0
var _entered := false
var _pose_at_entry := 0
var _pose_max := 0
var _lease_max := 0.0
var _released := false
var _release_reason := ""
var _pose_at_release := 0
var _left_phase := false
var _phase_seen: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _button(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = get_viewport().get_visible_rect().size * .5
	event.global_position = event.position
	get_viewport().push_input(event, true)


func _torso_aim() -> bool:
	var target: Vector3 = _body.global_position + Vector3(0, 1.05, 0)
	var direction: Vector3 = (target - _camera.global_position).normalized()
	var yaw: float = atan2(-direction.x, -direction.z)
	var pitch: float = asin(clampf(direction.y, -.98, .98))
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_visible_rect().size * .5
	motion.global_position = motion.position
	motion.relative = Vector2(-wrapf(yaw - _player._camera_yaw, -PI, PI) * .35 / _player.mouse_sensitivity,
		-(pitch - _player._camera_pitch) * .35 / _player.mouse_sensitivity)
	get_viewport().push_input(motion, true)
	var hit: Dictionary = _weapons._projectile_ray({"origin": _camera.global_position,
		"direction": -_camera.global_basis.z, "range": 100.0})
	return hit.has("point") and _health._owns_collider(hit.get("collider"))


func _place_player() -> bool:
	var probe := Physical.new()
	if not probe.configure(_player):
		return false
	var forward: Vector3 = -_body.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for radius: float in [6.0, 8.0, 10.0]:
		for angle: float in [0.0, .3, -.3, .6, -.6, .9, -.9]:
			var at: Vector3 = _body.global_position + forward.rotated(Vector3.UP, angle) * radius
			var floor: Variant = probe.floor_at(at, _body.global_position.y)
			if not floor is Vector3 or not probe.standing(floor):
				continue
			var ray := PhysicsRayQueryParameters3D.create(floor + Vector3.UP * 1.45,
				_body.global_position + Vector3.UP * 1.05, 0xffffffff, [_player.get_rid()])
			var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or not _health._owns_collider(hit.get("collider")):
				continue
			_player.set_preview_pose_authority(&"on_foot", true)
			_player.global_position = floor
			return true
	return false


func _snapshot() -> Dictionary:
	# The threat controller is created lazily by the first accepted observation, so it
	# must be read fresh every sample instead of cached at bind time.
	var threat: Variant = _life.get("_threat30") if _life != null else null
	if threat == null or not is_instance_valid(threat):
		return {}
	_threat = threat
	return threat.call("snapshot")


func _run() -> void:
	var deadline := Time.get_ticks_msec() + 115000
	while Time.get_ticks_msec() < deadline:
		_scene = get_tree().current_scene
		_pop = _scene.get("preview_population") if _scene != null else null
		if _pop != null and _scene.get("preview_ready") == true and _pop.get("city_ready") == true and _pop.get("daily") != null:
			break
		await get_tree().process_frame
	if _pop == null:
		_finish({"ok": false, "reason": "city_not_ready"})
		return
	_life = _pop.daily._lives.get(TARGET)
	_health = _pop.daily._health.get(TARGET)
	if _life == null or _health == null:
		_finish({"ok": false, "reason": "target_missing"})
		return
	_body = _health._token.body
	_player = _scene.get("_player")
	_weapons = _scene.get("preview_weapons")
	if not is_instance_valid(_player) or not is_instance_valid(_weapons):
		_finish({"ok": false, "reason": "player_or_weapon_missing"})
		return
	_camera = _player.get_preview_camera()
	_player.set_mouse_captured(true)
	if not _place_player():
		_finish({"ok": false, "reason": "player_view_unavailable"})
		return
	_weapons.shot_emitted.connect(func(_a, _b, _c, _d) -> void: _shots += 1)
	_button(MOUSE_BUTTON_RIGHT, false)
	if not _weapons.equip("tt_pistol").get("ok", false):
		_finish({"ok": false, "reason": "native_equip_refused"})
		return
	_threat = _life._threat30
	print("DSH_SURRENDER58 stage=armed id=", TARGET, " player_at=", _player.global_position)
	# Phase 0: the weapon must be live before the right button is accepted, exactly as
	# the proven threat harness waits for the first visible_weapon observation. Aiming
	# earlier leaves `_aiming` false and no aimed_at event is ever produced.
	var visible_deadline := Time.get_ticks_msec() + 25000
	var seen := false
	while Time.get_ticks_msec() < visible_deadline and not seen:
		_torso_aim()
		seen = not _snapshot().is_empty()
		await get_tree().physics_frame
	if not seen:
		_finish({"ok": false, "reason": "no_threat_observation"})
		return
	print("DSH_SURRENDER58 stage=visible kind=", str(_snapshot().get("kind", "")))
	# Phase 1: aim until the hold-up phase exists and its pose is committed. The
	# resident keeps walking, so the player is re-placed whenever the aim ray loses it.
	var aim_deadline := Time.get_ticks_msec() + 60000
	var misses := 0
	var ticks := 0
	while Time.get_ticks_msec() < aim_deadline and not _entered:
		ticks += 1
		if ticks % 30 == 0:
			_button(MOUSE_BUTTON_RIGHT, true)  # idempotent: keeps `_aiming` asserted
		if not _torso_aim():
			misses += 1
			if misses % 90 == 0:
				_place_player()
		else:
			misses = 0
		var state := _snapshot()
		var phase := str(state.get("phase", ""))
		if phase != "" and not _phase_seen.has(phase):
			_phase_seen.append(phase)
		_pose_max = maxi(_pose_max, int(state.get("surrender_pose_frames", 0)))
		_lease_max = maxf(_lease_max, float(state.get("aim_lease_ms", 0.0)))
		if phase == "SURRENDER58":
			_entered = true
			_pose_at_entry = int(state.get("surrender_pose_frames", 0))
		await get_tree().physics_frame
	if not _entered:
		_finish({"ok": false, "reason": "surrender_phase_not_reached", "phases": _phase_seen,
			"pose_max": _pose_max, "shots": _shots})
		return
	# Hold the gesture long enough that the committed pose is unambiguous.
	var hold_until := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < hold_until:
		_torso_aim()
		var state := _snapshot()
		_pose_max = maxi(_pose_max, int(state.get("surrender_pose_frames", 0)))
		await get_tree().physics_frame
	# Phase 2: LOWER the weapon and never shoot. The aim lease must expire, the pose must
	# lower through its own fade and the life must be released by `aim_released58`.
	_button(MOUSE_BUTTON_RIGHT, false)
	var release_seen_at := Time.get_ticks_msec()
	var observe_until := release_seen_at + 12000
	while Time.get_ticks_msec() < observe_until:
		var state := _snapshot()
		var phase := str(state.get("phase", ""))
		_pose_max = maxi(_pose_max, int(state.get("surrender_pose_frames", 0)))
		if phase != "" and not _phase_seen.has(phase):
			_phase_seen.append(phase)
		if phase != "SURRENDER58":
			_left_phase = true
			if not _released:
				_released = true
				_release_reason = str(state.get("reason", ""))
				_pose_at_release = int(state.get("surrender_pose_frames", 0))
			break
		await get_tree().physics_frame
	_weapons.equip("none")
	var ok: bool = _entered and _pose_max > _pose_at_entry and _left_phase and _shots == 0
	_finish({"ok": ok, "id": TARGET, "entered": _entered, "pose_at_entry": _pose_at_entry,
		"pose_max": _pose_max, "pose_at_release": _pose_at_release, "aim_lease_ms_max": roundf(_lease_max),
		"left_phase_without_shot": _left_phase, "release_reason": _release_reason,
		"shots_fired": _shots, "phases_seen": _phase_seen,
		"expectation": "release_reason aim_released58 proves the 850 ms lease expired and the pose lowered",
		"level": "real viewport input, no damage"})


func _finish(value: Dictionary) -> void:
	print("DSH_SURRENDER58_RELEASE_RESULT ", JSON.stringify(value))
	if not out_dir.is_empty():
		var file := FileAccess.open(out_dir.path_join("RELEASE58.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(value, "\t"))
			file.close()
	get_tree().quit(0 if value.get("ok", false) else 1)
