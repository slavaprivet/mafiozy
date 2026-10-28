extends SceneTree
## SHIP61 water acceptance probe (agent A).
##
## Loads the real castle map, installs ShipWaterBasin exactly the way the
## integrator will, proves the basin depths / navigation / ground collision with
## downward raycasts, and (outside --headless) writes two overview screenshots.
##
## Run headless:
##   Godot --path <game> --headless --script res://scripts/tests/ship61_water_probe.gd
## Run with shots:
##   Godot --path <game> --script res://scripts/tests/ship61_water_probe.gd

const DEFAULT_SHOT_DIR := "C:/Users/Слава/Documents/deepseek-harness/default-workspace/shots_ship61"

var _scene: Node
var _castle: Node3D
var _basin: Node3D
var _camera: Camera3D
var _out_dir := ""
var _failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(reason: String) -> void:
	_failures.append(reason)

func _has_property(object: Object, property: String) -> bool:
	if object == null:
		return false
	for entry: Dictionary in object.get_property_list():
		if str(entry.get("name", "")) == property:
			return true
	return false

func _check(condition: bool, reason: String) -> bool:
	if not condition:
		_failures.append(reason)
	return condition

func _ray_down(x: float, z: float) -> Dictionary:
	var scene_3d := _scene as Node3D
	var space: PhysicsDirectSpaceState3D = scene_3d.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, 30.0, z), Vector3(x, -20.0, z), 1)
	return space.intersect_ray(query)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("SHIP61_WATER_FAIL reason=scene_load")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	if _scene.get("preview_ready") != true:
		print("SHIP61_WATER_FAIL reason=preview_timeout")
		quit(1)
		return
	# The integrated host installs its own basin on a later physics frame. This
	# probe owns its basin, so keep the host out of the way (probe only).
	if _has_property(_scene, "_ship_install_pending"):
		_scene.set("_ship_install_pending", false)
	_castle = _scene.get("preview_castle") as Node3D
	if _castle == null:
		print("SHIP61_WATER_FAIL reason=no_castle")
		quit(1)
		return
	var basin_script: Script = load("res://scripts/ship/ship_water_basin.gd")
	if basin_script == null:
		print("SHIP61_WATER_FAIL reason=basin_script")
		quit(1)
		return
	_basin = basin_script.new() as Node3D
	if _basin == null:
		print("SHIP61_WATER_FAIL reason=basin_new")
		quit(1)
		return
	_scene.add_child(_basin)
	var installed: Dictionary = _basin.call("install", _scene, _castle)
	print("SHIP61_WATER_INSTALL_RESULT ", JSON.stringify(installed))
	if not bool(installed.get("ok", false)):
		print("SHIP61_WATER_FAIL reason=install:", installed.get("reason", "unknown"))
		quit(1)
		return
	for i in range(4):
		await physics_frame
	var depth_land: float = _basin.call("depth_at", 0.0, 988.0)
	var depth_bay: float = _basin.call("depth_at", 62.0, 988.0)
	var depth_channel: float = _basin.call("depth_at", 95.0, 900.0)
	var depth_gulf: float = _basin.call("depth_at", 200.0, 900.0)
	var depth_shore: float = _basin.call("depth_at", 79.0, 900.0)
	var depth_deep: float = _basin.call("depth_at", 200.0, 900.0)
	var depth_junction: float = _basin.call("depth_at", 90.0, 976.0)
	var navigable_junction: bool = _basin.call("is_navigable", 90.0, 976.0, 1.8)
	var navigable_bay: bool = _basin.call("is_navigable", 62.0, 988.0, 1.8)
	var navigable_land: bool = _basin.call("is_navigable", 0.0, 988.0, 1.8)
	var water_height: float = _basin.call("water_height_at", 62.0, 988.0)
	var water_level: float = _basin.call("water_level")
	var ground_gone: bool = _castle.get_node_or_null("CastleGround") == null
	var water_node: Node = _basin.get_node_or_null("ShipWater")
	var ground_node: Node = _basin.get_node_or_null("ShipShoreGround")
	var height_body: Node = _basin.get_node_or_null("ShipShoreGroundBody")
	var quay_node: Node = _basin.get_node_or_null("ShipQuayStone")
	var pier_node: Node = _basin.get_node_or_null("ShipPierTimber")
	var heightfield_shape: CollisionShape3D = null
	if height_body != null:
		for child: Node in height_body.get_children():
			if child is CollisionShape3D:
				heightfield_shape = child
				break
	var ground_hit := _ray_down(0.0, 988.0)
	var bottom_hit := _ray_down(62.0, 988.0)
	var ground_y: float = float(ground_hit.get("position", Vector3(0, 999, 0)).y) if not ground_hit.is_empty() else 999.0
	var bottom_y: float = float(bottom_hit.get("position", Vector3(0, 999, 0)).y) if not bottom_hit.is_empty() else 999.0
	var live_stats: Dictionary = _basin.call("stats")
	var snapshot: Dictionary = _basin.call("snapshot")
	var ripples_active := 0

	_check(absf(depth_land) <= 0.001, "depth_land")
	_check(depth_bay >= 5.0, "depth_bay")
	_check(depth_channel >= 5.0, "depth_channel")
	_check(depth_gulf >= 5.0, "depth_gulf")
	_check(depth_shore < 2.5, "depth_channel_shelf")
	_check(depth_junction >= 2.5, "depth_bay_channel_junction")
	_check(navigable_junction, "navigable_bay_channel_junction")
	_check(navigable_bay, "navigable_bay")
	_check(not navigable_land, "navigable_land")
	_check(absf(water_level + 0.55) <= 0.0001, "water_level")
	_check(water_height >= water_level - 0.061 and water_height <= water_level + 0.061, "water_wave")
	_check(ground_gone, "castle_ground")
	_check(water_node != null and water_node is MeshInstance3D, "water_node")
	_check(ground_node != null and ground_node is MeshInstance3D, "ground_node")
	_check(heightfield_shape != null and heightfield_shape.shape is HeightMapShape3D, "heightmap_shape")
	_check(quay_node != null and pier_node != null, "quay_or_pier")
	_check(not ground_hit.is_empty() and absf(ground_y) <= 0.65, "ground_ray")
	_check(not bottom_hit.is_empty() and bottom_y <= -6.0, "bottom_ray")
	if not _failures.is_empty():
		print("SHIP61_WATER_FAIL reason=", ",".join(_failures))
		quit(1)
		return
	if OS.get_environment("DSH_SHIP61_PERF") == "1":
		await _perf_probe()
		quit(0)
		return
	var shots_ok := true
	if DisplayServer.get_name() != "headless":
		shots_ok = await _capture_shots()
	if not shots_ok:
		print("SHIP61_WATER_FAIL reason=screenshots")
		quit(1)
		return
	# Ripple proof runs after the stills so the test event does not ring the
	# acceptance screenshot.
	_basin.call("add_ripple", Vector3(62.0, -0.55, 988.0), 1.2)
	await process_frame
	await process_frame
	live_stats = _basin.call("stats")
	ripples_active = int(live_stats.get("ripples_active", 0))
	_check(ripples_active > 0, "ripple_pool")
	if not _failures.is_empty():
		print("SHIP61_WATER_FAIL reason=", ",".join(_failures))
		quit(1)
		return
	print("SHIP61_WATER_METRICS ", JSON.stringify({
		"depth_land": depth_land, "depth_bay": depth_bay,
		"depth_channel": depth_channel, "depth_gulf": depth_gulf,
		"depth_channel_shelf_x79": depth_shore, "depth_deep": depth_deep,
		"depth_bay_channel_junction": depth_junction,
		"navigable_junction": navigable_junction,
		"navigable_bay": navigable_bay, "navigable_land": navigable_land,
		"water_height": water_height, "castle_ground_removed": ground_gone,
		"ground_ray_y": ground_y, "bottom_ray_y": bottom_y,
		"water_vertices": live_stats.get("water_vertices", 0),
		"water_triangles": live_stats.get("water_triangles", 0),
		"ground_vertices": live_stats.get("ground_vertices", 0),
		"ground_triangles": live_stats.get("ground_triangles", 0),
		"quay": live_stats.get("quay", false), "pier": live_stats.get("pier", false),
		"ripples_active": ripples_active, "snapshot": snapshot}))
	print("SHIP61_WATER_OK depth_bay=%.2f depth_channel=%.2f depth_gulf=%.2f junction=%.2f land=%.2f nav_bay=%s nav_land=%s nav_junction=%s ground_ray=%.2f bottom_ray=%.2f water_verts=%d ground_verts=%d quay=%s pier=%s ripples=%d" % [
		depth_bay, depth_channel, depth_gulf, depth_junction, depth_land, str(navigable_bay), str(navigable_land),
		str(navigable_junction), ground_y, bottom_y, int(live_stats.get("water_vertices", 0)),
		int(live_stats.get("ground_vertices", 0)), str(live_stats.get("quay", false)),
		str(live_stats.get("pier", false)), ripples_active])
	await create_timer(1.0).timeout
	quit(0)

