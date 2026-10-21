extends Node3D
## The ground outside the south castle gate. Coordinates are local to CastleSite.
## A few bounded terrain chunks replace thousands of individual ground tiles.

const X_MIN := -90.0
const X_MAX := 90.0
const Z_MIN := 76.0
const Z_MAX := 252.0
const CHUNKS_X := 3
const CHUNKS_Z := 3
const STEPS_X := 24
const STEPS_Z := 22
const CRATER_CENTERS := [Vector2(-20.0, 157.0), Vector2(14.0, 158.0), Vector2(25.0, 176.0),
	Vector2(-28.0, 216.0), Vector2(67.0, 207.0)]
const BURN_CENTERS := [Vector2(-28.0, 151.0), Vector2(33.0, 171.0),
	Vector2(4.0, 166.0), Vector2(-65.0, 206.0), Vector2(16.0, 222.0),
	Vector2(-14.0, 116.0), Vector2(17.0, 131.0)]

var _built := false
var _chunks := 0
var _vertices := 0
var _triangles := 0
var _landmarks: Dictionary = {}
var _terrain_material: Material

func install(world: Node3D, castle: Node3D) -> Dictionary:
	if _built:
		return {"ok": false, "reason": "already_installed"}
	if not is_instance_valid(world) or not is_instance_valid(castle):
		return {"ok": false, "reason": "missing_world_or_castle"}
	if get_parent() != world:
		if get_parent() != null:
			get_parent().remove_child(self)
		world.add_child(self)
	global_position = castle.global_position
	name = "BattlefieldSite"
	set_meta("battlefield", true)
	var soil := ShaderMaterial.new()
	soil.shader = load("res://assets/terrain/soil47.gdshader")
	soil.set_shader_parameter("macro_map", _make_grit_texture())
	soil.set_shader_parameter("soil_detail", load("res://assets/terrain/soil_detail47.png"))
	_terrain_material = soil
	_build_terrain()
	_build_landmarks()
	var cover := load("res://scripts/city/battlefield_ground_cover49.gd").new() as Node3D
	add_child(cover)
	cover.install(self, world)
	_built = true
	return {"ok": true, "stats": get_stats(), "landmarks": get_landmarks()}

func get_stats() -> Dictionary:
	return {"terrain_chunks": _chunks, "terrain_draw_calls_max": _chunks,
		"terrain_vertices": _vertices, "terrain_triangles": _triangles,
		"terrain_collision_shapes": _chunks, "bounds_local": [X_MIN, Z_MIN, X_MAX, Z_MAX]}

func get_landmarks() -> Dictionary:
	return _landmarks.duplicate(true)

func _make_grit_texture() -> Texture2D:
	# Shared offline colour/material bake: irregular worn ground and wheel tracks.
	# One texture for all nine chunks; geometry and physics remain unchanged.
	return load("res://assets/terrain/soil_macro49.png")

func terrain_height(x: float, z: float) -> float:
	# Near the original forecourt and at the outer edge, fade to CastleGround.
	# The central x+-13 m at z<110 stays *below* the existing gate road.
	# The stone forecourt narrows from pavers (x+-11.6, ending near z=90)
	# to the older 11 m road box. Bury only the footprint actually paved;
	# the former x+-16.5 mask exposed a green grass band alongside it.
	var paved_half := lerpf(11.6, 5.5, smoothstep(89.5, 92.5, z))
	var old_road := (1.0 - smoothstep(107.0, 113.0, z)) * (1.0 - smoothstep(paved_half - 0.6, paved_half + 0.4, absf(x)))
	var edge_x := 1.0 - smoothstep(76.0, 90.0, absf(x))
	var edge_z := 1.0 - smoothstep(240.0, 252.0, z)
	# Meet the paved ring road at z=79 from underneath, then emerge as packed
	# earth. The centre remains buried below the older stone gate approach.
	var start_z := smoothstep(76.0, 83.0, z)
	var noise := sin(x * 0.16 + z * 0.087) * sin(z * 0.13 - x * 0.061)
	var undulation := 0.12 + 0.09 * noise
	# Earthen defence line is broken in three deliberate, wide walkable passages.
	var defence := exp(-pow((z - 122.0) / 7.5, 2.0))
	var passage := minf(absf(x - _route_x(z, 0)),
		minf(absf(x - _route_x(z, -1)), absf(x - _route_x(z, 1))))
	var bank := 2.05 * defence * smoothstep(6.0, 16.0, passage)
	# Long shoulders frame the road from player height. The middle x+-5 and both
	# x+-47 flank lanes remain low; defenders can still cross their own field.
	var shoulder_zone := smoothstep(116.0, 140.0, z) * (1.0 - smoothstep(209.0, 237.0, z))
	var shoulders := 1.23 * exp(-pow((absf(x) - 17.5) / 7.4, 2.0)) * shoulder_zone
	# Broad shoulders break the flat horizon without obstructing the three
	# approach lanes; they are part of this same physical mesh.
	var hill := 1.18 * exp(-pow((x + 28.0) / 13.0, 2.0) - pow((z - 177.0) / 16.0, 2.0))
	hill += 0.95 * exp(-pow((x - 29.0) / 14.0, 2.0) - pow((z - 195.0) / 13.0, 2.0))
	hill += 0.70 * exp(-pow((x + 68.0) / 12.0, 2.0) - pow((z - 225.0) / 15.0, 2.0))
	# A crater is a low centre surrounded by a rounded rim. The centre cannot
	# be below y=0 because the existing CastleGround collider remains intact.
	var craters := 0.0
	for center: Vector2 in CRATER_CENTERS:
		var radius := Vector2(x - center.x, z - center.y).length()
		craters += 0.68 * exp(-pow((radius - 6.5) / 2.7, 2.0))
	var road := _road_weight(x, z)
	var h := (undulation + bank + shoulders + hill + craters) * (1.0 - road * 0.72)
	var rut := (1.0 - smoothstep(0.32, 0.85,
		absf(absf(x - _route_x(z, 0)) - 2.1))) * road
	h -= 0.035 * rut
	var coverage := minf(edge_x, minf(edge_z, start_z))
	# Physically sink the outermost vertices under CastleGround; this removes
	# the rectangular seam even where the two materials have different lighting.
	var visible_height := h * edge_x * edge_z * start_z + 0.018 - 0.072 * (1.0 - coverage)
	return lerpf(visible_height, -0.07, old_road)

