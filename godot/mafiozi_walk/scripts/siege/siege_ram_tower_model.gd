extends Node3D
## DSH_TOWER: procedural siege ram tower.
##
## The whole machine is built from a handful of destruction parts.  Every part
## owns one node with its own merged mesh, so a broken wheel / wall / roof can be
## hidden without touching the rest, and every timber still costs one draw call
## per material.  Nothing here is loaded from disk: the castle map is procedural
## too, and the two must not drift apart in style.

const WOOD := "wood"
const IRON := "iron"
const STEEL := "steel"
const ROPE := "rope"
const CLOTH := "cloth"
const PAINT := "paint"
const GOLD := "gold"

const WHEEL_R := 0.78
const WHEEL_X := 2.28
const WHEEL_Z: Array[float] = [-2.45, -0.05, 2.35]
const GALLERY_TOP := 4.65
const UPPER_TOP := 8.75
const PLATFORM_Y := 8.85
const PARAPET_TOP := 9.60
const ROOF_EAVE := 11.28
const ROOF_RIDGE := 13.05
const FRONT_Z := -2.78
const REAR_Z := 2.78

const WOOD_TONES: Array[Color] = [
	Color(0.238, 0.158, 0.096), Color(0.268, 0.180, 0.110),
	Color(0.214, 0.140, 0.084), Color(0.286, 0.194, 0.120),
	Color(0.198, 0.128, 0.076), Color(0.254, 0.170, 0.104),
]
const DARK_TONES: Array[Color] = [
	Color(0.160, 0.104, 0.062), Color(0.178, 0.116, 0.070),
	Color(0.146, 0.094, 0.056),
]
const IRON_COLOR := Color(0.176, 0.184, 0.196)
const STEEL_COLOR := Color(0.575, 0.585, 0.600)
const ROPE_COLOR := Color(0.505, 0.415, 0.255)
const CLOTH_COLOR := Color(0.545, 0.115, 0.095)
const CLOTH_BLUE := Color(0.125, 0.190, 0.315)
const GOLD_COLOR := Color(0.700, 0.535, 0.215)
const MUD_COLOR := Color(0.240, 0.205, 0.150)

var _materials: Dictionary = {}
var _parts: Dictionary = {}
var _surfaces: Dictionary = {}
var _active_part := ""
var _collision: Array[Dictionary] = []
var _anchors: Dictionary = {}
var _wheels: Array[Node3D] = []
var _wheel_radius := WHEEL_R
var _ram_pivot: Node3D = null
var _built := false
var _stats := {"boxes": 0, "tubes": 0, "parts": 0}

func build() -> Dictionary:
	if _built:
		return _result()
	_build_materials()
	_build_chassis()
	_build_wheels()
	_build_gallery()
	_build_ram()
	_build_winch()
	_build_upper_body()
	_build_platform()
	_build_roof()
	_build_ladder()
	_build_stores()
	_build_banners()
	_built = true
	_stats["parts"] = _parts.size()
	return _result()

func _result() -> Dictionary:
	return {"ok": true, "part_count": _parts.size(), "parts": _parts,
		"collision": _collision, "anchors": _anchors, "wheels": _wheels,
		"wheel_radius": _wheel_radius, "ram_pivot": _ram_pivot, "stats": _stats}

# ------------------------------------------------------------------ materials
func _build_materials() -> void:
	_materials[WOOD] = _wood_material(1.0, 0.90)
	_materials[IRON] = _metal_material(IRON_COLOR, 0.55, 0.62)
	_materials[STEEL] = _metal_material(Color(0.565, 0.575, 0.590), 0.55, 0.46)
	_materials[GOLD] = _metal_material(GOLD_COLOR, 0.70, 0.40)
	_materials[ROPE] = _flat_material(ROPE_COLOR, 0.98, 0.0)
	_materials[CLOTH] = _flat_material(CLOTH_COLOR, 0.94, 0.0)
	_materials[PAINT] = _flat_material(CLOTH_BLUE, 0.88, 0.0)

