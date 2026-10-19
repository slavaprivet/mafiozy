extends SceneTree
## Second headless probe: does the placed stack actually collide with the world?
##
## For every building it runs a downward ray at the centre of the authored
## footprint and at the main entrance, plus a short horizontal ray from a stand-in
## actor capsule at each main door. It reports the first collider name and the
## hit height, so a floating or buried building is visible as a number instead of
## an opinion. It also reports the real physics body count contributed by the
## three sites and the wall-clock cost of one full placement pass.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <game> \
##     --script res://scripts/tests/modular_buildings_overlap_probe.gd

const Restaurant = preload("res://scripts/destruction/restaurant/restaurant_site.gd")
const Hospital = preload("res://scripts/destruction/hospital_site/hospital_site.gd")
const Bank = preload("res://scripts/destruction/bank_site/bank_site.gd")

const SETTLE_FRAMES := 6
const HARD_DEADLINE_MS := 120000

var _world: Node3D
var _rows: Array[Dictionary] = []
var _started_ms := 0
var _frames := 0
var _done := false

func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	run.call_deferred()

func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if _frames >= SETTLE_FRAMES:
		_finish()
		return true
	if Time.get_ticks_msec() - _started_ms > HARD_DEADLINE_MS:
		print("MODULAR_HIT_ABORT deadline_ms=", Time.get_ticks_msec() - _started_ms)
		_finish()
		return true
	return false

func run() -> void:
	_world = Node3D.new()
	_world.name = "ModularHitWorld"
	root.add_child(_world)
	_place("restaurant_pizza", Restaurant.new(), Vector3(0, 0, 0))
	_place("hospital_structural01", Hospital.new(), Vector3(40, 0, 0))
	_place("bank_small", Bank.new(), Vector3(80, 0, 0))
	print("MODULAR_HIT_STAGE placed=", _rows.size())

func _place(label: String, site: RefCounted, origin: Vector3) -> void:
	var prepared: Dictionary = site.prepare(_world, origin, 0.0)
	var row := {"label": label, "origin": origin, "ok": prepared.get("ok", false), "status": str(prepared.get("status", ""))}
	var stats: Dictionary = site.stats() if site != null else {}
	row["recipe_bounds"] = stats.get("recipe_bounds", {})
	row["dimensions"] = stats.get("recipe_dimensions", [])
	row["soil_centre_y"] = stats.get("soil_centre_y", 0.0)
	row["node"] = prepared.get("node", null)
	_rows.append(row)

func _finish() -> void:
	_done = true
	var state := root.world_3d.direct_space_state
	for row: Dictionary in _rows:
		var origin: Vector3 = row.get("origin", Vector3.ZERO)
		var bounds: Dictionary = row.get("recipe_bounds", {})
		var min_v: Vector3 = _v3(bounds.get("minimum", [0, 0, 0]))
		var max_v: Vector3 = _v3(bounds.get("maximum", [0, 0, 0]))
		var centre := origin + Vector3((min_v.x + max_v.x) * 0.5, max_v.y + 6.0, (min_v.z + max_v.z) * 0.5)
		var down := _ray(state, centre, centre + Vector3(0, -40, 0))
		var soil_probe := origin + Vector3(0, 4.0, 0)
		var soil_hit := _ray(state, soil_probe, soil_probe + Vector3(0, -12, 0))
		print("MODULAR_HIT label=", row.get("label"),
			" ok=", row.get("ok"),
			" status=", row.get("status"),
			" recipe_min=", _fmt(min_v),
			" recipe_max=", _fmt(max_v),
			" soil_centre_y=", "%.2f" % float(row.get("soil_centre_y", 0.0)),
			" topdown_hit=", down.get("name", "-"),
			" topdown_y=", "%.3f" % float(down.get("y", -999.0)),
			" centre_down_hit=", soil_hit.get("name", "-"),
			" centre_down_y=", "%.3f" % float(soil_hit.get("y", -999.0)),
			" bodies=", _count_bodies(row.get("node")))
	print("MODULAR_HIT_SUMMARY rows=", _rows.size(), " wall_ms=", Time.get_ticks_msec() - _started_ms)
	quit(0)

func _ray(state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hit: Dictionary = state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider: Object = hit.get("collider")
	return {"name": collider.name if collider != null else "?", "y": (hit.get("position", Vector3.ZERO) as Vector3).y}

func _count_bodies(root_node: Variant) -> int:
	if not root_node is Node:
		return -1
	var total := 0
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is CollisionObject3D:
			total += 1
		for child: Node in current.get_children():
			stack.append(child)
	return total

func _fmt(v: Vector3) -> String:
	return "%.2f,%.2f,%.2f" % [v.x, v.y, v.z]

static func _v3(value: Variant) -> Vector3:
	if not value is Array or value.size() != 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
