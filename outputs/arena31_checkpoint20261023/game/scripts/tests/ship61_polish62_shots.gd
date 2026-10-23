extends SceneTree
## SHIP62 polish screenshots (agent Q / QA), windowed renderer, 1600x900.
##
## Boots the real castle scene and photographs the polished ship:
##   01 side      - hull, live rigging and flags, dark underwater planking
##   02 bow       - bowsprit, jib/ensign, head rigging
##   03 deck      - main deck from the helm
##   04 cabin     - the stern cabin stores
##   05 shot      - muzzle flash, smoke and barrel recoil
##   06 flight    - the ball in mid-air with its trail
##   07 wall_hit  - a small cannonball breach in the castle wall (dust + bricks)
##   08 wake      - the V wake / foam while under sail
##   09 overview  - the ship and the castle from the bay
##
## The same script produces the "before" baseline: pass `-- --before` (or `--tag=NAME`).
## Files: <tag>_01_side.png ... in DSH_SHOT_DIR or .../default-workspace/shots_ship62.
##
## Run WITHOUT --headless:
##   & 'C:\Users\Слава\AppData\Local\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe' `
##     --path 'D:\MafioziCombat31\ship_polish62\game' --resolution 1600x900 `
##     --script res://scripts/tests/ship61_polish62_shots.gd [-- --before]

const OUT_DEFAULT := "C:/Users/Слава/Documents/deepseek-harness/default-workspace/shots_ship62"
const SHOT_W := 1600
const SHOT_H := 900
const LOAD_DEADLINE_MS := 240000
const HOST_WAIT_MS := 30000

