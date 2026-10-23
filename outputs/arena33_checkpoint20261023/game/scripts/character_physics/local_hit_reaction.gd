extends RefCounted
## Local joint presentation springs. J is caller-supplied N*s; inertia is kg*m².
## No HP, body momentum, source admission, locomotion, or Nodes are owned here.
## Ancestor redistribution/caps are game tuning, not momentum conservation.
const NAMES := ["root", "pelvis", "spine_01", "chest", "neck", "head", "socket_head", "clavicle_l", "upperarm_l", "forearm_l", "hand_l", "socket_hand_l", "clavicle_r", "upperarm_r", "forearm_r", "hand_r", "socket_hand_r", "socket_weapon", "socket_back", "socket_steering_l", "socket_steering_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r", "socket_seat"]
# Verified canonical name-parent links from npc_visual_loader.gd, including sockets.
const PARENTS := [-1, 0, 1, 2, 3, 4, 5, 3, 7, 8, 9, 10, 3, 12, 13, 14, 15, 15, 3, 3, 3, 1, 21, 22, 1, 24, 25, 1]
const SELECTED := ["spine_01", "chest", "head", "upperarm_l", "forearm_l", "upperarm_r", "forearm_r"]
const ENDPOINT := {"spine_01": "chest", "chest": "neck", "head": "socket_head", "upperarm_l": "forearm_l", "forearm_l": "hand_l", "upperarm_r": "forearm_r", "forearm_r": "hand_r"}
const MAX_J_NS := 300.0
const MAX_DISTANCE_M := .75
const MAX_ANGLE_RAD := .25
const MAX_VELOCITY_RAD_S := 8.0
const EVENT_CAPACITY := 128
var _bound := false
var _actor := ""
var _epoch: Variant
var _names: Array[String] = []
var _parents: Array[int] = []
var _rest: Array[Transform3D] = []
var _rest_global: Array[Transform3D] = []
var _indices: Dictionary = {}
var _inertia: Dictionary = {}
var _theta: Dictionary = {}
var _velocity: Dictionary = {}
var _events: Array[String] = []

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "valid": false, "error": reason}

static func _epoch_valid(value: Variant) -> bool:
	return value is int and value >= 0 or value is String and not value.is_empty() and value.length() <= 96

