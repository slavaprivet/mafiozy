extends RefCounted
## Draw-only arm articulation. The accepted wrists, weapon and simulation state
## are immutable. Restore this layer before every simulation/attachment pass.
var enabled := true
var _saved: Dictionary = {}
var _components: Dictionary = {}
var _shown: Dictionary = {}
var _rig_ref: WeakRef
var _identity := 0
var _speed := 0.0
var _load := 0.0
var _release := 0.0
var _follow := 0.0
var _last: Dictionary = {}

func restore(_host: Node) -> void:
	var rig: Skeleton3D = _rig_ref.get_ref() if _rig_ref != null else null
	if is_instance_valid(rig):
		for bone: int in _saved:
			# An intervening locomotion/death animator owns any pose it replaced.
			if rig.get_bone_pose(bone).is_equal_approx(_shown[bone]):
				_restore_bone(rig, bone, _components[bone])
	_saved.clear()
	_components.clear()
	_shown.clear()

func clear(host: Node, reason: String = "reset") -> void:
	restore(host)
	_identity = 0
	_speed = 0.0
	_load = 0.0
	_release = 0.0
	_follow = 0.0
	_last = {"active": false, "reason": reason}

func present(host: Node, delta: float) -> void:
	restore(host)
	var rig: Skeleton3D = host.get("_rig")
	var weapon: Node3D = host.get("_sword")
	if not enabled or not is_instance_valid(rig) or not is_instance_valid(weapon) \
		or not host.call("_active") or bool(host.get("_unarmed")) \
		or bool(host.get("_sword_grounded")) or bool(host.get("_aiming_throw")) \
		or bool(host.get("_half_sword")) or not weapon.is_visible_in_tree():
		clear(host, "inactive")
		return
	if _identity != weapon.get_instance_id():
		clear(host, "equip")
		_identity = weapon.get_instance_id()
	_rig_ref = weakref(rig)
	var dt := clampf(delta, 0.001, 0.05)
	var speed: float = Vector3(host.get("_omega")).length()
	var acceleration := (speed - _speed) / dt
	_speed = speed
	var steering := bool(host.get("_hold_left")) or bool(host.get("_hold_right"))
	var load_target := clampf(acceleration / 35.0, 0.0, 1.0) if steering else 0.0
	_load = lerpf(_load, load_target, 1.0 - exp(-dt * 18.0))
	_release = lerpf(_release, smoothstep(0.8, 6.0, speed), 1.0 - exp(-dt * 24.0))
	_follow = maxf(_follow * exp(-dt * 6.0), _release * clampf(-acceleration / 40.0, 0.0, 1.0))
	var amount := _load * 0.30 + _release * 0.09 + _follow * 0.18
	var side: StringName = host.call("_active_side")
	var sides: Array[StringName] = []
	if side == &"both": sides.assign([&"left", &"right"])
	else: sides.append(side)
	var max_error := 0.0
	var max_elbow := 0.0
	var applied := 0
	for arm_side: StringName in sides:
		if host.call("_hand_lost31", arm_side): continue
		var result := _arm(host, rig, arm_side, amount)
		max_error = maxf(max_error, float(result.get("hand_error", 0.0)))
		max_elbow = maxf(max_elbow, float(result.get("elbow_shift", 0.0)))
		if bool(result.get("applied", false)): applied += 1
	for bone: int in _saved: _shown[bone] = rig.get_bone_pose(bone)
	_last = {"active": applied > 0, "arms": applied, "load": _load, "release": _release,
		"follow": _follow, "swivel": amount, "max_hand_error": max_error,
		"max_elbow_shift": max_elbow, "weapon_id": host.get("_weapon_id")}

