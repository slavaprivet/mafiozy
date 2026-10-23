class_name NativeLadderSourceRouteProbe
extends RefCounted
## Unified source corridor + native terminal grounding admission. Proposal only.
## Caller owns exact source-index/body mapping, E/Ctrl, motion commits and filters.

const Descriptor = preload("res://scripts/traversal/ladder_descriptor.gd")
const Probe = preload("res://scripts/traversal/ladder_probe.gd")
const Motion = preload("res://scripts/traversal/ladder_motion.gd")
const Policy = preload("res://scripts/traversal/ladder_source_collision_policy.gd")
const Settle = preload("res://scripts/traversal/ladder_landing_settle_probe.gd")
const PROVIDER := "GODOT_SOURCE_LADDER_ROUTE_V1"
var _space: PhysicsDirectSpaceState3D
var _actor_rid := RID()
var _mask := 0
var _probe := Probe.new()
var _settle := Settle.new()
var _lease: Dictionary={}
var _sequence := 0
var _samples: Array[Dictionary]=[]
var _cursor := 0
var _admitted := false

func configure(space: PhysicsDirectSpaceState3D, mask: int, actor_rid: RID) -> void:
	_space=space
	_mask=mask
	_actor_rid=actor_rid
	_lease.clear()
	_samples.clear()
	_cursor=0
	_admitted=false
	_probe.configure(space,mask,actor_rid)
	_settle.configure(space,mask,actor_rid)

func dispose() -> void:
	configure(null,0,RID())

func prepare(feet: Vector3, source_descriptor: Dictionary, end: String, current_source_records: Array) -> Dictionary:
	# One active admission lease. Every new attempt replaces/invalidate old proof,
	# including failures; root must not start a new attempt while traversing.
	_lease.clear()
	_samples.clear()
	_cursor=0
	_admitted=false
	if _space == null or _mask<=0:
		return _reject("space_unavailable")
	var descriptor: Dictionary = Descriptor.normalize(source_descriptor)
	if not descriptor.valid or end not in ["lower","upper"]:
		return _reject("invalid_descriptor")
	# Never admit a blanket source envelope exception in this conditional contract.
	if not descriptor.route_exclude_rids.is_empty():
		return _reject("blanket_exclusions_rejected")
	var candidate := {"descriptor":descriptor,"end":end}
	var validation: Dictionary = _probe.validate_candidate(feet,candidate)
	if not validation.valid:
		return _reject(validation.reason)
	var captured: Dictionary = _capture(descriptor,current_source_records)
	if not captured.valid:
		return captured
	var state: Dictionary = Motion.begin(feet,descriptor,end)
	var grounding: Dictionary = {}
	if end == "lower":
		grounding=_settle.inspect(descriptor.step_off_point)
		if not grounding.valid:
			return _reject("terminal_"+str(grounding.reason))
		if float(grounding.drop_m)>.00001:
			(state.path as Array).append(grounding.grounded_feet)
			state.total_m=float(state.total_m)+float(grounding.drop_m)
	var plan := {"provider":PROVIDER,"valid":true,"reason":"clear","descriptor":descriptor,
		"initial_state":state,"grounding":grounding,"bindings":captured.bindings,
		"bound_rids":captured.bound_rids,"collision_mask":_mask,"actor_rid":_actor_rid}
	_sequence+=1
	plan.lease_token=_sequence
	_lease=plan.duplicate(true)
	_cursor=0
	_admitted=false
	var points: Array = Motion.route_points(state)
	_samples.clear()
	for i in range(1,points.size()):
		var a: Vector3=points[i-1]
		var b: Vector3=points[i]
		var count := maxi(1,int(ceil(a.distance_to(b)/Probe.SWEEP_STEP_M)))
		for j in range(count+1):
			_samples.append({"root_position":a.lerp(b,float(j)/count)})
	plan.total_admission_samples=_samples.size()
	return plan

func inspect(feet: Vector3, source_descriptor: Dictionary, end: String, current_source_records: Array) -> Dictionary:
	# Synchronous certification convenience. Runtime should use budgeted windows.
	var plan := prepare(feet,source_descriptor,end,current_source_records)
	if not plan.valid:
		return plan
	while not _admitted:
		var window := inspect_window(plan,_cursor,32)
		if not window.clear:
			return _reject(window.reason)
	plan.admitted_samples=_cursor
	return plan

