extends SceneTree
const Pool=preload("res://scripts/transport/transport_damage_mark_pool.gd")
const Plan=preload("res://scripts/transport/transport_damage_mark_plan.gd")
const Debris=preload("res://scripts/transport/transport_vehicle_debris.gd")
var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var vehicle:=Node3D.new(); world.add_child(vehicle)
	var panel:=MeshInstance3D.new(); vehicle.add_child(panel)
	var box:=BoxMesh.new(); var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
	mesh.surface_set_material(0,StandardMaterial3D.new()); panel.mesh=mesh
	var debris:=Debris.new()
	var configured:=debris.configure(vehicle,world,[{"source":panel,"mass_kg":18.0,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.05}])
	check(configured.ok,"frozen physical debris configured before marks")
	if not configured.ok: finish(); return
	while not debris.stats().ready:
		check(debris.prewarm_step(1).ok,"body and hull prewarm")
		await physics_frame
	var pool:=Pool.new(); var prepared:=pool.configure(vehicle,world,{"actual_panel":panel},1)
	check(prepared.ok,"external pool configured after frozen structural receipt")
	if not prepared.ok: finish(); return
	var receipt:=Plan.plan_collision_round(0,PackedFloat64Array([0,0,.5]),PackedFloat64Array([0,0,1]))
	check(pool.commit(panel,"actual_panel",receipt,1).ok,"mark installed on configured assembly association")
	check(panel.get_child_count()==0,"marker does not become structural child")
	check(pool.snapshot().visible==1,"associated source mark visible before detachment")
	var launched:=debris.launch([{"linear_velocity":Vector3(1,2,0),"angular_velocity":Vector3(.1,0,0)}])
	check(launched.ok,"frozen physical launch accepts unchanged hierarchy")
	check(not panel.visible,"physical detachment hides original panel")
	var reconciled:=pool.reconcile_targets(1)
	check(reconciled.ok and reconciled.visible==0 and pool.snapshot().active==1,"source marks hidden without cloning or deleting content")
	var body:=debris.bodies()[0] as RigidBody3D
	check(body.get_child_count()==2,"debris contains original private visual and collision only")
	check((body.get_child(0) as Node3D).get_child_count()==0,"no marker in private debris copy")
	check(pool.reset(2).ok and pool.snapshot().active==0,"new lifetime clears source associations")
	pool.dispose(); debris.dispose(); world.free(); finish()
func finish() -> void:
	print("TRANSPORT_MARK_POOL_DEBRIS_SEAM ",JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"external markers plus frozen physical launch; no damage authority or material fidelity claim"}))
	quit(0 if failures.is_empty() else 1)
