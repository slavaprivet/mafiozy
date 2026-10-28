extends SceneTree

const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Candidate=preload("res://scripts/transport/candidates/transport_vehicle_debris_static_settle.gd")
const SAMPLE_FRAMES:=120
var checks:=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var count:=int(OS.get_environment("DEBRIS_STATIC_COUNT")); if count==0: count=1
	check(count in [1,3,10],"provider count")
	if not failures.is_empty(): finish({}); return
	var world:=Node3D.new(); root.add_child(world); var ground:=StaticBody3D.new(); ground.collision_layer=1; world.add_child(ground)
	var ground_collision:=CollisionShape3D.new(); var ground_shape:=BoxShape3D.new(); ground_shape.size=Vector3(180,.5,180); ground_collision.shape=ground_shape; ground_collision.position.y=-.25; ground.add_child(ground_collision)
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json"); var visuals: Array=[]; var helpers: Array=[]; var configure_us: Array=[]
	await process_frame; var memory_before:=int(Performance.get_monitor(Performance.MEMORY_STATIC))
	for index in count:
		var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path); check(loaded.get("ok",false),"actual hatch "+str(index))
		if not loaded.get("ok",false): finish({}); return
		var visual=loaded.visual; visuals.append(visual); world.add_child(visual.root); visual.root.global_position=Vector3((index%5)*14,2.5,(index/5)*14)
		var helper:=Candidate.new(); var at:=Time.get_ticks_usec(); var configured: Dictionary=helper.configure(visual.root,world,_rows(_sources(visual))); configure_us.append(Time.get_ticks_usec()-at)
		check(configured.get("ok",false) and configured.get("assemblies",0)==10 and configured.get("hulls",0)==76,"configure exact10/76 "+str(index)); helpers.append(helper)
	await process_frame; await process_frame
	var configured_memory:=int(Performance.get_monitor(Performance.MEMORY_STATIC))-memory_before
	await _ready(helpers)
	for helper in helpers: check(helper.launch(_motions()).get("ok",false),"launch")
	var awake:=await _physics_samples(SAMPLE_FRAMES); var settle_frames:=SAMPLE_FRAMES
	while _sleeping(helpers)<count*10 and settle_frames<1200: await physics_frame; settle_frames+=1
	check(_sleeping(helpers)==count*10,"all bodies naturally sleeping")
	var sleeping:=await _physics_samples(SAMPLE_FRAMES); var before_static_memory:=int(Performance.get_monitor(Performance.MEMORY_STATIC)); var positions: Array=[]
	for helper in helpers:
		for body: RigidBody3D in helper.bodies(): positions.append(body.global_transform)
		var frozen: Dictionary=helper.freeze_settled_static(); check(frozen.get("ok",false) and frozen.get("bodies",0)==10 and frozen.get("hulls",0)==76,"atomic static settle")
	await physics_frame
	var static_memory_delta:=int(Performance.get_monitor(Performance.MEMORY_STATIC))-before_static_memory; var frozen_samples:=await _physics_samples(SAMPLE_FRAMES)
	var transform_index:=0; var transforms_stable:=true
	for helper in helpers:
		check(helper.static_receipt().get("ok",false),"static receipt")
		for body: RigidBody3D in helper.bodies():
			body.apply_impulse(Vector3(8,4,-3)); transforms_stable=transforms_stable and body.global_transform.is_equal_approx(positions[transform_index]); transform_index+=1
	await physics_frame
	transform_index=0
	for helper in helpers:
		for body: RigidBody3D in helper.bodies(): transforms_stable=transforms_stable and body.global_transform.is_equal_approx(positions[transform_index]); transform_index+=1
	check(transforms_stable,"static settled bodies remain fixed under impulse")
	var hit_proof:=_query_proof(world,helpers[0]); check(hit_proof.ray and hit_proof.shape,"static wreck remains ray/shape queryable")
	var visible_meshes:=0
	for helper in helpers:
		for entry: Dictionary in helper._entries:
			if entry.template.visible and entry.template.is_visible_in_tree(): visible_meshes+=_mesh_count(entry.template)
	check(visible_meshes==count*76,"all private visual meshes remain visible")
	if count==1: await _lifecycle(helpers[0],visuals[0])
	finish({"providers":count,"bodies":count*10,"hulls":count*76,"configure_us":configure_us,"configure_total_us":_sum(configure_us),"configured_memory_static_delta":configured_memory,"static_transition_memory_delta":static_memory_delta,"settle_frames":settle_frames,"awake_physics_ms":_distribution(awake),"sleeping_physics_ms":_distribution(sleeping),"frozen_static_physics_ms":_distribution(frozen_samples),"ray_shape":hit_proof,"visible_private_meshes":visible_meshes})
	for helper in helpers:
		if not helper._disposed: helper.reset(); helper.dispose()
	for visual in visuals: visual.dispose()

