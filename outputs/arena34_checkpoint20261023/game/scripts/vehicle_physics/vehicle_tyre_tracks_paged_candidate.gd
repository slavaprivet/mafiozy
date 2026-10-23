class_name NativeVehicleTyreTracksPagedCandidate
extends "res://scripts/vehicle_physics/vehicle_tyre_tracks.gd"
## Proposal only: source-sized ring split into independently culled world-space pages.

const PAGE_SIZE := 100
const PAGE_COUNT := 12
const CLOCK_PERIOD_S := 32.0
const EMPTY_BOUNDS := AABB(Vector3(-0.01, -0.01, -0.01), Vector3(0.02, 0.02, 0.02))

var _elapsed_s := 0.0
var _birth_s := PackedFloat64Array()
var _pages: Array[MultiMesh] = []
var _page_nodes: Array[MultiMeshInstance3D] = []
var _track_material: ShaderMaterial

func _build_render_pool() -> void:
	_birth_s.resize(MAX_SEGMENTS)
	super._build_render_pool()
	var mesh := multimesh.mesh
	_track_material = mesh.surface_get_material(0) as ShaderMaterial
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
	for page_index in PAGE_COUNT:
		var pool := MultiMesh.new()
		pool.transform_format = MultiMesh.TRANSFORM_3D
		pool.use_custom_data = true
		pool.mesh = mesh
		pool.instance_count = PAGE_SIZE
		pool.visible_instance_count = 0
		pool.custom_aabb = EMPTY_BOUNDS
		_pages.append(pool)
		if page_index == 0:
			multimesh = pool
			_page_nodes.append(self)
		else:
			var page_node := MultiMeshInstance3D.new()
			page_node.name = "TyreTrackPage%02d" % page_index
			page_node.multimesh = pool
			page_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			page_node.ignore_occlusion_culling = false
			add_child(page_node)
			_page_nodes.append(page_node)
	ignore_occlusion_culling = false
	clear()

func clear() -> void:
	_reset_continuity()
	_last_physics_tick = -1
	_cursor = 0
	_count = 0
	_active_count = 0
	_track_bounds = AABB()
	_track_bounds_valid = false
	_elapsed_s = 0.0
	if _ages.size() != MAX_SEGMENTS:
		return
	for slot in MAX_SEGMENTS:
		_ages[slot] = LIFETIME_S
		_strengths[slot] = 0.0
		_opacities[slot] = 0.0
		_active[slot] = 0
		_segment_transforms[slot] = Transform3D.IDENTITY
		_birth_s[slot] = 0.0
		if _pages.size() == PAGE_COUNT:
			var page := _pages[slot / PAGE_SIZE]
			page.set_instance_transform(slot % PAGE_SIZE, Transform3D.IDENTITY)
			page.set_instance_custom_data(slot % PAGE_SIZE, Color(0, 0, 0, 0))
		elif multimesh != null:
			multimesh.set_instance_transform(slot, Transform3D.IDENTITY)
			multimesh.set_instance_custom_data(slot, Color(0, 0, 0, 0))
	for page in _pages:
		page.visible_instance_count = 0
		page.custom_aabb = EMPTY_BOUNDS
	if _track_material != null:
		_track_material.set_shader_parameter("elapsed_clock_s", 0.0)

func dispose() -> void:
	if _disposed:
		return
	clear()
	_disposed = true
	_configured = false
	for page_index in range(1, _page_nodes.size()):
		_page_nodes[page_index].queue_free()
	_pages.clear()
	_page_nodes.clear()
	_track_material = null
	multimesh = null
	if is_inside_tree():
		queue_free()

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
	_track_material.set_shader_parameter("elapsed_clock_s", fmod(_elapsed_s, CLOCK_PERIOD_S))
	var dirty := PackedByteArray()
	dirty.resize(PAGE_COUNT)
	while _active_count > 0:
		var oldest := posmod(_cursor - _active_count, MAX_SEGMENTS)
		if _elapsed_s - _birth_s[oldest] < LIFETIME_S:
			break
		_active[oldest] = 0
		_strengths[oldest] = 0.0
		_opacities[oldest] = 0.0
		_ages[oldest] = LIFETIME_S
		_pages[oldest / PAGE_SIZE].set_instance_custom_data(oldest % PAGE_SIZE, Color(0, 0, 0, 0))
		dirty[oldest / PAGE_SIZE] = 1
		_active_count -= 1
	for page_index in PAGE_COUNT:
		if dirty[page_index] != 0:
			_refresh_page(page_index)

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
	var page_index := _cursor / PAGE_SIZE
	var local_slot := _cursor % PAGE_SIZE
	_pages[page_index].set_instance_transform(local_slot, transform)
	_pages[page_index].set_instance_custom_data(local_slot,
		Color(strength, fmod(_elapsed_s, CLOCK_PERIOD_S), 0, 0))
	_refresh_page(page_index)
	_cursor = (_cursor + 1) % MAX_SEGMENTS
	_count = mini(MAX_SEGMENTS, _count + 1)
	_previous_points[index] = point
	_previous_normals[index] = normal

func _refresh_page(page_index: int) -> void:
	var first := page_index * PAGE_SIZE
	var highest := -1
	var bounds := AABB()
	var valid := false
	for offset in PAGE_SIZE:
		var slot := first + offset
		if _active[slot] == 0:
			continue
		highest = offset
		var transform := _segment_transforms[slot]
		var half_length := transform.basis.z * 0.5
		var segment_bounds := AABB(transform.origin - half_length, Vector3.ZERO)
		segment_bounds = segment_bounds.expand(transform.origin + half_length)
		segment_bounds = segment_bounds.grow(WIDTH_M + SURFACE_LIFT_M)
		bounds = bounds.merge(segment_bounds) if valid else segment_bounds
		valid = true
	_pages[page_index].visible_instance_count = highest + 1
	_pages[page_index].custom_aabb = bounds if valid else EMPTY_BOUNDS
