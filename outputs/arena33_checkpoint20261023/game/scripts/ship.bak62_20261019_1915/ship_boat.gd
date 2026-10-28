extends AnimatableBody3D
## SHIP61 (agent C) — the ship as a kinematic platform with buoyancy, sailing, rudder,
## flooding from hull holes and destructible parts.
##
## Design notes:
##  - The hull is NOT a RigidBody. It is an AnimatableBody3D driven every physics tick:
##    heave/pitch/roll come from `basin.water_height_at` samples on the waterline, the
##    course comes from the sail/rudder model. `sync_to_physics = true` makes the deck a
##    moving platform for CharacterBody3D players.
##  - `sync_to_physics` bodies take their transform from the physics body state, and a
##    plain `global_position` write outside a physics step is reverted on the next step.
##    The ship therefore keeps its own authoritative transform (`_origin`, `_yaw`,
##    `_pitch`, `_roll`), rebuilds it once per step and pushes it both to the node and to
##    `PhysicsServer3D`. That makes `simulate_step()` valid in and out of the tree (QA
##    drives it headless), while the live game still gets a normal moving platform.
##  - All foreign APIs (`ship_water_basin.gd`, `ship_model.gd`) are called dynamically
##    through `has_method`/`call`, because the agents that own them work in parallel and
##    may deliver a partial or differently-shaped dictionary. Every public method is
##    tolerant to null/invalid nodes.
##
## Local frame (contract): +Z stern, -Z bow, +X starboard, y=0 waterline.

const DEFAULT_WATER_LEVEL := -0.55
const START_WORLD := Vector3(62.0, -0.55, 988.0)
const START_YAW_DEG := -65.0

const HULL_LENGTH := 26.0
const HULL_BEAM := 8.8
const DECK_Y := 1.75

const MAX_SPEED := 6.5
const ACCEL := 0.55
const BRAKE := 0.75
const MAST_BRAKE := 1.6
const MAX_TURN_RAD := 0.3141592653589793 # 18 deg/s
const YAW_ACCEL := 0.70
const RUDDER_RATE := 2.4

## Forward water samples: 2-3 hull lengths would point past the bay mouth at the contract
## berth, so the navigability probe looks 9/15/21 m ahead (the bow is at 13 m).
const AHEAD_SAMPLES := [9.0, 15.0, 21.0]
const NAV_DRAFT := 1.8

const MAST_HP := 220.0
const DEFAULT_PART_HP := 120.0
const CANNON_HP := 160.0
const HULL_MAX_DAMAGE := 520.0

const HOLE_FLOOD_RATE := 0.005 # flooding per second per unit of hole severity
const MAX_HOLES := 24
const FLOOD_SINK_HEIGHT := 2.2
const FLOOD_REPAIR_RELIEF := 0.05
const SINK_SECONDS := 10.0
const SINK_DEPTH := 13.0

const MAX_DEBRIS := 40
const DEBRIS_LIFE := 20.0

const CLIMB_SPEED := 2.2
const REPAIR_REACH := 3.2

## Seven waterline samples: 0 bow, 1 stern, 2 port-bow, 3 starboard-bow,
## 4 port-quarter, 5 starboard-quarter, 6 centre.
const SAMPLE_OFFSETS := [
	Vector2(0.0, -11.5),
	Vector2(0.0, 11.5),
	Vector2(-4.0, -5.0),
	Vector2(4.0, -5.0),
	Vector2(-4.0, 5.0),
	Vector2(4.0, 5.0),
	Vector2(0.0, 0.0),
]

var _installed := false
var _autopilot := true

var _world: Node3D = null
var _basin: Object = null
var _player: CharacterBody3D = null
var _model: Node3D = null

var _length := HULL_LENGTH
var _beam := HULL_BEAM
var _deck_y := DECK_Y
var _water_level := DEFAULT_WATER_LEVEL

## Authoritative world transform state (the node is only a mirror of it).
var _origin := START_WORLD
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0

## Anchors (ship-local) taken from `model.build()`.
var _anchors: Dictionary = {}
var _cannon_mounts: Array[Vector3] = []

var _sails_open := false
var _speed := 0.0
var _rudder := 0.0
var _rudder_target := 0.0
var _yaw_rate := 0.0
var _time := 0.0
var _moor_position := START_WORLD
var _moor_yaw := 0.0

var _flooding := 0.0
var _flood_rate := 0.0
var _hull_damage := 0.0
var _mast_hp := MAST_HP
var _mast_broken := false
var _sunk := false
var _sink_t := 0.0
var _holes: Array[Dictionary] = []
var _part_hp: Dictionary = {}
var _broken_parts: Array[String] = []

var _obstacle_blocked := false
var _water_blocked := false
var _collision_disabled := false
var _rail_shapes: Array[CollisionShape3D] = []

var _debris_container: Node3D = null
var _debris_nodes: Array[Node3D] = []
var _debris_life: Array[float] = []
var _rng := RandomNumberGenerator.new()

var _step_transform := Transform3D.IDENTITY
var _carry_compensation := false

var _climb_input_bound := false
var _climb_input := 0.0


## ------------------------------------------------------------------ install