func _lifecycle(helper: RefCounted,visual: RefCounted) -> void:
	helper.reset(); check(helper.stats().bodies==0 and not helper.stats().static_settled and _sources(visual).all(func(source): return source.visible),"reset restores originals and clears static state")
	check(helper.launch(_motions()).get("ok",false),"relaunch after reset")
	var frames:=0
	while helper.stats().sleeping<10 and frames<900: await physics_frame; frames+=1
	check(helper.stats().sleeping==10 and helper.freeze_settled_static().get("ok",false),"relaunch naturally settles and freezes")
	var retired: Dictionary=helper.retire_wreck(); check(retired.get("ok",false) and retired.get("freed_bodies",0)==10 and helper.bodies().is_empty(),"retire frees static wreck bodies")
	check(_sources(visual).all(func(source): return not source.visible),"retire leaves stripped originals hidden")

func _query_proof(world: Node3D,helper: RefCounted) -> Dictionary:
	var entry: Dictionary=helper._entries[0]; var body:=entry.body as RigidBody3D; var point: Vector3=body.global_transform*entry.hulls[0].points[0]; var space:=world.get_world_3d().direct_space_state
	var ray:=PhysicsRayQueryParameters3D.create(body.global_position,point+(point-body.global_position).normalized()*.25,8); ray.hit_from_inside=true
	var ray_hit: Dictionary=space.intersect_ray(ray)
	var sphere:=SphereShape3D.new(); sphere.radius=.08; var query:=PhysicsShapeQueryParameters3D.new(); query.shape=sphere; query.transform=Transform3D(Basis.IDENTITY,point); query.collision_mask=8; query.collide_with_bodies=true
	var shape_hits:=space.intersect_shape(query,8)
	return {"ray":not ray_hit.is_empty() and ray_hit.collider is RigidBody3D,"shape":shape_hits.any(func(hit): return hit.collider is RigidBody3D),"ray_collider_id":ray_hit.collider_id if not ray_hit.is_empty() else 0,"shape_hits":shape_hits.size()}

func _ready(helpers: Array) -> void:
	while helpers.any(func(helper): return not helper.stats().ready):
		for helper in helpers:
			if not helper.stats().ready: check(helper.prewarm_step(10).get("ok",false),"prewarm")
		await physics_frame

func _sleeping(helpers: Array) -> int:
	var result:=0
	for helper in helpers: result+=int(helper.stats().sleeping)
	return result

func _physics_samples(frames: int) -> Array:
	var result: Array=[]
	for index in frames:
		await physics_frame; result.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0)
	return result

func _mesh_count(node: Node3D) -> int:
	var result:=1 if node is MeshInstance3D and node.mesh!=null else 0
	for child in node.get_children():
		if child is Node3D: result+=_mesh_count(child)
	return result

func _sources(visual: RefCounted) -> Array:
	var result: Array=[]
	for id in ["front_left","rear_left","front_right","rear_right"]: result.append(visual.doors[id])
	for source_name in ["Hood_lid","Trunk_lid"]:
		for node in visual.nodes.values():
			if node.get_meta("source_name","")==source_name: result.append(node); break
	for id in ["front_left","front_right","rear_left","rear_right"]: result.append(visual.wheels[id].pivot)
	return result

func _rows(sources: Array) -> Array:
	var result: Array=[]
	for i in sources.size(): result.append({"source":sources[i],"mass_kg":18.0+i,"collision_layer":8,"collision_mask":3,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08})
	return result

func _motions() -> Array:
	var result: Array=[]
	for i in 10: result.append({"linear_velocity":Vector3(i*.12,2.0+i*.05,-1),"angular_velocity":Vector3(.2,i*.08,-.3)})
	return result

func _sum(values: Array) -> int:
	var result:=0
	for value in values: result+=int(value)
	return result

func _distribution(values: Array) -> Dictionary:
	var sorted:=values.duplicate(); sorted.sort(); var count:=sorted.size()
	return {"count":count,"p50":(float(sorted[count/2-1])+float(sorted[count/2]))*.5,"p95":sorted[mini(count-1,int(ceil(count*.95))-1)],"max":sorted[-1]}

func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_VEHICLE_DEBRIS_STATIC_SETTLE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"isolated actual-hatch post-natural-sleep static wreck; no source/production/GPU/FPS/adoption"}))
	quit(1 if not failures.is_empty() else 0)
