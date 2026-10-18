extends RefCounted
## Local NPC retaliation presentation. Never applies HP or writes a transform.
## The host owns motion and the only skeleton write; a separate exact-contact
## bridge may consume one active swing after its independently verified hit.
const WINDUP := .24
const ACTIVE := .20
const RECOVERY := .24
const COOLDOWN := .65
const ENGAGEMENT_SECONDS := 5.0
const MAX_START_DISTANCE := 1.45
const MAX_BONES := 64
const MAX_DEFENSIVE_STEP_M := .22
const DEFENSIVE_STEP_SPEED := 1.1
const DEFENSIVE_STANDOFF_M := .72
var phase := "IDLE"
var sequence := 0
var age := 0.0
var _remaining := 0.0
var _consumed := false
var _token := {}
var _rig: WeakRef
var _rig_version := -1
var _target: WeakRef
var _target_rig: WeakRef
var _target_version := -1
var _target_chest := -1
var _target_neck := -1
var _step_remaining := 0.0
var _step_distance := 0.0
var _pose_telemetry: Dictionary = {}
var _peak_telemetry: Dictionary = {}
var _authority: Callable
var _events: Callable
var _last_revision := -1
var _parents := PackedInt32Array()
var _rest: Array[Transform3D] = []
var _world: Array[Transform3D] = []
var _arms: Array[Dictionary] = []
var _ready := false
var _disposed := false
var _held := false
var _span_frame := -1
var _sample_from := 0.0
var _sample_to := 0.0
var _clip_from := 0.0
var _clip_to := 0.0
var last_cancel := ""

func configure(token: Dictionary, rest: Array[Transform3D], authority_current: Callable, confirmed_event: Callable) -> bool:
	if _ready or _disposed or not _parents.is_empty() or not authority_current.is_valid() or not confirmed_event.is_valid(): return false
	var rig: Variant = token.get("rig")
	if token.get("ok") != true or not rig is Skeleton3D or not is_instance_valid(rig) or rest.size() != rig.get_bone_count() or rest.size() > MAX_BONES: return false
	if not token.get("source_id") is String or int(token.get("life_generation", 0)) < 1: return false
	for bone: int in rest.size():
		if not rest[bone].is_finite(): return false
		var parent: int = rig.get_bone_parent(bone)
		if parent >= bone: return false
		_parents.append(parent)
		_world.append(rest[bone] if parent < 0 else _world[parent] * rest[bone])
	for side: String in ["l", "r"]:
		var a: int = rig.find_bone("upperarm_" + side)
		var b: int = rig.find_bone("forearm_" + side)
		var c: int = rig.find_bone("hand_" + side)
		if mini(a, mini(b, c)) < 0 or _parents[b] != a or _parents[c] != b: return false
		var upper: Vector3 = _world[b].origin - _world[a].origin
		var lower: Vector3 = _world[c].origin - _world[b].origin
		if minf(upper.length(), lower.length()) <= .001: return false
		_arms.append({"a":a,"b":b,"c":c,"l1":upper.length(),"l2":lower.length(),"sign":-1.0 if side == "l" else 1.0})
	_token = token.duplicate(); _rest = rest.duplicate(); _rig = weakref(rig); _rig_version = rig.get_version()
	_authority = authority_current; _events = confirmed_event; _ready = true
	return true

