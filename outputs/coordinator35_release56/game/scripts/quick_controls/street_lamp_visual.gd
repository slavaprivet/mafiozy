extends RefCounted
## Reusable Bellini lantern head. The host keeps the authored pole/arm/base.
## Three visible surfaces per intact head, no callbacks or animation loops.
## build() is lamp-local; hit_shapes use the returned root's local coordinates.

const HEAD_ORIGIN := Vector3(1.15, 5.62, 0.0)
const GLASS_HALF_WIDTH := 0.276
const GLASS_HEIGHT := 0.49
const GLASS_THICKNESS := 0.009
const LIGHT_LOCAL_POSITION := Vector3(0.0, -0.16, 0.0)

static var _frame_mesh: ArrayMesh
static var _glass_mesh: ArrayMesh
static var _broken_glass_mesh: ArrayMesh
static var _bulb_mesh: ArrayMesh
static var _frame_material: StandardMaterial3D
static var _glass_material: ShaderMaterial
static var _bulb_material: ShaderMaterial
static var _hit_shapes: Array[Dictionary] = []
static var _metal_hit_shapes: Array[Dictionary] = []
static var _intact_triangles: int = 0

static func build() -> Dictionary:
	_prepare_shared()
	var head := Node3D.new()
	head.name = "BelliniGlassLantern"
	head.position = HEAD_ORIGIN
	var frame := _mesh_instance("PaintedMetalAndBronze", _frame_mesh, _frame_material)
	head.add_child(frame)
	var glass := _mesh_instance("ThickGlassPanes", _glass_mesh, _glass_material)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(glass)
	var broken_glass := _mesh_instance("BrokenGlassInFrame", _broken_glass_mesh, _glass_material)
	broken_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	broken_glass.visible = false
	head.add_child(broken_glass)
	var bulb := _mesh_instance("BulbAndFilament", _bulb_mesh, _bulb_material)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(bulb)
	var light_anchor := Node3D.new()
	light_anchor.name = "LightAnchor"
	light_anchor.position = LIGHT_LOCAL_POSITION
	head.add_child(light_anchor)
	var result: Dictionary = {
		"root": head, "frame": frame, "glass": glass, "broken_glass": broken_glass,
		"bulb": bulb, "light_anchor": light_anchor,
		"hit_shapes": _hit_shapes, "metal_hit_shapes": _metal_hit_shapes,
		"triangle_count": _intact_triangles,
		"head_origin": HEAD_ORIGIN,
	}
	set_power(result, 0.0)
	return result

static func set_power(bundle: Dictionary, power: float, broken: bool = false) -> void:
	var bulb_value: Variant = bundle.get("bulb")
	if is_instance_valid(bulb_value):
		var bulb := bulb_value as MeshInstance3D
		bulb.set_instance_shader_parameter("lamp_power", 0.0 if broken else clampf(power, 0.0, 1.0))
		bulb.set_instance_shader_parameter("lamp_intact", 0.0 if broken else 1.0)
	var glass_value: Variant = bundle.get("glass")
	if is_instance_valid(glass_value):
		glass_value.visible = not broken
	var broken_value: Variant = bundle.get("broken_glass")
	if is_instance_valid(broken_value):
		broken_value.visible = broken

