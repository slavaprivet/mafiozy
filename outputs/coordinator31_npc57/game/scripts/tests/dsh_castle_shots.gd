extends SceneTree
## Renders the castle from fixed viewpoints and saves PNGs, so the look can be judged
## instead of guessed at.

var _scene: Node
var _castle: Node3D
var _camera: Camera3D
var _out_dir := ""

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	_out_dir = OS.get_environment("DSH_SHOT_DIR")
	if _out_dir == "": _out_dir = "C:/Users/Слава/Documents/deepseek-harness/default-workspace"
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SHOTS_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	_castle = _scene.get("preview_castle")
	if _castle == null:
		print("SHOTS_FAIL no_castle"); quit(1); return
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 900.0
	_scene.add_child(_camera)
	_camera.current = true
	await _settle(30)
	var base: Vector3 = _castle.global_position
	# Outside the gate, looking at the gatehouse; then the courtyard; then a wall corner.
	var shots := [
		{"name": "gate_outside", "pos": base + Vector3(0.0, 6.0, 62.0), "look": base + Vector3(0.0, 7.0, 32.0)},
		{"name": "courtyard", "pos": base + Vector3(0.0, 8.0, 18.0), "look": base + Vector3(0.0, 12.0, -26.0)},
		{"name": "corner_tower", "pos": base + Vector3(46.0, 12.0, 46.0), "look": base + Vector3(32.0, 12.0, 32.0)},
		{"name": "wall_inside", "pos": base + Vector3(-8.0, 3.0, 6.0), "look": base + Vector3(-32.0, 9.0, 14.0)},
	]
	for shot: Dictionary in shots:
		_camera.global_position = shot["pos"]
		_camera.look_at(shot["look"], Vector3.UP)
		await _settle(12)
		var image: Image = root.get_texture().get_image()
		if image == null:
			print("SHOTS_FAIL image ", str(shot["name"])); continue
		var path := _out_dir.path_join("castle_%s.png" % str(shot["name"]))
		var error := image.save_png(path)
		print("SHOTS_SAVED ", str(shot["name"]), " err=", error, " path=", path)
	# And one after a breach, so the destruction can be seen too.
	_castle.call("apply_explosion", {"position": base + Vector3(0.0, 5.0, 32.0),
		"radius": 5.0, "power": 240.0, "direction": Vector3(0.0, 0.0, -1.0)})
	await _settle(70)
	_camera.global_position = base + Vector3(0.0, 6.0, 56.0)
	_camera.look_at(base + Vector3(0.0, 6.0, 32.0), Vector3.UP)
	await _settle(12)
	var image2: Image = root.get_texture().get_image()
	if image2 != null:
		var path2 := _out_dir.path_join("castle_breach.png")
		image2.save_png(path2)
		print("SHOTS_SAVED breach path=", path2)
	print("SHOTS_DONE")
	quit(0)