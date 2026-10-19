extends RefCounted
## Pure canonical-pose composition. The resident host is the sole skeleton writer.
## A restrained forearm-treatment gesture: supported left arm, small right-hand
## dressing motions, glance down and breathing. Feet, pelvis and body are untouched.
const REQUIRED := ["pelvis", "chest", "neck", "head", "upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r", "hand_r"]
const COMPOSED := ["chest", "neck", "head", "upperarm_l", "forearm_l", "upperarm_r", "forearm_r"]
const FADE_IN_S := .22
const FADE_OUT_S := .24
var _indices: Dictionary = {}
var _parents: PackedInt32Array = []
var _working: Array[Transform3D] = []
var _global: Array[Transform3D] = []
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _forward := Vector3.BACK
var _reach := 0.0
var _ready := false
var _rig_id := 0
var last_weight := 0.0
var last_elapsed := -1.0

func bind(rig: Skeleton3D, canonical_rest: Array[Transform3D]) -> bool:
	_ready = false
	if not is_instance_valid(rig) or canonical_rest.size() != rig.get_bone_count() or canonical_rest.size() > 128: return false
	_indices.clear(); _parents.clear(); _global.clear()
	for index: int in canonical_rest.size():
		var parent: int = rig.get_bone_parent(index)
		if parent >= index or not canonical_rest[index].is_finite(): return false
		_parents.append(parent); _global.append(Transform3D.IDENTITY)
		_indices[str(rig.get_bone_name(index))] = index
	for bone: String in REQUIRED:
		if not _indices.has(bone): return false
	_working = canonical_rest.duplicate()
	_compose_globals()
	_right = _point("upperarm_r") - _point("upperarm_l")
	_up = _point("head") - _point("pelvis")
	if _right.length_squared() < .0001 or _up.length_squared() < .0001: return false
	_right = _right.normalized(); _up = _up.normalized()
	_forward = _right.cross(_up).normalized()
	if _forward.length_squared() < .9: return false
	# Use the actual imported limb lengths, so differently sized residents share a pose.
	_reach = 0.0
	for side: String in ["l", "r"]:
		_reach += _point("upperarm_" + side).distance_to(_point("forearm_" + side))
		_reach += _point("forearm_" + side).distance_to(_point("hand_" + side))
	_reach *= .5
	if not is_finite(_reach) or _reach <= .001: return false
	_rig_id = rig.get_instance_id()
	_ready = true
	return true

func ready_for(rig: Skeleton3D) -> bool:
	return _ready and is_instance_valid(rig) and rig.get_instance_id() == _rig_id

func _compose_globals() -> void:
	for index: int in _working.size():
		var parent: int = _parents[index]
		_global[index] = _working[index] if parent < 0 else _global[parent] * _working[index]

func _point(name: String) -> Vector3:
	return _global[int(_indices[name])].origin

func _local_turn(name: String, angle: float) -> void:
	var index: int = _indices[name]
	var base: Transform3D = _working[index]
	var rotation: Quaternion = (base.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, angle)).normalized()
	_working[index] = Transform3D(Basis(rotation) * Basis.from_scale(base.basis.get_scale()), base.origin)

func _aim(name: String, end: String, target: Vector3) -> void:
	var index: int = _indices[name]
	var current: Vector3 = _point(end) - _point(name)
	var desired: Vector3 = target - _point(name)
	if current.length_squared() < .000001 or desired.length_squared() < .000001: return
	var rotation: Quaternion = Quaternion(current.normalized(), desired.normalized()) * _global[index].basis.get_rotation_quaternion()
	var parent: int = _parents[index]
	if parent >= 0: rotation = _global[parent].basis.get_rotation_quaternion().inverse() * rotation
	var base: Transform3D = _working[index]
	_working[index] = Transform3D(Basis(rotation.normalized()) * Basis.from_scale(base.basis.get_scale()), base.origin)
	_compose_globals()

func _arm(side: String, target: Vector3) -> void:
	var upper: String = "upperarm_" + side
	var fore: String = "forearm_" + side
	var hand: String = "hand_" + side
	var shoulder: Vector3 = _point(upper)
	var a: float = shoulder.distance_to(_point(fore))
	var b: float = _point(fore).distance_to(_point(hand))
	if a <= .0001 or b <= .0001: return
	var line: Vector3 = target - shoulder
	if line.length_squared() < .000001: return
	var distance: float = clampf(line.length(), absf(a - b) + .0001, a + b - .0001)
	line = line.normalized()
	var bend: Vector3 = -_up + _right * (-.45 if side == "l" else .45) - _forward * .15
	bend -= line * bend.dot(line)
	if bend.length_squared() < .000001: return
	bend = bend.normalized()
	var along: float = (a * a - b * b + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, a * a - along * along))
	var elbow: Vector3 = shoulder + line * along + bend * height
	var wrist: Vector3 = shoulder + line * distance
	_aim(upper, fore, elbow)
	_aim(fore, hand, wrist)

func compose(selected: Dictionary, sample: Dictionary) -> Dictionary:
	last_weight = 0.0; last_elapsed = -1.0
	if not _ready or sample.is_empty() or not selected.get("valid", false) or not selected.get("poses") is Array: return selected
	var elapsed: float = float(sample.get("elapsed_s", -1.0))
	var duration: float = float(sample.get("duration_s", 1.5))
	if not is_finite(elapsed) or not is_finite(duration) or elapsed < 0.0 or duration <= .5 or elapsed > duration: return selected
	var poses: Array[Transform3D] = selected.poses
	if poses.size() != _parents.size(): return selected
	# Fade back to idle BEFORE the 1.5 s treatment ends. No lingering gesture is
	# allowed to start or continue once life advances to the outbound walk.
	var weight: float = smoothstep(0.0, FADE_IN_S, elapsed) * (1.0 - smoothstep(duration - FADE_OUT_S, duration, elapsed))
	last_weight = weight; last_elapsed = elapsed
	if weight <= .00001: return selected
	_working = poses.duplicate()
	var breath: float = sin(elapsed * TAU / 1.4)
	_local_turn("chest", .055 + breath * .012)
	_local_turn("neck", .035)
	_local_turn("head", .13)
	_compose_globals()
	var shoulders: Vector3 = (_point("upperarm_l") + _point("upperarm_r")) * .5
	var pulse: float = sin(elapsed * TAU / .65)
	var circle: float = cos(elapsed * TAU / .65)
	var left_wrist: Vector3 = shoulders + _right * (_reach * .08) - _up * (_reach * .48) + _forward * (_reach * .44)
	var right_wrist: Vector3 = shoulders - _right * (_reach * (.18 + pulse * .035)) - _up * (_reach * (.40 + circle * .018)) + _forward * (_reach * (.49 + pulse * .012))
	_arm("l", left_wrist)
	_arm("r", right_wrist)
	for bone: String in COMPOSED:
		var index: int = _indices[bone]
		var base: Transform3D = poses[index]
		var desired: Transform3D = _working[index]
		var rotation: Quaternion = base.basis.get_rotation_quaternion().slerp(desired.basis.get_rotation_quaternion(), weight)
		poses[index] = Transform3D(Basis(rotation.normalized()) * Basis.from_scale(base.basis.get_scale()), base.origin)
	return selected
