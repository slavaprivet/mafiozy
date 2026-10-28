class_name NativeVehicleCrashSolver
extends RefCounted
## Proposal-only port of createCrashMechanicsState/applyCrashMechanicsImpact.
## Internal mechanics stay in source local axes (+X left, +Z forward). Public
## contact/sample vectors are Godot local (-X left, -Z forward). The caller is
## a trusted adapter which must load the pinned manifest, verify its FileAccess
## SHA, and pass the exact source_metadata.vehicleProfile row. This class shape-
## validates that row; the caller-supplied hash is a receipt, not file proof.
## This class
## applies no authoritative HP, body motion, visual mutation or debris flight.

const VISUAL_MANIFEST_SHA256 := "38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03"
const NODE_COUNT := 45
const BEAM_COUNT := 232
const GRID_X_COUNT := 3
const GRID_Y_COUNT := 3
const GRID_Z_COUNT := 5
const PART_IDS := [
	"hood", "trunk", "door_front_left", "door_front_right",
	"door_rear_left", "door_rear_right", "bumper_front", "bumper_rear",
	"wheel_front_left", "wheel_front_right", "wheel_rear_left", "wheel_rear_right",
]
const WHEEL_IDS := ["front_left", "front_right", "rear_left", "rear_right"]
const LOGICAL_REAR_FALLBACK_PROFILE_IDS := [
	"sport_coupe", "delivery_van", "utility_pickup", "city_bus",
	"city_ambulance", "fire_engine",
]
const SOURCE_NEIGHBORS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1),
	Vector3i(1, 1, 0), Vector3i(-1, 1, 0), Vector3i(1, 0, 1),
	Vector3i(-1, 0, 1), Vector3i(0, 1, 1), Vector3i(0, -1, 1),
]

var _configured := false
var _vehicle_id := ""
var _life_generation := 0
var _profile_id := ""
var _last_impact_physics_tick := -1
var _last_impact_sequence := -1
var _last_step_physics_tick := -1
var _profile := {}
var _grid_x := PackedFloat64Array()
var _grid_y := PackedFloat64Array()
var _grid_z := PackedFloat64Array()
var _rest := PackedVector3Array()
var _plastic := PackedVector3Array()
var _position := PackedVector3Array()
var _velocity := PackedVector3Array()
var _beam_a := PackedInt32Array()
var _beam_b := PackedInt32Array()
var _beam_original_length := PackedFloat64Array()
var _beam_rest_length := PackedFloat64Array()
var _beam_broken := PackedByteArray()
var _beam_plastic_strain := PackedFloat64Array()
var _force_scratch := PackedFloat64Array()
var _parts := {}
var _wheels := {}
var _engine := 1.0
var _radiator := 1.0
var _steering := 1.0
var _brakes := 1.0
var _temperature := 0.0
var _detached_parts: Array[String] = []
var _recent_events: Array = []
var _impacts := 0
var _total_energy_j := 0.0
var _absorbed_energy_j := 0.0
var _revision := 0
var _active := false
var _accumulator := 0.0
var _simulation_time := 0.0
var _max_crush_m := 0.0

func configure(vehicle_id_value: Variant, life_generation_value: Variant,
		profile_id_value: Variant, manifest_sha256_value: Variant,
		crash_profile_value: Variant) -> bool:
	if _configured or not vehicle_id_value is String \
			or (vehicle_id_value as String).is_empty() \
			or not life_generation_value is int or int(life_generation_value) < 1 \
			or not profile_id_value is String or (profile_id_value as String).is_empty() \
			or manifest_sha256_value != VISUAL_MANIFEST_SHA256 \
			or not crash_profile_value is Dictionary:
		return false
	var profile: Dictionary = crash_profile_value
	if profile.get("id") != profile_id_value or not _valid_profile(profile):
		return false
	_vehicle_id = vehicle_id_value
	_life_generation = int(life_generation_value)
	_profile_id = profile_id_value
	_profile = profile.duplicate(true)
	_allocate_fixed_storage()
	_build_state()
	_configured = true
	return true

