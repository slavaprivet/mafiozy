extends Node3D
## Cheap, collision-free assault dressing below the south curtain wall.
## Coordinates match CastleSite/BattlefieldSite (gate at z=68, castle y=0).

const SEED := 731806
const SHARD_LIMIT := 16

## The four assault ladders. These are the same coordinates the visual ladders use.
const LADDER_XS := [-38.0, -21.0, 21.0, 38.0]
const LADDER_FOOT_Z := 74.0
const LADDER_TOP_Z := 68.72
## The climber's line sits just outside the overhanging wall-walk deck. The visual
## ladder still touches the wall at 68.72; a body cannot descend through the deck.
const LADDER_CLIMB_TOP_Z := 69.05
const LADDER_BOTTOM_Y := 0.12
const LADDER_TOP_Y := 19.25
const LADDER_CLIMB_SPEED := 2.15

var _rng := RandomNumberGenerator.new()
var _terrain: Node3D
var _player: CharacterBody3D
var _parts: Dictionary = {"box": [], "tip": [], "scar": []}
var _batches: Dictionary = {}
var _groups: Dictionary = {}
var _anchors: Dictionary = {}
var _shards: Array[RigidBody3D] = []
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _climbing := false
var _climb_id := ""
var _climb_override := NAN
var _climb_pose_active := false
var _wait_release := false
var _stats := {"ladders": 0, "arrows": 0, "spears": 0, "broken_shields": 0,
	"impact_scars": 0, "instances": 0, "batches": 0, "colliders": 0,
	"broken_groups": 0, "broken_parts": 0}
var _installed := false