func _wood_material(brightness: float, roughness: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float brightness = 1.0;
uniform float rough = 0.9;
uniform float specular_amount = 0.045;
varying vec3 wood_local;
void vertex() {
	wood_local = VERTEX;
}
void fragment() {
	vec3 c = COLOR.rgb * brightness;
	float grain = sin(wood_local.y * 37.0 + sin(wood_local.x * 6.0) * 3.0);
	float fine = sin(wood_local.y * 149.0 + wood_local.z * 11.0);
	c *= 0.875 + 0.085 * grain + 0.038 * fine;
	c *= 0.955 + 0.070 * sin(wood_local.x * 3.1 + wood_local.z * 8.0);
	ALBEDO = clamp(c, vec3(0.0), vec3(1.0));
	ROUGHNESS = rough;
	SPECULAR = specular_amount;
}
"""
	material.shader = shader
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("rough", roughness)
	return material

func _metal_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _flat_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

# ------------------------------------------------------------------ part plumbing
func _part(id: String, node: Node3D = null) -> void:
	_active_part = id
	_surfaces = {}
	var root: Node3D = node if node != null else Node3D.new()
	root.name = "Part_" + id
	if node == null:
		add_child(root)
	_parts[id] = root

func _finish() -> void:
	if _active_part.is_empty():
		return
	var root: Node3D = _parts[_active_part]
	if root == null:
		_active_part = ""
		return
	var mesh := ArrayMesh.new()
	for key: String in _surfaces.keys():
		var st: SurfaceTool = _surfaces[key]
		st.commit(mesh)
		var index := mesh.get_surface_count() - 1
		mesh.surface_set_material(index, _materials.get(key, _materials[WOOD]))
	if mesh.get_surface_count() > 0:
		var view := MeshInstance3D.new()
		view.name = "Mesh"
		view.mesh = mesh
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(view)
	_surfaces = {}
	_active_part = ""

func _st(key: String) -> SurfaceTool:
	if not _surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = st
	return _surfaces[key]

func _vertex(st: SurfaceTool, p: Vector3, n: Vector3, c: Color, uv: Vector2 = Vector2.ZERO) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)

func _tri(key: String, a: Vector3, b: Vector3, c: Vector3, color: Color, normal: Vector3) -> void:
	var st := _st(key)
	# Godot front faces are CLOCKWISE; the geometric normal must point opposite
	# the outward normal so the face is lit from the right side.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var tmp := b
		b = c
		c = tmp
	_vertex(st, a, normal, color)
	_vertex(st, b, normal, color)
	_vertex(st, c, normal, color)

func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, normal: Vector3) -> void:
	var st := _st(key)
	var gn := (b - a).cross(c - a) + (c - a).cross(d - a)
	if gn.dot(normal) > 0.0:
		var tmp := b
		b = d
		d = tmp
	_vertex(st, a, normal, color, Vector2(0.0, 0.0))
	_vertex(st, b, normal, color, Vector2(0.0, 1.0))
	_vertex(st, c, normal, color, Vector2(1.0, 1.0))
	_vertex(st, a, normal, color, Vector2(0.0, 0.0))
	_vertex(st, c, normal, color, Vector2(1.0, 1.0))
	_vertex(st, d, normal, color, Vector2(1.0, 0.0))

func _box(key: String, center: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	if hx <= 0.0001 or hy <= 0.0001 or hz <= 0.0001:
		return
	var p: Array[Vector3] = [
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz),
		Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz),
	]
	var faces: Array = [
		[1, 5, 6, 2, Vector3(1, 0, 0), 0.98],
		[0, 4, 7, 3, Vector3(-1, 0, 0), 0.96],
		[3, 7, 6, 2, Vector3(0, 1, 0), 1.08],
		[0, 1, 5, 4, Vector3(0, -1, 0), 0.76],
		[4, 5, 6, 7, Vector3(0, 0, 1), 1.02],
		[0, 3, 2, 1, Vector3(0, 0, -1), 0.94],
	]
	for f: Array in faces:
		var face_normal: Vector3 = f[4]
		var n: Vector3 = basis * face_normal
		var shade: float = f[5]
		_quad(key, center + basis * p[f[0]], center + basis * p[f[1]],
			center + basis * p[f[2]], center + basis * p[f[3]], color * shade, n)
	_stats["boxes"] = int(_stats["boxes"]) + 1

func _tube(key: String, from: Vector3, to: Vector3, r0: float, r1: float, sides: int, color: Color,
		caps: bool = true) -> void:
	var axis := to - from
	var length := axis.length()
	if length < 0.0005 or sides < 3:
		return
	var up := axis / length
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x_axis := ref.cross(up).normalized()
	var z_axis := x_axis.cross(up).normalized()
	for i: int in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := x_axis * cos(a0) + z_axis * sin(a0)
		var d1 := x_axis * cos(a1) + z_axis * sin(a1)
		_quad(key, from + d0 * r0, to + d0 * r1, to + d1 * r1, from + d1 * r0,
			color, (d0 + d1).normalized())
	if caps:
		for i: int in sides:
			var a0 := TAU * float(i) / float(sides)
			var a1 := TAU * float(i + 1) / float(sides)
			var d0 := x_axis * cos(a0) + z_axis * sin(a0)
			var d1 := x_axis * cos(a1) + z_axis * sin(a1)
			_tri(key, from, from + d0 * r0, from + d1 * r0, color * 0.90, -up)
			_tri(key, to, to + d0 * r1, to + d1 * r1, color * 1.04, up)
	_stats["tubes"] = int(_stats["tubes"]) + 1

func _torus(key: String, center: Vector3, axis: Vector3, ring_radius: float, tube_radius: float,
		color: Color, ring_segments: int = 16, tube_segments: int = 5) -> void:
	var up := axis.normalized()
	if up.length_squared() < 0.5:
		up = Vector3.UP
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x_axis := ref.cross(up).normalized()
	var z_axis := x_axis.cross(up).normalized()
	for i: int in ring_segments:
		var a0 := TAU * float(i) / float(ring_segments)
		var a1 := TAU * float(i + 1) / float(ring_segments)
		var c0 := x_axis * cos(a0) + z_axis * sin(a0)
		var c1 := x_axis * cos(a1) + z_axis * sin(a1)
		for j: int in tube_segments:
			var b0 := TAU * float(j) / float(tube_segments)
			var b1 := TAU * float(j + 1) / float(tube_segments)
			var p00 := center + c0 * ring_radius + (c0 * cos(b0) + up * sin(b0)) * tube_radius
			var p01 := center + c0 * ring_radius + (c0 * cos(b1) + up * sin(b1)) * tube_radius
			var p10 := center + c1 * ring_radius + (c1 * cos(b0) + up * sin(b0)) * tube_radius
			var p11 := center + c1 * ring_radius + (c1 * cos(b1) + up * sin(b1)) * tube_radius
			_quad(key, p00, p10, p11, p01, color, (p00 - center).normalized())
	_stats["tubes"] = int(_stats["tubes"]) + 1

# ------------------------------------------------------------------ colours
func _wood_tone(seed_value: int) -> Color:
	var index := absi(seed_value) % WOOD_TONES.size()
	var c := WOOD_TONES[index]
	return c.lerp(Color(0.27, 0.24, 0.19), 0.10)

func _dark_tone(seed_value: int) -> Color:
	return DARK_TONES[absi(seed_value) % DARK_TONES.size()]

func _jitter(color: Color, seed_value: int, amount: float = 0.035) -> Color:
	var k: float = sin(float(seed_value) * 12.9898) * 43758.5453
	var whole: float = floor(k)
	var f: float = (k - whole) * 2.0 - 1.0
	return Color(clampf(color.r + f * amount, 0.0, 1.0),
		clampf(color.g + f * amount * 0.85, 0.0, 1.0),
		clampf(color.b + f * amount * 0.7, 0.0, 1.0))

# ------------------------------------------------------------------ chassis
func _build_chassis() -> void:
	_part("chassis")
	# Two long oak bed beams and the axles they sit on.
	for side: float in [-1.0, 1.0]:
		_box(WOOD, Vector3(side * 1.95, 1.18, 0.0), Vector3(0.38, 0.40, 6.25), _wood_tone(3))
		_box(WOOD, Vector3(side * 1.95, 1.42, 0.0), Vector3(0.30, 0.14, 6.05), _wood_tone(5))
		for z: float in WHEEL_Z:
			_box(IRON, Vector3(side * 2.02, 0.80, z), Vector3(0.16, 0.16, 0.9), IRON_COLOR * 0.9)
	for z: float in [WHEEL_Z[0], WHEEL_Z[2]]:
		_box(WOOD, Vector3(0.0, 1.02, z), Vector3(4.5, 0.34, 0.36), _wood_tone(1))
		_box(WOOD, Vector3(0.0, 1.32, z), Vector3(4.7, 0.20, 0.30), _wood_tone(4))
	# Cross bearers under the gallery floor.
	for z: float in [-1.55, 0.35, 2.15]:
		_box(WOOD, Vector3(0.0, 1.34, z), Vector3(4.35, 0.26, 0.30), _wood_tone(2))
	# Deck floor, boards running across the machine.
	var floor_y := 1.52
	var boards := 18
	for i: int in boards:
		var z := -2.62 + (float(i) + 0.5) * (5.24 / float(boards))
		var tone := _jitter(_wood_tone(i + 2), i, 0.028)
		_box(WOOD, Vector3(0.0, floor_y, z), Vector3(3.98, 0.14, 5.24 / float(boards) - 0.012), tone)
	# Iron corner brackets and bolt heads.
	for side: float in [-1.0, 1.0]:
		for z: float in [-2.6, 2.6]:
			_box(IRON, Vector3(side * 2.10, 1.30, z), Vector3(0.10, 0.55, 0.55), IRON_COLOR)
			for k: int in 3:
				_box(IRON, Vector3(side * 2.17, 1.14 + float(k) * 0.14, z), Vector3(0.05, 0.05, 0.05), IRON_COLOR * 1.1)
	# Tow bar / push beam at the rear: where the crew puts its hands.
	_box(WOOD, Vector3(0.0, 1.02, 3.34), Vector3(0.30, 0.24, 1.30), _wood_tone(0))
	_box(WOOD, Vector3(0.0, 1.02, 4.02), Vector3(3.0, 0.22, 0.24), _wood_tone(3))
	for side: float in [-1.0, 1.0]:
		_box(IRON, Vector3(side * 1.45, 1.02, 4.02), Vector3(0.16, 0.30, 0.30), IRON_COLOR)
		_box(ROPE, Vector3(side * 1.08, 1.09, 3.62), Vector3(0.62, 0.07, 0.07), ROPE_COLOR,
			Basis(Vector3.UP, side * 0.32))
		# Uprights and grab rails: an obvious place for the crew.
		_box(WOOD, Vector3(side * 1.34, 1.82, 4.02), Vector3(0.20, 1.62, 0.20), _dark_tone(2))
		_box(WOOD, Vector3(side * 1.34, 2.58, 4.02), Vector3(0.26, 0.20, 0.26), _dark_tone(4))
		_box(IRON, Vector3(side * 1.34, 2.38, 3.90), Vector3(0.34, 0.10, 0.10), IRON_COLOR)
		_box(WOOD, Vector3(side * 0.76, 1.72, 3.92), Vector3(0.14, 0.14, 0.86), _dark_tone(3),
			Basis(Vector3.RIGHT, 0.55))
	_box(WOOD, Vector3(0.0, 2.56, 4.02), Vector3(2.94, 0.20, 0.20), _wood_tone(4))
	_box(ROPE, Vector3(0.0, 2.56, 4.02), Vector3(1.10, 0.26, 0.26), ROPE_COLOR)
	# A bucket and a spare mallet hanging from the frame.
	_tube(WOOD, Vector3(1.34, 2.02, 3.86), Vector3(1.34, 1.74, 3.86), 0.16, 0.12, 9, _dark_tone(1), true)
	_torus(IRON, Vector3(1.34, 2.03, 3.86), Vector3(0.0, 0.0, 1.0), 0.16, 0.018, IRON_COLOR, 10, 4)
	_box(WOOD, Vector3(-1.34, 2.08, 3.86), Vector3(0.06, 0.44, 0.07), _wood_tone(2))
	_box(WOOD, Vector3(-1.34, 2.30, 3.86), Vector3(0.08, 0.14, 0.22), _dark_tone(4))
	_finish()
	_anchors["push_zone"] = Vector3(0.0, 0.0, 4.05)
	_collision.append({"part": "chassis", "position": Vector3(0.0, 1.10, 0.0),
		"size": Vector3(4.55, 0.95, 5.80), "rotation": Vector3.ZERO})
	# The push frame is solid: the crew leans on it instead of walking through it.
	_collision.append({"part": "chassis", "position": Vector3(0.0, 1.86, 4.04),
		"size": Vector3(2.86, 1.72, 0.30), "rotation": Vector3.ZERO})

# ------------------------------------------------------------------ wheels
func _build_wheels() -> void:
	for index: int in 6:
		var side: float = -1.0 if index < 3 else 1.0
		var slot := index % 3
		var z: float = WHEEL_Z[slot]
		var pivot := Node3D.new()
		pivot.name = "Wheel%d" % index
		pivot.position = Vector3(side * WHEEL_X, WHEEL_R, z)
		add_child(pivot)
		_wheels.append(pivot)
		_part("wheel_%d" % index, pivot)
		_build_wheel_mesh(index, side)
		_finish()
		_collision.append({"part": "wheel_%d" % index,
			"position": pivot.position + Vector3(0.0, 0.08, 0.0),
			"size": Vector3(0.48, 1.48, 1.48), "rotation": Vector3.ZERO})

func _build_wheel_mesh(index: int, side: float) -> void:
	var w := 0.36
	# Open wheel: iron tyre, wooden felloe ring, twelve spokes and a banded hub.
	# No solid disc, so the wheel reads as a wheel from the side and shows daylight
	# between the spokes.
	_torus(IRON, Vector3.ZERO, Vector3.RIGHT, WHEEL_R - 0.025, 0.075, IRON_COLOR * 0.95, 22, 5)
	_torus(WOOD, Vector3.ZERO, Vector3.RIGHT, WHEEL_R - 0.135, 0.085, _wood_tone(index + 2), 22, 5)
	for offset: float in [-0.10, 0.10]:
		_torus(WOOD, Vector3(offset, 0.0, 0.0), Vector3.RIGHT, WHEEL_R - 0.135, 0.052,
			_dark_tone(index + 1), 20, 4)
	# Twelve spokes, darker than the rim.
	for spoke: int in 12:
		var angle := TAU * float(spoke) / 12.0 + 0.11 * float(index)
		var dir := Vector3(0.0, cos(angle), sin(angle))
		var center := dir * (WHEEL_R * 0.53)
		_box(WOOD, center, Vector3(w * 0.60, WHEEL_R * 0.84, 0.070),
			_jitter(_dark_tone(index + spoke), spoke + 5, 0.045), Basis(Vector3.RIGHT, angle))
	# Hub: oak core with two iron bands and a gold retaining ring.
	_tube(WOOD, Vector3(-w * 0.55, 0.0, 0.0), Vector3(w * 0.55, 0.0, 0.0), 0.20, 0.20, 12, _wood_tone(index + 3), true)
	for x: float in [-w * 0.40, 0.0, w * 0.40]:
		_torus(IRON, Vector3(x, 0.0, 0.0), Vector3.RIGHT, 0.205, 0.028, IRON_COLOR, 12, 4)
	_tube(IRON, Vector3(side * w * 0.56, 0.0, 0.0), Vector3(side * w * 0.62, 0.0, 0.0), 0.11, 0.09, 10, IRON_COLOR, true)
	_torus(GOLD, Vector3(side * w * 0.58, 0.0, 0.0), Vector3.RIGHT, 0.125, 0.022, GOLD_COLOR, 12, 4)
	# Tyre nails and a few mud flecks on the rim.
	for nail: int in 10:
		var angle := TAU * float(nail) / 10.0 + 0.21
		var at := Vector3(side * w * 0.32, cos(angle) * (WHEEL_R - 0.02), sin(angle) * (WHEEL_R - 0.02))
		_box(IRON, at, Vector3(0.055, 0.065, 0.065), IRON_COLOR * 1.15)
	for i: int in 3:
		var angle := 0.8 + float(i) * 1.8
		_box(WOOD, Vector3(side * w * 0.30, cos(angle) * (WHEEL_R - 0.15), sin(angle) * (WHEEL_R - 0.15)),
			Vector3(0.12, 0.18, 0.18), MUD_COLOR * 0.8)

# ------------------------------------------------------------------ lower gallery
func _build_gallery() -> void:
	_build_side_frame("frame_left", -1.0)
	_build_side_frame("frame_right", 1.0)
	_build_front_frame()
	_build_rear_wall()
	# Gallery roof: a heavy shed roof falling toward the front, with a fascia
	# and brackets so it reads as a roof rather than a loose plank.
	_part("gallery_roof")
	var roof_y0 := GALLERY_TOP - 0.10
	for i: int in 14:
		var z := FRONT_Z - 0.40 + (float(i) + 0.5) * (6.42 / 14.0)
		var tone := _jitter(_wood_tone(i + 6), i + 40, 0.040)
		_box(WOOD, Vector3(0.0, roof_y0 + 0.11 + float(i) * 0.031, z),
			Vector3(5.02, 0.14, 6.42 / 14.0 - 0.020), tone,
			Basis(Vector3.RIGHT, -0.145))
		_box(WOOD, Vector3(0.0, roof_y0 + 0.03 + float(i) * 0.031, z + 0.20),
			Vector3(5.00, 0.05, 0.06), DARK_TONES[2], Basis(Vector3.RIGHT, -0.145))
	for side: float in [-1.0, 1.0]:
		# Barge board along each side of the shed roof.
		_box(WOOD, Vector3(side * 2.56, GALLERY_TOP + 0.22, 0.0), Vector3(0.18, 0.34, 6.52), _dark_tone(1),
			Basis(Vector3.RIGHT, -0.145))
		_box(IRON, Vector3(side * 2.60, GALLERY_TOP + 0.30, 0.0), Vector3(0.05, 0.08, 6.20), IRON_COLOR)
		# Corner brackets under the eave.
		for z: float in [FRONT_Z + 0.25, REAR_Z - 0.25]:
			_box(WOOD, Vector3(side * 2.34, GALLERY_TOP - 0.02, z), Vector3(0.16, 0.16, 0.82), _dark_tone(3),
				Basis(Vector3.RIGHT, -0.45))
			_box(IRON, Vector3(side * 2.42, GALLERY_TOP - 0.10, z), Vector3(0.20, 0.08, 0.08), IRON_COLOR)
	# Fascia boards front and rear.
	_box(WOOD, Vector3(0.0, GALLERY_TOP - 0.02, FRONT_Z - 0.30), Vector3(5.16, 0.40, 0.18), _dark_tone(2))
	_box(WOOD, Vector3(0.0, GALLERY_TOP + 0.10, REAR_Z + 0.30), Vector3(5.16, 0.34, 0.18), _dark_tone(3))
	_box(WOOD, Vector3(0.0, GALLERY_TOP - 0.20, FRONT_Z - 0.20), Vector3(4.90, 0.16, 0.16), _dark_tone(4))
	# Corbels under the front eave.
	for i: int in 5:
		var x := -2.0 + float(i) * 1.0
		_box(WOOD, Vector3(x, GALLERY_TOP - 0.24, FRONT_Z - 0.24), Vector3(0.18, 0.30, 0.60), _dark_tone(i + 1),
			Basis(Vector3.RIGHT, -0.45))
	for i: int in 5:
		_box(IRON, Vector3(-1.9 + float(i) * 0.95, GALLERY_TOP - 0.02, FRONT_Z - 0.39), Vector3(0.10, 0.10, 0.05), IRON_COLOR * 1.1)
	_finish()
	_collision.append({"part": "gallery_roof", "position": Vector3(0.0, GALLERY_TOP + 0.12, 0.0),
		"size": Vector3(5.3, 0.32, 6.5), "rotation": Vector3(-0.14, 0.0, 0.0)})

func _build_side_frame(id: String, side: float) -> void:
	_part(id)
	var x := side * 2.10
	# Dark backing panel: the gaps between boards read as deep shadow, not sky.
	_box(WOOD, Vector3(x - side * 0.09, 3.05, 0.0), Vector3(0.07, 2.90, 5.40), DARK_TONES[1] * 0.7)
	# Corner posts, standing proud of the planking.
	for z: float in [FRONT_Z + 0.10, REAR_Z - 0.10]:
		_box(WOOD, Vector3(x + side * 0.02, (1.52 + GALLERY_TOP) * 0.5, z),
			Vector3(0.36, GALLERY_TOP - 1.46, 0.36), _dark_tone(int(z)))
		_box(IRON, Vector3(x + side * 0.20, 1.86, z), Vector3(0.07, 0.46, 0.46), IRON_COLOR)
		_box(IRON, Vector3(x + side * 0.20, 4.40, z), Vector3(0.07, 0.34, 0.40), IRON_COLOR)
	# Horizontal belts, also proud of the boards.
	for y: float in [1.90, 3.26, 4.44]:
		_box(WOOD, Vector3(x + side * 0.11, y, 0.0), Vector3(0.16, 0.24, 5.40), _dark_tone(int(y)))
	# Vertical boards between the posts.
	var boards := 15
	for i: int in boards:
		var z := FRONT_Z + 0.26 + (float(i) + 0.5) * (5.42 / float(boards))
		var tone := _jitter(_wood_tone(i + int(side) + 3), i + int(side) * 7, 0.042)
		_box(WOOD, Vector3(x + side * 0.06, 3.05, z), Vector3(0.14, 2.44, 5.42 / float(boards) - 0.030), tone)
		# A darker, mud-stained wainscot at the base.
		_box(WOOD, Vector3(x + side * 0.13, 1.69, z), Vector3(0.05, 0.34, 5.42 / float(boards) - 0.030),
			tone.lerp(MUD_COLOR, 0.42))
		# Shorter scarfed board above the belt.
		_box(WOOD, Vector3(x + side * 0.135, 3.94, z), Vector3(0.045, 0.72, 5.42 / float(boards) - 0.032),
			_jitter(tone, i + 33, 0.05))
	# Exposed cross bracing in both upper bays.
	for bay: int in 2:
		var z0 := FRONT_Z + 0.50 + float(bay) * 2.55
		var z1 := z0 + 2.42
		var length := sqrt(2.42 * 2.42 + 1.22 * 1.22)
		for sign_value: float in [-1.0, 1.0]:
			_box(WOOD, Vector3(x + side * 0.23, 3.78, (z0 + z1) * 0.5),
				Vector3(0.13, 0.17, length), _dark_tone(bay + (3 if sign_value < 0.0 else 5)),
				Basis(Vector3.RIGHT, sign_value * atan2(1.22, 2.42)))
	# Diagonal corner braces down to the chassis.
	for z: float in [FRONT_Z + 0.12, REAR_Z - 0.12]:
		var lean := 1.0 if z > 0.0 else -1.0
		_box(WOOD, Vector3(x + side * 0.19, 2.55, z), Vector3(0.12, 0.14, 1.10), _dark_tone(2),
			Basis(Vector3.RIGHT, -0.72 * lean))
	# Iron straps and rivets across the lower boards.
	for z: float in [-2.1, 1.9]:
		_box(IRON, Vector3(x + side * 0.22, 2.54, z), Vector3(0.06, 0.11, 1.55), IRON_COLOR)
		for n: int in 4:
			_box(IRON, Vector3(x + side * 0.26, 2.54, z - 0.55 + float(n) * 0.36), Vector3(0.04, 0.04, 0.04), IRON_COLOR * 1.15)
	# A shield hanging on the side wall.
	_build_shield(Vector3(x + side * 0.30, 2.92, -0.55), -side * PI * 0.5, 0.96)
	# A coiled rope and a mallet.
	_torus(ROPE, Vector3(x + side * 0.26, 2.10, 1.62), Vector3(side, 0.0, 0.0), 0.21, 0.038, ROPE_COLOR, 12, 4)
	_box(WOOD, Vector3(x + side * 0.27, 1.98, 2.05), Vector3(0.06, 0.52, 0.07), _wood_tone(2))
	_box(WOOD, Vector3(x + side * 0.27, 2.24, 2.05), Vector3(0.08, 0.16, 0.24), _dark_tone(4))
	_finish()

func _build_front_frame() -> void:
	_part("front_frame")
	var z := FRONT_Z
	# Two heavy posts and a lintel around the ram opening.
	for side: float in [-1.0, 1.0]:
		_box(WOOD, Vector3(side * 1.62, 3.05, z), Vector3(0.38, 3.05, 0.40), _dark_tone(1))
		_box(IRON, Vector3(side * 1.62, 2.10, z - 0.22), Vector3(0.30, 0.16, 0.08), IRON_COLOR)
		_box(IRON, Vector3(side * 1.62, 3.95, z - 0.22), Vector3(0.30, 0.16, 0.08), IRON_COLOR)
	_box(WOOD, Vector3(0.0, 4.18, z), Vector3(3.55, 0.48, 0.42), _dark_tone(2))
	_box(WOOD, Vector3(0.0, 4.48, z), Vector3(3.75, 0.20, 0.34), _wood_tone(5))
	# Planked infill above the opening.
	for i: int in 9:
		var x := -1.62 + (float(i) + 0.5) * (3.24 / 9.0)
		_box(WOOD, Vector3(x, 4.52, z - 0.02), Vector3(3.24 / 9.0 - 0.014, 0.44, 0.20),
			_jitter(_wood_tone(i + 7), i, 0.03))
	# Diagonal braces from the posts to the lintel.
	for side: float in [-1.0, 1.0]:
		_box(WOOD, Vector3(side * 1.10, 4.02, z + 0.14), Vector3(0.14, 1.02, 0.14), _dark_tone(3),
			Basis(Vector3.BACK, side * 0.58))
	# The opening arch, framed in iron.
	for side: float in [-1.0, 1.0]:
		_box(IRON, Vector3(side * 0.86, 2.95, z - 0.22), Vector3(0.12, 2.1, 0.08), IRON_COLOR)
		_torus(IRON, Vector3(side * 1.62, 2.62, z - 0.23), Vector3(0.0, 0.0, 1.0), 0.16, 0.035, IRON_COLOR, 10, 4)
		# Ram guide rollers under the log.
		_tube(IRON, Vector3(side * 0.62 - 0.16, 1.98, z - 0.02), Vector3(side * 0.62 + 0.16, 1.98, z - 0.02),
			0.20, 0.20, 10, IRON_COLOR, true)
		_box(WOOD, Vector3(side * 0.62, 1.62, z - 0.02), Vector3(0.18, 0.52, 0.26), _dark_tone(3))
	_box(IRON, Vector3(0.0, 3.98, z - 0.22), Vector3(1.86, 0.12, 0.08), IRON_COLOR)
	# Soot and scoring around the ram mouth.
	for i: int in 5:
		_box(WOOD, Vector3(-0.9 + float(i) * 0.45, 3.72 + float(i % 2) * 0.10, z - 0.24),
			Vector3(0.26 + float(i) * 0.08, 0.10, 0.02), Color(0.045, 0.038, 0.032))
	# A row of iron caltrops / spikes over the lintel against escalade.
	for i: int in 7:
		var x := -1.48 + float(i) * 0.493
		_tube(IRON, Vector3(x, 4.62, z - 0.30), Vector3(x, 4.92, z - 0.42), 0.035, 0.008, 5, IRON_COLOR, true)
	# A painted device on the lintel.
	_box(PAINT, Vector3(0.0, 4.22, z - 0.26), Vector3(0.92, 0.22, 0.05), CLOTH_BLUE)
	_box(GOLD, Vector3(0.0, 4.22, z - 0.30), Vector3(0.52, 0.10, 0.03), GOLD_COLOR)
	for side: float in [-1.0, 1.0]:
		_tube(GOLD, Vector3(side * 0.18, 4.22, z - 0.31), Vector3(side * 0.34, 4.30, z - 0.31),
			0.022, 0.010, 5, GOLD_COLOR, true)
	_finish()
	_collision.append({"part": "front_frame", "position": Vector3(-1.62, 3.05, z),
		"size": Vector3(0.42, 3.10, 0.44), "rotation": Vector3.ZERO})
	_collision.append({"part": "front_frame", "position": Vector3(1.62, 3.05, z),
		"size": Vector3(0.42, 3.10, 0.44), "rotation": Vector3.ZERO})
	_collision.append({"part": "front_frame", "position": Vector3(0.0, 4.28, z),
		"size": Vector3(3.6, 0.62, 0.44), "rotation": Vector3.ZERO})

func _build_rear_wall() -> void:
	_part("rear_frame")
	var z := REAR_Z
	# Backing and proud corner posts.
	_box(WOOD, Vector3(0.0, 3.05, z - 0.06), Vector3(4.16, 2.92, 0.06), DARK_TONES[1] * 0.7)
	for side: float in [-1.0, 1.0]:
		_box(WOOD, Vector3(side * 2.02, 3.05, z + 0.02), Vector3(0.38, 3.10, 0.38), _dark_tone(2))
		_box(IRON, Vector3(side * 2.02, 1.86, z + 0.20), Vector3(0.44, 0.12, 0.08), IRON_COLOR)
		_box(IRON, Vector3(side * 2.02, 4.32, z + 0.20), Vector3(0.44, 0.12, 0.08), IRON_COLOR)
	var boards := 13
	for i: int in boards:
		var x := -2.0 + (float(i) + 0.5) * (4.0 / float(boards))
		var tone := _jitter(_wood_tone(i + 9), i + 60, 0.032)
		_box(WOOD, Vector3(x, 3.02, z + 0.05), Vector3(4.0 / float(boards) - 0.020, 2.86, 0.15), tone)
	for y: float in [1.86, 3.60, 4.34]:
		_box(WOOD, Vector3(0.0, y, z + 0.16), Vector3(4.28, 0.24, 0.14), _dark_tone(int(y)))
	# Small hatch with planks, iron bands and a ring.
	_box(WOOD, Vector3(0.0, 2.42, z + 0.16), Vector3(0.94, 1.48, 0.10), _dark_tone(0))
	for i: int in 3:
		_box(WOOD, Vector3(0.0, 2.02 + float(i) * 0.40, z + 0.22), Vector3(0.88, 0.34, 0.05),
			_jitter(_wood_tone(i + 2), i + 7, 0.04))
	for i: int in 2:
		_box(IRON, Vector3(0.0, 2.20 + float(i) * 0.44, z + 0.26), Vector3(0.78, 0.08, 0.05), IRON_COLOR)
	_torus(IRON, Vector3(0.0, 2.34, z + 0.30), Vector3(0.0, 0.0, 1.0), 0.10, 0.024, IRON_COLOR, 10, 4)
	# Graffiti / stamped mark.
	_box(PAINT, Vector3(0.0, 4.12, z + 0.24), Vector3(0.52, 0.20, 0.04), CLOTH_COLOR * 0.8)
	_finish()
	_collision.append({"part": "rear_frame", "position": Vector3(0.0, 3.02, z),
		"size": Vector3(4.35, 3.15, 0.34), "rotation": Vector3.ZERO})

# ------------------------------------------------------------------ ram
func _build_ram() -> void:
	_ram_pivot = Node3D.new()
	_ram_pivot.name = "RamPivot"
	_ram_pivot.position = Vector3(0.0, 4.55, 1.90)
	add_child(_ram_pivot)
	_part("ram", _ram_pivot)
	var y := -2.30
	# The log itself, tapered toward the head.
	_tube(WOOD, Vector3(0.0, y, 0.95), Vector3(0.0, y, -4.60), 0.46, 0.40, 16, _wood_tone(2), true)
	_tube(WOOD, Vector3(0.0, y, -4.60), Vector3(0.0, y, -7.35), 0.40, 0.36, 16, _wood_tone(4), true)
	for i: int in 5:
		var z := 0.55 - float(i) * 1.55
		_torus(IRON, Vector3(0.0, y, z), Vector3(0.0, 0.0, 1.0), 0.455 - 0.020 * float(i), 0.050, IRON_COLOR * 1.45, 16, 4)
	# Rear cap and the rope bridle that the winch pulls.
	_tube(IRON, Vector3(0.0, y, 0.96), Vector3(0.0, y, 1.14), 0.50, 0.50, 12, IRON_COLOR * 1.35, true)
	_torus(ROPE, Vector3(0.0, y, 0.55), Vector3(1.0, 0.0, 0.0), 0.48, 0.060, ROPE_COLOR, 14, 4)
	# Iron ram head: a stylised ram, as in the reference plate.
	_build_ram_head(y)
	# Chains up to the gallery ceiling.
	_build_chain(Vector3(-0.92, 0.30, -2.10), Vector3(-0.52, y + 0.36, -2.35))
	_build_chain(Vector3(0.92, 0.30, -2.10), Vector3(0.52, y + 0.36, -2.35))
	# Hanging rope ends.
	_tube(ROPE, Vector3(-0.92, 0.30, -2.10), Vector3(-0.96, 1.25, -2.14), 0.05, 0.05, 6, ROPE_COLOR, false)
	_tube(ROPE, Vector3(0.92, 0.30, -2.10), Vector3(0.96, 1.25, -2.14), 0.05, 0.05, 6, ROPE_COLOR, false)
	_finish()
	_anchors["ram_tip"] = Vector3(0.0, y, -8.15)
	_anchors["ram_grip"] = Vector3(0.55, 0.0, 0.95)
	_anchors["ram_handle_world_local"] = Vector3(0.0, 2.15, 3.90)

func _build_ram_head(y: float) -> void:
	var steel := STEEL_COLOR
	# Neck: two bright steel rings instead of one dark iron drum, so the head
	# does not read as a black fin in shadow.
	for z: float in [-7.34, -7.56]:
		_torus(STEEL, Vector3(0.0, y, z), Vector3(0.0, 0.0, 1.0), 0.48, 0.055, STEEL_COLOR * 0.86, 16, 4)
		for i: int in 6:
			var a := TAU * float(i) / 6.0
			_box(IRON, Vector3(cos(a) * 0.48, y + sin(a) * 0.48, z - 0.02), Vector3(0.05, 0.05, 0.05), IRON_COLOR * 1.2)
	# Main skull of the ram: narrower and taller, with a long muzzle.
	_box(STEEL, Vector3(0.0, y + 0.02, -7.88), Vector3(0.90, 0.92, 0.86), steel * 0.95)
	_box(STEEL, Vector3(0.0, y - 0.08, -8.32), Vector3(0.64, 0.58, 0.54), steel * 1.02)
	# Snout, jaw, mouth line and beard.
	_box(STEEL, Vector3(0.0, y - 0.20, -8.64), Vector3(0.46, 0.38, 0.34), steel * 1.06)
	_box(STEEL, Vector3(0.0, y - 0.44, -8.50), Vector3(0.40, 0.16, 0.42), steel * 0.84)
	_box(IRON, Vector3(0.0, y - 0.36, -8.82), Vector3(0.30, 0.05, 0.03), IRON_COLOR * 0.5)
	# Dark seams break the big steel planes into a face.
	_box(IRON, Vector3(0.0, y + 0.06, -8.37), Vector3(0.035, 0.46, 0.03), IRON_COLOR * 0.55)
	_box(IRON, Vector3(0.0, y - 0.22, -8.15), Vector3(0.72, 0.030, 0.03), IRON_COLOR * 0.55)
	for i: int in 3:
		_box(STEEL, Vector3(-0.14 + float(i) * 0.14, y - 0.56, -8.42), Vector3(0.07, 0.20, 0.07),
			STEEL_COLOR * 0.70, Basis(Vector3.RIGHT, 0.18 * float(i - 1)))
	for side: float in [-1.0, 1.0]:
		_box(IRON, Vector3(side * 0.13, y - 0.13, -8.80), Vector3(0.09, 0.08, 0.03), IRON_COLOR * 0.5)
		# Eyes: a dark steel socket under a gold iris.
		_box(STEEL, Vector3(side * 0.31, y + 0.12, -8.25), Vector3(0.16, 0.14, 0.04), STEEL_COLOR * 0.42)
		_box(GOLD, Vector3(side * 0.31, y + 0.12, -8.29), Vector3(0.115, 0.10, 0.05), GOLD_COLOR * 1.15)
		# Cheek plates.
		_box(STEEL, Vector3(side * 0.50, y - 0.04, -8.20), Vector3(0.12, 0.44, 0.50), steel * 0.88,
			Basis(Vector3.BACK, side * 0.10))
		# Ears and jaw guards.
		_box(STEEL, Vector3(side * 0.52, y + 0.28, -7.98), Vector3(0.20, 0.30, 0.12), steel * 0.82,
			Basis(Vector3.BACK, side * 0.45))
		_box(IRON, Vector3(side * 0.40, y - 0.32, -8.02), Vector3(0.12, 0.24, 0.34), IRON_COLOR * 0.9)
	# Raised nose bridge from the brow to the snout.
	_box(STEEL, Vector3(0.0, y + 0.10, -8.36), Vector3(0.17, 0.46, 0.05), steel * 1.10)
	# Curled horns hugging the cheeks: lower than the skull so neither horn
	# rises above the head as a floating hook.
	for side: float in [-1.0, 1.0]:
		var points: Array[Vector3] = [
			Vector3(side * 0.46, y + 0.12, -7.98),
			Vector3(side * 0.66, y + 0.09, -7.94),
			Vector3(side * 0.81, y - 0.03, -7.84),
			Vector3(side * 0.85, y - 0.21, -7.70),
			Vector3(side * 0.77, y - 0.38, -7.58),
			Vector3(side * 0.65, y - 0.46, -7.56),
			Vector3(side * 0.58, y - 0.44, -7.66),
		]
		for step: int in points.size() - 1:
			var t := float(step) / float(points.size() - 2)
			var r0 := 0.165 * (1.0 - t * 0.80)
			var r1 := 0.165 * (1.0 - (t + 0.14) * 0.80)
			_tube(STEEL, points[step], points[step + 1], r0, r1, 10, steel * (0.93 + 0.05 * float(step)), true)
			if step < 5:
				var axis := (points[step + 1] - points[step]).normalized()
				_torus(STEEL, points[step].lerp(points[step + 1], 0.55), axis,
					r0 * 1.05, 0.017, STEEL_COLOR * 0.80, 10, 4)
	# Iron mane plates behind the head.
	for i: int in 5:
		var a := -0.9 + float(i) * 0.45
		_box(STEEL, Vector3(sin(a) * 0.58, y - 0.34 + float(i) * 0.11, -7.66), Vector3(0.24, 0.18, 0.26),
			STEEL_COLOR * 0.76, Basis(Vector3.BACK, a))
	# Brow band and rivets.
	_torus(IRON, Vector3(0.0, y + 0.30, -8.05), Vector3(0.0, 0.0, 1.0), 0.56, 0.05, IRON_COLOR, 16, 4)
	for i: int in 8:
		var a := TAU * float(i) / 8.0
		_box(IRON, Vector3(cos(a) * 0.56, y + 0.30 + sin(a) * 0.56, -8.05), Vector3(0.055, 0.055, 0.055), IRON_COLOR * 1.2)
	# A plain iron brow band; no spike above the skull.

func _build_chain(from: Vector3, to: Vector3) -> void:
	var links := 13
	for i: int in links:
		var t0 := float(i) / float(links)
		var t1 := float(i + 1) / float(links)
		var a := from.lerp(to, t0)
		var b := from.lerp(to, t1)
		_tube(IRON, a, b, 0.028, 0.028, 5, IRON_COLOR * 1.15, false)
		var mid := (a + b) * 0.5
		var axis := (b - a).normalized()
		_torus(IRON, mid, axis, 0.090, 0.026, IRON_COLOR * 1.15, 8, 4)

# ------------------------------------------------------------------ winch / mechanism
func _build_winch() -> void:
	_part("winch")
	var y := 4.12
	var z := 2.16
	_tube(WOOD, Vector3(-0.62, y, z), Vector3(0.62, y, z), 0.30, 0.30, 12, _wood_tone(1), true)
	for x: float in [-0.52, 0.52]:
		_torus(IRON, Vector3(x, y, z), Vector3(1.0, 0.0, 0.0), 0.31, 0.035, IRON_COLOR, 12, 4)
	# Ratchet wheel and pawl.
	_torus(STEEL, Vector3(0.60, y, z), Vector3(1.0, 0.0, 0.0), 0.34, 0.045, STEEL_COLOR * 0.9, 16, 4)
	for tooth: int in 12:
		var a := TAU * float(tooth) / 12.0
		_box(IRON, Vector3(0.63, y + cos(a) * 0.40, z + sin(a) * 0.40), Vector3(0.07, 0.10, 0.08), IRON_COLOR)
	# Crank.
	_box(WOOD, Vector3(0.78, y + 0.34, z), Vector3(0.08, 0.72, 0.08), _dark_tone(0))
	_box(WOOD, Vector3(0.78, y + 0.70, z + 0.16), Vector3(0.07, 0.07, 0.34), _wood_tone(3))
	# Rope drum -> ram bridle.
	_tube(ROPE, Vector3(0.0, y - 0.30, z - 0.10), Vector3(0.0, 2.28, 1.15), 0.035, 0.035, 6, ROPE_COLOR, false)
	# Support brackets.
	for x: float in [-0.80, 0.80]:
		_box(WOOD, Vector3(x, y, z), Vector3(0.16, 0.90, 0.26), _dark_tone(3))
		_box(IRON, Vector3(x, y + 0.34, z - 0.14), Vector3(0.20, 0.12, 0.08), IRON_COLOR)
	_finish()
	_collision.append({"part": "winch", "position": Vector3(0.0, y, z),
		"size": Vector3(1.7, 1.0, 0.9), "rotation": Vector3.ZERO})

# ------------------------------------------------------------------ upper body
func _build_upper_body() -> void:
	_part("upper_wall")
	var y0 := GALLERY_TOP
	var y1 := UPPER_TOP
	# Backing panels behind the planking.
	for side: float in [-1.0, 1.0]:
		_box(WOOD, Vector3(side * 1.66, (y0 + y1) * 0.5, 0.0),
			Vector3(0.06, y1 - y0 - 0.16, 3.44), DARK_TONES[1] * 0.7)
	for z: float in [-1.70, 1.70]:
		_box(WOOD, Vector3(0.0, (y0 + y1) * 0.5, z),
			Vector3(3.38, y1 - y0 - 0.16, 0.06), DARK_TONES[1] * 0.7)
	# Corner posts, proud of the boards.
	for side: float in [-1.0, 1.0]:
		for z: float in [-1.86, 1.86]:
			_box(WOOD, Vector3(side * 1.82, (y0 + y1) * 0.5, z), Vector3(0.30, y1 - y0 + 0.10, 0.30), _dark_tone(int(side + z) + 2))
			_box(IRON, Vector3(side * 1.82, y1 - 0.18, z), Vector3(0.36, 0.14, 0.36), IRON_COLOR)
	# Side walls, planked.
	for side: float in [-1.0, 1.0]:
		var boards := 12
		for i: int in boards:
			var z := -1.64 + (float(i) + 0.5) * (3.28 / float(boards))
			_box(WOOD, Vector3(side * 1.76, (y0 + y1) * 0.5, z),
				Vector3(0.14, y1 - y0 - 0.20, 3.28 / float(boards) - 0.030),
				_jitter(_wood_tone(i + int(side) * 3 + 8), i + 11, 0.044))
		# Horizontal belts and iron straps, outside the boards.
		for y: float in [5.30, 6.55, 7.85]:
			_box(WOOD, Vector3(side * 1.88, y, 0.0), Vector3(0.16, 0.24, 3.76), _dark_tone(int(y)))
		for y: float in [5.95, 7.20]:
			_box(IRON, Vector3(side * 1.95, y, 0.0), Vector3(0.05, 0.12, 3.44), IRON_COLOR)
			for n: int in 5:
				_box(IRON, Vector3(side * 1.99, y, -1.3 + float(n) * 0.65), Vector3(0.04, 0.04, 0.04), IRON_COLOR * 1.15)
		# A narrow arrow slit with an iron frame.
		_box(IRON, Vector3(side * 1.90, 7.12, -0.55), Vector3(0.07, 1.02, 0.22), IRON_COLOR * 0.75)
		_box(WOOD, Vector3(side * 1.94, 7.12, -0.55), Vector3(0.05, 0.76, 0.08), Color(0.025, 0.024, 0.026))
		_box(IRON, Vector3(side * 1.97, 7.62, -0.55), Vector3(0.10, 0.06, 0.30), IRON_COLOR)
	# Front and rear walls.
	for z: float in [-1.76, 1.76]:
		var boards := 8
		for i: int in boards:
			var x := -1.56 + (float(i) + 0.5) * (3.12 / float(boards))
			_box(WOOD, Vector3(x, (y0 + y1) * 0.5, z),
				Vector3(3.12 / float(boards) - 0.028, y1 - y0 - 0.18, 0.14),
				_jitter(_wood_tone(i + 5), i + int(z * 5.0), 0.044))
		for y: float in [5.30, 6.55, 7.85]:
			_box(WOOD, Vector3(0.0, y, z + (0.11 if z < 0.0 else -0.11)), Vector3(3.62, 0.24, 0.16), _dark_tone(int(y)))
	# Front device board and shield.
	_build_shield(Vector3(0.0, 6.45, -2.02), 0.0, 1.00)
	# Small barred window on the rear.
	_box(IRON, Vector3(0.0, 5.72, 1.90), Vector3(0.66, 0.50, 0.06), IRON_COLOR * 0.8)
	for i: int in 3:
		_box(WOOD, Vector3(-0.22 + float(i) * 0.22, 5.72, 1.96), Vector3(0.05, 0.46, 0.05), _dark_tone(i))
	# Iron corner caps.
	for side: float in [-1.0, 1.0]:
		for z: float in [-1.86, 1.86]:
			_box(IRON, Vector3(side * 1.82, y1 - 0.08, z), Vector3(0.38, 0.16, 0.38), IRON_COLOR)
	# Flared skirt between the wide gallery roof and the narrower fighting tower.
	for side: float in [-1.0, 1.0]:
		for i: int in 14:
			var z := -2.52 + (float(i) + 0.5) * (5.04 / 14.0)
			_box(WOOD, Vector3(side * 1.95, 4.98, z), Vector3(0.15, 1.02, 5.04 / 14.0 - 0.018),
				_jitter(_wood_tone(i + 12), i + 70, 0.040), Basis(Vector3.BACK, side * 0.34))
		_box(WOOD, Vector3(side * 1.90, 4.58, 0.0), Vector3(0.20, 0.18, 5.16), _dark_tone(2))
		_box(WOOD, Vector3(side * 1.80, 5.46, 0.0), Vector3(0.20, 0.18, 3.72), _dark_tone(4))
	for z: float in [-1.82, 1.82]:
		for i: int in 7:
			var x := -1.44 + (float(i) + 0.5) * (2.88 / 7.0)
			_box(WOOD, Vector3(x, 4.98, z), Vector3(2.88 / 7.0 - 0.018, 1.02, 0.15),
				_jitter(_wood_tone(i + 3), i + 90, 0.040), Basis(Vector3.RIGHT, -0.34))
	_finish()
	_collision.append({"part": "upper_wall", "position": Vector3(0.0, 6.72, -1.78),
		"size": Vector3(3.55, 4.15, 0.30), "rotation": Vector3.ZERO})
	_collision.append({"part": "upper_wall", "position": Vector3(0.0, 6.72, 1.78),
		"size": Vector3(3.55, 4.15, 0.30), "rotation": Vector3.ZERO})
	for side: float in [-1.0, 1.0]:
		_collision.append({"part": "upper_wall", "position": Vector3(side * 1.78, 6.72, 0.0),
			"size": Vector3(0.30, 4.15, 3.70), "rotation": Vector3.ZERO})

func _build_shield(at: Vector3, yaw: float, scale: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var face := basis * Vector3(0.0, 0.0, -1.0)
	# Kite shield: four tapering oak boards with a leather face and an iron rim.
	var widths: Array[float] = [0.96, 0.88, 0.72, 0.46]
	for i: int in 4:
		var width := scale * widths[i]
		var drop := scale * (0.34 - 0.30 * float(i))
		_box(WOOD, at + basis * Vector3(0.0, drop, 0.0) + face * (0.016 * float(i)),
			Vector3(width, scale * 0.40, 0.060), _dark_tone(i + 1), basis)
	# Dark rim, slightly larger than the boards.
	_box(WOOD, at + face * 0.075, Vector3(scale * 1.02, scale * 1.38, 0.030), DARK_TONES[2], basis)
	_box(PAINT, at + face * 0.094, Vector3(scale * 0.86, scale * 1.18, 0.030), CLOTH_BLUE, basis)
	# Gold cross and a steel boss.
	_box(GOLD, at + face * 0.112, Vector3(scale * 0.15, scale * 1.06, 0.020), GOLD_COLOR, basis)
	_box(GOLD, at + face * 0.112, Vector3(scale * 0.76, scale * 0.14, 0.020), GOLD_COLOR, basis)
	_tube(STEEL, at + face * 0.09, at + face * 0.16, scale * 0.19, scale * 0.16, 10, STEEL_COLOR, true)
	_torus(IRON, at + face * 0.16, face, scale * 0.20, 0.022, IRON_COLOR, 12, 4)
	# Rivets along the rim.
	for i: int in 6:
		var angle := TAU * float(i) / 6.0
		_box(IRON, at + basis * Vector3(cos(angle) * scale * 0.42, sin(angle) * scale * 0.55, 0.0) + face * 0.09,
			Vector3(0.045, 0.045, 0.025), IRON_COLOR * 1.15, basis)
	# Leather straps behind the shield, visible from the side.
	for side: float in [-1.0, 1.0]:
		_box(IRON, at + basis * Vector3(side * scale * 0.30, scale * 0.18, 0.0) - face * 0.06,
			Vector3(0.07, 0.60, 0.03), IRON_COLOR * 0.8, basis)

# ------------------------------------------------------------------ fighting platform
func _build_platform() -> void:
	_part("platform")
	var y := PLATFORM_Y
	# A solid fighting floor.  The ladder arrives at a small balcony behind it,
	# so nobody has to drop through a hatch in the middle of the deck.
	_floor_field(Vector3(0.0, y, -0.05), Vector3(4.85, 0.20, 5.55))
	# Edge beams and a heavy rim.
	for side: float in [-1.0, 1.0]:
		_box(WOOD, Vector3(side * 2.46, y - 0.10, 0.0), Vector3(0.22, 0.30, 5.65), _dark_tone(2))
	_box(WOOD, Vector3(0.0, y - 0.10, -2.78), Vector3(5.10, 0.30, 0.22), _dark_tone(1))
	_box(WOOD, Vector3(0.0, y - 0.10, 2.78), Vector3(5.10, 0.30, 0.22), _dark_tone(3))
	# Support knees under the overhang.
	for side: float in [-1.0, 1.0]:
		for z: float in [-2.0, 0.6, 2.4]:
			_box(WOOD, Vector3(side * 2.20, y - 0.30, z), Vector3(0.16, 0.42, 0.50), _dark_tone(4),
				Basis(Vector3.RIGHT, 0.0))
	_finish()
	_collision.append({"part": "platform", "position": Vector3(0.0, y, -0.05),
		"size": Vector3(4.85, 0.24, 5.55), "rotation": Vector3.ZERO})

func _floor_field(center: Vector3, size: Vector3) -> void:
	var boards := maxi(2, int(round(size.z / 0.34)))
	for i: int in boards:
		var z := center.z - size.z * 0.5 + (float(i) + 0.5) * size.z / float(boards)
		_box(WOOD, Vector3(center.x, center.y, z), Vector3(size.x, size.y, size.z / float(boards) - 0.012),
			_jitter(_wood_tone(i + 1), i + 80, 0.028))

func _build_parapet() -> void:
	pass
# ------------------------------------------------------------------ roof
func _build_roof() -> void:
	_part("parapet")
	var y := PLATFORM_Y
	# Waist-high parapet boards on the exposed sides, then crenellations.  The
	# right flank has a gap where the ladder lands on its balcony.
	_parapet_wall(Vector3(0.0, y + 0.34, FRONT_Z + 0.10), Vector3(4.95, 0.66, 0.24), 0.0)
	_parapet_wall(Vector3(-2.44, y + 0.34, 0.0), Vector3(0.24, 0.66, 5.46), 0.0)
	_parapet_wall(Vector3(2.44, y + 0.34, -1.47), Vector3(0.24, 0.66, 2.62), 0.0)
	_parapet_wall(Vector3(2.44, y + 0.34, 2.02), Vector3(0.24, 0.66, 1.52), 0.0)
	_parapet_wall(Vector3(0.0, y + 0.34, REAR_Z - 0.10), Vector3(4.95, 0.66, 0.24), 0.0)
	# Merlons above the parapet.
	_merlons(Vector3(0.0, PARAPET_TOP, FRONT_Z + 0.10), 0.0)
	_merlons(Vector3(0.0, PARAPET_TOP, REAR_Z - 0.10), 0.0)
	_merlons(Vector3(-2.44, PARAPET_TOP, 0.0), PI * 0.5)
	_merlon_at(Vector3(2.44, PARAPET_TOP, -1.47), PI * 0.5, -0.80)
	_merlon_at(Vector3(2.44, PARAPET_TOP, -1.47), PI * 0.5, 0.80)
	_merlon_at(Vector3(2.44, PARAPET_TOP, 2.02), PI * 0.5, -0.50)
	_merlon_at(Vector3(2.44, PARAPET_TOP, 2.02), PI * 0.5, 0.50)
	# Roof posts and knee braces.
	for side: float in [-1.0, 1.0]:
		for z: float in [FRONT_Z + 0.20, REAR_Z - 0.20]:
			_box(WOOD, Vector3(side * 2.14, 10.02, z), Vector3(0.28, 2.34, 0.28), _dark_tone(1))
			_box(IRON, Vector3(side * 2.14, 9.28, z), Vector3(0.36, 0.14, 0.36), IRON_COLOR)
			_box(WOOD, Vector3(side * 1.92, 10.74, z), Vector3(0.14, 0.14, 0.70), _dark_tone(3),
				Basis(Vector3.BACK, side * 0.72))
	# Cross tie beams between the front and rear posts.
	for side: float in [-1.0, 1.0]:
		_box(WOOD, Vector3(side * 2.14, 10.86, 0.0), Vector3(0.18, 0.22, 5.30), _dark_tone(2))
	_finish()
	_collision.append({"part": "parapet", "position": Vector3(0.0, y + 0.48, FRONT_Z + 0.10),
		"size": Vector3(4.95, 0.92, 0.30), "rotation": Vector3.ZERO})
	_collision.append({"part": "parapet", "position": Vector3(-2.44, y + 0.48, 0.0),
		"size": Vector3(0.30, 0.92, 5.50), "rotation": Vector3.ZERO})
	_collision.append({"part": "parapet", "position": Vector3(2.44, y + 0.48, -1.47),
		"size": Vector3(0.30, 0.92, 2.66), "rotation": Vector3.ZERO})
	_collision.append({"part": "parapet", "position": Vector3(2.44, y + 0.48, 2.02),
		"size": Vector3(0.30, 0.92, 1.56), "rotation": Vector3.ZERO})
	_collision.append({"part": "parapet", "position": Vector3(0.0, y + 0.48, REAR_Z - 0.10),
		"size": Vector3(4.95, 0.92, 0.30), "rotation": Vector3.ZERO})
	_build_roof_shell()

func _parapet_wall(center: Vector3, size: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var boards := maxi(2, int(round(size.x / 0.30)))
	for i: int in boards:
		var x := -size.x * 0.5 + (float(i) + 0.5) * size.x / float(boards)
		_box(WOOD, center + basis * Vector3(x, 0.0, 0.0),
			Vector3(size.x / float(boards) - 0.014, size.y, size.z),
			_jitter(_wood_tone(i + 4), i + 100, 0.03), basis)
	# Iron cap rail.
	_box(IRON, center + Vector3(0.0, size.y * 0.5 + 0.035, 0.0), Vector3(size.x + 0.08, 0.06, size.z + 0.06),
		IRON_COLOR * 0.9, basis)

func _merlons(center: Vector3, yaw: float) -> void:
	for i: int in 4:
		_merlon_at(center, yaw, -1.68 + float(i) * 1.12, i)

func _merlon_at(center: Vector3, yaw: float, offset: float, seed_value: int = 0) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(WOOD, center + basis * Vector3(offset, 0.30, 0.0), Vector3(0.70, 0.62, 0.28),
		_jitter(_wood_tone(seed_value + 8), seed_value + 120, 0.040), basis)
	_box(IRON, center + basis * Vector3(offset, 0.64, 0.0), Vector3(0.78, 0.07, 0.34),
		IRON_COLOR * 0.9, basis)
	# A shooting loophole in each merlon.
	_box(WOOD, center + basis * Vector3(offset, 0.26, -0.16), Vector3(0.16, 0.24, 0.03), Color(0.03, 0.028, 0.03), basis)

func _build_roof_shell() -> void:
	_part("roof")
	var ridge_y := ROOF_RIDGE
	var eave_y := ROOF_EAVE
	var half_span := 3.02
	var slope := atan2(ridge_y - eave_y, half_span)
	# Two slopes of overlapping shingle courses.  Each course is split into five
	# staggered boards so the roof does not read as one smooth ramp.
	for side: float in [-1.0, 1.0]:
		var courses := 10
		for i: int in courses:
			var t := (float(i) + 0.5) / float(courses)
			var x := side * lerpf(half_span, 0.06, t)
			var y := lerpf(eave_y, ridge_y, t)
			for seg: int in 5:
				var z := -2.62 + (float(seg) + 0.5) * 1.31
				var tone := _jitter(_wood_tone(i + seg + (0 if side < 0.0 else 4)), i * 7 + seg + 140, 0.050)
				_box(WOOD, Vector3(x + side * 0.03 * float(seg % 2), y + 0.05, z),
					Vector3(0.66, 0.075, 1.20), tone * 0.92,
					Basis(Vector3.BACK, -side * slope))
				# Dark shadow line under the lower edge of every course.
				_box(WOOD, Vector3(x + side * 0.30, y - 0.055, z),
					Vector3(0.055, 0.075, 1.18), DARK_TONES[2],
					Basis(Vector3.BACK, -side * slope))
		# Eave fascia and a run of rafter ends.
		_box(WOOD, Vector3(side * 3.06, eave_y - 0.10, 0.0), Vector3(0.12, 0.40, 6.70), _dark_tone(2))
		_box(IRON, Vector3(side * 3.10, eave_y - 0.02, 0.0), Vector3(0.05, 0.09, 6.40), IRON_COLOR)
		for rafter: int in 7:
			var z := -2.85 + float(rafter) * 0.95
			_box(WOOD, Vector3(side * 2.72, eave_y - 0.22, z), Vector3(0.52, 0.12, 0.14), _dark_tone(rafter))
	# Barge boards and infill on the two gable ends.
	for z: float in [FRONT_Z - 0.18, REAR_Z + 0.18]:
		var boards := 9
		for i: int in boards:
			var t := (float(i) + 0.5) / float(boards)
			var y := lerpf(eave_y + 0.10, ridge_y - 0.05, t)
			var half := lerpf(3.00, 0.10, t)
			_box(WOOD, Vector3(0.0, y, z), Vector3(half * 2.0, 0.20, 0.12),
				_jitter(_dark_tone(i + 1), i + 160, 0.036))
		for side: float in [-1.0, 1.0]:
			var length := sqrt(half_span * half_span + (ridge_y - eave_y) * (ridge_y - eave_y))
			_box(WOOD, Vector3(side * 1.55, (eave_y + ridge_y) * 0.5 + 0.04, z + (0.12 if z > 0.0 else -0.12)),
				Vector3(length, 0.22, 0.16), _dark_tone(1),
				Basis(Vector3.BACK, -side * slope))
	# Ridge beam with tiles.
	_tube(WOOD, Vector3(0.0, ridge_y + 0.12, -3.42), Vector3(0.0, ridge_y + 0.12, 3.42), 0.16, 0.16, 10, _dark_tone(1), true)
	for i: int in 11:
		var z := -3.10 + float(i) * 0.62
		_box(WOOD, Vector3(0.0, ridge_y + 0.28, z), Vector3(0.34, 0.13, 0.55), DARK_TONES[0])
	# Finials: iron caps, gold orbs and carved beast heads.
	for z: float in [-3.42, 3.42]:
		_box(IRON, Vector3(0.0, ridge_y + 0.34, z), Vector3(0.20, 0.34, 0.20), IRON_COLOR)
		_box(GOLD, Vector3(0.0, ridge_y + 0.58, z), Vector3(0.12, 0.20, 0.12), GOLD_COLOR)
		_box(WOOD, Vector3(0.0, ridge_y - 0.02, z + (0.26 if z > 0.0 else -0.26)), Vector3(0.40, 0.32, 0.38), _dark_tone(0))
		for side: float in [-1.0, 1.0]:
			_tube(WOOD, Vector3(side * 0.18, ridge_y + 0.02, z + (0.26 if z > 0.0 else -0.26)),
				Vector3(side * 0.34, ridge_y + 0.26, z + (0.12 if z > 0.0 else -0.12)), 0.06, 0.02, 6, _dark_tone(3), true)
	# Pennant on a short mast above the ridge.
	_tube(WOOD, Vector3(0.0, ridge_y + 0.18, -3.30), Vector3(0.0, ridge_y + 1.55, -3.30), 0.035, 0.02, 6, _dark_tone(2), true)
	for i: int in 4:
		_box(CLOTH, Vector3(0.34 - float(i) * 0.07, ridge_y + 1.38 - float(i) * 0.13, -3.30),
			Vector3(0.64 - float(i) * 0.10, 0.22, 0.03), CLOTH_COLOR * (1.0 - float(i) * 0.07),
			Basis(Vector3.BACK, 0.10 * float(i)))
	# A lantern hanging under the ridge.
	_tube(IRON, Vector3(0.0, ridge_y - 0.10, -1.1), Vector3(0.0, ridge_y - 0.72, -1.1), 0.022, 0.022, 4, IRON_COLOR, false)
	_box(IRON, Vector3(0.0, ridge_y - 0.84, -1.1), Vector3(0.22, 0.28, 0.22), IRON_COLOR)
	_box(GOLD, Vector3(0.0, ridge_y - 0.84, -1.1), Vector3(0.15, 0.19, 0.15), Color(1.0, 0.68, 0.26))
	_finish()
	_collision.append({"part": "roof", "position": Vector3(0.0, 12.10, 0.0),
		"size": Vector3(5.9, 0.60, 6.6), "rotation": Vector3.ZERO})

# ------------------------------------------------------------------ ladder
func _build_ladder() -> void:
	_part("ladder")
	# A near-vertical assault ladder on the RIGHT flank, outside the roof eave and
	# clear of the rear push frame.  The top meets a small side landing.
	var bottom := Vector3(3.34, 0.02, 0.55)
	var top := Vector3(3.34, 8.74, 0.55)
	var length := bottom.distance_to(top)
	for side: float in [-1.0, 1.0]:
		_box(WOOD, Vector3(3.34, (bottom.y + top.y) * 0.5, 0.55 + side * 0.46),
			Vector3(0.13, length, 0.13), _wood_tone(3))
		_box(IRON, Vector3(3.42, (bottom.y + top.y) * 0.5, 0.55 + side * 0.46),
			Vector3(0.04, length * 0.92, 0.05), IRON_COLOR * 0.8)
	var rungs := 16
	for i: int in rungs:
		var t := (float(i) + 0.5) / float(rungs)
		var p := bottom.lerp(top, t)
		_box(WOOD, p, Vector3(0.10, 0.075, 1.06), _wood_tone(i + 1))
		for side: float in [-1.0, 1.0]:
			_box(IRON, p + Vector3(0.04, 0.0, side * 0.46), Vector3(0.12, 0.10, 0.08), IRON_COLOR)
	# Brackets to the gallery wall low down, and to the platform edge at the top.
	for y: float in [1.55, 3.40]:
		_box(WOOD, Vector3(2.78, y, 0.55), Vector3(1.16, 0.13, 0.16), _dark_tone(int(y)))
		_box(IRON, Vector3(2.20, y - 0.02, 0.55), Vector3(0.10, 0.18, 0.26), IRON_COLOR)
	_box(WOOD, Vector3(2.90, 8.62, 0.55), Vector3(0.96, 0.14, 0.18), _dark_tone(2))
	_box(WOOD, Vector3(3.34, 8.86, 0.06), Vector3(1.10, 0.12, 0.14), _dark_tone(1))
	_box(WOOD, Vector3(3.34, 8.86, 1.04), Vector3(1.10, 0.12, 0.14), _dark_tone(1))
	# A rope tied to the top rung.
	_tube(ROPE, Vector3(3.30, 8.56, 0.10), Vector3(3.20, 7.20, 0.16), 0.035, 0.035, 5, ROPE_COLOR, false)
	_finish()

# ------------------------------------------------------------------ stores and dressing
func _build_stores() -> void:
	_part("stores")
	var y := PLATFORM_Y + 0.10
	# Crate on the rear left of the platform.
	_box(WOOD, Vector3(-1.72, y + 0.28, 1.98), Vector3(0.78, 0.56, 0.74), _wood_tone(3))
	for z: float in [1.62, 2.34]:
		_box(WOOD, Vector3(-1.72, y + 0.28, z), Vector3(0.84, 0.10, 0.08), _dark_tone(int(z * 3.0)))
	for side: float in [-1.0, 1.0]:
		_box(WOOD, Vector3(-1.72 + side * 0.40, y + 0.28, 1.98), Vector3(0.08, 0.10, 0.78), _dark_tone(3))
	# Water barrel on the rear right.
	_tube(WOOD, Vector3(1.68, y + 0.02, 2.02), Vector3(1.68, y + 0.66, 2.02), 0.26, 0.24, 10, _wood_tone(1), true)
	for k: int in 3:
		_torus(IRON, Vector3(1.68, y + 0.16 + float(k) * 0.19, 2.02), Vector3(0.0, 1.0, 0.0), 0.255, 0.026, IRON_COLOR, 10, 4)
	# Arrow rack: a bundle of shafts leaning in the corner.
	for i: int in 7:
		var a := TAU * float(i) / 7.0
		_tube(WOOD, Vector3(1.05, y + 0.05, -2.15), Vector3(1.10 + cos(a) * 0.10, y + 0.95, -2.20 + sin(a) * 0.10),
			0.018, 0.014, 4, _wood_tone(i), false)
	# A small rack of javelins against the front parapet.
	for i: int in 3:
		_tube(WOOD, Vector3(-1.8 + float(i) * 0.16, y + 0.02, -2.3), Vector3(-1.76 + float(i) * 0.16, y + 1.55, -2.42),
			0.022, 0.018, 5, _wood_tone(i + 2), false)
		_box(STEEL, Vector3(-1.76 + float(i) * 0.16, y + 1.58, -2.42), Vector3(0.05, 0.16, 0.07), STEEL_COLOR * 0.9)
	_finish()

func _build_banners() -> void:
	_part("banners")
	# Large hanging banners on the fighting tower: colour is what makes the
	# machine readable from the gate, and the gold ram-mark matches the shields.
	for side: float in [-1.0, 1.0]:
		_hanging_banner(Vector3(side * 1.16, 8.34, -1.94), 0.78, 2.55,
			CLOTH_COLOR if side < 0.0 else CLOTH_BLUE, 0.0, true)
		_hanging_banner(Vector3(side * 1.92, 8.36, 0.0), 0.92, 2.25,
			CLOTH_BLUE if side < 0.0 else CLOTH_COLOR, -side * PI * 0.5, false)
	# A banner on the rear face too, so the crew's side is not a blank wall.
	_hanging_banner(Vector3(0.0, 8.28, 1.94), 0.86, 1.80, CLOTH_COLOR, PI, false)
	# Short pennants on the front corners of the parapet.
	for side: float in [-1.0, 1.0]:
		var x := side * 2.34
		_tube(WOOD, Vector3(x, PLATFORM_Y + 0.5, FRONT_Z - 0.02), Vector3(x, 10.55, FRONT_Z - 0.02), 0.035, 0.03, 6, _wood_tone(1), true)
		var cloth := CLOTH_COLOR if side < 0.0 else CLOTH_BLUE
		for i: int in 5:
			var t := float(i) / 5.0
			var w := lerpf(0.46, 0.28, t)
			_box(CLOTH, Vector3(x + side * 0.02, 10.45 - t * 1.30, FRONT_Z - 0.02 + 0.03),
				Vector3(w, 0.28, 0.025), cloth * (0.95 + 0.05 * float(i)),
				Basis(Vector3.BACK, sin(t * 2.4) * 0.10))
		_box(GOLD, Vector3(x + side * 0.02, 10.06, FRONT_Z + 0.02), Vector3(0.15, 0.15, 0.02), GOLD_COLOR,
			Basis(Vector3.BACK, 0.78))
	# A painted board with a ram's head over the gallery entrance.
	_box(PAINT, Vector3(0.0, 4.34, FRONT_Z - 0.28), Vector3(0.78, 0.38, 0.04), CLOTH_BLUE)
	_box(GOLD, Vector3(0.0, 4.34, FRONT_Z - 0.31), Vector3(0.16, 0.24, 0.02), GOLD_COLOR)
	for side: float in [-1.0, 1.0]:
		_tube(GOLD, Vector3(side * 0.08, 4.42, FRONT_Z - 0.32), Vector3(side * 0.26, 4.52, FRONT_Z - 0.32),
			0.028, 0.012, 5, GOLD_COLOR, true)
	_finish()

func _hanging_banner(top: Vector3, width: float, height: float, color: Color, yaw: float, emblem: bool) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var normal := basis * Vector3(0.0, 0.0, -1.0)
	# Cross pole with iron finials.
	_box(WOOD, top, Vector3(width + 0.20, 0.07, 0.07), _dark_tone(1), basis)
	for side: float in [-1.0, 1.0]:
		_box(IRON, top + basis * Vector3(side * (width * 0.5 + 0.12), 0.0, 0.0), Vector3(0.07, 0.11, 0.11), IRON_COLOR, basis)
	# Cloth: seven hanging strips with a slight belly and a torn bottom.
	var segments := 7
	for i: int in segments:
		var seg_h := height / float(segments)
		var offset := sin(float(i) * 0.85) * 0.035
		var shade := 0.96 + 0.06 * sin(float(i) * 1.7)
		var w := width * (1.0 - 0.008 * float(i))
		_box(CLOTH, top + Vector3(0.0, -seg_h * (float(i) + 0.5), 0.0) + normal * (0.018 + offset),
			Vector3(w, seg_h + 0.015, 0.028), color * shade, basis)
		# A dark fold between strips.
		_box(WOOD, top + Vector3(0.0, -seg_h * (float(i) + 1.0), 0.0) + normal * 0.006,
			Vector3(w, 0.016, 0.018), color * 0.55, basis)
	# Torn lower edge.
	for i: int in 4:
		var x := -width * 0.36 + float(i) * width * 0.24
		_box(CLOTH, top + Vector3(x, -height - 0.10, 0.0) + normal * 0.02,
			Vector3(width * 0.11, 0.22, 0.026), color * 0.85, basis)
	if emblem:
		var at := top + Vector3(0.0, -height * 0.46, 0.0) + normal * 0.055
		# A stylised gold ram's head: ring skull, muzzle, two curling horns.
		_torus(GOLD, at + Vector3(0.0, 0.08, 0.0), normal, 0.13, 0.026, GOLD_COLOR, 14, 4)
		_box(GOLD, at + Vector3(0.0, -0.14, 0.0), Vector3(0.13, 0.20, 0.022), GOLD_COLOR, basis)
		for side: float in [-1.0, 1.0]:
			var points: Array[Vector3] = [
				at + basis * Vector3(side * 0.12, 0.20, 0.0),
				at + basis * Vector3(side * 0.25, 0.28, 0.0),
				at + basis * Vector3(side * 0.33, 0.24, 0.0),
				at + basis * Vector3(side * 0.36, 0.12, 0.0),
			]
			for step: int in points.size() - 1:
				_tube(GOLD, points[step], points[step + 1], 0.030, 0.020, 6, GOLD_COLOR, true)
		_box(GOLD, at + Vector3(0.0, -0.44, 0.0), Vector3(0.26, 0.05, 0.020), GOLD_COLOR, basis)

