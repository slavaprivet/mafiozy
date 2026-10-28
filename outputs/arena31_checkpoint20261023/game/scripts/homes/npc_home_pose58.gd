extends "res://scripts/hospital/npc_treatment_pose28.gd"
## Pure supported-bed pose. The resident host remains the only skeleton writer.
const META := "npc_home_pose58"
var _home_rig: WeakRef

func bind(rig: Skeleton3D, canonical_rest: Array[Transform3D]) -> bool:
	if not super.bind(rig,canonical_rest): return false
	if not _indices.has("thigh_l") or not _indices.has("thigh_r"): return false
	_home_rig=weakref(rig)
	return true

static func sample(body: CharacterBody3D, delta: float, physical: Dictionary) -> Dictionary:
	if not is_instance_valid(body) or not body.is_inside_tree() or not body.is_on_floor() or delta<=0.0: return {}
	if not physical.get("horizontal") is Vector3 or Vector3(physical.horizontal).length()/delta>.05: return {}
	var value: Variant=body.get_meta(META,{})
	if not value is Dictionary or not value.get("active",false): return {}
	if int(value.get("frame",-1))!=Engine.get_physics_frames() or int(value.get("body_id",-1))!=body.get_instance_id() or absf(float(value.get("delta",0.0))-delta)>.00001: return {}
	var owner: Variant=value.get("owner")
	if not owner is WeakRef or not is_instance_valid(owner.get_ref()) or not owner.get_ref().sample_current(value): return {}
	return value

static func committed(rig: Skeleton3D, value: Dictionary) -> void:
	var owner: Variant=value.get("owner")
	if owner is WeakRef and is_instance_valid(owner.get_ref()): owner.get_ref().pose_committed(rig,value)

static func cancel_body(body: CharacterBody3D, reason: String="life_ended") -> void:
	if not is_instance_valid(body): return
	var value: Variant=body.get_meta(META,{})
	if not value is Dictionary: return
	var owner: Variant=value.get("owner")
	if owner is WeakRef and is_instance_valid(owner.get_ref()): owner.get_ref().cancel(reason)

func compose(selected: Dictionary, value: Dictionary) -> Dictionary:
	last_weight=0.0;value["pose_weight"]=0.0
	if not _ready or not selected.get("valid",false) or not selected.get("poses") is Array: return selected
	var rig: Skeleton3D=_home_rig.get_ref() as Skeleton3D if _home_rig!=null else null
	if not is_instance_valid(rig) or not value.get("bed_surface") is Vector3 or not value.get("bed_face") is Vector3: return selected
	var weight: float=clampf(float(value.get("weight",0.0)),0.0,1.0)
	if weight<=.00001: return selected
	var poses: Array[Transform3D]=selected.poses
	if poses.size()!=_parents.size(): return selected
	_working=poses.duplicate();_compose_globals()
	# Relax the hands beside the hips before rotating the complete skeleton.
	var hips: Vector3=(_point("thigh_l")+_point("thigh_r"))*.5
	_arm("l",hips-_right*_reach*.30-_up*_reach*.04)
	_arm("r",hips+_right*_reach*.30-_up*_reach*.04)
	var local_head: Vector3=(rig.global_basis.inverse()*Vector3(value.bed_face)).normalized()
	var local_front: Vector3=(rig.global_basis.inverse()*Vector3.UP).normalized()
	var local_right: Vector3=local_head.cross(local_front).normalized()
	if local_right.length_squared()<.9 or absf(local_head.dot(local_front))>.01: return selected
	local_front=local_right.cross(local_head).normalized()
	var rotation: Basis=Basis(local_right,local_head,local_front)*Basis(_right,_up,_forward).inverse()
	var target_hips: Vector3=rig.to_local(Vector3(value.bed_surface)+Vector3.UP*.12)
	var transform: Transform3D=Transform3D(rotation,target_hips-rotation*hips)
	for index: int in _working.size():
		if _parents[index]<0: _working[index]=transform*_working[index]
		if not _working[index].is_finite(): return selected
	var composed: Array[Transform3D]=[]
	for index: int in poses.size(): composed.append(poses[index].interpolate_with(_working[index],weight))
	selected["poses"]=composed
	value["pose_weight"]=weight;last_weight=weight
	return selected
