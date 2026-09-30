extends RefCounted
## OUTPUTS-ONLY PROPOSAL for Artist23 review. Capability registration is explicit.
## No masks, body/rig transforms, freeze, HP, blood, pose or death writes.
const SCHEMA:="npc_final_dead_contact/v1"
const IDENTITY:=["session_id","source_id","render_id","bridge_id","descriptor_sha256","placement_mode","life_generation","rig_epoch","body_instance_id","body_rid","rig_instance_id"]
var _player:WeakRef
var _capsule:WeakRef
var _records:Array=[]
var _by_rid:Dictionary={}
var _seen:Dictionary={}
var _epoch:=0
var _last_consumed_move:=-1
var _configured:=false
var _disposed:=false
var _busy:=false
var _query:=PhysicsShapeQueryParameters3D.new()
var _options:Dictionary={}
var stats:Dictionary={"attempted":0,"accepted":0,"rejected":0,"applied_ns":0.0}
func _init()->void:
	# Godot ObjectID is unique across simultaneous/replaced port instances.
	# RefCounted ObjectIDs reserve the sign bit; all ports share that category.
	_epoch=get_instance_id() & 0x7fffffffffffffff
func configure(player:CharacterBody3D,records:Array,options:Dictionary)->Dictionary:
	if _configured or _disposed or not Thread.is_main_thread():return {"ok":false,"reason":"lifetime"}
	if not is_instance_valid(player) or not player.is_inside_tree() or str(player.get_script().resource_path)!="res://scripts/preview_player.gd":return {"ok":false,"reason":"original_player_required"}
	var capsule:CollisionShape3D=player.get_node_or_null("PlayerCapsule")
	if capsule==null or not capsule.shape is CapsuleShape3D or records.is_empty() or records.size()>128:return {"ok":false,"reason":"capsule_or_records"}
	for key:String in ["max_impulse_ns","impulse_ns_per_mps","max_point_delta_energy_j","max_linear_speed_mps","max_angular_speed_rps","cooldown_ms"]:
		if typeof(options.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(options[key])) or float(options[key])<=0:return {"ok":false,"reason":"explicit_measured_limits_required:"+key}
	if options.max_impulse_ns>3.0 or options.impulse_ns_per_mps>1.0 or options.max_point_delta_energy_j>2.0 or options.max_linear_speed_mps>3.0 or options.max_angular_speed_rps>15.0 or options.cooldown_ms<80 or options.cooldown_ms>1000:return {"ok":false,"reason":"proposal_absolute_bound"}
	if not player.has_method("completed_ground_move_receipt"):return {"ok":false,"reason":"completed_move_receipt_required"}
	var pending:Array=[];var rid_map:Dictionary={}
	for item:Variant in records:
		if not item is Dictionary or not item.get("ragdoll_host") is RefCounted or not item.get("binding") is Dictionary or not item.get("current_life") is Callable or not item.current_life.is_valid():return {"ok":false,"reason":"capability_record"}
		var host:RefCounted=item.ragdoll_host
		if not host.has_method("status") or not host.has_method("owned_bodies"):return {"ok":false,"reason":"public_host_interface"}
		var status:Dictionary=host.status()
		for key:String in IDENTITY:
			if not item.binding.has(key) or status.get("binding",{}).get(key)!=item.binding[key]:return {"ok":false,"reason":"binding:"+key}
		var record:Dictionary={"host":host,"binding":item.binding.duplicate(true),"current":item.current_life,"parts":[],"last_ms":-1000000}
		var parts:Array=host.owned_bodies()
		if parts.size()!=16:return {"ok":false,"reason":"original_16_part_pool_required"}
		for body:Variant in parts:
			if not body is RigidBody3D or not is_instance_valid(body) or not body.is_inside_tree() or body.get_world_3d()!=player.get_world_3d() or rid_map.has(body.get_rid()):return {"ok":false,"reason":"part_identity"}
			var part:Dictionary={"body":weakref(body),"rid":body.get_rid(),"instance":body.get_instance_id(),"record":pending.size()}
			record.parts.append(part);rid_map[body.get_rid()]=part
		pending.append(record)
	_player=weakref(player);_capsule=weakref(capsule);_records=pending;_by_rid=rid_map;_options=options.duplicate();_configured=true
	return {"ok":true,"schema":SCHEMA,"records":_records.size(),"epoch":_epoch,"enabled":true,"proposal_only":true}
func _identity_live(record:Dictionary,incarnation:int)->bool:
	if _disposed or not _configured or _epoch!=incarnation or not _records.has(record) or not is_instance_valid(record.host) or not record.current.is_valid():return false
	var status:Dictionary=record.host.status()
	if status.get("mode")!="ACTIVE" or status.get("final_dead")!=true or str(status.get("death_key","")).is_empty():return false
	for key:String in IDENTITY:
		if status.get("binding",{}).get(key)!=record.binding[key]:return false
	return true
