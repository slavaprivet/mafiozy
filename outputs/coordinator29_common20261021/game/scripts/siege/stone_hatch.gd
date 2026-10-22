extends Node3D
## Stone hatch in the floor of the gate hoarding.
##
## The flaps are real hinged leaves; the stones are real rigid bodies that rest on a
## removable support and fall twenty metres onto the gate approach. The visual side of
## the pile is one MultiMesh, so a dozen independent stones still cost one draw call.
## After they settle they are frozen, which removes them from the solver.

const Layout = preload("res://scripts/siege/gate_defense_layout.gd")
const Art = preload("res://scripts/siege/gate_defense_art.gd")

const STONE_COUNT := 10
const FLAP_OPEN := 1.78
const LEVER_PULL := 1.85

var _castle: Node3D
var _player: CharacterBody3D
var _world: Node3D

var _open := false
var _lever_target := 0.0
var _lever_value := 0.0
var _flap_value := 0.0
var _released := false
var _dust_done := false
var _stone_motion_s := 0.0
var _stones_settled := false

var _left_flap: Node3D
var _right_flap: Node3D
var _lever_pivot: Node3D
var _latch_pivot: Node3D
var _support: StaticBody3D
var _support_shape: CollisionShape3D
var _multimesh: MultiMesh
var _multi_node: MultiMeshInstance3D
var _stones: Array[Dictionary] = []

var _sfx_release: AudioStreamWAV
var _sfx_creak: AudioStreamWAV
var _sfx_impact: AudioStreamWAV
var _dust_texture: ImageTexture
var _rng := RandomNumberGenerator.new()

var _stats := {}


func install(castle: Node3D, player: CharacterBody3D, world: Node3D) -> Dictionary:
	_castle = castle
	_player = player
	_world = world
	name = "StoneHatch"
	_rng.seed = 731806
	_dust_texture = Art.soft_texture(64)
	_sfx_release = Art.sfx(1.10, 58.0, 0.72, 2.4, -0.35, 18)
	_sfx_creak = Art.sfx(0.45, 240.0, 0.28, 8.0, 0.55, 19)
	_sfx_impact = Art.sfx(0.65, 44.0, 0.85, 6.5, -0.25, 20)
	_build_frame()
	_build_flaps()
	_build_lever()
	_build_support()
	_build_stones()
	_stats = {
		"stones": _stones.size(),
		"open": false,
		"released": false,
		"flap_angle": 0.0,
	}
	return {"ok": true, "stats": _stats}


func get_stats() -> Dictionary:
	var lowest := 999.0
	var awake := 0
	for stone: Dictionary in _stones:
		var body: RigidBody3D = stone.get("body")
		if not is_instance_valid(body):
			continue
		lowest = minf(lowest, body.global_position.y)
		if not body.sleeping and not body.freeze:
			awake += 1
	var result := _stats.duplicate(true)
	result["open"] = _open
	result["released"] = _released
	result["flap_angle"] = _flap_value
	result["lowest_stone_y"] = lowest if lowest < 900.0 else 0.0
	result["awake_stones"] = awake
	return result


## ------------------------------------------------------------------ build

func _build_frame() -> void:
	var wood := Art.tinted(Color(0.82, 0.70, 0.56), 0.94, 0.0, true)
	var iron: Material = _castle.call("shared_material", "iron")
	var half := Layout.HATCH_HALF
	var parts: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		parts.append(Art.box(Vector3(Layout.HATCH_CENTRE.x + side * half.x,
			Layout.FLOOR_Y - 0.04, Layout.HATCH_CENTRE.z),
			Vector3(0.13, 0.16, half.y * 2.0 + 0.18), Color(0.34, 0.22, 0.125)))
		parts.append(Art.box(Vector3(Layout.HATCH_CENTRE.x,
			Layout.FLOOR_Y - 0.04, Layout.HATCH_CENTRE.z + side * half.y),
			Vector3(half.x * 2.0 + 0.18, 0.16, 0.13), Color(0.34, 0.22, 0.125)))
	var frame := Art.box_batch(parts, wood)
	frame.name = "HatchFrame"
	add_child(frame)
	var iron_parts: Array[Dictionary] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			iron_parts.append(Art.box(Vector3(Layout.HATCH_CENTRE.x + sx * half.x,
				Layout.FLOOR_Y + 0.015, Layout.HATCH_CENTRE.z + sz * half.y),
				Vector3(0.22, 0.05, 0.22), Color(0.26, 0.275, 0.30)))
	for side: float in [-1.0, 1.0]:
		iron_parts.append(Art.box(Vector3(Layout.HATCH_CENTRE.x,
			Layout.FLOOR_Y + 0.015, Layout.HATCH_CENTRE.z + side * (half.y + 0.08)),
			Vector3(0.34, 0.05, 0.10), Color(0.27, 0.285, 0.31)))
	var fittings := Art.box_batch(iron_parts, iron)
	fittings.name = "HatchFittings"
	add_child(fittings)


