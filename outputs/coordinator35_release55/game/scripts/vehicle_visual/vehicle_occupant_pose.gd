extends RefCounted
## Source hero.vehiclePose + createArtistVehicle.poseOccupant presentation.
## Caller owns the single pose writer, source seat/transition and body transform.
const REQUIRED := ["chest", "neck", "head", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r", "upperarm_l", "upperarm_r", "forearm_l", "forearm_r", "hand_l", "hand_r", "socket_hand_l", "socket_hand_r"]
var _rig: WeakRef
var _motion: WeakRef
var _rest: Array[Transform3D] = []
var _poses: Array[Transform3D] = []
var _globals: Array[Transform3D] = []
var _parents: PackedInt32Array = []
var _names: Dictionary = {}
var _hand_rest: Dictionary = {}
var _to_root := Transform3D.IDENTITY
var _pivot := Transform3D.IDENTITY
var _scale := 1.0
var _hip := Vector3.ZERO
var _head_yaw := 0.0
var _grip_assignment := ""
var _initialized := false
var _ready := false
var _busy := false
var _epoch := -1

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

## canonical_rest must come from the existing locomotion bind, never last frame.
func configure(skeleton: Skeleton3D, motion: Node3D, canonical_rest: Array[Transform3D], source_scale: float) -> bool:
	if not Thread.is_main_thread() or _busy: return false
	_ready = false
	_rig = null; _motion = null
	if not is_instance_valid(skeleton) or not is_instance_valid(motion) or not motion.is_inside_tree() or not is_finite(source_scale) or source_scale <= 0 or source_scale > 10: return false
	if canonical_rest.size() != skeleton.get_bone_count() or canonical_rest.size() > 128: return false
	_rest = canonical_rest.duplicate(); _parents.clear(); _names.clear(); _globals.clear()
	for i in _rest.size():
		if skeleton.get_bone_parent(i) >= i or not _rest[i].origin.is_finite() or not _rest[i].basis.is_finite() or absf(_rest[i].basis.determinant()) < .000001: return false
		_parents.append(skeleton.get_bone_parent(i)); _names[skeleton.get_bone_name(i)] = i; _globals.append(Transform3D.IDENTITY)
	for name: String in REQUIRED:
		if not _names.has(name): return false
	_rig = weakref(skeleton); _motion = weakref(motion)
	_to_root = motion.global_transform.affine_inverse() * skeleton.global_transform
	_scale = source_scale; _poses = _rest.duplicate(); _pivot = Transform3D.IDENTITY; _compose()
	for side: String in ["l", "r"]: _hand_rest[side] = _rotation("hand_" + side)
	_hip = (_position("thigh_l") + _position("thigh_r")) * .5
	_ready = true; reset()
	return true

func reset(epoch: int = -1) -> void:
	if not Thread.is_main_thread() or _busy: return
	_epoch = epoch; _head_yaw = 0.0; _grip_assignment = ""; _initialized = false

func _compose() -> void:
	for i in _poses.size(): _globals[i] = _poses[i] if _parents[i] < 0 else _globals[_parents[i]] * _poses[i]

func _frame(name: String) -> Transform3D: return _pivot * _to_root * _globals[_names[name]]
func _position(name: String) -> Vector3: return _frame(name).origin
func _rotation(name: String) -> Quaternion: return _frame(name).basis.get_rotation_quaternion()

func _rotate(name: String, x: float = 0, y: float = 0, z: float = 0) -> void:
	var i: int = _names[name]
	var delta := Quaternion(Vector3.RIGHT, x) * Quaternion(Vector3.UP, y) * Quaternion(Vector3.BACK, z)
	var rotation := (_rest[i].basis.get_rotation_quaternion() * delta).normalized()
	_poses[i] = Transform3D(Basis(rotation) * Basis.from_scale(_rest[i].basis.get_scale()), _rest[i].origin)

func _world_rotation(name: String, rotation: Quaternion) -> void:
	var i: int = _names[name]; var parent: int = _parents[i]
	var frame := _pivot * _to_root
	if parent >= 0: frame *= _globals[parent]
	var local := (frame.basis.get_rotation_quaternion().inverse() * rotation).normalized()
	_poses[i] = Transform3D(Basis(local) * Basis.from_scale(_rest[i].basis.get_scale()), _rest[i].origin)
	_compose()

func _point_bone(name: String, end: String, target: Vector3) -> void:
	var origin := _position(name)
	var from := (_position(end) - origin).normalized(); var to := (target - origin).normalized()
	_world_rotation(name, Quaternion(from, to) * _rotation(name))

func _reach_palm(side: String, target: Vector3, hand_q: Quaternion) -> void:
	var upper := "upperarm_" + side; var fore := "forearm_" + side; var hand := "hand_" + side
	var palm: int = _names["socket_hand_" + side]
	var wrist := target - hand_q * (_rest[palm].origin * _scale)
	var shoulder := _position(upper)
	var a := shoulder.distance_to(_position(fore)); var b := _position(fore).distance_to(_position(hand))
	var line := wrist - shoulder
	var distance := minf(a + b - .000001, maxf(absf(a - b) + .000001, line.length()))
	line = line.normalized()
	var bend := Vector3(.35 if side == "r" else -.35, -1, -.15)
	bend = (bend - line * bend.dot(line)).normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0, a * a - along * along))
	var elbow := shoulder + line * along + bend * height
	_point_bone(upper, fore, elbow); _point_bone(fore, hand, wrist); _world_rotation(hand, hand_q)

