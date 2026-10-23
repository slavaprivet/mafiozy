extends SceneTree
## SHIP61 agent D probe — cannons, loading, firing, projectile impacts, ballistics.
##
## Headless, self-contained: no castle.tscn is loaded.  The four guns, the ship, the
## water and the castle are local test doubles, and the only constant from the contract
## that is exercised is the public API of ship_cannons.gd / ship_cannonball.gd.
##
## Run:
##   Godot_v4.7.2-stable_win64.exe --path <game> --headless \
##     --script res://scripts/tests/ship61_cannon_probe.gd

const CannonsScript = preload("res://scripts/ship/ship_cannons.gd")
const GRAVITY := 9.81
const SPEED := 62.0
const WATER_LEVEL := -0.55
const DT := 1.0 / 60.0

var _fails: Array[String] = []
var _notes: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


# ================================================================== test doubles
class FakeCastle:
	extends Node3D
	var events: Array = []

	func apply_explosion(event: Dictionary) -> Dictionary:
		events.append(event.duplicate(true))
		return {"ok": true, "detached": 3, "state": "committed"}

	func wall_half() -> float:
		return 400.0


class FakeBoat:
	extends Node3D
	var hits: Array = []

	func apply_hit(point: Vector3, damage: float, impulse: Vector3, kind: String) -> Dictionary:
		hits.append({"point": point, "damage": damage, "impulse": impulse, "kind": kind})
		return {"ok": true, "damage": damage}


class FakeBasin:
	extends Node
	var ripples: Array = []
	var depth := 6.0

	func water_level() -> float:
		return -0.55

	func water_height_at(_x: float, _z: float) -> float:
		return -0.55

	func depth_at(_x: float, _z: float) -> float:
		return depth

	func add_ripple(world_position: Vector3, strength: float = 1.0) -> void:
		ripples.append({"position": world_position, "strength": strength})


class FakeModel:
	extends Node3D
	var cannons: Array = []

	func _init() -> void:
		var specs: Array = [
			{"index": 0, "side": "port", "mount": Vector3(-3.55, 1.75, -4.2),
				"muzzle": Vector3(-4.9, 2.3, -4.2)},
			{"index": 1, "side": "starboard", "mount": Vector3(3.55, 1.75, -4.2),
				"muzzle": Vector3(4.9, 2.3, -4.2)},
			{"index": 2, "side": "port", "mount": Vector3(-3.55, 1.75, 3.4),
				"muzzle": Vector3(-4.9, 2.3, 3.4)},
			{"index": 3, "side": "starboard", "mount": Vector3(3.55, 1.75, 3.4),
				"muzzle": Vector3(4.9, 2.3, 3.4)},
		]
		for spec: Dictionary in specs:
			var node := Node3D.new()
			node.name = "Cannon%d" % int(spec.get("index", 0))
			node.position = spec.get("mount", Vector3.ZERO)
			add_child(node)
			var pivot := Node3D.new()
			pivot.name = "Pivot"
			pivot.position = Vector3(0.0, 0.55, 0.0)
			pivot.rotation.y = PI * 0.5 if str(spec.get("side")) == "port" else -PI * 0.5
			node.add_child(pivot)
			var barrel := Node3D.new()
			barrel.name = "Barrel"
			pivot.add_child(barrel)
			cannons.append({
				"index": spec.get("index", 0),
				"side": spec.get("side", "port"),
				"node": node,
				"mount": spec.get("mount", Vector3.ZERO),
				"pivot": pivot,
				"barrel": barrel,
				"muzzle": spec.get("muzzle", Vector3.ZERO),
			})

	func build() -> Dictionary:
		return {"ok": true, "length": 26.0, "beam": 8.8, "deck_y": 1.75,
			"cannons": cannons}


# ================================================================== harness
func _check(condition: bool, what: String) -> bool:
	if condition:
		print("  ok   ", what)
	else:
		_fails.append(what)
		print("  FAIL ", what)
	return condition


