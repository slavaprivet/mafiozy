extends SceneTree
## SHIP63 agent F probe — cannon hits on a SECOND ship, small castle breach, powder
## barrels, and the gunner camera / controls.
##
## Two modes in one file (agent F owns this test):
##   headless (default):
##     1. synthetic world (no castle scene): 6 hits on a boat double, own-ship hits only
##        after the 0.25 s grace, a powder barrel => explode_from_hit, pool/state intact;
##     2. real castle scene: 10 broadside shots at the south curtain (bricks per shot),
##        one gate shot, 6 shots into a REAL second ShipBoat target (holes / flooding).
##   screenshots (`-- --shots`), windowed 1600x900:
##     f_01_target_side.png, f_02_cannon_camera.png, f_03_target_shot.png,
##     f_04_target_hit.png, f_05_wall_breach.png
##     in DSH_SHOT_DIR or .../default-workspace/shots_ship63.
##
## Run headless:
##   & 'C:\...\Godot_v4.7.2-stable_win64.exe' --path <game> --headless `
##     --script res://scripts/tests/ship63_cannon_probe.gd [-- --no-castle]
## Run screenshots (NO --headless):
##   & '...Godot_v4.7.2-stable_win64.exe' --path <game> --resolution 1600x900 `
##     --script res://scripts/tests/ship63_cannon_probe.gd -- --shots

const CannonsScript = preload("res://scripts/ship/ship_cannons.gd")
const CannonballScript = preload("res://scripts/ship/ship_cannonball.gd")
const ShipModelScript = preload("res://scripts/ship/ship_model.gd")
const ShipBoatScript = preload("res://scripts/ship/ship_boat.gd")

const DT := 1.0 / 60.0
const CASTLE_SHOTS := 10
const TARGET_SHOTS := 6
const BLAST_MIN := 3
const BLAST_MAX := 8
const BLAST_HARD_MAX := 10
const LOAD_DEADLINE_MS := 240000
const HOST_WAIT_MS := 30000
const OUT_DEFAULT := "C:/Users/Слава/Documents/deepseek-harness/default-workspace/shots_ship63"
const SHOT_W := 1600
const SHOT_H := 900

var _shots_mode := false
var _skip_castle := false
var _cell_report := false
var _only: Array[String] = []
var _tag := "f"

var _checks := 0
var _fails: Array[String] = []
var _notes: Array[String] = []
var _metrics: Dictionary = {}

# Real-scene nodes (headless castle phase and screenshot mode).
var _scene: Node = null
var _castle: Node = null
var _host: Node = null
var _boat: Node3D = null
var _model: Node3D = null
var _cannons: Node = null
var _basin: Node = null
var _player: CharacterBody3D = null


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--shots":
			_shots_mode = true
		elif argument == "--no-castle":
			_skip_castle = true
		elif argument == "--cell-report":
			_cell_report = true
		elif argument == "--tag=":
			_tag = argument.trim_prefix("--tag=")
			if _tag.is_empty():
				_tag = "f"
		elif argument.begins_with("--only="):
			for token: String in argument.trim_prefix("--only=").split(",", false):
				var clean := token.strip_edges()
				if not clean.is_empty():
					_only.append(clean)
	if _shots_mode:
		call_deferred("_run_shots")
	elif _cell_report:
		call_deferred("_run_cell_report")
	else:
		call_deferred("_run_headless")


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
		return {"ok": true, "zone": "hull", "damage": damage, "hole": true,
			"flooding": 0.0, "integrity": 0.9, "sunk": false}


class FakePowderCargo:
	extends Node3D
	var calls: Array = []
	var failed := false

	func explode_from_hit(point: Vector3, direction: Vector3) -> Dictionary:
		calls.append({"point": point, "direction": direction})
		if failed:
			return {"ok": false, "reason": "test_failure"}
		return {"ok": true, "exploded": true, "index": 0}


class FakeBasin:
	extends Node
	var ripples: Array = []
	var depth := 0.0

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


# ================================================================== checks
func _check(condition: bool, what: String, detail: String = "") -> bool:
	_checks += 1
	if condition:
		print("  ok   ", what, "" if detail.is_empty() else "  " + detail)
	else:
		_fails.append(what)
		print("  FAIL ", what, "" if detail.is_empty() else "  " + detail)
	return condition


func _note(text: String) -> void:
	_notes.append(text)
	print("  note ", text)


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value: Variant in values:
		sum += float(value)
	return sum / float(values.size())


func _mini(values: Array) -> int:
	if values.is_empty():
		return -1
	var best := 2147483647
	for value: Variant in values:
		best = mini(best, int(value))
	return best


func _maxi(values: Array) -> int:
	if values.is_empty():
		return -1
	var best := -2147483648
	for value: Variant in values:
		best = maxi(best, int(value))
	return best