func install(world: Node3D, basin: Object, player: CharacterBody3D, model: Node3D) -> Dictionary:
	if _installed:
		return {"ok": false, "reason": "already_installed", "position": _origin}
	if model == null:
		return {"ok": false, "reason": "no_model"}
	_world = world
	_basin = basin
	_player = player
	_model = model
	if world != null and not is_inside_tree() and get_parent() == null:
		world.add_child(self)
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 1
	_rng.randomize()
	if model.get_parent() != self:
		var old_parent: Node = model.get_parent()
		if old_parent != null:
			old_parent.remove_child(model)
		add_child(model)
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	var build: Dictionary = {}
	if model.has_method("build"):
		var raw: Variant = model.call("build")
		if raw is Dictionary:
			build = raw as Dictionary
	_read_build(build)
	var shapes := _build_collision(build)
	shapes += _build_rails()
	_debris_container = Node3D.new()
	_debris_container.name = "ShipDebris"
	if world != null:
		world.add_child(_debris_container)
	else:
		add_child(_debris_container)
	_install_parts(build)
	_water_level = _basin_water_level()
	_installed = true
	moor(START_WORLD, deg_to_rad(START_YAW_DEG))
	_apply_sails_visual()
	print("SHIP61_BOAT_INSTALL pos=", _origin, " yaw_deg=", rad_to_deg(_yaw),
		" shapes=", shapes, " anchors=", _anchors.size(), " model_build=", not build.is_empty())
	return {
		"ok": true,
		"position": _origin,
		"yaw_deg": rad_to_deg(_yaw),
		"collision_shapes": shapes,
		"water_level": _water_level,
		"length": _length,
		"beam": _beam,
		"deck_y": _deck_y,
		"anchors": _anchors.keys(),
		"model_built": not build.is_empty(),
	}


func is_installed() -> bool:
	return _installed


func _read_build(build: Dictionary) -> void:
	_length = maxf(6.0, _num(build.get("length", null), HULL_LENGTH))
	_beam = maxf(2.0, _num(build.get("beam", null), HULL_BEAM))
	_deck_y = _num(build.get("deck_y", null), DECK_Y)
	_cache_anchors(build)


func _cache_anchors(build: Dictionary) -> void:
	_anchors = {
		"helm": Vector3(0.0, 3.05, 10.4),
		"sail_lever": Vector3(1.0, 2.2, 0.2),
		"crate_ammo": Vector3(-2.0, 0.95, 10.2),
		"crate_boards": Vector3(2.0, 0.95, 10.2),
		"mast_base": Vector3(0.0, 1.75, -1.0),
		"mast_top": Vector3(0.0, 17.7, -1.0),
		"upper_deck": Vector3(0.0, 5.2, -1.2),
		"ladder_base": Vector3(0.0, 1.75, 2.3),
		"ladder_top": Vector3(0.0, 5.2, 2.0),
		"bow": Vector3(0.0, 2.15, -13.0),
	}
	_cannon_mounts = [
		Vector3(-3.55, 1.75, -4.2),
		Vector3(3.55, 1.75, -4.2),
		Vector3(-3.55, 1.75, 3.4),
		Vector3(3.55, 1.75, 3.4),
	]
	for id: String in ["helm", "sail_lever"]:
		var entry: Variant = build.get(id, null)
		if entry is Dictionary:
			var dict := entry as Dictionary
			_anchors[id] = _vector_or(dict.get("position", null), _anchors[id])
	var mast: Variant = build.get("mast", null)
	if mast is Dictionary:
		var mast_dict := mast as Dictionary
		_anchors["mast_base"] = _vector_or(mast_dict.get("base", null), _anchors["mast_base"])
		_anchors["mast_top"] = _vector_or(mast_dict.get("top", null), _anchors["mast_top"])
	var upper: Variant = build.get("upper_deck", null)
	if upper is Dictionary:
		var upper_dict := upper as Dictionary
		_anchors["upper_deck"] = _vector_or(upper_dict.get("position", null), _anchors["upper_deck"])
		_anchors["ladder_base"] = _vector_or(upper_dict.get("ladder_base", null), _anchors["ladder_base"])
	var bow: Variant = build.get("bow", null)
	if bow is Dictionary:
		_anchors["bow"] = _vector_or((bow as Dictionary).get("position", null), _anchors["bow"])
	var crates: Variant = build.get("crates", null)
	if crates is Dictionary:
		var crate_dict := crates as Dictionary
		var pairs := [["ammo", "crate_ammo"], ["boards", "crate_boards"]]
		for pair: Array in pairs:
			var entry: Variant = crate_dict.get(str(pair[0]), null)
			if entry is Dictionary:
				var dict := entry as Dictionary
				_anchors[str(pair[1])] = _vector_or(dict.get("position", null), _anchors[str(pair[1])])
	var cannons: Variant = build.get("cannons", null)
	if cannons is Array and not (cannons as Array).is_empty():
		_cannon_mounts.clear()
		for entry: Variant in (cannons as Array):
			if not entry is Dictionary:
				continue
			var dict := entry as Dictionary
			var index := int(_num(dict.get("index", null), float(_cannon_mounts.size())))
			while _cannon_mounts.size() <= index:
				_cannon_mounts.append(Vector3.ZERO)
			_cannon_mounts[index] = _vector_or(dict.get("mount", null), _cannon_mounts[index])


