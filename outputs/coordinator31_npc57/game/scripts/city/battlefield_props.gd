extends Node3D
## Siege-camp dressing. All coordinates are local to the battlefield origin.
## Static repeated pieces are batched by mesh/material and 55 m visibility cell.

const SEED := 318726
const SHARD_LIMIT := 20
const SHARD_LIFE := 5.0

var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _batch_materials: Dictionary = {}
var _meshes: Dictionary = {}
var _pending: Dictionary = {}
var _batches: Dictionary = {}
var _groups: Dictionary = {}
var _shards: Array[Dictionary] = []
var _stats: Dictionary = {}
var _installed := false

func install(_castle: Node3D) -> Dictionary:
	if _installed:
		return get_stats()
	_installed = true
	_rng.seed = SEED
	_make_resources()
	_stats = {"carts": 0, "tents": 0, "barriers": 0, "watchtowers": 0, "trees": 0, "crates": 0, "barrels": 0, "shields": 0, "firepits": 0, "stone_piles": 0, "smoke_plumes": 0, "stones": 0, "grass": 0, "mesh_instances": 0, "mesh_pieces": 0, "colliders": 0, "breakable_groups": 0, "batches_by_z_sector": {}}
	_build_siege_line()
	_build_camp()
	_build_active_siege()
	_build_terrain_dressing()
	_flush_batches()
	_stats["breakable_groups"] = _groups.size()
	set_process(false)
	return get_stats()

func get_stats() -> Dictionary:
	return _stats.duplicate(true)

func _make_resources() -> void:
	_material("oak", Color(0.35, 0.20, 0.11), 0.94)
	_material("oak_edge", Color(0.22, 0.115, 0.065), 0.97)
	_material("char", Color(0.105, 0.095, 0.083), 1.0)
	_material("iron", Color(0.16, 0.18, 0.19), 0.82)
	_material("rust", Color(0.31, 0.175, 0.105), 0.95)
	_material("canvas", Color(0.59, 0.48, 0.32), 1.0)
	_material("canvas_dark", Color(0.37, 0.30, 0.24), 1.0)
	_material("red", Color(0.42, 0.09, 0.085), 0.95)
	_material("red_edge", Color(0.63, 0.38, 0.12), 0.86)
	_material("stone", Color(0.43, 0.42, 0.37), 1.0)
	_material("stone_dark", Color(0.25, 0.25, 0.24), 1.0)
	_material("ash", Color(0.17, 0.16, 0.14), 1.0)
	_material("grass", Color(0.29, 0.31, 0.17), 1.0)
	_material("grass_dry", Color(0.45, 0.38, 0.20), 1.0)
	_material("rope", Color(0.48, 0.36, 0.22), 1.0)
	_material("ember", Color(0.87, 0.28, 0.07), 0.75)
	var ember: StandardMaterial3D = _materials["ember"]
	ember.emission_enabled = true
	ember.emission = Color(0.72, 0.16, 0.025)
	ember.emission_energy_multiplier = 0.8
	for bucket in ["solid", "detail", "vegetation_grass", "glow"]:
		var shared := StandardMaterial3D.new()
		shared.albedo_color = Color.WHITE
		shared.roughness = 0.93
		shared.vertex_color_use_as_albedo = true
		shared.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		if bucket == "glow":
			shared.emission_enabled = true
			shared.emission = Color(0.72, 0.16, 0.025)
			shared.emission_energy_multiplier = 0.8
		_batch_materials[bucket] = shared
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_meshes["box"] = box
	var drum := CylinderMesh.new()
	drum.top_radius = 0.5
	drum.bottom_radius = 0.5
	drum.height = 1.0
	drum.radial_segments = 12
	_meshes["drum"] = drum
	var cone := CylinderMesh.new()
	cone.top_radius = 0.22
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 7
	_meshes["cone"] = cone
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.42
	wheel.outer_radius = 0.54
	wheel.rings = 16
	wheel.ring_segments = 7
	_meshes["wheel"] = wheel
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 7
	rock.rings = 4
	_meshes["rock"] = rock
	_meshes["tent_roof"] = _make_tent_roof()

func _make_tent_roof() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ridge_l := Vector3(-3.08, 3.72, 0)
	var ridge_r := Vector3(3.08, 3.72, 0)
	for side in [-1.0, 1.0]:
		var eave_l := Vector3(-3.08, 0.32, side * 2.58)
		var eave_r := Vector3(3.08, 0.32, side * 2.58)
		_roof_triangle(st, ridge_l, ridge_r, eave_r)
		_roof_triangle(st, ridge_l, eave_r, eave_l)
	# Closed rear gable; the front has a real aperture in the canvas mesh.
	_roof_triangle(st, Vector3(-3.08, 3.72, 0), Vector3(-3.08, 0.32, -2.58), Vector3(-3.08, 0.32, 2.58))
	var lintel_y := 2.15
	var shoulder_z := 2.58 * (3.72 - lintel_y) / 3.4
	for side in [-1.0, 1.0]:
		var eave := Vector3(3.08, 0.32, side * 2.58)
		var foot := Vector3(3.08, 0.32, side * 0.85)
		var corner := Vector3(3.08, lintel_y, side * 0.85)
		var shoulder := Vector3(3.08, lintel_y, side * shoulder_z)
		_roof_triangle(st, eave, foot, corner)
		_roof_triangle(st, eave, corner, shoulder)
	_roof_triangle(st, Vector3(3.08, 3.72, 0),
		Vector3(3.08, lintel_y, -shoulder_z), Vector3(3.08, lintel_y, shoulder_z))
	st.generate_normals()
	return st.commit()

func _roof_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Explicit back faces keep the canvas visible from the camp and from inside.
	for v in [a, b, c, c, b, a]:
		st.add_vertex(v)