## Event provider belongs to the accepted HP owner. No caller-supplied damage
## number or untrusted contact dictionary can start retaliation by itself.
func notify_confirmed_player_damage(event_id: String, target: Node3D) -> bool:
	if not _ready or _disposed or not is_instance_valid(target) or event_id.is_empty(): return false
	var result: Variant = _events.call(event_id)
	if not result is Dictionary or result.get("accepted") != true or result.get("event_id") != event_id or result.get("source_id") != _token.source_id or result.get("life_generation") != _token.life_generation: return false
	if result.get("attacker_kind") != "player" or result.get("attacker_instance_id") != target.get_instance_id(): return false
	if not result.get("hp_before") is float and not result.get("hp_before") is int: return false
	if not result.get("hp_after") is float and not result.get("hp_after") is int: return false
	if not is_finite(float(result.hp_before)) or not is_finite(float(result.hp_after)) or result.hp_after <= 0 or result.hp_after >= result.hp_before: return false
	if not result.get("revision") is int or result.revision <= _last_revision: return false
	_target = weakref(target)
	var target_rigs: Array[Node] = target.find_children("*","Skeleton3D",true,false)
	if target_rigs.size() != 1: _target = null; return false
	var target_rig: Skeleton3D = target_rigs[0] as Skeleton3D
	_target_chest = target_rig.find_bone("chest"); _target_neck = target_rig.find_bone("neck")
	if mini(_target_chest,_target_neck) < 0: _target = null; return false
	_target_rig = weakref(target_rig); _target_version = target_rig.get_version()
	if not _current(): _target = null; return false
	_last_revision = result.revision
	_span_frame = -1
	_remaining = ENGAGEMENT_SECONDS
	# One bounded step for this defensive engagement, not repeated chasing.
	_step_remaining = MAX_DEFENSIVE_STEP_M; _step_distance = 0.0
	_pose_telemetry.clear(); _peak_telemetry.clear()
	# A new real hit interrupts an attack, preventing contact from a staggered NPC.
	phase = "WINDUP"; age = 0.0; _consumed = false; sequence += 1
	return true

func _current() -> bool:
	if not _ready or _disposed or _rig == null or _target == null or not _authority.is_valid(): return false
	var rig: Skeleton3D = _rig.get_ref()
	var target: Node3D = _target.get_ref()
	if not is_instance_valid(rig) or rig.get_version() != _rig_version or rig.is_queued_for_deletion() or not rig.is_inside_tree() or not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree(): return false
	var target_rig: Skeleton3D = _target_rig.get_ref() if _target_rig != null else null
	if not is_instance_valid(target_rig) or target_rig.is_queued_for_deletion() or target_rig.get_version() != _target_version or not target.is_ancestor_of(target_rig): return false
	# Must include both lives, local HP lease and on-foot/grounded state.
	# Ordinary hit-stagger is suspended by the existing host pause callback.
	var answer: Variant = _authority.call(_token, target)
	return answer is bool and answer and not _disposed and _target != null and _target.get_ref() == target and is_instance_valid(target) and not target.is_queued_for_deletion() and is_instance_valid(rig) and rig.get_version() == _rig_version

func engaged() -> bool: return phase != "IDLE" and not _disposed

func step(delta: float) -> void:
	_span_frame = -1
	if not engaged(): return
	_held = false
	if not is_finite(delta) or delta <= 0.0 or delta > .05 or not _current(): cancel("lifetime_or_state"); return
	_remaining -= delta
	if _remaining <= 0.0: cancel("engagement_expired"); return
	var body: Node3D = _token.body
	var target: Node3D = _target.get_ref()
	if not is_instance_valid(body) or body.global_position.distance_to(target.global_position) > MAX_START_DISTANCE:
		cancel("target_out_of_reach"); return
	var previous_age := age
	age += delta
	if phase == "ACTIVE" and age > .015 and previous_age < .145:
		_sample_from = previous_age; _sample_to = age
		_clip_from = clampf((.015 - previous_age) / delta,0.0,1.0)
		_clip_to = clampf((.145 - previous_age) / delta,0.0,1.0)
		if _clip_to > _clip_from: _span_frame = Engine.get_physics_frames()
	match phase:
		"WINDUP":
			if age >= WINDUP: phase = "ACTIVE"; age = 0.0
		"ACTIVE":
			if age >= ACTIVE: phase = "RECOVERY"; age = 0.0
		"RECOVERY":
			if age >= RECOVERY: phase = "COOLDOWN"; age = 0.0
		"COOLDOWN":
			if age >= COOLDOWN: phase = "WINDUP"; age = 0.0; sequence += 1; _consumed = false