func _install_parts(build: Dictionary) -> void:
	_part_hp = {
		"mast": MAST_HP,
		"rail": 120.0,
		"crate_ammo": 90.0,
		"crate_boards": 90.0,
		"helm": 120.0,
		"transom": 180.0,
		"bowsprit": 100.0,
		"upper_deck": 260.0,
	}
	for index in 4:
		_part_hp["cannon_%d" % index] = CANNON_HP
	var parts: Variant = build.get("parts", null)
	if parts is Array:
		for entry: Variant in (parts as Array):
			if not entry is Dictionary:
				continue
			var dict := entry as Dictionary
			var id := str(dict.get("id", ""))
			var hp := _num(dict.get("hp", null), 0.0)
			if not id.is_empty() and hp > 0.0:
				_part_hp[id] = hp
	_mast_hp = maxf(1.0, _num(_part_hp.get("mast", null), MAST_HP))
	_broken_parts.clear()


## ------------------------------------------------------------------ transform

func _world_transform() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, _roll)), _origin)


func _sync_transform(force_immediate: bool = false) -> void:
	var xform := _world_transform()
	if not is_inside_tree():
		transform = xform
		return
	var parent := get_parent()
	var local_xform := xform
	if parent is Node3D:
		local_xform = (parent as Node3D).global_transform.affine_inverse() * xform
	var use_physics := sync_to_physics
	# install()/moor() can be called from the host's own `_physics_process`, where the
	# plain write on a sync_to_physics body stays stale until the next step. The host
	# reads `boat.to_global()`/`global_position` immediately to seat the player, so moor
	# forces the node transform through the sync toggle even inside a physics frame.
	var immediate := force_immediate or not Engine.is_in_physics_frame()
	if use_physics and not immediate:
		# Normal live path: the node is a mirror of the body state, which is applied at
		# the end of the physics step.
		transform = local_xform
	else:
		if use_physics:
			sync_to_physics = false
			transform = local_xform
			sync_to_physics = true
		else:
			transform = local_xform
	if use_physics:
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xform)


func _world_from_local(point_local: Vector3) -> Vector3:
	if not point_local.is_finite():
		return _origin
	return _world_transform() * point_local


func _local_from_world(point_world: Vector3) -> Vector3:
	if not point_world.is_finite():
		return Vector3.ZERO
	return _world_transform().affine_inverse() * point_world


func local_of(point_world: Vector3) -> Vector3:
	## Ship-local coordinates of a world point (handy for QA / prompts).
	return _local_from_world(point_world)


## ------------------------------------------------------------------ collision

func _build_collision(build: Dictionary) -> int:
	var count := 0
	var entries: Variant = build.get("collision", null)
	if not entries is Array or (entries as Array).is_empty():
		_punch_fallback_hull()
		return 4
	for entry: Variant in (entries as Array):
		if not entry is Dictionary:
			continue
		var dict := entry as Dictionary
		var position := _vector_or(dict.get("position", null), Vector3.ZERO)
		var size := _vector_or(dict.get("size", null), Vector3.ONE)
		if size.x == 0.0 and size.y == 0.0 and size.z == 0.0:
			continue
		var rotation_y := _num(dict.get("rotation_y", null), 0.0)
		_add_box("Hull_%d" % count, position, size, rotation_y)
		count += 1
	if count == 0:
		_punch_fallback_hull()
		return 4
	return count


func _punch_fallback_hull() -> void:
	## Only used when the model has not delivered collision data yet: a deck you can
	## stand on and a hull you cannot walk through.
	_add_box("Hull_Deck", Vector3(0.0, 1.55, 0.0), Vector3(8.6, 0.4, 25.6), 0.0)
	_add_box("Hull_Body", Vector3(0.0, -1.2, 0.0), Vector3(8.6, 2.9, 24.6), 0.0)
	_add_box("Hull_Quarter", Vector3(0.0, 2.85, 9.2), Vector3(8.4, 0.3, 6.4), 0.0)
	_add_box("Hull_Upper", Vector3(0.0, 5.05, -1.2), Vector3(6.4, 0.3, 6.0), 0.0)


func _build_rails() -> int:
	## Invisible bulwark boxes so a player does not simply walk overboard. The stern
	## quarter (z > 6) stays open on both sides: that is where the pier gangway meets the
	## hull, and a rail there would block boarding. `set_railings_enabled(false)` removes
	## them entirely if the host builds its own barriers.
	var half_beam := _beam * 0.5
	var rail_y := _deck_y + 0.60
	var rail_center_z := -3.3
	var rail_size_z := 18.4
	_rail_shapes.clear()
	_rail_shapes.append(_add_box("RailPort", Vector3(-(half_beam - 0.10), rail_y, rail_center_z), Vector3(0.16, 1.2, rail_size_z), 0.0))
	_rail_shapes.append(_add_box("RailStarboard", Vector3(half_beam - 0.10, rail_y, rail_center_z), Vector3(0.16, 1.2, rail_size_z), 0.0))
	return _rail_shapes.size()


func set_railings_enabled(enabled: bool) -> void:
	for shape: CollisionShape3D in _rail_shapes:
		if is_instance_valid(shape):
			shape.disabled = not enabled


