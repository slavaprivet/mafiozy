extends AnimatableBody3D
## DSH_TOWER: the rolling part of the siege ram tower.
##
## The body is a kinematic platform (like the ship) so a player can stand on the
## fighting top and climb its ladder.  It is pushed by the crew: every body in the
## rear push zone contributes, so more men really do move it faster.  Wheels turn
## from the measured distance, in the sign of travel.
##
## Damage is accepted only from siege weapons: cannonballs, catapult stones and
## powder barrels.  Blades and arrows are refused.  Every structural part has its
## own HP and its own debris burst; losing the wheels or the chassis brings the
## whole machine down.

const MODEL_SCRIPT := preload("res://scripts/siege/siege_ram_tower_model.gd")

const WHEEL_R := 0.78
const WHEEL_X := 2.28
const WHEEL_Z: Array[float] = [-2.45, -0.05, 2.35]

const MAX_SPEED := 1.85
const PUSH_BASE := 0.55
const PUSH_PER_MAN := 0.46
const ACCEL := 0.80
const BRAKE := 1.45
const MAX_YAW_RATE := 0.16
const YAW_ACCEL := 0.55
const PUSH_Z_MIN := 3.30
const PUSH_X_HALF := 3.20
const CLIMB_SPEED := 2.15
const RAM_COOLDOWN := 1.75
const MAX_DEBRIS := 130
const DEBRIS_LIFE := 26.0
const MAX_DUST := 70

const ALLOWED_KINDS: Array[String] = ["cannonball", "catapult", "stone", "powder", "barrel",
	"bomb", "explosion", "c4", "ram"]

const PART_HP := {
	"chassis": 380.0, "frame_left": 300.0, "frame_right": 300.0, "front_frame": 260.0,
	"rear_frame": 240.0, "upper_wall": 420.0, "platform": 340.0, "parapet": 220.0,
	"roof": 260.0, "ladder": 90.0, "winch": 140.0, "ram": 300.0, "stores": 60.0,
	"wheel_0": 100.0, "wheel_1": 100.0, "wheel_2": 100.0,
	"wheel_3": 100.0, "wheel_4": 100.0, "wheel_5": 100.0,
}

const PART_DEBRIS := {
	"chassis": 12, "frame_left": 11, "frame_right": 11, "front_frame": 10,
	"rear_frame": 9, "upper_wall": 15, "platform": 13, "parapet": 8,
	"roof": 15, "ladder": 5, "winch": 4, "ram": 14, "stores": 4,
	"wheel_0": 7, "wheel_1": 7, "wheel_2": 7, "wheel_3": 7, "wheel_4": 7, "wheel_5": 7,
}

var world: Node3D = null
var castle: Node3D = null
var player: CharacterBody3D = null
var model: Node3D = null
var data: Dictionary = {}

var _origin := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _speed := 0.0
var _yaw_rate := 0.0
var _wheel_spin := 0.0
var _pushers := 0
var _pusher_timer := 0.0
var _pusher_x := 0.0
var _blocked := false
var _step_transform := Transform3D.IDENTITY
var _installed := false

var _part_shapes: Dictionary = {}
var _part_nodes: Dictionary = {}
var _part_hp: Dictionary = {}
var _broken: Dictionary = {}
var _broken_wheels := 0
var _integrity := 1.0
var _destroyed := false
var _collapse_t := 0.0
var _collapse_roll := 0.0
var _collapse_pitch := 0.0
var _collapsed_once := false

var _ram_pivot: Node3D = null
var _ram_body: StaticBody3D = null
var _ram_rest := Vector3.ZERO
var _ram_state := "rest"
var _ram_t := 0.0
var _ram_offset := 0.0
var _ram_angle := 0.0
var _ram_cooldown := 0.0
var _ram_broken := false
var _ram_hits := 0
var _ram_victims: Dictionary = {}
var _last_hit := {}
var _climbing := false
var _force_pushers := -1
var _climb_override := NAN

var _debris: Array[RigidBody3D] = []
var _debris_life: Array[float] = []
var _dust: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _wood_debris_material: StandardMaterial3D
var _dust_material: StandardMaterial3D
var _dust_mesh: SphereMesh
var _debris_mesh: BoxMesh

func install(world_in: Node3D, castle_in: Node3D, player_in: CharacterBody3D) -> Dictionary:
	world = world_in
	castle = castle_in
	player = player_in
	name = "SiegeRamTowerBody"
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 1
	_rng.seed = 0x51E6E
	_wood_debris_material = StandardMaterial3D.new()
	_wood_debris_material.albedo_color = Color(0.315, 0.225, 0.145)
	_wood_debris_material.roughness = 0.94
	_dust_material = StandardMaterial3D.new()
	_dust_material.albedo_color = Color(0.63, 0.575, 0.485, 0.42)
	_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dust_mesh = SphereMesh.new()
	_dust_mesh.radius = 0.24
	_dust_mesh.height = 0.48
	_debris_mesh = BoxMesh.new()
	_debris_mesh.size = Vector3.ONE
	model = MODEL_SCRIPT.new()
	model.name = "SiegeRamTowerModel"
	add_child(model)
	data = model.call("build")
	if not data.get("ok", false):
		return {"ok": false, "reason": "model_failed"}
	_ram_pivot = data.get("ram_pivot") as Node3D
	_part_nodes = data.get("parts", {})
	_build_collision(data.get("collision", []))
	for id: String in _part_nodes.keys():
		_part_hp[id] = float(PART_HP.get(id, 120.0))
	# The ram's own collider rides the pivot so the head can be shot off.
	_add_ram_collider()
	_ram_rest = _ram_pivot.position
	_installed = true
	return {"ok": true, "parts": _part_nodes.size(), "collision": _part_shapes.size(),
		"colliders": _collision_count(), "ram": is_instance_valid(_ram_pivot)}