func apply_impact_native(contact_value: Variant) -> Dictionary:
	var rejected := {"applied": false, "energy_j": 0.0,
		"detach_part_ids_proposal": [], "deformed_nodes": 0}
	if not _configured or not contact_value is Dictionary:
		return rejected
	var contact: Dictionary = contact_value
	if contact.get("vehicle_id") != _vehicle_id \
			or contact.get("life_generation") != _life_generation \
			or not contact.get("physics_tick") is int \
			or int(contact.physics_tick) < 0 \
			or int(contact.physics_tick) < _last_impact_physics_tick \
			or not contact.get("impact_sequence") is int \
			or int(contact.impact_sequence) < 0 \
			or int(contact.impact_sequence) <= _last_impact_sequence \
			or not contact.get("point_native_m") is Vector3 \
			or not contact.get("normal_native") is Vector3 \
			or not _finite_number(contact.get("impact_speed_mps")):
		return rejected
	var event_id: Variant = contact.get("event_id")
	if event_id != null and (not event_id is String or (event_id as String).is_empty() \
			or (event_id as String).length() > 256):
		return rejected
	var point_native: Vector3 = contact.point_native_m
	var normal_native: Vector3 = contact.normal_native
	if not point_native.is_finite() or not normal_native.is_finite():
		return rejected
	var point: Vector3 = native_local_to_source(point_native)
	var normal: Vector3 = native_local_to_source(normal_native)
	var normal_length := normal.length()
	var speed := clampf(float(contact.impact_speed_mps), 0.0, 90.0)
	if normal_length < 0.00000001 or speed < 2.5:
		return rejected
	if event_id != null and _recent_events.has(event_id):
		return rejected
	var half_width := float(_profile.halfWidth)
	var half_length := float(_profile.halfLength)
	var height := float(_profile.height)
	if absf(point.x) > half_width + 1.5 or absf(point.z) > half_length + 1.5 \
			or point.y < -1.5 or point.y > height + 1.5:
		return rejected
	_last_impact_physics_tick = int(contact.physics_tick)
	_last_impact_sequence = int(contact.impact_sequence)
	var n := normal / normal_length
	var energy_j := 0.5 * float(_profile.massKg) * speed * speed
	var fast := clampf((speed - 6.0) / 12.0, 0.0, 1.0)
	var yield_blend := fast * fast * (3.0 - 2.0 * fast)
	var severity := maxf(0.0, speed * speed - 2.5 * 2.5) / 190.0 * (1.0 + 0.32 * yield_blend)
	var radius := clampf(0.52 + speed * 0.041, 0.58, 2.05)
	var limits := _crush_limits(half_width, half_length, height)
	var direction_limit := 1.0 / sqrt(
		(n.x / limits.x) * (n.x / limits.x)
		+ (n.y / limits.y) * (n.y / limits.y)
		+ (n.z / limits.z) * (n.z / limits.z))
	var depth := clampf(pow(speed - 2.5, 1.35) * 0.016 * (1.0 + 0.85 * yield_blend),
		0.0, direction_limit)
	var deformed_nodes := 0
	for index in NODE_COUNT:
		var rest := _rest[index]
		var dx := rest.x - point.x
		var dy := (rest.y - point.y) * 0.74
		var dz := rest.z - point.z
		var d2 := (dx * dx + dy * dy + dz * dz) / (radius * radius)
		var weight := exp(-d2 * 1.7) if d2 < 5.0 else 0.0
		if weight < 0.006:
			continue
		var buckle := depth * weight * 0.20
		var displacement := Vector3(
			-n.x * depth * weight + (signf(rest.x) * buckle * 0.5 if absf(n.z) > 0.55 else 0.0),
			-n.y * depth * weight + (buckle if rest.y > height * 0.4 else 0.0),
			-n.z * depth * weight)
		_plastic[index] += displacement
		var shift := _plastic[index] - rest
		var envelope := sqrt((shift.x / limits.x) * (shift.x / limits.x)
			+ (shift.y / limits.y) * (shift.y / limits.y)
			+ (shift.z / limits.z) * (shift.z / limits.z))
		if envelope > 1.0:
			_plastic[index] = rest + shift / envelope
		_position[index] += (_plastic[index] - _position[index]) * 0.88
		_velocity[index] = Vector3(
			clampf(_velocity[index].x - n.x * speed * weight * 0.045, -1.4, 1.4),
			clampf(_velocity[index].y - n.y * speed * weight * 0.045, -1.4, 1.4),
			clampf(_velocity[index].z - n.z * speed * weight * 0.045, -1.4, 1.4))
		deformed_nodes += 1
	for beam_index in BEAM_COUNT:
		var plastic_length := _plastic[_beam_a[beam_index]].distance_to(_plastic[_beam_b[beam_index]])
		var strain := absf(plastic_length - _beam_original_length[beam_index]) \
			/ _beam_original_length[beam_index]
		_beam_plastic_strain[beam_index] = maxf(_beam_plastic_strain[beam_index], strain)
		if strain > 0.018:
			_beam_rest_length[beam_index] = clampf(plastic_length,
				_beam_original_length[beam_index] * 0.20,
				_beam_original_length[beam_index] * 1.8)
		if strain > 0.64:
			_beam_broken[beam_index] = 1
	var detached: Array[String] = []
	for part_id: String in _parts:
		var part: Dictionary = _parts[part_id]
		if part.detached:
			continue
		var part_point: Vector3 = part.point
		var far_side := 0.035 if absf(point.x) > 0.35 and absf(part_point.x) > 0.35 \
			and point.x * part_point.x < 0.0 else 1.0
		var near := _locality(point, part_point, float(part.radius), 0.65) * far_side
		part.health = _health_loss(float(part.health), severity * near / float(part.strength))
		if part.health <= 0.025:
			part.detached = true
			_detached_parts.append(part_id)
			detached.append(part_id)
		_parts[part_id] = part
	var component_points: Dictionary = _profile.componentPoints
	var engine_point := _dict_vector(component_points.engine)
	var radiator_point := _dict_vector(component_points.radiator)
	var component_scale := clampf(half_width, 0.75, 1.6)
	if point.z * signf(engine_point.z if engine_point.z != 0.0 else 1.0) > half_length * 0.22:
		_engine = _health_loss(_engine, severity * _locality(point, engine_point,
			1.38 * component_scale, 0.5) * 0.50)
	if point.z * signf(radiator_point.z if radiator_point.z != 0.0 else 1.0) > half_length * 0.22:
		_radiator = _health_loss(_radiator, severity * _locality(point, radiator_point,
			1.20 * component_scale, 0.5) * 0.75)
	for wheel_id: String in WHEEL_IDS:
		var wheel: Dictionary = _wheels[wheel_id]
		var wheel_part: Dictionary = _parts["wheel_" + wheel_id]
		var side := 1.0 if wheel_id.ends_with("left") else -1.0
		var far_side := 0.025 if absf(point.x) > 0.35 and point.x * side < 0.0 else 1.0
		var near := _locality(point, wheel_part.point, 1.02 * component_scale, 0.6) * far_side
		var loss := severity * near * 0.70
		wheel.health = _health_loss(float(wheel.health), loss)
		wheel.detached = wheel_part.detached
		wheel.toe = clampf(float(wheel.toe) + loss * (n.x * 0.38 + side * absf(n.z) * 0.13), -0.48, 0.48)
		wheel.camber = clampf(float(wheel.camber) - side * loss * 0.24, -0.48, 0.48)
		wheel.sag = clampf(float(wheel.sag) + loss * 0.11, 0.0, 0.25)
		if wheel_id.begins_with("front"):
			_steering = _health_loss(_steering, loss * 0.24)
		_brakes = _health_loss(_brakes, loss * 0.075)
		_wheels[wheel_id] = wheel
	_impacts += 1
	_total_energy_j += energy_j
	_absorbed_energy_j += energy_j * clampf(0.22 + depth * 0.68, 0.22, 0.83)
	_active = deformed_nodes > 0
	_revision += 1
	_max_crush_m = 0.0
	for index in NODE_COUNT:
		_max_crush_m = maxf(_max_crush_m, _rest[index].distance_to(_plastic[index]))
	if event_id != null:
		_recent_events.append(event_id)
		if _recent_events.size() > 128:
			_recent_events.pop_front()
	return {"applied": true, "energy_j": energy_j,
		"detach_part_ids_proposal": detached, "deformed_nodes": deformed_nodes,
		"revision": _revision}