static func _prepare_shared() -> void:
	if _frame_mesh != null:
		return
	_frame_material = StandardMaterial3D.new()
	_frame_material.vertex_color_use_as_albedo = true
	_frame_material.roughness = 0.32
	_frame_material.metallic = 0.55
	_frame_material.metallic_specular = 0.62
	_glass_material = ShaderMaterial.new()
	var glass_shader := Shader.new()
	glass_shader.code = """shader_type spatial;
render_mode cull_disabled, depth_draw_never;
void fragment() {
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim = pow(1.0 - facing, 3.0);
	ALBEDO = vec3(0.61, 0.79, 0.81);
	METALLIC = 0.0;
	ROUGHNESS = 0.10;
	SPECULAR = 0.82;
	ALPHA = mix(0.055, 0.20, COLOR.a) + rim * 0.34;
}
"""
	_glass_material.shader = glass_shader
	_bulb_material = _make_bulb_material()
	var body := _bucket()
	var iron := Color(0.085, 0.115, 0.13)
	var bronze := Color(0.39, 0.265, 0.12)
	var dark_bronze := Color(0.25, 0.165, 0.08)
	# Gently pitched hood and a fine warm rim, rather than an emissive dome.
	_frustum(body, -0.31, -0.268, 0.235, 0.31, iron)
	_box(body, Vector3(0.0, -0.265, 0.0), Vector3(0.645, 0.032, 0.645), bronze)
	_frustum(body, 0.264, 0.397, 0.398, 0.155, iron)
	_box(body, Vector3(0.0, 0.263, 0.0), Vector3(0.815, 0.026, 0.815), bronze)
	_box(body, Vector3(0.0, 0.409, 0.0), Vector3(0.32, 0.03, 0.32), iron)
	_cylinder(body, Vector3(0.0, 0.449, 0.0), 0.045, 0.065, 8, dark_bronze)
	# Four narrow corner posts leave the glass and bulb visible from every side.
	for x: float in [-0.293, 0.293]:
		for z: float in [-0.293, 0.293]:
			_box(body, Vector3(x, -0.001, z), Vector3(0.037, 0.52, 0.037), iron)
	# A short socket hangs beneath the hood. It remains when the bulb is off.
	_cylinder(body, Vector3(0.0, 0.174, 0.0), 0.064, 0.116, 8, dark_bronze)
	_cylinder(body, Vector3(0.0, 0.115, 0.0), 0.071, 0.018, 8, bronze)
	_frame_mesh = _finish(body)
	_metal_frustum(-0.31, -0.268, 0.235, 0.31)
	_metal_box(Vector3(0.0, -0.265, 0.0), Vector3(0.645, 0.032, 0.645))
	_metal_frustum(0.264, 0.397, 0.398, 0.155)
	_metal_box(Vector3(0.0, 0.263, 0.0), Vector3(0.815, 0.026, 0.815))
	_metal_box(Vector3(0.0, 0.409, 0.0), Vector3(0.32, 0.03, 0.32))
	_metal_cylinder(Vector3(0.0, 0.449, 0.0), 0.045, 0.065)
	for x: float in [-0.293, 0.293]:
		for z: float in [-0.293, 0.293]:
			_metal_box(Vector3(x, -0.001, z), Vector3(0.037, 0.52, 0.037))
	_metal_cylinder(Vector3(0.0, 0.174, 0.0), 0.064, 0.116)
	_metal_cylinder(Vector3(0.0, 0.115, 0.0), 0.071, 0.018)
	var panes := _bucket()
	var remnants := _bucket()
	# Physical edge faces are more strongly tinted than the large clear faces.
	for side: int in 4:
		var axis_basis := Basis(Vector3.UP, float(side) * PI * 0.5)
		_glass_pane(panes, axis_basis)
		_glass_remnant(remnants, axis_basis, side)
		var shape := BoxShape3D.new()
		shape.size = Vector3(GLASS_HALF_WIDTH * 2.0, GLASS_HEIGHT, GLASS_THICKNESS)
		_hit_shapes.append({"shape": shape, "transform": Transform3D(axis_basis, axis_basis * Vector3(0.0, 0.0, GLASS_HALF_WIDTH))})
	_glass_mesh = _finish(panes)
	_broken_glass_mesh = _finish(remnants)
	var bulb_parts := _bucket()
	_ellipsoid(bulb_parts, Vector3(0.0, -0.023, 0.0), Vector3(0.076, 0.137, 0.076), 8, 6, Color(0.73, 0.69, 0.54, 0.36))
	# A small vertical luminous core reads as a filament through the clear panes.
	_box(bulb_parts, Vector3(0.0, -0.028, -0.077), Vector3(0.025, 0.132, 0.005), Color(1.0, 0.63, 0.20, 1.0))
	_box(bulb_parts, Vector3(0.0, -0.028, 0.077), Vector3(0.025, 0.132, 0.005), Color(1.0, 0.63, 0.20, 1.0))
	_bulb_mesh = _finish(bulb_parts)
	_intact_triangles = int((body["i"].size() + panes["i"].size() + bulb_parts["i"].size()) / 3)