func _build_collision(entries: Array) -> void:
	for raw: Variant in entries:
		if not raw is Dictionary:
			continue
		var entry := raw as Dictionary
		var part := str(entry.get("part", ""))
		var box := BoxShape3D.new()
		box.size = entry.get("size", Vector3.ONE)
		var shape := CollisionShape3D.new()
		shape.name = "Hit_%s_%d" % [part, _collision_count()]
		shape.shape = box
		shape.position = entry.get("position", Vector3.ZERO)
		shape.rotation = entry.get("rotation", Vector3.ZERO)
		shape.set_meta("tower_part", part)
		add_child(shape)
		if not _part_shapes.has(part):
			_part_shapes[part] = []
		(_part_shapes[part] as Array).append(shape)

func _add_ram_collider() -> void:
	if not is_instance_valid(_ram_pivot):
		return
	_ram_body = StaticBody3D.new()
	_ram_body.name = "RamHeadBody"
	_ram_body.collision_layer = 1
	_ram_body.collision_mask = 1
	var box := BoxShape3D.new()
	box.size = Vector3(1.05, 1.05, 9.4)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0.0, -2.30, -3.45)
	shape.set_meta("tower_part", "ram")
	_ram_body.add_child(shape)
	_ram_pivot.add_child(_ram_body)
	if not _part_shapes.has("ram"):
		_part_shapes["ram"] = []
	(_part_shapes["ram"] as Array).append(shape)

func _collision_count() -> int:
	var total := 0
	for key: String in _part_shapes.keys():
		total += (_part_shapes[key] as Array).size()
	return total

# ------------------------------------------------------------------ placement
func moor(world_position: Vector3, yaw: float) -> void:
	_origin = world_position
	_yaw = yaw
	_pitch = 0.0
	_roll = 0.0
	_speed = 0.0
	_yaw_rate = 0.0
	_sample_ground(true)
	_sync_transform(true)

func origin() -> Vector3:
	return _origin

func yaw() -> float:
	return _yaw

func destroyed() -> bool:
	return _destroyed

func ram_broken() -> bool:
	return _ram_broken

func speed() -> float:
	return _speed

func pushers() -> int:
	return _pushers

func integrity() -> float:
	return _integrity

# ------------------------------------------------------------------ ground / motion
func _fallback_height(x: float, z: float) -> float:
	if is_instance_valid(world):
		var field: Variant = world.get("preview_battlefield")
		if is_instance_valid(field) and (field as Node).has_method("terrain_height"):
			var local := Vector3(x, 0.0, z)
			if is_instance_valid(castle):
				local = castle.to_local(Vector3(x, 0.0, z))
			return float((field as Node).call("terrain_height", local.x, local.z))
	return 0.0

func _sample_ground(immediate: bool = false) -> void:
	if not _installed:
		return
	var space := get_world_3d().direct_space_state
	var heights: Array[float] = []
	var xform := Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, _roll)), _origin)
	var exclude: Array[RID] = [get_rid()]
	if is_instance_valid(_ram_body):
		exclude.append(_ram_body.get_rid())
	for side: float in [-1.0, 1.0]:
		for z: float in [WHEEL_Z[0], WHEEL_Z[2]]:
			var at := xform * Vector3(side * WHEEL_X, 0.0, z)
			var height := NAN
			if space != null:
				var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0,
					at + Vector3.DOWN * 3.0, 1, exclude)
				var hit := space.intersect_ray(query)
				if not hit.is_empty():
					height = float((hit.get("position", at) as Vector3).y)
			if is_nan(height):
				height = _fallback_height(at.x, at.z)
			heights.append(height)
	if heights.size() != 4:
		return
	var front := (heights[0] + heights[1]) * 0.5
	var rear := (heights[2] + heights[3]) * 0.5
	var left := (heights[0] + heights[2]) * 0.5
	var right := (heights[1] + heights[3]) * 0.5
	var average := (front + rear) * 0.5
	var target_pitch := atan2(front - rear, 4.80)
	var target_roll := atan2(right - left, 4.56)
	var blend := 1.0 if immediate else 1.0 - exp(-6.0 * get_physics_process_delta_time())
	_pitch = lerpf(_pitch, clampf(target_pitch, -0.22, 0.22), blend)
	_roll = lerpf(_roll, clampf(target_roll, -0.16, 0.16), blend)
	_origin.y = lerpf(_origin.y, average + 0.02, 1.0 if immediate else 0.55)

