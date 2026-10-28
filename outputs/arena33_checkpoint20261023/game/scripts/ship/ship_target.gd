extends Node3D
## SHIP63 / agent T — the second, identical ship used as a live damage target.
##
## The hulk owns its own `ShipModel` and `ShipBoat` instances built from exactly the
## same scripts as the player's ship: the same hull, decks, fittings, 64 collision
## shapes, the same flooding and sinking behaviour. It has no guns, no stations and
## no player control; the integrator only has to call `install()` (QA may call
## `sink_test()` / `reset()`).
##
## Berth: `(160, -0.55, 975)`, yaw 0° (bow north). The player's ship stands at
## `(115, -0.55, 975)` on the same heading, so the two hulls lie broadside to
## broadside 45 m apart centre to centre: the target's port side (local -X) faces
## the player's starboard battery. The berth is verified on install: depth at the
## centre, the bow, the stern and the two forward quarters, plus a box overlap query
## that must find no castle, quay or pier collision.
##
## Local frame, inherited from ship_boat.gd: +Z stern, -Z bow, +X starboard,
## y = 0 at the waterline.

const ShipBoatScr := preload("res://scripts/ship/ship_boat.gd")

## Loaded lazily, like the host does: a model file that is still being written must
## not stop the target (or the map) from booting.
const SHIP_MODEL_PATH := "res://scripts/ship/ship_model.gd"

const TARGET_POSITION := Vector3(160.0, -0.55, 975.0)
const TARGET_YAW_DEG := 0.0
const TARGET_SHIP_NAME := "TargetShip"

const DEFAULT_WATER_LEVEL := -0.55
## A 26 m hull draws ~1.8 m; anything shallower than this is not a berth but a shoal.
const MIN_BERTH_DEPTH := 6.0
const BERTH_DEPTH_REPORTED := 7.0

## QA strike numbers. 120 is the number the host's own `debug_hit_ship()` uses; one
## such hit punches the largest hull hole the damage model allows (r = 1.2 m).
const QA_SHOT_DAMAGE := 120.0
const QA_SHOT_IMPULSE := 8.0
const MAX_QA_SHOTS := 24
const SIM_STEP := 1.0 / 60.0
const SINK_EXTRA_SIM := 2.0
const AUTO_SINK_CAP := 120.0

## Hull hit points (ship-local).  `side` is -1 port / +1 starboard; `x` is resolved
## against the real hull surface (`ShipModel._hull_x_at`) at install time so the hole
## decal sits on the planking instead of floating beside it or hiding inside it.
## All of them sit below y = 1.95 so `_classify_zone` calls them `hull`, and all of
## them clear the four cannon mounts (r = 1.9) so a hit is never reclassified as
## `cannon_N`.  Four of the six are on the port side, which gives the flooding a
## genuine list instead of a symmetric squat.
const HULL_SHOTS := [
	{"z": -8.0, "side": -1.0, "y": 1.20},
	{"z": -2.0, "side": -1.0, "y": 1.20},
	{"z": 0.6, "side": 1.0, "y": 1.20},
	{"z": 6.5, "side": -1.0, "y": 1.20},
	{"z": -4.0, "side": -1.0, "y": 1.20},
	{"z": 3.0, "side": 1.0, "y": 1.20},
]
## Dead on the mast axis (r = 1.25 around (0, -1)), 12 m up the stick.
const MAST_SHOT := Vector3(0.0, 12.0, -1.0)

var world: Node3D = null
var basin: Object = null
var player: CharacterBody3D = null
var boat: AnimatableBody3D = null
var model: Node3D = null

var _installed := false
var _berth := TARGET_POSITION
var _berth_yaw := 0.0
var _length := 26.0
var _beam := 8.8
var _deck_y := 1.75
var _debris_root: Node3D = null
var _collision_shapes := 0
var _model_built := false
var _install_result: Dictionary = {}
var _shots_fired := 0
var _last_hit: Dictionary = {}


## ------------------------------------------------------------------ install

