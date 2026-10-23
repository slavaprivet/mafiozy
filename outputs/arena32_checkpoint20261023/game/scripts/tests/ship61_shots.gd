extends SceneTree
## SHIP61 screenshot pass (agent E / QA), windowed renderer.
##
## Produces the visual evidence for the ship battle:
##   ship61_hud.png        - the HUD over a harbour view with a synthetic state
##   ship61_01_bay.png     - the bay and the castle from the shore
##   ship61_02_pier.png    - the ship from the pier
##   ship61_03_helm.png    - the deck from the helm
##   ship61_04_cabin.png   - the cabin with the ammo/board crates
##   ship61_05_cannon.png  - the gun station with the aiming reticle
##   ship61_06_volley.png  - a broadside just after firing
##   ship61_07_flood.png   - flooding / settling waterline
##
## The host is owned by the integrator. When it is absent the probe still saves the
## synthetic HUD shot, then prints SHIP61_SHOTS_MISSING_HOST and exits with code 2.
##
## Run (never headless):
##   & '...\Godot_v4.7.2-stable_win64.exe' --path '...\game' `
##     --script res://scripts/tests/ship61_shots.gd

var _scene: Node = null
var _castle: Node = null
var _host: Node = null
var _camera: Camera3D = null
var _out_dir := ""
var _saved := 0
var _skipped: Array[String] = []

func _initialize() -> void:
	_run()

