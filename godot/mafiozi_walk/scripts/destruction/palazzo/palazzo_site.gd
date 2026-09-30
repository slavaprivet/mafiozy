extends "source/showcase.gd"
## Placeable copy of the accepted Palazzo, including its small landscaped site.
## Exact showcase body count, NOT a global-64 pool or a loaded-city performance claim.
## The host owns player, input, camera, environment, terrain and receipt admission.

@export var source_id: String = "palazzo_site_reference_v1"
const RUBBLE_LAYER := 512
const ACTOR_LAYER := 2
const MAX_EVENTS := 1024
var site_ready := false
var site_error := ""
var site_status := "not_ready"
var collapse_stage := -1
var last_explosion: Dictionary = {}
var _events: Dictionary = {}
var _actor_positions: Dictionary = {}
var _owned_bodies: Dictionary = {}
var _door: RigidBody3D
var _door_closed := Transform3D.IDENTITY
var _door_hinge := Vector3.ZERO
var _door_angle := 0.0
var _door_open := false
var _door_tween: Tween
var _door_query: PhysicsShapeQueryParameters3D
var _door_target_open := false
var _collapse_event_id := ""

func _ready() -> void:
	set_process_unhandled_input(false)
	if source_id.is_empty() or source_id.length()>200 or not _rigid_upright():
		site_error="source_id_or_unit_yaw_transform"; set_process(false); set_physics_process(false); return
	rng.seed=7302026
	batched=true
	set_meta("source_id",source_id); set_meta("building_id",source_id)
	_build_site()
	_build_building()
	building.set_meta("source_id",source_id); building.set_meta("building_id",source_id)
	_bind_door()
	_build_dust_pool()
	_build_queries()
	site_ready=true; site_status="intact"

func _rigid_upright() -> bool:
	var basis: Basis=global_transform.basis
	return global_transform.is_finite() and basis.is_equal_approx(basis.orthonormalized()) and absf(basis.determinant()-1.0)<.0001 and basis.y.is_equal_approx(Vector3.UP)

func _build_site() -> void:
	var plaza=static_box(Vector3(22,.24,18),Vector3(0,-.03,0),Color("b8b3a2"))
	plaza.name="OriginalPlaza"
	var foundation=static_box(Vector3(8.5,.22,6.5),Vector3(0,.19,0),Color("d8d0b9"))
	foundation.name="OriginalFoundation"
	for x in [-7.4,7.4]:
		for z in [-5.5,4.7]: _tree(Vector3(x,.1,z))
	for x in [-6.2,6.6]:
		var bench=Node3D.new(); bench.name="OriginalBench"; add_child(bench)
		bench.set_meta("palazzo_bench",true); bench.position=Vector3(x,.15,6.2)
		for z in [-.16,.04,.24]: visual(bench,Vector3(1.7,.10,.15),Vector3(0,.43,z),Color("80634b"))
		for sx in [-.64,.64]: visual(bench,Vector3(.09,.47,.48),Vector3(sx,.22,.02),DARK)
		visual(bench,Vector3(1.7,.34,.10),Vector3(0,.83,-.22),Color("80634b"))
	flash=OmniLight3D.new(); flash.name="OriginalBlastFlash"
	flash.light_color=Color("ffb76b"); flash.light_energy=0; flash.omni_range=12; add_child(flash)

func _tree(at: Vector3) -> void:
	var previous: int=get_child_count()
	super._tree(at)
	get_child(previous).set_meta("palazzo_tree",true)

func piece(label: String,size: Vector3,at: Vector3,color: Color,rotation_y: float=0.0) -> RigidBody3D:
	var body: RigidBody3D=super.piece(label,size,at,color,rotation_y)
	body.set_meta("source_id",source_id); body.set_meta("building_id",source_id)
	body.collision_layer=1; body.collision_mask=1|RUBBLE_LAYER
	_owned_bodies[body.get_instance_id()]=weakref(body)
	return body

