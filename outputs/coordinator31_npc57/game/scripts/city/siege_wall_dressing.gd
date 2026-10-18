extends Node3D
## Cheap, collision-free assault dressing below the south curtain wall.
## Coordinates match CastleSite/BattlefieldSite (gate at z=68, castle y=0).

const SEED := 731806
const SHARD_LIMIT := 16

var _rng := RandomNumberGenerator.new()
var _terrain: Node3D
var _parts: Dictionary = {"box": [], "tip": [], "scar": []}
var _batches: Dictionary = {}
var _groups: Dictionary = {}
var _shards: Array[RigidBody3D] = []
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _stats := {"ladders": 0, "arrows": 0, "spears": 0, "broken_shields": 0,
	"impact_scars": 0, "instances": 0, "batches": 0, "colliders": 0, "broken_groups": 0}
var _installed := false

func install(terrain: Node3D) -> Dictionary:
	if _installed:
		return get_stats()
	_installed = true
	_terrain = terrain
	_rng.seed = SEED
	_make_resources()
	_build_ladders()
	_build_projectiles()
	_build_broken_shields()
	_build_impact_scars()
	_flush()
	set_process(false)
	return get_stats()

func get_stats() -> Dictionary:
	return _stats.duplicate(true)

func _make_resources() -> void:
	var shared := StandardMaterial3D.new()
	shared.albedo_color = Color.WHITE
	shared.vertex_color_use_as_albedo = true
	shared.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	shared.roughness = 0.96
	_materials["shared"] = shared
	var shard_material := StandardMaterial3D.new()
	shard_material.albedo_color = Color(0.34, 0.20, 0.10)
	shard_material.roughness = 0.96
	_materials["shard"] = shard_material
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_meshes["box"] = box
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.5
	tip.height = 1.0
	tip.radial_segments = 4
	_meshes["tip"] = tip
	var scar := SphereMesh.new()
	scar.radius = 0.5
	scar.height = 1.0
	scar.radial_segments = 7
	scar.rings = 3
	_meshes["scar"] = scar

func _ground(x: float, z: float) -> float:
	if z >= 86.0 and is_instance_valid(_terrain) and _terrain.has_method("terrain_height"):
		return float(_terrain.call("terrain_height", x, z))
	return 0.0

func _add(mesh: String, at: Vector3, size: Vector3, color: Color,
		rotation := Vector3.ZERO, group := "") -> void:
	var xf := Transform3D(Basis.from_euler(rotation) * Basis().scaled(size), at)
	var arr: Array = _parts[mesh]
	if group != "":
		(_groups[group]["indices"] as Array).append([mesh, arr.size()])
	arr.append({"xf": xf, "color": color})
	_stats["instances"] += 1

func _beam(a: Vector3, b: Vector3, width: float, depth: float, color: Color,
		group := "") -> void:
	var delta := b - a
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized()))
	var xf := Transform3D(basis * Basis().scaled(Vector3(width, delta.length(), depth)),
		(a + b) * 0.5)
	var arr: Array = _parts["box"]
	if group != "":
		(_groups[group]["indices"] as Array).append(["box", arr.size()])
	arr.append({"xf": xf, "color": color})
	_stats["instances"] += 1

func _build_ladders() -> void:
	# The southern wall face is z=68.55 (WALL_HALF+WALL_THICK/2).
	# Tops touch masonry at z=68.7, 19.3 m high; feet are 5.1 m outside.
	for x in [-38.0, -21.0, 21.0, 38.0]:
		var id := "ladder_%d" % int(x)
		var foot := Vector3(x, 0.12, 74.0)
		var top := Vector3(x, 19.25, 68.72)
		_groups[id] = {"kind": "ladder", "x": x, "indices": [], "broken": false}
		var oak := Color(0.31, 0.175, 0.084)
		var edge := Color(0.19, 0.105, 0.056)
		for side in [-1.0, 1.0]:
			var dx: float = float(side) * 0.67
			_beam(foot + Vector3(dx, 0, 0), top + Vector3(dx, 0.42, 0), 0.17, 0.19,
				edge if side < 0 else oak, id)
		for rung in 19:
			# Two deliberately missing rungs make one ladder visibly battle damaged.
			if x == 38.0 and rung in [8, 9]:
				continue
			var t := 0.055 + float(rung) * 0.047
			var y := lerpf(foot.y, top.y, t)
			var z := lerpf(foot.z, top.z, t)
			_beam(Vector3(x - 0.70, y, z), Vector3(x + 0.70, y, z),
				0.11, 0.16, oak if rung % 4 else edge, id)
		# Iron braces/tie straps at the bottom and top, still in the box batch.
		for t in [0.08, 0.89]:
			var y := lerpf(foot.y, top.y, t)
			var z := lerpf(foot.z, top.z, t)
			for side in [-1.0, 1.0]:
				_add("box", Vector3(x + side * 0.67, y, z), Vector3(0.20, 0.15, 0.22),
					Color(0.16, 0.16, 0.15), Vector3.ZERO, id)
		_stats["ladders"] += 1