func _update_pushers() -> void:
	if _force_pushers >= 0:
		_pushers = _force_pushers
		_pusher_x = 0.0
		return
	var men := 0
	var sum_x := 0.0
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	if is_instance_valid(player) and player.is_on_floor():
		var local := _local_of(player.global_position)
		if local.z >= PUSH_Z_MIN and local.z <= 6.0 and absf(local.x) <= PUSH_X_HALF and local.y < 3.2:
			var velocity := player.velocity
			velocity.y = 0.0
			var pressing := Input.is_action_pressed(&"preview_move_forward")
			var pushing := velocity.length() > 0.20 and velocity.normalized().dot(forward) > 0.25
			if pressing and not pushing:
				# A man wedged against the timber has no velocity left; use where he
				# is looking/steering.  The camera yaw is independent of the model's
				# own forward offset, so it is the reliable push intent.
				var look_yaw := float(player.get("_camera_yaw"))
				var face := Basis(Vector3.UP, look_yaw) * Vector3(0.0, 0.0, -1.0)
				pushing = face.length_squared() > 0.01 and face.normalized().dot(forward) > 0.15
			if pushing:
				men += 1
				sum_x += local.x
	# Any other body that is actively leaning into the rear of the machine counts.
	if men > 0:
		for candidate: Node in get_tree().get_nodes_in_group("siege_tower_pushers"):
			var helper := candidate as CharacterBody3D
			if not is_instance_valid(helper) or helper == player:
				continue
			var local := _local_of(helper.global_position)
			if local.z < PUSH_Z_MIN or local.z > 6.0 or absf(local.x) > PUSH_X_HALF:
				continue
			var velocity := helper.velocity
			velocity.y = 0.0
			if velocity.length() > 0.18 and velocity.normalized().dot(forward) > 0.20:
				men += 1
				sum_x += local.x
	_pushers = men
	_pusher_x = sum_x / float(men) if men > 0 else 0.0

func _speed_for(men: int) -> float:
	if men <= 0:
		return 0.0
	return PUSH_BASE + PUSH_PER_MAN * float(men - 1) / sqrt(float(men))

func _update_motion(delta: float) -> void:
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var target := _speed_for(_pushers)
	var rate := ACCEL if target > _speed else BRAKE
	_speed = move_toward(_speed, target, rate * delta)
	if _speed < 0.005:
		_speed = 0.0
	var target_yaw := 0.0
	if _pushers > 0 and _speed > 0.05:
		target_yaw = clampf(_pusher_x * 0.055, -MAX_YAW_RATE, MAX_YAW_RATE)
	_yaw_rate = move_toward(_yaw_rate, target_yaw, YAW_ACCEL * delta)
	if _speed < 0.05:
		_yaw_rate = move_toward(_yaw_rate, 0.0, YAW_ACCEL * 2.0 * delta)
	if absf(_yaw_rate) > 0.0005:
		_yaw = wrapf(_yaw + _yaw_rate * delta, -PI, PI)
	if _speed <= 0.0:
		return
	_blocked = _path_blocked()
	if _blocked:
		_speed = 0.0
		return
	var step := forward * _speed * delta
	_origin += step
	_wheel_spin += _speed * delta / float(data.get("wheel_radius", 0.78))

func _path_blocked() -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var xform := Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, _roll)), _origin)
	var exclude: Array[RID] = [get_rid()]
	for x: float in [-1.6, 0.0, 1.6]:
		for y: float in [0.60, 3.80]:
			var from := xform * Vector3(x, y, -7.85)
			var to := xform * Vector3(x, y, -8.55)
			var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
			if not space.intersect_ray(query).is_empty():
				return true
	return false

# ------------------------------------------------------------------ ram
func trigger_ram() -> bool:
	if _destroyed or _ram_broken or not _installed:
		return false
	if _ram_cooldown > 0.0 or _ram_state != "rest":
		return false
	_ram_state = "windup"
	_ram_t = 0.0
	_ram_cooldown = RAM_COOLDOWN
	_ram_victims.clear()
	_last_hit = {"ok": false, "reason": "in_flight"}
	return true

func _update_ram(delta: float) -> void:
	_ram_cooldown = maxf(0.0, _ram_cooldown - delta)
	if not is_instance_valid(_ram_pivot):
		return
	match _ram_state:
		"windup":
			_ram_t += delta
			var t := clampf(_ram_t / 0.34, 0.0, 1.0)
			_ram_offset = ease(t, 0.6) * 0.62
			_ram_angle = -0.045 * sin(t * PI)
			if t >= 1.0:
				_ram_state = "strike"
				_ram_t = 0.0
		"strike":
			_ram_t += delta
			var t := clampf(_ram_t / 0.17, 0.0, 1.0)
			_ram_offset = lerpf(0.62, -1.28, t * t)
			_ram_angle = 0.02 * t
			_ram_pivot.position = _ram_rest + Vector3(0.0, 0.0, _ram_offset)
			_ram_pivot.rotation.x = _ram_angle
			# Sweep every frame of the thrust: a single end-of-swing check can
			# already be past a thin gate leaf.
			_ram_sweep()
			if t >= 1.0:
				_ram_state = "recover"
				_ram_t = 0.0
		"recover":
			_ram_t += delta
			var t := clampf(_ram_t / 0.62, 0.0, 1.0)
			_ram_offset = lerpf(-1.28, 0.0, ease(t, 0.45))
			_ram_angle = 0.06 * (1.0 - t)
			if t >= 1.0:
				_ram_state = "rest"
				_ram_offset = 0.0
				_ram_angle = 0.0
		_:
			_ram_offset = 0.0
			_ram_angle = 0.0
	_ram_pivot.position = _ram_rest + Vector3(0.0, 0.0, _ram_offset)
	_ram_pivot.rotation.x = _ram_angle

