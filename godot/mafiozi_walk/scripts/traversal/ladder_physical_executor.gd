class_name NativeLadderPhysicalExecutor
extends RefCounted
## Opt-in caller-owned CharacterBody executor. No automatic process/input/rig.
## Root must suspend other body writers while pending/active and own recovery.

const Route=preload("res://scripts/traversal/ladder_source_route_probe.gd")
const Motion=preload("res://scripts/traversal/ladder_motion.gd")
const Pose=preload("res://scripts/traversal/ladder_pose.gd")
const Probe=preload("res://scripts/traversal/ladder_probe.gd")
const PROVIDER := "GODOT_LADDER_PHYSICAL_EXECUTOR_V1"
const ROOT_EPSILON_M := .00001

var _actor: CharacterBody3D
var _route:=Route.new()
var _probe:=Probe.new()
var _plan: Dictionary={}
var _state: Dictionary={}
var _actor_lease: Dictionary={}
var _owned: Array[RID]=[]
var _borrowed: Array[RID]=[]
var _pending:=false
var _cursor:=0
var _last_root:=Vector3.ZERO
var _reason:="unconfigured"

func configure_actor(actor: CharacterBody3D) -> Dictionary:
	dispose()
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree():
		return _report(false,"actor_unavailable")
	_actor=actor
	if not actor.global_position.is_finite() or not is_finite(actor.safe_margin) or actor.safe_margin<0.0 or actor.safe_margin>Probe.FLOOR_SKIN_M:
		_actor=null
		return _report(false,"actor_envelope_mismatch")
	var rid:=actor.get_rid()
	if PhysicsServer3D.body_get_shape_count(rid)!=1:
		_actor=null
		return _report(false,"actor_shape_mismatch")
	var owner:=actor.shape_find_owner(0)
	var shape: Shape3D=actor.shape_owner_get_shape(owner,0)
	var transform:=PhysicsServer3D.body_get_shape_transform(rid,0)
	if not shape is CapsuleShape3D or actor.is_shape_owner_disabled(owner) or not actor.global_basis.is_equal_approx(Basis.IDENTITY) or not transform.basis.is_equal_approx(Basis.IDENTITY):
		_actor=null
		return _report(false,"actor_shape_mismatch")
	if absf(shape.height-Probe.BODY_HEIGHT_M)>ROOT_EPSILON_M or shape.radius<=0.0 or shape.radius>Probe.BODY_RADIUS_M or absf(transform.origin.x)>ROOT_EPSILON_M or absf(transform.origin.z)>ROOT_EPSILON_M or transform.origin.y<shape.height*.5-ROOT_EPSILON_M or transform.origin.y>shape.height*.5+Probe.FLOOR_SKIN_M+ROOT_EPSILON_M:
		_actor=null
		return _report(false,"actor_envelope_mismatch")
	_actor_lease={"rid":rid,"instance_id":actor.get_instance_id(),"mask":actor.collision_mask,"layer":actor.collision_layer,
		"basis":actor.global_basis,"space":actor.get_world_3d().direct_space_state,"shape_rid":shape.get_rid(),"shape_data":PhysicsServer3D.shape_get_data(shape.get_rid()),"shape_transform":transform,"safe_margin":actor.safe_margin}
	_last_root=actor.global_position
	_route.configure(actor.get_world_3d().direct_space_state,actor.collision_mask,rid)
	_probe.configure(actor.get_world_3d().direct_space_state,actor.collision_mask,rid)
	_reason="configured"
	return _report(true,_reason)

func begin(source_descriptor: Dictionary,end: String,records: Array,input_action: StringName=&"interact") -> Dictionary:
	if input_action!=&"interact":
		return {"provider":PROVIDER,"claimed":false,"accepted":false,"reason":"input_pass_through"}
	if busy():
		return {"provider":PROVIDER,"claimed":true,"accepted":false,"reason":"already_owned"}
	var guard:=_guard_actor(false)
	if not guard.valid:
		return {"provider":PROVIDER,"claimed":true,"accepted":false,"reason":guard.reason}
	_last_root=_actor.global_position
	# The caller exclusively owns exception mutations outside busy(). Capture
	# its live baseline once; do not resolve potentially freed source bodies later.
	_borrowed.clear()
	for body: PhysicsBody3D in _actor.get_collision_exceptions():
		if is_instance_valid(body): _borrowed.append(body.get_rid())
	_state.clear()
	_route.configure(_actor.get_world_3d().direct_space_state,_actor.collision_mask,_actor.get_rid())
	_plan=_route.prepare(_actor.global_position,source_descriptor,end,records)
	if not _plan.valid:
		_reason=_plan.reason
		return {"provider":PROVIDER,"claimed":true,"accepted":false,"reason":_reason}
	_pending=true
	_cursor=0
	_reason="admission_pending"
	return {"provider":PROVIDER,"claimed":true,"accepted":true,"pending":true,"reason":_reason}