func install(world_in: Node3D, basin_in: Object, player_in: CharacterBody3D,
		berth_position: Vector3 = TARGET_POSITION, yaw: float = 0.0) -> Dictionary:
	## `yaw` is in radians, like `ShipBoat.moor()`; the host passes
	## `deg_to_rad(TARGET_YAW_DEG)`. Defaults are the contract berth.
	if _installed:
		return {"ok": false, "reason": "already_installed", "position": _berth}
	if not is_instance_valid(world_in):
		return {"ok": false, "reason": "missing_world"}
	if not is_instance_valid(basin_in):
		return {"ok": false, "reason": "missing_basin"}
	world = world_in
	basin = basin_in
	player = player_in if is_instance_valid(player_in) else null
	if get_parent() == null:
		world.add_child(self)
	var berth := berth_position
	if not berth.is_finite():
		berth = TARGET_POSITION
	var level := _water_level()
	_berth = Vector3(berth.x, level, berth.z)
	_berth_yaw = wrapf(yaw if is_finite(yaw) else 0.0, -PI, PI)
	set_meta("ship63_target", true)
	if not is_in_group("ship_target"):
		add_to_group("ship_target")
	return _spawn_ship()


func _spawn_ship() -> Dictionary:
	## Builds the model first, then the hull, exactly like the player's ship does.
	_model_built = false
	var model_script: Script = load(SHIP_MODEL_PATH)
	if model_script == null:
		return {"ok": false, "reason": "model_missing"}
	var built: Dictionary = {}
	model = model_script.new()
	model.name = "TargetShipModel"
	add_child(model)
	var raw: Variant = model.call("build")
	if raw is Dictionary:
		built = raw as Dictionary
	_model_built = not built.is_empty()
	_read_build(built)

	boat = ShipBoatScr.new()
	boat.name = TARGET_SHIP_NAME
	add_child(boat)
	var before := _world_children()
	var installed: Dictionary = boat.call("install", world, basin, player, model)
	if not bool(installed.get("ok", false)):
		_dispose_ship()
		_installed = false
		return {"ok": false, "reason": "boat_install_failed", "boat": installed}
	_debris_root = _new_debris_root(before)
	_collision_shapes = _count_collision_shapes(boat)

	boat.call("moor", _berth, _berth_yaw)
	boat.call("set_autopilot", true)
	boat.call("set_sails", false)
	boat.call("steer", 0.0)
	# A moored hulk lays no wake: switching the whole foam system off saves three
	# draw calls and the per-step wake work, and nothing about the ship changes.
	if boat.has_method("set_wake_enabled"):
		boat.call("set_wake_enabled", false)
	# A target hulk 45 m away does not need to feed the shadow pass; the second
	# full ship is the biggest new render cost, so keep it out of the shadow map.
	_disable_shadows(model)
	_installed = true

	var report := berth_report()
	_install_result = {
		"ok": true,
		"name": TARGET_SHIP_NAME,
		"node": str(name),
		"berth": _berth,
		"position": _boat_position(),
		"yaw_deg": rad_to_deg(_berth_yaw),
		"water_level": _water_level(),
		"depth": report.get("depth_center", 0.0),
		"depth_bow": report.get("depth_bow", 0.0),
		"depth_stern": report.get("depth_stern", 0.0),
		"min_depth": report.get("min_depth", 0.0),
		"navigable": report.get("navigable", false),
		"depth_ok": report.get("ok", false),
		"overlaps": report.get("overlaps", 0),
		"overlap_names": report.get("overlap_names", []),
		"collision_shapes": _collision_shapes,
		"model_built": _model_built,
		"length": _length,
		"beam": _beam,
		"deck_y": _deck_y,
		"autopilot": true,
		"sails_open": sails_open(),
		"rudder": _boat_float("rudder", 0.0),
		"wake_enabled": false,
	}
	print("SHIP63_TARGET_INSTALL ", JSON.stringify({
		"berth": _berth, "yaw_deg": rad_to_deg(_berth_yaw), "depth": _install_result.depth,
		"min_depth": _install_result.min_depth, "navigable": _install_result.navigable,
		"shapes": _collision_shapes, "model_built": _model_built,
		"overlaps": _install_result.overlaps, "overlap_names": _install_result.overlap_names}))
	return _install_result


func _read_build(build: Dictionary) -> void:
	_length = maxf(6.0, _num(build.get("length", null), 26.0))
	_beam = maxf(2.0, _num(build.get("beam", null), 8.8))
	_deck_y = _num(build.get("deck_y", null), 1.75)


