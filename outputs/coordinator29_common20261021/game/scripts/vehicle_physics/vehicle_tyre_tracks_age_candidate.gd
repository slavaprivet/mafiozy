class_name NativeVehicleTyreTracksAgeCandidate
extends "res://scripts/vehicle_physics/vehicle_tyre_tracks.gd"
## Proposal-only renderer aging. Geometry, admission and continuity remain in
## the frozen component; this subclass replaces only per-tick alpha uploads.

const CLOCK_PERIOD_S := 32.0

var _elapsed_s := 0.0
var _birth_s := PackedFloat64Array()
var _track_material: ShaderMaterial

func _build_render_pool() -> void:
	_birth_s.resize(MAX_SEGMENTS)
	super._build_render_pool()
	_track_material = multimesh.mesh.surface_get_material(0) as ShaderMaterial
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 track_color : source_color = vec4(0.2039215686, 0.2156862745, 0.1960784314, 1.0);
uniform float elapsed_clock_s = 0.0;
varying float track_opacity;
void vertex() {
	float age_s = mod(elapsed_clock_s - INSTANCE_CUSTOM.y + 32.0, 32.0);
	float fade = min(1.0, max(0.0, (10.0 - age_s) / 4.5));
	track_opacity = INSTANCE_CUSTOM.x * fade;
}
void fragment() {
	if (track_opacity < 0.002) { discard; }
	ALBEDO = track_color.rgb;
	ALPHA = track_opacity;
}
"""
	_track_material.shader = shader

func clear() -> void:
	super.clear()
	_elapsed_s = 0.0
	if _birth_s.size() == MAX_SEGMENTS:
		_birth_s.fill(0.0)
	if _track_material != null:
		_track_material.set_shader_parameter("elapsed_clock_s", 0.0)

func dispose() -> void:
	super.dispose()
	_track_material = null

func age_at(slot: int) -> float:
	if slot < 0 or slot >= MAX_SEGMENTS or _active[slot] == 0:
		return LIFETIME_S
	return minf(LIFETIME_S, _elapsed_s - _birth_s[slot])

func opacity_at(slot: int) -> float:
	if slot < 0 or slot >= MAX_SEGMENTS or _active[slot] == 0:
		return 0.0
	return _strengths[slot] * minf(1.0,
		(LIFETIME_S - age_at(slot)) / (LIFETIME_S * FADE_FRACTION))

func _age_segments(delta: float) -> void:
	_elapsed_s += delta
	# Shader time stays in a short, exactly representable range. CPU lifetime
	# remains float64 and retires slots before any 32-second alias can recur.
	if _track_material != null:
		_track_material.set_shader_parameter("elapsed_clock_s", fmod(_elapsed_s, CLOCK_PERIOD_S))
	while _active_count > 0:
		var oldest := posmod(_cursor - _active_count, MAX_SEGMENTS)
		if _elapsed_s - _birth_s[oldest] < LIFETIME_S:
			break
		_active[oldest] = 0
		_strengths[oldest] = 0.0
		_opacities[oldest] = 0.0
		_ages[oldest] = LIFETIME_S
		multimesh.set_instance_custom_data(oldest, Color(0, 0, 0, 0))
		_active_count -= 1

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
	_birth_s[_cursor] = _elapsed_s
	_segment_transforms[_cursor] = transform
	multimesh.set_instance_transform(_cursor, transform)
	multimesh.set_instance_custom_data(_cursor, Color(strength, fmod(_elapsed_s, CLOCK_PERIOD_S), 0, 0))
	_expand_bounds(from_point + segment_normal * SURFACE_LIFT_M,
		point + segment_normal * SURFACE_LIFT_M)
	_cursor = (_cursor + 1) % MAX_SEGMENTS
	_count = mini(MAX_SEGMENTS, _count + 1)
	_previous_points[index] = point
	_previous_normals[index] = normal