func _material(id: String, color: Color, roughness: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	_materials[id] = m

func _terrain_y(x: float, z: float) -> float:
	var terrain := get_parent()
	if is_instance_valid(terrain) and terrain.has_method("terrain_height"):
		return float(terrain.call("terrain_height", x, z))
	return 0.0

func _piece(mesh: String, material: String, pos: Vector3, size: Vector3, rotation := Vector3.ZERO, group := "", no_shadow := false) -> void:
	# Looking along the assault axis spans both flanks; two depth sectors cull the
	# distant camp while avoiding a separate draw call for each side of the road.
	var cell := Vector2i(0, int(floor((pos.z - 80.0) / 85.0)))
	# Small opaque rubble shares the same batch as large opaque cover: both use
	# vertex colours and only wheel/tent-roof meshes may cast shadows.
	var bucket := "vegetation_grass" if material in ["grass", "grass_dry"] else ("glow" if material == "ember" else "solid")
	var key := "%s|%s|%d|%d" % [mesh, bucket, cell.x, cell.y]
	if not _pending.has(key):
		_pending[key] = {"mesh": mesh, "bucket": bucket, "cell": cell, "no_shadow": no_shadow, "parts": []}
	var lift := float(_groups[group]["ground_offset"]) if group != "" and _groups.has(group) else _terrain_y(pos.x, pos.z)
	# Rotate *after* local scaling. Global scaling flattened wagon wheels and roof slopes.
	var xf := Transform3D(Basis.from_euler(rotation) * Basis().scaled(size), pos + Vector3.UP * lift)
	(_pending[key]["parts"] as Array).append({"xf": xf, "group": group, "color": (_materials[material] as StandardMaterial3D).albedo_color})
	_stats["mesh_pieces"] += 1

func _box(material: String, pos: Vector3, size: Vector3, rotation := Vector3.ZERO, group := "", no_shadow := false) -> void:
	_piece("box", material, pos, size, rotation, group, no_shadow)

func _flush_batches() -> void:
	var keys := _pending.keys()
	keys.sort()
	for key in keys:
		var record: Dictionary = _pending[key]
		var pieces: Array = record["parts"]
		var base: Mesh = _meshes[record["mesh"]]
		var mesh: Mesh = base.duplicate()
		mesh.surface_set_material(0, _batch_materials[record["bucket"]])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = pieces.size()
		for i in pieces.size():
			var item: Dictionary = pieces[i]
			mm.set_instance_transform(i, item["xf"])
			mm.set_instance_color(i, item["color"])
			if item["group"] != "":
				(_groups[item["group"]]["indices"] as Array).append([key, i])
		var node := MultiMeshInstance3D.new()
		node.name = "Batched_%s" % key.replace("|", "_")
		node.multimesh = mm
		var casts_shadow: bool = record["mesh"] in ["tent_roof", "wheel"] and not record["no_shadow"]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if record["bucket"] == "vegetation_grass":
			node.set_meta("category", "vegetation_grass")
		add_child(node)
		_batches[key] = node
		_stats["mesh_instances"] += 1
		var sector := str((record["cell"] as Vector2i).y)
		var sectors: Dictionary = _stats["batches_by_z_sector"]
		sectors[sector] = int(sectors.get(sector, 0)) + 1
	_pending.clear()

func _group(id: String, center: Vector3, health: float, kind: String, collision_size := Vector3.ZERO) -> void:
	var lift := _terrain_y(center.x, center.z)
	_groups[id] = {"center": center + Vector3.UP * lift, "ground_offset": lift, "reach": maxf(2.2, collision_size.x * 0.5), "height": collision_size.y, "health": health, "kind": kind, "indices": [], "collider": null, "destroyed": false}
	if collision_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.name = "Cover_%s" % id
		body.position = center + Vector3.UP * (lift + collision_size.y * 0.5)
		body.set_meta("category", "cover")
		body.set_meta("battlefield_group", id)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = collision_size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		_groups[id]["collider"] = body
		_stats["colliders"] += 1

func _build_siege_line() -> void:
	# Two layered barricades; the gate road and routes round both wings stay open.
	for side in [-1.0, 1.0]:
		for row in 2:
			for i in 3:
				var p := Vector3(side * (21.0 + i * 5.0 + row * 2.0), 0, 103.0 + row * 18.0 + i * 2.1)
				_build_barricade(p, side, "barrier_%d_%d_%d" % [int(side), row, i])
	_build_cart(Vector3(63.0, 0, 143.0), 0.36, "cart_supply")
	_build_cart(Vector3(-63.0, 0, 158.0), -0.44, "cart_broken", true)
	_build_fallen_wheel(Vector3(-58.6, 0.18, 162.2), 0.76, 0.38)
	for side in [-1.0, 1.0]:
		for i in 2:
			_build_barricade(Vector3(side * (23.0 + i * 5.0), 0, 178.0 + i * 3.0), side, "outer_barrier_%d_%d" % [int(side), i])
		for row in 2:
			_build_palisade(Vector3(side * 21.0, 0, 149.0 + row * 31.0), side, "palisade_%d_%d" % [int(side), row])
	for p in [Vector3(-36, 0, 126), Vector3(36, 0, 166), Vector3(-48, 0, 177)]:
		_build_shield(p, _rng.randf_range(-1.0, 1.0), "")

func _build_barricade(p: Vector3, yaw: float, id: String) -> void:
	_group(id, p, 80.0, "wood", Vector3(3.8, 1.15, 1.4))
	var basis := Basis(Vector3.UP, yaw * 0.22)
	for j in 3:
		var z := (j - 1) * 0.42
		_box("oak_edge", p + basis * Vector3(0, 0.34 + j * 0.27, z), Vector3(3.8, 0.16, 0.20), Vector3(0, yaw * 0.22, 0), id)
	for x in [-1.55, 0.0, 1.55]:
		var stake := p + basis * Vector3(x, 0, -0.65)
		var rotation := Vector3(1.08, yaw * 0.22, 0)
		var stake_basis := Basis.from_euler(rotation)
		# Fit the actual tilted vertices to sloping terrain; group lift is applied later.
		var vertices: PackedVector3Array = _meshes["cone"].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var lowest := INF
		var group_lift := _terrain_y(p.x, p.z)
		for vertex: Vector3 in vertices:
			var point := stake + stake_basis * (vertex * Vector3(0.42, 1.36, 0.42))
			lowest = minf(lowest, point.y + group_lift - _terrain_y(point.x, point.z))
		var center := stake + Vector3.UP * (-lowest - 0.02)
		_piece("cone", "oak", center, Vector3(0.42, 1.36, 0.42), rotation, id)
		_box("iron", center + stake_basis * Vector3(0, -0.38, 0), Vector3(0.42, 0.1, 0.43), rotation, id)
	_stats["barriers"] += 1

func _build_palisade(p: Vector3, side: float, id: String) -> void:
	# Tall clustered pickets give the attackers a readable defensive line from 100 m.
	# One long damage group made all 23 stakes vanish when a stone struck one end.
	# Four touching panels keep the same batched meshes but make a local breach.
	var common_ground := _terrain_y(p.x, p.z)
	for section in 4:
		var first := section * 6
		var last: int = mini(first + 5, 22)
		var mid_x := (float(first + last) * 0.5 - 11.0) * 1.08
		var width := float(last - first + 1) * 1.08
		var section_id := "%s_section_%d" % [id, section]
		_group(section_id, p + Vector3(mid_x, 0, 0), 140.0, "wood",
			Vector3(width, 2.6, 0.85))
		# Preserve the original flat line across undulating ground; the new collider
		# and all its visual pieces must share one support height.
		var section_group: Dictionary = _groups[section_id]
		var lift_delta := common_ground - float(section_group["ground_offset"])
		section_group["ground_offset"] = common_ground
		var collider: StaticBody3D = section_group["collider"]
		collider.position.y += lift_delta
		# Keep the long top rail level, but drive every picket into the actual
		# bank below it. The previous common footing left up to a metre of air
		# under the end panels and an equally suspended collision box.
		var lowest_foot := common_ground
		var tallest_tip := 2.6
		for i in range(first, last + 1):
			var stake_x := p.x + (float(i) - 11.0) * 1.08
			lowest_foot = minf(lowest_foot, _terrain_y(stake_x, p.z) - 0.25)
			tallest_tip = maxf(tallest_tip, 3.0 + 0.6 * sin(float(i) * 1.7) + 0.35)
		var extra_depth := common_ground - lowest_foot
		var collider_shape: CollisionShape3D = collider.get_child(0) as CollisionShape3D
		var grounded_box := BoxShape3D.new()
		grounded_box.size = Vector3(width, tallest_tip + extra_depth, 0.85)
		collider_shape.shape = grounded_box
		collider.position.y += (tallest_tip - 2.6 - extra_depth) * 0.5
		section_group["center"] = p + Vector3(mid_x, lowest_foot, 0)
		section_group["height"] = grounded_box.size.y
		for i in range(first, last + 1):
			var x := (float(i) - 11.0) * 1.08
			var height := 3.0 + 0.6 * sin(float(i) * 1.7)
			var stake_foot := _terrain_y(p.x + x, p.z) - 0.25
			var stake_depth := maxf(0.0, common_ground - stake_foot)
			var center := p + Vector3(x, (height - stake_depth) * 0.5, 0)
			_piece("cone", "oak_edge" if i % 4 else "char", center,
				Vector3(0.42, height + stake_depth, 0.42), Vector3(0, 0, side * 0.08), section_id)
			_piece("cone", "iron", p + Vector3(x, height + 0.14, 0),
				Vector3(0.14, 0.42, 0.14), Vector3.ZERO, section_id)
		for height in [0.72, 1.63, 2.27]:
			_box("oak", p + Vector3(mid_x, height, -0.30),
				Vector3(width - 0.10, 0.16, 0.18), Vector3.ZERO, section_id)
		# Bracing belongs to the section it supports and leaves with that section.
		for brace_x in [-8.4, 0.0, 8.4]:
			if absf(brace_x - mid_x) <= width * 0.5:
				_box("oak_edge", p + Vector3(brace_x, 1.28, -0.65),
					Vector3(0.15, 2.6, 0.18), Vector3(-0.35, 0, 0), section_id)

func _build_cart(p: Vector3, yaw: float, id: String, broken := false) -> void:
	_group(id, p, 180.0, "wood", Vector3(3.9, 1.3, 2.2))
	_piece("rock", "ash", p + Vector3.UP * 0.025, Vector3(5.3, 0.045, 3.0), Vector3.ZERO, "", true)
	var b := Basis(Vector3.UP, yaw)
	# Slatted bed, four distinct corner posts, iron staples and separate rolling wheels.
	for j in 6:
		var z := (float(j) - 2.5) * 0.31
		_box("oak", p + b * Vector3(0, 1.05, z), Vector3(3.9, 0.13, 0.29), Vector3(0, yaw, 0), id)
	for side in [-1.0, 1.0]:
		for j in 3:
			_box("oak_edge", p + b * Vector3((j - 1) * 1.2, 1.50, side * 0.98), Vector3(1.27, 0.35, 0.11), Vector3(0, yaw, 0), id)
		for x in [-1.72, 1.72]:
			_box("oak", p + b * Vector3(x, 1.42, side * 0.98), Vector3(0.16, 1.0, 0.18), Vector3(0, yaw, 0), id)
		_box("iron", p + b * Vector3(0, 0.75, side * 0.84), Vector3(3.6, 0.10, 0.10), Vector3(0, yaw, 0), id)
		for x in [-1.18, 1.18]:
			if broken and side > 0 and x > 0:
				continue
			_build_wheel(p + b * Vector3(x, 0.83, side * 1.17), 0.83, yaw, id)
	for z in [-0.66, 0.66]:
		_box("oak_edge", p + b * Vector3(2.56, 0.83, z), Vector3(2.3, 0.14, 0.13), Vector3(0, yaw, 0), id)
	_box("iron", p + b * Vector3(3.65, 0.70, 0), Vector3(0.14, 0.10, 1.65), Vector3(0, yaw, 0), id)
	if not broken:
		for i in 5:
			var xp := _rng.randf_range(-1.35, 1.35)
			var zp := _rng.randf_range(-0.55, 0.55)
			_build_crate(p + b * Vector3(xp, 1.15, zp), 0.47, "cart_crate_%d" % i, false, id)
			# Cargo shares the cart body: dropped shields and bodies rest on visible crates.
			# The single owner collider removes every cargo shape with the cart.
			var cargo_shape := CollisionShape3D.new()
			var cargo_box := BoxShape3D.new()
			cargo_box.size = Vector3.ONE * 0.47
			cargo_shape.shape = cargo_box
			cargo_shape.position = b * Vector3(xp, 1.385 - 0.65, zp)
			(_groups[id]["collider"] as StaticBody3D).add_child(cargo_shape)
		_piece("drum", "canvas_dark", p + b * Vector3(-0.65, 1.54, 0.20), Vector3(0.66, 1.55, 0.66), Vector3(0, yaw, PI * 0.5), id)
		# The rolled canvas axis is local X after the quarter-turn around Z.
		for dx in [-0.28, 0.28]:
			_piece("drum", "rope", p + b * Vector3(-0.65 + dx, 1.54, 0.20), Vector3(0.69, 0.06, 0.69), Vector3(0, yaw, PI * 0.5), id)
	else:
		for i in 7:
			var offset := Vector3(_rng.randf_range(-4, -1.5), 0, _rng.randf_range(-2, 2))
			_box("oak", p + b * offset + Vector3.UP * 0.08, Vector3(_rng.randf_range(0.45, 1.25), 0.10, 0.13), Vector3(0, yaw + _rng.randf_range(-0.8, 0.8), 0), "", true)
	_stats["carts"] += 1

func _build_wheel(p: Vector3, radius: float, yaw: float, group: String) -> void:
	# Torus axis is Y; turn into a vertical wheel and attach radial wooden spokes.
	_piece("wheel", "oak_edge", p, Vector3(radius * 2.0, 0.23, radius * 2.0), Vector3(PI * 0.5, yaw, 0), group)
	_piece("drum", "iron", p, Vector3(0.27, 0.29, 0.27), Vector3(PI * 0.5, yaw, 0), group)
	for i in 8:
		var a := float(i) * TAU / 8.0
		var radial := Basis(Vector3.UP, yaw) * Vector3(cos(a), sin(a), 0)
		_box("oak", p + radial * radius * 0.45, Vector3(radius * 0.95, 0.09, 0.10), Vector3(0, yaw, a), group)

func _build_fallen_wheel(p: Vector3, radius: float, yaw: float) -> void:
	# A loose wheel lies flat as one rigid arrangement, even on uneven terrain.
	var parts: Array[Dictionary] = [
		{"mesh": "wheel", "material": "oak_edge", "p": p, "size": Vector3(radius * 2.0, 0.23, radius * 2.0), "rotation": Vector3(0, yaw, 0)},
		{"mesh": "drum", "material": "iron", "p": p, "size": Vector3(0.27, 0.29, 0.27), "rotation": Vector3(0, yaw, 0)}
	]
	for i in 8:
		var a := float(i) * TAU / 8.0
		var radial := Basis(Vector3.UP, yaw) * Vector3(cos(a), 0, sin(a))
		parts.append({"mesh": "box", "material": "oak", "p": p + radial * radius * 0.45,
			"size": Vector3(radius * 0.95, 0.09, 0.10), "rotation": Vector3(0, yaw - a, 0)})
	# Lean onto the rim as well as the projecting hub, avoiding a hovering hoop.
	var lean := Basis(Vector3.RIGHT, 0.18)
	for part: Dictionary in parts:
		part.p = p + lean * (part.p - p)
		part.rotation = (lean * Basis.from_euler(part.rotation)).get_euler()
	var terrain_lift := _terrain_y(p.x, p.z)
	var lowest := INF
	for part: Dictionary in parts:
		var basis := Basis.from_euler(part.rotation) * Basis().scaled(part.size)
		var vertices: PackedVector3Array = _meshes[part.mesh].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var point: Vector3 = part.p + basis * vertex
			lowest = minf(lowest, point.y + terrain_lift - _terrain_y(point.x, point.z))
	for part: Dictionary in parts:
		var point: Vector3 = part.p
		# Cancel per-piece terrain offsets so spokes remain attached to their rim.
		point.y += terrain_lift - _terrain_y(point.x, point.z) - lowest - 0.015
		_piece(part.mesh, part.material, point, part.size, part.rotation)

func _build_camp() -> void:
	for p in [Vector3(-77, 0, 198), Vector3(-65, 0, 205), Vector3(-33, 0, 224), Vector3(-33, 0, 240), Vector3(33, 0, 240), Vector3(33, 0, 205), Vector3(65, 0, 225), Vector3(77, 0, 202)]:
		_build_tent(p, "tent_%d" % _stats["tents"])
	for p in [Vector3(-53, 0, 195), Vector3(58, 0, 191), Vector3(-31, 0, 231), Vector3(31, 0, 231)]:
		_build_banner(p, "canvas_dark")
	for p in [Vector3(-16, 0, 157), Vector3(16, 0, 157)]:
		_build_banner(p)
	for p in [Vector3(-44, 0, 207), Vector3(43, 0, 221)]:
		_build_firepit(p)
	_build_cart(Vector3(-72, 0, 227), 0.18, "camp_cart_left")
	_build_cart(Vector3(72, 0, 232), -0.24, "camp_cart_right")
	_build_watchtower(Vector3(-79, 0, 164), "watchtower_left")
	_build_watchtower(Vector3(79, 0, 180), "watchtower_right")
	for p in [Vector3(-31, 0, 198), Vector3(35, 0, 220), Vector3(72, 0, 201)]:
		_build_barrel(p, 0.56, "barrel_%d" % _stats["barrels"])
	for p in [Vector3(-13, 0, 163), Vector3(13, 0, 171), Vector3(-15, 0, 190), Vector3(15, 0, 193)]:
		_build_barrel(p, 0.64, "front_barrel_%d" % _stats["barrels"])
		_build_shield(p + Vector3(1.25, 0, -0.7), 0.3, "")
		for i in 5:
			_box("oak_edge", p + Vector3(_rng.randf_range(-2.5, 2.5), 0.09, _rng.randf_range(-1.7, 1.7)), Vector3(_rng.randf_range(0.5, 1.6), 0.09, 0.16), Vector3(0, _rng.randf_range(0, TAU), 0), "", true)
	for i in 10:
		var side := -1.0 if i < 5 else 1.0
		var p := Vector3(side * _rng.randf_range(31, 76), 0, _rng.randf_range(185, 239))
		_build_crate(p, _rng.randf_range(0.45, 0.8), "crate_%d" % i)
	for p in [Vector3(-58, 0, 218), Vector3(50, 0, 217), Vector3(-33, 0, 190)]:
		_build_shield(p, _rng.randf_range(-0.8, 0.8), "")
	for i in 18:
		var side := -1.0 if i < 9 else 1.0
		var p := Vector3(side * _rng.randf_range(22.0, 80.0), 0, _rng.randf_range(139.0, 236.0))
		_build_discarded_spear(p, _rng.randf_range(0, TAU))

func _build_discarded_spear(p: Vector3, yaw: float) -> void:
	# A grounded shaft with a distinct iron leaf tip and leather wrapped grip.
	var b := Basis(Vector3.UP, yaw)
	_box("oak", p + b * Vector3(0, 0.055, 0), Vector3(0.055, 0.06, 2.75), Vector3(0, yaw, 0), "", true)
	_box("rope", p + b * Vector3(0, 0.075, -0.87), Vector3(0.082, 0.07, 0.34), Vector3(0, yaw, 0), "", true)
	_piece("cone", "iron", p + b * Vector3(0, 0.07, 1.55), Vector3(0.18, 0.48, 0.12), Vector3(PI * 0.5, yaw, 0), "", true)

func _build_active_siege() -> void:
	# Terrain owns the continuous, irregular wheel ruts; prop geometry must not
	# create regular bright road markings over them.
	for p in [Vector3(-10, 0, 139), Vector3(10, 0, 169), Vector3(-10, 0, 196), Vector3(10, 0, 211)]:
		_build_stone_pile(p, "stone_pile_%d" % _stats["stone_piles"])
	for p in [Vector3(-8, 0, 151), Vector3(8, 0, 163), Vector3(-8, 0, 183), Vector3(8, 0, 203), Vector3(-9, 0, 223)]:
		_build_shield(p, _rng.randf_range(-0.5, 0.5), "", true)
		for j in 4:
			var q: Vector3 = p + Vector3(_rng.randf_range(-2.2, 2.2), 0.075, _rng.randf_range(-1.5, 1.5))
			_box("oak_edge", q, Vector3(_rng.randf_range(0.7, 1.8), 0.09, 0.17), Vector3(0, _rng.randf_range(0, TAU), 0), "", true)
	for p in [Vector3(-26, 0, 149), Vector3(27, 0, 180), Vector3(-17, 0, 209)]:
		_build_smouldering_wreck(p)
	_build_watchtower(Vector3(-16, 0, 220), "command_tower_left")
	_build_watchtower(Vector3(16, 0, 220), "command_tower_right")
	for p in [Vector3(-28, 0, 200), Vector3(28, 0, 200), Vector3(-23, 0, 238), Vector3(23, 0, 238), Vector3(-71, 0, 153), Vector3(71, 0, 160)]:
		_build_tree(p, "tree_%d" % _stats["trees"])

func _build_stone_pile(p: Vector3, id: String) -> void:
	_group(id, p, 115.0, "stone", Vector3(2.45, 0.72, 2.0))
	_piece("rock", "ash", p + Vector3.UP * 0.035, Vector3(3.1, 0.055, 2.5), Vector3.ZERO, "", true)
	for i in 11:
		var x := _rng.randf_range(-1.12, 1.12)
		var z := _rng.randf_range(-0.86, 0.86)
		var h := _rng.randf_range(0.26, 0.54)
		_piece("rock", "stone" if i % 3 else "stone_dark", p + Vector3(x, h * 0.55, z), Vector3(h * 1.5, h, h * 1.18), Vector3(0, _rng.randf_range(0, TAU), 0), id)
	_stats["stone_piles"] += 1

func _build_smouldering_wreck(p: Vector3) -> void:
	_piece("rock", "ash", p + Vector3.UP * 0.03, Vector3(3.8, 0.05, 2.8), Vector3.ZERO, "", true)
	for i in 7:
		var q := p + Vector3(_rng.randf_range(-1.5, 1.5), 0.12, _rng.randf_range(-1.1, 1.1))
		_box("char", q, Vector3(_rng.randf_range(0.9, 2.2), 0.14, 0.19), Vector3(0, _rng.randf_range(0, TAU), 0), "", true)
	for i in 3:
		var glow := p + Vector3(_rng.randf_range(-0.48, 0.48), 0.13, _rng.randf_range(-0.35, 0.35))
		_piece("rock", "ember", glow, Vector3(0.18, 0.075, 0.15), Vector3.ZERO, "", true)
	_stats["smoke_plumes"] += 1

func _build_tent(p: Vector3, id: String) -> void:
	_group(id, p, 95.0, "canvas")
	_groups[id]["reach"] = 3.075 # Preserve the original stone-damage reach.
	# Ridge across the field, so the triangular gable faces approaching players.
	var yaw := PI * 0.5 + _rng.randf_range(-0.16, 0.16)
	var b := Basis(Vector3.UP, yaw)
	_tent_collision(id, yaw)
	_piece("tent_roof", "canvas", p, Vector3.ONE, Vector3(0, yaw, 0), id)
	for side in [-1.0, 1.0]:
		# Seam and rolled eave make the continuous cloth roof read at walking distance.
		_box("canvas_dark", p + b * Vector3(0, 0.36, side * 2.58), Vector3(6.12, 0.12, 0.10), Vector3(0, yaw, 0), id)
		for x in [-2.90, 2.90]:
			# Tie the roof slope to the existing peg instead of tilting a loose rod.
			var roof_tie := Vector3(x, 3.72 - 3.4 * 1.95 / 2.58, side * 1.95)
			var peg_tie := Vector3(x, 0.28, side * 3.55)
			var rope_delta := b * (roof_tie - peg_tie)
			var rope_rotation := Basis(Quaternion(Vector3.UP, rope_delta.normalized())).get_euler()
			_box("rope", p + b * (roof_tie + peg_tie) * 0.5,
				Vector3(0.055, rope_delta.length(), 0.055), rope_rotation, id)
			_piece("cone", "oak_edge", p + b * Vector3(x, 0.16, side * 3.55), Vector3(0.14, 0.32, 0.14), Vector3.ZERO, id)
	_box("oak_edge", p + Vector3.UP * 3.72, Vector3(6.2, 0.09, 0.09), Vector3(0, yaw, 0), id)
	for side in [-1.0, 1.0]:
		_box("oak", p + b * Vector3(side * 3.02, 1.85, 0), Vector3(0.11, 3.70, 0.11), Vector3.ZERO, id)
	# Ground cloth and folded entrance flap.
	_box("canvas_dark", p + Vector3.UP * 0.045, Vector3(5.88, 0.065, 5.02), Vector3(0, yaw, 0), id)
	_box("red", p + b * Vector3(3.22, 1.13, -1.44), Vector3(0.07, 2.15, 1.18), Vector3(0, yaw + 0.22, 0), id)
	_piece("rock", "ash", p + Vector3.UP * 0.025, Vector3(6.3, 0.045, 5.4), Vector3.ZERO, "", true)
	_stats["tents"] += 1

func _tent_collision(id: String, yaw: float) -> void:
	# One static body replaces the former solid box. Canvas follows the visible mesh.
	var body := StaticBody3D.new()
	body.name = "Cover_%s" % id
	body.position = _groups[id]["center"]
	body.rotation.y = yaw
	body.set_meta("category", "cover")
	body.set_meta("battlefield_group", id)
	var faces: PackedVector3Array = (_meshes["tent_roof"] as ArrayMesh).get_faces()
	var collision_faces := PackedVector3Array()
	# Visual mesh includes reverse triangles; physics uses one face with backface collision.
	for i in range(0, faces.size(), 6):
		for j in 3: collision_faces.append(faces[i + j])
	var canvas := ConcavePolygonShape3D.new()
	canvas.backface_collision = true
	canvas.set_faces(collision_faces)
	var canvas_shape := CollisionShape3D.new()
	canvas_shape.shape = canvas
	body.add_child(canvas_shape)
	for side in [-1.0, 1.0]:
		var post := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.11, 3.70, 0.11)
		post.shape = box
		post.position = Vector3(side * 3.02, 1.85, 0)
		body.add_child(post)
	var flap := CollisionShape3D.new()
	var flap_box := BoxShape3D.new()
	flap_box.size = Vector3(0.07, 2.15, 1.18)
	flap.shape = flap_box
	flap.position = Vector3(3.22, 1.13, -1.44)
	flap.rotation.y = 0.22
	body.add_child(flap)
	add_child(body)
	_groups[id]["collider"] = body
	_stats["colliders"] += 1