func _disable_hull_collision() -> void:
	if _collision_disabled:
		return
	_collision_disabled = true
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	print("SHIP61_BOAT_COLLISION_OFF pos=", _origin)


func _add_box(shape_name: String, position: Vector3, size: Vector3, rotation_y: float) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	node.name = shape_name
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(absf(size.x), 0.05), maxf(absf(size.y), 0.05), maxf(absf(size.z), 0.05))
	node.shape = box
	node.position = position
	node.rotation.y = rotation_y
	add_child(node)
	return node


## ------------------------------------------------------------------ mooring / state

func moor(world_position: Vector3, yaw: float) -> void:
	if not world_position.is_finite() or not is_finite(yaw):
		return
	_moor_position = world_position
	_moor_yaw = wrapf(yaw, -PI, PI)
	_yaw = _moor_yaw
	_yaw_rate = 0.0
	_rudder = 0.0
	_rudder_target = 0.0
	_speed = 0.0
	_pitch = 0.0
	_roll = 0.0
	_water_level = _basin_water_level()
	var y := _water_level if _basin != null else world_position.y
	_origin = Vector3(world_position.x, y, world_position.z)
	_sync_transform(true)
	_step_transform = _world_transform()


func set_sails(open: bool) -> void:
	if not _installed:
		_sails_open = open
		return
	_sails_open = open and not _mast_broken and not _sunk
	_apply_sails_visual()


## `moor()` takes radians; this convenience is for callers that keep degrees.
func moor_deg(world_position: Vector3, yaw_degrees: float) -> void:
	if not is_finite(yaw_degrees):
		return
	moor(world_position, deg_to_rad(yaw_degrees))


func toggle_sails() -> bool:
	set_sails(not _sails_open)
	return _sails_open


func sails_open() -> bool:
	return _sails_open


func _apply_sails_visual() -> void:
	if _model == null or not is_instance_valid(_model):
		return
	if _model.has_method("set_sail_amount"):
		_model.call("set_sail_amount", 1.0 if _sails_open else 0.0)
	if _model.has_method("set_lever"):
		_model.call("set_lever", _sails_open)


func steer(axis: float) -> void:
	if not is_finite(axis):
		return
	_rudder_target = clampf(axis, -1.0, 1.0)
	if _model != null and is_instance_valid(_model) and _model.has_method("set_wheel_angle"):
		_model.call("set_wheel_angle", _rudder_target * 1.2)


func speed() -> float:
	return _speed


func heading() -> float:
	return _yaw


func heading_deg() -> float:
	return rad_to_deg(_yaw)


func water_level() -> float:
	return _water_level


func mast_hp() -> float:
	return _mast_hp


func hole_count() -> int:
	return _holes.size()


func hull_integrity() -> float:
	return clampf(1.0 - _hull_damage / HULL_MAX_DAMAGE, 0.0, 1.0)


func flooding() -> float:
	return _flooding


func is_sunk() -> bool:
	return _sunk


func part_health(id: String) -> float:
	return _num(_part_hp.get(id, null), 0.0)


func _basin_water_level() -> float:
	if _basin != null and _basin.has_method("water_level"):
		var value: Variant = _basin.call("water_level")
		if value is float or value is int:
			var level := float(value)
			if is_finite(level):
				return level
	return DEFAULT_WATER_LEVEL


func _water_height(x: float, z: float) -> float:
	if _basin != null and _basin.has_method("water_height_at"):
		var value: Variant = _basin.call("water_height_at", x, z)
		if value is float or value is int:
			var height := float(value)
			if is_finite(height):
				return height
	return _water_level


func _navigable(x: float, z: float) -> bool:
	if _basin == null or not _basin.has_method("is_navigable"):
		return true
	var value: Variant = _basin.call("is_navigable", x, z, NAV_DRAFT)
	if value is bool:
		return bool(value)
	return true


## ------------------------------------------------------------------ anchors

func world_helm() -> Vector3:
	return _anchor_world("helm")


func world_sail_lever() -> Vector3:
	return _anchor_world("sail_lever")


func world_crate(kind: String) -> Vector3:
	var id := ""
	if kind == "ammo":
		id = "crate_ammo"
	elif kind == "boards":
		id = "crate_boards"
	if id.is_empty():
		return _origin
	return _anchor_world(id)


func world_deck(point_local: Vector3) -> Vector3:
	return _world_from_local(point_local)


func _anchor_world(id: String) -> Vector3:
	var local: Variant = _anchors.get(id, null)
	if local is Vector3:
		return _world_from_local(local as Vector3)
	return _origin


## ------------------------------------------------------------------ simulation step

func simulate_step(delta: float) -> void:
	if not _installed:
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	delta = minf(delta, 0.1)
	_step_transform = _world_transform()
	_time += delta
	_update_obstacles()
	_update_flooding(delta)
	_update_motion(delta)
	_update_buoyancy(delta)
	_update_debris(delta)
	_sync_transform()
	_carry_riders()


func _physics_process(delta: float) -> void:
	if not _autopilot:
		return
	simulate_step(delta)


func set_autopilot(enabled: bool) -> void:
	_autopilot = enabled


func set_carry_compensation(enabled: bool) -> void:
	_carry_compensation = enabled


## ------------------------------------------------------------------ movement