func _route_x(z: float, lane: int) -> float:
	var t := clampf((z - 105.0) / 140.0, 0.0, 1.0)
	if lane == 0:
		return 2.5 * sin(t * TAU * 0.8) * sin(t * PI)
	return float(lane) * (47.0 + 3.5 * sin(t * TAU * 0.65 + 0.4))

func _road_weight(x: float, z: float) -> float:
	var center := 1.0 - smoothstep(4.8, 10.4, absf(x - _route_x(z, 0)))
	var left := 1.0 - smoothstep(3.4, 8.0, absf(x - _route_x(z, -1)))
	var right := 1.0 - smoothstep(3.4, 8.0, absf(x - _route_x(z, 1)))
	return maxf(center, maxf(left, right))

func _ground_color(x: float, z: float) -> Color:
	var grass := Color(0.31, 0.39, 0.235)
	var dirt := Color(0.395, 0.305, 0.225)
	var road := Color(0.285, 0.247, 0.195)
	var ash := Color(0.17, 0.16, 0.145)
	# The last visible terrain vertices are buried by CastleGround near z=248.
	# Blend colour before that occlusion point so the soil does not end in a
	# sharp brown line against the existing green plane.
	var edge := maxf(smoothstep(73.0, 88.0, absf(x)), smoothstep(226.0, 246.0, z))
	var track := _road_weight(x, z)
	var churn := 0.13 + 0.24 * absf(sin(x * 0.43 + z * 0.11) * sin(z * 0.29 - x * 0.07))
	var color := grass.lerp(dirt, churn)
	# The siege has worn away the grass along the south wall. This closes the
	# bright green strip left between the ring road and the old terrain start.
	var wall_trample := 1.0 - smoothstep(80.0, 111.0, z)
	var trample_variation := 0.76 + 0.15 * sin(x * 0.31 + z * 0.23) * sin(z * 0.41 - x * 0.17)
	color = color.lerp(dirt.darkened(0.12), wall_trample * trample_variation)
	# Dark, irregular burn scars; the low-frequency edge is much less tiled than a decal.
	var scorch := 0.0
	for center: Vector2 in BURN_CENTERS:
		var ellipse := Vector2((x - center.x) / 18.0, (z - center.y) / 11.0)
		var radius := ellipse.length() + 0.19 * sin(x * 0.42 + z * 0.23)
		scorch = maxf(scorch, 1.0 - smoothstep(0.55, 1.15, radius))
	# The ditch is cut into the existing ground only visually: the dark muddy
	# channel lies between low banks, with wide unbroken crossings at each lane.
	var ditch := exp(-pow((z - 134.0) / 3.4, 2.0)) * (1.0 - track)
	color = color.lerp(Color(0.27, 0.25, 0.20), ditch * 0.64)
	color = color.lerp(road, track * (0.83 + 0.1 * sin(x * 0.61 + z * 0.14)))
	# Keep impact scars visible even where they cross the packed central road.
	color = color.lerp(ash, scorch * (0.72 if track > 0.5 else 0.84))
	# Two hoof/wheel ruts keep the road legible at a distance with zero extra meshes.
	var rut_offset := absf(x - _route_x(z, 0))
	var rut := (1.0 - smoothstep(0.25, 0.75, absf(rut_offset - 2.1))) * track
	color = color.darkened(rut * 0.24)
	# Compensate for the shared terrain tint at the buried edge; its last visible
	# vertices meet the CastleGround grass rather than outlining the mesh square.
	return color.lerp(Color(0.46, 0.66, 0.30), edge)

