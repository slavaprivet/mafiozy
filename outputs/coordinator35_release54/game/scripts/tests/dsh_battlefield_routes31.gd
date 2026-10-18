extends SceneTree
## Physics acceptance for the castle gate, central battlefield road and both flanks.
## Run on an isolated D: copy through tools/godot/test_scheduler.py.

const GRID_STEP := 4.0
const GRID_MIN_X := -20
const GRID_MAX_X := 20
const GRID_MIN_Z := 0
const GRID_MAX_Z := 42
const GRID_ORIGIN_Z := 80.0

var _scene: Node
var _castle: Node3D
var _battlefield: Node3D
var _capsule := CapsuleShape3D.new()
var _clear_cache: Dictionary = {}
var _blockers: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _has_property(object: Object, name: String) -> bool:
	for item: Dictionary in object.get_property_list():
		if String(item.get("name", "")) == name:
			return true
	return false

func _install_if_needed() -> bool:
	if _has_property(_scene, "preview_battlefield"):
		_battlefield = _scene.get("preview_battlefield") as Node3D
	if _battlefield != null:
		return true
	var script: GDScript = load("res://scripts/city/battlefield_site.gd") as GDScript
	if script == null:
		return false
	_battlefield = script.new() as Node3D
	if _battlefield == null:
		return false
	_castle.add_child(_battlefield)
	var result: Dictionary = _battlefield.call("install", _scene, _castle)
	if not bool(result.get("ok", true)):
		print("BATTLEFIELD_ROUTES_INSTALL_FAIL ", JSON.stringify(result))
		return false
	var props_script: GDScript = load("res://scripts/city/battlefield_props.gd") as GDScript
	if props_script != null:
		var props: Node3D = props_script.new() as Node3D
		if props != null:
			_battlefield.add_child(props)
			var props_result: Dictionary = props.call("install", _castle)
			if not bool(props_result.get("ok", true)):
				print("BATTLEFIELD_PROPS_INSTALL_FAIL ", JSON.stringify(props_result))
				return false
	return true

func _capsule_clear(local_x: float, local_z: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	var terrain_y := 0.0
	if _battlefield.has_method("terrain_height"):
		terrain_y = maxf(0.0, float(_battlefield.call("terrain_height", local_x, local_z)))
	# The pre-existing outer gate apron rises 8 cm above datum. Its top is a
	# walkable floor, so keep the static clearance capsule above that surface.
	query.transform = Transform3D(Basis(), _castle.global_position + Vector3(local_x, terrain_y + 1.02, local_z))
	query.collision_mask = 1
	query.collide_with_areas = false
	var hits: Array[Dictionary] = root.world_3d.direct_space_state.intersect_shape(query, 8)
	if not hits.is_empty() and absf(local_x) < 0.1:
		var names: Array[String] = []
		for hit: Dictionary in hits:
			var collider: Object = hit.get("collider")
			names.append(String(collider.get_path()) if collider is Node else str(collider))
		_blockers[str(local_z)] = names
	return hits.is_empty()

func _point(key: Vector2i) -> Vector2:
	return Vector2(float(key.x) * GRID_STEP, GRID_ORIGIN_Z + float(key.y) * GRID_STEP)

func _clear(key: Vector2i) -> bool:
	if not _clear_cache.has(key):
		var point := _point(key)
		_clear_cache[key] = _capsule_clear(point.x, point.y)
	return bool(_clear_cache[key])

func _route(start: Vector2i, goal: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var index := 0
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while index < queue.size():
		var key: Vector2i = queue[index]
		index += 1
		if key == goal:
			return {"ok": true, "visited": visited.size(), "checks": _clear_cache.size()}
		for direction: Vector2i in directions:
			var next: Vector2i = key + direction
			if next.x < GRID_MIN_X or next.x > GRID_MAX_X or next.y < GRID_MIN_Z or next.y > GRID_MAX_Z:
				continue
			if visited.has(next) or not _clear(next):
				continue
			visited[next] = true
			queue.append(next)
	return {"ok": false, "visited": visited.size(), "checks": _clear_cache.size()}

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("BATTLEFIELD_ROUTES_FAIL scene")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	_castle = _scene.get("preview_castle") as Node3D
	if _castle == null or not _install_if_needed():
		print("BATTLEFIELD_ROUTES_FAIL castle_or_field")
		quit(1)
		return
	_capsule.radius = 0.38
	_capsule.height = 1.72
	_castle.call("set_gate", true)
	for tick: int in 200:
		_castle.call("_advance_gate", 0.05)
		if float(_castle.call("gate_angle")) >= 0.95:
			break
	for tick: int in 3:
		await physics_frame
	var gate_misses: Array[float] = []
	for z: int in range(60, 85, 2):
		if not _capsule_clear(0.0, float(z)):
			gate_misses.append(float(z))
	var centre_misses: Array[float] = []
	for z: int in range(84, 225, 4):
		if not _capsule_clear(0.0, float(z)):
			centre_misses.append(float(z))
	var start := Vector2i(0, 1) # x=0, z=84
	var routes := {
		"attacker_centre": _route(start, Vector2i(0, 36)), # z=224
		"left_flank": _route(start, Vector2i(-12, 19)), # x=-48, z=156
		"right_flank": _route(start, Vector2i(12, 19)), # x=48, z=156
	}
	var passable := gate_misses.is_empty() and centre_misses.is_empty()
	for value: Dictionary in routes.values():
		passable = passable and bool(value.get("ok", false))
	print("BATTLEFIELD_ROUTES ", JSON.stringify({"pass": passable,
		"gate_blocked_z": gate_misses, "centre_blocked_z": centre_misses,
		"centre_blockers": _blockers,
		"routes": routes, "capsule_radius": _capsule.radius,
		"capsule_height": _capsule.height}))
	await create_timer(3.0).timeout
	quit(0 if passable else 1)
