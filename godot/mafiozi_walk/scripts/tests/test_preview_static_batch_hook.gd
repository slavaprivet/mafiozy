extends SceneTree
## Actual main integration only. No renderer/FPS or isolated-helper cost claim.
const MAIN = preload("res://scenes/main.tscn")
const PRINTSHOP := "REBUILD-VISUAL-print_shop-001"
const EXPECTED_OWNERS := ["REBUILD-VISUAL-old_town_narrow_townhouse_v1-013","REBUILD-VISUAL-old_town_narrow_townhouse_v1-005","REBUILD-VISUAL-gun_shop-001","REBUILD-VISUAL-pawnshop-001","REBUILD-VISUAL-old_town_narrow_townhouse_v1-004","REBUILD-VISUAL-old_town_narrow_townhouse_v1-012","REBUILD-VISUAL-old_town_narrow_townhouse_v1-007","LAMP-1-83","LAMP-15-78","LAMP-19-97","LAMP-21-84","LAMP-29-79","LAMP-30-98","LAMP-9-102","LAMP-9-84"]
var checks: int = 0
var failures: Array[String] = []
var metrics: Dictionary = {}
var world: Node3D
var player: CharacterBody3D
var main_sha: String
var helper_sha: String

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame

func start(enabled: bool) -> void:
	world = MAIN.instantiate()
	world.set("preview_static_batch_enabled",enabled)
	root.add_child(world)
	player = world.get("_player")
	if player != null: player.set_physics_process(false)
	world.set_process(false)
	await frames(3)
	check(world.get("preview_ready") and world.get("printshop_status") == "ready","actual main and printshop ready")

func nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child: Node in node.get_children(): result.append_array(nodes(child))
	return result

func original_nodes() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in nodes(world):
		if node is MultiMeshInstance3D and str(node.name).begins_with("StaticBatch_"): continue
		result[node.get_instance_id()] = [node.get_parent().get_instance_id(),str(world.get_path_to(node)),node.get_class(),node.get_meta("source_id",""),node.get_meta("source_index",-1)]
	return result

func meshes() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in world.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node
		var materials: Array = []
		if mesh.mesh != null:
			for surface: int in range(mesh.mesh.get_surface_count()):
				var material: Material = mesh.get_active_material(surface)
				materials.append(material.get_instance_id() if material != null else 0)
		result[mesh.get_instance_id()] = [mesh.global_transform,mesh.mesh.get_instance_id() if mesh.mesh != null else 0,materials,mesh.get_parent().get_instance_id(),mesh.layers,mesh.cast_shadow,mesh.gi_mode]
	return result

func visibility() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in world.find_children("*","MeshInstance3D",true,false):
		result[stable_path(node)] = node.visible
	return result

func stable_path(node: Node) -> String:
	# Godot appends process-global counters to unnamed generated nodes. Use
	# unchanged child indices for those segments across fresh main instances.
	var segments := PackedStringArray()
	while node != world:
		var name_value := str(node.name)
		segments.insert(0,node.get_class()+"#"+str(node.get_index()) if name_value.begins_with("@") else name_value)
		node = node.get_parent()
	return "/".join(segments)

func physical() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in nodes(world):
		if node is CollisionObject3D:
			result[node.get_instance_id()] = [node.global_transform,node.collision_layer,node.collision_mask,node.get_rid(),node.get_meta("source_id",""),node.get_meta("source_index",-1)]
		elif node is CollisionShape3D:
			var properties: Dictionary = {}
			if node.shape != null:
				for property: Dictionary in node.shape.get_property_list():
					if int(property.usage) & PROPERTY_USAGE_STORAGE:
						properties[property.name] = node.shape.get(property.name)
			result[node.get_instance_id()] = [node.global_transform,node.disabled,node.shape.get_instance_id() if node.shape != null else 0,properties]
	return result

func printshop_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for owner: Node in [world.get_node(PRINTSHOP),world.get("_printshop")]:
		for node: Node in nodes(owner):
			var entry: Array = [node.get_parent().get_instance_id()]
			if node is Node3D: entry.append_array([node.transform,node.visible])
			result[node.get_instance_id()] = entry
	return result