func _live(record:Dictionary)->bool:
	var incarnation:=_epoch
	if not _identity_live(record,incarnation):return false
	var host_id:int=record.host.get_instance_id()
	var current:Variant=record.current.call(record.binding.duplicate(true))
	# The owner callback may retire this port or change/recycle its host.
	return current is bool and current and _identity_live(record,incarnation) and record.host.get_instance_id()==host_id
func player_final_dead_contact_ready()->Dictionary:
	if not _configured or _disposed or _busy:return {"ready":false}
	for record:Dictionary in _records:
		if _live(record):return {"ready":true,"schema":SCHEMA,"epoch":_epoch,"max_impulse_ns":_options.max_impulse_ns,"impulse_ns_per_mps":_options.impulse_ns_per_mps,"cooldown_ms":_options.cooldown_ms,"max_contact_height_m":.65,"max_relative_speed_mps":7.0}
	return {"ready":false}
func _reject(reason:String)->Dictionary:
	stats.rejected+=1;return {"ok":false,"reason":reason,"applied_impulse_ns":Vector3.ZERO}
func admit_player_final_dead_contact(request:Dictionary)->Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or not _configured:return _reject("lifetime_or_reentry")
	_busy=true;stats.attempted+=1
	var result:=_admit(request)
	_busy=false;return result
