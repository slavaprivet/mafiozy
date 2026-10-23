class_name NativeLadderLandingSettleProbe
extends RefCounted
## Additive post-route physical grounding proposal. Never modifies source ladder,
## actor root, collision filters or support. All five support rays stay enabled.

const PROVIDER := "GODOT_LADDER_LANDING_SETTLE_V1"
const Probe = preload("res://scripts/traversal/ladder_probe.gd")
const MAX_DROP_M := .28 # Existing native ladder support-ray downward envelope.
const RAY_UP_M := .24
const HEIGHT_SPREAD_M := .08 # Existing support-height tolerance; not enlarged.
const OFFSETS: Array[Vector3] = [Vector3.ZERO,Vector3(.22,0,0),Vector3(-.22,0,0),Vector3(0,0,.22),Vector3(0,0,-.22)]

var _space: PhysicsDirectSpaceState3D
var _actor_rid := RID()
var _mask := 1
var _probe := Probe.new()
var _ray := PhysicsRayQueryParameters3D.new()

func configure(space: PhysicsDirectSpaceState3D, collision_mask: int = 1, actor_rid: RID = RID()) -> void:
	_space = space
	_mask = collision_mask
	_actor_rid = actor_rid
	_probe.configure(space,collision_mask,actor_rid)
	_ray.collision_mask = collision_mask
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	_ray.exclude = [actor_rid] if actor_rid.is_valid() else []

func dispose() -> void:
	configure(null,0,RID())

func inspect(authored_feet: Vector3, max_drop_m: float = MAX_DROP_M) -> Dictionary:
	if _space == null or _mask <= 0:
		return _reject("space_unavailable")
	if not authored_feet.is_finite() or not is_finite(max_drop_m) or max_drop_m < 0.0 or max_drop_m > MAX_DROP_M:
		return _reject("invalid_request")
	var supports: Array[Dictionary] = []
	var low := INF
	var high := -INF
	for offset: Vector3 in OFFSETS:
		_ray.from = authored_feet+offset+Vector3.UP*RAY_UP_M
		_ray.to = authored_feet+offset-Vector3.UP*(max_drop_m+.001)
		var hit := _space.intersect_ray(_ray)
		if hit.is_empty():
			return _reject("support_missing")
		var body: Variant = hit.collider
		if body is AnimatableBody3D or not body is StaticBody3D or not is_instance_valid(body) or body.is_queued_for_deletion():
			return _reject("support_not_static")
		if body.constant_linear_velocity != Vector3.ZERO or body.constant_angular_velocity != Vector3.ZERO:
			return _reject("support_not_static")
		var point: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		if not point.is_finite() or not normal.is_finite() or normal.y < Probe.MIN_WALKABLE_UP_DOT:
			return _reject("support_not_walkable")
		if point.y > authored_feet.y+.00001 or authored_feet.y-point.y > max_drop_m+.00001:
			return _reject("support_outside_drop")
		low = minf(low,point.y)
		high = maxf(high,point.y)
		var shape_index := int(hit.get("shape",-1))
		if shape_index < 0:
			return _reject("support_shape_unavailable")
		supports.append({"rid":body.get_rid(),"instance_id":body.get_instance_id(),"transform":body.global_transform,
			"shape_index":shape_index,"shape_rid":PhysicsServer3D.body_get_shape(body.get_rid(),shape_index),
			"shape_transform":PhysicsServer3D.body_get_shape_transform(body.get_rid(),shape_index),
			"position":point,"normal":normal,"source_id":body.get_meta("source_id","")})
	if high-low > HEIGHT_SPREAD_M:
		return _reject("support_height_spread")
	var grounded := Vector3(authored_feet.x,high,authored_feet.z)
	var count := maxi(1,int(ceil(authored_feet.distance_to(grounded)/Probe.SWEEP_STEP_M)))
	var roots: Array[Vector3] = []
	var samples: Array[Dictionary] = []
	for i in range(count+1):
		var feet := authored_feet.lerp(grounded,float(i)/count)
		roots.append(feet)
		samples.append({"root_position":feet})
	# Deliberately no route/body exclusions here: step-off is outside source corridor.
	var clearance := _probe.inspect_sweep_samples(samples,{})
	if not clearance.clear:
		return _reject("settle_blocked")
	if not _probe.landing_supported(grounded):
		return _reject("grounded_support_rejected")
	return {"provider":PROVIDER,"valid":true,"reason":"clear","authored_feet":authored_feet,
		"grounded_feet":grounded,"drop_m":authored_feet.y-grounded.y,"max_drop_m":max_drop_m,
		"ordered_roots":roots,"supports":supports,"collision_mask":_mask,"actor_rid":_actor_rid}

func revalidate(receipt: Dictionary) -> Dictionary:
	if receipt.get("provider") != PROVIDER or not bool(receipt.get("valid",false)) or not receipt.get("authored_feet") is Vector3 or not receipt.get("grounded_feet") is Vector3 or not receipt.get("supports") is Array:
		return _reject("invalid_receipt")
	if receipt.get("collision_mask") != _mask or receipt.get("actor_rid") != _actor_rid:
		return _reject("query_authority_changed")
	var requested_bound: Variant = receipt.get("max_drop_m")
	if not requested_bound is float and not requested_bound is int:
		return _reject("invalid_receipt")
	var fresh := inspect(receipt.authored_feet,float(requested_bound))
	if not fresh.valid:
		return fresh
	if receipt.supports.size() != fresh.supports.size() or receipt.grounded_feet.distance_to(fresh.grounded_feet)>.00001:
		return _reject("support_changed")
	for i in fresh.supports.size():
		var old: Variant = receipt.supports[i]
		var current: Dictionary = fresh.supports[i]
		if not old is Dictionary or old.get("rid") != current.rid or old.get("instance_id") != current.instance_id or old.get("transform") != current.transform or old.get("source_id") != current.source_id:
			return _reject("support_changed")
		if old.get("shape_index") != current.shape_index or old.get("shape_rid") != current.shape_rid or old.get("shape_transform") != current.shape_transform or old.get("position") != current.position or old.get("normal") != current.normal:
			return _reject("support_changed")
	return fresh

func _reject(reason: String) -> Dictionary:
	return {"provider":PROVIDER,"valid":false,"reason":reason,"ordered_roots":[],"supports":[]}