func _arm(host: Node, rig: Skeleton3D, side: StringName, amount: float) -> Dictionary:
	var arm: Dictionary = host.call("_arm_set", side)
	var bones: Array[int] = [arm.clav, arm.upper, arm.fore, arm.hand]
	for bone: int in bones:
		if bone < 0: return {}
	var original: Dictionary = {}
	var components: Dictionary = {}
	for bone: int in bones:
		original[bone] = rig.get_bone_pose(bone)
		components[bone] = [rig.get_bone_pose_position(bone), rig.get_bone_pose_rotation(bone), rig.get_bone_pose_scale(bone)]
	var shoulder: Transform3D = host.call("_chain_global", arm.upper)
	var elbow: Transform3D = host.call("_chain_global", arm.fore)
	var wrist: Transform3D = host.call("_chain_global", arm.hand)
	var clavicle: Transform3D = host.call("_chain_global", arm.clav)
	var l1 := shoulder.origin.distance_to(elbow.origin)
	var l2 := elbow.origin.distance_to(wrist.origin)
	var pole: float = arm.pole
	# Small scapular preparation, solved back to the original wrist. If the
	# accepted arm is already fully extended, retain its shoulder instead.
	var raised := clavicle
	raised.basis = Basis(Vector3.FORWARD, pole * _load * 0.035) * raised.basis
	var parent := rig.get_bone_parent(arm.clav)
	var parent_pose: Transform3D = host.call("_chain_global", parent) if parent >= 0 else Transform3D.IDENTITY
	rig.set_bone_pose(arm.clav, parent_pose.affine_inverse() * raised)
	var moved_shoulder: Transform3D = host.call("_chain_global", arm.upper)
	var distance := moved_shoulder.origin.distance_to(wrist.origin)
	if distance >= l1 + l2 - 0.00001 or distance <= absf(l1 - l2) + 0.00001 \
		or moved_shoulder.origin.distance_to(shoulder.origin) > 0.012:
		_restore_bone(rig, arm.clav, components[arm.clav])
		moved_shoulder = shoulder
		distance = shoulder.origin.distance_to(wrist.origin)
	if distance < 0.001 or l1 < 0.01 or l2 < 0.01:
		for bone: int in bones: _restore_bone(rig, bone, components[bone])
		return {}
	var axis := (wrist.origin - moved_shoulder.origin) / distance
	var along := (l1 * l1 - l2 * l2 + distance * distance) / (2.0 * distance)
	var radius := sqrt(maxf(0.0, l1 * l1 - along * along))
	var radial := elbow.origin - moved_shoulder.origin
	radial -= axis * radial.dot(axis)
	if radial.length_squared() < 1.0e-10:
		for bone: int in bones: _restore_bone(rig, bone, components[bone])
		return {}
	radial = Basis(axis, amount * pole) * radial.normalized()
	var new_elbow := moved_shoulder.origin + axis * along + radial * radius
	var upper_basis := Basis(Quaternion((elbow.origin - shoulder.origin).normalized(),
		(new_elbow - moved_shoulder.origin).normalized())) * shoulder.basis
	var upper_pose := Transform3D(upper_basis, moved_shoulder.origin)
	var clav_global: Transform3D = host.call("_chain_global", arm.clav)
	rig.set_bone_pose(arm.upper, clav_global.affine_inverse() * upper_pose)
	var fore_basis := Basis(Quaternion((wrist.origin - elbow.origin).normalized(),
		(wrist.origin - new_elbow).normalized())) * elbow.basis
	var fore_pose := Transform3D(fore_basis, new_elbow)
	rig.set_bone_pose(arm.fore, upper_pose.affine_inverse() * fore_pose)
	rig.set_bone_pose(arm.hand, fore_pose.affine_inverse() * wrist)
	var actual: Transform3D = host.call("_chain_global", arm.hand)
	var error := actual.origin.distance_to(wrist.origin)
	var valid := actual.is_finite() and error < 0.0002 \
		and actual.basis.x.distance_to(wrist.basis.x) < 0.0002 \
		and actual.basis.y.distance_to(wrist.basis.y) < 0.0002 \
		and rig.get_bone_pose(arm.fore).origin.distance_to(original[arm.fore].origin) < 0.0002 \
		and rig.get_bone_pose(arm.hand).origin.distance_to(original[arm.hand].origin) < 0.0002
	if not valid:
		for bone: int in bones: _restore_bone(rig, bone, components[bone])
		return {"applied": false, "hand_error": error}
	for bone: int in bones:
		_saved[bone] = original[bone]
		_components[bone] = components[bone]
	return {"applied": true, "hand_error": (rig.global_basis * (actual.origin - wrist.origin)).length(),
		"elbow_shift": (rig.global_basis * (elbow.origin - new_elbow)).length()}

func _restore_bone(rig: Skeleton3D, bone: int, components: Array) -> void:
	# Do not decompose a saved Basis again: that can round quaternion/scale on
	# every render tick and feed a tiny accumulating drift back into simulation.
	rig.set_bone_pose_position(bone, components[0])
	rig.set_bone_pose_rotation(bone, components[1])
	rig.set_bone_pose_scale(bone, components[2])

func status() -> Dictionary:
	return _last.duplicate()