func _build_projectiles() -> void:
	# Clusters mark active fire without tiny collision bodies or particle systems.
	for centre in [Vector2(-12.5, 79.0), Vector2(13.5, 83.0),
			Vector2(-27.0, 91.0), Vector2(30.0, 92.0), Vector2(-43.0, 103.0), Vector2(43.0, 105.0)]:
		for i in 11:
			var x: float = float(centre.x) + _rng.randf_range(-3.2, 3.2)
			var z: float = float(centre.y) + _rng.randf_range(-2.2, 2.2)
			var ground := _ground(x, z)
			var h := _rng.randf_range(0.75, 1.20)
			var lean := Vector3(_rng.randf_range(-0.28, 0.28), 0,
				_rng.randf_range(-0.24, 0.20))
			var start := Vector3(x, ground + 0.08, z)
			var end := start + Vector3(lean.x, h, lean.z)
			_beam(start, end, 0.035, 0.035, Color(0.25, 0.16, 0.09))
			_add("tip", end + (end - start).normalized() * 0.085,
				Vector3(0.13, 0.23, 0.13), Color(0.21, 0.22, 0.22),
				Vector3(lean.z * -0.6, 0, lean.x * 0.6))
			# A compact, colored nock reads as a fletched arrow from player height.
			_add("box", end - Vector3(lean.x, 0.10, lean.z),
				Vector3(0.12, 0.10, 0.04), Color(0.53, 0.44, 0.27))
			_stats["arrows"] += 1
	# A few taller attack spears break the silhouette, safely off the central lane.
	for at in [Vector2(-16.0, 76.0), Vector2(18.0, 77.0),
			Vector2(-34.0, 87.0), Vector2(35.0, 89.0)]:
		var p := Vector3(at.x, _ground(at.x, at.y), at.y)
		_beam(p + Vector3.UP * 0.05, p + Vector3(0.35, 2.35, 0.24),
			0.065, 0.065, Color(0.31, 0.20, 0.11))
		_add("tip", p + Vector3(0.38, 2.44, 0.26), Vector3(0.20, 0.36, 0.14),
			Color(0.19, 0.20, 0.20))
		_stats["spears"] += 1

func _build_broken_shields() -> void:
	for q in [Vector2(-15, 75), Vector2(17, 78), Vector2(-24, 83),
			Vector2(25, 81), Vector2(-39, 92), Vector2(40, 95)]:
		var id := "shield_%d" % _stats["broken_shields"]
		_groups[id] = {"kind": "shield", "x": q.x, "z": q.y,
			"indices": [], "broken": false}
		var y := _ground(q.x, q.y)
		var yaw := _rng.randf_range(-PI, PI)
		var broken: bool = int(_stats["broken_shields"]) % 2 == 0
		for plank in 3:
			if broken and plank == 2:
				continue
			var p := Vector3(q.x + (plank - 1) * 0.24, y + 0.095, q.y)
			_add("box", p, Vector3(0.24, 0.10, 1.32 - plank * 0.12),
				Color(0.37, 0.16, 0.12) if plank != 1 else Color(0.45, 0.19, 0.14),
				Vector3(0.13, yaw, 0.10), id)
		_add("box", Vector3(q.x, y + 0.17, q.y), Vector3(0.19, 0.11, 0.19),
			Color(0.17, 0.18, 0.18), Vector3.ZERO, id)
		_stats["broken_shields"] += 1