func _build_queries() -> void:
	shove_query=PhysicsShapeQueryParameters3D.new(); shove_query.shape=CapsuleShape3D.new(); shove_query.collision_mask=RUBBLE_LAYER
	push_ray=PhysicsRayQueryParameters3D.new(); push_ray.collision_mask=1
	support_query=PhysicsShapeQueryParameters3D.new(); support_query.shape=BoxShape3D.new(); support_query.collision_mask=RUBBLE_LAYER
	_door_query=PhysicsShapeQueryParameters3D.new(); _door_query.collision_mask=ACTOR_LAYER

func owns_collider(body: Variant) -> bool:
	return body is RigidBody3D and is_instance_valid(body) and body.get_parent()==building and _owned_bodies.has(body.get_instance_id()) and body.get_meta("source_id","")==source_id

func _event_available(id: String) -> bool:
	return not id.is_empty() and id.length()<=200 and not _events.has(id) and _events.size()<MAX_EVENTS

func apply_explosion(receipt: Dictionary) -> Dictionary:
	if not site_ready or rebuilding or collapsing: return {"ok":false,"reason":"site_not_available"}
	if receipt.get("admitted")!=true or receipt.get("authority")!="local_preview": return {"ok":false,"reason":"authority"}
	if receipt.get("source_id")!=source_id: return {"ok":false,"reason":"source_id"}
	var id: String=str(receipt.get("event_id",""))
	if not _event_available(id): return {"ok":false,"reason":"duplicate_or_event_budget"}
	if receipt.has("generation") and receipt.generation!=rebuild_generation: return {"ok":false,"reason":"stale_generation"}
	var at: Variant=receipt.get("position"); var direction: Variant=receipt.get("direction")
	var power: Variant=receipt.get("power"); var radius: Variant=receipt.get("radius")
	if not at is Vector3 or not direction is Vector3 or not at.is_finite() or not direction.is_finite() or direction.length_squared()<.000001: return {"ok":false,"reason":"coordinates"}
	if not (power is float or power is int) or not (radius is float or radius is int) or not is_finite(float(power)) or not is_finite(float(radius)) or power<=0 or power>10000 or radius<=0 or radius>3.2: return {"ok":false,"reason":"blast_limits"}
	var target: Variant=receipt.get("collider")
	if target==null and receipt.get("contact") is Dictionary: target=receipt.contact.get("collider")
	if not owns_collider(target) or (target.collision_layer&1)==0 or target.get_meta("detached",false): return {"ok":false,"reason":"owned_intact_collider_required"}
	var size: Vector3=target.get_meta("section_size")
	if not AABB(-size*.5,size).grow(.08).has_point(target.to_local(at)): return {"ok":false,"reason":"contact_outside_collider"}
	explode(at,float(radius),target,bool(receipt.get("passage",false)))
	var result: Dictionary=last_explosion.duplicate()
	result.event_id=id; result.generation=rebuild_generation
	_events[id]=result.duplicate()
	return result

func event_status(event_id: String) -> Dictionary:
	return _events.get(event_id,{"ok":false,"reason":"unknown_event"}).duplicate()

func explode(at: Vector3,radius: float,target: RigidBody3D=null,passage: bool=false) -> void:
	last_explosion={"ok":false,"reason":"site_not_available"}
	if not site_ready or rebuilding or collapsing: return
	var begin: int=Time.get_ticks_usec()
	if target==null:
		var nearest: float=radius
		for body in wall_panels:
			var distance_to_hit: float=body.global_position.distance_to(at)
			if distance_to_hit<nearest: nearest=distance_to_hit; target=body
	if target!=null and target.has_meta("wall_panel"): target=target.get_meta("wall_panel")
	if not owns_collider(target) or not target.freeze:
		last_explosion={"ok":false,"reason":"already_detached_or_foreign"}; return
	blast_serial+=1
	var detached: int=1
	if target.has_meta("fracture_tiles"): detached=_breach_wall(target,at,passage)
	else: _release(target,at,2.2)
	if detached==0: last_explosion={"ok":true,"committed":false,"detached":0,"state":"already_clear"}; return
	_dust(to_local(at)); flash.global_position=at+Vector3.UP; flash.light_energy=3
	site_status="local_breach"; last_blast_cpu_usec=Time.get_ticks_usec()-begin
	last_explosion={"ok":true,"committed":true,"detached":detached,"state":"committed","cpu_usec":last_blast_cpu_usec}