func ram_tip_world() -> Vector3:
	if not is_instance_valid(_ram_pivot):
		return _origin
	return _ram_pivot.global_transform * Vector3(0.0, -2.28, -8.05)

func _ram_sweep() -> void:
	if _destroyed:
		return
	var tip := ram_tip_world()
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var space := get_world_3d().direct_space_state
	var found: Array[Dictionary] = []
	if space != null:
		var sphere := SphereShape3D.new()
		sphere.radius = 1.25
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = sphere
		params.transform = Transform3D(Basis.IDENTITY, tip)
		params.collision_mask = 1 | 2 | 4
		var exclude: Array[RID] = [get_rid()]
		if is_instance_valid(_ram_body):
			exclude.append(_ram_body.get_rid())
		if is_instance_valid(player):
			exclude.append(player.get_rid())
		params.exclude = exclude
		found = space.intersect_shape(params, 16)
	var hits := 0
	for raw: Dictionary in found:
		var collider: Variant = raw.get("collider")
		if not is_instance_valid(collider):
			continue
		var key := (collider as Node).get_instance_id()
		if _ram_victims.has(key):
			continue
		_ram_victims[key] = true
		if _apply_ram_to(collider, tip, forward):
			hits += 1
	if hits > 0:
		_ram_hits += hits
		_last_hit = {"ok": true, "hits": _ram_hits, "new_hits": hits, "point": tip, "forward": forward}
		_spawn_dust(tip, 6, forward)
		_spawn_splinters(tip, 8, forward)

func _ram_hit() -> void:
	_ram_sweep()

func _apply_ram_to(collider: Object, point: Vector3, direction: Vector3) -> bool:
	var node := collider as Node
	if node == null or _is_own_descendant(node):
		return false
	# Castle masonry / gate: a short, heavy local blast of the same kind the
	# catapult uses, so the gate planks and nearby bricks react normally.
	if is_instance_valid(castle):
		if castle.has_method("owns_collider") and bool(castle.call("owns_collider", node)):
			var result: Variant = castle.call("apply_explosion", {
				"position": point, "radius": 1.05, "power": 210.0,
				"direction": direction, "event_id": "ram-tower",
			})
			return result is Dictionary and bool((result as Dictionary).get("ok", false))
	# Camp props and the dressing around the walls.
	var field: Variant = world.get("preview_battlefield") if is_instance_valid(world) else null
	if is_instance_valid(field):
		var props := (field as Node).get_node_or_null("BattlefieldProps")
		if is_instance_valid(props) and props.has_method("apply_damage"):
			var broken := int(props.call("apply_damage", point, 1.15, 150.0, "ram"))
			if broken > 0:
				return true
	# Powder barrels: a ram blow sets them off.
	if node.has_meta("ship_powder_barrel"):
		var walk: Node = node
		for _i: int in 5:
			if walk == null:
				break
			if walk.has_method("explode_from_hit"):
				walk.call("explode_from_hit", point, direction)
				return true
			walk = walk.get_parent()
	# A body that takes damage itself.
	var target := node
	for _i: int in 6:
		if target == null:
			break
		if target.has_method("apply_hit") and target != self:
			var result: Variant = target.call("apply_hit", point, 120.0, direction * 900.0, "ram")
			if result is Dictionary and bool((result as Dictionary).get("ok", false)):
				return true
		if target.has_method("take_hit"):
			target.call("take_hit", 120.0, point, direction, "ram", self)
			return true
		target = target.get_parent()
	if node is RigidBody3D:
		(node as RigidBody3D).apply_impulse(direction * 1000.0 + Vector3.UP * 160.0, point - node.global_position)
		return true
	return false

func _is_own_descendant(node: Node) -> bool:
	var walk: Node = node
	for _i: int in 8:
		if walk == null:
			return false
		if walk == self:
			return true
		walk = walk.get_parent()
	return false

# ------------------------------------------------------------------ pusher prompt
func ram_prompt_world() -> Vector3:
	var local_handle: Vector3 = data.get("anchors", {}).get("ram_handle_world_local", Vector3(0.0, 2.15, 3.9))
	return global_transform * local_handle

func player_at_ram(_unused: Vector3 = Vector3.ZERO) -> bool:
	if not is_instance_valid(player):
		return false
	var local := _local_of(player.global_position)
	if local.z >= 2.55 and local.z <= 5.9 and absf(local.x) <= 3.05 and local.y <= 3.2:
		return true
	return player.global_position.distance_to(ram_prompt_world()) <= 3.1