var _scene: Node = null
var _castle: Node = null
var _host: Node = null
var _boat: Node3D = null
var _model: Node3D = null
var _cannons: Node = null
var _hud_layers: Array = []
var _camera: Camera3D = null
var _out_dir := ""
var _tag := "after"
var _saved := 0
var _saved_names: Array[String] = []
var _failed := 0
## `--only=05,06` re-renders a subset of frames without touching the rest.
var _only: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--before":
			_tag = "before"
		elif argument.begins_with("--tag="):
			_tag = argument.trim_prefix("--tag=")
			if _tag.is_empty():
				_tag = "after"
		elif argument.begins_with("--only="):
			for token: String in argument.trim_prefix("--only=").split(",", false):
				var clean := token.strip_edges()
				if not clean.is_empty():
					_only.append(clean)
	_out_dir = OS.get_environment("DSH_SHOT_DIR")
	if _out_dir.is_empty():
		_out_dir = OUT_DEFAULT
	if _out_dir.ends_with("/") or _out_dir.ends_with("\\"):
		_out_dir = _out_dir.substr(0, _out_dir.length() - 1)
	var make_error := DirAccess.make_dir_recursive_absolute(_out_dir)
	print("SHIP62_SHOTS_START tag=", _tag, " dir=", _out_dir,
		" make_dir=", make_error, " renderer=", RenderingServer.get_current_rendering_method())

	# 1600x900 output even though the project ships a 1280x720 viewport.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i(SHOT_W, SHOT_H)
	root.size = Vector2i(SHOT_W, SHOT_H)
	DisplayServer.window_set_size(Vector2i(SHOT_W, SHOT_H))

	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SHIP62_SHOTS_FAIL scene_missing")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + LOAD_DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true:
			break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("SHIP62_SHOTS_FAIL preview_ready_timeout")
		quit(1)
		return
	_castle = _scene.get("preview_castle") as Node
	var host_deadline := Time.get_ticks_msec() + HOST_WAIT_MS
	while Time.get_ticks_msec() < host_deadline:
		_host = _scene.get("preview_ship") as Node
		if is_instance_valid(_host):
			break
		await process_frame
	if not is_instance_valid(_host):
		print("SHIP62_SHOTS_MISSING_HOST status=", str(_scene.get("ship_status")))
		quit(2)
		return
	_boat = _host.get("boat") as Node3D
	_model = _host.get("model") as Node3D
	_cannons = _host.get("cannons") as Node
	print("SHIP62_SHOTS_HOST name=", str(_host.name), " boat=", is_instance_valid(_boat),
		" model=", is_instance_valid(_model), " cannons=", is_instance_valid(_cannons))

	_camera = Camera3D.new()
	_camera.name = "Ship62ShotCamera"
	_camera.fov = 55.0
	_camera.near = 0.05
	_camera.far = 1200.0
	_scene.add_child(_camera)
	_camera.current = true
	_hide_hud()
	if _boat.has_method("set_autopilot"):
		_boat.call("set_autopilot", false)
	_boat.call("set_sails", false)
	await _settle(30)
	await _wait_real(0.5)
	var viewport_size: Vector2i = root.get_texture().get_size()
	print("SHIP62_SHOTS_VIEWPORT size=", viewport_size, " window=", root.size)

	# ----------------------------------------------------------- 1..4 hull/deck
	await _shot_local("01_side", _side_camera(), Vector3(0.0, 3.8, 0.0), 58.0)
	await _shot_local("02_bow", Vector3(8.5, 5.8, -22.0), Vector3(0.0, 3.8, -10.0), 55.0)
	await _shot_local("03_deck", Vector3(0.8, 4.9, 8.2), Vector3(0.0, 2.5, -9.0), 64.0)
	await _shot_local("04_cabin", Vector3(0.3, 1.60, 7.1), Vector3(0.0, 0.95, 11.7), 74.0)

	# ----------------------------------------------------------- 5..7 one real shot
	# debug_fire_at() solves the aim and fires without touching the ammo store: the
	# same ball gives the flash frame, the flight frame and the breach frame.
	var wall_point := Vector3(58.0, 6.0, 968.0)
	_view_local(Vector3(-14.0, 4.6, 2.0), Vector3(-4.0, 2.6, 0.5), 62.0)
	await _settle(6)
	var fired: Dictionary = _dict(_cannons.call("debug_fire_at", wall_point))
	print("SHIP62_SHOTS_FIRE ok=", fired.get("ok", false), " index=", fired.get("index", -1),
		" yaw=", fired.get("yaw_deg", 0.0), " pitch=", fired.get("pitch_deg", 0.0),
		" from=", fired.get("from", Vector3.ZERO))
	var impact: Dictionary = {}
	if bool(fired.get("ok", false)):
		# Leave the gun at once: this hides the green aim dots without touching the
		# flash/smoke/recoil, so the frame shows the effect and not the sight markers.
		_cannons.call("leave")
		# The flash lasts 0.08 s: capture the very next drawn frame.
		await _save("05_shot")
		await _wait_real(0.16)
		var ball: Node = _active_ball()
		if is_instance_valid(ball):
			var ball_pos: Vector3 = (ball as Node3D).global_position
			var velocity: Variant = ball.get("velocity")
			var direction := Vector3.FORWARD
			if velocity is Vector3:
				direction = (velocity as Vector3).normalized()
			if direction.length_squared() < 0.01:
				direction = Vector3.FORWARD
			var side := direction.cross(Vector3.UP).normalized()
			if side.length_squared() < 0.01:
				side = Vector3.RIGHT
			_camera.fov = 44.0
			_camera.global_position = ball_pos - direction * 6.0 + side * 4.0 + Vector3.UP * 2.4
			_camera.look_at(ball_pos + direction * 9.0, Vector3.UP)
			_camera.current = true
			await _settle(1)
			await _save("06_flight")
		else:
			_skip_shot("06_flight", "no active ball at 0.16 s")
		impact = await _wait_impact(4.0)
		if not impact.is_empty():
			var hit_at: Vector3 = impact.get("position", Vector3(0.0, 5.0, 968.0))
			_camera.fov = 50.0
			_camera.global_position = hit_at + Vector3(0.0, 3.5, 11.0)
			_camera.look_at(hit_at + Vector3(0.0, 0.6, 0.0), Vector3.UP)
			_camera.current = true
			await _settle(3)
			await _save("07_wall_hit")
			print("SHIP62_SHOTS_IMPACT type=", impact.get("type", ""),
				" at=", impact.get("position", Vector3.ZERO))
		else:
			_skip_shot("07_wall_hit", "no castle impact within 4 s")
	else:
		_skip_shot("05_shot", "debug_fire_at refused: " + str(fired.get("reason", "")))
		_skip_shot("06_flight", "no shot")
		_skip_shot("07_wall_hit", "no shot")

	# ----------------------------------------------------------- 8. wake
	_boat.call("moor", Vector3(58.0, _water_level(), 994.0), deg_to_rad(-90.0))
	_boat.call("set_sails", true)
	if _boat.has_method("set_autopilot"):
		_boat.call("set_autopilot", true)
	await _wait_real(9.0)
	var sail_state: Dictionary = _dict(_boat.call("snapshot"))
	print("SHIP62_SHOTS_SAIL speed=", sail_state.get("speed", 0.0),
		" wake=", sail_state.get("wake_strength", "n/a"),
		" bow=", sail_state.get("bow_wave", "n/a"))
	_view_local(Vector3(0.0, 10.0, 34.0), Vector3(0.0, 0.0, 6.0), 62.0)
	await _settle(4)
	await _save("08_wake")

	# ----------------------------------------------------------- 9. overview
	_view_world_offset(Vector3(56.0, 30.0, 46.0), Vector3(0.0, 4.0, 0.0), 56.0)
	await _settle(6)
	await _save("09_overview")

	if _boat.has_method("set_autopilot"):
		_boat.call("set_autopilot", false)
	_boat.call("set_sails", false)
	_show_hud()
	var expected := 9
	if _saved >= expected or (not _only.is_empty() and _saved > 0 and _failed == 0):
		print("SHIP62_SHOTS_OK tag=", _tag, " saved=", _saved, "/", expected, " names=",
			JSON.stringify(_saved_names), " dir=", _out_dir)
		quit(0)
	else:
		print("SHIP62_SHOTS_FAIL tag=", _tag, " saved=", _saved, "/", expected,
			" failed=", _failed, " names=", JSON.stringify(_saved_names))
		quit(1)


