extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Launch=preload("res://scripts/transport/transport_vehicle_debris_launch.gd")
const Orchestrator=preload("res://scripts/transport/transport_vehicle_damage_orchestrator.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var ground:=StaticBody3D.new(); ground.collision_layer=1; world.add_child(ground)
	var shape:=CollisionShape3D.new(); shape.shape=BoxShape3D.new(); shape.shape.size=Vector3(70,.5,70); shape.position.y=-.25; ground.add_child(shape)
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.ok,"real hatch visual")
	if not loaded.ok: finish({}); return
	var visual: RefCounted=loaded.visual; world.add_child(visual.root); visual.root.position.y=2.5
	var row: Dictionary={}
	for item: Dictionary in Bindings.load_oracle().rows:
		if item.profile_id=="city_hatchback": row=item; break
	var host:=RefCounted.new()
	var physical: Dictionary={"mass_kg":18.0,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08}
	var adapter:=Orchestrator.new(); var memory_before:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var start:=Time.get_ticks_usec(); var setup: Dictionary=adapter.configure(host,"skip-hatch",1,visual,row,world,physical); var configure_us:=Time.get_ticks_usec()-start
	check(setup.ok and setup.source_slots==10 and setup.assemblies==10,"source bound before dynamic skip")
	if not setup.ok: visual.dispose(); finish({"configure_us":configure_us}); return
	var prewarm_max_us:=0; var prewarm_frames:=0
	while not adapter._debris.stats().ready:
		start=Time.get_ticks_usec(); check(adapter.prewarm_step(1).ok,"bounded prewarm"); prewarm_max_us=maxi(prewarm_max_us,Time.get_ticks_usec()-start)
		prewarm_frames+=1; await physics_frame
	var memory_prepared:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var lethal: Dictionary={"authority":host,"vehicle_id":"skip-hatch","life_generation":1,"revision":1,"kind":"rpg","event_id":"event-1","damage":1.0,"prior_hp":240.0,"prior_explosions":0}
	check(adapter.accept(lethal).ok,"authoritative damage receipt")
	var hidden: Node3D=visual.nodes[row.explosion[0].key]; hidden.visible=false
	var transparent:=visual.nodes[row.explosion[4].key] as MeshInstance3D
	check(transparent!=null,"actual hood is direct scalar mesh")
	var material:=StandardMaterial3D.new(); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; transparent.material_override=material
	var ineligible: Node3D=visual.nodes[row.explosion[5].key]; ineligible.set_meta("source_copy_ineligible",true)
	var rows: Array=[]; var draws: Array=[]; var accepted_indices: Array=[]; var expected: Dictionary={}
	for part: Dictionary in row.explosion:
		var index:=int(part.source_index)
		var source: Node3D=visual.nodes[part.key]
		var outcome: String="hidden" if index==0 else "transparent" if index==4 else "ineligible" if index==5 else "copy"
		rows.append({"source_index":index,"source":source,"outcome":outcome})
		if outcome=="copy":
			var group: Dictionary={"source_index":index,"draws":[.5,.5,.5,.5,.5,.5,.5],"signed_speed_mps":index*.25,"travel_yaw_native":index*.09}
			draws.append(group); accepted_indices.append(index)
			expected[index]=Launch.explosion(index,source.global_position-visual.root.global_position,group.signed_speed_mps,group.travel_yaw_native,group.draws)
	var phase: Dictionary={"authority":host,"vehicle_id":"skip-hatch","life_generation":1,"revision":2,"phase":"post_char_callback_glass","char_applied":true,"callback_completed":true,"glass_applied":true,"rows":rows}
	var blast: Dictionary={"authority":host,"vehicle_id":"skip-hatch","life_generation":1,"revision":2,"kind":"step","dt":0.0,"prior_hp":0.0,"prior_explosions":0,"phase_receipt":phase,"draw_groups":draws}
	var altered:=blast.duplicate(true); altered.draw_groups[altered.draw_groups.size()-1].draws[6]=1.0
	check(not adapter.accept(altered).ok and adapter.revision()==1 and adapter.bodies().is_empty(),"late invalid draw rejects entire batch")
	check(rows.slice(1).all(func(item): return item.source.visible),"invalid draw hides no additional source")
	altered=blast.duplicate(true); altered.phase_receipt.callback_completed=false
	check(adapter.accept(altered).get("error")=="phase_authority" and adapter.bodies().is_empty(),"missing completed callback phase fails closed")
	altered=blast.duplicate(true); altered.phase_receipt.authority=RefCounted.new()
	check(adapter.accept(altered).get("error")=="phase_authority","forged phase capability fails closed")
	for skipped_index in [0,4,5]:
		altered=blast.duplicate(true); altered.phase_receipt.rows[skipped_index].outcome="copy"
		check(not adapter.accept(altered).ok and adapter.bodies().is_empty(),"false copy claim rejected at original index "+str(skipped_index))
	altered=blast.duplicate(true); altered.draw_groups.insert(0,{"source_index":0,"draws":[.5,.5,.5,.5,.5,.5,.5],"signed_speed_mps":0.0,"travel_yaw_native":0.0})
	check(not adapter.accept(altered).ok and adapter.bodies().is_empty(),"skipped original index consumes zero draws")
	var launch_positions: Dictionary={}
	for index in accepted_indices: launch_positions[index]=rows[index].source.global_position
	start=Time.get_ticks_usec(); var result: Dictionary=adapter.accept(blast); var launch_us:=Time.get_ticks_usec()-start
	check(result.ok and result.bodies==7 and result.state.explosions==1,"seven accepted roots launch physically")
	var bodies:=adapter.bodies()
	for i in bodies.size():
		var index: int=accepted_indices[i]; var body: RigidBody3D=bodies[i]
		check(body.get_meta("assembly_index")==index and body.linear_velocity.distance_to(expected[index].linear_velocity_mps)<.00001,"original index and per-root motion "+str(index))
		check(not rows[index].source.visible,"only admitted original hidden "+str(index))
	check(not hidden.visible and transparent.visible and ineligible.visible,"all three skipped roots preserve visibility")
	for frame in 120: await physics_frame
	var fallen:=0
	for i in bodies.size():
		if bodies[i].global_position.y<launch_positions[accepted_indices[i]].y: fallen+=1
	check(fallen>=6,"accepted rigid bodies fall")
	var retired: Dictionary=adapter.retire_wreck()
	check(retired.ok and retired.freed_bodies==7 and adapter.bodies().is_empty(),"wreck retirement frees selected bodies only")
	check(not hidden.visible and transparent.visible and ineligible.visible,"retirement keeps skipped roots unchanged")
	var orphans:=0
	for child: Node in world.get_children():
		if child is RigidBody3D: orphans+=1
	check(orphans==0,"no skipped prewarm or launched body orphan")
	var reset_result: Dictionary=adapter.reset_for_respawn()
	check(reset_result.ok and reset_result.restored_originals==7,"respawn restores copied roots only")
	check(not hidden.visible and transparent.visible and ineligible.visible,"retire then respawn preserves all skipped visibility")
	visual.dispose()
	var loaded2:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded2.ok,"second real hatch for direct respawn")
	if loaded2.ok:
		var visual2: RefCounted=loaded2.visual; world.add_child(visual2.root); visual2.root.position=Vector3(15,2.5,0)
		var adapter2:=Orchestrator.new()
		check(adapter2.configure(host,"direct-reset-hatch",1,visual2,row,world,physical).ok,"direct reset source binding")
		while not adapter2._debris.stats().ready:
			adapter2.prewarm_step(10)
			await physics_frame
		var lethal2: Dictionary={"authority":host,"vehicle_id":"direct-reset-hatch","life_generation":1,"revision":1,"kind":"rpg","event_id":"event-2","damage":1.0,"prior_hp":240.0,"prior_explosions":0}
		check(adapter2.accept(lethal2).ok,"second authoritative hit")
		var hidden2: Node3D=visual2.nodes[row.explosion[0].key]; hidden2.visible=false
		var transparent2:=visual2.nodes[row.explosion[4].key] as MeshInstance3D
		var material2:=StandardMaterial3D.new(); material2.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; transparent2.material_override=material2
		var ineligible2: Node3D=visual2.nodes[row.explosion[5].key]; ineligible2.set_meta("source_copy_ineligible",true)
		var rows2: Array=[]
		for part: Dictionary in row.explosion:
			var index:=int(part.source_index)
			rows2.append({"source_index":index,"source":visual2.nodes[part.key],"outcome":"hidden" if index==0 else "transparent" if index==4 else "ineligible" if index==5 else "copy"})
		var phase2: Dictionary={"authority":host,"vehicle_id":"direct-reset-hatch","life_generation":1,"revision":2,"phase":"post_char_callback_glass","char_applied":true,"callback_completed":true,"glass_applied":true,"rows":rows2}
		var blast2: Dictionary={"authority":host,"vehicle_id":"direct-reset-hatch","life_generation":1,"revision":2,"kind":"step","dt":0.0,"prior_hp":0.0,"prior_explosions":0,"phase_receipt":phase2,"draw_groups":draws.duplicate(true)}
		check(adapter2.accept(blast2).ok and adapter2.bodies().size()==7,"direct reset starts with seven launched roots")
		var direct_reset: Dictionary=adapter2.reset_for_respawn()
		check(direct_reset.ok and direct_reset.restored_originals==7 and adapter2.bodies().is_empty(),"direct respawn restores copied roots only")
		check(not hidden2.visible and transparent2.visible and ineligible2.visible,"direct respawn preserves hidden, transparent and ineligible skips")
		var direct_orphans:=0
		for child: Node in world.get_children():
			if child is RigidBody3D: direct_orphans+=1
		check(direct_orphans==0,"direct reset leaves no rigid body orphan")
		visual2.dispose()
	world.free()
	finish({"configure_us":configure_us,"prewarm_frames":prewarm_frames,"prewarm_max_us":prewarm_max_us,"launch_us":launch_us,"memory_before_bytes":memory_before,"memory_prepared_bytes":memory_prepared,"accepted":accepted_indices,"fallen":fallen,"hulls":setup.hulls})
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DAMAGE_DYNAMIC_SKIP ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"real hatch subset + host phase fixture; source callback/current material snapshot not proven; no LIVE"}))
	quit(0 if failures.is_empty() else 1)