func _update_obstacles() -> void:
	_obstacle_blocked = false
	if not is_inside_tree():
		return
	var space := get_world_3d()
	if space == null:
		return
	var state := space.direct_space_state
	if state == null:
		return
	var xform := _world_transform()
	var exclude: Array[RID] = [get_rid()]
	for offset: float in [-3.2, 0.0, 3.2]:
		var from := xform * Vector3(offset, 2.2, -12.0)
		var to := xform * Vector3(offset, 2.2, -28.0)
		var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
		if not state.intersect_ray(query).is_empty():
			_obstacle_blocked = true
			return


func _water_ahead_ok() -> bool:
	if _basin == null:
		return true
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	for distance: float in AHEAD_SAMPLES:
		var point := _origin + forward * distance
		if not _navigable(point.x, point.z):
			return false
	return true


func _update_motion(delta: float) -> void:
	_water_blocked = not _water_ahead_ok()
	var blocked := _mast_broken or _sunk or _water_blocked or _obstacle_blocked
	var target_speed := MAX_SPEED if (_sails_open and not blocked) else 0.0
	var rate := ACCEL if target_speed > _speed else BRAKE
	if _mast_broken or _sunk:
		rate = maxf(rate, MAST_BRAKE)
	_speed = move_toward(_speed, target_speed, rate * delta)
	if _speed < 0.0:
		_speed = 0.0
	_rudder = move_toward(_rudder, _rudder_target, RUDDER_RATE * delta)
	var speed_factor := clampf(_speed / MAX_SPEED, 0.0, 1.0)
	var target_yaw_rate := -_rudder * MAX_TURN_RAD * speed_factor
	_yaw_rate = move_toward(_yaw_rate, target_yaw_rate, YAW_ACCEL * delta)
	if _speed < 0.05:
		# A ship that is not moving through the water does not answer the helm.
		_yaw_rate = 0.0
	_yaw = wrapf(_yaw + _yaw_rate * delta, -PI, PI)
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	_origin += forward * _speed * delta


## ------------------------------------------------------------------ buoyancy

func _update_buoyancy(delta: float) -> void:
	var xform := _world_transform()
	var heights: Array[float] = []
	var sum := 0.0
	for offset: Vector2 in SAMPLE_OFFSETS:
		var point := xform * Vector3(offset.x, 0.0, offset.y)
		var height := _water_height(point.x, point.z)
		heights.append(height)
		sum += height
	var mean := sum / float(heights.size())
	var bow := heights[0]
	var stern := heights[1]
	var starboard := (heights[3] + heights[5]) * 0.5
	var port := (heights[2] + heights[4]) * 0.5
	var pitch_target := clampf(atan2(bow - stern, _length), -0.10, 0.10) * 0.9
	var roll_target := clampf(atan2(starboard - port, _beam), -0.10, 0.10) * 0.9
	# Ambient swell, tiny, so the deck is alive even in calm water.
	if not _sunk:
		pitch_target += sin(_time * 0.45 + 1.2) * 0.008
		roll_target += sin(_time * 0.60) * 0.012
	var centroid := _hole_centroid()
	if _flooding > 0.0 and not centroid.is_zero_approx():
		# List toward the flooded side; the water inside is heavier than the water outside.
		roll_target += -0.42 * _flooding * clampf(centroid.x / 3.0, -1.0, 1.0)
		pitch_target += 0.34 * _flooding * clampf(centroid.y / 9.0, -1.0, 1.0)
	var target_y := mean - _flooding * FLOOD_SINK_HEIGHT - _sink_extra()
	var blend := 1.0 - exp(-delta * 2.6)
	_pitch = lerpf(_pitch, clampf(pitch_target, -0.35, 0.35), 1.0 - exp(-delta * 1.8))
	_roll = lerpf(_roll, clampf(roll_target, -0.40, 0.40), 1.0 - exp(-delta * 1.8))
	_origin.y = lerpf(_origin.y, target_y, blend)


func _sink_extra() -> float:
	if not _sunk:
		return 0.0
	return minf(1.0, _sink_t / SINK_SECONDS) * SINK_DEPTH


func _hole_centroid() -> Vector2:
	if _holes.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	var weight := 0.0
	for hole: Dictionary in _holes:
		var local: Vector3 = hole.get("local", Vector3.ZERO)
		var severity := _num(hole.get("severity", null), 1.0)
		sum += Vector2(local.x, local.z) * severity
		weight += severity
	if weight <= 0.0:
		return Vector2.ZERO
	return sum / weight


## ------------------------------------------------------------------ flooding

func _update_flooding(delta: float) -> void:
	_flood_rate = _hole_severity_sum() * HOLE_FLOOD_RATE
	if _sunk:
		_sink_t += delta
		if _sink_t >= SINK_SECONDS * 0.6:
			# Well under the surface now: the deck stops being a floor, so a player left
			# on it drops into the water (the integrator fishes him out).
			_disable_hull_collision()
		return
	if _flood_rate > 0.0:
		_flooding = minf(1.0, _flooding + _flood_rate * delta)
	if _flooding >= 1.0:
		_sunk = true
		_sink_t = 0.0
		_speed = minf(_speed, 1.0)
		_apply_sails_visual()
		print("SHIP61_BOAT_SUNK pos=", _origin, " holes=", _holes.size(),
			" flooding=", _flooding)