func _perf_probe() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 700.0
	_scene.add_child(_camera)
	_camera.current = true
	_camera.global_position = Vector3(10.0, 14.0, 1012.0)
	_camera.look_at(Vector3(90.0, -2.0, 940.0), Vector3.UP)
	for frame in range(30):
		await process_frame
	var visible_ms := await _measure_frames(90)
	var names := ["ShipShoreGround", "ShipWater", "ShipQuayStone", "ShipPierTimber",
		"ShipShoreRocks", "ShipShorePlants"]
	for node_name: String in names:
		var node := _basin.get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = false
	for frame in range(20):
		await process_frame
	var hidden_ms := await _measure_frames(90)
	var perf_stats: Dictionary = _basin.call("stats")
	print("SHIP61_PERF visible_ms=%.2f hidden_ms=%.2f visible_fps=%.1f hidden_fps=%.1f ground_tris=%d water_tris=%d" % [
		visible_ms, hidden_ms, 1000.0 / maxf(visible_ms, 0.01), 1000.0 / maxf(hidden_ms, 0.01),
		int(perf_stats.get("ground_triangles", 0)), int(perf_stats.get("water_triangles", 0))])

func _measure_frames(count: int) -> float:
	var total := 0.0
	for frame in range(count):
		var start := Time.get_ticks_usec()
		await process_frame
		total += float(Time.get_ticks_usec() - start) / 1000.0
	return total / float(count)