func _build_watchtower(p: Vector3, id: String) -> void:
	# A recognisable high silhouette at both ends of the attackers' line.
	_group(id, p, 220.0, "wood", Vector3(3.6, 5.2, 3.6))
	# The old full-volume box blocked stones under the visibly open tower.
	# Reuse its StaticBody and primary shape for the platform, then bound the
	# structural timbers. Destruction still removes the whole tower at once.
	var body: StaticBody3D = _groups[id]["collider"]
	var platform: CollisionShape3D = body.get_child(0) as CollisionShape3D
	var platform_box := BoxShape3D.new()
	platform_box.size = Vector3(3.6, 0.16, 3.65)
	platform.shape = platform_box
	platform.position = Vector3(0, 2.50, 0)
	for x in [-1.55, 1.55]:
		for z in [-1.55, 1.55]:
			_tower_shape(body, Vector3(0.26, 5.3, 0.26), Vector3(x, 0.05, z))
	for side in [-1.0, 1.0]:
		for level in [1.25, 3.15]:
			_tower_shape(body, Vector3(3.4, 0.15, 0.17), Vector3(0, level - 2.6, side * 1.54))
			_tower_shape(body, Vector3(0.17, 0.15, 3.4), Vector3(side * 1.54, level - 2.6, 0))
		_tower_shape(body, Vector3(0.15, 3.8, 0.17), Vector3(0, 0.02, side * 1.53),
			Vector3(0, 0, side * 0.69))
	var collision_brace_length := Vector2(3.1, 3.4).length()
	var collision_brace_angle := atan2(3.1, 3.4)
	for slope in [-1.0, 1.0]:
		_tower_shape(body, Vector3(0.15, collision_brace_length, 0.16), Vector3(0, -0.45, 1.54),
			Vector3(0, 0, slope * collision_brace_angle))
	for side in [-1.0, 1.0]:
		_tower_shape(body, Vector3(0.16, collision_brace_length, 0.15), Vector3(side * 1.54, -0.45, 0),
			Vector3(side * collision_brace_angle, 0, 0))
		_tower_shape(body, Vector3(0.11, 1.15, 3.62), Vector3(side * 1.70, 3.20, 0))
		_tower_shape(body, Vector3(3.62, 1.15, 0.11), Vector3(0, 3.20, side * 1.70))
	# A single ladder strip bounds its rungs without eleven extra physics shapes.
	_tower_shape(body, Vector3(1.1, 5.0, 0.10), Vector3(-1.0, 0, -1.93))
	for x in [-1.55, 1.55]:
		for z in [-1.55, 1.55]:
			_box("oak_edge", p + Vector3(x, 2.65, z), Vector3(0.26, 5.3, 0.26), Vector3.ZERO, id)
			_box("iron", p + Vector3(x, 0.8, z), Vector3(0.32, 0.11, 0.32), Vector3.ZERO, id)
	for side in [-1.0, 1.0]:
		for level in [1.25, 3.15]:
			_box("oak", p + Vector3(0, level, side * 1.54), Vector3(3.4, 0.15, 0.17), Vector3.ZERO, id)
			_box("oak", p + Vector3(side * 1.54, level, 0), Vector3(0.17, 0.15, 3.4), Vector3.ZERO, id)
		_box("oak", p + Vector3(0, 2.62, side * 1.53), Vector3(0.15, 3.8, 0.17), Vector3(0, 0, side * 0.69), id)
	# Cross braces tie the high platform to its legs. Keep the ladder face clear.
	var brace_length := Vector2(3.1, 3.4).length()
	var brace_angle := atan2(3.1, 3.4)
	for slope in [-1.0, 1.0]:
		_box("oak_edge", p + Vector3(0, 2.15, 1.54),
			Vector3(0.15, brace_length, 0.16), Vector3(0, 0, slope * brace_angle), id)
	for side in [-1.0, 1.0]:
		_box("oak_edge", p + Vector3(side * 1.54, 2.15, 0),
			Vector3(0.16, brace_length, 0.15), Vector3(side * brace_angle, 0, 0), id)
	for i in 9:
		_box("oak", p + Vector3((float(i) - 4.0) * 0.39, 5.1, 0), Vector3(0.37, 0.16, 3.65), Vector3.ZERO, id)
	for side in [-1.0, 1.0]:
		_box("oak_edge", p + Vector3(side * 1.70, 5.80, 0), Vector3(0.11, 1.15, 3.62), Vector3.ZERO, id)
		_box("oak_edge", p + Vector3(0, 5.80, side * 1.7), Vector3(3.62, 1.15, 0.11), Vector3.ZERO, id)
	for i in 11:
		_box("oak_edge", p + Vector3(-1.0, 0.35 + i * 0.43, -1.93), Vector3(1.1, 0.075, 0.12), Vector3.ZERO, id)
	_box("oak_edge", p + Vector3(-1.52, 2.6, -1.93), Vector3(0.10, 5.0, 0.10), Vector3.ZERO, id)
	_box("oak_edge", p + Vector3(-0.50, 2.6, -1.93), Vector3(0.10, 5.0, 0.10), Vector3.ZERO, id)
	_box("oak", p + Vector3(0, 6.48, 0), Vector3(0.12, 1.45, 0.12), Vector3.ZERO, id)
	_box("red", p + Vector3(0.64, 6.78, 0), Vector3(1.20, 0.72, 0.04), Vector3.ZERO, id)
	_stats["watchtowers"] += 1