func step(delta_value: Variant, speed_value: Variant, throttle_value: Variant,
		physics_tick_value: Variant) -> Dictionary:
	var rejected := {"accepted": false, "changed": false, "substeps": 0,
		"revision": _revision, "active": _active}
	if not _configured or not _finite_number(delta_value) or float(delta_value) < 0.0 \
			or not _finite_number(speed_value) or not _finite_number(throttle_value) \
			or not physics_tick_value is int \
			or int(physics_tick_value) <= _last_step_physics_tick:
		return rejected
	_last_step_physics_tick = int(physics_tick_value)
	var delta := float(delta_value)
	if delta == 0.0:
		return {"accepted": true, "changed": false, "substeps": 0,
			"revision": _revision, "active": _active}
	var elapsed := minf(delta, 0.1)
	var changed := false
	var steps := 0
	if _active:
		_accumulator = minf(0.1, _accumulator + elapsed)
		var moving := false
		while _accumulator >= 1.0 / 240.0 - 0.0000000001 and steps < 24:
			moving = _fixed_step(1.0 / 240.0)
			_accumulator = maxf(0.0, _accumulator - 1.0 / 240.0)
			steps += 1
		if steps > 0:
			_active = moving
			_revision += 1
			changed = true
			if not moving:
				_velocity.fill(Vector3.ZERO)
	if _radiator < 0.8 and _engine > 0.015:
		var load := clampf(absf(float(throttle_value)), 0.0, 1.0)
		var road_speed := absf(float(speed_value))
		_temperature = clampf(_temperature + elapsed * (
			(1.0 - _radiator) * (0.008 + load * 0.055)
			- (0.004 + road_speed * 0.0007) * _radiator), 0.0, 1.0)
		if _temperature > 0.85:
			_engine = _health_loss(_engine, elapsed * (_temperature - 0.85) * 0.018)
	elif _temperature > 0.0:
		_temperature = maxf(0.0, _temperature - elapsed * 0.025)
	return {"accepted": true, "changed": changed, "substeps": steps,
		"revision": _revision, "active": _active}