## ------------------------------------------------------------------ lifecycle

func reset() -> Dictionary:
	## Removes the damaged hulk and builds an identical one on the same berth.
	_shots_fired = 0
	_last_hit = {}
	if not _installed:
		return {"ok": false, "reason": "not_installed", "position": _berth}
	_dispose_ship()
	_installed = false
	var result := _spawn_ship()
	result["reset"] = true
	if bool(result.get("ok", false)):
		print("SHIP63_TARGET_RESET pos=", _berth, " yaw_deg=", rad_to_deg(_berth_yaw),
			" shapes=", _collision_shapes)
	return result


func dispose() -> void:
	## The integrator's teardown hook: leaves no debris container behind in the world.
	if is_instance_valid(boat) and boat.has_method("set_autopilot"):
		boat.call("set_autopilot", false)
	_dispose_ship()
	_installed = false


func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_disable_shadows(child)


func _dispose_ship() -> void:
	if is_instance_valid(model) and model.get_parent() == self:
		remove_child(model)
		model.queue_free()
	model = null
	if is_instance_valid(boat):
		if boat.has_method("set_autopilot"):
			boat.call("set_autopilot", false)
		if boat.get_parent() == self:
			remove_child(boat)
		boat.queue_free()
	boat = null
	if is_instance_valid(_debris_root):
		var parent := _debris_root.get_parent()
		if parent != null:
			parent.remove_child(_debris_root)
		_debris_root.queue_free()
	_debris_root = null


## ------------------------------------------------------------------ berth QA

func berth_report() -> Dictionary:
	## Depth under the keel and a shape overlap probe around the hull. A clear berth
	## is `ok` when the shallowest of the five hull samples is at least MIN_BERTH_DEPTH
	## and nothing solid intersects the hull box.
	var level := _water_level()
	var origin := Vector3(_berth.x, level, _berth.z)
	var basis := Basis(Vector3.UP, _berth_yaw)
	var bow := origin + basis * Vector3(0.0, 0.0, -_length * 0.5)
	var stern := origin + basis * Vector3(0.0, 0.0, _length * 0.5)
	var port_bow := origin + basis * Vector3(-_beam * 0.5, 0.0, -_length * 0.5)
	var starboard_quarter := origin + basis * Vector3(_beam * 0.5, 0.0, _length * 0.5)
	var depth_center := _depth_at(origin.x, origin.z)
	var depth_bow := _depth_at(bow.x, bow.z)
	var depth_stern := _depth_at(stern.x, stern.z)
	var depth_port_bow := _depth_at(port_bow.x, port_bow.z)
	var depth_starboard_quarter := _depth_at(starboard_quarter.x, starboard_quarter.z)
	var min_depth := minf(depth_center, minf(depth_bow, minf(depth_stern,
		minf(depth_port_bow, depth_starboard_quarter))))
	var probe := _collision_probe()
	return {
		"ok": min_depth >= MIN_BERTH_DEPTH and int(probe.get("count", 0)) == 0,
		"berth": origin,
		"yaw_deg": rad_to_deg(_berth_yaw),
		"water_level": level,
		"depth_center": depth_center,
		"depth_bow": depth_bow,
		"depth_stern": depth_stern,
		"depth_port_bow": depth_port_bow,
		"depth_starboard_quarter": depth_starboard_quarter,
		"min_depth": min_depth,
		"expected_depth": BERTH_DEPTH_REPORTED,
		"navigable": _is_navigable(origin.x, origin.z),
		"overlaps": int(probe.get("count", 0)),
		"overlap_names": probe.get("names", []),
	}


func _collision_probe() -> Dictionary:
	var result := {"count": 0, "names": []}
	if not is_inside_tree() or not is_instance_valid(boat):
		return result
	var space := get_world_3d().direct_space_state
	if space == null:
		return result
	var shape := BoxShape3D.new()
	shape.size = Vector3(_beam + 1.0, 4.6, _length + 1.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP, _berth_yaw),
		Vector3(_berth.x, 1.35, _berth.z))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var exclude: Array[RID] = []
	if boat is CollisionObject3D:
		exclude.append((boat as CollisionObject3D).get_rid())
	query.exclude = exclude
	var hits := space.intersect_shape(query, 32)
	var names: Array[String] = []
	for hit: Dictionary in hits:
		var collider: Variant = hit.get("collider", null)
		if collider is Node:
			names.append(str((collider as Node).name))
	result["count"] = hits.size()
	result["names"] = names
	return result