func _admit(r:Dictionary)->Dictionary:
	var incarnation:=_epoch
	var player:CharacterBody3D=_player.get_ref();var capsule:CollisionShape3D=_capsule.get_ref()
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion() or not is_instance_valid(capsule) or capsule.disabled:return _reject("player_lifetime")
	if not Engine.is_in_physics_frame() or r.get("schema")!=SCHEMA or r.get("owner_epoch")!=_epoch or r.get("physics_frame")!=Engine.get_physics_frames():return _reject("frame_or_epoch")
	if not r.get("event_id") is String or r.event_id.is_empty() or r.event_id.length()>160 or _seen.has(r.event_id):return _reject("replay_or_event_id")
	if r.get("actor_instance_id")!=player.get_instance_id() or r.get("actor_rid")!=player.get_rid() or r.get("actor_pose_epoch")!=player._pose_epoch:return _reject("actor_identity")
	var completed:Dictionary=player.completed_ground_move_receipt()
	if completed.get("frame")!=Engine.get_physics_frames() or completed.get("pose_epoch")!=player._pose_epoch or not completed.get("serial") is int or completed.serial<=_last_consumed_move or r.get("movement_serial")!=completed.serial:return _reject("completed_move_required")
	if completed.get("start")!=r.get("actor_start") or completed.get("end")!=r.get("actor_end"):return _reject("completed_move_mismatch")
	if player._pose_authority!=&"on_foot" or not player._jump.is_empty() or not player.is_on_floor() or not player._free_mouse_look or player._text_control_focused():return _reject("actor_not_ground_walking")
	if is_instance_valid(player._weapon_host) and player._weapon_host.controls_blocked():return _reject("actor_menu")
	if r.get("delivery")!="command_unapplied" or r.get("damage")!=false or not _by_rid.has(r.get("collider_rid")):return _reject("target_or_delivery")
	var part:Dictionary=_by_rid[r.collider_rid];var record:Dictionary=_records[part.record]
	if not _live(record):return _reject("not_current_final_dead")
	var body:RigidBody3D=part.body.get_ref()
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or body.get_rid()!=part.rid or body.get_instance_id()!=part.instance or r.get("collider_instance_id")!=part.instance:return _reject("part_replaced")
	if body.get_world_3d()!=player.get_world_3d() or body.freeze or body.collision_layer!=256 or body.collision_mask!=257:return _reject("part_inactive_or_filters")
	# Detect pool replacement through its public capability, not a private chain.
	if not body in record.host.owned_bodies():return _reject("not_owned_part")
	var now:=Time.get_ticks_msec()
	if now-int(record.last_ms)<int(_options.cooldown_ms):return _reject("corpse_cooldown")
	if not r.get("now_ms") is int or abs(now-r.now_ms)>50:return _reject("stale_clock")
	for key:String in ["actor_start","actor_end","actual_velocity","world_point","world_normal","body_velocity","suggested_impulse_ns"]:
		if not r.get(key) is Vector3 or not r[key].is_finite():return _reject("nonfinite:"+key)
	var delta:=player.get_physics_process_delta_time();var motion:=player.get_position_delta()
	if not motion.is_finite() or delta<=0 or delta>.1:return _reject("motion_delta")
	var horizontal:=Vector3(motion.x,0,motion.z);var velocity:=horizontal/delta
	if horizontal.length()<.001 or absf(motion.y)>.15 or velocity.length()>7.0:return _reject("motion_not_walking")
	if r.actor_end.distance_to(player.global_position)>.002 or r.actor_start.distance_to(player.global_position-motion)>.002 or r.actual_velocity.distance_to(velocity)>.03:return _reject("actual_motion_mismatch")
	_query.shape=capsule.shape;_query.transform=capsule.global_transform;_query.transform.origin-=motion;_query.collision_mask=256;_query.exclude=[player.get_rid()];_query.margin=.001;_query.motion=Vector3.ZERO
	var space:=player.get_world_3d().direct_space_state
	var contact:=space.get_rest_info(_query)
	if contact.is_empty():
		_query.motion=motion;var sweep:=space.cast_motion(_query)
		if sweep.size()!=2 or sweep[0]>=1:return _reject("no_native_sweep_contact")
		_query.transform.origin+=motion*clampf(sweep[1],0,1);_query.motion=Vector3.ZERO;contact=space.get_rest_info(_query)
	if contact.is_empty() or contact.rid!=part.rid or contact.collider_id!=part.instance or contact.shape!=r.get("shape_index"):return _reject("native_contact_identity")
	if contact.point.distance_to(r.world_point)>.005 or contact.normal.dot(r.world_normal)<.98:return _reject("native_contact_changed")
	var height:float=contact.point.y-minf(player.global_position.y,(player.global_position-motion).y)
	if height<-.025 or height>.65:return _reject("not_foot_contact")
	var normal:=Vector3(contact.normal.x,0,contact.normal.z)
	if normal.length_squared()<.25:return _reject("nonhorizontal_contact")
	normal=normal.normalized()
	var closing:float=-(velocity-contact.linear_velocity).dot(normal)
	if closing<.15 or closing>7 or contact.linear_velocity.distance_to(r.body_velocity)>.05:return _reject("not_closing_or_velocity_changed")
	var origin:=player.global_position+Vector3.UP*.35;var end:Vector3=contact.point+(origin-contact.point).normalized()*.003
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1,[player.get_rid()])).is_empty():return _reject("world_occluded")
	var expected:Vector3=-normal*minf(float(_options.max_impulse_ns),closing*float(_options.impulse_ns_per_mps))
	if expected.distance_to(r.suggested_impulse_ns)>.005 or absf(expected.y)>.00001:return _reject("impulse_formula")
	var state:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state==null or not state.inverse_inertia_tensor.is_finite() or not is_finite(body.mass) or body.mass<=0:return _reject("native_state")
	var impulse:=expected;var offset:Vector3=contact.point-body.global_position
	# Bounded search retains safe point impulse strength without the up-to-2x
	# loss of a coarse halve-and-stop limiter. No transforms/velocities changed.
	var predicted:Dictionary={}
	var lower:=0.0;var upper:=1.0;var fraction:=1.0
	var safe_prediction:Dictionary={}
	for attempt:int in 10:
		impulse=expected*fraction
		var dv:=impulse/body.mass;var dw:Vector3=state.inverse_inertia_tensor*(offset.cross(impulse))
		var v:Vector3=state.linear_velocity+dv;var w:Vector3=state.angular_velocity+dw
		var linear_energy:=.5*body.mass*(v.length_squared()-state.linear_velocity.length_squared())
		var angular_energy:float=state.angular_velocity.dot(offset.cross(impulse))+.5*dw.dot(offset.cross(impulse))
		predicted={"linear_speed":v.length(),"angular_speed":w.length(),"delta_energy_j":linear_energy+angular_energy}
		if v.length()<=float(_options.max_linear_speed_mps) and w.length()<=float(_options.max_angular_speed_rps) and linear_energy+angular_energy<=float(_options.max_point_delta_energy_j):
			lower=fraction;safe_prediction=predicted
			if fraction==1.0:break
		else:upper=fraction
		fraction=(lower+upper)*.5
	impulse=expected*lower;predicted=safe_prediction
	if predicted.is_empty():return _reject("point_energy_bound")
	if impulse.length()<.005 or predicted.linear_speed>float(_options.max_linear_speed_mps) or predicted.angular_speed>float(_options.max_angular_speed_rps) or predicted.delta_energy_j>float(_options.max_point_delta_energy_j):return _reject("point_energy_bound")
	if not _live(record) or not _identity_live(record,incarnation) or not is_instance_valid(body) or body.is_queued_for_deletion() or body.freeze:return _reject("life_changed_before_commit")
	if player.completed_ground_move_receipt()!=completed or body.get_rid()!=part.rid or body.get_instance_id()!=part.instance or not body in record.host.owned_bodies():return _reject("capability_changed_before_commit")
	_last_consumed_move=completed.serial
	_seen[r.event_id]=true
	if _seen.size()>1024:_seen.erase(_seen.keys()[0])
	record.last_ms=now
	var was_sleeping:=body.sleeping
	# Native public method, on the exact revalidated owned segment only.
	body.apply_impulse(impulse,offset)
	stats.accepted+=1;stats.applied_ns+=impulse.length()
	return {"ok":true,"event_id":r.event_id,"owner_epoch":_epoch,"source_id":record.binding.source_id,"life_generation":record.binding.life_generation,"applied_segment":str(body.name),"applied_body_instance_id":part.instance,"applied_impulse_ns":impulse,"native_point":contact.point,"was_sleeping":was_sleeping,"sleeping_after_call":body.sleeping,"predicted":predicted,"damage":false}
func dispose()->void:
	if _disposed:return
	_disposed=true;_configured=false;_epoch+=1;_records.clear();_by_rid.clear();_seen.clear();_player=null;_capsule=null