func _breach_wall(body: RigidBody3D,at: Vector3,passage: bool=false) -> int:
	if body==_door: _stop_door()
	var count: int=super._breach_wall(body,at,passage)
	for chunk in body.get_meta("pooled_fragments"):
		if not chunk.get_meta("detached",false): chunk.collision_layer=1; chunk.collision_mask=1|RUBBLE_LAYER
	return count

func _release(body: RigidBody3D,at: Vector3,power: float,exit_direction: Vector3=Vector3.ZERO) -> void:
	if not owns_collider(body): return
	if body==_door: _stop_door()
	var world_exit: Vector3=global_transform.basis*exit_direction if exit_direction!=Vector3.ZERO else Vector3.ZERO
	super._release(body,at,power,world_exit)
	if is_instance_valid(body): body.collision_layer=RUBBLE_LAYER; body.collision_mask=1|RUBBLE_LAYER

func request_full_collapse(event_id: String) -> Dictionary:
	if not site_ready or rebuilding or collapsing: return {"ok":false,"reason":"site_not_available"}
	if not _event_available(event_id): return {"ok":false,"reason":"duplicate_or_event_budget"}
	var result: Dictionary={"ok":true,"started":true,"generation":rebuild_generation,"state":"collapsing"}
	_events[event_id]=result
	_collapse_event_id=event_id
	collapse()
	return result.duplicate()

func collapse() -> void:
	if not site_ready or rebuilding or collapsing: return
	_stop_door(); collapsing=true; collapse_stage=-1
	var generation: int=rebuild_generation
	_dust(Vector3(0,1.1,0)); site_status="collapsing"
	for level in [0,1,2]:
		await get_tree().create_timer(.65).timeout
		if generation!=rebuild_generation or not is_inside_tree(): return
		for body in pieces:
			if body.freeze and not body.get_meta("detached",false) and body.position.y<[2.9,5.6,20.0][level]:
				_release(body,to_global(Vector3(0,-1,0)),1.5 if level<2 else .8)
		collapse_stage=level
		if _events.has(_collapse_event_id): _events[_collapse_event_id].stage=level
		_dust(Vector3(0,1.1+level*1.6,0))
	site_status="all_sections_released"
	if _events.has(_collapse_event_id):
		_events[_collapse_event_id].state="all_sections_released"
		_events[_collapse_event_id].completed=true

func request_reset() -> Dictionary:
	if not site_ready or rebuilding: return {"ok":false,"reason":"site_not_available"}
	reset_building()
	return {"ok":true,"queued":true,"generation":rebuild_generation}

func reset_building() -> void:
	if rebuilding or not site_ready: return
	if _events.has(_collapse_event_id) and _events[_collapse_event_id].state=="collapsing":
		_events[_collapse_event_id].state="cancelled_generation"
		_events[_collapse_event_id].completed=false
	_collapse_event_id=""
	rebuilding=true; rebuild_generation+=1; _stop_door(); collapsing=false; collapse_stage=-1
	rng.seed=7302026; _actor_positions.clear(); _owned_bodies.clear()
	building.queue_free()
	await get_tree().process_frame
	if not is_inside_tree(): return
	_build_building(); building.set_meta("source_id",source_id); building.set_meta("building_id",source_id)
	_bind_door(); rebuilding=false; site_status="intact"
	flash.light_energy=0
	for particles in dust_pool: particles.emitting=false; particles.visible=false

func _wake_debris(body: RigidBody3D) -> void:
	if owns_collider(body): super._wake_debris(body)

func _park_debris(body: RigidBody3D) -> void:
	if owns_collider(body): super._park_debris(body)

func _impact_wake(body: RigidBody3D,velocity: Vector3) -> void:
	if owns_collider(body): super._impact_wake(body,velocity)