func _build_impact_scars() -> void:
	# Asymmetric dark gouges and limestone chips on the forecourt, never road stripes.
	for q in [Vector2(-17.0, 73.0), Vector2(-31.0, 76.0), Vector2(24.0, 75.0),
			Vector2(42.0, 79.0), Vector2(-26.0, 87.0), Vector2(32.0, 91.0)]:
		var y := _ground(q.x, q.y)
		var p := Vector3(q.x, y, q.y)
		_add("scar", p + Vector3(0, 0.018, 0),
			Vector3(_rng.randf_range(2.0, 3.4), 0.047, _rng.randf_range(1.4, 2.3)),
			Color(0.105, 0.100, 0.092), Vector3(0, _rng.randf_range(0, TAU), 0))
		for i in 5:
			var x: float = float(q.x) + _rng.randf_range(-1.7, 1.7)
			var z: float = float(q.y) + _rng.randf_range(-1.3, 1.3)
			var s := _rng.randf_range(0.15, 0.37)
			_add("scar", Vector3(x, _ground(x, z) + s * 0.20, z),
				Vector3(s, s * 0.36, s * 0.8), Color(0.48, 0.45, 0.37),
				Vector3(0, _rng.randf_range(0, TAU), 0))
		_stats["impact_scars"] += 1

func _flush() -> void:
	for key in ["box", "tip", "scar"]:
		var items: Array = _parts[key]
		var mesh: Mesh = (_meshes[key] as Mesh).duplicate()
		mesh.surface_set_material(0, _materials["shared"])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = items.size()
		for i in items.size():
			var item: Dictionary = items[i]
			mm.set_instance_transform(i, item["xf"])
			mm.set_instance_color(i, item["color"])
		var node := MultiMeshInstance3D.new()
		node.name = "SiegeWall_%s" % key
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("category", "siege_wall_dressing")
		add_child(node)
		_batches[key] = node
		_stats["batches"] += 1
	_parts.clear()

func apply_damage(world_point: Vector3, radius: float, impulse: float) -> int:
	# Called next to castle.apply_explosion, including strikes the castle accepts.
	var point := to_local(world_point)
	var broken := 0
	for id in _groups:
		var g: Dictionary = _groups[id]
		if g["broken"]:
			continue
		var dx := absf(point.x - float(g["x"]))
		var nearby := false
		if g["kind"] == "ladder":
			nearby = dx <= radius + 1.0 and point.z >= 68.0 - radius \
				and point.z <= 74.5 + radius and point.y >= -radius \
				and point.y <= 20.0 + radius
		else:
			nearby = dx <= radius + 0.95 and absf(point.z - float(g["z"])) <= radius + 1.0 \
				and point.y <= radius + 1.0
		if not nearby:
			continue
		for pair in g["indices"]:
			var mm: MultiMesh = (_batches[pair[0]] as MultiMeshInstance3D).multimesh
			var xf := mm.get_instance_transform(pair[1])
			xf.basis = Basis().scaled(Vector3.ONE * 0.0001)
			mm.set_instance_transform(pair[1], xf)
		g["broken"] = true
		broken += 1
		if g["kind"] == "ladder":
			_spawn_ladder_shards(Vector3(float(g["x"]), clampf(point.y, 0.5, 18.5),
				clampf(point.z, 68.7, 74.0)), impulse)
	_stats["broken_groups"] += broken
	return broken

func _spawn_ladder_shards(at: Vector3, impulse: float) -> void:
	# At most four real planks from a broken ladder; already-spawned pieces retire.
	for i in 4:
		while _shards.size() >= SHARD_LIMIT:
			var oldest: RigidBody3D = _shards.pop_front()
			if is_instance_valid(oldest):
				oldest.queue_free()
		var body := RigidBody3D.new()
		body.name = "LadderSplinter"
		body.mass = 0.16
		body.position = at + Vector3(_rng.randf_range(-0.6, 0.6),
			_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.2, 0.3))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.08, 0.08, _rng.randf_range(0.55, 1.15))
		shape.shape = box
		body.add_child(shape)
		var visual := MeshInstance3D.new()
		visual.mesh = _meshes["box"]
		visual.scale = box.size
		visual.material_override = _materials["shard"]
		body.add_child(visual)
		add_child(body)
		body.apply_central_impulse(Vector3(_rng.randf_range(-0.7, 0.7),
			0.7 + _rng.randf_range(0, 0.7), 0.7 + _rng.randf_range(0, 0.4)) \
			* clampf(impulse * 0.018, 1.5, 5.0))
		_shards.append(body)
		var retire := Timer.new()
		retire.one_shot = true
		retire.wait_time = 4.5
		retire.timeout.connect(body.queue_free)
		body.add_child(retire)
		retire.start()
