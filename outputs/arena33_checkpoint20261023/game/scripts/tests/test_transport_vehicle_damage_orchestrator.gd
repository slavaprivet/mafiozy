extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Orchestrator=preload("res://scripts/transport/transport_vehicle_damage_orchestrator.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var floor_body:=StaticBody3D.new(); floor_body.collision_layer=1; world.add_child(floor_body)
	var floor_shape:=CollisionShape3D.new(); floor_shape.shape=BoxShape3D.new(); floor_shape.shape.size=Vector3(60,.5,60); floor_shape.position.y=-.25; floor_body.add_child(floor_shape)
	var catalog:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalog.entries.city_hatchback,catalog.base_path)
	check(loaded.ok,"real hatch import")
	if not loaded.ok: finish({}); return
	var visual: RefCounted=loaded.visual; world.add_child(visual.root); visual.root.position.y=2.5
	var row: Dictionary={}
	for item: Dictionary in Bindings.load_oracle().rows:
		if item.profile_id=="city_hatchback": row=item; break
	var host:=RefCounted.new(); var wrong_host:=RefCounted.new()
	var physical: Dictionary={"mass_kg":18.0,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08}
	var orchestrator:=Orchestrator.new()
	var start:=Time.get_ticks_usec()
	var setup: Dictionary=orchestrator.configure(host,"hatch-1",1,visual,row,world,physical)
	var configure_us:=Time.get_ticks_usec()-start
	check(setup.ok and setup.assemblies==10,"bound source order and physical provider "+str(setup))
	if not setup.ok: visual.dispose(); finish({"configure_us":configure_us}); return
	var receipt: Dictionary={"authority":host,"vehicle_id":"hatch-1","life_generation":1,"revision":1,"kind":"collision","event_id":"contact-1","impact_mps":50.0,"prior_hp":240.0,"prior_explosions":0}
	var forged:=receipt.duplicate(); forged.authority=wrong_host
	check(not orchestrator.accept(forged).ok and orchestrator.revision()==0,"missing host authority fails closed")
	forged=receipt.duplicate(); forged.life_generation=2
	check(not orchestrator.accept(forged).ok,"stale lifetime fails closed")
	var collision:=orchestrator.accept(receipt)
	check(collision.ok and collision.state.hp==160.0 and not collision.state.destroying and collision.state.explosions==0,"crash HP without automatic explosion")
	check(not orchestrator.accept(receipt).ok,"replay revision fails closed")
	var repeated_contact:=receipt.duplicate(); repeated_contact.revision=2; repeated_contact.prior_hp=160.0
	check(not orchestrator.accept(repeated_contact).ok and orchestrator.state().hp==160.0,"same contact cannot bypass replay with new revision")
	var early_rpg: Dictionary={"authority":host,"vehicle_id":"hatch-1","life_generation":1,"revision":2,"kind":"rpg","event_id":"early","damage":1.0,"prior_hp":160.0,"prior_explosions":0}
	check(orchestrator.accept(early_rpg).ok,"authenticated lethal damage before prewarm")
	var pending: Dictionary={"authority":host,"vehicle_id":"hatch-1","life_generation":1,"revision":3,"kind":"step","dt":0.0,"prior_hp":0.0,"prior_explosions":0,"phase_receipt":_phase(host,"hatch-1",3,visual,row),"draw_groups":[]}
	for item: Dictionary in row.explosion: pending.draw_groups.append(_draw(item.source_index,3.0,.4))
	check(orchestrator.accept(pending).get("error")=="PREWARM_PENDING" and orchestrator.revision()==2 and orchestrator.bodies().is_empty(),"blast held until physical bodies prewarmed")
	var prewarm_us: Array[int]=[]
	while not orchestrator._debris.stats().ready:
		start=Time.get_ticks_usec(); var warmed: Dictionary=orchestrator.prewarm_step(1); prewarm_us.append(Time.get_ticks_usec()-start)
		check(warmed.ok,"prewarm step")
		await physics_frame
	var step: Dictionary=pending
	var bad:=step.duplicate(true); bad.draw_groups[4].draws[6]=1.0
	check(not orchestrator.accept(bad).ok and orchestrator.revision()==2 and orchestrator.bodies().is_empty(),"invalid late RNG validates before any source mutation")
	bad=step.duplicate(true); bad.draw_groups[3].source_index=4
	check(not orchestrator.accept(bad).ok and orchestrator.bodies().is_empty(),"original index ordering enforced")
	var before_positions: Array=[]
	for item: Dictionary in row.explosion: before_positions.append(visual.nodes[item.key].global_position)
	start=Time.get_ticks_usec(); var blast:=orchestrator.accept(step); var blast_us:=Time.get_ticks_usec()-start
	check(blast.ok and blast.launched and blast.state.wrecked and blast.state.explosions==1 and blast.bodies==10,"one explosion edge launches ten")
	check(not orchestrator.accept(step).ok,"explosion replay denied")
	var bodies:=orchestrator.bodies()
	for i in bodies.size():
		var body: RigidBody3D=bodies[i]
		check(body.get_meta("assembly_index")==i and body.linear_velocity.is_finite() and not visual.nodes[row.explosion[i].key].visible,"exact source index and hidden original "+str(i))
	for frame in 120: await physics_frame
	var fallen:=0
	for i in bodies.size():
		if bodies[i].global_position.y<before_positions[i].y: fallen+=1
	check(fallen>=8,"real gravity moves launched rigid bodies down")
	var count_before: int=orchestrator.state().explosions
	var later:=step.duplicate(true); later.revision=4; later.prior_explosions=1; later.erase("draw_groups")
	check(orchestrator.accept(later).ok and orchestrator.state().explosions==count_before,"no second blast")
	check(not orchestrator.dispose().ok and orchestrator.bodies().size()==10,"generic dispose refuses launched wreck")
	var retired: Dictionary=orchestrator.retire_wreck()
	check(retired.ok and retired.hidden_originals==10 and retired.freed_bodies==10,"wreck cleanup frees copies but keeps originals hidden")
	check(not orchestrator.retire_wreck().ok and orchestrator.bodies().is_empty(),"repeat wreck cleanup idempotent")
	var orphan_count:=0
	for child: Node in world.get_children():
		if child is RigidBody3D: orphan_count+=1
	check(orphan_count==0 and row.explosion.all(func(item): return not visual.nodes[item.key].visible),"no orphan rigid bodies or silent source repair")
	check(orchestrator.reset_for_respawn().ok and row.explosion.all(func(item): return visual.nodes[item.key].visible),"explicit respawn restores originals after wreck cleanup")
	visual.dispose()
	# Keep the ArrayMesh resource identity while replacing positions. This is the
	# stale-hull case the explicit deformation hook must retire permanently.
	var loaded2:=Visual.instantiate_visual(catalog.entries.city_hatchback,catalog.base_path)
	check(loaded2.ok,"second actual hatch for in-place geometry invalidation")
	if loaded2.ok:
		var visual2: RefCounted=loaded2.visual; world.add_child(visual2.root); visual2.root.position=Vector3(12,2.5,0)
		var adapter2:=Orchestrator.new()
		check(adapter2.configure(host,"hatch-2",1,visual2,row,world,physical).ok,"second physical provider configured")
		while not adapter2._debris.stats().ready:
			adapter2.prewarm_step(10)
			await physics_frame
		var lethal: Dictionary={"authority":host,"vehicle_id":"hatch-2","life_generation":1,"revision":1,"kind":"rpg","event_id":"rpg-2","damage":1.0,"prior_hp":240.0,"prior_explosions":0}
		check(adapter2.accept(lethal).ok,"second vehicle lethal receipt")
		var source: Node3D=visual2.nodes[row.explosion[0].key]
		var stack: Array[Node]=[source]; var mesh_node: MeshInstance3D
		while not stack.is_empty():
			var node: Node=stack.pop_back()
			if node is MeshInstance3D and node.mesh is ArrayMesh:
				mesh_node=node; break
			for child: Node in node.get_children(): stack.append(child)
		check(mesh_node!=null,"real mutable source mesh found")
		if mesh_node!=null:
			var mesh: ArrayMesh=mesh_node.mesh
			var mesh_identity:=mesh
			var arrays: Array=mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			vertices[0].x+=.125; arrays[Mesh.ARRAY_VERTEX]=vertices
			var material:=mesh.surface_get_material(0); var surface_name:=mesh.surface_get_name(0)
			check(adapter2.invalidate_geometry().ok,"host deformation hook retires prepared hulls")
			mesh.surface_remove(0); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); mesh.surface_set_material(mesh.get_surface_count()-1,material); mesh.surface_set_name(mesh.get_surface_count()-1,surface_name)
			check(mesh_node.mesh==mesh_identity and not adapter2.prewarm_step().ok,"same mesh identity changed; stale prewarm denied")
			var invalid_blast: Dictionary={"authority":host,"vehicle_id":"hatch-2","life_generation":1,"revision":2,"kind":"step","dt":0.0,"prior_hp":0.0,"prior_explosions":0,"phase_receipt":_phase(host,"hatch-2",2,visual2,row),"draw_groups":[]}
			for part: Dictionary in row.explosion: invalid_blast.draw_groups.append(_draw(part.source_index))
			check(adapter2.accept(invalid_blast).get("error")=="GEOMETRY_INVALIDATED" and adapter2.revision()==1 and adapter2.bodies().is_empty() and source.visible,"stale hull cannot launch after in-place vertex change")
		adapter2.dispose(); visual2.dispose()
	var loaded3:=Visual.instantiate_visual(catalog.entries.city_hatchback,catalog.base_path)
	check(loaded3.ok,"third actual hatch for direct launched respawn")
	if loaded3.ok:
		var visual3: RefCounted=loaded3.visual; world.add_child(visual3.root); visual3.root.position=Vector3(24,2.5,0)
		var adapter3:=Orchestrator.new()
		check(adapter3.configure(host,"hatch-3",1,visual3,row,world,physical).ok,"direct respawn provider configured")
		while not adapter3._debris.stats().ready:
			adapter3.prewarm_step(10)
			await physics_frame
		var hit3: Dictionary={"authority":host,"vehicle_id":"hatch-3","life_generation":1,"revision":1,"kind":"rpg","event_id":"rpg-3","damage":1.0,"prior_hp":240.0,"prior_explosions":0}
		check(adapter3.accept(hit3).ok,"direct respawn lethal receipt")
		var blast3: Dictionary={"authority":host,"vehicle_id":"hatch-3","life_generation":1,"revision":2,"kind":"step","dt":0.0,"prior_hp":0.0,"prior_explosions":0,"phase_receipt":_phase(host,"hatch-3",2,visual3,row),"draw_groups":[]}
		for part: Dictionary in row.explosion: blast3.draw_groups.append(_draw(part.source_index))
		check(adapter3.accept(blast3).ok and adapter3.bodies().size()==10,"direct respawn starts from launched wreck")
		check(adapter3.reset_for_respawn().ok and adapter3.bodies().is_empty() and row.explosion.all(func(item): return visual3.nodes[item.key].visible),"direct source onReset restores originals and frees bodies")
		visual3.dispose()
	finish({"configure_us":configure_us,"prewarm_step_max_us":prewarm_us.max(),"blast_us":blast_us,"fallen":fallen,"assemblies":setup.assemblies,"hulls":setup.hulls,"vertices":setup.vertices})
func _draw(index: int,speed: float=0.0,yaw: float=0.0) -> Dictionary:
	return {"source_index":index,"draws":[.5,.5,.5,.5,.5,.5,.5],"signed_speed_mps":speed,"travel_yaw_native":yaw}
func _phase(authority: RefCounted,vehicle_id: String,revision: int,visual: RefCounted,row: Dictionary) -> Dictionary:
	var rows: Array=[]
	for part: Dictionary in row.explosion: rows.append({"source_index":part.source_index,"source":visual.nodes[part.key],"outcome":"copy"})
	# Fixture host receipt only; production must derive this after actual char,
	# callback and glass phases, including current recursive source material state.
	return {"authority":authority,"vehicle_id":vehicle_id,"life_generation":1,"revision":revision,"phase":"post_char_callback_glass","char_applied":true,"callback_completed":true,"glass_applied":true,"rows":rows}
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DAMAGE_ORCHESTRATOR ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"real hatch Godot headless; isolated host capability receipts, no LIVE/full-city FPS"}))
	quit(0 if failures.is_empty() else 1)