# ------------------------------------------------------------------ ladder
func climb_assist(actor: CharacterBody3D, delta: float) -> void:
	if not _installed or _destroyed or not is_instance_valid(actor):
		return
	if not is_finite(delta) or delta <= 0.0 or delta > 0.25:
		return
	var local := _local_of(actor.global_position)
	# The ladder is on the right flank: the rear push frame is never in its zone.
	var on_ladder: bool = local.x > 2.45 and local.x < 3.75 and local.z > -0.35 and local.z < 1.45
	var in_zone: bool = local.y > -0.30 and local.y < 9.05 and on_ladder
	if not in_zone:
		_climbing = false
		return
	var axis := 0.0
	if not is_nan(_climb_override):
		axis = clampf(_climb_override, -1.0, 1.0)
	elif InputMap.has_action(&"preview_move_forward") and Input.is_action_pressed(&"preview_move_forward"):
		axis += 1.0
	if is_nan(_climb_override) and InputMap.has_action(&"preview_move_back") and Input.is_action_pressed(&"preview_move_back"):
		axis -= 1.0
	var just_forward := (not is_nan(_climb_override) and _climb_override > 0.0) or Input.is_action_just_pressed(&"preview_move_forward")
	# W starts a climb, S starts a descent from the balcony.
	if not _climbing and not just_forward and axis >= 0.0:
		return
	_climbing = true
	if is_zero_approx(axis):
		return
	var bottom := 0.04
	var top := 8.82
	var next_y := clampf(local.y + CLIMB_SPEED * axis * delta, bottom, top)
	var grab := minf(1.0, delta * 7.0)
	var next_local := Vector3(lerpf(local.x, 3.34, grab), next_y, lerpf(local.z, 0.55, grab))
	if axis < 0.0 and local.y > 8.45 and local.x < 2.56:
		# Step out through the parapet gap onto the ladder before descending.
		next_local.x = 2.68
	if axis > 0.0 and next_y >= top - 0.001:
		next_local = Vector3(2.30, 8.99, 0.55)
		_climbing = false
	if axis < 0.0 and next_y <= bottom + 0.001:
		next_local.x = 3.42
	actor.global_position = to_global(next_local)
	actor.velocity = Vector3(0.0, CLIMB_SPEED * axis, 0.0)

func climbing() -> bool:
	return _climbing

# ------------------------------------------------------------------ damage
func apply_hit(world_point: Vector3, damage: float, _impulse: Vector3, kind: String) -> Dictionary:
	if _destroyed:
		return {"ok": false, "reason": "destroyed"}
	if not ALLOWED_KINDS.has(kind):
		_refuse_fx(world_point)
		return {"ok": false, "reason": "immune", "kind": kind}
	if not world_point.is_finite():
		return {"ok": false, "reason": "bad_point"}
	var amount := damage
	match kind:
		"cannonball":
			amount = maxf(damage, 70.0) * 1.55
		"catapult", "stone":
			amount = maxf(damage, 300.0) * 1.30
		"powder", "barrel", "bomb", "explosion", "c4":
			amount = maxf(damage, 420.0) * 1.55
		"ram":
			amount = damage
	var local := _local_of(world_point)
	var part := _classify(local)
	var dealt := _damage_part(part, amount, world_point)
	_last_hit = {"ok": dealt, "part": part, "damage": amount, "kind": kind, "point": world_point}
	return {"ok": dealt, "part": part, "damage": amount, "kind": kind,
		"integrity": _integrity, "destroyed": _destroyed, "ram_broken": _ram_broken}

func blast_at(world_point: Vector3, radius: float, power: float, kind: String = "catapult") -> bool:
	if _destroyed:
		return false
	if not world_point.is_finite():
		return false
	var local := _local_of(world_point)
	if absf(local.x) > 4.6 or local.z < -7.8 or local.z > 5.2 or local.y < -1.0 or local.y > 13.4:
		return false
	var amount := 420.0
	if kind == "powder" or kind == "barrel" or kind == "explosion" or kind == "c4":
		amount = 650.0
	elif kind == "cannonball":
		amount = 120.0
	elif power > 0.0:
		amount = clampf(power * 1.45, 160.0, 720.0)
	var part := _classify(local)
	var dealt := _damage_part(part, amount, world_point)
	var splashed := false
	# Splash a little into the neighbouring parts so a barrel does not merely
	# scratch one plank.
	for other: String in _part_hp.keys():
		if other == part or _broken.has(other):
			continue
		var center := _part_center(other)
		if center.distance_to(local) <= maxf(1.6, radius) and _part_hp.has(other):
			if _damage_part(other, amount * 0.22, world_point):
				splashed = true
	_last_hit = {"ok": dealt or splashed or _destroyed, "part": part, "damage": amount, "kind": kind,
		"integrity": _integrity, "destroyed": _destroyed, "blast": true}
	_spawn_dust(world_point, 10, Vector3.UP)
	return dealt or splashed or _destroyed

