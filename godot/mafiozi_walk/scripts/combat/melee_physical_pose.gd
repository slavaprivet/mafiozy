extends RefCounted
## Fixed-length presentation retarget, deliberately distinct from exact Walk IK.
## No admission, contact, motion, impulse, physics or skeleton writes are owned.
const BONE_COUNT := 28
const ENTRY_END := .14
const EXIT_START := .72
const MAX_LOCAL_SPEED := 20.0
const ENDPOINT_SPEED := 8.0
var _rig: WeakRef
var _version := 0
var _parents := PackedInt32Array()
var _rest: Array[Transform3D] = []
var _scales: Array[Vector3] = []
var _rest_global: Array[Transform3D] = []
var _chains: Array[Dictionary] = []
var _ready := false
var _lifted: Array[Quaternion] = []
var _lift_kind := ""
var _lift_epoch := -1
var _last_progress := -1.0
var _last_output: Array[Transform3D] = []
var _entry: Array[Transform3D] = []
var _rate_epoch := -1
var _rate_kind := ""
var _rate_active := false
var _rate_age := -1.0
var _settling := false

func configure(skeleton: Skeleton3D, canonical_rest: Array[Transform3D]) -> bool:
	if _ready or not Thread.is_main_thread() or not is_instance_valid(skeleton) or not skeleton.is_inside_tree() or canonical_rest.size() != BONE_COUNT or skeleton.get_bone_count() != BONE_COUNT: return false
	var node: Node = skeleton
	while node != null:
		if node.is_queued_for_deletion(): return false
		node = node.get_parent()
	var parents := PackedInt32Array()
	var scales: Array[Vector3] = []
	var global_rest: Array[Transform3D] = []
	for i in BONE_COUNT:
		var frame := canonical_rest[i]
		if not _rotation_frame(frame) or not frame.is_equal_approx(skeleton.get_bone_rest(i)): return false
		var scale := frame.basis.get_scale()
		# The canonical rig has uniform local scale. Nonuniform rest would create
		# inherited shear even after replacing the authored IK scale.
		if absf(scale.x-scale.y) > .00001 or absf(scale.x-scale.z) > .00001: return false
		var parent := skeleton.get_bone_parent(i)
		if parent >= i or parent < -1: return false
		parents.append(parent); scales.append(scale)
		global_rest.append(frame if parent < 0 else global_rest[parent]*frame)
	var chains: Array[Dictionary] = []
	for side in ["l","r"]:
		for prefix in [["upperarm_","forearm_","hand_"],["thigh_","shin_","foot_"]]:
			var a := skeleton.find_bone(prefix[0]+side); var b := skeleton.find_bone(prefix[1]+side); var c := skeleton.find_bone(prefix[2]+side)
			if a < 0 or b < 0 or c < 0 or parents[b] != a or parents[c] != b: return false
			var upper := global_rest[b].origin-global_rest[a].origin; var lower := global_rest[c].origin-global_rest[b].origin
			if minf(upper.length(),lower.length()) < .001: return false
			var direction := (global_rest[c].origin-global_rest[a].origin).normalized()
			var pole := global_rest[a].basis.z.normalized()
			pole = (pole-direction*pole.dot(direction)).normalized()
			if pole.length_squared() < .5: return false
			chains.append({"a":a,"b":b,"c":c,"leg":prefix[0]=="thigh_","l1":upper.length(),"l2":lower.length(),"upper":upper.normalized(),"lower":lower.normalized(),"direction":direction,"pole":pole})
	_rest = canonical_rest.duplicate(); _parents = parents; _scales = scales
	_rest_global = global_rest; _chains = chains
	_rig = weakref(skeleton); _version = skeleton.get_version(); _ready = true
	return true

static func _frame(value: Variant) -> bool:
	return value is Transform3D and value.is_finite() and is_finite(value.basis.determinant()) and value.basis.determinant() > .0000001

