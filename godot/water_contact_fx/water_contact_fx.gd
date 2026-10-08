extends Node3D
## Explicit update only. Visual particles cannot receive physics/interaction rays.
## Three fixed MultiMesh buffers, compact live instances, source mesh topology.
const Sim = preload("res://water_contact_simulator.gd")
const SEGMENTS := 12
const STRIDE := 16 # 3x4 transform + RGBA custom data; no instance colors.
const EFFECT_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 effect_color : source_color;
uniform float effect_opacity;
uniform float effect_roughness;
varying float effect_alpha;
void vertex() { effect_alpha = INSTANCE_CUSTOM.x; }
void fragment() {
 ALBEDO = effect_color.rgb;
 ALPHA = effect_opacity * effect_alpha;
 METALLIC = .08;
 ROUGHNESS = effect_roughness;
}
"""
var simulator: RefCounted
var drops: MultiMeshInstance3D
var circles: MultiMeshInstance3D
var froth: MultiMeshInstance3D
var _drop_buffer := PackedFloat32Array()
var _ring_buffer := PackedFloat32Array()
var _foam_buffer := PackedFloat32Array()
var _disposed := false
var _built := false
var buffer_capacity_resizes := 0
var _ring_basis: Array[Basis] = []
var _ring_cos := PackedFloat64Array()
var _ring_sin := PackedFloat64Array()
var last_upload_us := 0

func setup(options: Dictionary) -> bool:
	if _built or _disposed: return false
	if transform != Transform3D.IDENTITY: return false
	if is_inside_tree() and global_transform != Transform3D.IDENTITY: return false
	simulator = Sim.new()
	if not simulator.configure(options): simulator = null; return false
	name = "Hero water contact effects"
	drops = _batch("Ballistic water droplets", _sphere(), simulator.droplets.size(), Color("b7e0e3"), 0.9, 0.16)
	circles = _batch("Shore clipped expanding arcs", _arc(), simulator.rings.size() * SEGMENTS, Color("d6efeb"), 0.55, 0.6)
	froth = _batch("Surface recontact foam", _disk(), simulator.foam.size(), Color("e1eee5"), 0.62, 0.85)
	_drop_buffer.resize(drops.multimesh.instance_count * STRIDE)
	_ring_buffer.resize(circles.multimesh.instance_count * STRIDE)
	_foam_buffer.resize(froth.multimesh.instance_count * STRIDE)
	buffer_capacity_resizes = 3
	for i in range(SEGMENTS):
		_ring_basis.append(Basis(Vector3.UP, i * TAU / SEGMENTS))
		for fraction in [0.0, 0.5, 1.0]:
			var angle: float = (i + fraction) * TAU / SEGMENTS
			_ring_cos.append(cos(angle)); _ring_sin.append(sin(angle))
	_built = true
	return true

func _batch(label: String, geometry: ArrayMesh, count: int, color: Color, opacity: float, roughness: float) -> MultiMeshInstance3D:
	var shader := Shader.new(); shader.code = EFFECT_SHADER
	var material := ShaderMaterial.new(); material.shader = shader; material.render_priority = 3
	material.set_shader_parameter("effect_color", color)
	material.set_shader_parameter("effect_opacity", opacity)
	material.set_shader_parameter("effect_roughness", roughness)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_custom_data = true
	mm.mesh = geometry; mm.instance_count = maxi(1, count); mm.visible_instance_count = 0
	# Three source disables frustum culling. Keep source-world envelope available.
	mm.custom_aabb = AABB(Vector3(-1000000, -1000000, -1000000), Vector3(2000000, 2000000, 2000000))
	var mesh := MultiMeshInstance3D.new(); mesh.name = label; mesh.multimesh = mm
	mesh.material_override = material; mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visible = false; add_child(mesh)
	return mesh

static func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _sphere() -> ArrayMesh:
	var vertices := PackedVector3Array(); var indices := PackedInt32Array()
	for iy in range(5):
		for ix in range(7):
			var phi := float(ix) / 6 * TAU; var theta := float(iy) / 4 * PI
			vertices.append(Vector3(-cos(phi) * sin(theta), cos(theta), sin(phi) * sin(theta)))
	for iy in range(4):
		for ix in range(6):
			var a := iy * 7 + ix + 1; var b := iy * 7 + ix; var c := (iy + 1) * 7 + ix; var d := c + 1
			if iy != 0: indices.append_array(PackedInt32Array([a, d, b]))
			if iy != 3: indices.append_array(PackedInt32Array([b, d, c]))
	return _mesh(vertices, vertices.duplicate(), indices)

static func _arc() -> ArrayMesh:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var indices := PackedInt32Array()
	for radius in [0.97, 1.03]:
		for i in range(4):
			var angle := float(i) / 3 * TAU / SEGMENTS
			vertices.append(Vector3(cos(angle) * radius, 0, -sin(angle) * radius)); normals.append(Vector3.UP)
	for i in range(3): indices.append_array(PackedInt32Array([i, i + 1, i + 4, i + 4, i + 1, i + 5]))
	return _mesh(vertices, normals, indices)

static func _disk() -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3.ZERO]); var normals := PackedVector3Array([Vector3.UP]); var indices := PackedInt32Array()
	for i in range(8):
		var angle := float(i) / 7 * TAU
		vertices.append(Vector3(cos(angle), 0, -sin(angle))); normals.append(Vector3.UP)
	for i in range(1, 8): indices.append_array(PackedInt32Array([i, 0, i + 1]))
	return _mesh(vertices, normals, indices)

static func _write(buffer: PackedFloat32Array, index: int, basis: Basis, x: float, y: float, z: float, alpha: float) -> void:
	var at := index * STRIDE
	buffer[at] = basis.x.x; buffer[at + 1] = basis.y.x; buffer[at + 2] = basis.z.x; buffer[at + 3] = x
	buffer[at + 4] = basis.x.y; buffer[at + 5] = basis.y.y; buffer[at + 6] = basis.z.y; buffer[at + 7] = y
	buffer[at + 8] = basis.x.z; buffer[at + 9] = basis.y.z; buffer[at + 10] = basis.z.z; buffer[at + 11] = z
	buffer[at + 12] = clampf(alpha, 0, 1); buffer[at + 13] = 0; buffer[at + 14] = 0; buffer[at + 15] = 0

func _upload() -> void:
	var started := Time.get_ticks_usec()
	var n := 0
	for p in simulator.droplets:
		if not p.active: continue
		var velocity := Vector3(p.vx, p.vy, p.vz); var speed := velocity.length()
		var direction := velocity / speed if speed > 0.001 else Vector3.UP
		var basis := Basis(Quaternion(Vector3.UP, direction)).scaled_local(Vector3(p.radius, p.radius * (1 + minf(3, speed * 0.28)), p.radius))
		_write(_drop_buffer, n, basis, p.x, p.y, p.z, clampf((p.life - p.age) / 0.25, 0, 1)); n += 1
	_commit(drops,_drop_buffer,n)
	n = 0
	for p in simulator.rings:
		if not p.active: continue
		var fade := pow(1 - p.age / p.life, 1.8)
		if fade < 0.015: continue
		for i in range(SEGMENTS):
			var wet := true
			for fraction_index in range(3):
				var angle_index := i * 3 + fraction_index
				for rim in [0.97, 1.03]:
					var w: Variant = simulator.sample(p.x + _ring_cos[angle_index] * p.radius * rim, p.z - _ring_sin[angle_index] * p.radius * rim)
					if w == null or absf(float(w.level) - (p.y - 0.016)) > 0.08: wet = false; break
				if not wet: break
			if not wet: continue
			var basis := _ring_basis[i].scaled_local(Vector3(p.radius, 1, p.radius))
			_write(_ring_buffer, n, basis, p.x, p.y, p.z, fade * minf(1, 0.3 + p.strength)); n += 1
	_commit(circles,_ring_buffer,n)
	n = 0
	for p in simulator.foam:
		if not p.active: continue
		var size: float = p.radius * (1 + p.age * 0.65)
		var basis := Basis(Vector3.UP, p.angle).scaled_local(Vector3(size, 1, size * 0.62))
		_write(_foam_buffer, n, basis, p.x, p.y, p.z, pow(1 - p.age / p.life, 1.5)); n += 1
	_commit(froth,_foam_buffer,n)
	last_upload_us = Time.get_ticks_usec() - started

static func _commit(mesh: MultiMeshInstance3D, buffer: PackedFloat32Array, count: int) -> void:
	if count > 0: mesh.multimesh.buffer = buffer
	if mesh.multimesh.visible_instance_count != count: mesh.multimesh.visible_instance_count = count
	mesh.visible = count > 0

func advance(dt: float, input: Dictionary = {}) -> void:
	if _disposed or not _built: return
	simulator.update(dt, input)
	_upload()

func get_ripples() -> Array[Dictionary]:
	return simulator.get_ripples() if simulator != null else []

func stats() -> Dictionary:
	var result: Dictionary = simulator.stats() if simulator != null else {}
	var calls := 0
	if not _disposed and _built:
		for mesh in [drops, circles, froth]:
			if mesh.visible and mesh.multimesh.visible_instance_count > 0: calls += 1
	result.drawCalls = calls
	result.ringSegments = circles.multimesh.visible_instance_count if is_instance_valid(circles) else 0
	result.bufferCapacityResizes = buffer_capacity_resizes
	result.uploadMicroseconds = last_upload_us
	return result

func dispose(detach: bool = true) -> void:
	if _disposed: return
	_disposed = true
	if simulator != null: simulator.dispose()
	for mesh in [drops, circles, froth]:
		if is_instance_valid(mesh):
			mesh.multimesh.mesh = null; mesh.multimesh = null; mesh.material_override = null
			remove_child(mesh); mesh.free()
	_drop_buffer.clear(); _ring_buffer.clear(); _foam_buffer.clear()
	_ring_basis.clear(); _ring_cos.clear(); _ring_sin.clear()
	if detach and get_parent() != null: get_parent().remove_child(self)

func _exit_tree() -> void:
	# External removal also releases source callbacks and effect resources.
	if not _disposed: dispose(false)