static func _same_epoch(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _finite_vector(value: Variant) -> bool:
	return value is Vector3 and value.is_finite()

static func _transform_valid(value: Variant) -> bool:
	if not value is Transform3D or not value.is_finite(): return false
	var basis: Basis = value.basis
	var lengths := Vector3(basis.x.length(), basis.y.length(), basis.z.length())
	if not lengths.is_finite() or minf(lengths.x, minf(lengths.y, lengths.z)) <= .0000001 or maxf(lengths.x, maxf(lengths.y, lengths.z)) > 1000000.0: return false
	if not is_finite(basis.determinant()) or basis.determinant() <= .000000000001: return false
	# Preserve the input's nonuniform scale. Shear/mirrors have no unambiguous
	# canonical quaternion and are rejected before any spring state advances.
	var x := basis.x / lengths.x; var y := basis.y / lengths.y; var z := basis.z / lengths.z
	return absf(x.dot(y)) <= .0001 and absf(x.dot(z)) <= .0001 and absf(y.dot(z)) <= .0001

static func _length(value: Vector3) -> float:
	var maximum := maxf(absf(value.x), maxf(absf(value.y), absf(value.z)))
	return 0.0 if maximum == 0.0 else maximum * (value / maximum).length()

static func _cap(value: Vector3, maximum: float) -> Vector3:
	var largest := maxf(absf(value.x), maxf(absf(value.y), absf(value.z)))
	if largest == 0.0: return Vector3.ZERO
	var scaled := value / largest
	var norm := scaled.length()
	return scaled * (maximum / norm) if largest > maximum / norm else value

static func _inertia_value(value: Variant) -> Variant:
	if _number(value) and value >= .000001 and value <= 1000000.0: return Vector3.ONE * float(value)
	if _finite_vector(value) and minf(value.x, minf(value.y, value.z)) >= .000001 and maxf(value.x, maxf(value.y, value.z)) <= 1000000.0: return value
	return null

func bind(actor_id: String, epoch_id: Variant, rig: Dictionary) -> Dictionary:
	if _bound: return _fail("already_bound")
	if actor_id.is_empty() or actor_id.length() > 128: return _fail("actor_id")
	if not _epoch_valid(epoch_id): return _fail("epoch_id")
	if not rig.get("names") is Array or not rig.get("parents") is Array or not rig.get("rest_local") is Array or not rig.get("inertia_kg_m2") is Dictionary: return _fail("rig_fields")
	if rig.names.size() != 28 or rig.parents.size() != 28 or rig.rest_local.size() != 28: return _fail("rig_count")
	var names: Array[String] = []; var parents: Array[int] = []; var rest: Array[Transform3D] = []
	var indices := {}; var inertia := {}; var globals: Array[Transform3D] = []
	for i in range(28):
		var name: Variant = rig.names[i]; var parent: Variant = rig.parents[i]
		if not name is String or not NAMES.has(name) or indices.has(name): return _fail("rig_names")
		if not parent is int or parent < -1 or parent >= i: return _fail("rig_parents")
		if not _transform_valid(rig.rest_local[i]): return _fail("rig_rest")
		names.append(name); parents.append(parent); rest.append(rig.rest_local[i]); indices[name] = i
		globals.append(rest[i] if parent < 0 else globals[parent] * rest[i])
		if not _transform_valid(globals[i]): return _fail("rig_rest_global")
	for i in range(28):
		var canonical := NAMES.find(names[i])
		var expected_parent: int = PARENTS[canonical]
		if expected_parent < 0:
			if parents[i] != -1: return _fail("rig_hierarchy")
		elif parents[i] < 0 or names[parents[i]] != NAMES[expected_parent]: return _fail("rig_hierarchy")
	for name: String in SELECTED:
		var value: Variant = _inertia_value(rig.inertia_kg_m2.get(name))
		if value == null: return _fail("rig_inertia")
		inertia[name] = value
	# Commit only a complete validated rig. Caller arrays/dictionaries remain owned.
	_actor = actor_id; _epoch = epoch_id; _names = names; _parents = parents
	_rest = rest; _rest_global = globals; _indices = indices; _inertia = inertia; _bound = true
	_clear_motion()
	return {"ok": true, "valid": true}

func _clear_motion() -> void:
	_events.clear(); _theta.clear(); _velocity.clear()
	for name: String in SELECTED:
		_theta[name] = Vector3.ZERO; _velocity[name] = Vector3.ZERO

func reset(new_epoch: Variant) -> Dictionary:
	if not _bound: return _fail("unbound")
	if not _epoch_valid(new_epoch): return _fail("epoch_id")
	var seen := _events.duplicate() if _same_epoch(new_epoch, _epoch) else []
	_epoch = new_epoch; _clear_motion(); _events.assign(seen)
	return {"ok": true, "valid": true}

static func _segment_distance(point: Vector3, start: Vector3, end: Vector3) -> float:
	var segment := end - start; var offset := point - start
	if not segment.is_finite() or not offset.is_finite(): return INF
	var length := _length(segment)
	if length == 0.0: return _length(offset)
	if not is_finite(length): return INF
	var direction := segment / length
	var projection := clampf(offset.dot(direction), 0.0, length)
	return _length(point - (start + direction * projection))

static func _hit_failure(reason: String) -> Dictionary:
	return {"result": _fail(reason)}

func _prepare_hit(event: Dictionary, world_frames: Dictionary) -> Dictionary:
	# One validation/projection path for preflight and commit. Staging is local,
	# includes CURRENT velocity capping, and never stores/consumes a receipt token.
	if not _bound: return _hit_failure("unbound")
	if not event.get("actor_id") is String or event.actor_id != _actor: return _hit_failure("actor_mismatch")
	if not _epoch_valid(event.get("epoch_id")) or not _same_epoch(event.epoch_id, _epoch): return _hit_failure("epoch_mismatch")
	if not event.get("event_id") is String or event.event_id.is_empty() or event.event_id.length() > 256: return _hit_failure("event_id")
	if _events.has(event.event_id): return _hit_failure("event_replayed")
	if not _finite_vector(event.get("world_point")): return _hit_failure("world_point")
	if not _finite_vector(event.get("impulse_ns")): return _hit_failure("impulse_ns")
	var point: Vector3 = event.world_point; var impulse: Vector3 = event.impulse_ns
	if _length(impulse) > MAX_J_NS: return _hit_failure("impulse_range")
	if world_frames.size() != 28: return _hit_failure("world_frame_count")
	for name: String in _names:
		if not _transform_valid(world_frames.get(name)): return _hit_failure("world_frame")
	# Shape checks constrain supplied frames; caller still owns their authenticity.
	var common_scale: Vector3 = world_frames[_names[0]].basis.get_scale() / _rest_global[0].basis.get_scale()
	if absf(common_scale.x - common_scale.y) > .00001 or absf(common_scale.x - common_scale.z) > .00001: return _hit_failure("world_rig_scale")
	for i in range(28):
		var frame: Transform3D = world_frames[_names[i]]
		var expected_scale := _rest_global[i].basis.get_scale() * common_scale.x
		var scale_error := (frame.basis.get_scale() - expected_scale).abs()
		if maxf(scale_error.x, maxf(scale_error.y, scale_error.z)) > .00001: return _hit_failure("world_rig_scale")
		if _parents[i] >= 0:
			var parent_frame: Transform3D = world_frames[_names[_parents[i]]]
			var expected_length := _length(parent_frame.basis * _rest[i].origin)
			if absf(_length(frame.origin - parent_frame.origin) - expected_length) > .002: return _hit_failure("world_rig_length")
	var target := ""; var distance := INF
	# Stable order resolves geometric ties, with no random draw or fallback point.
	for name: String in SELECTED:
		var candidate := _segment_distance(point, world_frames[name].origin, world_frames[ENDPOINT[name]].origin)
		if candidate < distance: distance = candidate; target = name
	if target.is_empty() or distance > MAX_DISTANCE_M: return _hit_failure("contact_distance")
	var next_velocity := _velocity.duplicate(true)
	var index: int = _indices[target]; var depth := 0
	while index >= 0:
		var name := _names[index]
		if _inertia.has(name):
			var frame: Transform3D = world_frames[name]
			var torque := (point - frame.origin).cross(impulse)
			if not torque.is_finite(): return _hit_failure("angular_overflow")
			var local: Vector3 = frame.basis.orthonormalized().transposed() * torque
			var inertia: Vector3 = _inertia[name]
			var change := Vector3(local.x / inertia.x, local.y / inertia.y, local.z / inertia.z) * pow(.35, depth)
			if not change.is_finite(): return _hit_failure("angular_overflow")
			change = _cap(change, MAX_VELOCITY_RAD_S)
			next_velocity[name] = _cap(next_velocity[name] + change, MAX_VELOCITY_RAD_S)
			depth += 1
		index = _parents[index]
	return {"result": {"ok": true, "valid": true, "target": target, "distance_m": distance}, "next_velocity": next_velocity}

func can_add_hit(event: Dictionary, world_frames: Dictionary) -> Dictionary:
	# Exact public add_hit result without spring/FIFO/input mutation.
	return _prepare_hit(event, world_frames).result

func add_hit(event: Dictionary, world_frames: Dictionary) -> Dictionary:
	var prepared := _prepare_hit(event, world_frames)
	var result: Dictionary = prepared.result
	if not result.ok: return result
	_velocity = prepared.next_velocity
	_events.append(event.event_id)
	if _events.size() > EVENT_CAPACITY: _events.pop_front()
	return result

static func _omega(name: String) -> float:
	return 18.0 if name == "head" else 14.0 if name in ["spine_01", "chest"] else 16.0

static func _limits(name: String) -> Array[Vector3]:
	if name == "head": return [Vector3(-.65, -.65, -.45), Vector3(.65, .65, .45)]
	if name in ["spine_01", "chest"]: return [Vector3(-.35, -.45, -.30), Vector3(.35, .45, .30)]
	if name.begins_with("upperarm"): return [Vector3.ONE * -2.6, Vector3.ONE * 2.6]
	return [Vector3(-2.53, -.15, -.15), Vector3(.087, .15, .15)]

static func _inside_envelope(rotation: Quaternion, rest_rotation: Quaternion, bounds: Array[Vector3]) -> bool:
	# Euler is used only for the anatomical acceptance test, never as a kick axis.
	var relative := (rest_rotation.inverse() * rotation).get_euler()
	for axis in range(3):
		if relative[axis] < bounds[0][axis] or relative[axis] > bounds[1][axis]: return false
	return true

func _base_valid(base: Array) -> bool:
	if base.size() != 28: return false
	for transform: Variant in base:
		if not _transform_valid(transform): return false
	return true

func _base_rig_valid(base: Array) -> bool:
	for i in range(28):
		var origin_error: Vector3 = (base[i].origin - _rest[i].origin).abs()
		var scale_error: Vector3 = (base[i].basis.get_scale() - _rest[i].basis.get_scale()).abs()
		if maxf(origin_error.x, maxf(origin_error.y, origin_error.z)) > .00001 or maxf(scale_error.x, maxf(scale_error.y, scale_error.z)) > .00001: return false
	return true

func sample(delta: float, base_local: Array) -> Dictionary:
	if not _bound: return _fail("unbound")
	if not is_finite(delta) or delta < 0: return _fail("delta")
	if not _base_valid(base_local): return _fail("base_pose")
	if not _base_rig_valid(base_local): return _fail("invalid_base_rig")
	var dt := minf(delta, .1)
	var poses: Array[Transform3D] = []
	for transform: Transform3D in base_local: poses.append(transform)
	var next_theta := {}; var next_velocity := {}; var selected_pose := {}
	var active := false; var energy := 0.0
	for name: String in SELECTED:
		var theta: Vector3 = _theta[name]; var velocity: Vector3 = _velocity[name]
		var omega := _omega(name); var decay := exp(-omega * dt)
		var common := theta * omega + velocity
		var next: Vector3 = _cap((theta + common * dt) * decay, MAX_ANGLE_RAD)
		var speed: Vector3 = _cap((velocity - common * (omega * dt)) * decay, MAX_VELOCITY_RAD_S)
		if _length(next) < .00001 and _length(speed) < .0001: next = Vector3.ZERO; speed = Vector3.ZERO
		next_theta[name] = next; next_velocity[name] = speed
		active = active or next != Vector3.ZERO or speed != Vector3.ZERO
		var inertia: Vector3 = _inertia[name]
		energy += .5 * (inertia.x * (speed.x * speed.x + omega * omega * next.x * next.x) + inertia.y * (speed.y * speed.y + omega * omega * next.y * next.y) + inertia.z * (speed.z * speed.z + omega * omega * next.z * next.z))
		var index: int = _indices[name]; var base: Transform3D = base_local[index]
		if next != Vector3.ZERO:
			var rest_rotation := _rest[index].basis.orthonormalized().get_rotation_quaternion()
			var base_rotation := base.basis.orthonormalized().get_rotation_quaternion()
			var bounds := _limits(name)
			# A pre-existing out-of-envelope base keeps its ENTIRE basis exactly.
			# Local rotation-vector composition preserves the current joint axes.
			if _inside_envelope(base_rotation, rest_rotation, bounds):
				var angle := _length(next)
				var goal := (base_rotation * Quaternion(next / angle, angle)).normalized()
				var result_rotation := goal
				if not _inside_envelope(goal, rest_rotation, bounds):
					var low := 0.0; var high := 1.0
					for step in range(6):
						var fraction := (low + high) * .5
						var candidate := base_rotation.slerp(goal, fraction).normalized()
						if _inside_envelope(candidate, rest_rotation, bounds): low = fraction
						else: high = fraction
					result_rotation = base_rotation.slerp(goal, low).normalized()
					if low == 0.0 or not _inside_envelope(result_rotation, rest_rotation, bounds): result_rotation = base_rotation
				if result_rotation != base_rotation:
					poses[index] = Transform3D(Basis(result_rotation).scaled_local(base.basis.get_scale()), base.origin)
		selected_pose[name] = poses[index]
	if not is_finite(energy): return _fail("energy_overflow")
	_theta = next_theta; _velocity = next_velocity
	return {"ok": true, "valid": true, "poses": poses, "selected_pose": selected_pose, "active": active, "residual_energy_j": energy}

func apply_to_selected(delta: float, base_selected: Dictionary) -> Dictionary:
	if not _bound: return _fail("unbound")
	if not base_selected.get("valid") is bool or not base_selected.valid or not base_selected.get("poses") is Array: return _fail("base_invalid")
	if base_selected.has("authority_epoch") and (not _epoch_valid(base_selected.authority_epoch) or not _same_epoch(base_selected.authority_epoch, _epoch)): return _fail("base_epoch")
	if base_selected.has("visual_offset") and not _finite_vector(base_selected.visual_offset): return _fail("visual_offset")
	if base_selected.has("visual_rotation"):
		var rotation: Variant = base_selected.visual_rotation
		if not rotation is Quaternion or not rotation.is_finite() or absf(rotation.length_squared() - 1.0) > .0001: return _fail("visual_rotation")
	var sampled := sample(delta, base_selected.poses)
	if not sampled.ok: return sampled
	var result := base_selected.duplicate(true)
	for key: String in sampled: result[key] = sampled[key]
	return result

func snapshot() -> Dictionary:
	return {"bound": _bound, "actor_id": _actor, "epoch_id": _epoch, "names": _names.duplicate(), "parents": _parents.duplicate(), "rest_local": _rest.duplicate(), "inertia_kg_m2": _inertia.duplicate(true), "theta_rad": _theta.duplicate(true), "velocity_rad_s": _velocity.duplicate(true), "event_ids": _events.duplicate()}
