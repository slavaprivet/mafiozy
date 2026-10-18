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
	_stats = {"carts": 0, "tents": 0, "barriers": 0, "watchtowers": 0, "trees": 0, "crates": 0, "barrels": 0, "shields": 0, "firepits": 0, "stones": 0, "grass": 0, "mesh_instances": 0, "mesh_pieces": 0, "colliders": 0, "breakable_groups": 0, "batches_by_z_sector": {}}
	_build_siege_line()
	_build_camp()
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
	var ridge_l := Vector3(-2.12, 2.42, 0)
	var ridge_r := Vector3(2.12, 2.42, 0)
	for side in [-1.0, 1.0]:
		var eave_l := Vector3(-2.12, 0.28, side * 2.02)
		var eave_r := Vector3(2.12, 0.28, side * 2.02)
		_roof_triangle(st, ridge_l, ridge_r, eave_r)
		_roof_triangle(st, ridge_l, eave_r, eave_l)
	for x in [-2.12, 2.12]:
		_roof_triangle(st, Vector3(x, 2.42, 0), Vector3(x, 0.28, -2.02), Vector3(x, 0.28, 2.02))
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
	var cell := Vector2i(int(floor(pos.x / 95.0)), int(floor((pos.z - 80.0) / 85.0)))
	var bucket := "vegetation_grass" if material in ["grass", "grass_dry"] else ("glow" if material == "ember" else ("detail" if no_shadow else "solid"))
	var key := "%s|%s|%d|%d" % [mesh, bucket, cell.x, cell.y]
	if not _pending.has(key):
		_pending[key] = {"mesh": mesh, "bucket": bucket, "cell": cell, "no_shadow": no_shadow, "parts": []}
	var lift := float(_groups[group]["ground_offset"]) if group != "" and _groups.has(group) else _terrain_y(pos.x, pos.z)
	var xf := Transform3D(Basis.from_euler(rotation).scaled(size), pos + Vector3.UP * lift)
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
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if record["no_shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
	_groups[id] = {"center": center + Vector3.UP * lift, "ground_offset": lift, "health": health, "kind": kind, "indices": [], "collider": null, "destroyed": false}
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
	_build_cart(Vector3(42.0, 0, 143.0), 0.36, "cart_supply")
	_build_cart(Vector3(-43.0, 0, 158.0), -0.44, "cart_broken", true)
	_build_wheel(Vector3(-38.6, 0.18, 162.2), 0.76, 0.38, "")
	for side in [-1.0, 1.0]:
		for i in 2:
			_build_barricade(Vector3(side * (23.0 + i * 5.0), 0, 178.0 + i * 3.0), side, "outer_barrier_%d_%d" % [int(side), i])
	for p in [Vector3(-36, 0, 126), Vector3(36, 0, 166), Vector3(-48, 0, 177)]:
		_build_shield(p, _rng.randf_range(-1.0, 1.0), "")

func _build_barricade(p: Vector3, yaw: float, id: String) -> void:
	_group(id, p, 80.0, "wood", Vector3(3.8, 1.15, 1.4))
	var basis := Basis(Vector3.UP, yaw * 0.22)
	for j in 3:
		var z := (j - 1) * 0.42
		_box("oak_edge", p + basis * Vector3(0, 0.34 + j * 0.27, z), Vector3(3.8, 0.16, 0.20), Vector3(0, yaw * 0.22, 0), id)
	for j in 0:
		pass
	for x in [-1.55, 0.0, 1.55]:
		var stake := p + basis * Vector3(x, 0, -0.65)
		_piece("cone", "oak", stake + Vector3.UP * 0.68, Vector3(0.42, 1.36, 0.42), Vector3(1.08, 0, 0), id)
		_box("iron", stake + Vector3(0, 0.22, 0), Vector3(0.42, 0.1, 0.43), Vector3.ZERO, id)
	_stats["barriers"] += 1

func _build_cart(p: Vector3, yaw: float, id: String, broken := false) -> void:
	_group(id, p, 180.0, "wood", Vector3(3.9, 1.3, 2.2))
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
			_build_wheel(p + b * Vector3(x, 0.72, side * 1.17), 0.72, yaw, id)
	for z in [-0.66, 0.66]:
		_box("oak_edge", p + b * Vector3(2.56, 0.83, z), Vector3(2.3, 0.14, 0.13), Vector3(0, yaw, 0), id)
	_box("iron", p + b * Vector3(3.65, 0.70, 0), Vector3(0.14, 0.10, 1.65), Vector3(0, yaw, 0), id)
	if not broken:
		for i in 5:
			var xp := _rng.randf_range(-1.35, 1.35)
			var zp := _rng.randf_range(-0.55, 0.55)
			_build_crate(p + b * Vector3(xp, 1.15, zp), 0.47, "cart_crate_%d" % i, false)
		_piece("drum", "canvas_dark", p + b * Vector3(-0.65, 1.54, 0.20), Vector3(0.66, 1.55, 0.66), Vector3(0, yaw, PI * 0.5), id)
		for dz in [-0.28, 0.28]:
			_piece("drum", "rope", p + b * Vector3(-0.65, 1.54, 0.20 + dz), Vector3(0.69, 0.06, 0.69), Vector3(0, yaw, PI * 0.5), id)
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
		var radial := Vector3(cos(a), sin(a), 0)
		_box("oak", p + radial * radius * 0.45, Vector3(radius * 0.95, 0.09, 0.10), Vector3(0, yaw, a), group)

func _build_camp() -> void:
	for p in [Vector3(-77, 0, 198), Vector3(-65, 0, 205), Vector3(-49, 0, 224), Vector3(-38, 0, 238), Vector3(37, 0, 238), Vector3(48, 0, 205), Vector3(65, 0, 225), Vector3(77, 0, 202)]:
		_build_tent(p, "tent_%d" % _stats["tents"])
	for p in [Vector3(-53, 0, 195), Vector3(58, 0, 191), Vector3(-31, 0, 231), Vector3(31, 0, 231)]:
		_build_banner(p)
	for p in [Vector3(-44, 0, 207), Vector3(43, 0, 221)]:
		_build_firepit(p)
	_build_cart(Vector3(-72, 0, 227), 0.18, "camp_cart_left")
	_build_cart(Vector3(72, 0, 232), -0.24, "camp_cart_right")
	_build_watchtower(Vector3(-79, 0, 164), "watchtower_left")
	_build_watchtower(Vector3(79, 0, 180), "watchtower_right")
	for p in [Vector3(-31, 0, 198), Vector3(35, 0, 220), Vector3(72, 0, 201)]:
		_build_barrel(p, 0.56, "barrel_%d" % _stats["barrels"])
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

func _build_tent(p: Vector3, id: String) -> void:
	_group(id, p, 95.0, "canvas", Vector3(4.2, 1.8, 4.2))
	var yaw := _rng.randf_range(-0.28, 0.28)
	var b := Basis(Vector3.UP, yaw)
	_piece("tent_roof", "canvas", p, Vector3.ONE, Vector3(0, yaw, 0), id)
	for side in [-1.0, 1.0]:
		# Seam and rolled eave make the continuous cloth roof read at walking distance.
		_box("canvas_dark", p + b * Vector3(0, 0.34, side * 2.04), Vector3(4.22, 0.12, 0.10), Vector3(0, yaw, 0), id)
		for x in [-1.95, 1.95]:
			_box("rope", p + b * Vector3(x, 0.80, side * 2.22), Vector3(0.055, 1.70, 0.055), Vector3(side * 0.69, yaw, 0), id)
			_piece("cone", "oak_edge", p + b * Vector3(x, 0.16, side * 2.9), Vector3(0.14, 0.32, 0.14), Vector3.ZERO, id)
	_box("oak_edge", p + Vector3.UP * 2.40, Vector3(4.35, 0.09, 0.09), Vector3(0, yaw, 0), id)
	for side in [-1.0, 1.0]:
		_box("oak", p + b * Vector3(side * 1.91, 1.19, 0), Vector3(0.11, 2.36, 0.11), Vector3.ZERO, id)
	# Ground cloth and folded entrance flap.
	_box("canvas_dark", p + Vector3.UP * 0.045, Vector3(3.8, 0.065, 3.75), Vector3(0, yaw, 0), id)
	_box("red", p + b * Vector3(1.93, 0.50, -0.53), Vector3(0.07, 0.9, 1.0), Vector3(0.15, yaw + 0.35, 0), id)
	_stats["tents"] += 1

func _build_watchtower(p: Vector3, id: String) -> void:
	# A recognisable high silhouette at both ends of the attackers' line.
	_group(id, p, 220.0, "wood", Vector3(3.6, 5.2, 3.6))
	for x in [-1.55, 1.55]:
		for z in [-1.55, 1.55]:
			_box("oak_edge", p + Vector3(x, 2.65, z), Vector3(0.26, 5.3, 0.26), Vector3.ZERO, id)
			_box("iron", p + Vector3(x, 0.8, z), Vector3(0.32, 0.11, 0.32), Vector3.ZERO, id)
	for side in [-1.0, 1.0]:
		for level in [1.25, 3.15]:
			_box("oak", p + Vector3(0, level, side * 1.54), Vector3(3.4, 0.15, 0.17), Vector3.ZERO, id)
			_box("oak", p + Vector3(side * 1.54, level, 0), Vector3(0.17, 0.15, 3.4), Vector3.ZERO, id)
		_box("oak", p + Vector3(0, 2.62, side * 1.53), Vector3(0.15, 3.8, 0.17), Vector3(0, 0, side * 0.69), id)
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

func _build_banner(p: Vector3) -> void:
	_box("oak_edge", p + Vector3.UP * 2.1, Vector3(0.13, 4.2, 0.13))
	_box("iron", p + Vector3.UP * 4.16, Vector3(1.25, 0.08, 0.08))
	_box("red", p + Vector3(0.54, 3.47, 0), Vector3(1.05, 1.37, 0.055), Vector3(0, 0, 0.08))
	_box("red_edge", p + Vector3(0.55, 2.87, 0.035), Vector3(1.0, 0.10, 0.028))

func _build_crate(p: Vector3, size: float, id: String, collider := true) -> void:
	if collider:
		_group(id, p, 25.0, "wood", Vector3.ONE * size)
	var half := size * 0.5
	_box("oak", p + Vector3.UP * half, Vector3(size, size, size), Vector3.ZERO, id if collider else "")
	for side in [-1.0, 1.0]:
		_box("oak_edge", p + Vector3(0, half, side * half), Vector3(size * 0.92, size * 0.09, size * 0.08), Vector3(0, 0, 0.58), id if collider else "")
		_box("iron", p + Vector3(side * half, half, 0), Vector3(size * 0.045, size * 0.90, size * 0.045), Vector3.ZERO, id if collider else "")
	_stats["crates"] += 1

func _build_barrel(p: Vector3, size: float, id: String) -> void:
	_group(id, p, 30.0, "wood", Vector3(size, size * 1.5, size))
	_piece("drum", "oak", p + Vector3.UP * size * 0.72, Vector3(size, size * 1.42, size), Vector3.ZERO, id)
	for h in [0.19, 0.57, 1.12]:
		_piece("drum", "iron", p + Vector3.UP * h * size, Vector3(size * 1.05, size * 0.075, size * 1.05), Vector3.ZERO, id)
	_piece("drum", "oak_edge", p + Vector3.UP * size * 1.45, Vector3(size * 0.82, size * 0.065, size * 0.82), Vector3.ZERO, id)
	_stats["barrels"] += 1

func _build_shield(p: Vector3, yaw: float, group: String) -> void:
	var rot := Vector3(0.12, yaw, 0.16)
	_piece("drum", "red", p + Vector3.UP * 0.59, Vector3(0.92, 0.10, 0.92), Vector3(PI * 0.5 + rot.x, rot.y, rot.z), group)
	_piece("wheel", "iron", p + Vector3.UP * 0.59, Vector3(0.94, 0.13, 0.94), Vector3(PI * 0.5 + rot.x, rot.y, rot.z), group)
	_piece("drum", "iron", p + Vector3.UP * 0.59, Vector3(0.23, 0.15, 0.23), Vector3(PI * 0.5 + rot.x, rot.y, rot.z), group)
	_stats["shields"] += 1

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
			_box("grass_dry" if i % 3 else "grass", p + Vector3(j * 0.08, 0, 0), Vector3(0.035, s, 0.018), Vector3(0, _rng.randf_range(0, TAU), _rng.randf_range(-0.4, 0.4)), "", true)
		_stats["grass"] += 1

func _build_tree(p: Vector3, id: String) -> void:
	_group(id, p, 120.0, "wood", Vector3(0.9, 3.8, 0.9))
	_piece("cone", "char", p + Vector3.UP * 2.0, Vector3(1.02, 4.0, 1.02), Vector3(0, _rng.randf_range(0, TAU), 0.11), id)
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.3
		var high := 2.3 + float(i % 2) * 0.9
		_box("char", p + Vector3(cos(a) * 0.64, high, sin(a) * 0.64), Vector3(0.19, 1.7, 0.19), Vector3(sin(a) * 0.67, a, cos(a) * 0.67), id)
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
		if (g["center"] as Vector3).distance_to(local_point) > radius + 2.2:
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
		batch.multimesh.set_instance_transform(pair[1], Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	var collider: StaticBody3D = g["collider"]
	if is_instance_valid(collider):
		collider.set_deferred("collision_layer", 0)
		collider.set_deferred("collision_mask", 0)
		collider.queue_free()
	_spawn_splinters(g["center"], hit_point, g["kind"])

func _spawn_splinters(center: Vector3, hit_point: Vector3, kind: String) -> void:
	while _shards.size() + 5 > SHARD_LIMIT:
		var oldest: Dictionary = _shards.pop_front()
		if is_instance_valid(oldest["body"]):
			oldest["body"].queue_free()
	var origin := center + Vector3.UP * 0.8
	var away := (origin - hit_point).normalized()
	for i in 5:
		var body := RigidBody3D.new()
		body.mass = 0.6 if kind == "wood" else 1.4
		body.position = origin + Vector3(_rng.randf_range(-0.45, 0.45), _rng.randf_range(0.1, 0.6), _rng.randf_range(-0.45, 0.45))
		body.collision_layer = 1
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.36, 0.08, 0.11) if kind == "wood" else Vector3(0.18, 0.14, 0.16)
		shape.shape = box
		body.add_child(shape)
		var visual := MeshInstance3D.new()
		visual.mesh = _meshes["box"]
		visual.scale = box.size
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
