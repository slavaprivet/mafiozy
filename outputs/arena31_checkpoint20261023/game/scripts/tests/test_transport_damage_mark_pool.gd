extends SceneTree

const Pool=preload("res://scripts/transport/transport_damage_mark_pool.gd")
const Plan=preload("res://scripts/transport/transport_damage_mark_plan.gd")
const Pose=preload("res://scripts/transport/transport_source_mark_pose.gd")
const ITERATIONS:=1000

var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var hierarchy:=_hierarchy(); var world: Node3D=hierarchy.world; get_root().add_child(world)
	var vehicle: Node3D=hierarchy.vehicle; var assembly: Node3D=hierarchy.assembly; var target_a: MeshInstance3D=hierarchy.target_a; var target_b: MeshInstance3D=hierarchy.target_b
	var structural_children:=assembly.get_child_count(); var world_children:=world.get_child_count()
	var singular_hierarchy:=_hierarchy(); var singular_world: Node3D=singular_hierarchy.world; get_root().add_child(singular_world); singular_world.scale=Vector3(1,0,1); var singular_pool:=Pool.new()
	check(singular_pool.configure(singular_hierarchy.vehicle,singular_world,{"panel":singular_hierarchy.target_b},1).error=="transform" and singular_world.get_child_count()==1,"singular external parent rejected before pool mutation")
	singular_pool.dispose(); singular_world.free(); check(Pool.MAX_BINDINGS==4096,"target binding preparation is bounded")
	var pool:=Pool.new(); var configure_begin:=Time.get_ticks_usec(); var configured:=pool.configure(vehicle,world,{"panel_a":target_a,"panel_b":target_b},1); var configure_us:=Time.get_ticks_usec()-configure_begin
	check(configured.ok and configured.slots==32 and configured.cursor==0,"configure bounded external pool")
	if not configured.ok: finish({}); world.free(); return
	var effects: Node3D=configured.effects_root
	check(effects.get_parent()==world and not Pool._is_descendant(effects,vehicle) and world.get_child_count()==world_children+1,"effects root is external vehicle sibling")
	check(assembly.get_child_count()==structural_children,"detachable assembly structural count unchanged")
	check(effects.get_child_count()==32 and pool.snapshot().active==0,"32 nodes precreated hidden")
	var mesh_ids: Dictionary={}; var material_ids: Dictionary={}
	for slot in 32:
		var node:=pool.get_slot_node(slot); mesh_ids[node.mesh.get_instance_id()]=true; material_ids[node.mesh.surface_get_material(0).get_instance_id()]=true
	check(mesh_ids.size()==2 and material_ids.size()==2,"two private meshes/materials shared by all slots")
	var point:=PackedFloat64Array([.12,.03,-.08]); var normal:=PackedFloat64Array([.23,.91,-.34]); normal=_normalized(normal)
	var bullet:=Plan.plan_bullet(pool.snapshot().cursor,point,normal,49.0); var bullet_pose:=Pose.compose(bullet.position,bullet.quaternion,bullet.scale)
	var committed:=pool.commit(target_a,"panel_a",bullet,1)
	check(committed.ok and committed.slot==1 and pool.snapshot().cursor==2,"bullet receipt commits physical slot and cursor")
	check(_transform_near(committed.node.global_transform,target_a.global_transform*bullet_pose.native_transform),"target parent times raw local pose exactly once")
	check(pool.commit(target_a,"panel_a",bullet,1).error=="cursor" and pool.snapshot().cursor==2,"stale receipt cannot advance cursor")
	var pending:=Plan.plan_bullet(pool.snapshot().cursor,point,normal,25.0); var malformed:=pending.duplicate(true); malformed.scale=PackedFloat64Array([0,1,1])
	check(pool.commit(target_a,"panel_a",malformed,1).error=="pose_scale" and pool.snapshot().cursor==2,"failed pose install is cursor-atomic")
	check(pool.commit(target_b,"panel_a",pending,1).error=="target" and pool.snapshot().cursor==2,"source identity binding is host-authoritative")
	var tangent:=_normalized(PackedFloat64Array([-.17,.93,.34])); var scratch:=Plan.plan_collision_scratch(pool.snapshot().cursor,point,normal,tangent,10.0,4.5); var scratch_pose:=Pose.compose(scratch.position,scratch.quaternion,scratch.scale)
	check(absf(_length(scratch.quaternion)-1.0)>.001,"scratch receipt retains raw nonunit quaternion")
	var scratch_commit:=pool.commit(target_a,"panel_a",scratch,1)
	check(scratch_commit.ok and scratch_commit.slot==3 and _transform_near(scratch_commit.node.global_transform,target_a.global_transform*scratch_pose.native_transform),"raw scratch shear installed without decomposition")
	var round:=Plan.plan_collision_round(pool.snapshot().cursor,point,normal); var round_pose:=Pose.compose(round.position,round.quaternion,round.scale); var round_commit:=pool.commit(target_b,"panel_b",round,1)
	check(round_commit.ok and round_commit.slot==4 and pool.snapshot().active==3,"second target collision round committed")
	vehicle.transform=Transform3D(Basis.from_euler(Vector3(.04,.79,-.11)).scaled(Vector3(.97,1.13,.92)),Vector3(2.1,.35,-1.4))
	var followed:=pool.reconcile_targets(1)
	check(followed.ok and _transform_near(pool.get_slot_node(1).global_transform,target_a.global_transform*bullet_pose.native_transform) and _transform_near(pool.get_slot_node(3).global_transform,target_a.global_transform*scratch_pose.native_transform) and _transform_near(pool.get_slot_node(4).global_transform,target_b.global_transform*round_pose.native_transform),"external marks follow moving targets from stored raw local poses")
	var ids_after: Dictionary={}; var materials_after: Dictionary={}
	for slot in 32:
		var node:=pool.get_slot_node(slot); ids_after[node.mesh.get_instance_id()]=true; materials_after[node.mesh.surface_get_material(0).get_instance_id()]=true
	check(ids_after==mesh_ids and materials_after==material_ids,"impacts allocate no mesh/material resources")
	target_a.visible=false; var hidden:=pool.reconcile_targets(1)
	check(hidden.ok and hidden.visible==1 and not pool.get_slot_node(1).visible and not pool.get_slot_node(3).visible and pool.get_slot_node(4).visible,"hidden target hides all associated marks only")
	target_a.visible=true; check(pool.reconcile_targets(1).visible==3,"visible target restores persistent marks")
	vehicle.remove_child(assembly); world.add_child(assembly); var detached:=pool.reconcile_targets(1)
	check(detached.visible==1 and not pool.get_slot_node(1).visible and not pool.get_slot_node(3).visible,"detached target marks hidden outside authority root")
	var cursor_before: int=pool.snapshot().cursor
	check(pool.commit(target_a,"panel_a",Plan.plan_bullet(cursor_before,point,normal,9.0),1).error=="target_state" and pool.snapshot().cursor==cursor_before,"detached target cannot consume cursor")
	world.remove_child(assembly); vehicle.add_child(assembly); check(pool.reconcile_targets(1).visible==3,"reattached bound target can reconcile")
	target_a.free(); var freed:=pool.reconcile_targets(1)
	check(freed.ok and freed.visible==1,"freed target weak binding hides all marks safely")
	check(pool.reset(2).ok and pool.snapshot().cursor==0 and pool.snapshot().active==0 and pool.snapshot().visible==0,"reset clears visibility, receipts and cursor")
	check(pool.commit(target_b,"panel_b",Plan.plan_bullet(0,point,normal,9.0),1).error=="generation","stale generation rejected after reset")
	check(pool.reset(2).error=="generation","reset generation is monotonic")
	check(assembly.get_child_count()==structural_children-1,"pool never added children to detachable assembly")
	check(pool.reset(3).ok,"benchmark reset")
	var begin:=Time.get_ticks_usec(); var checksum:=0
	for i in ITERATIONS:
		var receipt:=Plan.plan_bullet(pool.snapshot().cursor,point,normal,24.0); var result:=pool.commit(target_b,"panel_b",receipt,3); checksum+=int(result.slot)
	var elapsed:=Time.get_ticks_usec()-begin
	check(pool.snapshot().active<=32 and pool.snapshot().cursor>=ITERATIONS and checksum>0,"bounded pool survives repeated wrap without TTL deletion")
	var reconcile_begin:=Time.get_ticks_usec(); var reconciled:=0
	for i in ITERATIONS:
		target_b.position.x+=.00001; reconciled+=int(pool.reconcile_targets(3).visible)
	var reconcile_elapsed:=Time.get_ticks_usec()-reconcile_begin
	check(reconciled>0,"bounded active-target reconciliation consumed")
	pool.get_slot_node(7).material_override=StandardMaterial3D.new(); check(pool.reconcile_targets(3).error=="slot_state","external material override fails closed"); pool.get_slot_node(7).material_override=null
	effects.visible=false; check(pool.snapshot().error=="external_root","externally hidden effects root cannot overstate snapshot visibility"); effects.visible=true
	pool.get_slot_node(7).queue_free(); check(pool.reconcile_targets(3).error=="slot_state","externally queued slot fails closed before reconciliation mutation"); pool.get_slot_node(7).cancel_free()
	pool.get_slot_node(0).mesh.surface_get_material(0).roughness=.123; check(pool.reconcile_targets(3).error=="slot_state","in-place prepared resource mutation fails closed")
	var retained_material: Material=pool.get_slot_node(0).mesh.surface_get_material(0); var resource_callback:=Callable(pool,"_on_prepared_resource_changed"); check(retained_material.changed.is_connected(resource_callback),"prepared resource integrity signal connected")
	var effects_id:=effects.get_instance_id(); pool.dispose()
	check(not retained_material.changed.is_connected(resource_callback),"dispose disconnects externally retained resources")
	retained_material.set_meta("post_dispose_probe",true)
	check(not is_instance_id_valid(effects_id) and pool.snapshot().error=="lifetime","dispose removes external nodes and invalidates lifecycle")
	world.free()
	finish({"iterations":ITERATIONS,"configure_us":configure_us,"benchmark_us":elapsed,"us_per_plan_commit":float(elapsed)/ITERATIONS,"reconcile_benchmark_us":reconcile_elapsed,"us_per_reconcile_32":float(reconcile_elapsed)/ITERATIONS,"checksum":checksum,"slots":32,"mesh_resources":2,"material_resources":2})