func _points(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in values:
		out.append(str(value))
	return out


func _meta_nodes(root: Node, key: String) -> Array[Node]:
	var out: Array[Node] = []
	if not is_instance_valid(root):
		return out
	for node: Node in root.find_children("*", "", true, false):
		if node.has_meta(key) and bool(node.get_meta(key)):
			out.append(node)
	if root.has_meta(key) and bool(root.get_meta(key)):
		out.append(root)
	return out


func _settle(frames: int) -> void:
	for _i: int in frames:
		await process_frame


func _wait_real(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame


# ================================================================== headless
func _run_headless() -> void:
	print("SHIP63_CANNON_PROBE_START")
	await _phase_synthetic()
	if not _skip_castle:
		await _phase_castle()
	else:
		_note("castle phase skipped with --no-castle")
	var ok := _fails.is_empty()
	print("SHIP63_CANNON_SUMMARY ", JSON.stringify({
		"ok": ok,
		"checks": _checks,
		"fails": _fails,
		"notes": _notes,
		"metrics": _metrics,
		"castle_radius": CannonballScript.CASTLE_RADIUS,
		"castle_power": CannonballScript.CASTLE_POWER,
		"castle_surface_offset": CannonballScript.CASTLE_SURFACE_OFFSET,
		"castle_support_radius": CannonballScript.CASTLE_SUPPORT_RADIUS,
		"ship_damage": CannonballScript.SHIP_DAMAGE,
		"ship_impulse": CannonballScript.SHIP_IMPULSE,
	}))
	if ok:
		print("SHIP63_CANNON_OK")
		quit(0)
	else:
		print("SHIP63_CANNON_FAIL ", JSON.stringify(_fails))
		quit(1)


# ------------------------------------------------------------------ 1. synthetic
func _phase_synthetic() -> void:
	print("SHIP63_PHASE synthetic")
	var world := Node3D.new()
	world.name = "Ship63ProbeWorld"
	root.add_child(world)
	var model := FakeModel.new()
	model.name = "FakeModel"
	world.add_child(model)
	var boat := FakeBoat.new()
	boat.name = "FakeBoat"
	world.add_child(boat)
	var target := FakeBoat.new()
	target.name = "FakeTargetBoat"
	world.add_child(target)
	# Own hull pieces: one 6 m ahead (inside the 0.25 s grace, must be flown through) and
	# one 30 m ahead (hit after the grace, must damage the firing ship exactly once).
	var own_near := _add_box(boat, "OwnNearHull", Vector3(6.0, 2.3, -4.2),
		Vector3(1.8, 1.8, 1.8))
	var own_far := _add_box(boat, "OwnFarHull", Vector3(30.0, 1.0, -4.2),
		Vector3(2.0, 4.0, 6.0))
	# Another ShipBoat-like target 40 m to port (firing ship's port battery).
	var target_hull := _add_box(target, "TargetHull", Vector3(-40.0, 1.0, -4.2),
		Vector3(2.5, 4.0, 8.0))
	target.position = Vector3.ZERO
	# A powder barrel 40 m off the port aft gun; the cargo is its SIBLING, not an
	# ancestor, so the tree-search fallback in _powder_owner is exercised too.
	var barrel := _add_box(world, "PowderBarrel", Vector3(-40.0, 1.6, 3.4),
		Vector3(1.6, 1.6, 1.6))
	barrel.set_meta("ship_powder_barrel", true)
	var cargo := FakePowderCargo.new()
	cargo.name = "FakePowderCargo"
	world.add_child(cargo)
	var basin := FakeBasin.new()
	basin.name = "FakeBasin"
	world.add_child(basin)
	var cannons := CannonsScript.new()
	cannons.name = "ShipCannons"
	cannons.set_process(false)
	cannons.set_physics_process(false)
	world.add_child(cannons)
	await physics_frame
	await physics_frame

	var install := _dict(cannons.call("install", world, boat, model, null, basin))
	_check(bool(install.get("ok", false)), "synthetic install ok",
		str(install.get("reason", "")))
	_check(int(install.get("cannons", 0)) == 4, "synthetic install found 4 cannons",
		str(install.get("cannons", 0)))
	var state := _dict(cannons.call("state"))
	_check(state.has("last_target_type"), "state() has last_target_type")
	_check(str(state.get("last_target_type", "missing")) == "",
		"last_target_type starts empty", str(state.get("last_target_type", "")))
	_check(int(state.get("pool", 0)) == 24, "projectile pool is 24")
	_check(int(state.get("puff_slots", 0)) == 200, "effect pool untouched (200 slots)")

	# ---------------------------------------------------------- 6 hits on a boat
	print("SHIP63_SYNTH target boat, 6 shots")
	var target_points: Array[Vector3] = []
	var target_impacts: Array = []
	for i: int in TARGET_SHOTS:
		var aim := Vector3(-40.0, 1.8, -4.2)
		var fired := _dict(cannons.call("debug_fire_at", aim))
		if not bool(fired.get("ok", false)):
			_check(false, "target shot %d fired" % i, str(fired.get("reason", "")))
			continue
		var impact := _manual_flight(cannons)
		target_impacts.append(impact)
		target_points.append(impact.get("position", Vector3.ZERO))
	state = _dict(cannons.call("state"))
	_check(target.hits.size() == TARGET_SHOTS,
		"6 shots called the target boat apply_hit 6 times", str(target.hits.size()))
	var all_ship := true
	var all_other := true
	for impact: Dictionary in target_impacts:
		if str(impact.get("type", "")) != "ship":
			all_ship = false
		if str(impact.get("target_type", "")) != "other_ship":
			all_other = false
	_check(all_ship, "every target impact type == \"ship\"")
	_check(all_other, "every target impact target_type == \"other_ship\"")
	_check(int(state.get("other_ship_hits", 0)) == TARGET_SHOTS,
		"state.other_ship_hits == 6", str(state.get("other_ship_hits", -1)))
	_check(int(state.get("own_ship_hits", -1)) == 0, "state.own_ship_hits == 0",
		str(state.get("own_ship_hits", -1)))
	var damage_ok := true
	var impulse_ok := true
	var kind_ok := true
	for hit: Dictionary in target.hits:
		if absf(float(hit.get("damage", 0.0)) - CannonballScript.SHIP_DAMAGE) > 0.01:
			damage_ok = false
		var impulse: Vector3 = hit.get("impulse", Vector3.ZERO)
		if absf(impulse.length() - CannonballScript.SHIP_IMPULSE) > 0.05:
			impulse_ok = false
		if str(hit.get("kind", "")) != "cannonball":
			kind_ok = false
	_check(damage_ok, "apply_hit damage == SHIP_DAMAGE",
		str(CannonballScript.SHIP_DAMAGE))
	_check(impulse_ok, "apply_hit impulse length == SHIP_IMPULSE",
		str(CannonballScript.SHIP_IMPULSE))
	_check(kind_ok, "apply_hit kind == \"cannonball\"")
	if not target_impacts.is_empty():
		var first: Dictionary = target_impacts[0]
		var result := _dict(first.get("result"))
		_check(bool(result.get("ok", false)), "impact carries apply_hit result")
		_check(str(first.get("zone", "")) == "hull", "impact zone comes from apply_hit",
			str(first.get("zone", "")))

	# ---------------------------------------------------------- own ship after grace
	print("SHIP63_SYNTH own ship, grace 0.25 s")
	var own_before: int = boat.hits.size()
	var own_shot := _dict(cannons.call("debug_fire_at", Vector3(30.0, 1.8, -4.2)))
	_check(bool(own_shot.get("ok", false)), "own-hull shot fired",
		str(own_shot.get("reason", "")))
	var own_impact := _manual_flight(cannons)
	var own_point: Vector3 = own_impact.get("position", Vector3.ZERO)
	_check(str(own_impact.get("type", "")) == "ship", "own hull impact type == ship")
	_check(str(own_impact.get("target_type", "")) == "own_ship",
		"own hull impact target_type == own_ship")
	_check(own_point.x > 20.0, "the near own hull (6 m) was flown through during grace",
		"hit x=%.2f" % own_point.x)
	_check(boat.hits.size() == own_before + 1, "own ship damaged exactly once after grace",
		str(boat.hits.size() - own_before))
	state = _dict(cannons.call("state"))
	_check(int(state.get("own_ship_hits", 0)) == 1, "state.own_ship_hits == 1")
	_check(str(state.get("last_target_type", "")) == "own_ship",
		"state.last_target_type == own_ship")

	# ---------------------------------------------------------- powder barrel
	print("SHIP63_SYNTH powder barrel")
	var hits_before: int = target.hits.size()
	var barrel_shot := _dict(cannons.call("debug_fire_at", Vector3(-40.0, 1.6, 3.4)))
	_check(bool(barrel_shot.get("ok", false)), "barrel shot fired",
		str(barrel_shot.get("reason", "")))
	var barrel_impact := _manual_flight(cannons)
	_check(str(barrel_impact.get("type", "")) == "powder",
		"barrel impact type == powder", str(barrel_impact.get("type", "")))
	_check(str(barrel_impact.get("target_type", "")) == "powder_barrel",
		"barrel impact target_type == powder_barrel")
	_check(cargo.calls.size() == 1, "cargo.explode_from_hit called once",
		str(cargo.calls.size()))
	if not cargo.calls.is_empty():
		var call: Dictionary = cargo.calls[0]
		_check((call.get("point", Vector3.ZERO) as Vector3).distance_to(
			Vector3(-40.0, 1.6, 3.4)) < 1.0, "explode point is the barrel hit point",
			str(call.get("point", Vector3.ZERO)))
		_check((call.get("direction", Vector3.ZERO) as Vector3).length() > 0.9,
			"explode direction is a unit vector")
	state = _dict(cannons.call("state"))
	_check(int(state.get("powder_hits", 0)) == 1, "state.powder_hits == 1")
	_check(str(state.get("last_target_type", "")) == "powder_barrel",
		"state.last_target_type == powder_barrel")
	_check(int(state.get("balls_active", -1)) == 0, "the ball was spent on the barrel")
	_check(target.hits.size() == hits_before, "barrel did not also damage the hull")
	_check(int(state.get("puffs_active", 0)) > 0, "powder FX uses the shared puff pool",
		str(state.get("puffs_active", 0)))

	# ---------------------------------------------------------- pool intact
	state = _dict(cannons.call("state"))
	_check(int(state.get("pool", 0)) == 24, "pool still 24 after all impacts")
	_check(int(state.get("effect_draw_calls", 0)) == 5, "effects still 5 draw calls")
	_check(int(state.get("balls_active", -1)) == 0, "no active balls at the end")
	var snapshot := _dict(cannons.call("snapshot"))
	_check(snapshot.has("last_target_type"), "snapshot() carries last_target_type")
	_check((snapshot.get("mounts", []) as Array).size() == 4, "snapshot has 4 mounts")
	_metrics["synthetic"] = {
		"target_hits": target.hits.size(),
		"other_ship_hits": int(state.get("other_ship_hits", 0)),
		"own_ship_hits": int(state.get("own_ship_hits", 0)),
		"powder_hits": int(state.get("powder_hits", 0)),
		"target_points": _points(target_points),
	}

	world.queue_free()
	await process_frame
	await process_frame


func _add_box(parent: Node, node_name: String, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


## Deterministic flight for the synthetic world: the cannon node is manually ticked.
func _manual_flight(cannons: Node, max_steps: int = 900) -> Dictionary:
	for _step: int in max_steps:
		cannons.call("_process", DT)
		cannons.call("_physics_process", DT)
		var state := _dict(cannons.call("state"))
		if int(state.get("balls_active", 0)) == 0:
			var impact := _dict(state.get("last_impact"))
			if not impact.is_empty():
				return impact
	return {}


# ------------------------------------------------------------------ 2. real castle
func _phase_castle() -> void:
	print("SHIP63_PHASE castle")
	var scene_ok: bool = await _load_scene()
	if not scene_ok:
		return
	var level := _water_level()
	_host.call("debug_reset_ship")
	await _settle(6)
	_boat.call("set_sails", false)
	_boat.call("steer", 0.0)

	# The host-side target (agent T) is the integration contract.  The host berths it
	# abeam (TARGET_SPAWN = 160, 975), so the real hits below are measured on it.
	var target_result := await _resolve_target()
	var target_boat: Node3D = target_result.get("boat") as Node3D
	var target_owned := bool(target_result.get("owned", true))
	var target_ok := is_instance_valid(target_boat)
	_check(target_ok, "second ShipBoat target available",
		str(target_result.get("spot", Vector3.ZERO)))
	if target_ok:
		var host_pos: Vector3 = target_boat.global_position
		_check(absf(host_pos.x - _boat.global_position.x) >= 25.0
			and absf(host_pos.z - _boat.global_position.z) <= 6.0,
			"target is abeam of the player (not dead ahead)", str(host_pos))
		_metrics["target_berth"] = str(host_pos)

	# Agent P's barrels: the real props carry the meta and the real ball can resolve the
	# cargo that owns them.  (The synthetic phase above proves the explosion path itself;
	# the deck barrels cannot be shot from the broadside without hitting our own hull.)
	var powder := _host.get("powder") as Node
	if is_instance_valid(powder):
		var barrels := _meta_nodes(_scene, "ship_powder_barrel")
		if barrels.is_empty():
			_note("powder cargo is installed but no prop carries ship_powder_barrel yet")
		else:
			_check(barrels.size() >= 2, "P powder barrels carry meta ship_powder_barrel",
				str(barrels.size()))
			var balls: Array = _cannons.get("_balls") as Array
			if not balls.is_empty():
				var probe_ball := balls[0] as Node
				var resolved: Variant = probe_ball.call("_powder_owner", barrels[0])
				_check(resolved is Node and is_instance_valid(resolved)
					and (resolved as Node).has_method("explode_from_hit"),
					"cannonball resolves the cargo that owns a real barrel",
					str(resolved))
				_check(bool(probe_ball.call("_is_powder_barrel", barrels[0])),
					"cannonball recognises a real barrel collider")
		_metrics["powder_barrels"] = barrels.size()
	if target_ok:
		var target_hits: Array = []
		var aiming: Array[Vector3] = []
		# z offsets avoid the four cannon mounts (z=-4.2 and +3.4, r=1.9) and stay
		# inside the narrowing bow/stern, so every ball lands in the "hull" zone.
		var target_z: Array[float] = [-8.5, -6.5, -1.0, 1.0, 5.5, 7.5]
		for index: int in TARGET_SHOTS:
			var z: float = target_z[index]
			var to_shooter := target_boat.to_local(_boat.global_position)
			var side := 1.0 if to_shooter.x >= 0.0 else -1.0
			var point: Vector3 = target_boat.to_global(Vector3(3.6 * side, 1.2, z))
			aiming.append(point)
			var shots0 := int(_dict(_cannons.call("state")).get("shots", 0))
			var fired := _dict(_cannons.call("debug_fire_at", point))
			if not bool(fired.get("ok", false)):
				_check(false, "target shot %d fired" % index, str(fired.get("reason", "")))
				continue
			var impact := await _wait_live_impact(_cannons, shots0 + 1, 8.0)
			target_hits.append(impact)
			var kind := str(impact.get("type", "none"))
			var ttype := str(impact.get("target_type", ""))
			var zone := str(impact.get("zone", ""))
			print("SHIP63_TARGET_SHOT i=%d kind=%s target=%s zone=%s at=%s" % [index, kind,
				ttype, zone, str(impact.get("position", Vector3.ZERO))])
			await _wait_real(0.6)
		var ship_impacts := 0
		var hull_zones := 0
		for impact: Dictionary in target_hits:
			if str(impact.get("type", "")) == "ship" \
					and str(impact.get("target_type", "")) == "other_ship":
				ship_impacts += 1
			if str(impact.get("zone", "")) == "hull":
				hull_zones += 1
		var target_state := _dict(_cannons.call("state"))
		_check(ship_impacts == TARGET_SHOTS,
			"6/6 balls hit the second ship", "%d/%d" % [ship_impacts, TARGET_SHOTS])
		_check(hull_zones == TARGET_SHOTS, "6/6 impacts were hull hits",
			str(hull_zones))
		_check(int(target_state.get("other_ship_hits", 0)) == TARGET_SHOTS,
			"state.other_ship_hits == 6", str(target_state.get("other_ship_hits", -1)))
		_check(str(target_state.get("last_target_type", "")) == "other_ship",
			"state.last_target_type == other_ship")
		await _wait_real(4.0)
		var t_snapshot := _dict(target_boat.call("snapshot"))
		var holes := int(t_snapshot.get("holes", 0))
		var flooding := float(t_snapshot.get("flooding", 0.0))
		var integrity := float(t_snapshot.get("integrity", 1.0))
		_check(holes >= TARGET_SHOTS, "target has >= 6 hull holes", str(holes))
		_check(flooding > 0.02, "target is taking water", "flooding=%.3f" % flooding)
		_check(integrity < 0.8, "target hull integrity dropped", "%.3f" % integrity)
		_metrics["target"] = {
			"berth": str(target_boat.global_position),
			"owned_by_probe": target_owned,
			"shots": TARGET_SHOTS,
			"ship_impacts": ship_impacts,
			"hull_zones": hull_zones,
			"holes": holes,
			"flooding": snappedf(flooding, 0.001),
			"integrity": snappedf(integrity, 0.001),
			"aim_points": _points(aiming),
		}
		if target_owned:
			target_boat.queue_free()
			await _settle(4)

	# ---------------------------------------------------------- gate + 10 wall shots
	print("SHIP63_PHASE castle wall")
	_boat.call("moor", Vector3(30.0, level, 1000.0), deg_to_rad(-47.0))
	await _settle(6)
	var gate_before := _castle_stats()
	var gate_shot := await _fire_castle(Vector3(0.0, 6.0, 968.3), "gate")
	var gate_after := _castle_stats()
	var boards_delta := int(gate_after.get("gate_boards_broken", 0)) \
		- int(gate_before.get("gate_boards_broken", 0))
	var leaves_delta := int(gate_after.get("gate_leaves_detached", 0)) \
		- int(gate_before.get("gate_leaves_detached", 0))
	var gate_ok := boards_delta > 0 or leaves_delta > 0 \
		or bool(gate_after.get("gate_open", false))
	_check(gate_ok, "gate shot breaks boards / leaves",
		"boards %+d, leaves %+d, open=%s" % [boards_delta, leaves_delta,
		str(gate_after.get("gate_open", false))])
	_metrics["gate"] = {
		"boards_delta": boards_delta,
		"leaves_delta": leaves_delta,
		"open": bool(gate_after.get("gate_open", false)),
		"blast": int(gate_shot.get("blast", -1)),
	}

	# Ten independent points on plain curtain masonry: y=6.0 is between the decorative
	# courses (the cell report shows four to eight 1x0.54x0.55 bricks per blast there),
	# y=12.0 is one cascade height above it.  Columns are 8 m apart; the sea only lets
	# the ship moor at x >= 36, so the two westernmost points are fired up to 16 m off
	# the beam (31.6 deg, inside the 32 deg arc).  x=60 is avoided: the corner tower
	# decoration there returns 11-brick blasts.
	var wall_points: Array[Vector3] = [
		Vector3(20.0, 6.0, 968.0), Vector3(28.0, 6.0, 968.0),
		Vector3(36.0, 6.0, 968.0), Vector3(44.0, 6.0, 968.0),
		Vector3(52.0, 6.0, 968.0), Vector3(20.0, 12.0, 968.0),
		Vector3(28.0, 12.0, 968.0), Vector3(36.0, 12.0, 968.0),
		Vector3(44.0, 12.0, 968.0), Vector3(52.0, 12.0, 968.0),
	]
	var totals: Array[int] = []
	var blasts: Array[int] = []
	var misses := 0
	var per_shot: Array = []
	var index := 0
	for point: Vector3 in wall_points:
		var moored := await _moor_abeam(clampf(point.x, 36.0, 52.0))
		if not moored:
			misses += 1
			per_shot.append({"i": index, "at": str(point), "kind": "no_berth",
				"blast": -1, "total": -1})
			print("SHIP63_WALL_SHOT i=%d at=%s kind=no_berth" % [index, str(point)])
			index += 1
			continue
		var shot := await _fire_castle(point, "wall_%d" % index)
		index += 1
		var kind := str(shot.get("kind", "none"))
		if kind != "castle":
			misses += 1
		var blast := int(shot.get("blast", -1))
		if blast >= 0:
			blasts.append(blast)
		var total := int(shot.get("total", -1))
		if total >= 0:
			totals.append(total)
		per_shot.append({"i": index - 1, "at": str(point), "kind": kind,
			"blast": blast, "total": total,
			"event_at": str(shot.get("event_at", Vector3.ZERO))})
		print("SHIP63_WALL_SHOT i=%d at=%s kind=%s blast=%d total=%d event=%s" % [
			index - 1, str(point), kind, blast, total,
			str(shot.get("event_at", Vector3.ZERO))])
	var avg := _avg(blasts)
	var maximum := _maxi(blasts)
	var minimum := _mini(blasts)
	print("SHIP63_WALL shots=%d hits=%d misses=%d blast_avg=%.2f blast_min=%d blast_max=%d cascade_avg=%.2f"
		% [CASTLE_SHOTS, CASTLE_SHOTS - misses, misses, avg, minimum, maximum,
		_avg(totals)])
	_check(misses <= 1, "at most 1 wall miss", "%d/%d" % [misses, CASTLE_SHOTS])
	_check(avg >= BLAST_MIN and avg <= BLAST_MAX,
		"wall blast avg in 3..8", "%.2f (min %d / max %d)" % [avg, minimum, maximum])
	_check(maximum <= BLAST_HARD_MAX, "wall blast max <= 10", str(maximum))
	_check(minimum >= 1, "every landed shot detached >= 1 brick", str(minimum))
	var wall_state := _dict(_cannons.call("state"))
	_check(str(wall_state.get("last_hit_kind", "")) == "castle",
		"state.last_hit_kind == castle after wall shots")
	_check(str(wall_state.get("last_target_type", "")) == "castle",
		"state.last_target_type == castle after wall shots")
	var last_event := _dict(_dict(wall_state.get("last_impact")).get("event"))
	_check(absf(float(last_event.get("support_radius", -1.0))
		- CannonballScript.CASTLE_SUPPORT_RADIUS) < 0.001,
		"castle event carries support_radius=0.35",
		str(last_event.get("support_radius", "missing")))
	_metrics["wall"] = {
		"shots": CASTLE_SHOTS,
		"hits": CASTLE_SHOTS - misses,
		"misses": misses,
		"blast_values": blasts,
		"cascade_values": totals,
		"blast_avg": snappedf(avg, 0.01),
		"blast_min": minimum,
		"blast_max": maximum,
		"cascade_avg": snappedf(_avg(totals), 0.01),
		"rows": per_shot,
	}
	await _phase_fps()


func _load_scene() -> bool:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		_check(false, "castle scene loads")
		return false
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + LOAD_DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true:
			break
		await process_frame
	if _scene.get("preview_ready") != true:
		_check(false, "preview_ready")
		return false
	_castle = _scene.get("preview_castle") as Node
	var host_deadline := Time.get_ticks_msec() + HOST_WAIT_MS
	while Time.get_ticks_msec() < host_deadline:
		_host = _scene.get("preview_ship") as Node
		if is_instance_valid(_host):
			break
		await process_frame
	if not is_instance_valid(_host):
		_check(false, "preview_ship host", str(_scene.get("ship_status")))
		return false
	_boat = _host.get("boat") as Node3D
	_model = _host.get("model") as Node3D
	_cannons = _host.get("cannons") as Node
	_basin = _host.get("basin") as Node
	_player = _host.get("player") as CharacterBody3D
	_check(is_instance_valid(_castle), "preview_castle")
	_check(is_instance_valid(_boat), "host.boat")
	_check(is_instance_valid(_cannons), "host.cannons")
	_check(is_instance_valid(_basin), "host.basin")
	return is_instance_valid(_boat) and is_instance_valid(_cannons)


## Prefer the host's real target (agent T).  Only when it is missing does the probe
## build its own ShipBoat double abeam, so this file still runs on a bare scene.
func _resolve_target() -> Dictionary:
	var host_target := _host.get("target") as Node
	if is_instance_valid(host_target):
		var host_boat := host_target.get("boat") as Node3D
		if is_instance_valid(host_boat):
			return {"boat": host_boat, "owned": false, "source": "host",
				"spot": host_boat.global_position}
	_note("host target missing; the probe builds its own ShipBoat double")
	var spot := _pick_target_spot()
	var result := await _install_target(spot)
	result["owned"] = true
	result["source"] = "probe"
	result["spot"] = spot
	return result


## A broadside berth ~40 m away with enough depth for a second ship.
func _pick_target_spot() -> Vector3:
	var level := _water_level()
	var origin: Vector3 = _boat.global_position
	var candidates: Array[Vector3] = [
		Vector3(origin.x - 40.0, level, origin.z),
		Vector3(origin.x + 40.0, level, origin.z),
		Vector3(origin.x, level, origin.z + 40.0),
		Vector3(origin.x, level, origin.z - 40.0),
	]
	for candidate: Vector3 in candidates:
		var depth := 0.0
		if is_instance_valid(_basin) and _basin.has_method("depth_at"):
			depth = float(_basin.call("depth_at", candidate.x, candidate.z))
		print("SHIP63_TARGET_SPOT at=%s depth=%.2f" % [str(candidate), depth])
		if depth >= 4.0:
			return candidate
	_note("no candidate berth had depth >= 4 m; using the first one")
	return candidates[0]


func _install_target(spot: Vector3) -> Dictionary:
	var model := ShipModelScript.new()
	model.name = "Ship63TargetModel"
	_scene.add_child(model)
	var boat := ShipBoatScript.new()
	boat.name = "Ship63Target"
	_scene.add_child(boat)
	var result := _dict(boat.call("install", _scene, _basin, _player, model))
	if not bool(result.get("ok", false)):
		_check(false, "target ShipBoat.install", str(result.get("reason", "")))
		return {}
	boat.call("moor", spot, 0.0)
	# The target must keep simulating: ShipBoat steps its flooding/buoyancy only when
	# the autopilot is on.  Sails stay furled and the rudder is amidships, so she holds
	# the berth while taking water.
	boat.call("set_autopilot", true)
	boat.call("set_sails", false)
	boat.call("steer", 0.0)
	if boat.has_method("set_wake_enabled"):
		boat.call("set_wake_enabled", false)
	await _settle(30)
	var snapshot := _dict(boat.call("snapshot"))
	print("SHIP63_TARGET installed pos=%s holes=%d flooding=%.3f"
		% [str(snapshot.get("position", Vector3.ZERO)), int(snapshot.get("holes", 0)),
		float(snapshot.get("flooding", 0.0))])
	return {"boat": boat, "model": model, "result": result}


## Put the player's ship abeam of `x` on the south wall, port battery facing north.
func _moor_abeam(x: float) -> bool:
	var level := _water_level()
	for z: float in [994.0, 1000.0, 1006.0, 988.0]:
		var depth := 99.0
		if is_instance_valid(_basin) and _basin.has_method("depth_at"):
			depth = float(_basin.call("depth_at", x, z))
		if depth < 4.0:
			continue
		_boat.call("moor", Vector3(x, level, z), deg_to_rad(-90.0))
		await _settle(6)
		return true
	return false


func _castle_stats() -> Dictionary:
	if is_instance_valid(_castle) and _castle.has_method("get_stats"):
		return _dict(_castle.call("get_stats"))
	return {}


func _fire_castle(point: Vector3, label: String) -> Dictionary:
	var before := _castle_stats()
	var shots0 := int(_dict(_cannons.call("state")).get("shots", 0))
	var fired := _dict(_cannons.call("debug_fire_at", point))
	var out := {"ok": bool(fired.get("ok", false)), "label": label, "kind": "none",
		"blast": -1, "total": -1, "impact": {}, "event_at": Vector3.ZERO}
	if not out["ok"]:
		print("SHIP63_CASTLE_REFUSED label=%s reason=%s" % [label,
			str(fired.get("reason", ""))])
		return out
	var impact := await _wait_live_impact(_cannons, shots0 + 1, 8.0)
	out["impact"] = impact
	out["kind"] = str(impact.get("type", "none"))
	var result := _dict(impact.get("result"))
	out["blast"] = int(result.get("detached", -1))
	var event := _dict(impact.get("event"))
	out["event_at"] = _vec(event.get("position"), Vector3.ZERO)
	await _wait_real(1.8)
	var after := _castle_stats()
	out["total"] = int(after.get("detached", 0)) - int(before.get("detached", 0))
	return out


func _wait_live_impact(cannons: Node, expected_shots: int, max_seconds: float) -> Dictionary:
	var deadline := Time.get_ticks_msec() + int(max_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var state := _dict(cannons.call("state"))
		var impact := _dict(state.get("last_impact"))
		if int(state.get("shots", 0)) >= expected_shots \
				and int(state.get("balls_active", 0)) == 0 \
				and str(impact.get("event_id", "")) == "ship-cannon:%d" % expected_shots:
			return impact
	return {}


func _phase_fps() -> void:
	for _frame: int in 60:
		await process_frame
	var fps := Engine.get_frames_per_second()
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	print("SHIP63_FPS fps=%d draw_calls=%d physics_ms=%.2f headless=%s"
		% [fps, draw_calls, physics_ms, str(DisplayServer.get_name())])
	_metrics["fps"] = fps
	_metrics["draw_calls"] = draw_calls
	_metrics["physics_ms"] = snappedf(physics_ms, 0.01)


func _water_level() -> float:
	if is_instance_valid(_basin) and _basin.has_method("water_level"):
		return float(_basin.call("water_level"))
	return -0.55


# ================================================================== cell diagnostics
## Read-only diagnostic: one shot, then list exactly which castle cells died.  Used
## while tuning CASTLE_SURFACE_OFFSET; it does not modify castle_site.gd.
func _run_cell_report() -> void:
	print("SHIP63_CELL_REPORT_START radius=", CannonballScript.CASTLE_RADIUS,
		" power=", CannonballScript.CASTLE_POWER,
		" offset=", CannonballScript.CASTLE_SURFACE_OFFSET)
	var scene_ok: bool = await _load_scene()
	if not scene_ok:
		quit(1)
		return
	_host.call("debug_reset_ship")
	await _settle(6)
	await _moor_abeam(52.0)
	var cells: Array = _castle.get("_cells") as Array
	var alive_before := {}
	for index: int in cells.size():
		if bool((cells[index] as Dictionary).get("alive", false)):
			alive_before[index] = true
	var shot := await _fire_castle(Vector3(52.0, 6.0, 968.0), "cell_report")
	await _wait_real(2.2)
	# The event dictionary contains its own position; read it explicitly.
	var impact := _dict(shot.get("impact"))
	var event_dict := _dict(impact.get("event"))
	var event_at := _vec(event_dict.get("position"), Vector3.ZERO)
	var local_event: Vector3 = _castle.to_local(event_at)
	var dead := 0
	print("SHIP63_CELL_EVENT at=%s local=%s radius=%s power=%s blast=%d" % [
		str(event_at), str(local_event), str(event_dict.get("radius", 0.0)),
		str(event_dict.get("power", 0.0)), int(shot.get("blast", -1))])
	for index: int in cells.size():
		var cell: Dictionary = cells[index]
		if bool(cell.get("alive", true)):
			continue
		if alive_before.has(index):
			dead += 1
			var distance := 0.0
			if _castle.has_method("_cell_distance55"):
				distance = float(_castle.call("_cell_distance55", cell, local_event))
			var at := _vec(cell.get("at"), Vector3.ZERO)
			print("SHIP63_CELL i=%d group=%s mat=%s at=%s size=%s d=%.2f shape=%s" % [
				index, str(cell.get("group", "")), str(cell.get("material", "")),
				str(at), str(cell.get("size", Vector3.ZERO)), distance,
				str(cell.get("shape", "box"))])
	print("SHIP63_CELL_TOTAL dead=%d" % dead)
	quit(0)


# ================================================================== screenshots
func _run_shots() -> void:
	var out_dir := OS.get_environment("DSH_SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OUT_DEFAULT
	if out_dir.ends_with("/") or out_dir.ends_with("\\"):
		out_dir = out_dir.substr(0, out_dir.length() - 1)
	var make_error := DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHIP63_SHOTS_START tag=", _tag, " dir=", out_dir, " make_dir=", make_error,
		" renderer=", RenderingServer.get_current_rendering_method())

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i(SHOT_W, SHOT_H)
	root.size = Vector2i(SHOT_W, SHOT_H)
	DisplayServer.window_set_size(Vector2i(SHOT_W, SHOT_H))

	var scene_ok: bool = await _load_scene()
	if not scene_ok:
		print("SHIP63_SHOTS_FAIL no_scene")
		quit(1)
		return
	_host.call("debug_reset_ship")
	_boat.call("set_sails", false)
	_boat.call("steer", 0.0)
	if _boat.has_method("set_autopilot"):
		_boat.call("set_autopilot", false)
	await _settle(20)

	var camera := Camera3D.new()
	camera.name = "Ship63ShotCamera"
	camera.fov = 55.0
	camera.near = 0.05
	camera.far = 1200.0
	_scene.add_child(camera)
	camera.current = true
	var hud_layers: Array = []
	_collect_canvas_layers(_scene, hud_layers)
	_hide_hud(hud_layers)

	var target := await _resolve_target()
	var target_boat: Node3D = target.get("boat") as Node3D
	var saved: Array[String] = []
	var failed := 0
	if not is_instance_valid(target_boat):
		print("SHIP63_SHOTS_TARGET_FAIL")
		failed += 1
	else:
		print("SHIP63_SHOTS_TARGET source=%s berth=%s" % [str(target.get("source", "")),
			str(target_boat.global_position)])

	# 1. both ships at rest
	if is_instance_valid(target_boat):
		var mid: Vector3 = (_boat.global_position + target_boat.global_position) * 0.5
		camera.fov = 55.0
		camera.global_position = mid + Vector3(0.0, 11.0, 44.0)
		camera.look_at(mid + Vector3(0.0, 1.0, -6.0), Vector3.UP)
		camera.current = true
		await _settle(10)
		if await _save(camera, out_dir, "f_01_target_side", saved):
			pass
		else:
			failed += 1
		# 2/3/4. gunner camera, shot and hit
		failed += await _shoot_target_sequence(camera, target_boat, hud_layers, out_dir, saved)
	# 5. small breach in the castle wall
	failed += await _wall_breach_shot(camera, out_dir, saved)

	_show_hud(hud_layers)
	var ok := failed == 0
	if ok:
		print("SHIP63_SHOTS_OK saved=%d names=%s dir=%s" % [saved.size(),
			JSON.stringify(saved), out_dir])
		quit(0)
	else:
		print("SHIP63_SHOTS_FAIL saved=%d failed=%d names=%s" % [saved.size(), failed,
			JSON.stringify(saved)])
		quit(1)


func _shoot_target_sequence(camera: Camera3D, target_boat: Node3D, hud_layers: Array,
		out_dir: String, saved: Array[String]) -> int:
	var failed := 0
	# Pick the gun whose broadside faces the target.
	var to_target: Vector3 = target_boat.global_position - _boat.global_position
	to_target.y = 0.0
	var best_gun := 0
	var best_dot := -2.0
	for index: int in 4:
		var outward := _vec(_cannons.call("_gun_rest_outward_world", index), Vector3.RIGHT)
		var dot := outward.normalized().dot(to_target.normalized())
		if dot > best_dot:
			best_dot = dot
			best_gun = index
	_host.call("debug_set_station", "cannon", best_gun)
	await _settle(25)
	_show_hud(hud_layers)
	await _settle(6)
	var gun_camera := _host.get("_gun_camera") as Camera3D
	var mount := _vec(_cannons.call("mount_world", best_gun), Vector3.ZERO)
	var muzzle := _vec(_cannons.call("_muzzle_world", best_gun), mount)
	var barrel_len := mount.distance_to(muzzle)
	print("SHIP63_SHOTS_CAMERA gun=%d camera=%s eye_to_mount=%.2f barrel=%.2f fov=%.1f"
		% [best_gun, str(gun_camera.global_position if is_instance_valid(gun_camera) else Vector3.ZERO),
		(gun_camera.global_position.distance_to(mount) if is_instance_valid(gun_camera) else -1.0),
		barrel_len, gun_camera.fov if is_instance_valid(gun_camera) else -1.0])
	if await _save(null, out_dir, "f_02_cannon_camera", saved):
		pass
	else:
		failed += 1

	# Aim with the same ballistic solve debug_fire_at uses, then load/fire through the
	# host's real R / LMB path.
	var to_shooter := target_boat.to_local(_boat.global_position)
	var side := 1.0 if to_shooter.x >= 0.0 else -1.0
	var point: Vector3 = target_boat.to_global(Vector3(3.6 * side, 1.2, 0.0))
	var horizontal := Vector3(point.x - muzzle.x, 0.0, point.z - muzzle.z)
	var distance := horizontal.length()
	var gun_outward := _vec(_cannons.call("_gun_rest_outward_world", best_gun), Vector3.RIGHT)
	var yaw := gun_outward.signed_angle_to(horizontal.normalized(), Vector3.UP)
	var pitch := float(_cannons.call("_ballistic_pitch", distance, point.y - muzzle.y,
		CannonsScript.BALL_SPEED))
	_cannons.call("set_aim_degrees", rad_to_deg(yaw), rad_to_deg(pitch))
	await _settle(40)
	_host.call("_load_manning_cannon")
	await _wait_real(1.35)
	_host.call("_fire_manning_cannon")
	var state := _dict(_cannons.call("state"))
	print("SHIP63_SHOTS_FIRE loaded=%s shots=%d" % [str(state.get("loading", false)),
		int(state.get("shots", 0))])
	await _save(null, out_dir, "f_03_target_shot", saved)
	var impact := await _wait_live_impact(_cannons, int(state.get("shots", 0)), 8.0)
	var kind := str(impact.get("type", "none"))
	print("SHIP63_SHOTS_TARGET_IMPACT kind=%s target=%s at=%s" % [kind,
		str(impact.get("target_type", "")), str(impact.get("position", Vector3.ZERO))])
	_host.call("debug_set_station", "leave")
	_hide_hud(hud_layers)
	await _settle(4)
	if not impact.is_empty():
		var hit_at := _vec(impact.get("position"), point)
		var direction := _vec(impact.get("direction"), Vector3.RIGHT)
		camera.fov = 48.0
		camera.global_position = hit_at - direction * 12.0 + Vector3.UP * 3.6 \
			+ direction.cross(Vector3.UP) * 4.0
		camera.look_at(hit_at, Vector3.UP)
		camera.current = true
		await _settle(3)
		if await _save(null, out_dir, "f_04_target_hit", saved):
			pass
		else:
			failed += 1
	else:
		failed += 1
		print("SHIP63_SHOTS_FAIL no target impact")
	return failed


func _wall_breach_shot(camera: Camera3D, out_dir: String, saved: Array[String]) -> int:
	var level := _water_level()
	_boat.call("moor", Vector3(58.0, level, 994.0), deg_to_rad(-90.0))
	_boat.call("set_sails", false)
	_boat.call("steer", 0.0)
	await _settle(12)
	var point := Vector3(44.0, 6.0, 968.0)
	var shots0 := int(_dict(_cannons.call("state")).get("shots", 0))
	var fired := _dict(_cannons.call("debug_fire_at", point))
	if not bool(fired.get("ok", false)):
		print("SHIP63_SHOTS_FAIL wall_fire reason=", str(fired.get("reason", "")))
		return 1
	# debug_fire_at mans a gun: leave at once so the green aim dots are not in the photo.
	_cannons.call("leave")
	var impact := await _wait_live_impact(_cannons, shots0 + 1, 8.0)
	if impact.is_empty():
		print("SHIP63_SHOTS_FAIL wall_no_impact")
		return 1
	var hit_at := _vec(impact.get("position"), point)
	print("SHIP63_SHOTS_WALL kind=%s at=%s detached=%d" % [str(impact.get("type", "")),
		str(hit_at), int(_dict(impact.get("result")).get("detached", -1))])
	await _wait_real(0.3)
	camera.fov = 50.0
	camera.global_position = hit_at + Vector3(-7.0, 1.2, 9.0)
	camera.look_at(hit_at + Vector3(0.0, -0.8, 0.0), Vector3.UP)
	camera.current = true
	await _settle(6)
	if await _save(null, out_dir, "f_05_wall_breach", saved):
		return 0
	return 1


func _collect_canvas_layers(node: Node, out: Array) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			out.append([child, (child as CanvasLayer).visible])
		_collect_canvas_layers(child, out)


func _hide_hud(layers: Array) -> void:
	for entry: Array in layers:
		if is_instance_valid(entry[0]):
			(entry[0] as CanvasLayer).visible = false


func _show_hud(layers: Array) -> void:
	for entry: Array in layers:
		if is_instance_valid(entry[0]):
			(entry[0] as CanvasLayer).visible = bool(entry[1])


func _save(camera: Camera3D, out_dir: String, name: String, saved: Array[String]) -> bool:
	if not _only.is_empty():
		var matched := false
		for token: String in _only:
			if name.contains(token):
				matched = true
				break
		if not matched:
			print("SHIP63_SHOTS_FILTERED ", name)
			return true
	if is_instance_valid(camera):
		camera.current = true
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("SHIP63_SHOTS_FAIL ", name, " image=null")
		return false
	var path := out_dir.path_join("%s.png" % name)
	var error := image.save_png(path)
	if error == OK:
		saved.append("%s.png" % name)
		print("SHIP63_SHOTS_SAVED ", path, " size=", image.get_width(), "x",
			image.get_height())
		return true
	print("SHIP63_SHOTS_FAIL ", path, " err=", error)
	return false


func _vec(value: Variant, fallback: Vector3) -> Vector3:
	return value as Vector3 if value is Vector3 else fallback