func _hole_severity_sum() -> float:
	var total := 0.0
	for hole: Dictionary in _holes:
		total += _num(hole.get("severity", null), 1.0)
	return total


## ------------------------------------------------------------------ damage

func apply_hit(world_point: Vector3, damage: float, impulse: Vector3, kind: String) -> Dictionary:
	var result := {
		"ok": false,
		"zone": "",
		"damage": 0.0,
		"hole": false,
		"flooding": _flooding,
		"integrity": hull_integrity(),
		"hole_world": Vector3.ZERO,
		"sunk": _sunk,
	}
	if not _installed:
		result["reason"] = "not_installed"
		return result
	if not world_point.is_finite():
		result["reason"] = "bad_point"
		return result
	var hit_damage := damage
	if not is_finite(hit_damage) or hit_damage < 0.0:
		hit_damage = 0.0
	hit_damage = minf(hit_damage, 500.0)
	var local := _local_from_world(world_point)
	var zone := _classify_zone(local)
	var part_id := ""
	var hole := false
	var hole_world := Vector3.ZERO
	if zone == "hull":
		var radius := clampf(0.45 + hit_damage * 0.0065, 0.45, 1.2)
		hole_world = _add_hole(local, radius)
		hole = true
		_hull_damage += hit_damage
	elif zone == "mast":
		part_id = "mast"
		_mast_hp = maxf(0.0, _mast_hp - hit_damage)
		_part_hp["mast"] = _mast_hp
		if _mast_hp <= 0.0 and not _mast_broken:
			_break_mast(local)
	else:
		part_id = zone
		var hp := _num(_part_hp.get(part_id, null), DEFAULT_PART_HP) - hit_damage
		_part_hp[part_id] = maxf(0.0, hp)
		if hp <= 0.0 and not _broken_parts.has(part_id):
			_break_part(part_id, local)
	_after_hit_fx(world_point, zone, local, impulse)
	result["ok"] = true
	result["zone"] = zone
	result["damage"] = hit_damage
	result["hole"] = hole
	result["flooding"] = _flooding
	result["integrity"] = hull_integrity()
	result["hole_world"] = hole_world
	result["sunk"] = _sunk
	result["part"] = part_id
	result["part_hp"] = _num(_part_hp.get(part_id, null), -1.0) if not part_id.is_empty() else -1.0
	return result


func _classify_zone(local: Vector3) -> String:
	var mast_base: Vector3 = _anchors.get("mast_base", Vector3(0.0, 1.75, -1.0))
	var mast_top: Vector3 = _anchors.get("mast_top", Vector3(0.0, 17.7, -1.0))
	if not _mast_broken and local.y >= mast_base.y - 0.4 and local.y <= mast_top.y + 1.0:
		if Vector2(local.x - mast_base.x, local.z - mast_base.z).length() <= 1.25:
			return "mast"
	var helm: Vector3 = _anchors.get("helm", Vector3(0.0, 3.05, 10.4))
	if local.distance_to(helm) <= 1.35:
		return "helm"
	var ammo: Vector3 = _anchors.get("crate_ammo", Vector3(-2.0, 0.95, 10.2))
	if local.distance_to(ammo) <= 1.45:
		return "crate_ammo"
	var boards: Vector3 = _anchors.get("crate_boards", Vector3(2.0, 0.95, 10.2))
	if local.distance_to(boards) <= 1.45:
		return "crate_boards"
	for index in _cannon_mounts.size():
		if local.distance_to(_cannon_mounts[index]) <= 1.9:
			return "cannon_%d" % index
	if local.z < -13.2 and local.y > 0.6:
		return "bowsprit"
	if local.z > 11.6 and local.y < 6.0:
		return "transom"
	var upper: Vector3 = _anchors.get("upper_deck", Vector3(0.0, 5.2, -1.2))
	if local.y > upper.y - 0.7 and absf(local.z - upper.z) < 5.6:
		return "upper_deck"
	if local.y > 1.95 and (absf(local.x) > 3.15 or local.z > 6.0):
		return "rail"
	if local.y < 2.0:
		return "hull"
	return "upper_deck"


func _add_hole(local: Vector3, radius: float) -> Vector3:
	if _holes.size() >= MAX_HOLES:
		# The pool is full: the oldest hole is widened instead of growing forever.
		var oldest: Dictionary = _holes.pop_front()
		var old_radius := _num(oldest.get("radius", null), radius)
		radius = maxf(radius, minf(1.35, old_radius + 0.15))
	var severity := clampf(radius / 0.8, 0.5, 2.0)
	_holes.append({"local": local, "radius": radius, "severity": severity})
	_flood_rate = _hole_severity_sum() * HOLE_FLOOD_RATE
	var world := _world_from_local(local)
	if _model != null and is_instance_valid(_model):
		if _model.has_method("punch_hole"):
			_model.call("punch_hole", local, radius)
		if _model.has_method("shake"):
			_model.call("shake", 0.4)
	if _basin != null and _basin.has_method("add_ripple"):
		_basin.call("add_ripple", world, 1.0)
	print("SHIP61_BOAT_HOLE local=", local, " world=", world, " radius=", radius,
		" holes=", _holes.size(), " flood_rate=", _flood_rate)
	return world