static func _make_bulb_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
instance uniform float lamp_power = 0.0;
instance uniform float lamp_intact = 1.0;
void fragment() {
	ALBEDO = COLOR.rgb * mix(0.16, 1.0, lamp_intact);
	ROUGHNESS = 0.28;
	SPECULAR = 0.55;
	EMISSION = vec3(1.0, 0.53, 0.18) * lamp_power * mix(1.1, 4.0, COLOR.a);
}
"""
	material.shader = shader
	return material

static func _mesh_instance(label: String, mesh: ArrayMesh, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = mesh
	result.material_override = material
	return result

static func _bucket() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}

static func _finish(data: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["v"]
	arrays[Mesh.ARRAY_NORMAL] = data["n"]
	arrays[Mesh.ARRAY_COLOR] = data["c"]
	arrays[Mesh.ARRAY_INDEX] = data["i"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _quad(data: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	var start: int = data["v"].size()
	for point: Vector3 in [a, b, c, d]:
		data["v"].append(point)
		data["n"].append(normal)
		data["c"].append(color)
	var indices: Array = [0, 1, 2, 0, 2, 3] if (b - a).cross(c - a).dot(normal) < 0.0 else [0, 2, 1, 0, 3, 2]
	for index: int in indices:
		data["i"].append(start + index)

static func _triangle(data: Dictionary, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	var start: int = data["v"].size()
	for point: Vector3 in [a, b, c]:
		data["v"].append(point)
		data["n"].append(normal)
		data["c"].append(color)
	data["i"].append_array(PackedInt32Array([start, start + 1, start + 2] if (b - a).cross(c - a).dot(normal) < 0.0 else [start, start + 2, start + 1]))

static func _box(data: Dictionary, center: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY, edge_glass: bool = false) -> void:
	var h := size * 0.5
	var points: Array[Vector3] = []
	for point: Vector3 in [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]:
		points.append(center + basis * point)
	var faces: Array = [[0, 1, 2, 3, Vector3.BACK], [4, 5, 6, 7, Vector3.FORWARD], [0, 4, 7, 3, Vector3.LEFT], [1, 5, 6, 2, Vector3.RIGHT], [0, 1, 5, 4, Vector3.DOWN], [3, 2, 6, 7, Vector3.UP]]
	# Z face normals use actual coordinate signs (Godot FORWARD is negative Z).
	faces[0][4] = Vector3.FORWARD
	faces[1][4] = Vector3.BACK
	for face_index: int in faces.size():
		var face: Array = faces[face_index]
		var tint := color
		if edge_glass:
			tint.a = 0.0 if face_index < 2 else 1.0
		_quad(data, points[face[0]], points[face[1]], points[face[2]], points[face[3]], basis * face[4], tint)

static func _frustum(data: Dictionary, low: float, high: float, bottom: float, top: float, color: Color) -> void:
	for side: int in 4:
		var basis := Basis(Vector3.UP, float(side) * PI * 0.5)
		var a := basis * Vector3(-bottom, low, bottom)
		var b := basis * Vector3(bottom, low, bottom)
		var c := basis * Vector3(top, high, top)
		var d := basis * Vector3(-top, high, top)
		var normal := basis * Vector3(0.0, bottom - top, high - low).normalized()
		_quad(data, a, b, c, d, normal, color)
	_quad(data, Vector3(-top, high, -top), Vector3(top, high, -top), Vector3(top, high, top), Vector3(-top, high, top), Vector3.UP, color)
	_quad(data, Vector3(-bottom, low, -bottom), Vector3(bottom, low, -bottom), Vector3(bottom, low, bottom), Vector3(-bottom, low, bottom), Vector3.DOWN, color)

static func _cylinder(data: Dictionary, center: Vector3, radius: float, height: float, segments: int, color: Color) -> void:
	for segment: int in segments:
		var a := float(segment) * TAU / float(segments)
		var b := float(segment + 1) * TAU / float(segments)
		var pa := Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		var pb := Vector3(cos(b) * radius, 0.0, sin(b) * radius)
		var up := Vector3.UP * height * 0.5
		_quad(data, center + pa - up, center + pb - up, center + pb + up, center + pa + up, (pa + pb).normalized(), color)
		_triangle(data, center + up, center + pa + up, center + pb + up, Vector3.UP, color)
		_triangle(data, center - up, center + pa - up, center + pb - up, Vector3.DOWN, color)

static func _glass_pane(data: Dictionary, basis: Basis) -> void:
	_box(data, basis * Vector3(0.0, 0.0, GLASS_HALF_WIDTH), Vector3(GLASS_HALF_WIDTH * 2.0, GLASS_HEIGHT, GLASS_THICKNESS), Color.WHITE, basis, true)

static func _metal_box(center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	_metal_hit_shapes.append({"shape": shape, "transform": Transform3D(Basis.IDENTITY, center)})

static func _metal_cylinder(center: Vector3, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_metal_hit_shapes.append({"shape": shape, "transform": Transform3D(Basis.IDENTITY, center)})

static func _metal_frustum(low: float, high: float, bottom: float, top: float) -> void:
	var points := PackedVector3Array()
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			points.append(Vector3(x * bottom, low, z * bottom))
			points.append(Vector3(x * top, high, z * top))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_metal_hit_shapes.append({"shape": shape, "transform": Transform3D.IDENTITY})

static func _glass_remnant(data: Dictionary, basis: Basis, side: int) -> void:
	var low := -GLASS_HEIGHT * 0.5
	var tip_height := 0.045 + float(side % 2) * 0.018
	var z := GLASS_HALF_WIDTH
	var normal := basis * Vector3.BACK
	_triangle(data, basis * Vector3(-0.262, low, z), basis * Vector3(-0.17, low, z), basis * Vector3(-0.246, low + tip_height, z), normal, Color(1, 1, 1, 0.7))
	_triangle(data, basis * Vector3(0.168, low, z), basis * Vector3(0.265, low, z), basis * Vector3(0.256, low + tip_height * 0.6, z), normal, Color(1, 1, 1, 0.7))

static func _ellipsoid(data: Dictionary, center: Vector3, radius: Vector3, segments: int, rings: int, color: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = segments
	sphere.rings = rings
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var offset: int = data["v"].size()
	for index: int in vertices.size():
		data["v"].append(center + vertices[index] * radius)
		data["n"].append((normals[index] / radius).normalized())
		data["c"].append(color)
	for index: int in indices:
		data["i"].append(offset + index)