func install(terrain: Node3D) -> Dictionary:
	if _installed:
		return get_stats()
	_installed = true
	_terrain = terrain
	var world: Node = terrain.get_parent()
	if world != null:
		_player = world.get("_player") as CharacterBody3D
	_rng.seed = SEED
	_make_resources()
	_build_ladders()
	_build_projectiles()
	_build_broken_shields()
	_build_impact_scars()
	_flush()
	set_process(false)
	set_physics_process(true)
	process_physics_priority = 100
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
	for x in LADDER_XS:
		var id := "ladder_%d" % int(x)
		var foot := Vector3(x, LADDER_BOTTOM_Y, LADDER_FOOT_Z)
		var top := Vector3(x, LADDER_TOP_Y, LADDER_TOP_Z)
		_groups[id] = {"kind": "ladder", "x": x, "indices": [], "broken": false}
		var anchor := Node3D.new()
		anchor.name = "LadderAnchor_%d" % int(x)
		anchor.position = foot
		add_child(anchor)
		_anchors[id] = anchor
		# A projectile-only hit box: layer 1 so cannonballs and catapult stones strike it,
		# but the player is in its exception list so the ladder never blocks walking or
		# the climb. It follows the rake of the ladder.
		var hit_body := StaticBody3D.new()
		hit_body.name = "LadderHit_%d" % int(x)
		hit_body.collision_layer = 1
		hit_body.collision_mask = 0
		hit_body.position = Vector3(x, (LADDER_BOTTOM_Y + LADDER_TOP_Y) * 0.5,
			(LADDER_FOOT_Z + LADDER_TOP_Z) * 0.5)
		hit_body.rotation.x = -atan2(LADDER_FOOT_Z - LADDER_TOP_Z,
			LADDER_TOP_Y - LADDER_BOTTOM_Y)
		add_child(hit_body)
		if is_instance_valid(_player):
			hit_body.add_collision_exception_with(_player)
		var hit_shape := CollisionShape3D.new()
		var hit_box := BoxShape3D.new()
		hit_box.size = Vector3(1.48, LADDER_TOP_Y - LADDER_BOTTOM_Y + 1.1, 0.34)
		hit_shape.shape = hit_box
		hit_body.add_child(hit_shape)
		_groups[id]["hit_body"] = hit_body
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
			for side in [-1.0, 1.0]:
				_add("box", Vector3(x + side * 0.70, y, z), Vector3(0.11, 0.10, 0.19),
					Color(0.20, 0.205, 0.22), Vector3.ZERO, id)
		# Rope lashings where the stringers meet the wall head.
		for side in [-1.0, 1.0]:
			_add("box", Vector3(x + side * 0.67, 18.82, 69.12),
				Vector3(0.27, 0.12, 0.27), Color(0.46, 0.36, 0.21), Vector3.ZERO, id)
		# Iron braces/tie straps at the bottom and top, still in the box batch.
		for t in [0.08, 0.89]:
			var y := lerpf(foot.y, top.y, t)
			var z := lerpf(foot.z, top.z, t)
			for side in [-1.0, 1.0]:
				_add("box", Vector3(x + side * 0.67, y, z), Vector3(0.20, 0.15, 0.22),
					Color(0.16, 0.16, 0.15), Vector3.ZERO, id)
		# Per-piece health. The visual instances stay in one MultiMesh; a broken piece
		# is hidden by its own slot, so a ladder can lose rungs one by one.
		var ladder_parts: Array[Dictionary] = []
		for pair: Array in (_groups[id]["indices"] as Array):
			var item: Dictionary = _parts[pair[0]][pair[1]]
			var xf: Transform3D = item["xf"]
			ladder_parts.append({"key": pair[0], "index": pair[1],
				"at": xf.origin, "hp": 26.0, "alive": true})
		_groups[id]["parts"] = ladder_parts
		_groups[id]["max_parts"] = ladder_parts.size()
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
			# Extend the same shaft line below the soil, preserving tail and feathers.
			var buried_start := start - (end - start) * (0.12 / (end.y - start.y))
			_beam(buried_start, end, 0.035, 0.035, Color(0.25, 0.16, 0.09))
			# The arrowhead is buried at start; feathers belong at the exposed tail.
			# Reuse the existing tip/box batches for two thin crossed feather vanes.
			var shaft := (end - start).normalized()
			var feather_basis := Basis(Quaternion(Vector3.UP, shaft))
			var feather_at := end - shaft * 0.13
			_add("tip", feather_at, Vector3(0.16, 0.24, 0.022),
				Color(0.58, 0.50, 0.34), (feather_basis * Basis(Vector3.RIGHT, PI)).get_euler())
			_add("box", feather_at, Vector3(0.022, 0.20, 0.14),
				Color(0.48, 0.40, 0.27), feather_basis.get_euler())
			_stats["arrows"] += 1
	# A few taller attack spears break the silhouette, safely off the central lane.
	for at in [Vector2(-16.0, 76.0), Vector2(18.0, 77.0),
			Vector2(-34.0, 87.0), Vector2(35.0, 89.0)]:
		var p := Vector3(at.x, _ground(at.x, at.y), at.y)
		var spear_start := p + Vector3.UP * 0.05
		var spear_end := p + Vector3(0.35, 2.35, 0.24)
		spear_start -= (spear_end - spear_start) * (0.09 / (spear_end.y - spear_start.y))
		_beam(spear_start, spear_end, 0.065, 0.065, Color(0.31, 0.20, 0.11))
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
		var shield_rotation := Vector3(0.13, yaw, 0.10)
		var shield_basis := Basis.from_euler(shield_rotation)
		var shield_center := Vector3(q.x, y + 0.095, q.y)
		var broken: bool = int(_stats["broken_shields"]) % 2 == 0
		for plank in 3:
			if broken and plank == 2:
				continue
			var p := shield_center + shield_basis * Vector3((plank - 1) * 0.24, 0, 0)
			_add("box", p, Vector3(0.24, 0.10, 1.32 - plank * 0.12),
				Color(0.37, 0.16, 0.12) if plank != 1 else Color(0.45, 0.19, 0.14),
				shield_rotation, id)
		_add("box", shield_center + shield_basis * Vector3(0, 0.075, 0),
			Vector3(0.19, 0.11, 0.19), Color(0.17, 0.18, 0.18), shield_rotation, id)
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

