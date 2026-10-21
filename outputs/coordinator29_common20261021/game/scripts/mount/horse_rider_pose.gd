extends RefCounted
## Rider presentation for the castle horse. Presentation only: the host owns the
## single skeleton write through WalkPreviewPlayer._apply_selected_pose() while the
## player's pose authority is "horse". No health, inventory or persistence.
##
## The hero rig has no authored riding clip, so the seated pose is composed from the
## canonical rest transforms exactly like the existing vehicle occupant pose does:
## thighs forward and spread over the barrel, knees down, hands low as if on reins.

const REQUIRED := ["chest", "neck", "head", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r", "upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r", "hand_r"]

var _rig: WeakRef
var _motion: WeakRef
var _rest: Array[Transform3D] = []
var _poses: Array[Transform3D] = []
var _names: Dictionary = {}
var _scale := 1.0
var _hip_height := 0.95
var _ready := false
var _busy := false
var _epoch := -1
var _error := "not_bound"

func configure(skeleton: Skeleton3D, motion: Node3D, canonical_rest: Array[Transform3D], source_scale: float) -> bool:
	if not Thread.is_main_thread() or _busy:
		return false
	_ready = false
	_rig = null
	_motion = null
	_error = "invalid_rig"
	if not is_instance_valid(skeleton) or not is_instance_valid(motion) or not motion.is_inside_tree():
		return false
	if not is_finite(source_scale) or source_scale <= 0.0 or source_scale > 10.0:
		return false
	if canonical_rest.size() != skeleton.get_bone_count() or canonical_rest.size() < 8 or canonical_rest.size() > 128:
		return false
	_rest = canonical_rest.duplicate()
	_poses = _rest.duplicate()
	_names.clear()
	_error = "bone_missing"
	for index: int in _rest.size():
		if not _rest[index].origin.is_finite() or not _rest[index].basis.is_finite():
			return false
		if absf(_rest[index].basis.determinant()) < 0.000001:
			return false
		_names[skeleton.get_bone_name(index)] = index
	for name: String in REQUIRED:
		if not _names.has(name):
			return false
	_scale = source_scale
	_rig = weakref(skeleton)
	_motion = weakref(motion)
	_hip_height = _measure_hip_height(skeleton)
	# The hero rig is a stylised, big-headed figure: its hip joint really sits about
	# half a metre above the player origin. Never "correct" that to a human value.
	if not is_finite(_hip_height) or _hip_height < 0.30 or _hip_height > 1.35:
		_hip_height = 0.49
	_ready = true
	_error = ""
	reset()
	return true

## Hip height in player-local space. The seated pose keeps the hip joint where the
## rest pose puts it, so the caller places the player origin at seat - hip height.
func _measure_hip_height(skeleton: Skeleton3D) -> float:
	var globals: Array[Transform3D] = []
	for index: int in _rest.size():
		var parent: int = skeleton.get_bone_parent(index)
		globals.append(_rest[index] if parent < 0 else globals[parent] * _rest[index])
	var motion: Node3D = _motion.get_ref() as Node3D
	var to_motion := Transform3D.IDENTITY
	if is_instance_valid(motion) and is_instance_valid(skeleton):
		to_motion = motion.global_transform.affine_inverse() * skeleton.global_transform
	var hip: Vector3 = (globals[_names["thigh_l"]].origin + globals[_names["thigh_r"]].origin) * 0.5
	return (to_motion * hip).y

func hip_height() -> float:
	return _hip_height

func reset(epoch: int = -1) -> void:
	if _busy:
		return
	_epoch = epoch
	if _ready:
		_poses = _rest.duplicate()

func is_ready() -> bool:
	return _ready and not _busy and is_instance_valid(_rig.get_ref()) and is_instance_valid(_motion.get_ref())

func status() -> Dictionary:
	return {"ready": is_ready(), "error": _error, "hip_height": _hip_height,
		"bones": _rest.size(), "scale": _scale}

func _rotate(name: String, x: float = 0.0, y: float = 0.0, z: float = 0.0) -> void:
	var index: int = int(_names[name])
	var delta := Quaternion(Vector3.RIGHT, x) * Quaternion(Vector3.UP, y) * Quaternion(Vector3.BACK, z)
	var rotation: Quaternion = (_rest[index].basis.get_rotation_quaternion() * delta).normalized()
	_poses[index] = Transform3D(Basis(rotation) * Basis.from_scale(_rest[index].basis.get_scale()), _rest[index].origin)

## speed_ratio is 0..1 of the gallop speed. The pose leans further forward and the
## body rises a little with the gait, so the rider is not a frozen statue.
func sample(delta: float, speed_ratio: float, airborne: bool, phase: float, turn: float = 0.0) -> Dictionary:
	if not is_ready() or _busy:
		return {"valid": false}
	if not is_finite(delta) or delta <= 0.0 or not is_finite(phase) or not is_finite(turn):
		return {"valid": false}
	_busy = true
	var ratio: float = clampf(speed_ratio, 0.0, 1.0)
	var lean: float = 0.13 + ratio * 0.16
	var bounce: float = sin(phase * 2.0) * 0.018 * ratio
	var pitch: float = 0.0
	_poses = _rest.duplicate()
	_rotate("chest", lean + pitch, 0.0, -turn * 0.06)
	_rotate("neck", -lean * 0.55, -turn * 0.10)
	_rotate("head", -lean * 0.35 + (0.04 if airborne else 0.0), -turn * 0.16)
	for side: String in ["l", "r"]:
		var sign_side: float = 1.0 if side == "l" else -1.0
		# Seat: thighs almost horizontal and opened wide enough for the shins to
		# hang outside the barrel instead of folding under the saddle.
		_rotate("thigh_" + side, -1.52 - ratio * 0.05, 0.0, sign_side * 1.05)
		_rotate("shin_" + side, 1.50, 0.0, 0.0)
		_rotate("foot_" + side, -0.30, 0.0, 0.0)
		# Hands low and forward over the withers, elbows soft: the rein grip.
		_rotate("upperarm_" + side, -0.55 - ratio * 0.08, 0.0, sign_side * 0.55)
		_rotate("forearm_" + side, -0.55, 0.0, 0.0)
		_rotate("hand_" + side, -0.10, 0.0, sign_side * 0.08)
	var offset := Vector3(0.0, bounce, 0.0)
	var rotation := Quaternion(Vector3.RIGHT, -0.03 * ratio)
	_busy = false
	return {"valid": true, "poses": _poses.duplicate(), "visual_offset": offset,
		"visual_rotation": rotation, "epoch": _epoch, "hip_height": _hip_height}

func dispose() -> void:
	if _busy:
		return
	_ready = false
	_rest.clear()
	_poses.clear()
	_names.clear()
	_rig = null
	_motion = null