func _run() -> void:
	_out_dir = OS.get_environment("DSH_SHOT_DIR")
	if _out_dir.is_empty():
		_out_dir = "C:/Users/Слава/Documents/deepseek-harness/default-workspace/shots_ship61"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("SHIP61_SHOTS_START dir=", _out_dir)

	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SHIP61_SHOTS_FAIL scene_missing")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true:
			break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("SHIP61_SHOTS_FAIL preview_ready_timeout")
		quit(1)
		return
	_castle = _scene.get("preview_castle")
	_camera = Camera3D.new()
	_camera.name = "Ship61ShotCamera"
	_camera.fov = 64.0
	_camera.near = 0.05
	_camera.far = 900.0
	_scene.add_child(_camera)
	_camera.current = true
	await _settle(20)

	# The host may be installed right after preview_ready.
	var host_deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < host_deadline:
		_host = _scene.get("preview_ship")
		if is_instance_valid(_host):
			break
		await process_frame

	var host_hud := _host_hud()
	var host_hud_visible := true
	if is_instance_valid(host_hud):
		host_hud_visible = (host_hud as CanvasLayer).visible
		(host_hud as CanvasLayer).visible = false
	await _hud_showcase()
	if is_instance_valid(host_hud):
		(host_hud as CanvasLayer).visible = host_hud_visible

	# The synthetic HUD frame can be regenerated alone while the other ship modules
	# are still being written: -- --hud-only
	if OS.get_cmdline_user_args().has("--hud-only"):
		print("SHIP61_SHOTS_HUD_ONLY saved=%d" % _saved)
		quit(0)
		return

	if not is_instance_valid(_host):
		print("SHIP61_SHOTS_MISSING_HOST")
		quit(2)
		return
	print("SHIP61_SHOTS_HOST name=", str(_host.name))

	# ------------------------------------------------------------ 1. bay/castle
	_camera.global_position = Vector3(58.0, 9.0, 1062.0)
	_camera.look_at(Vector3(8.0, 10.0, 938.0), Vector3.UP)
	await _settle(6)
	_save("ship61_01_bay.png")

	# ------------------------------------------------------------ ship geometry
	var boat := _host.get("boat") as Node3D
	var ship_position := _ship_position()
	var ship_basis := Basis.IDENTITY
	if is_instance_valid(boat):
		ship_position = boat.global_position
		ship_basis = boat.global_transform.basis.orthonormalized()
	var side_dir := ship_basis.x.normalized()
	if side_dir.length_squared() < 0.01:
		side_dir = Vector3.RIGHT
	var aft_dir := ship_basis.z.normalized()
	if aft_dir.length_squared() < 0.01:
		aft_dir = Vector3.BACK
	print("SHIP61_SHOTS_SHIP pos=", ship_position, " boat=", is_instance_valid(boat))

	# ------------------------------------------------------------ 2. from pier
	var pier_eye := ship_position + Vector3(-17.0, 5.6, 14.0)
	_camera.global_position = pier_eye
	_camera.look_at(ship_position + Vector3.UP * 3.2, Vector3.UP)
	await _settle(6)
	_save("ship61_02_pier.png")

	# ------------------------------------------------------------ 3. helm deck
	var helm_world := ship_position + Vector3.UP * 4.75 + aft_dir * 10.4
	if is_instance_valid(boat) and boat.has_method("world_helm"):
		helm_world = boat.call("world_helm") + Vector3.UP * 1.7
	_camera.global_position = helm_world
	var helm_look := ship_position + Vector3.UP * 3.4 - aft_dir * 8.0
	if is_instance_valid(boat):
		helm_look = boat.to_global(Vector3(0.0, 2.4, -6.0))
	_camera.look_at(helm_look, Vector3.UP)
	await _settle(6)
	_save("ship61_03_helm.png")

	# ------------------------------------------------------------ 4. cabin/crates
	var cabin_eye := ship_position + Vector3.UP * 1.55 + aft_dir * 7.2
	var cabin_look := ship_position + Vector3.UP * 0.95 + aft_dir * 11.4
	if is_instance_valid(boat):
		cabin_eye = boat.to_global(Vector3(0.0, 1.55, 7.1))
		cabin_look = boat.to_global(Vector3(0.0, 0.95, 11.6))
	_camera.global_position = cabin_eye
	_camera.look_at(cabin_look, Vector3.UP)
	await _settle(6)
	_save("ship61_04_cabin.png")

	# ------------------------------------------------------------ 5. gun station
	await _take_ammo(1)
	_man_cannon(0)
	await _settle(3)
	await _load_gun(0)
	_cannon_call(["set_aim_degrees"], [0.0, 9.0])
	await _settle(2)
	var cannon_state := _cannon_state()
	if cannon_state.is_empty():
		cannon_state = {"manning": true, "index": 0, "side": "port", "loaded": true, "pitch": 9.0, "yaw": 0.0}
	_apply_cannon_hud(cannon_state)
	await _settle(3)
	var gun_eye := ship_position + Vector3.UP * 4.9 - side_dir * 3.4 + aft_dir * 2.6
	var gun_look := ship_position + Vector3.UP * 2.0 - side_dir * 14.0 + aft_dir * 2.0
	if is_instance_valid(boat):
		gun_eye = boat.to_global(Vector3(-1.4, 3.45, -1.2))
		gun_look = boat.to_global(Vector3(-10.0, 2.1, -4.2))
	_camera.global_position = gun_eye
	_camera.look_at(gun_look, Vector3.UP)
	_camera.current = true
	await _settle(8)
	_save("ship61_05_cannon.png")

	# ------------------------------------------------------------ 6. broadside
	_fire_gun()
	await _settle(2)
	await _take_ammo(1)
	_man_cannon(1)
	await _settle(2)
	await _load_gun(1)
	_fire_gun()
	await _settle(3)
	_apply_cannon_hud(_cannon_state())
	_camera.global_position = ship_position + side_dir * 20.0 + Vector3.UP * 10.0 + aft_dir * 6.0
	_camera.look_at(ship_position + Vector3.UP * 2.4, Vector3.UP)
	_camera.current = true
	await _settle(3)
	_save("ship61_06_volley.png")

	# ------------------------------------------------------------ 7. flooding
	_hit_ship(5)
	await _settle(4)
	Engine.time_scale = 2.0
	await _wait_real(7.0)
	Engine.time_scale = 1.0
	_refresh_hud_from_snapshot()
	await _settle(4)
	_camera.global_position = ship_position - side_dir * 19.0 + Vector3.UP * 3.4 + aft_dir * 4.0
	_camera.look_at(ship_position + Vector3.UP * 1.0, Vector3.UP)
	_camera.current = true
	await _settle(6)
	_save("ship61_07_flood.png")
	var snapshot := _snapshot()
	var ship_state: Dictionary = _sub(snapshot, ["ship"])
	print("SHIP61_SHOTS_FLOOD flooding=", ship_state.get("flooding"), " integrity=", ship_state.get("integrity"))

	if not _skipped.is_empty():
		print("SHIP61_SHOTS_SKIPPED ", JSON.stringify(_skipped))
	print("SHIP61_SHOTS_OK saved=%d" % _saved)
	quit(0)