func _tower_shape(body: StaticBody3D, size: Vector3, local_center: Vector3,
		rotation := Vector3.ZERO) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position = local_center
	collision.rotation = rotation
	body.add_child(collision)

func _build_banner(p: Vector3, cloth := "red") -> void:
	var id := "banner_%d" % int(_stats.get("banners", 0))
	# The visible pole is solid and all four parts fall with it on a hit.
	_group(id, p, 35.0, "wood", Vector3(0.13, 4.2, 0.13))
	# Keep blade damage on the timber pole, but release cloth and slats.
	_groups[id]["debris_kind"] = "canvas"
	_groups[id]["debris_cloth"] = cloth
	_box("oak_edge", p + Vector3.UP * 2.1, Vector3(0.13, 4.2, 0.13), Vector3.ZERO, id)
	_box("iron", p + Vector3.UP * 4.16, Vector3(1.25, 0.08, 0.08), Vector3.ZERO, id)
	_box(cloth, p + Vector3(0.87, 3.28, 0), Vector3(1.72, 1.74, 0.055), Vector3(0, 0, 0.08), id)
	_box("red_edge", p + Vector3(0.55, 2.87, 0.035), Vector3(1.0, 0.10, 0.028), Vector3.ZERO, id)
	_stats["banners"] = int(_stats.get("banners", 0)) + 1

