extends RefCounted
## Presentation in the three-resident preview only. Never writes source agenda,
## destination, HP, owner generation, physics or save state.
const LOOK_PERIOD := 5.7
const MAX_HEAD_YAW := .24
const MAX_CHEST_YAW := .045
var _rig: WeakRef
var _head := -1
var _chest := -1
var _clock := 0.0
var _phase := 0.0
var _weight := 0.0

func bind(rig: Skeleton3D, source_id: String) -> bool:
	if not Thread.is_main_thread() or not is_instance_valid(rig) or source_id.is_empty(): return false
	_head = rig.find_bone("head")
	_chest = rig.find_bone("chest")
	if _head < 0 or _chest < 0: return false
	_rig = weakref(rig)
	var seed := 2166136261
	for i in source_id.length(): seed = ((seed ^ source_id.unicode_at(i)) * 16777619) & 0xffffffff
	_phase = float(seed % 6283) / 1000.0
	return true

func step(delta: float, horizontal_speed: float) -> bool:
	if not Thread.is_main_thread() or _rig == null or not is_finite(delta) or delta <= 0.0 or delta > .05 or not is_finite(horizontal_speed): return false
	var rig: Skeleton3D = _rig.get_ref()
	if not is_instance_valid(rig): return false
	_clock = fposmod(_clock + delta, LOOK_PERIOD * 64.0)
	_weight = move_toward(_weight, 1.0 if horizontal_speed < .05 else 0.0, delta * 2.5)
	if _weight <= .00001: return true
	var wave := sin(TAU * _clock / LOOK_PERIOD + _phase)
	var head_pose := rig.get_bone_pose_rotation(_head)
	var chest_pose := rig.get_bone_pose_rotation(_chest)
	rig.set_bone_pose_rotation(_head, (head_pose * Quaternion(Vector3.UP, wave * MAX_HEAD_YAW * _weight)).normalized())
	rig.set_bone_pose_rotation(_chest, (chest_pose * Quaternion(Vector3.UP, wave * MAX_CHEST_YAW * _weight)).normalized())
	return true

func dispose() -> void:
	_rig = null