func advance_admission(max_samples: int=16) -> Dictionary:
	if not _pending:
		return _report(false,"not_pending")
	var guard:=_guard_actor()
	if not guard.valid: return abort(guard.reason)
	var window: Dictionary=_route.inspect_window(_plan,_cursor,max_samples)
	if not window.clear: return abort(window.reason)
	_cursor=window.next_cursor
	if window.complete:
		_pending=false
		_state=_plan.initial_state.duplicate(true)
		_reason="active"
	return {"provider":PROVIDER,"valid":true,"pending":_pending,"active":active(),"reason":_reason,"next_cursor":_cursor}

func request_slide() -> Dictionary:
	if not active(): return {"provider":PROVIDER,"claimed":false,"accepted":false,"reason":"input_pass_through"}
	var guard:=_guard_actor()
	if not guard.valid: return abort(guard.reason)
	_state=Motion.slide_down(_state)
	return {"provider":PROVIDER,"claimed":true,"accepted":true,"reason":"slide_active"}

func request_cancel() -> Dictionary:
	if _pending: return abort("admission_cancelled")
	if not active(): return {"provider":PROVIDER,"claimed":false,"accepted":false,"reason":"input_pass_through"}
	var guard:=_guard_actor()
	if not guard.valid: return abort(guard.reason)
	_state=Motion.cancel(_state)
	_reason="safe_cancel"
	return {"provider":PROVIDER,"claimed":true,"accepted":true,"reason":_reason}

func step(delta_s: float,rig: Dictionary={}) -> Dictionary:
	if not active(): return _report(false,"not_active")
	var guard:=_guard_actor()
	if not guard.valid: return abort(guard.reason)
	var proposal: Dictionary=Motion.propose(_state,delta_s)
	if not proposal.valid: return abort(proposal.reason)
	# Each <=4cm physical segment below revalidates the complete source lease
	# and conservative endpoint. Avoid an identical extra whole-frame query.
	var accepted:=0
	var failure:=""
	var physical_contact: Dictionary={}
	for sample: Dictionary in proposal.sweep_samples:
		var filters: Dictionary=_route.movement_filters(_plan,_actor.global_position,sample.root_position)
		if not filters.valid:
			failure=filters.reason
			break
		_sync_filters(filters.during_move)
		var from: Vector3=_actor.global_position
		var start_support: bool=float(_state.travelled_m)==0.0 and _probe.landing_supported(from)
		var collision:=_actor.move_and_collide(sample.root_position-_actor.global_position)
		_last_root=_actor.global_position
		var exact:=_last_root.distance_to(sample.root_position)<=ROOT_EPSILON_M
		var terminal_skin:=false
		var start_skin:=false
		var root_error: Vector3=_last_root-sample.root_position
		var terminal_target: bool=Motion.requires_terminal_support(sample.state) or sample.root_position.distance_to((sample.state.path as Array)[-1])<=ROOT_EPSILON_M
		if start_support and (collision==null or collision.get_normal().y>=Probe.MIN_WALKABLE_UP_DOT):
			start_skin=root_error.length()<=minf(Probe.FLOOR_SKIN_M,_actor.safe_margin+ROOT_EPSILON_M) and root_error.y>=-ROOT_EPSILON_M
		if terminal_target:
			var error: Vector3=_last_root-sample.root_position
			terminal_skin=Vector2(error.x,error.z).length()<=ROOT_EPSILON_M and error.y>=-ROOT_EPSILON_M and error.y<=minf(Probe.FLOOR_SKIN_M,_actor.safe_margin+ROOT_EPSILON_M) and (collision==null or collision.get_normal().y>=Probe.MIN_WALKABLE_UP_DOT) and _probe.landing_supported(_last_root)
		if (collision!=null or not exact) and not terminal_skin and not start_skin:
			failure="physical_blocked"
			physical_contact={"target":sample.root_position,"actual":_last_root,"normal":collision.get_normal() if collision!=null else Vector3.ZERO,"has_collision":collision!=null}
			break
		if terminal_target and not _probe.landing_supported(_last_root):
			failure="terminal_unsupported"
			break
		# Re-query native recovery's real endpoint before restoring corridor filters.
		if not exact:
			var actual_filters: Dictionary=_route.movement_filters(_plan,_last_root,_last_root)
			if not actual_filters.valid:
				failure=actual_filters.reason
				break
			filters=actual_filters
		_sync_filters(filters.after_move)
		accepted+=1
	_state=Motion.commit(_state,proposal,accepted,failure)
	# Actual partial collision or supporting skin contact always wins over planned root.
	_state.root_position=_last_root
	if not failure.is_empty():
		var stopped:=abort(failure)
		stopped.physical_contact=physical_contact
		return stopped
	if _state.done:
		_reason="complete"
		_release_filters()
	else:
		_reason="active"
	return {"provider":PROVIDER,"valid":true,"reason":_reason,"active":active(),"accepted_samples":accepted,
		"actual_root":_last_root,"state":state(),"pose":committed_pose(rig)}