func _wake_supported_rubble() -> void:
	for i in range(mini(4,support_wakes.size())):
		var request: Dictionary=support_wakes.pop_front()
		var source: RigidBody3D=request.body
		if not is_instance_valid(source): continue
		support_wake_ids.erase(source.get_instance_id())
		support_query.shape.size=request.size+Vector3(.16,.32,.16)
		support_query.transform=request.transform; support_query.transform.origin.y+=.12
		for hit in get_world_3d().direct_space_state.intersect_shape(support_query,pieces.size()):
			var other=hit.collider as RigidBody3D
			if owns_collider(other) and other!=source and other.get_meta("parked",false) and other.global_position.y>request.transform.origin.y+.08: _wake_debris(other)

func push_from_actor(actor: CharacterBody3D,capsule: CollisionShape3D,delta: float) -> Dictionary:
	if not site_ready or rebuilding or not is_instance_valid(actor) or not is_instance_valid(capsule) or not actor.is_ancestor_of(capsule) or not capsule.shape is CapsuleShape3D or capsule.disabled: return {"ok":false,"reason":"actor_capsule"}
	if (actor.collision_layer&ACTOR_LAYER)==0 or (actor.collision_mask&1)==0 or (actor.collision_mask&RUBBLE_LAYER)!=0: return {"ok":false,"reason":"actor_collision_policy"}
	if not is_finite(delta) or delta<=0: return {"ok":false,"reason":"delta"}
	var actor_id: int=actor.get_instance_id()
	var previous: Vector3=_actor_positions.get(actor_id,actor.global_position)
	if not _actor_positions.has(actor_id) and _actor_positions.size()>=16: return {"ok":false,"reason":"actor_budget"}
	_actor_positions[actor_id]=actor.global_position
	var moved: Vector3=actor.global_position-previous; moved.y=0
	if moved.length_squared()<=.000001 or moved.length()>2: return {"ok":true,"pushed":0}
	var direction: Vector3=(moved/maxf(delta,.001)).limit_length(1.0)
	var native_shape: CapsuleShape3D=capsule.shape
	shove_query.shape.radius=maxf(.52,native_shape.radius+.24)
	shove_query.shape.height=maxf(native_shape.height+.08,shove_query.shape.radius*2)
	shove_query.transform=Transform3D(Basis.IDENTITY,capsule.global_position+direction*.16)
	var pushed: int=0
	for hit in get_world_3d().direct_space_state.intersect_shape(shove_query,24):
		var body=hit.collider as RigidBody3D
		if not owns_collider(body) or not body.get_meta("detached",false): continue
		push_ray.from=capsule.global_position+Vector3.UP*(.7-native_shape.height*.5); push_ray.to=body.global_position
		if not get_world_3d().direct_space_state.intersect_ray(push_ray).is_empty(): continue
		var away: Vector3=body.global_position-actor.global_position; away.y=0
		var wanted: Vector3=direction*2.1+away.normalized()*.9
		var horizontal: Vector3=Vector3(body.linear_velocity.x,0,body.linear_velocity.z)
		_wake_debris(body)
		body.apply_central_impulse((wanted-horizontal).limit_length(3.2)*body.mass*minf(1,delta*12))
		body.set_meta("pushed_by_actor",true); pushed+=1
	return {"ok":true,"pushed":pushed}

func _process(delta: float) -> void:
	if not site_ready: return
	_sync_batches()
	flash.light_energy=maxf(0,flash.light_energy-delta*28)

func _physics_process(_delta: float) -> void:
	if not site_ready or rebuilding: return
	_wake_supported_rubble()
	for id in active_debris.keys():
		var body: RigidBody3D=active_debris[id]
		if body.freeze or body.sleeping: active_debris.erase(id)

func _unhandled_input(_event: InputEvent) -> void:
	pass