func _build_terrain() -> void:
	var step_x := (X_MAX - X_MIN) / float(CHUNKS_X)
	var step_z := (Z_MAX - Z_MIN) / float(CHUNKS_Z)
	for cz in CHUNKS_Z:
		for cx in CHUNKS_X:
			var x0 := X_MIN + float(cx) * step_x
			var z0 := Z_MIN + float(cz) * step_z
			_build_chunk(cx, cz, x0, z0, step_x, step_z)

func _build_chunk(cx: int, cz: int, x0: float, z0: float, span_x: float, span_z: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for iz in STEPS_Z + 1:
		for ix in STEPS_X + 1:
			var x := x0 + span_x * float(ix) / float(STEPS_X)
			var z := z0 + span_z * float(iz) / float(STEPS_Z)
			var h := terrain_height(x, z)
			vertices.append(Vector3(x, h, z))
			normals.append(Vector3.UP)
			colors.append(_ground_color(x, z))
			uvs.append(Vector2((x - X_MIN) / (X_MAX - X_MIN),
				(z - Z_MIN) / (Z_MAX - Z_MIN)))
	# Reuse adjacent sampled heights for smooth normals. Calling terrain_height
	# four extra times at every vertex made the crater math needlessly expensive.
	for iz in STEPS_Z + 1:
		for ix in STEPS_X + 1:
			var i := iz * (STEPS_X + 1) + ix
			var left := vertices[iz * (STEPS_X + 1) + maxi(ix - 1, 0)]
			var right := vertices[iz * (STEPS_X + 1) + mini(ix + 1, STEPS_X)]
			var near := vertices[maxi(iz - 1, 0) * (STEPS_X + 1) + ix]
			var far := vertices[mini(iz + 1, STEPS_Z) * (STEPS_X + 1) + ix]
			normals[i] = (far - near).cross(right - left).normalized()
	for iz in STEPS_Z:
		for ix in STEPS_X:
			var a := iz * (STEPS_X + 1) + ix
			var b := a + 1
			var c := a + STEPS_X + 1
			var d := c + 1
			# Godot renders clockwise front faces; these triangles face upward.
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.name = "Terrain_%d_%d" % [cx, cz]
	visual.mesh = mesh
	visual.material_override = _terrain_material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.set_meta("surface", "battlefield_ground")
	visual.set_meta("vegetation", "grass")
	visual.set_meta("road", "path")
	add_child(visual)
	# The shared CastleGround remains underneath. Each simple triangle terrain shape
	# follows the visible bank, so fighters neither float over nor sink into it.
	var body := StaticBody3D.new()
	body.name = "TerrainCollision_%d_%d" % [cx, cz]
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("surface", "dirt")
	body.set_meta("battlefield_ground", true)
	add_child(body)
	var shape := CollisionShape3D.new()
	var terrain_shape := mesh.create_trimesh_shape()
	# Godot's mesh front-face winding differs from the triangle normal convention
	# in some physics backends. The player must collide from above in either one.
	terrain_shape.backface_collision = true
	shape.shape = terrain_shape
	body.add_child(shape)
	_chunks += 1
	_vertices += vertices.size()
	_triangles += indices.size() / 3

func _build_landmarks() -> void:
	_landmarks = {
		# Defenders muster inside the south courtyard, clear of the keep, siege
		# engine at z=48, loose stone at (3.2,50.4), and stair at x=-28.6.
		"defender_spawn": Vector3(0.0, 0.05, 27.0),
		"defender_left": Vector3(-18.0, 0.05, 37.0),
		"defender_right": Vector3(18.0, 0.05, 37.0),
		# Keep the old exterior staging points under explicit names. They are
		# useful for sorties and artillery crews, not defender spawning.
		"forecourt_center": Vector3(0.0, 0.05, 96.0),
		"forecourt_left": Vector3(-28.0, terrain_height(-28.0, 103.0), 103.0),
		"forecourt_right": Vector3(28.0, terrain_height(28.0, 103.0), 103.0),
		"attacker_spawn": Vector3(0.0, terrain_height(0.0, 229.0), 229.0),
		"attacker_left": Vector3(-43.0, terrain_height(-43.0, 226.0), 226.0),
		"attacker_right": Vector3(43.0, terrain_height(43.0, 226.0), 226.0),
		"left_flank": Vector3(-49.0, terrain_height(-49.0, 155.0), 155.0),
		"right_flank": Vector3(49.0, terrain_height(49.0, 155.0), 155.0),
		"catapult_lane": Vector3(14.0, terrain_height(14.0, 199.0), 199.0),
		"central_approach": Vector3(0.0, terrain_height(0.0, 156.0), 156.0),
	}