func _capture_shots() -> bool:
	_out_dir = OS.get_environment("DSH_SHOT_DIR")
	if _out_dir.is_empty():
		_out_dir = DEFAULT_SHOT_DIR
	_out_dir = _out_dir.replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_camera = Camera3D.new()
	_camera.name = "Ship61WaterShotCamera"
	_camera.fov = 62.0
	_camera.far = 700.0
	_camera.near = 0.1
	_scene.add_child(_camera)
	_camera.current = true
	var first := await _shot("ship61_water_overview.png",
		Vector3(10.0, 14.0, 1012.0), Vector3(90.0, -2.0, 940.0))
	var second := await _shot("ship61_water_pier.png",
		Vector3(30.0, 2.2, 1002.0), Vector3(76.0, -0.2, 948.0))
	if OS.get_environment("DSH_SHIP61_EXTRA") == "1":
		await _shot("ship61_water_bay.png",
			Vector3(38.0, 4.5, 1042.0), Vector3(150.0, -1.5, 890.0))
		await _shot("ship61_water_quay.png",
			Vector3(58.0, 2.6, 992.0), Vector3(84.0, -0.4, 900.0))
		await _shot("ship61_water_quay2.png",
			Vector3(94.0, 2.8, 942.0), Vector3(78.0, 0.2, 862.0))
		await _shot("ship61_water_shore.png",
			Vector3(6.0, 3.0, 1020.0), Vector3(38.0, -0.4, 990.0))
		await _shot("ship61_water_pier2.png",
			Vector3(30.0, 2.2, 1002.0), Vector3(76.0, -0.2, 948.0))
		await _shot("ship61_water_quay3.png",
			Vector3(89.0, 2.2, 906.0), Vector3(80.0, 0.4, 898.0))
		await _shot("ship61_water_quay4.png",
			Vector3(79.0, 3.5, 954.0), Vector3(80.0, 0.2, 858.0))
		await _shot("ship61_water_quay5.png",
			Vector3(94.0, 3.2, 990.0), Vector3(79.0, 0.0, 972.0))
	return first and second

func _shot(file_name: String, from: Vector3, toward: Vector3) -> bool:
	_camera.global_position = from
	_camera.look_at(toward, Vector3.UP)
	for frame in range(40):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty():
		return false
	var path := _out_dir.path_join(file_name)
	var error: Error = picture.save_png(path)
	print("DSHOT_SAVED ", path, " error=", error, " size=", picture.get_size())
	return error == OK