## ------------------------------------------------------------------ API

func snapshot() -> Dictionary:
	var state: Dictionary = {}
	if is_instance_valid(boat) and boat.has_method("snapshot"):
		var raw: Variant = boat.call("snapshot")
		if raw is Dictionary:
			state = raw as Dictionary
	var sunk := bool(state.get("sunk", false))
	var usable := _installed and not sunk
	if state.has("usable"):
		usable = usable and bool(state.get("usable"))
	var position: Vector3 = _berth
	if state.get("position", null) is Vector3:
		position = state.get("position") as Vector3
	elif is_instance_valid(boat):
		position = boat.global_position
	var holes := int(state.get("holes", 0))
	return {
		"ok": _installed,
		"installed": _installed,
		"name": TARGET_SHIP_NAME,
		"berth": _berth,
		"position": position,
		"yaw_deg": rad_to_deg(_berth_yaw),
		"speed": _num(state.get("speed", null), 0.0),
		"flooding": _num(state.get("flooding", null), 0.0),
		"flood_rate": _num(state.get("flood_rate", null), 0.0),
		"integrity": _num(state.get("integrity", null), 1.0),
		"hull_damage": _num(state.get("hull_damage", null), 0.0),
		"holes": holes,
		"hole_worlds": state.get("hole_worlds", []),
		"mast_hp": _num(state.get("mast_hp", null), 0.0),
		"mast_broken": bool(state.get("mast_broken", false)),
		"broken_parts": state.get("broken_parts", []),
		"sunk": sunk,
		"usable": usable,
		"sink_t": _num(state.get("sink_t", null), 0.0),
		"sails_open": bool(state.get("sails_open", false)),
		"rudder": _num(state.get("rudder", null), 0.0),
		"rudder_target": _num(state.get("rudder_target", null), 0.0),
		"pitch_deg": _num(state.get("pitch_deg", null), 0.0),
		"roll_deg": _num(state.get("roll_deg", null), 0.0),
		"heel_deg": _num(state.get("heel_deg", null), 0.0),
		"water_level": _num(state.get("water_level", null), _water_level()),
		"depth_center": _num(state.get("depth_center", null), 0.0),
		"depth_bow": _num(state.get("depth_bow", null), 0.0),
		"aground": bool(state.get("aground", false)),
		"debris": int(state.get("debris", 0)),
		"collision_shapes": _collision_shapes,
		"model_built": _model_built,
		"length": _length,
		"beam": _beam,
		"deck_y": _deck_y,
		"autopilot": _installed,
		"shots_fired": _shots_fired,
		"last_hit": _last_hit.duplicate(),
	}