func _hierarchy() -> Dictionary:
	var world:=Node3D.new(); world.name="External_world"; world.transform=Transform3D(Basis.from_euler(Vector3(.13,-.22,.07)).scaled(Vector3(1.08,.94,1.03)),Vector3(3,.4,-2))
	var vehicle:=Node3D.new(); vehicle.name="Actual_vehicle_root"; vehicle.transform=Transform3D(Basis.from_euler(Vector3(-.08,.61,.12)).scaled(Vector3(1.12,.91,1.06)),Vector3(1.4,.2,-.9)); world.add_child(vehicle)
	var assembly:=Node3D.new(); assembly.name="Detachable_door_assembly"; assembly.transform=Transform3D(Basis.from_euler(Vector3(.17,-.31,.09)).scaled(Vector3(.88,1.14,.96)),Vector3(.72,.55,.18)); vehicle.add_child(assembly)
	var target_a:=MeshInstance3D.new(); target_a.name="Actual_source_panel_A"; target_a.mesh=BoxMesh.new(); target_a.transform=Transform3D(Basis.from_euler(Vector3(.11,.24,-.18)).scaled(Vector3(1.04,.87,1.09)),Vector3(.13,.08,-.04)); assembly.add_child(target_a)
	var target_b:=MeshInstance3D.new(); target_b.name="Actual_source_panel_B"; target_b.mesh=BoxMesh.new(); target_b.transform=Transform3D(Basis.from_euler(Vector3(-.05,-.19,.14)).scaled(Vector3(.93,1.07,.89)),Vector3(-.42,.61,.25)); vehicle.add_child(target_b)
	return {"world":world,"vehicle":vehicle,"assembly":assembly,"target_a":target_a,"target_b":target_b}

func _normalized(values: PackedFloat64Array) -> PackedFloat64Array:
	var length:=_length(values); return PackedFloat64Array([values[0]/length,values[1]/length,values[2]/length])
func _length(values: PackedFloat64Array) -> float: return sqrt(values[0]*values[0]+values[1]*values[1]+values[2]*values[2])
func _transform_near(actual: Transform3D,expected: Transform3D) -> bool:
	return actual.origin.is_equal_approx(expected.origin) and actual.basis.x.is_equal_approx(expected.basis.x) and actual.basis.y.is_equal_approx(expected.basis.y) and actual.basis.z.is_equal_approx(expected.basis.z)
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DAMAGE_MARK_POOL "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"bounded external 32-node runtime; host owns target bindings, hit authority and planner inputs"}))
	quit(0 if failures.is_empty() else 1)