func sample_deformation_native(native_point_value: Variant) -> Variant:
	if not _configured or not native_point_value is Vector3 \
			or not (native_point_value as Vector3).is_finite():
		return null
	var point := native_local_to_source(native_point_value as Vector3)
	var xv := _interval_value(_grid_x, point.x)
	var yv := _interval_value(_grid_y, point.y)
	var zv := _interval_value(_grid_z, point.z)
	var xi := mini(GRID_X_COUNT - 2, int(floor(xv)))
	var yi := mini(GRID_Y_COUNT - 2, int(floor(yv)))
	var zi := mini(GRID_Z_COUNT - 2, int(floor(zv)))
	var xt := xv - xi
	var yt := yv - yi
	var zt := zv - zi
	var result_source := Vector3.ZERO
	for z in 2:
		for y in 2:
			for x in 2:
				var weight := (xt if x else 1.0 - xt) * (yt if y else 1.0 - yt) \
					* (zt if z else 1.0 - zt)
				var index := _node_index(xi + x, yi + y, zi + z)
				result_source += (_position[index] - _rest[index]) * weight
	return source_local_to_native(result_source)

func deformation_snapshot_native() -> Dictionary:
	if not _configured:
		return {}
	var positions_native := PackedVector3Array()
	var rest_native := PackedVector3Array()
	positions_native.resize(NODE_COUNT)
	rest_native.resize(NODE_COUNT)
	for index in NODE_COUNT:
		positions_native[index] = source_local_to_native(_position[index])
		rest_native[index] = source_local_to_native(_rest[index])
	return {"vehicle_id": _vehicle_id, "life_generation": _life_generation,
		"profile_id": _profile_id, "revision": _revision,
		"positions_native": positions_native.duplicate(),
		"rest_native": rest_native.duplicate()}

func mechanical_snapshot() -> Dictionary:
	if not _configured:
		return {}
	# revision/changed track structural integration exactly like the source. Heat
	# and engine health may change without either, so drive consumers read this
	# lightweight snapshot independently instead of deep structural state.
	return {"vehicle_id": _vehicle_id, "life_generation": _life_generation,
		"profile_id": _profile_id, "revision": _revision, "engine": _engine,
		"radiator": _radiator, "steering": _steering, "brakes": _brakes,
		"temperature": _temperature, "wheels": _wheels.duplicate(true)}