func _build_crate(p: Vector3, size: float, id: String, collider := true, owner_group := "") -> void:
	if collider:
		_group(id, p, 25.0, "wood", Vector3.ONE * size)
	var half := size * 0.5
	var group := id if collider else owner_group
	_box("oak", p + Vector3.UP * half, Vector3(size, size, size), Vector3.ZERO, group)
	for side in [-1.0, 1.0]:
		_box("oak_edge", p + Vector3(0, half, side * half), Vector3(size * 0.92, size * 0.09, size * 0.08), Vector3(0, 0, 0.58), group)
		_box("iron", p + Vector3(side * half, half, 0), Vector3(size * 0.045, size * 0.90, size * 0.045), Vector3.ZERO, group)
	_stats["crates"] += 1

func _build_barrel(p: Vector3, size: float, id: String) -> void:
	_group(id, p, 30.0, "wood", Vector3(size, size * 1.5, size))
	_piece("drum", "oak", p + Vector3.UP * size * 0.72, Vector3(size, size * 1.42, size), Vector3.ZERO, id)
	for h in [0.19, 0.57, 1.12]:
		_piece("drum", "iron", p + Vector3.UP * h * size, Vector3(size * 1.05, size * 0.075, size * 1.05), Vector3.ZERO, id)
	_piece("drum", "oak_edge", p + Vector3.UP * size * 1.45, Vector3(size * 0.82, size * 0.065, size * 0.82), Vector3.ZERO, id)
	_stats["barrels"] += 1