func sink_test(shots: int, simulate_seconds: float = -1.0,
		damage: float = QA_SHOT_DAMAGE) -> Dictionary:
	## Hurls `shots` QA cannon hits at the hulk and returns the resulting state.
	## The plan alternates hull hits along the port side with mast hits: two mast hits
	## (240 damage) fell the 220 HP mast, the rest punch holes and start the flooding.
	##
	## `simulate_seconds`:
	##   < 0 (default, and only when shots > 0) — advance the ship's own simulation
	##       until she is under plus two seconds, capped at 120 s, so a single
	##       `sink_test(6)` really ends with `sunk=true, usable=false`;
	##     0 — damage only, the caller drives the frame loop;
	##   > 0 — advance exactly that many seconds synchronously.
	var state := snapshot()
	if not _installed or not is_instance_valid(boat):
		state["ok"] = false
		state["reason"] = "not_installed"
		return state
	var count := clampi(shots, 0, MAX_QA_SHOTS)
	var hit_damage := damage
	if not is_finite(hit_damage) or hit_damage <= 0.0:
		hit_damage = QA_SHOT_DAMAGE
	var plan := _shot_plan(count)
	var hits: Array[Dictionary] = []
	for entry: Dictionary in plan:
		var local: Vector3 = entry.get("local", Vector3.ZERO)
		var world_point := _world_point(local)
		var direction := _outward(local)
		var hit: Dictionary = boat.call("apply_hit", world_point, hit_damage,
			direction * QA_SHOT_IMPULSE, "cannonball")
		_shots_fired += 1
		_last_hit = hit
		hits.append({
			"local": local,
			"world": world_point,
			"zone": str(hit.get("zone", "")),
			"damage": _num(hit.get("damage", null), 0.0),
			"hole": bool(hit.get("hole", false)),
			"part": str(hit.get("part", "")),
			"flooding": _num(hit.get("flooding", null), 0.0),
		})
	var simulated := 0.0
	if simulate_seconds < 0.0:
		if count > 0:
			simulated = _advance_until_sunk(AUTO_SINK_CAP)
	elif simulate_seconds > 0.0:
		simulated = _advance(simulate_seconds)
	var result := snapshot()
	result["shots"] = count
	result["damage_per_shot"] = hit_damage
	result["hits"] = hits
	result["simulated_seconds"] = simulated
	result["seconds_to_sink"] = _seconds_to_sink(result)
	print("SHIP63_TARGET_SINK_TEST ", JSON.stringify({
		"shots": count, "holes": result.holes, "mast_broken": result.mast_broken,
		"flooding": result.flooding, "flood_rate": result.flood_rate,
		"sunk": result.sunk, "usable": result.usable,
		"simulated_seconds": simulated,
		"seconds_to_sink": result.seconds_to_sink}))
	return result


func _shot_plan(count: int) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var hull_index := 0
	for index in count:
		var mast := index > 0 and index % 3 == 2
		if mast:
			plan.append({"local": MAST_SHOT, "zone": "mast"})
		else:
			var spec: Dictionary = HULL_SHOTS[hull_index % HULL_SHOTS.size()]
			var z := float(spec.get("z", 0.0))
			var side := float(spec.get("side", -1.0))
			var y := float(spec.get("y", 1.2))
			var half_width := _hull_half_width(z, y)
			plan.append({"local": Vector3(side * maxf(0.5, half_width - 0.03), y, z),
				"zone": "hull"})
			hull_index += 1
	return plan


func _hull_half_width(z: float, y: float) -> float:
	## Where the outer planking actually is at this station, so a cannonball hole and
	## its dark decal sit on the hull.  Falls back to half the beam.
	if is_instance_valid(model) and model.has_method("_hull_x_at"):
		var value: Variant = model.call("_hull_x_at", z, y)
		if value is float:
			var width := float(value)
			if is_finite(width) and width > 0.5:
				return width
	return _beam * 0.5


func _advance(seconds: float) -> float:
	## Steps the ship's own simulation synchronously. Returns the simulated time.
	if not is_instance_valid(boat):
		return 0.0
	var total := clampf(seconds, 0.0, 240.0)
	var elapsed := 0.0
	var after_sink := 0.0
	while elapsed < total:
		var dt := minf(SIM_STEP, total - elapsed)
		boat.call("simulate_step", dt)
		elapsed += dt
		if is_sunk():
			after_sink += dt
			if after_sink >= SINK_EXTRA_SIM:
				break
	return elapsed


func _advance_until_sunk(cap_seconds: float) -> float:
	## One-call QA sink: floods until the hull goes under, then two more seconds so
	## `sink_t` and the visual descent are non-zero. Capped so a target that cannot
	## sink (e.g. no holes) can never hang the caller.
	if not is_instance_valid(boat):
		return 0.0
	var total := clampf(cap_seconds, 0.0, 240.0)
	var elapsed := 0.0
	var after_sink := 0.0
	while elapsed < total:
		boat.call("simulate_step", SIM_STEP)
		elapsed += SIM_STEP
		if is_sunk():
			after_sink += SIM_STEP
			if after_sink >= SINK_EXTRA_SIM:
				break
	return elapsed


func _seconds_to_sink(state: Dictionary) -> float:
	if bool(state.get("sunk", false)):
		return 0.0
	var rate := _num(state.get("flood_rate", null), 0.0)
	if rate <= 0.0:
		return -1.0
	var flooding := _num(state.get("flooding", null), 0.0)
	return maxf(0.0, (1.0 - flooding) / rate)