func snapshot_source() -> Dictionary:
	if not _configured:
		return {}
	var nodes: Array = []
	for index in NODE_COUNT:
		nodes.append({"rest": _vector_dict(_rest[index]), "plastic": _vector_dict(_plastic[index]),
			"position": _vector_dict(_position[index]), "velocity": _vector_dict(_velocity[index])})
	var beams: Array = []
	for index in BEAM_COUNT:
		beams.append({"a": _beam_a[index], "b": _beam_b[index],
			"originalLength": _beam_original_length[index], "restLength": _beam_rest_length[index],
			"broken": _beam_broken[index] != 0, "plasticStrain": _beam_plastic_strain[index]})
	var parts := {}
	for part_id: String in _parts:
		var part: Dictionary = _parts[part_id]
		parts[part_id] = {"id": part.id, "point": _vector_dict(part.point),
			"radius": part.radius, "strength": part.strength,
			"health": part.health, "detached": part.detached}
	return {"profile_id": _profile_id, "nodes": nodes, "beams": beams,
		"parts": parts, "wheels": _wheels.duplicate(true), "engine": _engine,
		"radiator": _radiator, "steering": _steering, "brakes": _brakes,
		"temperature": _temperature, "detachedParts": _detached_parts.duplicate(),
		"recentEvents": _recent_events.duplicate(true), "impacts": _impacts,
		"totalEnergyJ": _total_energy_j, "absorbedEnergyJ": _absorbed_energy_j,
		"revision": _revision, "active": _active, "accumulator": _accumulator,
		"simulationTime": _simulation_time, "maxCrush": _max_crush_m,
		"lastImpactSequence": _last_impact_sequence,
		"lastImpactPhysicsTick": _last_impact_physics_tick,
		"lastStepPhysicsTick": _last_step_physics_tick}

func runtime_contract() -> Dictionary:
	return {"configured": _configured, "nodes": _rest.size(), "beams": _beam_a.size(),
		"force_scratch_scalars": _force_scratch.size(), "force_scratch_bytes": _force_scratch.size() * 8,
		"last_impact_sequence": _last_impact_sequence,
		"last_impact_physics_tick": _last_impact_physics_tick,
		"last_step_physics_tick": _last_step_physics_tick}

func _allocate_fixed_storage() -> void:
	_grid_x.resize(GRID_X_COUNT)
	_grid_y.resize(GRID_Y_COUNT)
	_grid_z.resize(GRID_Z_COUNT)
	_rest.resize(NODE_COUNT)
	_plastic.resize(NODE_COUNT)
	_position.resize(NODE_COUNT)
	_velocity.resize(NODE_COUNT)
	_beam_a.resize(BEAM_COUNT)
	_beam_b.resize(BEAM_COUNT)
	_beam_original_length.resize(BEAM_COUNT)
	_beam_rest_length.resize(BEAM_COUNT)
	_beam_broken.resize(BEAM_COUNT)
	_beam_plastic_strain.resize(BEAM_COUNT)
	_force_scratch.resize(NODE_COUNT * 3)

func _build_state() -> void:
	var half_width := float(_profile.halfWidth)
	var half_length := float(_profile.halfLength)
	var height := float(_profile.height)
	_grid_x = PackedFloat64Array([-half_width, 0.0, half_width])
	_grid_y = PackedFloat64Array([0.28, height * 0.46, height * 0.91])
	_grid_z = PackedFloat64Array([-half_length, -half_length * 0.5, 0.0,
		half_length * 0.5, half_length])
	for z in GRID_Z_COUNT:
		for y in GRID_Y_COUNT:
			for x in GRID_X_COUNT:
				var index := _node_index(x, y, z)
				var rest := Vector3(_grid_x[x], _grid_y[y], _grid_z[z])
				_rest[index] = rest
				_plastic[index] = rest
				_position[index] = rest
				_velocity[index] = Vector3.ZERO
	var beam_index := 0
	for z in GRID_Z_COUNT:
		for y in GRID_Y_COUNT:
			for x in GRID_X_COUNT:
				for neighbor in SOURCE_NEIGHBORS:
					var xx := x + neighbor.x
					var yy := y + neighbor.y
					var zz := z + neighbor.z
					if xx < 0 or xx >= GRID_X_COUNT or yy < 0 or yy >= GRID_Y_COUNT \
							or zz < 0 or zz >= GRID_Z_COUNT:
						continue
					var a := _node_index(x, y, z)
					var b := _node_index(xx, yy, zz)
					var length := _rest[a].distance_to(_rest[b])
					_beam_a[beam_index] = a
					_beam_b[beam_index] = b
					_beam_original_length[beam_index] = length
					_beam_rest_length[beam_index] = length
					beam_index += 1
	assert(beam_index == BEAM_COUNT)
	_build_parts()
	for wheel_id: String in WHEEL_IDS:
		_wheels[wheel_id] = {"health": 1.0, "toe": 0.0, "camber": 0.0,
			"sag": 0.0, "detached": false}

