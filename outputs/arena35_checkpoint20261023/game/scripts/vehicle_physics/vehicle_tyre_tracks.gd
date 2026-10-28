class_name NativeVehicleTyreTracks
extends MultiMeshInstance3D
## Bounded presentation-only tyre marks. The caller owns vehicle/contact
## authority and supplies the already sampled wheel contacts. This component
## performs no raycasts and must be mounted in world space, never under a car.

const MAX_SEGMENTS := 1200
const LIFETIME_S := 10.0
const SPACING_M := 0.28
const WIDTH_M := 0.19
const MIN_SLIP := 0.2
const MIN_SPEED_MPS := 0.6
const MAX_GAP_M := 3.0
const MAX_ALPHA := 0.42
const FADE_FRACTION := 0.45
const SURFACE_LIFT_M := 0.018
const WHEEL_COUNT := 4
const SURFACE_IDS := {"road": true, "sidewalk": true, "bridge": true}

var _configured := false
var _disposed := false
var _vehicle_id := ""
var _life_generation := 0
var _last_physics_tick := -1
var _cursor := 0
var _count := 0
var _active_count := 0
var _ages := PackedFloat32Array()
var _strengths := PackedFloat32Array()
var _opacities := PackedFloat32Array()
var _active := PackedByteArray()
var _segment_transforms: Array[Transform3D] = []
var _previous_points := PackedVector3Array()
var _previous_normals := PackedVector3Array()
var _has_previous := PackedByteArray()
var _track_bounds := AABB()
var _track_bounds_valid := false

func configure(vehicle_id_value: Variant, life_generation_value: Variant) -> bool:
	if _configured or _disposed or not vehicle_id_value is String \
			or (vehicle_id_value as String).is_empty() or not life_generation_value is int \
			or int(life_generation_value) < 1:
		return false
	_vehicle_id = vehicle_id_value
	_life_generation = int(life_generation_value)
	_build_render_pool()
	_configured = true
	return true

func step(delta_value: Variant, physics_tick_value: Variant, speed_value: Variant,
		contacts_value: Variant) -> bool:
	if not _configured or _disposed or not _finite_number(delta_value) \
			or float(delta_value) < 0.0 or not physics_tick_value is int \
			or not _finite_number(speed_value) or not contacts_value is Array:
		_reset_continuity()
		return false
	var delta := float(delta_value)
	var physics_tick := int(physics_tick_value)
	if physics_tick <= _last_physics_tick:
		_reset_continuity()
		return false
	_last_physics_tick = physics_tick
	_age_segments(delta)
	var contacts: Array = contacts_value
	if contacts.size() > WHEEL_COUNT:
		_reset_continuity()
		return false
	var by_wheel: Array = [null, null, null, null]
	for value: Variant in contacts:
		if not value is Dictionary:
			_reset_continuity()
			return false
		var admitted := _admit_contact(value, physics_tick)
		if admitted.is_empty():
			_reset_continuity()
			return false
		var index := int(admitted.wheel_index)
		if by_wheel[index] != null:
			_reset_continuity()
			return false
		by_wheel[index] = admitted
	var speed_mps := float(speed_value)
	for index in WHEEL_COUNT:
		_consume_wheel(index, by_wheel[index], speed_mps)
	return true

func clear() -> void:
	_reset_continuity()
	_last_physics_tick = -1
	_cursor = 0
	_count = 0
	_active_count = 0
	_track_bounds = AABB()
	_track_bounds_valid = false
	if _ages.size() != MAX_SEGMENTS:
		return
	for slot in MAX_SEGMENTS:
		_ages[slot] = LIFETIME_S
		_strengths[slot] = 0.0
		_opacities[slot] = 0.0
		_active[slot] = 0
		_segment_transforms[slot] = Transform3D.IDENTITY
		if multimesh != null:
			multimesh.set_instance_transform(slot, Transform3D.IDENTITY)
			multimesh.set_instance_custom_data(slot, Color(0, 0, 0, 0))
	if multimesh != null:
		multimesh.custom_aabb = AABB(Vector3(-0.01, -0.01, -0.01), Vector3(0.02, 0.02, 0.02))

func dispose() -> void:
	if _disposed:
		return
	clear()
	_disposed = true
	_configured = false
	multimesh = null
	if is_inside_tree():
		queue_free()

func stats() -> Dictionary:
	return {"configured": _configured, "disposed": _disposed,
		"vehicle_id": _vehicle_id, "life_generation": _life_generation,
		"last_physics_tick": _last_physics_tick, "count": _count,
		"active": _active_count, "cursor": _cursor, "capacity": MAX_SEGMENTS}