func _build_flaps() -> void:
	var wood := Art.tinted(Color(0.82, 0.70, 0.56), 0.95, 0.0, true)
	var iron: Material = _castle.call("shared_material", "iron")
	var half := Layout.HATCH_HALF
	_left_flap = Node3D.new()
	_left_flap.name = "HatchFlapLeft"
	_left_flap.position = Vector3(Layout.HATCH_CENTRE.x - half.x, Layout.FLOOR_Y - 0.045,
		Layout.HATCH_CENTRE.z)
	add_child(_left_flap)
	_right_flap = Node3D.new()
	_right_flap.name = "HatchFlapRight"
	_right_flap.position = Vector3(Layout.HATCH_CENTRE.x + half.x, Layout.FLOOR_Y - 0.045,
		Layout.HATCH_CENTRE.z)
	add_child(_right_flap)
	for flap: Node3D in [_left_flap, _right_flap]:
		var direction: float = 1.0 if flap == _left_flap else -1.0
		var planks: Array[Dictionary] = []
		for i: int in 4:
			var z: float = -half.y + (float(i) + 0.5) * (half.y * 2.0 / 4.0)
			planks.append(Art.box(Vector3(direction * half.x * 0.5, 0.0, z),
				Vector3(half.x - 0.01, 0.085, half.y * 2.0 / 4.0 - 0.008),
				Color(0.36, 0.235, 0.135).lightened(0.012 * float(i))))
		var flap_mesh := Art.box_batch(planks, wood)
		flap_mesh.name = "FlapPlanks"
		flap.add_child(flap_mesh)
		var straps: Array[Dictionary] = []
		for z: float in [-0.34, 0.34]:
			straps.append(Art.box(Vector3(direction * half.x * 0.5, 0.052, z),
				Vector3(half.x * 0.96, 0.028, 0.09), Color(0.24, 0.255, 0.28)))
		var strap_mesh := Art.box_batch(straps, iron)
		strap_mesh.name = "FlapStraps"
		flap.add_child(strap_mesh)
	# Latch bar: visible until the lever releases it.
	_latch_pivot = Node3D.new()
	_latch_pivot.name = "HatchLatch"
	_latch_pivot.position = Vector3(Layout.HATCH_CENTRE.x - 0.18,
		Layout.FLOOR_Y + 0.05, Layout.HATCH_CENTRE.z + half.y + 0.02)
	add_child(_latch_pivot)
	var latch := Art.box(Vector3(0.18, 0.0, -0.02), Vector3(0.50, 0.07, 0.10),
		Color(0.30, 0.31, 0.33))
	var latch_mesh := Art.box_batch([latch], iron)
	latch_mesh.name = "HatchLatchBar"
	_latch_pivot.add_child(latch_mesh)