func _build_parts() -> void:
	var half_width := float(_profile.halfWidth)
	var half_length := float(_profile.halfLength)
	var height := float(_profile.height)
	var ys := height / 2.14
	var spread := clampf(half_width, 0.75, 1.6)
	var points: Dictionary = _profile.partPoints
	_add_part("hood", _dict_vector(points.hood), 1.25 * spread, 1.22)
	_add_part("trunk", _dict_vector(points.trunk), 1.12 * spread, 1.15)
	_add_part("bumper_front", Vector3(0, 0.55 * ys, half_length), 1.25 * spread, 0.70)
	_add_part("bumper_rear", Vector3(0, 0.55 * ys, -half_length), 1.25 * spread, 0.70)
	for wheel_id: String in WHEEL_IDS:
		var side := 1.0 if wheel_id.ends_with("left") else -1.0
		var front := wheel_id.begins_with("front")
		var door_default := Vector3(side * half_width, 1.05 * ys,
			(0.20 if front else -0.98) * half_length / 2.15)
		var door_id := "door_" + wheel_id
		var door_point := _dict_vector(points[door_id]) if points.has(door_id) else door_default
		_add_part(door_id, door_point,
			0.98 * spread, 1.30)
		_add_part("wheel_" + wheel_id, _dict_vector(points["wheel_" + wheel_id]),
			0.94 * spread, 1.24)

func _add_part(part_id: String, point: Vector3, radius: float, strength: float) -> void:
	_parts[part_id] = {"id": part_id, "point": point, "radius": radius,
		"strength": strength, "health": 1.0, "detached": false}

func _fixed_step(h: float) -> bool:
	for index in NODE_COUNT:
		var offset := index * 3
		_force_scratch[offset] = (_plastic[index].x - _position[index].x) * 240.0 \
			- _velocity[index].x * 26.0
		_force_scratch[offset + 1] = (_plastic[index].y - _position[index].y) * 240.0 \
			- _velocity[index].y * 26.0
		_force_scratch[offset + 2] = (_plastic[index].z - _position[index].z) * 240.0 \
			- _velocity[index].z * 26.0
	for beam_index in BEAM_COUNT:
		if _beam_broken[beam_index] != 0:
			continue
		var a := _beam_a[beam_index]
		var b := _beam_b[beam_index]
		var delta := _position[b] - _position[a]
		var length := delta.length()
		if length < 0.00000001:
			continue
		var relative := (_velocity[b] - _velocity[a]).dot(delta) / length
		var force := clampf((length - _beam_rest_length[beam_index]) * 42.0
			+ relative * 1.8, -100.0, 100.0) / length
		var a_offset := a * 3
		var b_offset := b * 3
		_force_scratch[a_offset] += delta.x * force
		_force_scratch[a_offset + 1] += delta.y * force
		_force_scratch[a_offset + 2] += delta.z * force
		_force_scratch[b_offset] -= delta.x * force
		_force_scratch[b_offset + 1] -= delta.y * force
		_force_scratch[b_offset + 2] -= delta.z * force
	var moving := false
	for index in NODE_COUNT:
		var offset := index * 3
		var velocity := _velocity[index]
		var position := _position[index]
		velocity.x = clampf(velocity.x + _force_scratch[offset] * h, -2.0, 2.0)
		position.x += velocity.x * h
		var delta := position.x - _plastic[index].x
		if absf(delta) > 0.15:
			position.x = _plastic[index].x + signf(delta) * 0.15
			velocity.x = 0.0
		velocity.y = clampf(velocity.y + _force_scratch[offset + 1] * h, -2.0, 2.0)
		position.y += velocity.y * h
		delta = position.y - _plastic[index].y
		if absf(delta) > 0.15:
			position.y = _plastic[index].y + signf(delta) * 0.15
			velocity.y = 0.0
		velocity.z = clampf(velocity.z + _force_scratch[offset + 2] * h, -2.0, 2.0)
		position.z += velocity.z * h
		delta = position.z - _plastic[index].z
		if absf(delta) > 0.15:
			position.z = _plastic[index].z + signf(delta) * 0.15
			velocity.z = 0.0
		_velocity[index] = velocity
		_position[index] = position
		if velocity.length() > 0.0008:
			moving = true
	_simulation_time += h
	return moving