func _build_shield(p: Vector3, yaw: float, group: String, fallen := false) -> void:
	var tilt := 0.11 if fallen else PI * 0.5 + 0.12
	var height := 0.13 if fallen else 0.73
	var rot := Vector3(tilt, yaw, 0.11)
	var basis := Basis.from_euler(rot)
	var ground_chunks: Array[Dictionary] = []
	var terrain := get_parent()
	for child: Node in terrain.get_children():
		if not child is MeshInstance3D or child.get_meta("surface", "") != "battlefield_ground": continue
		var bounds: AABB = child.mesh.get_aabb()
		if p.x + 1.0 < bounds.position.x or p.x - 1.0 > bounds.end.x or p.z + 1.0 < bounds.position.z or p.z - 1.0 > bounds.end.z: continue
		var arrays: Array = child.mesh.surface_get_arrays(0)
		ground_chunks.append({"bounds": bounds, "vertices": arrays[Mesh.ARRAY_VERTEX],
			"indices": arrays[Mesh.ARRAY_INDEX], "steps_x": terrain.STEPS_X, "steps_z": terrain.STEPS_Z})
	var lift := float(_groups[group]["ground_offset"]) if group != "" and _groups.has(group) else _terrain_y(p.x, p.z)
	var lowest := INF
	# Ground the whole shield without separating its face, rim and boss.
	for part: Array in [["drum", Vector3(1.26, 0.10, 1.26)], ["wheel", Vector3(1.28, 0.13, 1.28)], ["drum", Vector3(0.27, 0.15, 0.27)]]:
		var vertices: PackedVector3Array = _meshes[part[0]].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var point: Vector3 = p + Vector3.UP * (height + lift) + basis * (vertex * part[1])
			lowest = minf(lowest, point.y - _shield_ground_height(point.x, point.z, ground_chunks))
	height -= lowest + 0.015
	_piece("drum", "red", p + Vector3.UP * height, Vector3(1.26, 0.10, 1.26), rot, group)
	_piece("wheel", "iron", p + Vector3.UP * height, Vector3(1.28, 0.13, 1.28), rot, group)
	_piece("drum", "iron", p + Vector3.UP * height, Vector3(0.27, 0.15, 0.27), rot, group)
	_stats["shields"] += 1