func _build_lever() -> void:
	var wood := Art.tinted(Color(0.82, 0.70, 0.56), 0.93, 0.0, true)
	var iron: Material = _castle.call("shared_material", "iron")
	var post: Array[Dictionary] = []
	post.append(Art.box(Vector3(Layout.LEVER_POS.x, Layout.FLOOR_Y + 0.55,
		Layout.LEVER_POS.z), Vector3(0.18, 1.10, 0.18), Color(0.30, 0.19, 0.11)))
	post.append(Art.box(Vector3(Layout.LEVER_POS.x, Layout.FLOOR_Y + 0.06,
		Layout.LEVER_POS.z), Vector3(0.52, 0.12, 0.52), Color(0.31, 0.20, 0.115)))
	var post_mesh := Art.box_batch(post, wood)
	post_mesh.name = "HatchLeverPost"
	add_child(post_mesh)
	var fittings: Array[Dictionary] = []
	fittings.append(Art.box(Vector3(Layout.LEVER_POS.x, Layout.FLOOR_Y + 0.96,
		Layout.LEVER_POS.z - 0.10), Vector3(0.30, 0.22, 0.10), Color(0.26, 0.275, 0.30)))
	for side: float in [-1.0, 1.0]:
		fittings.append(Art.box(Vector3(Layout.LEVER_POS.x + side * 0.15,
			Layout.FLOOR_Y + 0.96, Layout.LEVER_POS.z - 0.10),
			Vector3(0.05, 0.05, 0.05), Color(0.33, 0.34, 0.36)))
	var fitting_mesh := Art.box_batch(fittings, iron)
	fitting_mesh.name = "HatchLeverBracket"
	add_child(fitting_mesh)
	_lever_pivot = Node3D.new()
	_lever_pivot.name = "HatchLeverArm"
	_lever_pivot.position = Vector3(Layout.LEVER_POS.x, Layout.FLOOR_Y + 0.96,
		Layout.LEVER_POS.z - 0.10)
	add_child(_lever_pivot)
	var arm_parts: Array[Dictionary] = []
	arm_parts.append(Art.box(Vector3(0.0, 0.26, 0.0), Vector3(0.075, 0.60, 0.075),
		Color(0.30, 0.19, 0.11)))
	arm_parts.append(Art.box(Vector3(0.0, 0.60, 0.0), Vector3(0.19, 0.16, 0.19),
		Color(0.55, 0.34, 0.08)))
	var arm_mesh := Art.box_batch(arm_parts, wood)
	arm_mesh.name = "HatchLeverArmMesh"
	_lever_pivot.add_child(arm_mesh)
	# A taut iron rod from the lever bracket to the latch: the mechanism is visible.
	var rod := Art.beam(Vector3(Layout.LEVER_POS.x, Layout.FLOOR_Y + 0.94,
		Layout.LEVER_POS.z - 0.18), Vector3(Layout.HATCH_CENTRE.x + 0.05,
		Layout.FLOOR_Y + 0.08, Layout.HATCH_CENTRE.z + Layout.HATCH_HALF.y + 0.05),
		0.035, 0.035, Color(0.26, 0.275, 0.30))
	var rod_mesh := Art.box_batch([rod], iron)
	rod_mesh.name = "HatchLeverRod"
	add_child(rod_mesh)


func _build_support() -> void:
	_support = StaticBody3D.new()
	_support.name = "HatchStoneSupport"
	_support.collision_layer = 1
	_support.collision_mask = 1
	_support.position = Vector3(Layout.HATCH_CENTRE.x, Layout.FLOOR_Y - 0.05,
		Layout.HATCH_CENTRE.z)
	add_child(_support)
	_support_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Layout.HATCH_HALF.x * 2.0 - 0.04, 0.10,
		Layout.HATCH_HALF.y * 2.0 - 0.04)
	_support_shape.shape = box
	_support.add_child(_support_shape)


func _build_stones() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.74, 0.71, 0.65)
	material.roughness = 0.97
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = Art.rock_mesh(17, 6, 10)
	_multimesh.instance_count = STONE_COUNT
	_multi_node = MultiMeshInstance3D.new()
	_multi_node.name = "HatchStones"
	_multi_node.multimesh = _multimesh
	_multi_node.material_override = material
	add_child(_multi_node)
	# A deliberately loose, non-overlapping heap. Twelve stones that intersect at
	# spawn would explode apart the frame the support is removed.
	var spots: Array[Vector3] = [
		Vector3(-0.36, 0.0, -0.30), Vector3(0.05, 0.0, -0.35), Vector3(0.37, 0.0, -0.09),
		Vector3(0.29, 0.0, 0.30), Vector3(-0.10, 0.0, 0.36), Vector3(-0.38, 0.0, 0.13),
		Vector3(-0.18, 0.30, -0.02), Vector3(0.19, 0.29, 0.10), Vector3(-0.01, 0.28, -0.19),
		Vector3(0.02, 0.58, 0.02)]
	for index: int in STONE_COUNT:
		var top := index >= 6
		var size := Vector3(0.34, 0.28, 0.34) if not top else Vector3(0.27, 0.22, 0.27)
		var spot: Vector3 = spots[index]
		var at := Vector3(Layout.HATCH_CENTRE.x + spot.x,
			Layout.FLOOR_Y + size.y * 0.5 + spot.y,
			Layout.HATCH_CENTRE.z + spot.z)
		var body := RigidBody3D.new()
		body.name = "HatchStone%d" % index
		body.position = at
		body.mass = 32.0
		body.continuous_cd = true
		body.collision_layer = 1
		body.collision_mask = 1
		body.freeze = true
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.linear_damp = 0.08
		body.angular_damp = 0.35
		add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		var rotation := Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0.0, TAU),
			_rng.randf_range(-0.25, 0.25))
		body.rotation = rotation
		var tone := Color(0.42, 0.40, 0.36).lightened(_rng.randf_range(-0.04, 0.05))
		_multimesh.set_instance_transform(index, Transform3D(
			Basis.from_euler(rotation).scaled(size), at))
		_multimesh.set_instance_color(index, tone)
		_stones.append({"body": body, "size": size, "rotation": rotation, "color": tone,
			"index": index})