## ---------------------------------------------------------------- HUD shot

func _hud_showcase() -> void:
	var hud_script: Script = load("res://scripts/ship/ship_hud.gd")
	if hud_script == null:
		print("SHIP61_SHOTS_FAIL hud_script")
		return
	var hud: CanvasLayer = hud_script.new()
	hud.name = "Ship61FakeHud"
	_scene.add_child(hud)
	hud.call("install", null)
	# The synthetic state is judged on its own: silence every other HUD layer
	# (horse health, weapon panel, FPS plate) for this single frame.
	var hidden_layers: Array = []
	var all_layers: Array = []
	_collect_canvas_layers(_scene, all_layers)
	for layer_node: Variant in all_layers:
		var canvas := layer_node as CanvasLayer
		if canvas == hud:
			continue
		hidden_layers.append([canvas, canvas.visible])
		canvas.visible = false
	var fake_state := {
		"water": {"depth": 4.2},
		"ship": {
			"speed": 3.4,
			"sails_open": true,
			"integrity": 0.72,
			"flooding": 0.18,
			"position": Vector3(62.0, -0.55, 988.0),
			"sunk": false,
		},
		"cannons": {
			"manning": true,
			"index": 1,
			"side": "port",
			"loaded": true,
			"pitch": 12.0,
			"yaw": -4.0,
		},
		"hud": {"balls": 6, "boards": 3},
	}
	hud.call("update_state", fake_state)
	hud.call("set_cannon", fake_state["cannons"])
	hud.call("message", "Паруса раскрыты", 8.0)
	hud.call("message", "Ядро загружено", 8.0)
	# Background: the bay and the castle, so the synthetic HUD is judged in context.
	_camera.global_position = Vector3(58.0, 9.0, 1062.0)
	_camera.look_at(Vector3(8.0, 10.0, 938.0), Vector3.UP)
	_camera.current = true
	await _settle(12)
	_save("ship61_hud.png")
	for entry: Array in hidden_layers:
		(entry[0] as CanvasLayer).visible = bool(entry[1])
	hud.call("dispose")
	hud.queue_free()

func _collect_canvas_layers(node: Node, out: Array) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			out.append(child)
		_collect_canvas_layers(child, out)

## ---------------------------------------------------------------- host API

func _host_hud() -> CanvasLayer:
	if not is_instance_valid(_host):
		return null
	var hud: Variant = _host.get("hud")
	if hud is CanvasLayer:
		return hud
	return null

func _snapshot() -> Dictionary:
	if is_instance_valid(_host) and _host.has_method("snapshot"):
		var state: Variant = _host.call("snapshot")
		if state is Dictionary:
			return state
	return {}

func _ship_position() -> Vector3:
	var ship: Dictionary = _sub(_snapshot(), ["ship"])
	var position: Variant = ship.get("position")
	if position is Vector3:
		return position
	return Vector3(62.0, -0.55, 988.0)

func _cannon_state() -> Dictionary:
	if is_instance_valid(_host):
		var cannons: Variant = _host.get("cannons")
		if is_instance_valid(cannons) and (cannons as Node).has_method("state"):
			var state: Variant = (cannons as Node).call("state")
			if state is Dictionary:
				return state
		var snapshot: Dictionary = _sub(_snapshot(), ["cannons"])
		if not snapshot.is_empty():
			return snapshot
	return {}

func _apply_cannon_hud(state_value: Dictionary) -> void:
	if not is_instance_valid(_host):
		return
	var hud: Variant = _host.get("hud")
	if is_instance_valid(hud) and (hud as Node).has_method("set_cannon"):
		(hud as Node).call("set_cannon", state_value)

func _refresh_hud_from_snapshot() -> void:
	if not is_instance_valid(_host):
		return
	var hud: Variant = _host.get("hud")
	if is_instance_valid(hud) and (hud as Node).has_method("update_state"):
		(hud as Node).call("update_state", _snapshot())