func _shield_ground_height(x: float, z: float, chunks: Array[Dictionary]) -> float:
	# Use the existing visible/collision triangles, not the unsampled height formula.
	for chunk: Dictionary in chunks:
		var bounds: AABB = chunk.bounds
		if x < bounds.position.x or x > bounds.end.x or z < bounds.position.z or z > bounds.end.z: continue
		var gx: float = (x - bounds.position.x) / bounds.size.x * chunk.steps_x
		var gz: float = (z - bounds.position.z) / bounds.size.z * chunk.steps_z
		var ix := clampi(int(floor(gx)), 0, int(chunk.steps_x) - 1)
		var iz := clampi(int(floor(gz)), 0, int(chunk.steps_z) - 1)
		var offset: int = (iz * chunk.steps_x + ix) * 6 + (0 if gx - ix + gz - iz <= 1.0 else 3)
		var a: Vector3 = chunk.vertices[chunk.indices[offset]]
		var b: Vector3 = chunk.vertices[chunk.indices[offset + 1]]
		var c: Vector3 = chunk.vertices[chunk.indices[offset + 2]]
		var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		var wa := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / denominator
		var wb := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / denominator
		return wa * a.y + wb * b.y + (1.0 - wa - wb) * c.y
	return _terrain_y(x, z)

func _build_firepit(p: Vector3) -> void:
	for i in 9:
		var angle := TAU * float(i) / 9.0
		var q := p + Vector3(cos(angle) * 0.82, 0.11, sin(angle) * 0.82)
		_piece("rock", "stone_dark", q, Vector3(0.37, 0.22, 0.31), Vector3(0, angle, 0), "", true)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		_box("char", p + Vector3(cos(angle) * 0.25, 0.12, sin(angle) * 0.25), Vector3(0.60, 0.16, 0.12), Vector3(0, angle, 0), "", true)
	_piece("rock", "ember", p + Vector3.UP * 0.12, Vector3(0.14, 0.07, 0.14), Vector3.ZERO, "", true)
	_stats["firepits"] += 1

func _build_terrain_dressing() -> void:
	# Scars, charred growth and rubble are deterministic. The road is kept clean.
	for p in [Vector3(-81, 0, 112), Vector3(79, 0, 145), Vector3(-75, 0, 180), Vector3(83, 0, 205), Vector3(-88, 0, 226)]:
		_build_tree(p, "tree_%d" % _stats["trees"])
	for i in 115:
		var x := _rng.randf_range(-91.0, 91.0)
		var z := _rng.randf_range(92.0, 249.0)
		if absf(x) < 13.0:
			continue
		var p := Vector3(x, 0, z)
		if i % 4 == 0:
			_piece("rock", "ash", p + Vector3.UP * 0.02, Vector3(_rng.randf_range(0.9, 2.3), 0.055, _rng.randf_range(0.6, 1.4)), Vector3(0, _rng.randf_range(0, TAU), 0), "", true)
		else:
			var s := _rng.randf_range(0.25, 0.95)
			_piece("rock", "stone" if i % 3 else "stone_dark", p + Vector3.UP * s * 0.28, Vector3(s, s * 0.55, s * 0.79), Vector3(0, _rng.randf_range(0, TAU), 0), "", true)
			_stats["stones"] += 1
	for i in 240:
		var x := _rng.randf_range(-92, 92)
		var z := _rng.randf_range(85, 249)
		if absf(x) < 12.0 or (z > 186 and 31.0 < absf(x) and absf(x) < 72.0):
			continue
		var p := Vector3(x, 0.19, z)
		var s := _rng.randf_range(0.19, 0.48)
		for j in 2:
			var rotation := Vector3(0, _rng.randf_range(0, TAU), _rng.randf_range(-0.4, 0.4))
			# Match the rotated blade's lower edge to terrain, with a small buried root.
			var half_height := (s * absf(cos(rotation.z)) + 0.035 * absf(sin(rotation.z))) * 0.5
			var blade := Vector3(p.x + j * 0.08, half_height - 0.015, p.z)
			_box("grass_dry" if i % 3 else "grass", blade, Vector3(0.035, s, 0.018), rotation, "", true)
		_stats["grass"] += 1