func get_stats() -> Dictionary:
	var active: int=0; var detached: int=0; var parked: int=0
	for body in pieces:
		if not is_instance_valid(body): continue
		if body.get_meta("detached",false): detached+=1
		if body.get_meta("parked",false): parked+=1
		if not body.freeze and not body.sleeping: active+=1
	var trees: int=0; var benches: int=0
	for child in get_children():
		if child.get_meta("palazzo_tree",false): trees+=1
		if child.get_meta("palazzo_bench",false): benches+=1
	return {"ok":site_ready,"error":site_error,"source_id":source_id,"generation":rebuild_generation,"rebuilding":rebuilding,"collapsing":collapsing,"collapse_stage":collapse_stage,"status":site_status,"pieces":pieces.size(),"pool":pooled_fragments.size(),"panels":wall_panels.size(),"detached":detached,"active":active,"parked":parked,"trees":trees,"benches":benches,"native_body_cap":657,"active_limit_enforced":false,"loaded_city_performance":"unverified"}

func _bind_door() -> void:
	_door=null; _door_angle=0; _door_open=false; _door_target_open=false
	for body in wall_panels:
		if body.name.begins_with("Entrance"):
			_door=body; _door_closed=body.transform
			_door_hinge=_door_closed.origin-_door_closed.basis.x*float(body.get_meta("section_size").x)*.5
			break

func _door_available() -> bool:
	return site_ready and not rebuilding and not collapsing and is_instance_valid(_door) and not _door.get_meta("detached",false) and not _door.get_meta("fracture_active",false)

func get_door_prompt(actor: Node3D) -> Dictionary:
	if not _door_available() or not is_instance_valid(actor) or not actor.is_inside_tree(): return {"available":false,"reason":"door_or_actor_unavailable"}
	var distance_to_door: float=actor.global_position.distance_to(_door.global_position)
	var busy: bool=is_instance_valid(_door_tween) and _door_tween.is_running()
	return {"available":distance_to_door<=2 and not busy,"distance":distance_to_door,"open":_door_open,"busy":busy,"text":"Закрыть дверь" if _door_open else "Открыть дверь"}

func _door_pose(angle: float) -> Transform3D:
	var rotation:=Basis(Vector3.UP,angle)
	return Transform3D(rotation*_door_closed.basis,_door_hinge+rotation*(_door_closed.origin-_door_hinge))

func _door_pose_clear(pose: Transform3D) -> bool:
	var shape: CollisionShape3D=_door.get_child(0) if _door.get_child(0) is CollisionShape3D else null
	if shape==null:
		for child in _door.get_children():
			if child is CollisionShape3D: shape=child; break
	if shape==null: return false
	_door_query.shape=shape.shape; _door_query.transform=building.global_transform*pose*shape.transform
	return get_world_3d().direct_space_state.intersect_shape(_door_query,1).is_empty()

func interact_door(actor: Node3D) -> Dictionary:
	var prompt: Dictionary=get_door_prompt(actor)
	if not prompt.get("available",false): return {"ok":false,"reason":"door_out_of_reach_busy_or_unavailable"}
	_door_target_open=not _door_open
	var target: float=PI*.5 if _door_target_open else 0.0
	for i in range(1,19):
		if not _door_pose_clear(_door_pose(lerpf(_door_angle,target,float(i)/18.0))): return {"ok":false,"reason":"door_sweep_blocked"}
	_door_tween=create_tween(); _door_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_door_tween.tween_method(_move_door,_door_angle,target,.5)
	_door_tween.finished.connect(_door_finished)
	return {"ok":true,"started":true,"opening":_door_target_open}

func _move_door(angle: float) -> void:
	if not _door_available(): _stop_door(); return
	var pose: Transform3D=_door_pose(angle)
	if not _door_pose_clear(pose):
		_stop_door(); _door_open=_door_angle>.001; site_status="door_motion_blocked"; return
	_door_angle=angle; _door.transform=pose; _queue_render(_door)
	for chunk in _door.get_meta("pooled_fragments"):
		chunk.transform=pose*Transform3D(Basis.IDENTITY,chunk.get_meta("panel_center"))
		initial_transforms[chunk.get_instance_id()]=chunk.global_transform; _queue_render(chunk)

func _door_finished() -> void:
	_door_open=_door_target_open

func _stop_door() -> void:
	if is_instance_valid(_door_tween): _door_tween.kill()