func _break_mast(local: Vector3) -> void:
	_mast_broken = true
	_mast_hp = 0.0
	_part_hp["mast"] = 0.0
	if not _broken_parts.has("mast"):
		_broken_parts.append("mast")
	if _model != null and is_instance_valid(_model):
		if _model.has_method("set_mast_broken"):
			_model.call("set_mast_broken", true)
		if _model.has_method("shake"):
			_model.call("shake", 1.0)
	var world := _world_from_local(local)
	_spawn_debris(world, 6)
	if _basin != null and _basin.has_method("add_ripple"):
		_basin.call("add_ripple", world, 1.5)
	print("SHIP61_BOAT_MAST_BROKEN pos=", _origin, " speed=", _speed)


func _break_part(id: String, local: Vector3) -> void:
	if id.is_empty() or _broken_parts.has(id):
		return
	_broken_parts.append(id)
	var world := _world_from_local(local)
	if _model != null and is_instance_valid(_model):
		if _model.has_method("break_part"):
			_model.call("break_part", id)
		if _model.has_method("shake"):
			_model.call("shake", 0.8)
	_spawn_debris(world, 4)
	if _basin != null and _basin.has_method("add_ripple"):
		_basin.call("add_ripple", world, 1.0)
	print("SHIP61_BOAT_PART_BROKEN id=", id, " at=", world)


func _after_hit_fx(world_point: Vector3, zone: String, _local: Vector3, impulse: Vector3) -> void:
	if _basin != null and _basin.has_method("add_ripple"):
		_basin.call("add_ripple", world_point, 0.6)
	if _model != null and is_instance_valid(_model) and _model.has_method("shake"):
		_model.call("shake", 0.25)
	if zone != "hull" and not _sunk:
		_spawn_debris(world_point, 2)


## ------------------------------------------------------------------ repair

func nearest_hole_world(from_world: Vector3, reach: float = 3.0) -> Vector3:
	if _holes.is_empty() or not from_world.is_finite():
		return Vector3.ZERO
	var best := Vector3.ZERO
	var best_distance := maxf(reach, 0.01)
	for hole: Dictionary in _holes:
		var local: Vector3 = hole.get("local", Vector3.ZERO)
		var world := _world_from_local(local)
		var distance := world.distance_to(from_world)
		if distance <= best_distance:
			best_distance = distance
			best = world
	return best


func repair_at(world_point: Vector3) -> bool:
	if _holes.is_empty() or not world_point.is_finite():
		return false
	var index := -1
	var best := REPAIR_REACH
	for i in _holes.size():
		var local: Vector3 = _holes[i].get("local", Vector3.ZERO)
		var distance := _world_from_local(local).distance_to(world_point)
		if distance <= best:
			best = distance
			index = i
	if index < 0:
		return false
	var hole: Dictionary = _holes[index]
	_holes.remove_at(index)
	_hull_damage = maxf(0.0, _hull_damage - 25.0)
	_flooding = maxf(0.0, _flooding - FLOOD_REPAIR_RELIEF)
	_flood_rate = _hole_severity_sum() * HOLE_FLOOD_RATE
	if _model != null and is_instance_valid(_model) and _model.has_method("repair_hole"):
		_model.call("repair_hole", hole.get("local", Vector3.ZERO), _num(hole.get("radius", null), 0.6))
	print("SHIP61_BOAT_REPAIR at=", world_point, " holes=", _holes.size(),
		" flooding=", _flooding, " flood_rate=", _flood_rate)
	return true


## ------------------------------------------------------------------ ladder

func set_climb_input(axis: float) -> void:
	if is_nan(axis):
		_climb_input_bound = false
		return
	_climb_input_bound = true
	_climb_input = clampf(axis, -1.0, 1.0)


func _climb_axis() -> float:
	if _climb_input_bound:
		return _climb_input
	var axis := 0.0
	if InputMap.has_action(&"preview_move_forward") and Input.is_action_pressed(&"preview_move_forward"):
		axis += 1.0
	if InputMap.has_action(&"preview_move_back") and Input.is_action_pressed(&"preview_move_back"):
		axis -= 1.0
	return clampf(axis, -1.0, 1.0)


func climb_assist(player: CharacterBody3D, delta: float) -> void:
	if not _installed or player == null or not is_instance_valid(player):
		return
	if not is_finite(delta) or delta <= 0.0 or delta > 0.25:
		return
	var local := _local_from_world(player.global_position)
	if not _in_ladder_zone(local):
		return
	var axis := _climb_axis()
	if is_zero_approx(axis):
		return
	var base: Vector3 = _anchors.get("ladder_base", Vector3(0.0, 1.75, 2.3))
	var top: Vector3 = _anchors.get("ladder_top", Vector3(0.0, 5.2, 2.0))
	var next_y := clampf(local.y + CLIMB_SPEED * axis * delta, base.y, top.y)
	var span := maxf(0.01, top.y - base.y)
	var t := clampf((next_y - base.y) / span, 0.0, 1.0)
	var z_target := lerpf(base.z, top.z, t)
	var grab := minf(1.0, delta * 6.0)
	var next_local := Vector3(lerpf(local.x, 0.0, grab), next_y, lerpf(local.z, z_target, grab))
	if axis > 0.0 and next_y >= top.y - 0.001:
		# Step off the ladder onto the fighting top; the next frame is normal walking.
		next_local.z = minf(next_local.z, 1.40)
	if axis < 0.0 and next_y <= base.y + 0.001:
		next_local.z = maxf(next_local.z, base.z + 0.20)
	player.global_position = _world_from_local(next_local)
	player.velocity = Vector3(0.0, CLIMB_SPEED * axis, 0.0)


