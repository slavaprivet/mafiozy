class_name NativeVehicleCrashCage
extends RefCounted
## Proposal-only immutable crash-cage geometry and deformation sampler.
## It deliberately owns no impacts, health, debris, rendering or runtime hook.

const NODE_COUNT := 45
const BEAM_COUNT := 232
const GRID_X_COUNT := 3
const GRID_Y_COUNT := 3
const GRID_Z_COUNT := 5
const SOURCE_HALF_WIDTH_RANGE := Vector2(0.5, 2.6)
const SOURCE_HALF_LENGTH_RANGE := Vector2(1.2, 8.0)
const SOURCE_HEIGHT_RANGE := Vector2(0.8, 4.8)
const SOURCE_NEIGHBORS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1),
	Vector3i(1, 1, 0), Vector3i(-1, 1, 0),
	Vector3i(1, 0, 1), Vector3i(-1, 0, 1),
	Vector3i(0, 1, 1), Vector3i(0, -1, 1),
]

var _configured := false
var _profile_id := ""
var _half_width_m := 0.0
var _half_length_m := 0.0
var _height_m := 0.0
var _grid_source_x := PackedFloat64Array()
var _grid_source_y := PackedFloat64Array()
var _grid_source_z := PackedFloat64Array()
var _rest_source := PackedVector3Array()
var _rest_native := PackedVector3Array()
var _plastic_native := PackedVector3Array()
var _positions_native := PackedVector3Array()
var _velocities_native := PackedVector3Array()
var _beam_a := PackedInt32Array()
var _beam_b := PackedInt32Array()
var _beam_original_length_m := PackedFloat64Array()
var _beam_rest_length_m := PackedFloat64Array()
var _beam_broken := PackedByteArray()
var _beam_plastic_strain := PackedFloat64Array()

func configure_from_descriptor(descriptor_value: Variant) -> bool:
	if _configured or not descriptor_value is Dictionary:
		return false
	var descriptor: Dictionary = descriptor_value
	if not descriptor.get("profile_id") is String \
			or (descriptor.profile_id as String).is_empty() \
			or descriptor.get("source_units") != "metres" \
			or descriptor.get("source_forward_axis") != "+Z" \
			or descriptor.get("godot_forward_axis") != "-Z" \
			or not descriptor.get("body_half_extents_m") is Dictionary:
		return false
	var extents: Dictionary = descriptor.body_half_extents_m
	if not _finite_number(extents.get("x")) or not _finite_number(extents.get("y")) \
			or not _finite_number(extents.get("z")):
		return false
	var half_width := float(extents.x)
	var height := float(extents.y) * 2.0
	var half_length := float(extents.z)
	# The JS source clamps these ranges. Native proposal state rejects instead:
	# malformed descriptor authority must never be silently repaired.
	if half_width < SOURCE_HALF_WIDTH_RANGE.x or half_width > SOURCE_HALF_WIDTH_RANGE.y \
			or half_length < SOURCE_HALF_LENGTH_RANGE.x or half_length > SOURCE_HALF_LENGTH_RANGE.y \
			or height < SOURCE_HEIGHT_RANGE.x or height > SOURCE_HEIGHT_RANGE.y:
		return false
	_profile_id = descriptor.profile_id
	_half_width_m = half_width
	_half_length_m = half_length
	_height_m = height
	_allocate_fixed_storage()
	_build_source_geometry()
	_configured = true
	return true

func is_configured() -> bool:
	return _configured

func summary() -> Dictionary:
	return {"configured": _configured, "profile_id": _profile_id,
		"half_width_m": _half_width_m, "half_length_m": _half_length_m,
		"height_m": _height_m, "nodes": NODE_COUNT if _configured else 0,
		"beams": BEAM_COUNT if _configured else 0,
		"proposal_only": true}

func rest_node_source(index: int) -> Variant:
	if not _configured or index < 0 or index >= NODE_COUNT:
		return null
	return _rest_source[index]

func rest_node_native(index: int) -> Variant:
	if not _configured or index < 0 or index >= NODE_COUNT:
		return null
	return _rest_native[index]