## ------------------------------------------------------------------ shot helpers
func _wait_impact(max_seconds: float) -> Dictionary:
	var deadline := Time.get_ticks_msec() + int(max_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var state: Dictionary = _dict(_cannons.call("state"))
		var impact: Dictionary = _dict(state.get("last_impact"))
		if not impact.is_empty() and int(state.get("balls_active", 0)) == 0 \
				and str(impact.get("type", "")) == "castle":
			return impact
	return {}


func _active_ball() -> Node:
	if not is_instance_valid(_cannons):
		return null
	var balls: Variant = _cannons.get("_balls")
	if balls is Array:
		for item: Variant in (balls as Array):
			if is_instance_valid(item) and bool((item as Node).get("active")):
				return item as Node
	return null


## ------------------------------------------------------------------ cameras
func _side_camera() -> Vector3:
	# The ship is moored against the castle's south wall, so the open-water side is
	# the one whose beam vector points south (+Z). Shooting from the castle side puts
	# the camera inside the wall and the frame becomes solid masonry.
	var side := 1.0
	if is_instance_valid(_boat):
		if (_boat.global_basis.x as Vector3).normalized().z < 0.0:
			side = -1.0
	return Vector3(33.0 * side, 5.4, 2.0)


func _sun() -> DirectionalLight3D:
	var stack: Array[Node] = [_scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		if node is DirectionalLight3D and (node as DirectionalLight3D).visible:
			return node as DirectionalLight3D
	return null


func _view_local(local_position: Vector3, local_look: Vector3, fov: float) -> void:
	if not is_instance_valid(_boat):
		return
	_camera.fov = fov
	_camera.global_position = _boat.to_global(local_position)
	_camera.look_at(_boat.to_global(local_look), Vector3.UP)
	_camera.current = true


func _view_world_offset(offset: Vector3, look_offset: Vector3, fov: float) -> void:
	if not is_instance_valid(_boat):
		return
	var origin: Vector3 = _boat.global_position
	_camera.fov = fov
	_camera.global_position = origin + offset
	_camera.look_at(origin + look_offset, Vector3.UP)
	_camera.current = true


func _shot_local(name: String, local_position: Vector3, local_look: Vector3, fov: float) -> void:
	_view_local(local_position, local_look, fov)
	await _settle(8)
	await _save(name)


## ------------------------------------------------------------------ utilities
func _skip_shot(name: String, why: String) -> void:
	_failed += 1
	print("DSHOT_SKIP ", name, " reason=", why)


func _save(name: String) -> void:
	if not _only.is_empty():
		var matched := false
		for token: String in _only:
			if name.contains(token):
				matched = true
				break
		if not matched:
			print("DSHOT_FILTERED ", name)
			return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		_failed += 1
		print("DSHOT_FAIL ", name, " image=null")
		return
	var file_name := "%s_%s.png" % [_tag, name]
	var path := _out_dir.path_join(file_name)
	var error := image.save_png(path)
	if error == OK:
		_saved += 1
		_saved_names.append(file_name)
		print("DSHOT_SAVED ", path, " size=", image.get_width(), "x", image.get_height())
	else:
		_failed += 1
		print("DSHOT_FAIL ", path, " err=", error)


func _hide_hud() -> void:
	_hud_layers.clear()
	_collect_canvas_layers(_scene, _hud_layers)
	for entry: Array in _hud_layers:
		(entry[0] as CanvasLayer).visible = false


func _show_hud() -> void:
	for entry: Array in _hud_layers:
		if is_instance_valid(entry[0]):
			(entry[0] as CanvasLayer).visible = bool(entry[1])


func _collect_canvas_layers(node: Node, out: Array) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			out.append([child, (child as CanvasLayer).visible])
		_collect_canvas_layers(child, out)


func _water_level() -> float:
	var basin: Variant = _host.get("basin")
	if is_instance_valid(basin) and (basin as Node).has_method("water_level"):
		return float((basin as Node).call("water_level"))
	return -0.55


func _settle(frames: int) -> void:
	for _i: int in frames:
		await process_frame


func _wait_real(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