func _unit(options: Dictionary, key: String, fallback: float) -> float:
	return clampf(float(options[key]), 0, 1) if options.has(key) else fallback

func _hero(fold: float, reach: float, options: Dictionary, driver: bool, grips: Dictionary = {}, forced: String = "") -> void:
	var inner := _unit(options, "innerLeg", fold); var outer := _unit(options, "outerLeg", fold)
	var duck := _unit(options, "duck", 0); var hand := _unit(options, "handReach", reach); var close := _unit(options, "closeReach", 0)
	var door_side := "r" if float(options.get("side", 1)) < 0 else "l"
	var dt := clampf(float(options.get("dt", 1.0 / 60.0)), 0, .1)
	var steer := clampf(float(options.get("steer", 0)), -1, 1) if driver else 0.0
	_head_yaw += (steer * .42 - _head_yaw) * (1.0 - exp(-6.0 * dt))
	var chest := fold * .48 + duck * .3
	_poses = _rest.duplicate(); _pivot = Transform3D.IDENTITY
	_rotate("chest", chest, 0, (-1.0 if door_side == "r" else 1.0) * (hand * .1 - close * .08))
	_rotate("neck", -chest * .72, _head_yaw * .72); _rotate("head", -chest * .28, _head_yaw * .28)
	for side: String in ["l", "r"]:
		var leg := outer if side == door_side else inner
		var door_arm := hand if side == door_side else 0.0; var close_arm := close if side == door_side else 0.0
		var sign_value := 1.0 if side == "l" else -1.0
		_rotate("thigh_" + side, -leg * 1.7); _rotate("shin_" + side, leg * .94); _rotate("foot_" + side, -leg * .09)
		var upper := -fold * (.82 if side == "l" else .72) - reach * (.65 if side == "l" else .1) if driver else -fold * .34
		var fore := -fold * .42 - reach * .3 if driver else -fold * .92
		_rotate("upperarm_" + side, upper - door_arm * .42 - close_arm * .28, 0, sign_value * (door_arm * .58 - close_arm * .34 + (0.0 if driver else .16 * fold)))
		_rotate("forearm_" + side, fore - door_arm * .55 - close_arm * .42, 0, -sign_value * (0.0 if driver else .1 * fold))
	_compose()
	if driver and not grips.is_empty():
		var direct := _position("socket_hand_l").distance_to(grips.left) + _position("socket_hand_r").distance_to(grips.right)
		var crossed := _position("socket_hand_l").distance_to(grips.right) + _position("socket_hand_r").distance_to(grips.left)
		var use_direct := forced == "direct" or (forced != "crossed" and direct <= crossed)
		_reach_palm("l", grips.left if use_direct else grips.right, _hand_rest.l)
		_reach_palm("r", grips.right if use_direct else grips.left, _hand_rest.r)

