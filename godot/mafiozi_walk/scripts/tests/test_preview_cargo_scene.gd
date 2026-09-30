extends SceneTree
var failures: Array[String]=[]
var checks:=0
var test_destroy_event: Dictionary={}
func source_fixture(uid: String) -> Dictionary:
	return test_destroy_event.duplicate() if test_destroy_event.get("event_id")==uid else {}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene: Node3D=load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled=false; scene.preview_weapons_enabled=true
	root.add_child(scene)
	while not scene.preview_ready: await physics_frame
	var p: CharacterBody3D=scene._player
	var transport: Node3D=scene.preview_transport
	var weapons: Node=scene.preview_weapons
	var cargo: Node=weapons.get_node_or_null("WeaponCargo")
	check(cargo!=null,"actual cargo bound")
	if cargo==null: quit(1); return
	p.set_mouse_captured(true)
	for i in 60: await physics_frame
	var profile: Dictionary=transport.compartments.access_profile("trunk")
	var stand: Vector3=transport.body.to_global(profile.position_local_m+profile.outward_local*.9)
	stand.y=.01; p.global_position=stand
	for i in 5: await physics_frame
	var bounds: Dictionary=transport.compartments.cargo_bounds()
	var target: Vector3=transport.visual.root.to_global((bounds.min+bounds.max)*.5)
	var camera: Camera3D=p.get_preview_camera()
	camera.top_level=true; camera.global_position=stand+Vector3.UP*2.0
	camera.look_at(target,Vector3.UP)
	print("CARGO_AIM ",cargo.aim_context()," profile ",profile)
	check(weapons.equip("ak74").ok,"equip AK")
	check(cargo.aim_context().near_trunk,"actual approach in trunk range")
	check(cargo.aim_context().aimed_trunk,"actual camera targets cargo volume")
	check(not cargo.store_held().get("ok",false),"closed trunk refuses store")
	check(cargo.bridge.actions().actions.is_empty(),"closed trunk no prompts")
	transport.compartments.set_open("trunk",true)
	for i in 100: await physics_frame
	camera.global_position=stand+Vector3.UP*2.0; camera.look_at(transport.visual.root.to_global((bounds.min+bounds.max)*.5),Vector3.UP)
	var original: Dictionary=weapons.fire_state.duplicate(true)
	var item_uid: String=weapons.inventory.get_item_uid("ak74")
	var stored: Dictionary=cargo.store_held()
	print("CARGO_STORE ",stored.get("ok")," ",stored.get("reason",""))
	check(stored.get("ok",false),"actual source trunk accepts AK")
	check(cargo.cargo.summary(cargo.generation).used_units==cargo.bridge.capacity_metadata().costs.ak74,"AK occupies current measured cost")
	check(not weapons.inventory.get_owned_ids().has("ak74"),"stored item removed from inventory")
	check(cargo.renderer.debug_snapshot().total_count==1,"actual reduced cargo model exists")
	if stored.get("ok",false):
		var entry: Dictionary=cargo.cargo.snapshot(cargo.generation).items[0]
		check(entry.item.uid==item_uid,"stable cargo identity")
		check(entry.item.fireState.magazine==original.magazine,"ammo retained in trunk")
		var item_center: Vector3=transport.visual.root.to_global(entry.item_bounds_local_m.get_center())
		camera.look_at(item_center,Vector3.UP)
		var context: Dictionary=cargo.aim_context()
		print("CARGO_ITEM_AIM ",context)
		check(context.item_uid==item_uid,"aim picks exact weapon geometry")
		var taken: Dictionary=cargo.take_item(item_uid)
		check(taken.get("ok",false),"E semantic exact item transfer")
		check(weapons.inventory.get_item_uid("ak74")==item_uid,"pickup preserves UID")
		check(cargo.cargo.summary(cargo.generation).used_units==0,"capacity freed")
		check(weapons.fire_state.weaponId=="ak74","latest user: trunk pickup immediately equips selected weapon")
	transport.compartments.set_open("trunk",false)
	check(cargo.bridge.actions().actions.is_empty(),"closing target immediately hides cargo actions")
	# Real ground placement and source lying/falling visual, away from the car.
	p.global_position=Vector3(31,.01,-18)
	for i in 8: await physics_frame
	check(weapons.equip("ak74").ok,"re-equip taken AK")
	var dropped: Dictionary=cargo.drop_held()
	print("GROUND_DROP ",dropped.get("ok")," ",dropped.get("reason",""))
	check(dropped.get("ok",false),"actual unobstructed ground drop")
	if dropped.get("ok",false):
		check(weapons.inventory.get_drop_item(dropped.drop.uid).uid==item_uid,"ground same item UID")
		check(cargo.renderer.debug_snapshot().falling_count==1,"new ground model falling")
		for i in 40: await physics_frame
		check(cargo.renderer.debug_snapshot().falling_count==0,"source fall settles")
		var at: Dictionary=dropped.drop.position
		var floor_point:=Vector3(at.x,at.y,at.z)
		p.global_position=floor_point+Vector3(.7,.01,0)
		for i in 5: await physics_frame
		camera.global_position=floor_point+Vector3(0,2,.8)
		# Aim a real triangle, not empty space at the aggregate AABB centre.
		var ground_row: Dictionary=cargo.renderer.get("_ground")[dropped.drop.uid]
		var aimed:=false
		for part: Dictionary in ground_row.parts:
			var faces: PackedVector3Array=part.mesh.get_faces()
			for face: int in range(0,faces.size(),3):
				var point: Vector3=ground_row.visual.global_transform*part.transform*((faces[face]+faces[face+1]+faces[face+2])/3.0)
				camera.look_at(point,Vector3.UP)
				if cargo.renderer.pick(camera.global_position,-camera.global_basis.z,12.0,{"enabled":true,"scope":"ground"}).get("hit",false): aimed=true; break
			if aimed: break
		check(aimed,"real visible ground triangle selected")
		var context: Dictionary=cargo.aim_context()
		print("GROUND_AIM ",context)
		check(context.drop_uid==dropped.drop.uid,"ground geometry aimed and reachable")
		check(cargo.pickup_ground(dropped.drop.uid).get("ok",false),"actual ground pickup")
		check(weapons.inventory.get_item_uid("ak74")==item_uid,"ground pickup same identity")
	# Only the source-provider seam is a fixture: ground rays, inventory, vehicle,
	# model geometry and the complete all-or-nothing destruction batch are real.
	p.global_position=stand
	for i in 8: await physics_frame
	camera.global_position=stand+Vector3.UP*2.0; camera.look_at(transport.visual.root.to_global((bounds.min+bounds.max)*.5),Vector3.UP)
	transport.compartments.set_open("trunk",true)
	for i in 100: await physics_frame
	camera.global_position=p.global_position+Vector3.UP*2.0; camera.look_at(transport.visual.root.to_global((bounds.min+bounds.max)*.5),Vector3.UP)
	check(weapons.equip("ak74").ok,"AK before destruction batch")
	var restore: Dictionary=cargo.store_held()
	print("CARGO_RESTORE ",restore.get("ok")," ",restore.get("reason","")," aim ",cargo.aim_context())
	check(restore.get("ok",false),"AK back into cargo")
	check(weapons.equip("tt_pistol").ok,"second different item")
	check(cargo.store_held().get("ok",false),"second reduced model non-overlap")
	check(not cargo.consume_vehicle_destruction("fixture-destroy").get("ok",false),"no damage source cannot invent destruction")
	check(cargo.bind_destruction_source(source_fixture),"explicit test-only source bound")
	test_destroy_event={"event_id":"fixture-destroy","vehicle_id":cargo.vehicle_id,"life_generation":cargo.generation,"body_instance_id":transport.body.get_instance_id(),"destroyed":true}
	var destroyed: Dictionary=cargo.consume_vehicle_destruction("fixture-destroy")
	print("CARGO_DESTROY ",destroyed.get("ok")," ",destroyed.get("reason",""))
	check(destroyed.get("ok",false),"real collision-ground batch prepares before consumption")
	check(weapons.inventory.get_dropped().size()==2,"two stored weapons now ground pickups")
	check(cargo.renderer.debug_snapshot().falling_count==2,"destroyed cargo physically presented falling")
	check(cargo.consume_vehicle_destruction("fixture-destroy").get("duplicate",false),"destruction replay idempotent")
	check(weapons.inventory.get_dropped().size()==2,"replay never duplicates pickups")
	p.set_mouse_captured(false)
	check(not cargo.store_held().get("ok",false),"released mouse cannot store")
	scene.free()
	await process_frame; await process_frame
	print("CARGO_SCENE ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