## ------------------------------------------------------------------ interaction

func interaction_action() -> Dictionary:
	if not is_instance_valid(_player):
		return {}
	if _player.global_position.distance_to(global_position + Layout.LEVER_POS) > 2.35:
		return {}
	var label := "Открыть каменный люк" if not _open else "Закрыть каменный люк"
	return {"owner": "castle_hatch", "key": "F", "label": label,
		"world": global_position + Layout.LEVER_POS + Vector3.UP * 0.55}


func interact() -> bool:
	if not is_instance_valid(_player):
		return false
	if _player.global_position.distance_to(global_position + Layout.LEVER_POS) > 2.35:
		return false
	_open = not _open
	_lever_target = 1.0 if _open else 0.0
	Art.play_3d(self, _sfx_creak, global_position + Layout.LEVER_POS + Vector3.UP, -2.0,
		0.9 if _open else 1.15)
	if _open and not _released:
		_release_stones()
	return true


func _release_stones() -> void:
	_released = true
	_support_shape.disabled = true
	Art.play_3d(self, _sfx_release, global_position + Vector3(Layout.HATCH_CENTRE.x,
		Layout.FLOOR_Y, Layout.HATCH_CENTRE.z), 0.0, 0.92)
	for stone: Dictionary in _stones:
		var body: RigidBody3D = stone.get("body")
		if not is_instance_valid(body):
			continue
		body.freeze = false
		body.sleeping = false
		body.apply_central_impulse(Vector3(_rng.randf_range(-0.8, 0.8),
			_rng.randf_range(-0.3, 0.1), _rng.randf_range(-0.8, 0.8)) * body.mass * 0.12)
	# A puff at the hatch itself: dust that has lain on the stones for years.
	Art.dust(self, Layout.HATCH_CENTRE + Vector3(0.0, 0.10, 0.0), _dust_texture,
		Color(0.50, 0.46, 0.38))
	_stats["released"] = true


func _process(delta: float) -> void:
	var was_lever := _lever_value
	_lever_value = move_toward(_lever_value, _lever_target, delta * 3.4)
	if is_instance_valid(_lever_pivot):
		_lever_pivot.rotation.x = LEVER_PULL * smoothstep(0.0, 1.0, _lever_value)
	if is_instance_valid(_latch_pivot):
		_latch_pivot.rotation.z = -1.0 * smoothstep(0.0, 1.0, _lever_value)
	var flap_target := 1.0 if _open else 0.0
	_flap_value = move_toward(_flap_value, flap_target, delta * 2.6)
	var angle := FLAP_OPEN * smoothstep(0.0, 1.0, _flap_value)
	if is_instance_valid(_left_flap):
		_left_flap.rotation.z = -angle
	if is_instance_valid(_right_flap):
		_right_flap.rotation.z = angle
	if was_lever != _lever_value:
		_stats["open"] = _open
	_update_stones(delta)


func _update_stones(delta: float) -> void:
	if _stones.is_empty() or _multimesh == null:
		return
	if not _released:
		return
	if _stones_settled:
		return
	var moving := false
	for stone: Dictionary in _stones:
		var body: RigidBody3D = stone.get("body")
		if not is_instance_valid(body):
			continue
		if not body.freeze and not body.sleeping:
			moving = true
		var size: Vector3 = stone.get("size", Vector3.ONE)
		var body_basis := body.global_transform.basis.orthonormalized()
		_multimesh.set_instance_transform(int(stone.get("index", 0)),
			Transform3D(body_basis * Basis.IDENTITY.scaled(size), body.global_position))
		if body.global_position.y < 1.4 and not _dust_done:
			_dust_done = true
			_impact_dust(body.global_position)
	if moving:
		_stone_motion_s += delta
		if _stone_motion_s > 5.0:
			for stone: Dictionary in _stones:
				var body: RigidBody3D = stone.get("body")
				if is_instance_valid(body) and not body.freeze:
					body.freeze = true
					body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			_stones_settled = true


func _impact_dust(at: Vector3) -> void:
	var local := to_local(at)
	Art.dust(self, Vector3(local.x, 0.18, local.z), _dust_texture, Color(0.54, 0.51, 0.44))
	Art.play_3d(self, _sfx_impact, Vector3(at.x, 0.4, at.z), 1.5, 0.95, 60.0)