func apply_damage(world_point: Vector3, radius: float, impulse: float,
		damage: float = 0.0) -> int:
	# Called next to castle.apply_explosion, including strikes the castle accepts.
	var point := to_local(world_point)
	var damage_amount: float = damage if damage > 0.0 else maxf(26.0, impulse * 0.62)
	var broken := 0
	for id in _groups:
		var g: Dictionary = _groups[id]
		if g["kind"] == "ladder":
			# A ladder is damaged piece by piece: a ball takes the rungs and stringers
			# around the impact, and the next ball takes the next few.
			var dx := absf(point.x - float(g["x"]))
			if dx > radius + 1.0 or point.z < 68.0 - radius \
					or point.z > LADDER_FOOT_Z + radius or point.y < -radius \
					or point.y > 20.0 + radius:
				continue
			var parts: Array = g.get("parts", [])
			var hit_parts := 0
			var alive_parts := 0
			for part: Dictionary in parts:
				if not bool(part.get("alive", true)):
					continue
				alive_parts += 1
				var at: Vector3 = part.get("at", Vector3.ZERO)
				if at.distance_to(point) > radius * 0.65 + 0.35:
					continue
				part["hp"] = float(part.get("hp", 26.0)) - damage_amount
				if float(part["hp"]) > 0.0:
					continue
				part["alive"] = false
				alive_parts -= 1
				hit_parts += 1
				_hide_ladder_part(part)
				if bool(g.get("broken", false)):
					_spawn_ladder_piece(at, impulse)
			if alive_parts <= 0:
				g["destroyed"] = true
				var hit_body: StaticBody3D = g.get("hit_body")
				if is_instance_valid(hit_body):
					hit_body.collision_layer = 0
			if hit_parts <= 0:
				continue
			_stats["broken_parts"] = int(_stats.get("broken_parts", 0)) + hit_parts
			if not bool(g.get("broken", false)):
				g["broken"] = true
				broken += 1
				_spawn_ladder_shards(Vector3(float(g["x"]), clampf(point.y, 0.5, 18.5),
					clampf(point.z, 68.7, 74.0)), impulse)
			continue
		if g["broken"]:
			continue
		var dx := absf(point.x - float(g["x"]))
		var nearby := false
		if g["kind"] == "ladder":
			nearby = false
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
	_stats["broken_groups"] = int(_stats.get("broken_groups", 0)) + broken
	return broken


func _hide_ladder_part(part: Dictionary) -> void:
	var key := str(part.get("key", "box"))
	var batch: MultiMeshInstance3D = _batches.get(key)
	if not is_instance_valid(batch) or batch.multimesh == null:
		return
	var slot := int(part.get("index", -1))
	if slot < 0:
		return
	var xf := batch.multimesh.get_instance_transform(slot)
	xf.basis = Basis().scaled(Vector3.ONE * 0.0001)
	batch.multimesh.set_instance_transform(slot, xf)


func _spawn_ladder_piece(at: Vector3, impulse: float) -> void:
	while _shards.size() >= SHARD_LIMIT:
		var oldest: RigidBody3D = _shards.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var body := RigidBody3D.new()
	body.name = "LadderPiece"
	body.mass = 0.14
	body.position = at
	var box := BoxShape3D.new()
	box.size = Vector3(_rng.randf_range(0.07, 0.12), _rng.randf_range(0.07, 0.12),
		_rng.randf_range(0.30, 0.72))
	var shape := CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	visual.mesh = _meshes["box"]
	visual.scale = box.size
	visual.material_override = _materials["shard"]
	body.add_child(visual)
	body.tree_exiting.connect(_on_shard_exiting.bind(body))
	add_child(body)
	body.apply_central_impulse(Vector3(_rng.randf_range(-0.6, 0.6),
		0.5 + _rng.randf_range(0, 0.6), 0.5 + _rng.randf_range(0, 0.4)) \
		* clampf(impulse * 0.018, 1.2, 4.0))
	_shards.append(body)
	var retire := Timer.new()
	retire.one_shot = true
	retire.wait_time = 4.5
	retire.timeout.connect(body.queue_free)
	body.add_child(retire)
	retire.start()

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
		# The retire timer frees the body, and this signal removes its reference
		# from the bounded array so shard_count reflects live physics objects.
		body.tree_exiting.connect(_on_shard_exiting.bind(body))
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

func _physics_process(delta: float) -> void:
	if not _installed:
		return
	if not is_instance_valid(_player):
		var world: Node = get_parent().get_parent() if get_parent() != null else null
		if world != null:
			_player = world.get("_player") as CharacterBody3D
		if not is_instance_valid(_player):
			return
	climb_assist(_player, delta)


func _on_shard_exiting(body: RigidBody3D) -> void:
	_shards.erase(body)