func _tick(cannons: Node, seconds: float) -> void:
	var steps: int = int(round(seconds / DT))
	for _i: int in steps:
		cannons.call("_process", DT)
		cannons.call("_physics_process", DT)


func _simulate_until_idle(cannons: Node, maximum: float) -> float:
	var elapsed := 0.0
	while elapsed < maximum:
		var state: Dictionary = cannons.call("state")
		if elapsed > 0.15 and int(state.get("balls_active", 0)) == 0:
			break
		_tick(cannons, 0.1)
		elapsed += 0.1
	return elapsed


func _load_and_fire(cannons: Node) -> Dictionary:
	var started: bool = bool(cannons.call("load_ball"))
	_tick(cannons, 1.3)
	var was_loaded: bool = bool(cannons.call("loaded"))
	var shot: Dictionary = cannons.call("fire")
	shot["load_started"] = started
	shot["was_loaded"] = was_loaded
	return shot


func _horizontal_range(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()


func _analytic_range(speed: float, angle_deg: float, y0: float, y1: float) -> float:
	var angle := deg_to_rad(angle_deg)
	var vy := speed * sin(angle)
	var vx := speed * cos(angle)
	var dy: float = y0 - y1
	var flight: float = (vy + sqrt(vy * vy + 2.0 * GRAVITY * dy)) / GRAVITY
	return vx * flight


# ================================================================== scenario
func _run() -> void:
	print("SHIP61_CANNON_PROBE start")
	var world := Node3D.new()
	world.name = "ProbeWorld"
	root.add_child(world)
	var model := FakeModel.new()
	model.name = "FakeModel"
	world.add_child(model)
	var boat := FakeBoat.new()
	boat.name = "FakeBoat"
	world.add_child(boat)
	# A piece of the firing ship's own hull, 1 m in front of the starboard muzzle.
	# The 0.25 s grace must let the ball through it instead of hitting its own ship.
	var own_hull := StaticBody3D.new()
	own_hull.name = "OwnHullProbe"
	own_hull.collision_layer = 1
	own_hull.collision_mask = 1
	own_hull.position = Vector3(6.0, 2.3, -4.2)
	var own_shape := CollisionShape3D.new()
	var own_box := BoxShape3D.new()
	own_box.size = Vector3(1.8, 1.8, 1.8)
	own_shape.shape = own_box
	own_hull.add_child(own_shape)
	boat.add_child(own_hull)
	var basin := FakeBasin.new()
	basin.name = "FakeBasin"
	world.add_child(basin)
	var castle := FakeCastle.new()
	castle.name = "FakeCastle"
	world.add_child(castle)
	# A 2 x 14 x 10 m masonry box broadside of the starboard guns, 40 m out.
	var wall := StaticBody3D.new()
	wall.name = "ProbeWall"
	wall.collision_layer = 1
	wall.collision_mask = 1
	wall.position = Vector3(40.0, 7.0, -4.2)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	# From below the waterline to 15 m: a flat shot at 34 m has dropped ~1.5 m by then.
	wall_box.size = Vector3(2.0, 16.0, 10.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	world.add_child(wall)
	var cannons := CannonsScript.new()
	cannons.name = "ShipCannons"
	cannons.set_process(false)
	cannons.set_physics_process(false)
	world.add_child(cannons)
	# Two physics frames so the StaticBody3D is registered in the broadphase.
	await physics_frame
	await physics_frame

	var install: Dictionary = cannons.call("install", world, boat, model, null, basin)
	_check(bool(install.get("ok", false)), "install ok")
	_check(int(install.get("cannons", 0)) == 4, "install found 4 cannons")
	_check(int(install.get("pool", 0)) == 24, "projectile pool is 24")
	cannons.call("bind_castle", castle)
	cannons.call("set_ball_stock", 17)

	# ------------------------------------------------------------ man / leave
	_check(bool(cannons.call("man", 1)), "man(1) accepted")
	_check(bool(cannons.call("manning")), "manning() true")
	_check(int(cannons.call("manning_index")) == 1, "manning_index() == 1")
	_check(not bool(cannons.call("man", 99)), "man(99) rejected")
	cannons.call("leave")
	_check(not bool(cannons.call("manning")), "leave() clears manning")
	_check(int(cannons.call("manning_index")) == -1, "manning_index() == -1 after leave")
	_check(bool(cannons.call("man", 1)), "man(1) again")

	# ------------------------------------------------------------ aim clamps
	cannons.call("aim", 100.0, 100.0)
	var state: Dictionary = cannons.call("state")
	_check(absf(float(state.get("yaw_target_deg", 0.0)) - 32.0) < 0.01,
		"yaw target clamps to +32 deg")
	_check(absf(float(state.get("pitch_target_deg", 0.0)) - 30.0) < 0.01,
		"pitch target clamps to +30 deg")
	_tick(cannons, 1.2)
	state = cannons.call("state")
	_check(absf(float(state.get("yaw_deg", 0.0)) - 32.0) < 0.2,
		"yaw reaches +32 deg")
	_check(absf(float(state.get("pitch_deg", 0.0)) - 30.0) < 0.2,
		"pitch reaches +30 deg")
	cannons.call("aim", -100.0, -100.0)
	_tick(cannons, 1.4)
	state = cannons.call("state")
	_check(absf(float(state.get("yaw_deg", 0.0)) + 32.0) < 0.2,
		"yaw clamps to -32 deg")
	_check(absf(float(state.get("pitch_deg", 0.0)) + 8.0) < 0.2,
		"pitch clamps to -8 deg")
	_check(bool(cannons.call("set_aim_degrees", 0.0, 0.0)), "set_aim_degrees accepted")
	_tick(cannons, 1.0)

	# HUD-facing state keys requested by the integrator.
	var required := ["manning", "index", "loaded", "yaw_deg", "pitch_deg", "side",
		"label", "balls_in_stock"]
	var missing: Array[String] = []
	for key: String in required:
		if not state.has(key):
			missing.append(key)
	_check(missing.is_empty(), "state() has HUD keys %s" % str(missing))
	_check(int(state.get("balls_in_stock", -1)) == 17, "state balls_in_stock=17")
	_check(str(state.get("side", "")) == "starboard", "state side=starboard")
	var snapshot: Dictionary = cannons.call("snapshot")
	_check(snapshot.has("mounts") and (snapshot.get("mounts") as Array).size() == 4,
		"snapshot has 4 mounts")

	# ------------------------------------------------------------ stations / yaw
	var mount2: Vector3 = cannons.call("mount_world", 2)
	var station2: Vector3 = cannons.call("station_world", 2)
	var look2: float = cannons.call("look_yaw", 2)
	_check(mount2.distance_to(Vector3(-3.55, 1.75, 3.4)) < 0.02,
		"mount_world(2) is the port aft mount")
	_check(station2.distance_to(Vector3(-2.35, 1.77, 3.4)) < 0.05,
		"station_world(2) is 1.2 m inboard")
	_check(absf(look2 - PI * 0.5) < 0.01, "look_yaw(2) faces the port broadside")

	# ------------------------------------------------------------ load / fire gate
	cannons.call("man", 1)
	cannons.call("set_aim_degrees", 0.0, 0.0)
	_tick(cannons, 0.8)
	var dry: Dictionary = cannons.call("fire")
	_check(not bool(dry.get("ok", true)), "fire() without a ball is refused")
	_check(str(dry.get("reason", "")) == "not_loaded", "  reason=not_loaded")
	_check(bool(cannons.call("load_ball")), "load_ball() starts")
	_check(not bool(cannons.call("loaded")), "loaded() is false during the 1.2 s ram")
	_check(not bool(cannons.call("load_ball")), "load_ball() refuses a second ball")
	_tick(cannons, 1.3)
	_check(bool(cannons.call("loaded")), "loaded() is true after 1.2 s")
	var wall_shot: Dictionary = cannons.call("fire")
	_check(bool(wall_shot.get("ok", false)), "fire() with a ball succeeds")
	_check(bool(wall_shot.has("from")) and bool(wall_shot.has("direction")),
		"fire() returns from/direction")
	_check(not bool(cannons.call("loaded")), "the gun is empty after firing")
	var again: Dictionary = cannons.call("fire")
	_check(not bool(again.get("ok", true)), "a second fire() needs a reload")

	# ------------------------------------------------------------ wall -> castle
	var wall_sim: float = _simulate_until_idle(cannons, 3.0)
	_check(castle.events.size() == 1, "the wall produced exactly 1 castle event")
	if castle.events.size() == 1:
		var event: Dictionary = castle.events[0]
		_check(absf(float(event.get("radius", 0.0)) - 1.9) < 0.001,
			"castle event radius = 1.9")
		_check(absf(float(event.get("power", 0.0)) - 120.0) < 0.001,
			"castle event power = 120")
		_check(str(event.get("event_id", "")).begins_with("ship-cannon:"),
			"castle event id is ship-cannon:<n>")
		var impact_dir: Vector3 = event.get("direction", Vector3.ZERO)
		_check(impact_dir.x > 0.9, "wall hit direction is outboard (+X)")
	_check(basin.ripples.is_empty(), "the wall shot made no water ripple")
	_check(boat.hits.is_empty(), "the wall shot did not hit the firing ship")
	state = cannons.call("state")
	_check(int(state.get("castle_hits", 0)) == 1, "state castle_hits = 1")
	_check(int(state.get("balls_active", -1)) == 0, "the ball expired on the wall")
	print("SHIP61_CANNON_WALL simulated=%.2fs events=%d" % [wall_sim, castle.events.size()])

	# ------------------------------------------------------------ water + ballistics
	cannons.call("man", 0)
	cannons.call("set_aim_degrees", 0.0, 15.0)
	_tick(cannons, 1.2)
	state = cannons.call("state")
	var dir15: Vector3 = state.get("direction", Vector3.ZERO)
	_check(absf(rad_to_deg(asin(clampf(dir15.y, -1.0, 1.0))) - 15.0) < 0.15,
		"barrel points 15 deg above the horizon")
	var ripples_before_15: int = basin.ripples.size()
	var shot15: Dictionary = _load_and_fire(cannons)
	_check(bool(shot15.get("ok", false)), "15 deg shot fired")
	var from15: Vector3 = shot15.get("from", Vector3.ZERO)
	var sim15: float = _simulate_until_idle(cannons, 6.0)
	_check(basin.ripples.size() == ripples_before_15 + 1,
		"15 deg shot made exactly 1 water ripple")
	var ripple15: Vector3 = Vector3.ZERO
	if basin.ripples.size() > ripples_before_15:
		ripple15 = (basin.ripples[ripples_before_15] as Dictionary).get("position", Vector3.ZERO)
		_check(absf(float((basin.ripples[ripples_before_15] as Dictionary).get("strength", 0.0)) - 1.4) < 0.001,
			"water ripple strength = 1.4")
	var range15: float = _horizontal_range(from15, ripple15)
	var analytic15: float = _analytic_range(SPEED, 15.0, from15.y, WATER_LEVEL)
	state = cannons.call("state")
	_check(int(state.get("water_hits", 0)) == 1, "state water_hits = 1")
	_check(str((state.get("last_impact", {}) as Dictionary).get("type", "")) == "water",
		"last impact type is water")

	cannons.call("man", 0)
	cannons.call("set_aim_degrees", 0.0, 30.0)
	_tick(cannons, 1.4)
	state = cannons.call("state")
	var dir30: Vector3 = state.get("direction", Vector3.ZERO)
	_check(absf(rad_to_deg(asin(clampf(dir30.y, -1.0, 1.0))) - 30.0) < 0.15,
		"barrel points 30 deg above the horizon")
	var ripples_before_30: int = basin.ripples.size()
	var shot30: Dictionary = _load_and_fire(cannons)
	_check(bool(shot30.get("ok", false)), "30 deg shot fired")
	var from30: Vector3 = shot30.get("from", Vector3.ZERO)
	var sim30: float = _simulate_until_idle(cannons, 9.0)
	_check(basin.ripples.size() == ripples_before_30 + 1, "30 deg shot made a second water ripple")
	var ripple30: Vector3 = Vector3.ZERO
	if basin.ripples.size() > ripples_before_30:
		ripple30 = (basin.ripples[ripples_before_30] as Dictionary).get("position", Vector3.ZERO)
	var range30: float = _horizontal_range(from30, ripple30)
	var analytic30: float = _analytic_range(SPEED, 30.0, from30.y, WATER_LEVEL)
	_check(absf(range15 - analytic15) < 8.0,
		"15 deg simulated range matches the analytic range (%.1f vs %.1f m)" % [range15, analytic15])
	_check(absf(range30 - analytic30) < 12.0,
		"30 deg simulated range matches the analytic range (%.1f vs %.1f m)" % [range30, analytic30])
	_check(range30 > range15 + 50.0, "30 deg flies farther than 15 deg")
	# The briefing expected 60..140 m at 15 deg; at the contract speed of 62 m/s the
	# physical answer is ~206 m.  Report it instead of silently bending the physics.
	if range15 < 60.0 or range15 > 140.0:
		var note := "contract note: 15 deg at 62 m/s gives %.1f m, outside the stated 60..140 m; speed/gravity kept exactly as contracted" % range15
		_notes.append(note)
		print("SHIP61_CANNON_NOTE ", note)
	print("SHIP61_CANNON_BALLISTIC 15deg=%.1f m (analytic %.1f) 30deg=%.1f m (analytic %.1f) sim=%.1fs/%.1fs"
		% [range15, analytic15, range30, analytic30, sim15, sim30])

	# ------------------------------------------------------------ debug_fire_at
	var debug: Dictionary = cannons.call("debug_fire_at", Vector3(40.0, 3.0, -4.2))
	_check(bool(debug.get("ok", false)), "debug_fire_at() fires without inventory")
	_check(bool(debug.get("debug", false)), "debug_fire_at() marks its result")
	var debug_index: int = int(debug.get("index", -1))
	_check(debug_index == 1 or debug_index == 3, "debug_fire_at() picked a starboard gun")
	var debug_sim: float = _simulate_until_idle(cannons, 3.0)
	_check(castle.events.size() == 2, "debug_fire_at() hit the wall (2nd castle event)")
	print("SHIP61_CANNON_DEBUG index=%d yaw=%.1f pitch=%.1f simulated=%.2fs events=%d"
		% [debug_index, float(debug.get("yaw_deg", 0.0)), float(debug.get("pitch_deg", 0.0)),
		debug_sim, castle.events.size()])

	# ------------------------------------------------------------ summary
	var summary := {
		"fails": _fails.size(),
		"notes": _notes,
		"castle_events": castle.events.size(),
		"water_ripples": basin.ripples.size(),
		"ship_hits": boat.hits.size(),
		"range15_m": snappedf(range15, 0.1),
		"range30_m": snappedf(range30, 0.1),
		"range15_in_contract_window_60_140": range15 >= 60.0 and range15 <= 140.0,
		"analytic15_m": snappedf(analytic15, 0.1),
		"analytic30_m": snappedf(analytic30, 0.1),
		"shots": int((cannons.call("state") as Dictionary).get("shots", 0)),
		"hits": int((cannons.call("state") as Dictionary).get("hits", 0)),
	}
	if _fails.is_empty():
		print("SHIP61_CANNON_OK ", JSON.stringify(summary))
		world.queue_free()
		quit(0)
	else:
		print("SHIP61_CANNON_FAIL ", JSON.stringify(summary))
		world.queue_free()
		quit(1)