func _build_tree(p: Vector3, id: String) -> void:
	var tall := _rng.randf_range(5.8, 8.1)
	_group(id, p, 120.0, "wood", Vector3(0.9, tall, 0.9))
	var trunk_rotation := Vector3(0, _rng.randf_range(0, TAU), 0.08)
	var trunk_basis := Basis.from_euler(trunk_rotation)
	_piece("cone", "char", p + Vector3.UP * tall * 0.5, Vector3(1.08, tall, 1.08), trunk_rotation, id)
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.3
		var high := tall * (0.51 + float(i % 2) * 0.14)
		# Start inside the actual tilted trunk, then grow outward and upward.
		var start := p + Vector3.UP * tall * 0.5 + trunk_basis * Vector3(0, high - tall * 0.5, 0)
		var tip := start + Vector3(cos(a) * tall * 0.23, tall * 0.24, sin(a) * tall * 0.23)
		var direction := tip - start
		var rotation := Basis(Quaternion(Vector3.UP, direction.normalized())).get_euler()
		_box("char", (start + tip) * 0.5, Vector3(0.22, direction.length(), 0.22), rotation, id)
	for i in 3:
		var a := float(i) * TAU / 3.0
		_box("oak_edge", p + Vector3(cos(a) * 0.62, 0.15, sin(a) * 0.62), Vector3(1.4, 0.15, 0.19), Vector3(0, a, 0), id)
	_stats["trees"] += 1

## Called by weapon/projectile integration. Nothing is simulated while undamaged.
## A blade cuts wooden cover only. A stone also tears down canvas and shields.
func apply_damage(world_point: Vector3, radius: float, impulse: float, damage_type := "stone") -> int:
	var local_point := to_local(world_point)
	var hit := 0
	for id in _groups:
		var g: Dictionary = _groups[id]
		if g["destroyed"] or (damage_type == "sword" and g["kind"] != "wood"):
			continue
		var center: Vector3 = g["center"]
		var offset := local_point - center
		var height: float = g["height"]
		var vertical_gap := maxf(0.0, absf(offset.y - height * 0.5) - height * 0.5)
		if Vector3(offset.x, vertical_gap, offset.z).length() > radius + float(g["reach"]):
			continue
		g["health"] = float(g["health"]) - maxf(0.0, impulse)
		if g["health"] <= 0.0:
			_destroy_group(id, local_point)
			hit += 1
	return hit

func _destroy_group(id: String, hit_point: Vector3) -> void:
	var g: Dictionary = _groups[id]
	g["destroyed"] = true
	for ref in g["indices"]:
		var pair: Array = ref
		var batch: MultiMeshInstance3D = _batches[pair[0]]
		# Keep the old origin when hiding an instance. Moving it to world zero
		# expands this sector's AABB across the whole map after the first hit.
		var hidden := batch.multimesh.get_instance_transform(pair[1])
		hidden.basis = Basis().scaled(Vector3.ZERO)
		batch.multimesh.set_instance_transform(pair[1], hidden)
	var collider: StaticBody3D = g["collider"]
	if is_instance_valid(collider):
		collider.set_deferred("collision_layer", 0)
		collider.set_deferred("collision_mask", 0)
		collider.queue_free()
	_spawn_splinters(g["center"], hit_point,
		str(g.get("debris_kind", g["kind"])), str(g.get("debris_cloth", "canvas")))

func _spawn_splinters(center: Vector3, hit_point: Vector3, kind: String,
		cloth_material := "canvas") -> void:
	while _shards.size() + 5 > SHARD_LIMIT:
		var oldest: Dictionary = _shards.pop_front()
		if is_instance_valid(oldest["body"]):
			oldest["body"].queue_free()
	var origin := center + Vector3.UP * 0.8
	var away := (origin - hit_point).normalized()
	for i in 5:
		var body := RigidBody3D.new()
		var cloth_scrap := kind == "canvas" and i < 3
		var canvas_slat := kind == "canvas" and i >= 3
		if cloth_scrap:
			body.mass = 0.16
			body.gravity_scale = 0.55
			body.linear_damp = 0.65
		elif canvas_slat:
			body.mass = 0.45
		else:
			body.mass = 0.6 if kind == "wood" else 1.4
		body.position = origin + Vector3(_rng.randf_range(-0.45, 0.45), _rng.randf_range(0.1, 0.6), _rng.randf_range(-0.45, 0.45))
		body.collision_layer = 1
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		if cloth_scrap:
			box.size = Vector3(0.48, 0.025, 0.34)
		elif canvas_slat:
			box.size = Vector3(0.45, 0.07, 0.08)
		else:
			box.size = Vector3(0.36, 0.08, 0.11) if kind == "wood" else Vector3(0.18, 0.14, 0.16)
		shape.shape = box
		body.add_child(shape)
		var visual := MeshInstance3D.new()
		visual.mesh = _meshes["box"]
		visual.scale = box.size
		if cloth_scrap:
			visual.material_override = _materials[cloth_material]
		elif canvas_slat:
			visual.material_override = _materials["oak"]
		else:
			visual.material_override = _materials["oak"] if kind == "wood" else _materials["stone"]
		body.add_child(visual)
		add_child(body)
		body.linear_velocity = away * _rng.randf_range(1.5, 3.2) + Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(2.5, 4.2), _rng.randf_range(-1.5, 1.5))
		body.angular_velocity = Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3), _rng.randf_range(-3, 3))
		_shards.append({"body": body, "life": SHARD_LIFE})
	set_process(true)

func _process(delta: float) -> void:
	for i in range(_shards.size() - 1, -1, -1):
		_shards[i]["life"] = float(_shards[i]["life"]) - delta
		if _shards[i]["life"] <= 0.0:
			var body: RigidBody3D = _shards[i]["body"]
			if is_instance_valid(body):
				body.queue_free()
			_shards.remove_at(i)
	if _shards.is_empty():
		set_process(false)

