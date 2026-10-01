extends SceneTree
## ENGINE HOLD: prepared component fixture, not yet parsed or executed.
## Install overlay in a separate game copy; leave frozen40 and open game intact.
## Calls the real site/glass lifecycle. Bullet admission is explicitly synthetic.
const Site = preload("res://scripts/destruction/palazzo/palazzo_structural_site.gd")

class CapsuleWalker extends CharacterBody3D:
	var command := Vector3.ZERO
	var contacts: Array[int] = []
	func _physics_process(_delta: float) -> void:
		velocity=command
		move_and_slide()
		for i in get_slide_collision_count():
			var collider: Object=get_slide_collision(i).get_collider()
			if is_instance_valid(collider) and not contacts.has(collider.get_instance_id()): contacts.append(collider.get_instance_id())

var world: Node3D
var site: Node3D
var checks := 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var output := "res://tests/glazing_lifecycle43_result.json"
var finished := false
var serial := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label); print("GLAZING43 FAIL ",label)
	return value

func step(count: int=1) -> void:
	for i in count:
		await physics_frame
		await process_frame

func row_for(wall: RigidBody3D) -> Dictionary:
	for row: Dictionary in site._glazing._panes.values():
		if row.wall.get_ref()==wall: return row
	return {}

func side_panel() -> RigidBody3D:
	for wall: RigidBody3D in site.wall_panels:
		if str(wall.name).begins_with("Side") and wall.position.is_equal_approx(Vector3(-4,1.57,0)): return wall
	return null

func synthetic_bullet(row: Dictionary) -> Dictionary:
	serial+=1
	return site._glazing.apply_bullet({"admitted":true,"authority":"local_preview","server_authority":false,"scope":"new_local_session_building_glass","explosive":false,"source_id":site.source_id,"generation":site.rebuild_generation,"weapon_id":"tt_pistol","event_id":"SIMULATED-component-glazing43:"+str(serial),"collider":row.body,"position":row.body.to_global(Vector3(-row.size.x*.24,row.size.y*.23,.0075)),"direction":-row.body.global_basis.z,"power":20.0})

func visible_effects(node: Node) -> int:
	var total:=0
	for child: Node in node.get_children():
		if child is MeshInstance3D and child.is_visible_in_tree() and child.get_parent().get_meta("glassEffect",false): total+=1
		total+=visible_effects(child)
	return total

func reset(label: String) -> void:
	var old_helper: WeakRef=weakref(site._glazing)
	var old_generation: int=site.rebuild_generation
	check(site.request_reset().get("queued",false),label+": real site reset queued")
	for i in 80:
		await step()
		if not site.rebuilding and site.rebuild_generation>old_generation: break
	await step(3)
	check(not is_instance_valid(old_helper.get_ref()),label+": old helper and decorations freed")
	check(site.rebuild_generation==old_generation+1 and site._glazing.stats().panes==28,label+": new generation restores all 28 panes")
	check(site._glazing.stats().broken==0 and site._glazing.stats().get("support_lost",-1)==0,label+": new panes have no previous lifecycle state")
	for row: Dictionary in site._glazing._panes.values():
		check(site._glazing.owns_collider(row.body) and row.mesh.is_visible_in_tree(),label+": new actual pane collides and renders")

func native_capsule_crossing(origin: Vector3,normal: Vector3,label: String) -> Dictionary:
	var walker:=CapsuleWalker.new(); walker.name="ActualCapsule43"
	# This diagnoses frozen architectural/pane barriers only. The native player's
	# rubble push loop and global passage acceptance are separate required QA.
	walker.collision_layer=2; walker.collision_mask=1
	walker.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	var shape:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new()
	capsule.radius=.30; capsule.height=1.90; shape.shape=capsule; walker.add_child(shape)
	world.add_child(walker); walker.global_position=origin+normal*1.15
	var start: Vector3=walker.global_position
	await step(2)
	walker.command=-normal*2.5
	await step(64)
	walker.command=Vector3.ZERO
	var finish: Vector3=walker.global_position
	var result: Dictionary={"start":start,"finish":finish,"signed_finish_m":(finish-origin).dot(normal),"distance_m":start.distance_to(finish),"contact_ids":walker.contacts.duplicate(),"capsule_height_m":1.90,"capsule_radius_m":.30,"collision_mask":1,"move_and_slide":true,"teleport_during_movement":false,"rubble_push_acceptance":false}
	walker.queue_free(); await step(2)
	evidence[label]=result
	return result