func _in_ladder_zone(local: Vector3) -> bool:
	if absf(local.x) > 1.15:
		return false
	if local.z < 1.55 or local.z > 3.85:
		return false
	return local.y >= 1.45 and local.y <= 5.75


## ------------------------------------------------------------------ platform carry

func _carry_riders() -> void:
	if not _carry_compensation:
		return
	if _player == null or not is_instance_valid(_player):
		return
	var now := _world_transform()
	var motion := now * _step_transform.affine_inverse()
	if motion.is_equal_approx(Transform3D.IDENTITY):
		return
	var local := _local_from_world(_player.global_position)
	if _on_deck_local(local):
		_player.global_position = motion * _player.global_position


func _on_deck_local(local: Vector3) -> bool:
	if local.y < _deck_y - 0.5 or local.y > _deck_y + 4.2:
		return false
	return absf(local.x) <= _beam * 0.5 + 0.35 and absf(local.z) <= _length * 0.5 + 0.60


## ------------------------------------------------------------------ debris

func _debris_root() -> Node3D:
	if _debris_container != null and is_instance_valid(_debris_container):
		return _debris_container
	return self


func _spawn_debris(world_position: Vector3, count: int) -> void:
	var root := _debris_root()
	var amount := clampi(count, 1, 8)
	for _i in amount:
		if _debris_nodes.size() >= MAX_DEBRIS:
			var old: Node3D = _debris_nodes.pop_front()
			_debris_life.pop_front()
			if is_instance_valid(old):
				old.queue_free()
		var body := RigidBody3D.new()
		body.name = "ShipWreck_%d" % _rng.randi_range(0, 99999)
		body.mass = 8.0
		body.collision_layer = 4
		body.collision_mask = 1
		var size := Vector3(_rng.randf_range(0.25, 0.9), _rng.randf_range(0.12, 0.30), _rng.randf_range(0.40, 1.10))
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.30, 0.21, 0.13)
		material.roughness = 0.92
		mesh.material_override = material
		body.add_child(mesh)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
		body.global_position = world_position + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.1, 0.9), _rng.randf_range(-0.6, 0.6))
		body.linear_velocity = Vector3(_rng.randf_range(-2.2, 2.2), _rng.randf_range(1.0, 4.0), _rng.randf_range(-2.2, 2.2))
		body.angular_velocity = Vector3(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0))
		_debris_nodes.append(body)
		_debris_life.append(DEBRIS_LIFE)


func _update_debris(delta: float) -> void:
	var index := _debris_nodes.size() - 1
	while index >= 0:
		_debris_life[index] -= delta
		var node := _debris_nodes[index]
		var remove := _debris_life[index] <= 0.0 or not is_instance_valid(node)
		if not remove and node.global_position.y < -25.0:
			remove = true
		if remove:
			if is_instance_valid(node):
				node.queue_free()
			_debris_nodes.remove_at(index)
			_debris_life.remove_at(index)
		index -= 1


func debris_count() -> int:
	return _debris_nodes.size()


## ------------------------------------------------------------------ snapshot

func snapshot() -> Dictionary:
	var hole_worlds: Array[Vector3] = []
	for hole: Dictionary in _holes:
		hole_worlds.append(_world_from_local(hole.get("local", Vector3.ZERO)))
	return {
		"ok": _installed,
		"speed": _speed,
		"speed_mps": _speed,
		"heading": _yaw,
		"heading_deg": rad_to_deg(_yaw),
		"sails_open": _sails_open,
		"flooding": _flooding,
		"flood_rate": _flood_rate,
		"integrity": hull_integrity(),
		"hull_damage": _hull_damage,
		"holes": _holes.size(),
		"hole_worlds": hole_worlds,
		"mast_hp": _mast_hp,
		"mast_broken": _mast_broken,
		"sunk": _sunk,
		"sink_t": _sink_t,
		"position": _origin,
		"rudder": _rudder,
		"rudder_target": _rudder_target,
		"yaw_rate": _yaw_rate,
		"blocked_water": _water_blocked,
		"blocked_obstacle": _obstacle_blocked,
		"debris": _debris_nodes.size(),
		"broken_parts": _broken_parts.duplicate(),
		"water_level": _water_level,
		"pitch": _pitch,
		"roll": _roll,
		"collision_disabled": _collision_disabled,
		"moor_position": _moor_position,
		"moor_yaw": _moor_yaw,
		"installed": _installed,
	}


## ------------------------------------------------------------------ helpers

func _num(value: Variant, fallback: float) -> float:
	if value is float:
		var as_float := float(value)
		return as_float if is_finite(as_float) else fallback
	if value is int:
		return float(value)
	return fallback


func _vector_or(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		var as_vector := value as Vector3
		if as_vector.is_finite():
			return as_vector
	return fallback
