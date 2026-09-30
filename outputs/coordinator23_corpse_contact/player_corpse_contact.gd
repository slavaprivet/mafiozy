extends RefCounted
## PROPOSAL ONLY. No binding or production enable until NPC owner implements
## the public admission contract. Root detects contact; NPC owner owns force.
var _ready_hook:Callable
var _admit_hook:Callable
var _query:=PhysicsShapeQueryParameters3D.new()
var _last_attempt_ms:=-1000000
var _serial:=0
var attempts:=0
var accepted:=0
var last_result:Dictionary={}
func configure(ready_hook:Callable,admit_hook:Callable)->bool:
	_ready_hook=ready_hook;_admit_hook=admit_hook
	return _ready_hook.is_valid() and _admit_hook.is_valid()
func begin(player:CharacterBody3D)->Dictionary:
	if not _ready_hook.is_valid() or not _admit_hook.is_valid() or not player.is_on_floor():return {}
	if player._pose_authority!=&"on_foot" or not player._jump.is_empty() or not player._free_mouse_look:return {}
	var capsule:CollisionShape3D=player.get_node_or_null("PlayerCapsule")
	if not is_instance_valid(capsule) or capsule.disabled or capsule.shape==null:return {}
	return {"position":player.global_position,"capsule":capsule.global_transform,"shape":capsule.shape,"velocity":player.velocity,"frame":Engine.get_physics_frames(),"pose_epoch":player._pose_epoch}
func finish(player:CharacterBody3D,start:Dictionary,delta:float)->void:
	if start.is_empty() or not _ready_hook.is_valid() or not _admit_hook.is_valid():return
	if not Engine.is_in_physics_frame() or start.frame!=Engine.get_physics_frames() or start.pose_epoch!=player._pose_epoch:return
	if player._pose_authority!=&"on_foot" or not player._jump.is_empty() or not player.is_on_floor() or not player._free_mouse_look:return
	if not is_finite(delta) or delta<=0 or delta>.1:return
	var motion:Vector3=player.global_position-start.position
	var horizontal:=Vector3(motion.x,0,motion.z)
	if not motion.is_finite() or horizontal.length()<.001 or absf(motion.y)>.15:return
	# Actual move_and_slide result, never desired movement or teleported placement.
	var intended:Vector3=start.velocity*delta
	if horizontal.length()>Vector2(intended.x,intended.z).length()+.02:return
	var now:=Time.get_ticks_msec()
	# Fixed coarse gate avoids repeated owner work while standing in contact.
	if now-_last_attempt_ms<50:return
	var contract:Variant=_ready_hook.call()
	if not contract is Dictionary or not contract.get("ready",false) or contract.get("schema")!="npc_final_dead_contact/v1":return
	for name:String in ["epoch","max_impulse_ns","impulse_ns_per_mps","cooldown_ms","max_contact_height_m","max_relative_speed_mps"]:
		if not contract.has(name):return
		if typeof(contract[name]) not in [TYPE_INT,TYPE_FLOAT]:return
	if not contract.epoch is int or contract.epoch<1:return
	var cap:float=contract.max_impulse_ns;var gain:float=contract.impulse_ns_per_mps
	var cooldown:int=contract.cooldown_ms;var height:float=contract.max_contact_height_m;var maximum_speed:float=contract.max_relative_speed_mps
	if not is_finite(cap) or cap<=0 or not is_finite(gain) or gain<=0 or cooldown<50 or cooldown>1000 or not is_finite(height) or height<=0 or height>.65 or not is_finite(maximum_speed) or maximum_speed<=0:return
	if now-_last_attempt_ms<cooldown:return
	_query.shape=start.shape;_query.transform=start.capsule;_query.motion=motion
	_query.collision_mask=256;_query.exclude=[player.get_rid()];_query.margin=.001
	_query.collide_with_areas=false;_query.collide_with_bodies=true
	var space:=player.get_world_3d().direct_space_state
	# cast_motion intentionally ignores bodies already overlapping the start.
	# First use a real rest-info contact at the actual initial capsule transform.
	_query.motion=Vector3.ZERO
	var contact:Dictionary=space.get_rest_info(_query)
	var initial_overlap:=not contact.is_empty()
	var sweep:=PackedFloat32Array([0.0,0.0])
	if contact.is_empty():
		_query.motion=motion;sweep=space.cast_motion(_query)
		if sweep.size()!=2 or sweep[0]>=1.0:return
		_query.transform.origin=start.capsule.origin+motion*clampf(sweep[1],0,1)
		_query.motion=Vector3.ZERO
		contact=space.get_rest_info(_query)
	if contact.is_empty() or not contact.get("rid") is RID or not contact.get("point") is Vector3 or not contact.get("normal") is Vector3:return
	var point:Vector3=contact.point;var normal:Vector3=contact.normal
	if not point.is_finite() or not normal.is_finite() or normal.length_squared()<.5:return
	var local_height:=point.y-minf(start.position.y,player.global_position.y)
	if local_height<-.025 or local_height>height:return
	var horizontal_normal:=Vector3(normal.x,0,normal.z)
	if horizontal_normal.length_squared()<.25:return
	horizontal_normal=horizontal_normal.normalized()
	var actor_velocity:=horizontal/delta
	var body_velocity:Vector3=contact.get("linear_velocity",Vector3.ZERO)
	if not body_velocity.is_finite():return
	var closing_speed:float=maxf(0.0,-(actor_velocity-body_velocity).dot(horizontal_normal))
	if closing_speed<.15 or closing_speed>maximum_speed:return
	# Separate layer1 obstruction check; cannot transmit a nudge through a wall.
	var origin:=player.global_position+Vector3.UP*.35
	var end:=point+(origin-point).normalized()*.003
	var wall_ray:=PhysicsRayQueryParameters3D.create(origin,end,1,[player.get_rid()])
	if not space.intersect_ray(wall_ray).is_empty():return
	_last_attempt_ms=now;_serial+=1;attempts+=1
	var request:Dictionary={"schema":"npc_final_dead_contact/v1","owner_epoch":contract.epoch,"event_id":"player_contact:%d:%d:%d"%[player.get_instance_id(),start.pose_epoch,_serial],"physics_frame":start.frame,"now_ms":now,"actor_instance_id":player.get_instance_id(),"actor_rid":player.get_rid(),"actor_pose_epoch":start.pose_epoch,"actor_start":start.position,"actor_end":player.global_position,"actual_velocity":actor_velocity,"requested_velocity":start.velocity,"collider_instance_id":contact.get("collider_id",0),"collider_rid":contact.rid,"shape_index":contact.get("shape",-1),"world_point":point,"world_normal":normal,"body_velocity":body_velocity,"relative_closing_speed":closing_speed,"contact_height":local_height,"safe_fraction":sweep[0],"unsafe_fraction":sweep[1],"initial_overlap":initial_overlap,"suggested_impulse_ns":-horizontal_normal*minf(cap,closing_speed*gain),"max_impulse_ns":cap,"delivery":"command_unapplied","damage":false}
	var result:Variant=_admit_hook.call(request)
	last_result=result.duplicate(true) if result is Dictionary else {"ok":false,"reason":"invalid_owner_result"}
	if last_result.get("ok",false):accepted+=1