func door_and_broken_then_collapse() -> void:
	var door: RigidBody3D=site._door
	var row: Dictionary=row_for(door)
	if not check(not row.is_empty(),"real authored door has one registered pane"): return
	check(synthetic_bullet(row).get("ok",false),"component bullet starts actual delayed Walk fracture")
	await step(12)
	check(row.broken and row.body.collision_layer==0 and visible_effects(row.mesh)>0,"fractured supported window retains Walk rim before structural loss")
	var before: Transform3D=row.body.global_transform
	# Explicit lifecycle setup, not E/selection admission. The composed door43
	# prompt requires a real player camera; this fixture must not impersonate it.
	# Exercise the unchanged actual door pose/collision/glazing writer by tween.
	var motion: Tween=site.create_tween()
	motion.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	motion.tween_method(site._move_door,0.0,PI*.5,.5)
	evidence.door_motion={"actual_pose_writer":true,"native_E_input":false,"setup":"component physics tween invokes owned _move_door"}
	await step(40)
	check(not before.is_equal_approx(row.body.global_transform),"broken door pane remnant follows actual opening door")
	check(row.body.global_transform.is_equal_approx(door.global_transform*row.wall_local),"broken pane local attachment remains exact through door motion")
	check(visible_effects(row.mesh)>0 and not row.get("support_lost",true),"intact moving door does not discard attached rim")
	await step(2)
	var panel: RigidBody3D=side_panel()
	var wall_row: Dictionary=row_for(panel)
	var point: Vector3=wall_row.body.global_position
	var normal: Vector3=wall_row.body.global_basis.z
	var intact: Dictionary=await native_capsule_crossing(point,normal,"before_collapse_capsule")
	check(intact.signed_finish_m>0 and not intact.contact_ids.is_empty(),"standing native capsule is physically stopped at the intact window wall")
	check(site.request_full_collapse("glazing43-real-site-K-owner").get("started",false),"real full-collapse owner starts timed collapse")
	check(row.body.collision_layer==0 and not row.mesh.is_visible_in_tree(),"already fractured pane rim retires synchronously when K removes its support")
	for pane: Dictionary in site._glazing._panes.values():
		check(pane.body.collision_layer==0 and not site._glazing.owns_collider(pane.body),"K immediately retires each fixed pane barrier, including queued fractures")
	await step(180)
	var stats: Dictionary=site._glazing.stats()
	check(site.event_status("glazing43-real-site-K-owner").get("completed",false),"real timed site collapse completes")
	check(stats.get("support_lost",-1)==28 and stats.get("retired_pane_visuals",-1)==28 and stats.rejected==0,"all 28 pane supports and retained visuals retire without fracture rejection")
	for pane: Dictionary in site._glazing._panes.values():
		check(pane.broken and pane.collision.disabled and visible_effects(pane.mesh)==0 and not pane.mesh.is_visible_in_tree(),"no fixed collider or cyan rim survives completed full collapse")
	var cleared: Dictionary=await native_capsule_crossing(point,normal,"after_collapse_capsule")
	check(cleared.signed_finish_m<-.8,"standing native capsule crosses the former wall/window plane after actual collapse")
	evidence.full_collapse=stats
	await reset("reset after completed full collapse")

func pending_then_support_loss() -> void:
	var panel: RigidBody3D=side_panel()
	var row: Dictionary=row_for(panel)
	check(synthetic_bullet(row).get("pending",false) and not row.broken,"first actual Walk fracture remains pending before delay")
	var before: int=site._glazing._glass.stats().broken_panels
	# Same actual hook called by the support helper: activate its existing pool
	# then give every source chunk to gravity, without fabricating an RPG.
	var chunks: Array=site._support_expand_piece(panel)
	check(chunks.size()==panel.get_meta("pooled_fragments").size() and chunks.size()>0,"support expansion uses the exact prewarmed compound pool")
	for chunk: RigidBody3D in chunks: site._release(chunk,chunk.global_position,0.0)
	check(row.body.collision_layer==0 and not site._glazing.owns_collider(row.body),"support loss removes pending pane's real barrier immediately")
	await step(15)
	check(row.broken and not row.pending and not row.mesh.is_visible_in_tree() and visible_effects(row.mesh)==0,"pending-to-support-loss fracture completes with no orphan rim")
	check(site._glazing._glass.stats().broken_panels==before and site._glazing.stats().rejected==0,"support-loss notification does not duplicate the pending fracture")
	evidence.pending_to_support_lost=site._glazing.stats()
	await reset("reset after support loss")

func pending_then_reset() -> void:
	var panel: RigidBody3D=side_panel()
	var row: Dictionary=row_for(panel)
	check(synthetic_bullet(row).get("pending",false),"new pending fracture exists before reset")
	site._glazing.break_for_wall(panel)
	var old_mesh: WeakRef=weakref(row.mesh)
	await reset("reset while structural fracture is pending")
	await step(30)
	check(not is_instance_valid(old_mesh.get_ref()) and site._glazing.stats().broken==0,"old delayed fracture cannot alter the new generation")

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
	create_timer(40).timeout.connect(func():
		if not finished: check(false,"bounded 40-second component fixture"); finish())
	world=Node3D.new(); world.name="GlazingLifecycle43"; root.add_child(world)
	site=Site.new(); site.source_id="palazzo-glazing43-component"
	site.transform=Transform3D(Basis(Vector3.UP,.4),Vector3(30,2,-20))
	world.add_child(site); await step(5)
	if not check(site.site_ready and is_instance_valid(site._glazing),"actual finished structural Palazzo initializes under translation/yaw"): finish(); return
	check(site._glazing.stats().panes==28,"authored 28-pane inventory retained")
	await door_and_broken_then_collapse()
	await pending_then_support_loss()
	await pending_then_reset()
	finish()

func finish() -> void:
	if finished: return
	finished=true
	var report: Dictionary={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"evidence":evidence,"native_physics_capsule":true,"synthetic_bullet_admission":true,"native_weapon_input":false,"native_door_input":false,"loaded_player_passage_accepted":false,"performance_accepted":false,"limits":["Component native physics only; actual player, rubble pushing and loaded scene remain separate gates.","Physical brass mullions, frame destruction and exact compound support adjacency remain OPEN.","Headless visible flags do not replace final screenshot review."]}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"\t")); file.close()
	else: push_error("Cannot write glazing43 result: "+output)
	print("GLAZING43 ",report.status," checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 2)