func abort(reason: String="aborted") -> Dictionary:
	if not _state.is_empty() and bool(_state.get("valid",false)):
		_state=Motion.abort(_state,reason)
		if is_instance_valid(_actor): _state.root_position=_actor.global_position
	_pending=false
	_release_filters()
	_route.dispose()
	_reason=reason
	return {"provider":PROVIDER,"valid":false,"claimed":true,"accepted":false,"reason":reason,"active":false,"pending":false,
		"actual_root":_actor.global_position if is_instance_valid(_actor) else _last_root,"needs_physical_recovery":not _state.is_empty(),"state":state()}

func dispose() -> void:
	_release_filters()
	_route.dispose()
	_probe.configure(null,0,RID())
	_actor=null
	_actor_lease.clear()
	_plan.clear()
	_state.clear()
	_pending=false
	_borrowed.clear()
	_cursor=0
	_reason="disposed"

func busy() -> bool: return _pending or active()
func active() -> bool: return bool(_state.get("valid",false)) and not bool(_state.get("done",true))
func state() -> Dictionary: return _state.duplicate(true)
func owned_filters() -> Array[RID]: return _owned.duplicate()

## Read-only lifecycle binding for the current admitted ownership, never input.
func lifetime_authority() -> Dictionary:
	if not busy(): return _report(false,"not_owned")
	var guard:=_guard_actor()
	if not guard.valid: return guard
	var sources: Array=[]
	for binding: Dictionary in _plan.bindings:
		var body: Variant=binding.body
		if not is_instance_valid(body) or body.is_queued_for_deletion() or not body.is_inside_tree() or body.get_instance_id()!=binding.instance_id or body.get_rid()!=binding.rid:
			return _report(false,"source_unavailable")
		sources.append({"body":body,"instance_id":binding.instance_id,"rid":binding.rid})
	return {"provider":PROVIDER,"valid":true,"reason":"owned","actor":_actor,"actor_instance_id":_actor_lease.instance_id,"sources":sources}

func committed_pose(rig: Dictionary={}) -> Dictionary:
	if _state.is_empty(): return {"valid":false,"reason":"no_committed_state"}
	return Pose.propose(_state.descriptor,{"root_position":_state.root_position,"travelled_m":_state.travelled_m,"direction":_state.direction,"sliding":_state.sliding,"mount_progress":_state.mount_progress,"dismount_progress":_state.dismount_progress},rig)

func _guard_actor(require_owned_root: bool=true) -> Dictionary:
	if not is_instance_valid(_actor) or _actor.is_queued_for_deletion() or not _actor.is_inside_tree() or _actor_lease.is_empty(): return _report(false,"actor_unavailable")
	var rid:=_actor.get_rid()
	if not _actor.global_position.is_finite() or rid!=_actor_lease.rid or _actor.get_instance_id()!=_actor_lease.instance_id or _actor.collision_mask!=_actor_lease.mask or _actor.collision_layer!=_actor_lease.layer or _actor.global_basis!=_actor_lease.basis or _actor.get_world_3d().direct_space_state!=_actor_lease.space or _actor.safe_margin!=_actor_lease.safe_margin or (require_owned_root and _actor.global_position.distance_to(_last_root)>ROOT_EPSILON_M): return _report(false,"actor_authority_changed")
	if PhysicsServer3D.body_get_shape_count(rid)!=1 or PhysicsServer3D.body_get_shape(rid,0)!=_actor_lease.shape_rid or PhysicsServer3D.shape_get_data(_actor_lease.shape_rid)!=_actor_lease.shape_data or PhysicsServer3D.body_get_shape_transform(rid,0)!=_actor_lease.shape_transform or _actor.is_shape_owner_disabled(_actor.shape_find_owner(0)): return _report(false,"actor_shape_changed")
	return _report(true,"current")

func _sync_filters(wanted: Array) -> void:
	if not is_instance_valid(_actor): return
	for rid: RID in _owned.duplicate():
		if not wanted.has(rid):
			PhysicsServer3D.body_remove_collision_exception(_actor.get_rid(),rid)
			_owned.erase(rid)
	for rid: RID in wanted:
		if not _borrowed.has(rid) and not _owned.has(rid):
			PhysicsServer3D.body_add_collision_exception(_actor.get_rid(),rid)
			_owned.append(rid)

func _release_filters() -> void:
	if is_instance_valid(_actor):
		for rid: RID in _owned:
			PhysicsServer3D.body_remove_collision_exception(_actor.get_rid(),rid)
	_owned.clear()

func _report(valid: bool,reason: String) -> Dictionary:
	return {"provider":PROVIDER,"valid":valid,"reason":reason}