func target_position() -> Vector3:
	var target: Node3D = _target.get_ref() if _target != null else null
	return target.global_position if is_instance_valid(target) else Vector3.INF

func defensive_velocity(delta: float) -> Vector3:
	# Pure proposal. The existing residents host applies it with its native capsule.
	if phase != "WINDUP" or _held or not _current() or delta <= 0.0 or delta > .05 or _step_remaining <= 0.0: return Vector3.ZERO
	var offset: Vector3 = target_position() - _token.body.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= DEFENSIVE_STANDOFF_M: return Vector3.ZERO
	var step := minf(_step_remaining,minf(distance-DEFENSIVE_STANDOFF_M,DEFENSIVE_STEP_SPEED*delta))
	return offset.normalized()*(step/delta)

func record_defensive_motion(before: Vector3,after: Vector3) -> void:
	if not before.is_finite() or not after.is_finite(): cancel("invalid_defensive_motion"); return
	var displacement := Vector2(after.x-before.x,after.z-before.z).length()
	_step_distance += displacement
	_step_remaining = maxf(0.0,_step_remaining-displacement)

func _target_anchor() -> Vector3:
	var rig: Skeleton3D = _target_rig.get_ref()
	var chest: Vector3 = rig.get_bone_global_pose(_target_chest).origin
	var neck: Vector3 = rig.get_bone_global_pose(_target_neck).origin
	return rig.global_transform * chest.lerp(neck,.60)

func snapshot() -> Dictionary:
	return {"phase":phase,"sequence":sequence,"age":age,"remaining":_remaining,"held":_held,"consumed":_consumed,"last_cancel":last_cancel,"defensive_step_m":_step_distance,"step_remaining_m":_step_remaining,"pose":_pose_telemetry.duplicate(),"peak":_peak_telemetry.duplicate()}

func contact_window() -> bool:
	# Covers only this physics step's clipped interval, including its final
	# boundary crossing. The bridge MUST clip endpoint sweeps by these factors.
	return _span_frame == Engine.get_physics_frames() and _clip_to > _clip_from and not _held and not _consumed and _current()

func hold_for_hit(delta: float) -> void:
	_span_frame = -1
	if not engaged(): return
	if not is_finite(delta) or delta <= 0.0 or delta > .05 or not _current(): cancel("invalid_hit_hold"); return
	_remaining -= delta
	if _remaining <= 0.0: cancel("hit_hold_expired"); return
	if not _held:
		sequence += 1
		phase = "WINDUP"; age = 0.0; _consumed = false
	_held = true

func capability() -> Dictionary:
	if not contact_window(): return {}
	return {"attacker":_token.duplicate(),"rig":_rig.get_ref(),"target":_target.get_ref(),"sequence":sequence,"phase":phase,"age":age,"contact_kind":"fist","side":"r" if sequence % 2 == 1 else "l","active_window":true,"source_authority":false,"physics_frame":_span_frame,"sample_age_from":_sample_from,"sample_age_to":_sample_to,"window_start":.015,"window_end":.145,"sweep_alpha_from":_clip_from,"sweep_alpha_to":_clip_to}

func confirm_contact(expected_sequence: int) -> bool:
	if expected_sequence != sequence or not contact_window(): return false
	_consumed = true
	return true

func cancel(reason: String = "cancel") -> void:
	phase = "IDLE"; age = 0.0; _remaining = 0.0; _consumed = true; _target = null; _span_frame = -1; last_cancel = reason
	_step_remaining = 0.0

func dispose() -> void:
	cancel("disposed"); _disposed = true; _authority = Callable(); _events = Callable(); _token.clear(); _rig = null
	_target_rig = null

