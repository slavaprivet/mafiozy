extends SceneTree
## DSH_CASTLE: is the stone actually held by the man's arms?
## Renders the player carrying it from a close third-person camera.

var _scene: Node
var _player: CharacterBody3D
var _catapult: Node3D
var _castle: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var out_dir: String = OS.get_environment("DSH_SHOT_DIR")
	if out_dir == "": out_dir = "C:/Users/Слава/Documents/deepseek-harness/default-workspace"
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null: print("CARRY_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_player = _scene.get("_player")
	_catapult = _scene.get("preview_catapult")
	_castle = _scene.get("preview_castle")
	if _player == null or _catapult == null or _castle == null:
		print("CARRY_FAIL missing"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(30)
	# Take the stone into his arms the way the game does.
	_catapult.call("_try_interact")
	await _settle(20)
	if not bool(_catapult.get("_carrying_stone")):
		# Put him next to the stone and try again.
		var stone: Variant = _catapult.get("_stone")
		if is_instance_valid(stone):
			_player.global_position = (stone as Node3D).global_position + Vector3(1.0, 0.05, 1.0)
		await _settle(10)
		_catapult.call("_try_interact")
		await _settle(20)
	print("CARRY_STATE carrying=", _catapult.get("_carrying_stone"))
	var camera := Camera3D.new()
	camera.fov = 50.0
	_scene.add_child(camera)
	camera.current = true
	var basis: Basis = _player._visual.global_basis
	camera.global_position = _player.global_position + basis.z * 2.6 + Vector3.UP * 1.4 \
		+ basis.x * 1.1
	camera.look_at(_player.global_position + Vector3.UP * 1.1, Vector3.UP)
	await _settle(20)
	var image: Image = root.get_texture().get_image()
	if image != null:
		var path: String = out_dir.path_join("castle_carry.png")
		image.save_png(path)
		print("CARRY_SAVED ", path)
	print("CARRY_DONE")
	quit(0)