func _build_render_pool() -> void:
	var vertices := PackedVector3Array([
		Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, 0.5),
		Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, -0.5), Vector3(-0.5, 0, 0.5),
	])
	var normals := PackedVector3Array()
	normals.resize(6)
	normals.fill(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var segment_mesh := ArrayMesh.new()
	segment_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Authored sRGB #343732; source_color performs the renderer conversion.
uniform vec4 track_color : source_color = vec4(0.2039215686, 0.2156862745, 0.1960784314, 1.0);
varying float track_opacity;
void vertex() { track_opacity = INSTANCE_CUSTOM.x; }
void fragment() {
	if (track_opacity < 0.002) { discard; }
	ALBEDO = track_color.rgb;
	ALPHA = track_opacity;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = 1
	segment_mesh.surface_set_material(0, material)
	var pool := MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.use_custom_data = true
	pool.mesh = segment_mesh
	pool.instance_count = MAX_SEGMENTS
	pool.visible_instance_count = MAX_SEGMENTS
	multimesh = pool
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ignore_occlusion_culling = true
	_ages.resize(MAX_SEGMENTS)
	_strengths.resize(MAX_SEGMENTS)
	_opacities.resize(MAX_SEGMENTS)
	_active.resize(MAX_SEGMENTS)
	_segment_transforms.resize(MAX_SEGMENTS)
	_previous_points.resize(WHEEL_COUNT)
	_previous_normals.resize(WHEEL_COUNT)
	_has_previous.resize(WHEEL_COUNT)
	clear()

func _admit_contact(value: Dictionary, physics_tick: int) -> Dictionary:
	if not value.get("vehicle_id") is String or value.vehicle_id != _vehicle_id \
			or not value.get("life_generation") is int \
			or int(value.life_generation) != _life_generation \
			or not value.get("physics_tick") is int or int(value.physics_tick) != physics_tick \
			or not value.get("wheel_index") is int or int(value.wheel_index) < 0 \
			or int(value.wheel_index) >= WHEEL_COUNT or not value.get("grounded") is bool \
			or not value.get("surface_id") is String or not _finite_number(value.get("slip")):
		return {}
	var admitted := {"wheel_index": int(value.wheel_index), "grounded": bool(value.grounded),
		"surface_id": str(value.surface_id), "slip": float(value.slip)}
	if not admitted.grounded:
		return admitted
	if not value.get("point_world_m") is Vector3 or not value.get("normal_world") is Vector3:
		return {}
	var point: Vector3 = value.point_world_m
	var normal: Vector3 = value.normal_world
	if not point.is_finite() or not normal.is_finite() or normal.length_squared() < 0.000001:
		return {}
	admitted["point_world_m"] = point
	admitted["normal_world"] = normal.normalized()
	return admitted

func _consume_wheel(index: int, value: Variant, speed_mps: float) -> void:
	if value == null:
		_has_previous[index] = 0
		return
	var contact := value as Dictionary
	if not contact.grounded or float(contact.slip) < MIN_SLIP \
			or absf(speed_mps) < MIN_SPEED_MPS or not SURFACE_IDS.has(contact.surface_id):
		_has_previous[index] = 0
		return
	var point: Vector3 = contact.point_world_m
	var normal: Vector3 = contact.normal_world
	if _has_previous[index] == 0:
		_previous_points[index] = point
		_previous_normals[index] = normal
		_has_previous[index] = 1
		return
	var from_point := _previous_points[index]
	var delta := point - from_point
	var length_m := delta.length()
	if length_m > MAX_GAP_M:
		_previous_points[index] = point
		_previous_normals[index] = normal
		return
	if length_m < SPACING_M:
		return
	var tangent := delta / length_m
	var average_normal := _previous_normals[index] + normal
	if average_normal.length_squared() < 0.000001:
		average_normal = normal
	average_normal = average_normal.normalized()
	var width_axis := tangent.cross(average_normal)
	if width_axis.length_squared() < 0.000001:
		_has_previous[index] = 0
		return
	width_axis = width_axis.normalized()
	var segment_normal := width_axis.cross(tangent).normalized()
	var center := (from_point + point) * 0.5 + segment_normal * SURFACE_LIFT_M
	var transform := Transform3D(Basis(width_axis * WIDTH_M, segment_normal, tangent * length_m), center)
	var strength := minf(MAX_ALPHA, maxf(0.0, float(contact.slip)) * MAX_ALPHA)
	if _active[_cursor] == 0:
		_active_count += 1
	_active[_cursor] = 1
	_ages[_cursor] = 0.0
	_strengths[_cursor] = strength
	_opacities[_cursor] = strength
	_segment_transforms[_cursor] = transform
	multimesh.set_instance_transform(_cursor, transform)
	multimesh.set_instance_custom_data(_cursor, Color(strength, 0, 0, 0))
	_expand_bounds(from_point + segment_normal * SURFACE_LIFT_M,
		point + segment_normal * SURFACE_LIFT_M)
	_cursor = (_cursor + 1) % MAX_SEGMENTS
	_count = mini(MAX_SEGMENTS, _count + 1)
	_previous_points[index] = point
	_previous_normals[index] = normal

func _age_segments(delta: float) -> void:
	for slot in MAX_SEGMENTS:
		if _active[slot] == 0:
			continue
		_ages[slot] = minf(LIFETIME_S, _ages[slot] + delta)
		var fade := minf(1.0, (LIFETIME_S - _ages[slot]) / (LIFETIME_S * FADE_FRACTION))
		var opacity := _strengths[slot] * fade
		_opacities[slot] = opacity
		multimesh.set_instance_custom_data(slot, Color(opacity, 0, 0, 0))
		if _ages[slot] >= LIFETIME_S:
			_strengths[slot] = 0.0
			_active[slot] = 0
			_active_count -= 1

func _expand_bounds(from_point: Vector3, to_point: Vector3) -> void:
	var segment_bounds := AABB(from_point, Vector3.ZERO).expand(to_point).grow(WIDTH_M + SURFACE_LIFT_M)
	_track_bounds = _track_bounds.merge(segment_bounds) if _track_bounds_valid else segment_bounds
	_track_bounds_valid = true
	multimesh.custom_aabb = _track_bounds

func _reset_continuity() -> void:
	_has_previous.fill(0)

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