func inspect_window(plan: Dictionary, cursor: int, max_samples: int = 16) -> Dictionary:
	if cursor!=_cursor or max_samples<1 or max_samples>32 or _admitted:
		return {"clear":false,"reason":"invalid_window","complete":false,"next_cursor":_cursor}
	var window := _samples.slice(_cursor,mini(_samples.size(),_cursor+max_samples))
	var result := _inspect_samples(plan,window)
	if not result.clear:
		_lease.clear()
		return {"clear":false,"reason":result.reason,"complete":false,"next_cursor":_cursor}
	_cursor+=int(result.accepted_samples)
	if _cursor==_samples.size():
		var terminal: Vector3=plan.initial_state.path[-1]
		if not _probe.landing_supported(terminal):
			_lease.clear()
			return {"clear":false,"reason":"terminal_unsupported","complete":false,"next_cursor":_cursor}
		_admitted=true
	return {"clear":true,"reason":"clear","complete":_admitted,"next_cursor":_cursor,"accepted_samples":result.accepted_samples,"total_samples":_samples.size()}

func inspect_samples(plan: Dictionary, samples: Array) -> Dictionary:
	if not _admitted:
		return {"clear":false,"reason":"admission_incomplete","accepted_samples":0}
	return _inspect_samples(plan,samples)

func _inspect_samples(plan: Dictionary, samples: Array) -> Dictionary:
	var lease := _validate_lease(plan)
	if not lease.valid:
		return {"clear":false,"reason":lease.reason,"accepted_samples":0}
	var descriptor: Dictionary=plan.descriptor
	var bound: Array[RID]=plan.bound_rids
	for i in samples.size():
		var sample: Variant=samples[i]
		if not sample is Dictionary or not sample.get("root_position") is Vector3 or not sample.root_position.is_finite():
			return {"clear":false,"reason":"invalid_sample","accepted_samples":i}
		var result: Dictionary=_probe.inspect_sweep_samples([sample],descriptor,{"exclude":Policy.excludes_bound(sample.root_position,descriptor,bound)})
		if not result.clear:
			return {"clear":false,"reason":"dynamic_blocked","accepted_samples":i}
	return {"clear":true,"reason":"clear","accepted_samples":samples.size()}

func movement_filters(plan: Dictionary, from: Vector3, to: Vector3) -> Dictionary:
	if not from.is_finite() or not to.is_finite() or from.distance_to(to)>Probe.SWEEP_STEP_M+.00001:
		return {"valid":false,"reason":"invalid_segment"}
	var endpoint := inspect_samples(plan,[{"root_position":to}])
	if not endpoint.clear:
		return {"valid":false,"reason":endpoint.reason}
	var bound: Array[RID]=plan.bound_rids
	var before: Array=Policy.excludes_bound(from,plan.descriptor,bound)
	var after: Array=Policy.excludes_bound(to,plan.descriptor,bound)
	# Boundary exit retains filters for the accepted tiny sweep, restores immediately
	# AFTER it. The outside endpoint was checked with full source collisions above.
	return {"valid":true,"reason":"clear","during_move":bound if not before.is_empty() or not after.is_empty() else [],"after_move":after}

func _capture(descriptor: Dictionary, records: Array) -> Dictionary:
	if records.is_empty():
		return _reject("source_bindings_required")
	var bindings: Array[Dictionary]=[]
	var bound: Array[RID]=[]
	var indices := {}
	var seen_rids := {}
	for value: Variant in records:
		if not value is Dictionary or not is_instance_valid(value.get("body")) or not value.get("body") is StaticBody3D:
			return _reject("invalid_source_binding")
		var body: StaticBody3D=value.body
		var index: Variant=value.get("source_static_index")
		if not index is int or index<0 or indices.has(index) or not _body_valid(body,descriptor.id):
			return _reject("invalid_source_binding")
		if str(value.get("building_entry_id",""))!=str(descriptor.id):
			return _reject("source_identity_mismatch")
		indices[index]=true
		var rid := body.get_rid()
		if seen_rids.has(rid):
			return _reject("duplicate_source_body")
		seen_rids[rid]=true
		if PhysicsServer3D.body_get_shape_count(rid)!=1:
			return _reject("source_shape_mismatch")
		var shape := PhysicsServer3D.body_get_shape(rid,0)
		# Source base envelopes canonically have no storeyPart, mapped explicitly
		# to String "" by trusted source-index binder. Missing binding KEY is unsafe.
		if not value.has("storey_part") or not value.storey_part is String:
			return _reject("source_role_required")
		var role: String=value.storey_part
		bindings.append({"body":body,"instance_id":body.get_instance_id(),"rid":rid,"transform":body.global_transform,
			"source_static_index":index,"shape_rid":shape,"shape_transform":PhysicsServer3D.body_get_shape_transform(rid,0),
			"shape_data":PhysicsServer3D.shape_get_data(shape),"layer":body.collision_layer,"mask":body.collision_mask,"role":role})
		if not role.begins_with("Roof_Ladder_Rail_Collision") and not bound.has(rid):
			bound.append(rid)
	return {"valid":true,"bindings":bindings,"bound_rids":bound}