func _man_cannon(index: int) -> bool:
	# debug_set_station mirrors the real F interaction: host station, player pose,
	# cannon manning and the HUD overlay all move together.
	if is_instance_valid(_host) and _host.has_method("debug_set_station"):
		var current: Dictionary = _cannon_state()
		if int(current.get("index", -1)) != index:
			_host.call("debug_set_station", "cannon", index)
		return true
	if is_instance_valid(_host) and _host.has_method("interact"):
		_host.call("interact", {"kind": "ship_cannon", "index": index})
		return true
	var call := _cannon_call(["man"], [index])
	return bool(call.get("ok", false))

func _take_ammo(count: int) -> void:
	for i: int in maxi(1, count):
		var action: Dictionary = _call_on(_host, ["interact"], ["ship_ammo"])
		if not action.get("ok", false):
			_skipped.append("ship_ammo")
			return
		await _wait_real(0.85)

func _load_gun(index: int) -> bool:
	var current: Dictionary = _cannon_state()
	if int(current.get("index", -1)) != index:
		_man_cannon(index)
		await _settle(3)
	# The host owns the stores: _load_manning_cannon spends one ball and starts
	# the 1.2 s loading animation; the direct cannon call is a fallback only.
	var call: Dictionary = _call_on(_host, ["_load_manning_cannon"], [])
	if not call.get("ok", false):
		call = _cannon_call(["load_ball", "load", "reload"], [])
	if not call.get("ok", false):
		_skipped.append("load_ball")
		return false
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		var state: Dictionary = _cannon_state()
		if bool(state.get("loaded", false)):
			return true
		await process_frame
	_skipped.append("cannon_not_loaded")
	return false

func _fire_gun() -> void:
	var call: Dictionary = _call_on(_host, ["_fire_manning_cannon"], [])
	if not call.get("ok", false):
		_cannon_call(["fire", "shoot"], [])

func _hit_ship(count: int) -> void:
	if _host.has_method("debug_hit_ship"):
		_host.call("debug_hit_ship", count)
		return
	var boat: Variant = _host.get("boat")
	if is_instance_valid(boat) and (boat as Node).has_method("apply_hit"):
		for i: int in count:
			var side := ship_side_vector()
			(boat as Node).call("apply_hit", (boat as Node3D).global_position + side * 4.0 + Vector3.UP * 0.4,
				55.0, -side * 2.0, "cannonball")
		return
	_skipped.append("debug_hit_ship")
	print("SKIP debug_hit_ship (host has no debug_hit_ship and boat has no apply_hit)")

func ship_side_vector() -> Vector3:
	var boat: Node3D = null
	if is_instance_valid(_host):
		boat = _host.get("boat") as Node3D
	if is_instance_valid(boat):
		return boat.global_transform.basis.x.normalized()
	return Vector3.RIGHT

func _cannon_call(names: Array, args: Array) -> Dictionary:
	var targets: Array = []
	if is_instance_valid(_host):
		targets.append(_host)
	if is_instance_valid(_host):
		targets.append(_host.get("cannons"))
		targets.append(_host.get("boat"))
	for target: Variant in targets:
		if not is_instance_valid(target):
			continue
		for name: String in names:
			if (target as Node).has_method(name):
				var result: Variant = (target as Node).callv(name, args)
				return {"ok": true, "method": name, "result": result}
	return {"ok": false}

func _call_on(target: Node, names: Array, args: Array) -> Dictionary:
	if not is_instance_valid(target):
		return {"ok": false}
	for name: String in names:
		if target.has_method(name):
			return {"ok": true, "result": target.callv(name, args)}
	return {"ok": false}

## ---------------------------------------------------------------- utils

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _wait_real(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _save(file_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("DSHOT_FAIL ", file_name, " image=null")
		return
	var path := _out_dir.path_join(file_name)
	var error := image.save_png(path)
	if error == OK:
		_saved += 1
		print("DSHOT_SAVED ", path)
	else:
		print("DSHOT_FAIL ", path, " err=", error)

func _sub(source: Dictionary, keys: Array) -> Dictionary:
	for key: String in keys:
		var value: Variant = source.get(key)
		if value is Dictionary:
			return value
	return {}