static func _rotation_frame(value: Variant) -> bool:
	if not _frame(value): return false
	var x: Vector3 = value.basis.x.normalized(); var y: Vector3 = value.basis.y.normalized(); var z: Vector3 = value.basis.z.normalized()
	return absf(x.dot(y)) <= .0001 and absf(x.dot(z)) <= .0001 and absf(y.dot(z)) <= .0001

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _smooth5(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t*t*t*(t*(t*6.0-15.0)+10.0)

func _live() -> bool:
	if not _ready or not Thread.is_main_thread(): return false
	var skeleton: Variant = _rig.get_ref()
	if not is_instance_valid(skeleton) or not skeleton.is_inside_tree() or skeleton.get_version() != _version: return false
	var node: Node = skeleton
	while node != null:
		if node.is_queued_for_deletion(): return false
		node = node.get_parent()
	return true

static func _fail(reason: String) -> Dictionary:
	return {"valid":false,"error":reason}

func reset() -> void:
	_lifted.clear(); _lift_kind = ""; _last_progress = -1.0
	_last_output.clear(); _entry.clear(); _rate_epoch = -1; _rate_kind = ""; _rate_active = false; _rate_age = -1.0
	_settling = false

static func _toward(a: Quaternion, b: Quaternion, angle: float) -> Quaternion:
	var distance := a.angle_to(b)
	return b if distance <= angle or distance < .000001 else a.slerp(b,angle/distance).normalized()

func _limit(target: Array, base: Array, delta: float, epoch: int, active: bool, kind: String, age: float, duration: float) -> Array[Transform3D]:
	var fresh := _last_output.size()!=BONE_COUNT or _rate_epoch!=epoch
	if fresh: _last_output.assign(base)
	if active and (fresh or not _rate_active or _rate_kind!=kind or age<_rate_age): _entry = _last_output.duplicate()
	var result: Array[Transform3D] = []
	for i in BONE_COUNT:
		var wanted: Quaternion = target[i].basis.get_rotation_quaternion()
		var previous: Quaternion = _last_output[i].basis.get_rotation_quaternion()
		var q := _toward(previous,wanted,MAX_LOCAL_SPEED*delta)
		if active:
			# Keep a shrinking reachable cone around ordinary gait. The remaining
			# angular distance can always finish without an end-of-action snap.
			var ordinary: Quaternion = base[i].basis.get_rotation_quaternion()
			q = _toward(ordinary,q,ENDPOINT_SPEED*maxf(0.0,duration-age))
			if age <= .0000001:
				q = (_entry[i] as Transform3D).basis.get_rotation_quaternion()
		var frame := Transform3D(Basis(q)*Basis.from_scale(_scales[i]),_rest[i].origin)
		if active and age <= .0000001: frame = _entry[i]
		var base_q: Quaternion = base[i].basis.get_rotation_quaternion()
		if not active and (q.is_equal_approx(base_q) or q.is_equal_approx(-base_q)): frame = base[i]
		result.append(frame)
	_last_output = result.duplicate(); _rate_epoch = epoch; _rate_active = active; _rate_kind = kind; _rate_age = age
	return result

func _fixed_world(rotations: Array[Quaternion]) -> Array[Transform3D]:
	var frames: Array[Transform3D] = []
	for i in BONE_COUNT:
		var parent := _parents[i]
		var origin: Vector3 = _rest[i].origin if parent < 0 else frames[parent]*_rest[i].origin
		frames.append(Transform3D(Basis(rotations[i])*Basis.from_scale(_rest_global[i].basis.get_scale()),origin))
	return frames

func _solve_fixed_chains(source_global: Array[Transform3D], rotations: Array[Quaternion]) -> void:
	var fixed := _fixed_world(rotations)
	for chain in _chains:
		var a: int = chain.a; var b: int = chain.b; var c: int = chain.c
		var anchor := fixed[a].origin
		var delta := source_global[c].origin-anchor
		var direction := delta.normalized()
		if direction.length_squared() < .5: direction = chain.direction
		var reach: float = chain.l1+chain.l2
		var softness := reach*.04
		var distance := delta.length()
		# Smooth approach to extension, avoiding the sqrt singularity at a locked
		# elbow/knee and the original source pole's sign flip near straight legs.
		if distance > reach-softness: distance = reach-softness*exp(-(distance-(reach-softness))/softness)
		distance = clampf(distance,absf(chain.l1-chain.l2)+reach*.001,reach*(1.0-.001))
		var parent := _parents[a]
		var transport: Quaternion = rotations[parent]*_rest_global[parent].basis.get_rotation_quaternion().inverse()
		var rest_direction: Vector3 = transport*(chain.direction as Vector3)
		var pole: Vector3 = Quaternion(rest_direction,direction)*(transport*(chain.pole as Vector3))
		pole = (pole-direction*pole.dot(direction)).normalized()
		var along: float = (chain.l1*chain.l1-chain.l2*chain.l2+distance*distance)/(2.0*distance)
		var elbow := anchor+direction*along+pole*sqrt(maxf(0.0,chain.l1*chain.l1-along*along))
		var wrist := anchor+direction*distance
		# Both segments share one transported hinge axis. Independent shortest
		# from-to rotations can flip their twist at an antipodal straight limb.
		var hinge := direction.cross(pole).normalized()
		var upper_y := (elbow-anchor).normalized(); var lower_y := (wrist-elbow).normalized()
		rotations[a] = Basis(hinge,upper_y,hinge.cross(upper_y)).orthonormalized().get_rotation_quaternion()
		rotations[b] = Basis(hinge,lower_y,hinge.cross(lower_y)).orthonormalized().get_rotation_quaternion()

func sample(source: Dictionary, ordinary_base: Dictionary, epoch: int = 0, delta: float = 1.0/60.0) -> Dictionary:
	if not _live(): return _fail("binding")
	if not is_finite(delta) or delta < 0 or delta > .1 or epoch < 0: return _fail("time_or_epoch")
	# Original source no-op remains an exact no-op, including caller metadata.
	if not source.has("melee"):
		_lifted.clear(); _lift_kind = ""; _last_progress = -1.0
		if not source.get("valid",false) or not source.get("poses") is Array or source.poses.size()!=BONE_COUNT: return _fail("base")
		for i in BONE_COUNT:
			if not _rotation_frame(source.poses[i]) or source.poses[i].origin.distance_to(_rest[i].origin)>.00001 or source.poses[i].basis.get_scale().distance_to(_scales[i])>.00001: return _fail("ordinary_rig")
		if source.get("authority_epoch",epoch) != epoch: return _fail("epoch")
		if not _settling or _rate_epoch != epoch:
			reset()
			return source
		var settled := _limit(source.poses,source.poses,delta,epoch,false,"idle",0,1)
		if settled == source.poses:
			reset()
			return source
		var idle := source.duplicate(); idle.poses = settled; idle.authority_epoch = epoch
		return idle
	if source.has("melee_physical"): return _fail("already_retargeted")
	if epoch < 0 or not source.get("valid") is bool or not source.valid or not ordinary_base.get("valid") is bool or not ordinary_base.valid: return _fail("base")
	if source.get("authority_epoch",epoch) != epoch or ordinary_base.get("authority_epoch",epoch) != epoch: return _fail("epoch")
	if not source.get("poses") is Array or source.poses.size() != BONE_COUNT or not ordinary_base.get("poses") is Array or ordinary_base.poses.size() != BONE_COUNT: return _fail("poses")
	var metadata: Variant = source.melee
	if not metadata is Dictionary or not metadata.get("active") is bool or not _number(metadata.get("age")) or not _number(metadata.get("duration")) or metadata.duration <= 0: return _fail("melee")
	for selected: Dictionary in [source,ordinary_base]:
		if not selected.get("visual_offset") is Vector3 or not selected.visual_offset.is_finite(): return _fail("visual")
		var rotation: Variant = selected.get("visual_rotation",Quaternion.IDENTITY)
		if not rotation is Quaternion or not rotation.is_finite() or absf(rotation.length_squared()-1.0) > .0001: return _fail("visual")
	var source_global: Array[Transform3D] = []
	var rotations: Array[Quaternion] = []
	var base_global: Array[Transform3D] = []
	for i in BONE_COUNT:
		var src: Variant = source.poses[i]; var base: Variant = ordinary_base.poses[i]
		if not _frame(src) or not _rotation_frame(base): return _fail("bone")
		if base.origin.distance_to(_rest[i].origin) > .00001 or base.basis.get_scale().distance_to(_scales[i]) > .00001: return _fail("ordinary_rig")
		var parent := _parents[i]
		var global: Transform3D = src if parent < 0 else source_global[parent]*src
		# Source IK's inverse-parent shear cancels in its complete global frame.
		# Reject unsupported globally sheared input instead of guessing its axes.
		if not _rotation_frame(global): return _fail("source_global")
		source_global.append(global); rotations.append(global.basis.get_rotation_quaternion())
		base_global.append(base if parent < 0 else base_global[parent]*base)
	_solve_fixed_chains(source_global,rotations)
	var weight := 1.0
	var progress := clampf(float(metadata.age)/float(metadata.duration),0.0,1.0)
	if metadata.active:
		weight = _smooth5(progress/ENTRY_END)*(1.0-_smooth5((progress-EXIT_START)/(1.0-EXIT_START)))
	var poses: Array[Transform3D] = []
	var blended_global: Array[Quaternion] = []
	var kind := str(metadata.get("type","none"))
	var fresh := _lifted.size() != BONE_COUNT or _lift_kind != kind or _lift_epoch != epoch or progress < _last_progress
	var lifted: Array[Quaternion] = []
	for i in BONE_COUNT:
		var base_q := base_global[i].basis.get_rotation_quaternion()
		if base_q.dot(_rest_global[i].basis.get_rotation_quaternion()) < 0: base_q = -base_q
		var target := rotations[i].normalized()
		var reference: Quaternion = base_q if fresh else _lifted[i]
		if target.dot(reference) < 0: target = -target
		lifted.append(target)
		# Preserve the continuous lifted quaternion branch during endpoint fades.
		# A shortest-arc choice each frame flips at 180 degrees during gait.
		blended_global.append(base_q.slerpni(target,weight).normalized())
	for i in BONE_COUNT:
		if weight == 0.0:
			poses.append(ordinary_base.poses[i]); continue
		var parent := _parents[i]
		var rotation: Quaternion = blended_global[i] if parent < 0 else (blended_global[parent].inverse()*blended_global[i]).normalized()
		poses.append(Transform3D(Basis(rotation)*Basis.from_scale(_scales[i]),_rest[i].origin))
	var result := source.duplicate()
	result.poses = _limit(poses,ordinary_base.poses,delta,epoch,metadata.active,kind,float(metadata.age),float(metadata.duration)); result.melee = metadata.duplicate(true); result.authority_epoch = epoch
	result.melee_physical = {"version":1,"fixed_limb_lengths":true,"blend_weight":weight}
	_settling = result.poses != ordinary_base.poses
	_lifted = lifted; _lift_kind = kind; _lift_epoch = epoch; _last_progress = progress
	return result