func static_batches() -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in world.find_children("*","MultiMeshInstance3D",true,false):
		if str(node.name).begins_with("StaticBatch_"): result.append(node)
	return result

func check_active(original_visibility: Dictionary) -> void:
	var summary: Dictionary = world.get("static_batch_summary")
	check(world.get("static_batch_status") == "ready" and summary.get("ok",false),"active main publishes successful status")
	check(summary.get("batch_nodes",0) == 69 and summary.get("batched_sources",0) == 248,"actual main matches 69 groups / 248 source leaves")
	check(static_batches().size() == 69,"69 actual static batch nodes exist")
	var hidden: int = 0
	var after: Dictionary = visibility()
	for path: String in original_visibility:
		if original_visibility[path] and not after[path]: hidden += 1
	check(hidden == 248,"exactly 248 originally visible mesh leaves hidden")
	var batch_instances: int = 0
	var excluded: bool = true
	for batch: MultiMeshInstance3D in static_batches():
		batch_instances += batch.multimesh.instance_count
		excluded = excluded and str(batch.get_parent().get_meta("source_id","")) in EXPECTED_OWNERS
	check(batch_instances == 248 and excluded,"batch instances stay under explicit non-printshop owners")
	var owners: Array[String] = []
	for owner: Node3D in world.get("_static_render_roots"):
		owners.append(str(owner.get_meta("source_id","")))
	owners.sort()
	var expected: Array = EXPECTED_OWNERS.duplicate()
	expected.sort()
	check(owners == expected,"exact literal seven buildings and eight lamps admitted")
	metrics["batch_nodes"] = summary.get("batch_nodes",0)
	metrics["batched_sources"] = summary.get("batched_sources",0)
	metrics["eligible"] = summary.get("eligible",0)
	metrics["source_mesh_count"] = after.size()

func input_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = false
	root.push_input(event)

func blocked(from: Vector3,to: Vector3) -> bool:
	var capsule: CollisionShape3D = player.get_node("PlayerCapsule")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	query.transform = Transform3D(Basis.IDENTITY,from+Vector3(0,capsule.shape.height*.5+.015,0))
	query.motion = to-from
	query.margin = .005
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	return world.get_world_3d().direct_space_state.cast_motion(query)[0] < .999

func door_cycle(label: String) -> void:
	var interior: Node3D = world.get("_printshop")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	var anchor := Vector3(data.doors.public.anchor[0],data.doors.public.anchor[1],data.doors.public.anchor[2])
	var direction: Vector3 = interior.anchor("publicApproach")-interior.anchor("publicInside")
	direction.y = 0
	direction = direction.normalized()
	var outside: Vector3 = anchor+direction*1.4
	var inside: Vector3 = anchor-direction*1.4
	player.global_position = outside
	await frames(2)
	check(blocked(outside,inside),label+": closed door blocks actual player capsule")
	input_e()
	check(interior.nearest_action(outside).opening,label+": real single E starts opening")
	await frames(55)
	check(is_equal_approx(interior.door_fraction("public"),1.0) and not blocked(outside,inside),label+": open leaf permits physical passage")
	input_e()
	await frames(55)
	check(is_equal_approx(interior.door_fraction("public"),0.0) and blocked(outside,inside),label+": real E closes solid door")
	check(is_equal_approx(interior.door_fraction("service"),0.0),label+": service door remains closed")