## W/S on an intact assault ladder. The same crawl presentation the ship uses is fed
## the ladder's own base/top/rung count, so there is no second pose implementation.
func climb_assist(actor: CharacterBody3D, delta: float) -> void:
	if not _installed or not is_instance_valid(actor): return
	if not is_finite(delta) or delta <= 0.0 or delta > 0.25: return
	var found := _ladder_at(actor)
	if found.is_empty() or not ladder_climbable(str(found["id"])):
		_release_climb(actor)
		return
	var id: String = str(found["id"])
	var x: float = float(found["x"])
	var local_y: float = actor.global_position.y
	var axis := 0.0
	if not is_nan(_climb_override):
		axis = clampf(_climb_override, -1.0, 1.0)
	else:
		if InputMap.has_action(&"preview_move_forward") and Input.is_action_pressed(&"preview_move_forward"):
			axis += 1.0
		if InputMap.has_action(&"preview_move_back") and Input.is_action_pressed(&"preview_move_back"):
			axis -= 1.0
	var just_forward := (not is_nan(_climb_override) and _climb_override > 0.0) \
		or Input.is_action_just_pressed(&"preview_move_forward")
	# Held W must not instantly re-mount the ladder at the top: wait for release.
	if _wait_release:
		if axis > 0.0:
			return
		_wait_release = false
	# W starts the climb; once on the rungs, held W/S move up and down.
	if not _climbing and not just_forward and axis >= 0.0:
		return
	_climbing = true
	_climb_id = id
	if axis != 0.0:
		var next_y := clampf(local_y + LADDER_CLIMB_SPEED * axis * delta,
			LADDER_BOTTOM_Y, LADDER_TOP_Y)
		var t := clampf((next_y - LADDER_BOTTOM_Y) / (LADDER_TOP_Y - LADDER_BOTTOM_Y), 0.0, 1.0)
		var next_pos := Vector3(x, next_y, lerpf(LADDER_FOOT_Z, LADDER_CLIMB_TOP_Z, t))
		if axis > 0.0 and next_y >= LADDER_TOP_Y - 0.02:
			next_pos = Vector3(x, 19.02, 68.80)
			_climbing = false
			_climb_id = ""
			_wait_release = true
		elif axis < 0.0 and next_y <= LADDER_BOTTOM_Y + 0.02:
			next_pos = Vector3(x, 0.06, LADDER_FOOT_Z + 0.40)
			_climbing = false
			_climb_id = ""
			_wait_release = true
		actor.global_position = to_global(next_pos)
		actor.velocity = Vector3(0.0, LADDER_CLIMB_SPEED * axis, 0.0)
	if _climbing and actor.has_method("set_ship_climb_pose"):
		var anchor: Node3D = _anchors.get(id)
		if is_instance_valid(anchor):
			var top_local := Vector3(0.0, LADDER_TOP_Y - LADDER_BOTTOM_Y,
				LADDER_TOP_Z - LADDER_FOOT_Z)
			actor.call("set_ship_climb_pose", {"active": true, "ship": anchor,
				"local": anchor.to_local(actor.global_position), "base": Vector3.ZERO,
				"top": top_local, "rung_count": 19, "axis": axis})
			_climb_pose_active = true
	elif _climb_pose_active:
		_release_climb(actor)


func _ladder_at(actor: CharacterBody3D) -> Dictionary:
	var p := to_local(actor.global_position)
	var min_z := 68.60 if p.y > 18.0 else 69.0
	if p.y < -0.4 or p.y > LADDER_TOP_Y + 0.6 or p.z < min_z or p.z > LADDER_FOOT_Z + 1.4:
		return {}
	for x: float in LADDER_XS:
		if absf(p.x - x) > 1.25:
			continue
		return {"id": "ladder_%d" % int(x), "x": x}
	return {}


func ladder_climbable(id: String) -> bool:
	if not _groups.has(id):
		return false
	var group: Dictionary = _groups[id]
	return not bool(group.get("broken", false)) and not bool(group.get("destroyed", false))


func _release_climb(actor: CharacterBody3D) -> void:
	if _climbing or _climb_pose_active:
		_climbing = false
		_climb_id = ""
		_climb_pose_active = false
		if is_instance_valid(actor) and actor.has_method("set_ship_climb_pose"):
			actor.call("set_ship_climb_pose", {})


func debug_climb_axis(axis: float) -> void:
	_climb_override = axis


func ladder_status() -> Dictionary:
	var rows := {}
	for id: String in _groups:
		var group: Dictionary = _groups[id]
		if group.get("kind", "") != "ladder":
			continue
		rows[id] = {"broken": bool(group.get("broken", false)),
			"destroyed": bool(group.get("destroyed", false)),
			"parts": (group.get("parts", []) as Array).size(),
			"alive": (group.get("parts", []) as Array).filter(
				func(part: Dictionary) -> bool: return bool(part.get("alive", true))).size()}
	return {"climbing": _climbing, "ladder": _climb_id, "rows": rows}