func beam(index: int) -> Dictionary:
	if not _configured or index < 0 or index >= BEAM_COUNT:
		return {}
	return {"a": _beam_a[index], "b": _beam_b[index],
		"original_length_m": _beam_original_length_m[index],
		"rest_length_m": _beam_rest_length_m[index],
		"broken": _beam_broken[index] != 0,
		"plastic_strain": _beam_plastic_strain[index]}

func sample_deformation_native(native_point_value: Variant) -> Variant:
	if not _configured:
		return null
	var source_point_value: Variant = native_local_to_source(native_point_value)
	if source_point_value == null:
		return null
	var source_point: Vector3 = source_point_value
	var xv := _interval_value(_grid_source_x, source_point.x)
	var yv := _interval_value(_grid_source_y, source_point.y)
	var zv := _interval_value(_grid_source_z, source_point.z)
	var xi := mini(GRID_X_COUNT - 2, int(floor(xv)))
	var yi := mini(GRID_Y_COUNT - 2, int(floor(yv)))
	var zi := mini(GRID_Z_COUNT - 2, int(floor(zv)))
	var xt := xv - xi
	var yt := yv - yi
	var zt := zv - zi
	var result := Vector3.ZERO
	for z in 2:
		for y in 2:
			for x in 2:
				var weight := (xt if x else 1.0 - xt) * (yt if y else 1.0 - yt) \
					* (zt if z else 1.0 - zt)
				var node_index := _node_index(xi + x, yi + y, zi + z)
				var position := _positions_native[node_index]
				if not position.is_finite():
					return null
				result += (position - _rest_native[node_index]) * weight
	return result

static func source_local_to_native(value: Variant) -> Variant:
	if not value is Vector3 or not (value as Vector3).is_finite():
		return null
	var point: Vector3 = value
	return Vector3(-point.x, point.y, -point.z)

static func native_local_to_source(value: Variant) -> Variant:
	# The descriptor transform is an involution: Godot local = (-X, Y, -Z).
	return source_local_to_native(value)

func _allocate_fixed_storage() -> void:
	_grid_source_x.resize(GRID_X_COUNT)
	_grid_source_y.resize(GRID_Y_COUNT)
	_grid_source_z.resize(GRID_Z_COUNT)
	_rest_source.resize(NODE_COUNT)
	_rest_native.resize(NODE_COUNT)
	_plastic_native.resize(NODE_COUNT)
	_positions_native.resize(NODE_COUNT)
	_velocities_native.resize(NODE_COUNT)
	_beam_a.resize(BEAM_COUNT)
	_beam_b.resize(BEAM_COUNT)
	_beam_original_length_m.resize(BEAM_COUNT)
	_beam_rest_length_m.resize(BEAM_COUNT)
	_beam_broken.resize(BEAM_COUNT)
	_beam_plastic_strain.resize(BEAM_COUNT)

func _build_source_geometry() -> void:
	_grid_source_x[0] = -_half_width_m
	_grid_source_x[1] = 0.0
	_grid_source_x[2] = _half_width_m
	_grid_source_y[0] = 0.28
	_grid_source_y[1] = _height_m * 0.46
	_grid_source_y[2] = _height_m * 0.91
	_grid_source_z[0] = -_half_length_m
	_grid_source_z[1] = -_half_length_m * 0.5
	_grid_source_z[2] = 0.0
	_grid_source_z[3] = _half_length_m * 0.5
	_grid_source_z[4] = _half_length_m
	for z in GRID_Z_COUNT:
		for y in GRID_Y_COUNT:
			for x in GRID_X_COUNT:
				var index := _node_index(x, y, z)
				var source_rest := Vector3(_grid_source_x[x], _grid_source_y[y], _grid_source_z[z])
				var native_rest: Vector3 = source_local_to_native(source_rest)
				_rest_source[index] = source_rest
				_rest_native[index] = native_rest
				_plastic_native[index] = native_rest
				_positions_native[index] = native_rest
				_velocities_native[index] = Vector3.ZERO
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
					var original_length := _rest_source[a].distance_to(_rest_source[b])
					_beam_a[beam_index] = a
					_beam_b[beam_index] = b
					_beam_original_length_m[beam_index] = original_length
					_beam_rest_length_m[beam_index] = original_length
					_beam_broken[beam_index] = 0
					_beam_plastic_strain[beam_index] = 0.0
					beam_index += 1
	assert(beam_index == BEAM_COUNT)

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
