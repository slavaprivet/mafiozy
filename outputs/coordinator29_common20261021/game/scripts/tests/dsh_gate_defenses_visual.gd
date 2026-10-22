extends SceneTree
## Graphical evidence for the gate defences. Drives the postern, the stone hatch and the
## cauldron, then takes stills from outside the gate, from the hoarding and from the
## postern. Run without --headless.

const Layout = preload("res://scripts/siege/gate_defense_layout.gd")

var _game: Node
var _castle: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _out := ""


func _initialize() -> void:
	call_deferred("_run")


func _shot(label: String, from: Vector3, toward: Vector3) -> bool:
	var base := _castle.global_position
	_camera.global_position = base + from
	_camera.look_at(base + toward, Vector3.UP)
	for i: int in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var path := _out.path_join("gate_%s.png" % label)
	var error := image.save_png(path)
	print("GATE_SHOT ", JSON.stringify({"label": label, "path": path, "error": error}))
	return error == OK


func _run() -> void:
	_out = OS.get_environment("DSH_GATE_SHOTS")
	if _out.is_empty():
		_out = "res://outputs/gate_defense_shots"
	DirAccess.make_dir_recursive_absolute(_out)
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("GATE_VISUAL_FAIL scene")
		quit(1)
		return
	_game = packed.instantiate()
	root.add_child(_game)
	current_scene = _game
	var deadline := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline and _game.get("preview_ready") != true:
		await process_frame
	_castle = _game.get("preview_castle") as Node3D
	_player = _game.get("_player") as CharacterBody3D
	# The ship is installed a few frames after the castle and brings its own tutorial
	# overlay. Wait for it, then retire the overlay: the evidence is about the gate.
	for i: int in 150:
		await process_frame
	for node: Node in _game.find_children("*", "CanvasLayer", true, false):
		if String(node.name).begins_with("ShipHud"):
			(node as CanvasLayer).visible = false
	if _castle == null:
		print("GATE_VISUAL_FAIL parts")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 500.0
	_game.add_child(_camera)
	_camera.current = true
	var results: Array[bool] = []
	results.append(await _shot("outside", Vector3(-4.0, 5.0, 91.0), Vector3(0.0, 13.0, 68.0)))
	results.append(await _shot("hoarding", Vector3(0.0, 24.5, 64.0), Vector3(0.0, 20.4, 71.2)))
	results.append(await _shot("hoarding_side", Vector3(-8.0, 22.8, 74.0), Vector3(0.0, 20.3, 70.8)))
	results.append(await _shot("cauldron_close", Vector3(-1.85, 22.8, 66.6), Vector3(-1.85, 20.7, 70.4)))
	results.append(await _shot("hatch_close", Vector3(1.4, 22.8, 66.6), Vector3(1.4, 20.1, 70.6)))
	results.append(await _shot("postern", Vector3(-8.2, 1.65, 73.4), Vector3(-8.2, 1.35, 68.6)))

	# Open the postern and the hatch, then tip the cauldron, so the action is visible.
	var sally: Node3D = _castle.get("_sally_port") as Node3D
	var hatch: Node3D = _castle.get("_stone_hatch") as Node3D
	var cauldron: Node3D = _castle.get("_gate_cauldron") as Node3D
	if sally != null:
		_player.global_position = _castle.to_global(Vector3(-8.2, 0.25, 67.0))
		await physics_frame
		var action: Dictionary = _castle.call("interaction_action")
		_castle.call("interact_castle", action)
		for i: int in 120:
			await physics_frame
		results.append(await _shot("postern_open", Vector3(-8.2, 1.8, 72.8),
			Vector3(-8.2, 1.2, 68.2)))
	if hatch != null:
		_player.global_position = _castle.to_global(Layout.LEVER_POS + Vector3(0.0, 0.25, 0.0))
		await physics_frame
		var action: Dictionary = _castle.call("interaction_action")
		_castle.call("interact_castle", action)
		for i: int in 60:
			await physics_frame
	if cauldron != null:
		var z := float(cauldron.call("get_stats").get("z", Layout.CAULDRON_START.z))
		for i: int in 90:
			_player.global_position = _castle.to_global(Vector3(Layout.CAULDRON_START.x,
				Layout.FLOOR_Y + 0.25, z - 0.86))
			_player.velocity = Vector3(0.0, 0.0, 2.0)
			cauldron.call("_physics_process", 0.05)
			z = float(cauldron.call("get_stats").get("z", z))
		for i: int in 110:
			await physics_frame
	results.append(await _shot("action_outside", Vector3(-5.0, 8.0, 86.0), Vector3(0.0, 10.0, 69.5)))
	results.append(await _shot("action_top", Vector3(0.0, 24.0, 64.5), Vector3(0.0, 20.0, 71.5)))
	print("GATE_VISUAL ", JSON.stringify({"pass": not results.has(false), "shots": results.size()}))
	await create_timer(1.5).timeout
	quit(0 if not results.has(false) else 1)