func _refuse_fx(point: Vector3) -> void:
	# A blade rings off the iron and oak but does no harm.
	_spawn_dust(point, 2, Vector3.UP)

func _damage_part(part: String, amount: float, point: Vector3) -> bool:
	if _broken.has(part) or not _part_hp.has(part) or _destroyed:
		return false
	var before := float(_part_hp[part])
	var after := maxf(0.0, before - maxf(0.0, amount))
	_part_hp[part] = after
	if after <= 0.0:
		_break_part(part, point)
	_recompute_integrity()
	return true

func _recompute_integrity() -> void:
	var total := 0.0
	var left := 0.0
	for id: String in _part_hp.keys():
		var max_hp := float(PART_HP.get(id, 120.0))
		total += max_hp
		left += float(_part_hp[id])
	_integrity = clampf(left / maxf(1.0, total), 0.0, 1.0)

func _part_center(part: String) -> Vector3:
	var shapes: Array = _part_shapes.get(part, [])
	if shapes.is_empty():
		return Vector3(0.0, 3.0, 0.0)
	var sum := Vector3.ZERO
	var count := 0
	for raw: Variant in shapes:
		var shape := raw as CollisionShape3D
		if is_instance_valid(shape):
			sum += shape.global_position
			count += 1
	if count == 0:
		return Vector3(0.0, 3.0, 0.0)
	return _local_of(sum / float(count))

func _classify(local: Vector3) -> String:
	if local.y > 10.05:
		return "roof"
	if local.y > 8.30:
		if absf(local.x) > 2.32 or local.z < -2.55 or (local.z > 2.55 and absf(local.x) > 1.25):
			return "parapet"
		return "platform"
	if local.z > 2.48 and local.y < 5.0:
		if absf(local.x) < 1.05 and local.y < 8.9:
			return "ladder"
		return "rear_frame"
	if local.y > 4.55:
		return "upper_wall"
	if local.y < 1.90:
		for index: int in 6:
			var side := -1.0 if index < 3 else 1.0
			var slot := index % 3
			var at := Vector3(side * WHEEL_X, WHEEL_R, WHEEL_Z[slot])
			if local.distance_to(at) < 1.05:
				return "wheel_%d" % index
		return "chassis"
	if local.z < -2.45:
		if absf(local.x) < 1.45 and local.y < 3.65:
			return "ram"
		return "front_frame"
	if local.z > 2.35:
		return "rear_frame"
	if local.y > 3.30 and local.z > 1.25 and absf(local.x) < 1.15:
		return "winch"
	if absf(local.x) > 1.72:
		return "frame_left" if local.x < 0.0 else "frame_right"
	if local.y < 1.55:
		return "chassis"
	return "frame_left" if local.x < 0.0 else "frame_right"

func _break_part(part: String, point: Vector3) -> void:
	if _broken.has(part):
		return
	_broken[part] = true
	var node: Node3D = _part_nodes.get(part)
	if is_instance_valid(node):
		node.visible = false
	_disable_part(part)
	_spawn_part_debris(part, point)
	_spawn_dust(point, 8, Vector3.UP)
	if part == "ram":
		_ram_broken = true
		_ram_state = "rest"
		_ram_offset = 0.0
		_ram_angle = 0.0
		if is_instance_valid(_ram_pivot):
			_ram_pivot.rotation.x = 0.55
			_ram_pivot.position = _ram_rest + Vector3(0.0, -0.12, 0.10)
		if is_instance_valid(_ram_body):
			_ram_body.collision_layer = 0
			_ram_body.collision_mask = 0
	if part.begins_with("wheel_"):
		_broken_wheels += 1
	var collapse := false
	if part == "chassis":
		collapse = true
	if _broken.has("frame_left") and _broken.has("frame_right"):
		collapse = true
	if _broken_wheels >= 3:
		collapse = true
	if collapse:
		_collapse()
	elif _broken_wheels >= 2 and not _broken.has("front_frame"):
		# Two wheels gone: the machine slews and stops until it is finished off.
		_speed = 0.0

func _disable_part(part: String) -> void:
	var shapes: Array = _part_shapes.get(part, [])
	for raw: Variant in shapes:
		var shape := raw as CollisionShape3D
		if is_instance_valid(shape):
			shape.set_deferred("disabled", true)

func _spawn_part_debris(part: String, point: Vector3) -> void:
	var count := int(PART_DEBRIS.get(part, 8))
	var center := _part_center(part)
	if center.is_zero_approx():
		center = _local_of(point)
	var pieces := clampi(count, 3, 18)
	for i: int in pieces:
		var at := to_global(center + Vector3(_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-0.4, 0.8), _rng.randf_range(-1.0, 1.0)))
		_spawn_debris(at, Vector3(_rng.randf_range(-2.5, 2.5), _rng.randf_range(1.0, 4.5),
			_rng.randf_range(-2.5, 2.5)))

func _spawn_splinters(point: Vector3, count: int, forward: Vector3) -> void:
	for i: int in count:
		_spawn_debris(point + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3),
			_rng.randf_range(-0.3, 0.3)), forward * _rng.randf_range(4.0, 8.0)
			+ Vector3(_rng.randf_range(-2.0, 2.0), _rng.randf_range(1.0, 4.0), _rng.randf_range(-2.0, 2.0)),
			true)