## Fixed-length local IK sampled into the existing gait array, never into rig.
func compose_pose(base: Dictionary) -> Dictionary:
	if not engaged() or _held or not base.get("valid",false) or not _current(): return base
	var poses: Array[Transform3D] = base.poses
	if poses.size() != _rest.size(): cancel("pose_topology"); return base
	var weight := clampf(age / WINDUP, 0.0, 1.0) if phase == "WINDUP" else 1.0
	if phase == "RECOVERY": weight = 1.0 - clampf(age / RECOVERY, 0.0, 1.0)
	if phase == "COOLDOWN": weight = 0.0
	if weight <= 0.0: return base
	_fk(poses)
	var rig: Skeleton3D = _rig.get_ref()
	var target_world := _target_anchor()
	var target_local: Vector3 = rig.global_transform.affine_inverse()*target_world
	for arm: Dictionary in _arms:
		var striking: bool = (arm.sign > 0.0) == (sequence % 2 == 1)
		var pulse := sin(PI * clampf(age / ACTIVE, 0.0, 1.0)) if phase == "ACTIVE" and striking else 0.0
		var shoulder: Vector3 = _world[arm.a].origin
		var reach: float = arm.l1 + arm.l2
		var distance := reach * lerpf(.46, .97, pulse)
		var direction: Vector3 = (target_local-shoulder).normalized()
		if direction.length_squared() < .5: cancel("invalid_aim"); return base
		var goal: Vector3 = shoulder + direction * distance
		var along := clampf((arm.l1 * arm.l1 - arm.l2 * arm.l2 + distance * distance) / (2.0 * distance), 0.0, float(arm.l1))
		var pole := Vector3(float(arm.sign), -.8, 0.0)
		pole = (pole - direction * pole.dot(direction)).normalized()
		var elbow: Vector3 = shoulder + direction * along + pole * sqrt(maxf(0.0, arm.l1 * arm.l1 - along * along))
		_aim(poses, arm.a, arm.b, elbow, weight)
		_aim(poses, arm.b, arm.c, goal, weight)
		if striking:
			var wrist_world: Vector3 = rig.global_transform*_world[arm.c].origin
			var goal_world: Vector3 = rig.global_transform*goal
			_pose_telemetry={"sequence":sequence,"physics_frame":Engine.get_physics_frames(),"phase":phase,"age":age,"pulse":pulse,"target_world":target_world,"wrist_world":wrist_world,"goal_world":goal_world,"wrist_target_gap_m":wrist_world.distance_to(target_world),"ik_goal_error_m":wrist_world.distance_to(goal_world),"body_distance_m":_token.body.global_position.distance_to(target_position()),"reach_m":(rig.global_transform.basis*direction*reach).length()}
			if phase == "ACTIVE" and (_peak_telemetry.get("sequence",-1) != sequence or pulse > float(_peak_telemetry.get("pulse",-1.0))): _peak_telemetry=_pose_telemetry.duplicate()
	return base

func _fk(poses: Array[Transform3D]) -> void:
	for bone: int in poses.size(): _world[bone] = poses[bone] if _parents[bone] < 0 else _world[_parents[bone]] * poses[bone]

func _aim(poses: Array[Transform3D], bone: int, child: int, target: Vector3, weight: float) -> void:
	# Solve in the actual parent affine frame, rather than stripping its scale
	# from a world quaternion. The local TRS writer retains this rotation exactly.
	var parent: Transform3D = _world[_parents[bone]] if _parents[bone] >= 0 else Transform3D.IDENTITY
	var from: Vector3 = (poses[bone].basis*poses[child].origin).normalized()
	var to: Vector3 = (parent.affine_inverse()*target-poses[bone].origin).normalized()
	if minf(from.length_squared(),to.length_squared()) < .5: return
	var turn: Quaternion = Quaternion.IDENTITY.slerp(Quaternion(from,to),weight)
	poses[bone] = Transform3D(Basis(turn)*poses[bone].basis,poses[bone].origin)
	_fk(poses)
