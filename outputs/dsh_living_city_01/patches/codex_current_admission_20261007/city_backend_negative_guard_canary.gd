extends SceneTree

# Small physics fixture for the shipped backend. No city population or benchmark.
const Backend = preload("res://scripts/city/runtime/npc_city_engine_navigation.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const NavigationHost = preload("res://scripts/city/runtime/npc_city_navigation_host.gd")
var _world: Node3D
var _permission := true
var _checks: Array[Dictionary] = []
var _calls := 0
var _max_x := INF

func _initialize() -> void: call_deferred("_run")
func _space() -> PhysicsDirectSpaceState3D: return _world.get_world_3d().direct_space_state
func _admit(_point: Vector3, _id: String, _generation: int) -> bool:
	_calls+=1; return _permission and _point.x<=_max_x
func _check(ok: bool, name: String, detail: Dictionary={}) -> void:
	_checks.append({"ok":ok,"name":name,"detail":detail})
	if not ok: push_error("BACKEND_GUARD_CANARY " + name)

func _run() -> void:
	_world=Node3D.new(); root.add_child(_world)
	var floor_body:=StaticBody3D.new(); floor_body.collision_layer=1
	var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(20,1,20)
	shape.shape=box; floor_body.add_child(shape); floor_body.position.y=-0.5; _world.add_child(floor_body)
	var map:=NavigationServer3D.map_create(); NavigationServer3D.map_set_active(map,true)
	var mesh:=NavigationMesh.new()
	mesh.set_vertices(PackedVector3Array([Vector3(-10,0,-10),Vector3(10,0,-10),Vector3(10,0,10),Vector3(-10,0,10)]))
	mesh.add_polygon(PackedInt32Array([0,3,2,1]))
	var region:=NavigationServer3D.region_create(); NavigationServer3D.region_set_navigation_mesh(region,mesh)
	NavigationServer3D.region_set_map(region,map)
	for i in range(4): await physics_frame
	var iteration:=NavigationServer3D.map_get_iteration_id(map)
	var queue:=Queue.new()
	var backend:=Backend.new(queue,_space)
	backend._map=map; backend._regions.append(region); backend._state="READY"; backend._epoch=1
	var owner:=Queue.Owner.new("fixture_guard",1)
	var path:=PackedVector3Array([Vector3.ZERO,Vector3(1,0,0),Vector3(2,0,0)])
	_check(backend.request_proven_route(owner,path,_admit,[],map,iteration+1)<0,"changed_map_iteration_rejected")
	_check(backend.request_proven_route(owner,PackedVector3Array([Vector3.ZERO,Vector3(6,0,0)]),_admit,[],map,iteration)<0,"oversized_prefix_leg_rejected")
	var id:=backend.request_proven_route(owner,path,_admit,[],map,iteration)
	_check(id>=0,"valid_prefix_accepted")
	if id>=0:
		_check(backend.request_proven_route(owner,path,_admit,[],map,iteration)<0,"second_current_job_rejected")
		for i in range(6):
			queue.reserve(Engine.get_physics_frames(),owner)
			backend._validate(backend._jobs[id])
			if str(backend._jobs[id].status)=="READY": break
			await physics_frame
		_check(str(backend._jobs[id].status)=="READY","prefix_physically_validated")
		var first:=backend.admit_motion(id,Vector3.ZERO,Vector3(0.05,0,0))
		_check(first,"clear_motion_admitted")
		var before:=_calls
		_permission=false
		var revoked:=backend.admit_motion(id,Vector3(0.05,0,0),Vector3(0.1,0,0))
		_check(not revoked,"current_permission_revocation_denies_next_motion",{"motion_admitted":revoked,"source_calls_before":before,"source_calls_after":_calls,"admit_due":backend._jobs[id].get("admit_due"),"physics_frame":Engine.get_physics_frames()})
		_permission=true; owner.dead=true
		_check(not backend.admit_motion(id,Vector3(0.1,0,0),Vector3(0.15,0,0)),"dead_owner_denies_motion")
		owner.dead=false
		_check(not backend.admit_motion(id,Vector3.ZERO,Vector3(0.3,0,0)),"real_step_over_025_rejected")
		backend._jobs[id].iteration=iteration+1
		_check(not backend.admit_motion(id,Vector3.ZERO,Vector3(0.05,0,0)),"changed_map_denies_existing_motion")
		backend._jobs[id].iteration=iteration
		backend.cancel(id)
		_check(not backend.admit_motion(id,Vector3.ZERO,Vector3(0.05,0,0)),"cancelled_exact_job_denies_motion")
	# Actual mover: accepted source motion must still call move_and_slide; a
	# revoked callback stops its next step instead of merely changing a counter.
	var body:=CharacterBody3D.new(); body.collision_layer=2; body.collision_mask=1
	var capsule:=CapsuleShape3D.new(); capsule.radius=0.36; capsule.height=1.9
	var collider:=CollisionShape3D.new(); collider.shape=capsule; collider.position.y=0.95
	body.add_child(collider); _world.add_child(body)
	await create_timer(0.05).timeout
	iteration=NavigationServer3D.map_get_iteration_id(map)
	var nav:=NavigationHost.new(); nav._queue=queue; nav._backend=backend; nav._root=weakref(_world); nav._geometry_valid=true
	var mover_owner:=Queue.Owner.new("fixture_mover",1)
	var mover:=nav.request_proven_route(mover_owner,body,path,_admit,map,iteration)
	_check(mover>=0,"actual_mover_route_accepted")
	if mover>=0:
		var native_id: int=nav._records[mover].backend_id
		for i in range(6):
			await physics_frame
			queue.reserve(Engine.get_physics_frames(),mover_owner); backend._validate(backend._jobs[native_id])
			if backend._jobs[native_id].status=="READY": break
		var before:=body.position
		var moved: Dictionary=nav.step(mover,1.0/60.0,1.8,9.8)
		moved["fixture_backend_state"]=backend.state(); moved["fixture_map_iteration"]=NavigationServer3D.map_get_iteration_id(map); moved["fixture_job_iteration"]=backend._jobs[native_id].iteration
		_check(float(moved.get("step_metres",0.0))>0.0 and body.position!=before,"positive_real_move_and_slide",moved)
		_permission=false; before=body.position
		var stopped: Dictionary=nav.step(mover,1.0/60.0,1.8,9.8)
		_check(stopped.get("status")=="BLOCKED" and body.position==before,"revocation_stops_actual_body",stopped)
		_permission=true
		nav.cancel(mover)
	# Source a/b and physical sweep remain distinct, and exact operands survive
	# terminal path cleanup. At most 16 failure records may be retained.
	for index in range(20):
		await physics_frame
		_permission=false
		var trace_owner:=Queue.Owner.new("fixture_trace_"+str(index),1)
		var trace_id:=backend.request_proven_route(trace_owner,path,_admit,[],map,NavigationServer3D.map_get_iteration_id(map))
		queue.reserve(Engine.get_physics_frames(),trace_owner); backend._validate(backend._jobs[trace_id])
		if index==0:
			var failure: Dictionary=backend._jobs[trace_id].get("validation_refusal",{})
			_check(failure.get("stage")=="source_a" and failure.get("a")==Vector3.ZERO and failure.get("source_id")==trace_owner.source_id and backend._jobs[trace_id].path.is_empty(),"source_a_operands_saved_before_cleanup",failure)
		backend.cancel(trace_id)
	_check(backend.diagnostics().get("validation_refusals",[]).size()==16,"refusal_history_bounded_16")
	_permission=true; _max_x=0.2
	await physics_frame
	var b_owner:=Queue.Owner.new("fixture_source_b",1)
	var b_id:=backend.request_proven_route(b_owner,path,_admit,[],map,NavigationServer3D.map_get_iteration_id(map))
	queue.reserve(Engine.get_physics_frames(),b_owner); backend._validate(backend._jobs[b_id])
	_check(backend._jobs[b_id].get("validation_refusal",{}).get("stage")=="source_b","source_b_failure_is_distinct")
	backend.cancel(b_id); _max_x=INF
	var wall:=StaticBody3D.new(); wall.collision_layer=1
	var wall_shape:=CollisionShape3D.new(); var wall_box:=BoxShape3D.new(); wall_box.size=Vector3(.2,1.9,.2)
	wall_shape.shape=wall_box; wall.add_child(wall_shape); wall.position=Vector3(.7,.975,0); _world.add_child(wall)
	await physics_frame
	var sweep_owner:=Queue.Owner.new("fixture_sweep",1)
	var sweep_id:=backend.request_proven_route(sweep_owner,path,_admit,[],map,NavigationServer3D.map_get_iteration_id(map))
	queue.reserve(Engine.get_physics_frames(),sweep_owner); backend._validate(backend._jobs[sweep_id])
	_check(backend._jobs[sweep_id].get("validation_refusal",{}).get("stage")=="capsule_sweep","physical_capsule_refusal_is_distinct")
	backend.cancel(sweep_id)
	var clear_job: Dictionary={}
	_check(backend._physics_clear(Vector3(-2,0,0),Vector3(-1.95,0,0),[],clear_job),"initial_clear_start_proved")
	var entering:=StaticBody3D.new(); entering.collision_layer=1
	var entering_shape:=CollisionShape3D.new(); var entering_box:=BoxShape3D.new(); entering_box.size=Vector3(.2,1.9,.2)
	entering_shape.shape=entering_box; entering.add_child(entering_shape); entering.position=Vector3(-1.95,.975,0); _world.add_child(entering)
	await physics_frame
	var overlapped:=backend._physics_clear(Vector3(-1.95,0,0),Vector3(-1.9,0,0),[],clear_job)
	_check(not overlapped,"new_dynamic_start_overlap_rejected",{"motion_admitted":overlapped})
	var ok:=true
	for check: Dictionary in _checks: ok=ok and bool(check.ok)
	var result:={"ok":ok,"checks":_checks,"scope":"actual backend and physics with fixture source callback; no live host/policy or city performance claim"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):
			var out:=arg.trim_prefix("--qa-out="); DirAccess.make_dir_recursive_absolute(out)
			var file:=FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE)
			file.store_string(JSON.stringify(result,"\t")); file.close()
	print("BACKEND_GUARD_CANARY ",JSON.stringify({"ok":ok,"checks":_checks.size()}))
	backend.dispose(); queue.dispose(); _world.queue_free()
	await create_timer(2.0).timeout
	quit(0 if ok else 1)