func _collapse() -> void:
	if _destroyed:
		return
	_destroyed = true
	_speed = 0.0
	_yaw_rate = 0.0
	_ram_state = "rest"
	_collapse_t = 0.0
	_collapse_roll = 0.0
	_collapse_pitch = 0.0
	for part: String in _part_shapes.keys():
		_disable_part(part)
	if is_instance_valid(_ram_body):
		_ram_body.collision_layer = 0
		_ram_body.collision_mask = 0
	# A burst of timber and dust across the whole frame.
	for i: int in 78:
		var at := to_global(Vector3(_rng.randf_range(-2.7, 2.7),
			_rng.randf_range(0.8, 12.2), _rng.randf_range(-3.3, 3.4)))
		_spawn_debris(at, Vector3(_rng.randf_range(-5.5, 5.5), _rng.randf_range(0.5, 6.5),
			_rng.randf_range(-5.5, 5.5)))
	_spawn_dust(to_global(Vector3(0.0, 5.0, 0.0)), 34, Vector3.UP)
	_collapsed_once = true
	print("DSH_TOWER_COLLAPSE parts=", _broken.size(), " debris=", _debris.size())

# ------------------------------------------------------------------ debris / dust
func _spawn_debris(world_point: Vector3, velocity: Vector3, splinter: bool = false) -> void:
	while _debris.size() >= MAX_DEBRIS:
		var old: RigidBody3D = _debris.pop_front()
		_debris_life.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var body := RigidBody3D.new()
	body.name = "TowerDebris_%d" % _rng.randi_range(0, 99999)
	body.mass = 7.0
	body.collision_layer = 4
	body.collision_mask = 1
	body.continuous_cd = true
	var size := Vector3(_rng.randf_range(0.20, 0.95), _rng.randf_range(0.10, 0.26), _rng.randf_range(0.16, 0.55))
	if splinter:
		size = Vector3(_rng.randf_range(0.05, 0.12), _rng.randf_range(0.05, 0.10), _rng.randf_range(0.5, 1.1))
	var view := MeshInstance3D.new()
	view.mesh = _debris_mesh
	view.scale = size
	view.material_override = _wood_debris_material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(view)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var debris_root: Node = world if is_instance_valid(world) else get_parent()
	if is_instance_valid(debris_root):
		debris_root.add_child(body)
	else:
		add_child(body)
	body.global_position = world_point
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0),
		_rng.randf_range(-8.0, 8.0))
	_debris.append(body)
	_debris_life.append(DEBRIS_LIFE)

func _spawn_dust(at: Vector3, count: int, direction: Vector3) -> void:
	while _dust.size() >= MAX_DUST:
		var old: Dictionary = _dust.pop_front()
		var old_node: Node3D = old.get("node")
		if is_instance_valid(old_node):
			old_node.queue_free()
	for i: int in count:
		var mote := MeshInstance3D.new()
		mote.mesh = _dust_mesh
		mote.material_override = _dust_material
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dust_root: Node = world if is_instance_valid(world) else get_parent()
		if is_instance_valid(dust_root):
			dust_root.add_child(mote)
		else:
			add_child(mote)
		mote.global_position = at + Vector3(_rng.randf_range(-0.4, 0.4),
			_rng.randf_range(-0.2, 0.4), _rng.randf_range(-0.4, 0.4))
		_dust.append({"node": mote, "age": 0.0, "life": _rng.randf_range(0.6, 1.3),
			"velocity": direction * _rng.randf_range(0.3, 1.8)
				+ Vector3(_rng.randf_range(-1.4, 1.4), _rng.randf_range(0.4, 1.9), _rng.randf_range(-1.4, 1.4))})

func _update_debris(delta: float) -> void:
	var index := _debris.size() - 1
	while index >= 0:
		_debris_life[index] -= delta
		var body := _debris[index]
		var remove := _debris_life[index] <= 0.0 or not is_instance_valid(body)
		if not remove and body.global_position.y < -30.0:
			remove = true
		if remove:
			if is_instance_valid(body):
				body.queue_free()
			_debris.remove_at(index)
			_debris_life.remove_at(index)
		index -= 1
	var dust_index := _dust.size() - 1
	while dust_index >= 0:
		var entry: Dictionary = _dust[dust_index]
		var node: Node3D = entry.get("node")
		if not is_instance_valid(node):
			_dust.remove_at(dust_index)
			dust_index -= 1
			continue
		var age := float(entry.get("age", 0.0)) + delta
		var life := maxf(0.05, float(entry.get("life", 1.0)))
		var velocity: Vector3 = entry.get("velocity", Vector3.ZERO)
		velocity.y -= 2.1 * delta
		velocity *= 1.0 - clampf(2.3 * delta, 0.0, 1.0)
		node.global_position += velocity * delta
		var t := clampf(age / life, 0.0, 1.0)
		var grow := lerpf(0.55, 3.4, t)
		node.scale = Vector3(grow, grow * 0.8, grow)
		node.transparency = 1.0 - t * 0.15
		if t >= 1.0:
			node.queue_free()
			_dust.remove_at(dust_index)
		else:
			entry["age"] = age
			entry["velocity"] = velocity
			_dust[dust_index] = entry
		dust_index -= 1

