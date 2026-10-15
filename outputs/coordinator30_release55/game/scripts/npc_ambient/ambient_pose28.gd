extends "res://scripts/hospital/npc_treatment_pose28.gd"
## Pure pose composition using the existing calibrated two-bone arm solver.
## Only preview_resident_host commits these transforms to the actual skeleton.
const KINDS := ["bench", "book", "look_around", "watch", "sleeves", "stretch", "rub_palms", "neck", "shoulders", "collar", "wipe_forehead", "scratch_head", "window", "look_far", "newspaper", "camera", "pocket", "phone"]
const META := "npc_ambient28"
var _ambient_rig: WeakRef
var _legs_ready := false
var _hand_rest30: Dictionary = {}
var _bench_feet30: Dictionary = {}
var _bench_start30: Dictionary = {}

func bind(rig: Skeleton3D, canonical_rest: Array[Transform3D]) -> bool:
	if not super.bind(rig, canonical_rest): return false
	_ambient_rig = weakref(rig)
	for side30: String in ["l","r"]:
		if not _indices.has("socket_hand_"+side30): return false
		_hand_rest30[side30] = _global[_indices["hand_"+side30]].basis.get_rotation_quaternion()
	_legs_ready = true
	for bone: String in ["thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]:
		if not _indices.has(bone): _legs_ready = false
	return true

static func sample(body: CharacterBody3D, delta: float, physical: Dictionary) -> Dictionary:
	if not is_instance_valid(body) or not body.is_inside_tree() or not body.is_on_floor() or physical.is_empty() or delta <= 0.0: return {}
	if not physical.get("horizontal") is Vector3 or Vector3(physical.horizontal).length()/delta > .05: return {}
	var value: Variant = body.get_meta(META, {})
	if not value is Dictionary or not value.get("active", false) or (str(value.get("kind", "")) not in KINDS and value.get("kind") != "police_phone30"): return {}
	if int(value.get("frame", -1)) != Engine.get_physics_frames() or int(value.get("body_id", -1)) != body.get_instance_id() or absf(float(value.get("delta", 0.0))-delta) > .00001: return {}
	var owner: Variant = value.get("owner")
	if not owner is WeakRef or not is_instance_valid(owner.get_ref()): return {}
	var elapsed: float = float(value.get("elapsed_s", -1.0))
	var duration: float = float(value.get("duration_s", 0.0))
	if not is_finite(elapsed) or not is_finite(duration) or elapsed < 0 or duration < 4 or duration > 8 or elapsed > duration: return {}
	if not owner.get_ref().sample_current(value): return {}
	return value

static func suppress(body: CharacterBody3D) -> void:
	if not is_instance_valid(body): return
	var value: Variant = body.get_meta(META, {})
	if not value is Dictionary: return
	var owner: Variant = value.get("owner")
	if owner is WeakRef and is_instance_valid(owner.get_ref()): owner.get_ref().pose_suppressed()

## Death/retirement owners may call this before freeing or disabling the body.
## The same inactive owner stamp exists during APPROACH/DOCK/ALIGN as well.
static func cancel_body(body: CharacterBody3D, reason: String = "life_ended") -> void:
	if not is_instance_valid(body): return
	var value: Variant = body.get_meta(META, {})
	if not value is Dictionary: return
	var owner: Variant = value.get("owner")
	if owner is WeakRef and is_instance_valid(owner.get_ref()): owner.get_ref().cancel(reason)

static func committed(rig: Skeleton3D, value: Dictionary) -> void:
	var owner: Variant = value.get("owner")
	if owner is WeakRef and is_instance_valid(owner.get_ref()): owner.get_ref().pose_committed(rig, value)

func _turn_global(name: String, axis: Vector3, angle: float) -> void:
	var index: int = _indices[name]
	var rotation: Quaternion = Quaternion(axis, angle) * _global[index].basis.get_rotation_quaternion()
	var parent: int = _parents[index]
	if parent >= 0: rotation = _global[parent].basis.get_rotation_quaternion().inverse() * rotation
	var base: Transform3D = _working[index]
	_working[index] = Transform3D(Basis(rotation.normalized()) * Basis.from_scale(base.basis.get_scale()), base.origin)
	_compose_globals()

func _p(origin: Vector3, right: float, up: float, forward: float) -> Vector3:
	return origin + (_right*right + _up*up + _forward*forward) * _reach

func _leg(side: String, foot_target: Vector3) -> void:
	var thigh: String = "thigh_" + side
	var shin: String = "shin_" + side
	var foot: String = "foot_" + side
	var foot_rotation: Quaternion = _global[int(_indices[foot])].basis.get_rotation_quaternion()
	var hip: Vector3 = _point(thigh)
	var a: float = hip.distance_to(_point(shin)); var b: float = _point(shin).distance_to(_point(foot))
	var line: Vector3 = foot_target-hip
	if minf(a,b) < .0001 or line.length_squared() < .000001: return
	var distance: float = clampf(line.length(), absf(a-b)+.0001, a+b-.0001)
	line = line.normalized()
	var bend: Vector3 = _forward-line*line.dot(_forward)
	if bend.length_squared() < .00001: bend = _right * (-1.0 if side == "l" else 1.0)
	bend = bend.normalized()
	var along: float = (a*a-b*b+distance*distance)/(2.0*distance)
	var knee: Vector3 = hip + line*along + bend*sqrt(maxf(0,a*a-along*along))
	_aim(thigh, shin, knee); _aim(shin, foot, hip+line*distance)
	# Keep the foot orientation from the sampled standing pose, with its sole down.
	var index: int = _indices[foot]
	var rotation: Quaternion = foot_rotation
	var parent: int = _parents[index]
	if parent >= 0: rotation = _global[parent].basis.get_rotation_quaternion().inverse()*rotation
	var base: Transform3D = _working[index]
	_working[index] = Transform3D(Basis(rotation.normalized())*Basis.from_scale(base.basis.get_scale()),base.origin)
	_compose_globals()

func _hand_rotation30(side: String, rotation: Quaternion) -> void:
	var index: int = _indices["hand_"+side]
	var parent: int = _parents[index]
	if parent >= 0: rotation = _global[parent].basis.get_rotation_quaternion().inverse()*rotation
	var base: Transform3D = _working[index]
	_working[index] = Transform3D(Basis(rotation.normalized())*Basis.from_scale(base.basis.get_scale()),base.origin)
	_compose_globals()

func _palm30(side: String, target: Vector3, fingers: Vector3) -> void:
	# The actual canonical palm socket converts a surface target to its wrist.
	var socket: Vector3 = _working[_indices["socket_hand_"+side]].origin
	var rest: Quaternion = _hand_rest30[side]
	var direction: Vector3 = rest*socket
	if direction.length_squared() < .00001 or fingers.length_squared() < .00001: return
	var rotation: Quaternion = Quaternion(direction.normalized(),fingers.normalized())*rest
	_arm(side,target-rotation*socket)
	_hand_rotation30(side,rotation)

func _seat(value: Dictionary) -> bool:
	if not _legs_ready or not value.get("seat") is Vector3 or not is_instance_valid(_ambient_rig.get_ref()): return false
	var rig: Skeleton3D = _ambient_rig.get_ref()
	_bench_feet30.clear(); _bench_start30.clear()
	for side30: String in ["l","r"]: _bench_start30[side30] = _global[_indices["foot_"+side30]]
	# On this canonical rig `pelvis` is the low root anchor. Anatomical hip
	# position is the thigh-joint midpoint, not that misleading bone origin.
	var hips: Vector3 = (_point("thigh_l")+_point("thigh_r"))*.5
	var target: Vector3 = rig.to_local(Vector3(value.seat)+Vector3.UP*.10)
	var pelvis: int = _indices["pelvis"]; var parent: int = _parents[pelvis]
	var desired: Vector3 = _point("pelvis")+target-hips
	var local: Vector3 = _global[parent].affine_inverse()*desired if parent >= 0 else desired
	_working[pelvis] = Transform3D(_working[pelvis].basis,local)
	_compose_globals()
	for side30: String in ["l","r"]:
		var hip: Vector3 = _point("thigh_"+side30)
		var upper: float = hip.distance_to(_point("shin_"+side30))
		var lower: float = _point("shin_"+side30).distance_to(_point("foot_"+side30))
		# A high real bench and short legs require naturally hanging feet. Their
		# reachable anchors are explicit; the actor's capsule remains supported.
		var foot: Vector3 = hip+_forward*(upper*.94+lower*.04)-_up*(upper*.34+lower*.98)
		_bench_feet30[side30] = foot
		_leg(side30,foot)
	_turn_global("chest",_right,-.07)
	_arm("l",_point("shin_l")+_up*_reach*.08)
	_arm("r",_point("shin_r")+_up*_reach*.08)
	return true

func _bench_blend_contacts30(poses: Array[Transform3D], weight: float) -> void:
	_working = poses.duplicate(); _compose_globals()
	for side30: String in ["l","r"]:
		var start: Transform3D = _bench_start30[side30]
		var target: Vector3 = start.origin.lerp(_bench_feet30[side30],weight)
		_leg(side30,target)
		var index: int = _indices["foot_"+side30]; var parent: int = _parents[index]
		var rotation: Quaternion = start.basis.get_rotation_quaternion()
		if parent >= 0: rotation = _global[parent].basis.get_rotation_quaternion().inverse()*rotation
		var base: Transform3D = _working[index]
		_working[index] = Transform3D(Basis(rotation.normalized())*Basis.from_scale(base.basis.get_scale()),base.origin)
		_compose_globals()
	for side30: String in ["l","r"]:
		for part30: String in ["thigh_","shin_","foot_"]:
			var index: int = _indices[part30+side30]; poses[index] = _working[index]

func compose(selected: Dictionary, value: Dictionary) -> Dictionary:
	last_weight = 0.0
	value["pose_weight"] = 0.0
	if not _ready or not selected.get("valid", false) or not selected.get("poses") is Array: return selected
	var kind: String = str(value.get("kind", ""))
	if kind not in KINDS and kind != "police_phone30": return selected
	var elapsed: float = float(value.get("elapsed_s", 0.0)); var duration: float = float(value.get("duration_s", 0.0))
	var fade: float = .75 if kind == "bench" else .35
	var weight: float = smoothstep(0.0, fade, elapsed) * (1.0-smoothstep(duration-fade, duration, elapsed))
	last_weight = weight; last_elapsed = elapsed
	if weight <= .00001: return selected
	var poses: Array[Transform3D] = selected.poses
	if poses.size() != _parents.size(): return selected
	_working = poses.duplicate(); _compose_globals()
	var shoulders: Vector3 = (_point("upperarm_l") + _point("upperarm_r"))*.5
	var head: Vector3 = _point("head")
	var pelvis: Vector3 = _point("pelvis")
	var slow: float = sin(elapsed*TAU/3.6)
	var pulse: float = sin(elapsed*TAU/.65)
	match kind:
		"bench":
			if not _seat(value): last_weight = 0.0; return selected
			_turn_global("head", _up, slow*.08)
		"book":
			_arm("l", _p(shoulders,-.23,-.40,.52)); _arm("r", _p(shoulders,.23,-.40+.012*pulse,.52))
			_turn_global("head", _right, .24)
		"look_around":
			_turn_global("chest", _up, slow*.15); _turn_global("neck", _up, slow*.45)
		"watch":
			_arm("l", _p(shoulders,.12,-.26,.45)); _arm("r", _p(shoulders,.14,-.15,.46))
			_turn_global("head", _right, .27); _turn_global("head", _up, -.12)
		"sleeves":
			var side: float = 1.0 if fmod(elapsed,4.0) < 2.0 else -1.0
			_arm("l", _p(shoulders,-.30,-.38,.48)); _arm("r", _p(shoulders,.10+side*.22,-.32+.04*pulse,.37))
			_turn_global("head", _right, .18)
		"stretch":
			_arm("l", _p(shoulders,-.48,.78,.14)); _arm("r", _p(shoulders,.48,.78,.14))
			_turn_global("chest", _right, -.13-.025*slow); _turn_global("head", _right, -.12)
		"rub_palms":
			_arm("l", _p(shoulders,-.03,-.34+.025*pulse,.48)); _arm("r", _p(shoulders,.03,-.34-.025*pulse,.48))
		"neck":
			_turn_global("neck", _forward, slow*.24); _turn_global("head", _right, .12*cos(elapsed*TAU/3.6))
		"shoulders":
			_arm("l", _p(shoulders,-.43,-.60+.06*slow,.03+.07*cos(elapsed*2.0)))
			_arm("r", _p(shoulders,.43,-.60+.06*slow,.03+.07*cos(elapsed*2.0)))
			_turn_global("chest", _right, slow*.08)
		"collar":
			_palm30("l",_p(shoulders,-.24,-.10,.42),_up); _palm30("r",_p(shoulders,.24,-.10+.015*pulse,.42),_up)
			_turn_global("head", _up, slow*.10)
		"wipe_forehead":
			_arm("r", head + (_right*(.12+.15*slow) + _up*.12 + _forward*.15)*_reach)
			_turn_global("head", _right, .08)
		"scratch_head":
			_arm("r", head + (_right*.24 + _up*(.22+.025*pulse))*_reach)
			_turn_global("head", _forward, -.14)
		"window":
			_arm("l", _p(shoulders,-.28,-.50,.06)); _arm("r", head+(_forward*.12-_up*.28)*_reach)
			_turn_global("chest", _right, .10); _turn_global("head", _up, slow*.15)
		"look_far":
			_arm("l", head+(-_right*.13+_up*.14+_forward*.24)*_reach)
			_turn_global("head", _up, slow*.20); _turn_global("head", _right, -.08)
		"newspaper":
			_arm("l", _p(shoulders,-.36,-.28,.56)); _arm("r", _p(shoulders,.36,-.28,.56))
			_turn_global("head", _right, .17); _turn_global("head", _up, slow*.08)
		"camera":
			_arm("l", head+(-_right*.15-_up*.12+_forward*.30)*_reach)
			_arm("r", head+(_right*.15-_up*.12+_forward*(.30+.008*pulse))*_reach)
			_turn_global("head", _right, -.03)
		"pocket":
			var hips30: Vector3 = (_point("thigh_l")+_point("thigh_r"))*.5
			_palm30("r",_p(hips30,.35,.26+.012*pulse,.36),-_up)
			_turn_global("head",_right,.26); _turn_global("head",_up,.17)
		"police_phone30":
			var ear30: Vector3 = head+(-_right*.27+_up*.04+_forward*.07)*_reach
			_palm30("l",ear30-_up*_reach*.09,_up)
			_palm30("r",_p(shoulders,-.08,-.25,.38),-_right*.7+_up*.3)
			_turn_global("head",_forward,-.06); _turn_global("chest",_up,slow*.025)
		"phone":
			var phone30: Vector3 = _p(shoulders,-.24,-.32,.72)
			_palm30("l",phone30-_up*_reach*.10-_right*_reach*.06,_up)
			_palm30("r",phone30+_right*_reach*.16+_up*_reach*.03-_forward*_reach*(.07+.04*pulse),-_right*.8+_forward*.2)
			_turn_global("head",_right,.28); _turn_global("head",_up,-.10)
	for index: int in poses.size():
		var base: Transform3D = poses[index]; var target: Transform3D = _working[index]
		var rotation: Quaternion = base.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), weight)
		poses[index] = Transform3D(Basis(rotation.normalized())*Basis.from_scale(base.basis.get_scale()),base.origin.lerp(target.origin,weight))
	if kind == "bench": _bench_blend_contacts30(poses,weight)
	value["pose_weight"] = weight
	return selected
