extends SceneTree
## SHIP64: helm/cannon controls, physical balls, station hold, ladder.
## Prints every phase so a hang is visible in the log.

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	print("SHIP64_FIX_BOOT")
	var packed: PackedScene = load("res://scenes/castle.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await process_frame
	print("SHIP64_FIX_READY ", scene.get("preview_ready"))
	var host: Node = null
	var host_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < host_deadline:
		host = scene.get("preview_ship")
		if is_instance_valid(host):
			break
		await process_frame
	print("SHIP64_FIX_HOST ", is_instance_valid(host))
	for i in 40:
		await physics_frame
	var player: CharacterBody3D = scene.get("_player")
	var boat: Node3D = host.get("boat")
	var cannons: Node3D = host.get("cannons")
	print("SHIP64_FIX_START balls=", host.get("balls"))
	# --- cannon station
	host.call("debug_set_station", "cannon", 2)
	for i in 20:
		await physics_frame
	print("SHIP64_FIX_STATION station=", host.get("_station"), " manning=", cannons.call("manning"),
		" index=", cannons.call("manning_index"))
	var state0: Dictionary = cannons.call("state")
	var yaw0: float = float(state0.get("yaw_deg", 0.0))
	var pitch0: float = float(state0.get("pitch_deg", 0.0))
	_key(KEY_D, true)
	for i in 35:
		await physics_frame
	_key(KEY_D, false)
	var state1: Dictionary = cannons.call("state")
	var yaw1: float = float(state1.get("yaw_deg", 0.0))
	_key(KEY_W, true)
	for i in 35:
		await physics_frame
	_key(KEY_W, false)
	var state2: Dictionary = cannons.call("state")
	var pitch1: float = float(state2.get("pitch_deg", 0.0))
	# Direct API check: mechanics independent of the synthetic-key injection.
	cannons.call("aim", 0.55, 0.35)
	for i in 12:
		await physics_frame
	var state3: Dictionary = cannons.call("state")
	var gun3 := _gun_state(state3, 2)
	print("SHIP64_FIX_DIRECT yaw=", gun3.get("yaw_deg", 0.0), " pitch=", gun3.get("pitch_deg", 0.0),
		" target=", gun3.get("yaw_target_deg", 0.0))
	cannons.call("set_aim_degrees", 20.0, 10.0)
	var guns_raw: Array = cannons.get("_guns")
	print("SHIP64_FIX_RAW man=", cannons.get("_man_index"), " guns=", guns_raw.size(),
		" target=", (guns_raw[2] as Dictionary).get("yaw_target", -1.0))
	cannons.call("_process", 0.5)
	var state4: Dictionary = cannons.call("state")
	var guns_after: Array = cannons.get("_guns")
	print("SHIP64_FIX_TOP yaw=", state4.get("yaw_deg", 0.0), " target=", state4.get("yaw_target_deg", 0.0),
		" raw_target=", (guns_after[2] as Dictionary).get("yaw_target", -1.0),
		" raw_yaw=", (guns_after[2] as Dictionary).get("yaw", -1.0))
	var gun4 := _gun_state(state4, 2)
	print("SHIP64_FIX_PUMP yaw=", gun4.get("yaw_deg", 0.0), " pitch=", gun4.get("pitch_deg", 0.0),
		" target=", gun4.get("yaw_target_deg", 0.0))
	print("SHIP64_FIX_AIM yaw=", yaw0, "->", yaw1, " pitch=", pitch0, "->", pitch1)
	print("SHIP64_FIX_PROPS visible=", _visible_balls(host))
	_key(KEY_E, true)
	_key(KEY_E, false)
	for i in 90:
		await physics_frame
	print("SHIP64_FIX_LOAD loaded=", cannons.call("loaded"), " balls=", host.get("balls"),
		" props=", _visible_balls(host))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	event.pressed = true
	host.call("_unhandled_input", event)
	for i in 10:
		await physics_frame
	print("SHIP64_FIX_LEAVE station=", host.get("_station"), " hold=", player.get("_vehicle_hold"))
	# --- helm
	host.call("debug_set_station", "helm", -1)
	for i in 20:
		await physics_frame
	print("SHIP64_FIX_HELM station=", host.get("_station"), " station_hold=", player.get("_station_hold"))
	_key(KEY_A, true)
	for i in 24:
		await physics_frame
	_key(KEY_A, false)
	var ship: Dictionary = boat.call("snapshot")
	print("SHIP64_FIX_RUDDER ", ship.get("rudder"), " wheel=", _wheel_angle(host))
	# --- ladder: leave and put the player at the ladder foot.
	host.call("debug_set_station", "leave", -1)
	for i in 5:
		await physics_frame
	player.global_position = boat.call("world_deck", Vector3(0.0, 1.80, 2.30))
	for i in 10:
		await physics_frame
	var before: Vector3 = player.global_position
	_key(KEY_W, true)
	for i in 120:
		await physics_frame
	_key(KEY_W, false)
	var after: Vector3 = player.global_position
	print("SHIP64_FIX_LADDER before=", before, " after=", after, " dy=", after.y - before.y)
	print("SHIP64_FIX_OK")
	quit(0)


func _gun_state(state: Dictionary, index: int) -> Dictionary:
	var states: Array = state.get("cannon_states", [])
	if index >= 0 and index < states.size():
		return states[index] as Dictionary
	return {}


func _visible_balls(host: Node) -> int:
	var count := 0
	var props: Array = host.get("_ball_props")
	for node: Variant in props:
		var mesh := node as MeshInstance3D
		if is_instance_valid(mesh) and mesh.visible:
			count += 1
	return count


func _wheel_angle(host: Node) -> float:
	var model: Node = host.get("model")
	if is_instance_valid(model):
		return float(model.get("_wheel_angle"))
	return -999.0