func debris_count() -> int:
	return _debris.size()

# ------------------------------------------------------------------ transform / loop
func _sync_transform(force_immediate: bool = false) -> void:
	var xform := Transform3D(Basis.from_euler(Vector3(_pitch + _collapse_pitch, _yaw, _roll + _collapse_roll)), _origin)
	if not is_inside_tree():
		transform = xform
		return
	var parent := get_parent()
	var local_xform := xform
	if parent is Node3D:
		local_xform = (parent as Node3D).global_transform.affine_inverse() * xform
	var use_physics := sync_to_physics
	var immediate := force_immediate or not Engine.is_in_physics_frame()
	if use_physics and not immediate:
		transform = local_xform
	else:
		if use_physics:
			sync_to_physics = false
			transform = local_xform
			sync_to_physics = true
		else:
			transform = local_xform
	if use_physics:
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xform)

func _local_of(world_point: Vector3) -> Vector3:
	return Transform3D(Basis.from_euler(Vector3(_pitch + _collapse_pitch, _yaw, _roll + _collapse_roll)),
		_origin).affine_inverse() * world_point

func simulate_step(delta: float) -> void:
	if not _installed:
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	delta = minf(delta, 0.1)
	_step_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, _roll)), _origin)
	if _destroyed:
		_collapse_t += delta
		var t := clampf(_collapse_t / 1.0, 0.0, 1.0)
		_collapse_roll = ease(t, 0.5) * 0.42
		_collapse_pitch = ease(t, 0.5) * -0.16
		_origin.y = maxf(_origin.y - delta * 0.55, _fallback_height(_origin.x, _origin.z) - 0.4)
		if t >= 1.0 and _part_nodes.size() > 0:
			for node: Variant in _part_nodes.values():
				if is_instance_valid(node):
					(node as Node3D).visible = false
		_update_debris(delta)
		_sync_transform()
		return
	_pusher_timer -= delta
	if _pusher_timer <= 0.0:
		_pusher_timer = 0.2
		_update_pushers()
	_sample_ground()
	_update_motion(delta)
	_update_ram(delta)
	if is_instance_valid(model):
		var wheels: Array = data.get("wheels", [])
		for raw: Variant in wheels:
			var wheel := raw as Node3D
			if is_instance_valid(wheel):
				wheel.rotation.x = _wheel_spin
	_update_debris(delta)
	_sync_transform()
	_carry_rider()

func _carry_rider() -> void:
	if not is_instance_valid(player):
		return
	if _destroyed or _climbing:
		return
	if not player.is_on_floor():
		return
	var local := _local_of(player.global_position)
	if local.y < 1.05 or absf(local.x) > 2.60 or absf(local.z) > 3.10:
		return
	var now := Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, _roll)), _origin)
	var motion := now * _step_transform.affine_inverse()
	if motion.is_equal_approx(Transform3D.IDENTITY):
		return
	player.global_position = motion * player.global_position

# ------------------------------------------------------------------ QA / prompt
func prompt_action() -> Dictionary:
	if _destroyed or not _installed or not is_instance_valid(player):
		return {}
	if not player_at_ram():
		return {}
	if _ram_broken:
		return {}
	var label := "Ударить тараном"
	if _ram_cooldown > 0.0:
		label = "Таран отходит"
	return {"owner": "tower", "kind": "tower_ram", "label": label, "key": "E",
		"world": ram_prompt_world() + Vector3.UP * 0.9}

func snapshot() -> Dictionary:
	return {"installed": _installed, "destroyed": _destroyed, "origin": _origin,
		"yaw": _yaw, "speed": _speed, "pushers": _pushers, "integrity": _integrity,
		"ram_broken": _ram_broken, "ram_state": _ram_state, "ram_hits": _ram_hits,
		"ram_tip": ram_tip_world(), "broken_parts": _broken.keys(), "broken_wheels": _broken_wheels,
		"debris": _debris.size(), "dust": _dust.size(), "part_hp": _part_hp.duplicate(true),
		"last_hit": _last_hit, "colliders": _collision_count(), "climbing": _climbing,
		"model_parts": _part_nodes.size()}

func debug_break(part: String) -> bool:
	if not _part_hp.has(part) or _broken.has(part):
		return false
	_damage_part(part, 99999.0, global_position + Vector3.UP * 3.0)
	return true

func debug_pushers(value: int) -> void:
	_pushers = maxi(0, value)
	_pusher_x = 0.0

func debug_force_pushers(value: int) -> void:
	_force_pushers = value

func debug_climb_axis(axis: float) -> void:
	_climb_override = axis

func wheel_angle() -> float:
	var wheels: Array = data.get("wheels", [])
	if wheels.is_empty():
		return 0.0
	var wheel := wheels[0] as Node3D
	return wheel.rotation.x if is_instance_valid(wheel) else 0.0