## World grip positions use the source +Z hero root frame (motion's parent).
## Explicit root_frame is useful for pure tests; omitted = current native parent.
func sample(seat: Dictionary, options: Dictionary = {}, root_frame: Variant = null, epoch: int = 0) -> Dictionary:
	if not Thread.is_main_thread() or _busy or not _ready or not is_instance_valid(_rig.get_ref()) or not is_instance_valid(_motion.get_ref()): return {"valid": false}
	if not seat.get("id") is String or seat.id.is_empty() or seat.id.length() > 128 or not seat.get("can_drive") is bool or not _number(seat.get("side")) or not _number(seat.get("recline")): return {"valid": false}
	if options.size() > 48 or not options.get("pose", {}) is Dictionary or options.get("pose", {}).size() > 32 or (root_frame != null and not root_frame is Transform3D): return {"valid": false}
	var input: Dictionary = options.get("pose", {}).duplicate()
	input.merge(options, true)
	for key: String in ["fold", "reach", "recline", "reclineBlend", "gripBlend", "doorGripBlend", "innerLeg", "outerLeg", "duck", "handReach", "closeReach", "side", "dt", "steer"]:
		if input.has(key) and (not (input[key] is int or input[key] is float) or not is_finite(float(input[key]))): return {"valid": false}
	if absf(float(input.get("recline", seat.recline))) > 1.5: return {"valid": false}
	if not is_finite(float(seat.recline)) or absf(float(seat.recline)) > 1.5 or not float(seat.side) in [-1.0, 1.0]: return {"valid": false}
	var world: Transform3D = _motion.get_ref().get_parent().global_transform if root_frame == null else root_frame
	if not world.origin.is_finite() or not world.basis.is_finite() or absf(world.basis.determinant()) < .000001: return {"valid": false}
	for key: String in ["doorGrip", "steering_left", "steering_right"]:
		if input.has(key) and (not input[key] is Vector3 or not input[key].is_finite()): return {"valid": false}
	if epoch != _epoch: reset(epoch)
	_busy = true
	var fold := _unit(options, "fold", 1); var reach := _unit(options, "reach", 0)
	var recline := float(options.get("recline", seat.recline)) * _unit(options, "reclineBlend", fold)
	var driver: bool = seat.can_drive
	if not _initialized:
		_hero(1, 0, {}, driver); _initialized = true
	var inverse_tilt := Quaternion(Vector3.RIGHT, recline)
	var inverse_world := world.affine_inverse()
	var grip_blend := _unit(options, "gripBlend", -1)
	var grips: Dictionary = {}
	if driver and (fold > .88 if grip_blend < 0 else grip_blend > 0) and input.has("steering_left") and input.has("steering_right"):
		for side: String in ["left", "right"]: grips[side] = inverse_tilt * ((inverse_world * input["steering_" + side]) - _hip) + _hip
		if grip_blend >= 0:
			_hero(fold, reach, input, driver)
			var left := _position("socket_hand_l"); var right := _position("socket_hand_r")
			if _grip_assignment.is_empty(): _grip_assignment = "direct" if left.distance_to(grips.left) + right.distance_to(grips.right) <= left.distance_to(grips.right) + right.distance_to(grips.left) else "crossed"
			var mapped := {"left": grips.left if _grip_assignment == "direct" else grips.right, "right": grips.right if _grip_assignment == "direct" else grips.left}
			grips = {"left": left.lerp(mapped.left, grip_blend), "right": right.lerp(mapped.right, grip_blend)}
		elif _grip_assignment == "crossed": grips = {"left": grips.right, "right": grips.left}
	_hero(fold, reach, input, driver, grips, "direct" if not _grip_assignment.is_empty() else str(options.get("steeringGripAssignment", "")))
	if not driver and fold > .7:
		var angle := .34 * clampf((fold - .7) / .3, 0, 1)
		for side: String in ["l", "r"]: _world_rotation("upperarm_" + side, Quaternion(Vector3.BACK, angle if side == "l" else -angle) * _rotation("upperarm_" + side))
	var door_blend := _unit(options, "doorGripBlend", 0)
	if door_blend > 0 and input.has("doorGrip"):
		var side := "l" if float(seat.side) > 0 else "r"
		var name := "socket_hand_" + side
		var target: Vector3 = inverse_tilt * ((inverse_world * input.doorGrip) - _hip) + _hip
		_reach_palm(side, _position(name).lerp(target, door_blend), _rotation(name))
	var preserved := {"thigh_l": _rotation("thigh_l"), "thigh_r": _rotation("thigh_r"), "head": _rotation("head")}
	var tilt := inverse_tilt.inverse()
	_pivot = Transform3D(Basis(tilt), _hip - tilt * _hip)
	for name: String in ["thigh_l", "thigh_r", "head"]: _world_rotation(name, preserved[name])
	var result := {"valid": true, "poses": _poses.duplicate(), "visual_offset": _pivot.origin, "visual_rotation": tilt, "head_yaw": _head_yaw, "seat_id": seat.id, "epoch": _epoch, "grip_assignment": _grip_assignment}
	_busy = false
	return result

func apply(selected: Dictionary) -> bool:
	if not Thread.is_main_thread() or _busy or not _ready or not selected.get("valid", false) or int(selected.get("epoch", -999)) != _epoch or not is_instance_valid(_rig.get_ref()) or not is_instance_valid(_motion.get_ref()): return false
	if not selected.get("poses") is Array or selected.poses.size() != _rest.size(): return false
	if not selected.get("visual_offset") is Vector3 or not selected.visual_offset.is_finite() or not selected.get("visual_rotation") is Quaternion or not selected.visual_rotation.is_finite() or not selected.visual_rotation.is_normalized(): return false
	for pose: Variant in selected.poses:
		if not pose is Transform3D or not pose.origin.is_finite() or not pose.basis.is_finite(): return false
	var rig: Skeleton3D = _rig.get_ref(); var motion: Node3D = _motion.get_ref()
	for i in _rest.size(): rig.set_bone_pose(i, selected.poses[i])
	motion.position = selected.visual_offset; motion.quaternion = selected.visual_rotation
	return true

func dispose() -> void:
	if not Thread.is_main_thread() or _busy: return
	_ready = false; _rest.clear(); _poses.clear(); _globals.clear(); _names.clear(); _rig = null; _motion = null