static func source_local_to_native(point: Vector3) -> Vector3:
	return Vector3(-point.x, point.y, -point.z)

static func native_local_to_source(point: Vector3) -> Vector3:
	return source_local_to_native(point)

static func _valid_profile(profile: Dictionary) -> bool:
	for scalar in ["massKg", "halfWidth", "halfLength", "height"]:
		if not _finite_number(profile.get(scalar)):
			return false
	if float(profile.massKg) < 400.0 or float(profile.massKg) > 40000.0 \
			or float(profile.halfWidth) < 0.5 or float(profile.halfWidth) > 2.6 \
			or float(profile.halfLength) < 1.2 or float(profile.halfLength) > 8.0 \
			or float(profile.height) < 0.8 or float(profile.height) > 4.8:
		return false
	if not profile.get("partPoints") is Dictionary \
			or not profile.get("wheelPositions") is Dictionary \
			or not profile.get("componentPoints") is Dictionary:
		return false
	var part_points: Dictionary = profile.partPoints
	var wheel_points: Dictionary = profile.wheelPositions
	var component_points: Dictionary = profile.componentPoints
	for id in ["hood", "trunk", "door_front_left", "door_front_right", "wheel_front_left",
			"wheel_front_right", "wheel_rear_left", "wheel_rear_right"]:
		if not _valid_vector_dict(part_points.get(id)):
			return false
	# These exact pinned-manifest profiles have no authored rear-door part points.
	# createCrashMechanicsState still creates both logical damage parts from its
	# canonical formula. Profile identity, not caller-supplied family, owns this
	# narrowly bounded exception; no other missing visual mount is admitted.
	for id in ["door_rear_left", "door_rear_right"]:
		if part_points.has(id) and not _valid_vector_dict(part_points.get(id)):
			return false
		if not part_points.has(id) \
				and not LOGICAL_REAR_FALLBACK_PROFILE_IDS.has(profile.get("id")):
			return false
	for id in WHEEL_IDS:
		if not _valid_vector_dict(wheel_points.get(id)):
			return false
	for id in ["engine", "radiator"]:
		if not _valid_vector_dict(component_points.get(id)):
			return false
	return true

static func _valid_vector_dict(value: Variant) -> bool:
	return value is Dictionary and _finite_number(value.get("x")) \
		and _finite_number(value.get("y")) and _finite_number(value.get("z"))

static func _dict_vector(value: Dictionary) -> Vector3:
	return Vector3(float(value.x), float(value.y), float(value.z))

static func _vector_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}

static func _crush_limits(half_width: float, half_length: float, height: float) -> Vector3:
	return Vector3(minf(1.30, half_width * 1.20), minf(0.80, height * 0.38),
		minf(1.65, half_length * 0.72))

static func _locality(point: Vector3, target: Vector3, radius: float,
		vertical_scale := 1.0) -> float:
	var d2 := ((point.x - target.x) * (point.x - target.x)
		+ ((point.y - target.y) * vertical_scale) * ((point.y - target.y) * vertical_scale)
		+ (point.z - target.z) * (point.z - target.z)) / (radius * radius)
	return 0.0 if d2 >= 5.0 else exp(-d2 * 1.5)

static func _health_loss(value: float, amount: float) -> float:
	return clampf(value - maxf(0.0, amount), 0.0, 1.0)

static func _node_index(x: int, y: int, z: int) -> int:
	return (z * GRID_Y_COUNT + y) * GRID_X_COUNT + x

static func _interval_value(values: PackedFloat64Array, value: float) -> float:
	var admitted := clampf(value, values[0], values[values.size() - 1])
	for index in values.size() - 1:
		if admitted <= values[index + 1]:
			return index + (admitted - values[index]) / (values[index + 1] - values[index])
	return values.size() - 1

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