func usable() -> bool:
	return _installed and not is_sunk()


func is_sunk() -> bool:
	if not is_instance_valid(boat) or not boat.has_method("is_sunk"):
		return false
	return bool(boat.call("is_sunk"))


func is_installed() -> bool:
	return _installed


func set_sails(open: bool) -> bool:
	## A sinking hulk refuses canvas; otherwise this is a pass-through to the boat.
	if not usable() or not is_instance_valid(boat):
		return false
	if boat.has_method("set_sails"):
		boat.call("set_sails", open)
	return sails_open()


func steer(axis: float) -> bool:
	## A sinking hulk does not answer the helm either. Returns true when applied.
	if not usable() or not is_instance_valid(boat):
		return false
	if boat.has_method("steer"):
		boat.call("steer", axis)
	return true


func sails_open() -> bool:
	if is_instance_valid(boat) and boat.has_method("sails_open"):
		return bool(boat.call("sails_open"))
	return false


func set_autopilot(enabled: bool) -> void:
	if is_instance_valid(boat) and boat.has_method("set_autopilot"):
		boat.call("set_autopilot", enabled)


func set_wake_enabled(enabled: bool) -> void:
	if is_instance_valid(boat) and boat.has_method("set_wake_enabled"):
		boat.call("set_wake_enabled", enabled)


func position() -> Vector3:
	return _boat_position()


func length() -> float:
	return _length


func beam() -> float:
	return _beam


## ------------------------------------------------------------------ helpers

func _boat_position() -> Vector3:
	if is_instance_valid(boat):
		return boat.global_position
	return _berth


func _boat_float(key: String, fallback: float) -> float:
	var state := snapshot()
	return _num(state.get(key, null), fallback)


func _water_level() -> float:
	if basin != null and basin.has_method("water_level"):
		var value: Variant = basin.call("water_level")
		if value is float or value is int:
			var level := float(value)
			if is_finite(level):
				return level
	return DEFAULT_WATER_LEVEL


func _depth_at(x: float, z: float) -> float:
	if basin != null and basin.has_method("depth_at"):
		var value: Variant = basin.call("depth_at", x, z)
		if value is float or value is int:
			var depth := float(value)
			if is_finite(depth):
				return depth
	return 0.0


func _is_navigable(x: float, z: float) -> bool:
	if basin != null and basin.has_method("is_navigable"):
		var value: Variant = basin.call("is_navigable", x, z, 1.8)
		if value is bool:
			return bool(value)
	return _depth_at(x, z) >= MIN_BERTH_DEPTH


func _world_point(local: Vector3) -> Vector3:
	if is_instance_valid(boat) and boat.has_method("world_deck"):
		var value: Variant = boat.call("world_deck", local)
		if value is Vector3:
			return value as Vector3
	if is_instance_valid(boat):
		return boat.to_global(local)
	return _berth + local


func _outward(local: Vector3) -> Vector3:
	var flat := Vector3(local.x, 0.0, local.z)
	if flat.length_squared() < 0.01:
		flat = Vector3(0.0, 0.0, -1.0)
	return flat.normalized()


func _count_collision_shapes(root: Node) -> int:
	var total := 0
	for child: Node in root.get_children():
		if child is CollisionShape3D:
			total += 1
		total += _count_collision_shapes(child)
	return total


func _world_children() -> Array[Node]:
	var list: Array[Node] = []
	if is_instance_valid(world):
		for child: Node in world.get_children():
			list.append(child)
	return list


func _new_debris_root(before: Array[Node]) -> Node3D:
	## ShipBoat creates its own "ShipDebris" container in the world. The target must
	## remember which one is its own so reset() can take the wreckage with it.
	if not is_instance_valid(world):
		return null
	for child: Node in world.get_children():
		if before.has(child):
			continue
		if child is Node3D and str(child.name).begins_with("ShipDebris"):
			return child as Node3D
	return null


func _num(value: Variant, fallback: float) -> float:
	if value is float:
		var as_float := float(value)
		return as_float if is_finite(as_float) else fallback
	if value is int:
		return float(value)
	return fallback