func run() -> void:
	main_sha = FileAccess.get_sha256("res://scripts/main.gd")
	helper_sha = FileAccess.get_sha256("res://scripts/preview_static_batch.gd")
	await start(false)
	check(world.get("static_batch_status") == "disabled" and world.get("_static_batch_lease") == null and (world.get("static_batch_summary") as Dictionary).is_empty(),"default OFF does not allocate a helper plan or lease")
	check(static_batches().is_empty(),"OFF has no generated static batches")
	await door_cycle("OFF")
	var original_meshes: Dictionary = meshes()
	var original_physics: Dictionary = physical()
	var original_tree: Dictionary = original_nodes()
	var original_visibility: Dictionary = visibility()
	var original_printshop: Dictionary = printshop_snapshot()
	metrics["physical_nodes"] = original_physics.size()
	check(world.call("apply_preview_static_batches"),"actual main OFF to ON succeeds")
	check_active(original_visibility)
	check(meshes() == original_meshes and physical() == original_physics and original_nodes() == original_tree,"ON retains original mesh resources, transforms, physics IDs/shapes and hierarchy")
	check(printshop_snapshot() == original_printshop,"entire printshop original and interior branches untouched")
	var lease: RefCounted = world.get("_static_batch_lease")
	var active_ids: Array = []
	for node: Node in static_batches(): active_ids.append(node.get_instance_id())
	check(world.call("apply_preview_static_batches") and world.get("_static_batch_lease") == lease and static_batches().size() == 69,"repeat ON is idempotent")
	await door_cycle("ON")
	check(printshop_snapshot() == original_printshop and physical() == original_physics,"door cycle preserves excluded hierarchy and exact returned closed physics")
	world.call("restore_preview_static_batches")
	check(world.get("static_batch_status") == "restored" and world.get("_static_batch_lease") == null,"main releases lease on restore")
	check(visibility() == original_visibility and meshes() == original_meshes and physical() == original_physics,"restore recovers exact original visibility/resources/physics")
	check(static_batches().is_empty() and lease.batch_nodes().is_empty(),"restore frees generated batch nodes even with externally retained lease")
	var freed: bool = true
	for id: int in active_ids: freed = freed and not is_instance_id_valid(id)
	check(freed,"every first-generation batch instance freed")
	world.call("restore_preview_static_batches")
	check(visibility() == original_visibility,"double restore preserves exact visibility")
	# Dependency activation is AFTER restore, per ownership contract.
	var light := OmniLight3D.new()
	world.add_child(light)
	check(not world.call("apply_preview_static_batches") and world.get("static_batch_status") == "fallback","local light blocks next apply after restore")
	check(world.get("preview_ready") and world.get("_static_batch_lease") == null and static_batches().is_empty(),"rejected lighting admission keeps ready main without partial batch")
	check(visibility() == original_visibility and meshes() == original_meshes and physical() == original_physics,"lighting fallback retains all source content and physics")
	light.free()
	check(world.call("apply_preview_static_batches"),"removing rejected dependency permits explicit rebuild")
	check_active(original_visibility)
	var final_lease: RefCounted = world.get("_static_batch_lease")
	var all_ids: Array[int] = []
	for node: Node in nodes(world): all_ids.append(node.get_instance_id())
	world.free()
	await frames(2)
	freed = true
	for id: int in all_ids: freed = freed and not is_instance_id_valid(id)
	check(freed and final_lease.batch_nodes().is_empty() and final_lease.batch_receipts().is_empty(),"scene teardown frees all original/generated nodes and restores retained lease")
	lease = null
	final_lease = null
	# Startup opt-in independently exercises the before-player/ready hook.
	await start(true)
	check_active(original_visibility)
	check(world.get("preview_ready") and world.get("static_batch_status") == "ready","enabled startup reaches main readiness with active batches")
	world.call("restore_preview_static_batches")
	check(visibility() == original_visibility,"enabled startup restores same canonical source visibility")
	world.free()
	await frames(2)
	# Actual failed startup admission, not an injected fake helper failure.
	light = OmniLight3D.new()
	root.add_child(light)
	await start(true)
	check(world.get("preview_ready") and world.get("static_batch_status") == "fallback","startup local-light rejection keeps complete main READY fallback")
	check(world.get("_static_batch_lease") == null and static_batches().is_empty() and visibility() == original_visibility,"failed startup is atomic with canonical visible content")
	check(not (world.get("static_batch_summary") as Dictionary).get("errors",[]).is_empty(),"fallback publishes explicit admission errors")
	world.free()
	light.free()
	await frames(2)
	check(FileAccess.get_sha256("res://scripts/main.gd") == main_sha and FileAccess.get_sha256("res://scripts/preview_static_batch.gd") == helper_sha,"main/helper frozen throughout final run")
	print("STATIC_BATCH_MAIN_HOOK_TEST ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"main_sha256":main_sha,"helper_sha256":helper_sha,"live":false,"fps":false,"cpu_benchmark":false}))
	quit(0 if failures.is_empty() else 1)