func _body_valid(body: StaticBody3D, source_id: String) -> bool:
	return is_instance_valid(body) and not body is AnimatableBody3D and not body.is_queued_for_deletion() and body.is_inside_tree() and body.get_world_3d().direct_space_state==_space and str(body.get_meta("source_id",""))==source_id and body.constant_linear_velocity==Vector3.ZERO and body.constant_angular_velocity==Vector3.ZERO

func _validate_lease(plan: Dictionary) -> Dictionary:
	if _space==null or _mask<=0 or plan.get("provider")!=PROVIDER or not bool(plan.get("valid",false)) or not plan.get("descriptor") is Dictionary or not plan.get("bindings") is Array or not plan.get("bound_rids") is Array or not plan.get("grounding") is Dictionary or not plan.get("initial_state") is Dictionary:
		return _reject("invalid_plan")
	if plan.bindings.is_empty() or not bool(plan.descriptor.get("valid",false)) or Descriptor.normalize(plan.descriptor)!=plan.descriptor:
		return _reject("invalid_plan")
	if plan.get("collision_mask")!=_mask or plan.get("actor_rid")!=_actor_rid:
		return _reject("query_authority_changed")
	if _lease.is_empty() or plan.get("lease_token")!=_lease.get("lease_token"):
		return _reject("source_lease_changed")
	for key: String in ["descriptor","initial_state","bindings","bound_rids","grounding"]:
		if plan.get(key)!=_lease.get(key):
			return _reject("source_lease_changed")
	var initial: Dictionary=plan.initial_state
	if not initial.get("root_position") is Vector3 or not initial.get("entry_end") is String:
		return _reject("invalid_plan")
	var expected_state: Dictionary=Motion.begin(initial.root_position,plan.descriptor,initial.entry_end)
	if not expected_state.valid:
		return _reject("invalid_plan")
	if initial.entry_end=="lower":
		if plan.grounding.is_empty() or plan.grounding.get("authored_feet")!=plan.descriptor.step_off_point or not plan.grounding.get("grounded_feet") is Vector3:
			return _reject("invalid_plan")
		if float(plan.grounding.get("drop_m",NAN))>.00001:
			expected_state.path.append(plan.grounding.grounded_feet)
			expected_state.total_m=float(expected_state.total_m)+float(plan.grounding.drop_m)
	elif not plan.grounding.is_empty():
		return _reject("invalid_plan")
	if expected_state!=initial:
		return _reject("invalid_plan")
	var expected_bound: Array[RID]=[]
	var source_indices := {}
	var source_rids := {}
	for entry: Variant in plan.bindings:
		if not entry is Dictionary or not is_instance_valid(entry.get("body")) or not entry.body is StaticBody3D:
			return _reject("source_lease_changed")
		var body: StaticBody3D=entry.body
		var index: Variant=entry.get("source_static_index")
		if not index is int or index<0 or source_indices.has(index) or source_rids.has(body.get_rid()) or not entry.get("role") is String:
			return _reject("source_lease_changed")
		source_indices[index]=true
		source_rids[body.get_rid()]=true
		if not _body_valid(body,str(plan.descriptor.get("id",""))) or body.get_rid()!=entry.get("rid") or body.get_instance_id()!=entry.get("instance_id") or body.global_transform!=entry.get("transform") or body.collision_layer!=entry.get("layer") or body.collision_mask!=entry.get("mask"):
			return _reject("source_lease_changed")
		var rid := body.get_rid()
		if PhysicsServer3D.body_get_shape_count(rid)!=1 or PhysicsServer3D.body_get_shape(rid,0)!=entry.get("shape_rid") or PhysicsServer3D.body_get_shape_transform(rid,0)!=entry.get("shape_transform") or PhysicsServer3D.shape_get_data(entry.shape_rid)!=entry.get("shape_data") or body.is_shape_owner_disabled(body.shape_find_owner(0)):
			return _reject("source_lease_changed")
		if not str(entry.get("role","")).begins_with("Roof_Ladder_Rail_Collision"):
			expected_bound.append(rid)
	if expected_bound!=plan.bound_rids:
		return _reject("source_filters_changed")
	if not plan.get("grounding",{}).is_empty() and not _settle.revalidate(plan.grounding).valid:
		return _reject("terminal_support_changed")
	return {"valid":true,"reason":"clear"}

func _reject(reason: String) -> Dictionary:
	return {"provider":PROVIDER,"valid":false,"reason":reason}
