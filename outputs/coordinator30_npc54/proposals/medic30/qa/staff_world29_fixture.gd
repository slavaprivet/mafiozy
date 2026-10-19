extends SceneTree
const Registry = preload("res://scripts/venues/npc_venue_registry29.gd")
const Visit = preload("res://scripts/hospital/npc_restaurant_visit28.gd")
const Queue = preload("res://scripts/venues/npc_service_queue29.gd")
var checks: Array[String] = []
var failures: Array[String] = []
var evidence: Dictionary = {}
var game: Node3D
var output := ""
var finished := false

func check(ok: bool, label: String) -> bool:
	checks.append(label)
	if not ok: failures.append(label); print("STAFF29_FAIL ", label)
	return ok

func _initialize() -> void:
	_run.call_deferred()

func step(count: int = 1) -> void:
	for index: int in range(count): await physics_frame; await process_frame

func capsule(point: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new(); body.collision_layer = 1; body.collision_mask = 1
	var shape := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = .36; cap.height = 1.9
	shape.shape = cap; shape.position.y = .95; body.add_child(shape); game.add_child(body); body.global_position = point
	return body

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): output = arg.trim_prefix("--qa-out=")
	create_timer(150).timeout.connect(func():
		if not finished: check(false, "bounded native staff fixture deadline"); finish())
	var queue: RefCounted = Queue.new()
	for i: int in range(286): check(queue.enqueue(str(i), "one"), "enqueue " + str(i))
	for i: int in range(286):
		check(queue.owns(str(i), "one"), "FIFO sole owner " + str(i)); queue.release(str(i))
	check(queue.keys.is_empty() and queue.queues.is_empty(), "all 286 reused without resident population")
	game = load("res://scripts/main.gd").new(); game.block_data_path = "res://data/city_block.json"; game.city_block_mode = true
	game.preview_residents_enabled = false; game.preview_final_dead_contact_enabled = false
	root.add_child(game); current_scene = game
	for tick: int in range(1800):
		await step()
		if game.preview_ready: break
	if not check(game.preview_ready, "actual world ready"): finish(); return
	check(game.preview_population == null, "roaming resident population remains disabled")
	var host: Node = game.preview_venue_staff29
	if not check(is_instance_valid(host), "staff host exists"): finish(); return
	evidence.setup = host.report
	check(host.report.get("ok", false), "all staff placements accepted")
	check(host._rows.size() == 12, "one staff per 12 signed venues")
	await step(15)
	var rigs := {}; var total_nodes := 0; var meshes := 0; var vertices := 0
	for row: Dictionary in host._rows.values():
		var actor: CharacterBody3D = row.actor
		check(actor.available29(), "staff supported " + str(actor.get_instance_id()))
		check(actor._skeleton.get_bone_count() == 28, "canonical rig " + str(actor.get_instance_id()))
		check(not rigs.has(actor._skeleton.get_instance_id()), "private skeleton " + str(actor.get_instance_id())); rigs[actor._skeleton.get_instance_id()] = true
		var nodes: Array[Node] = [actor]; var index := 0
		while index < nodes.size():
			var node: Node = nodes[index]; total_nodes += 1
			if node is MeshInstance3D:
				meshes += 1
				for surface: int in range(node.mesh.get_surface_count()): vertices += node.mesh.surface_get_array_len(surface)
			for child: Node in node.get_children(): nodes.append(child)
			index += 1
	evidence.cost = {"nodes":total_nodes,"mesh_instances":meshes,"vertices":vertices,"skeletons":rigs.size(),"bones":rigs.size()*28,"path_planners":0,"performance_accepted":false}
	var registry: RefCounted = Registry.for_scene(game)
	var site: Node3D = game.preview_service_sites29.current_sites()[0]
	var venue: String = str(site._swing29.get_instance_id())
	var entry: Dictionary = registry.entry(venue)
	if not check(not entry.is_empty() and host._rows.has(venue), "fixture target has live staff admission"): finish(); return
	var first: CharacterBody3D = capsule(entry.rooms[0])
	var second: CharacterBody3D = capsule(entry.rooms[1])
	await step(2)
	var visit_a: RefCounted = Visit.new(); var visit_b: RefCounted = Visit.new()
	check(visit_a.begin(game, first, RID(), "fixture_client_a", "БОЛЬНИЦА"), "first physical client admitted")
	check(visit_b.begin(game, second, RID(), "fixture_client_b", "БОЛЬНИЦА"), "second physical client admitted")
	var first_inside := false
	for tick: int in range(1200):
		await step()
		var ra: String = visit_a.step(1.0/60.0); visit_b.step(1.0/60.0)
		if ra == "entered": first_inside = true; break
		if ra == "blocked": break
	evidence.first_route = visit_a.snapshot(); evidence.second_route = visit_b.snapshot()
	if not check(first_inside and visit_a.is_inside(), "first alone reaches physical service slot"): finish(); return
	check(not visit_b.is_inside() and visit_b._phase == "SERVICE_WAIT", "second waits inside without settlement gate")
	check(not visit_b.publish_service_dwell29("hospital"), "waiting client cannot publish service activity")
	var staff: CharacterBody3D = host._rows[venue].actor
	staff.disable29()
	check(visit_b.step(1.0/60.0) == "blocked" and not visit_b.is_inside(), "lost staff makes waiting visit honestly blocked")
	staff._disabled29 = false # Component fixture restores availability; no health/payment receipt.
	for tick: int in range(25):
		await step(); visit_a.hold(1.0/60.0); visit_b.step(1.0/60.0); visit_a.publish_service_dwell29("hospital")
	check(staff.serving29 and registry.service_customer29(venue) == first, "medic animation follows only real active service dwell")
	check(registry.doorway_state29(second).mode == "waiting", "avoidance holds waiting slot without releasing claims")
	var capacity_before: int = registry.ledger.venues[venue].slots.size()
	check(visit_a.begin_exit(), "first starts physical exit")
	check(registry.ledger.venues[venue].slots.size() == capacity_before, "exit initiation retains capacity")
	var second_inside := false; var first_out := false
	for tick: int in range(1600):
		await step()
		if not first_out: first_out = visit_a.step(1.0/60.0) == "exited"
		if not second_inside: second_inside = visit_b.step(1.0/60.0) == "entered"
		else: visit_b.hold(1.0/60.0)
		if first_out and second_inside: break
	evidence.exit_route = visit_a.snapshot(); evidence.promoted_route = visit_b.snapshot()
	check(first_out and visit_a.is_outside(), "first really exits before capacity release")
	check(second_inside and visit_b.is_inside(), "second FIFO client physically reaches freed counter")
	visit_b.cancel(); await step(10)
	check(registry._service29.keys.is_empty(), "cancel retires service claim")
	check(not staff.serving29, "cancel stops service gesture")
	first.queue_free(); second.queue_free()
	await step(2)
	var doomed: CharacterBody3D = capsule(entry.rooms[0]); await step(2)
	var doomed_visit: RefCounted = Visit.new()
	check(doomed_visit.begin(game, doomed, RID(), "retired_client", "БОЛЬНИЦА"), "retired-body lifecycle client admitted")
	var doomed_key: String = doomed_visit._key; var doomed_id: int = doomed.get_instance_id()
	doomed.queue_free(); await step(90)
	check(not registry.ledger.requests.has(doomed_key) and not registry._service29.keys.has(doomed_key) and not registry._actor_by_body29.has(doomed_id), "freed body releases capacity service and readonly index without another visit")
	site.set_meta("venue_closed29", true); await step(10)
	check(not staff.available29() and not staff.serving29, "closed site cannot continue staff service")
	var previous_staff: int = staff.get_instance_id()
	check(site.request_reset().get("ok", false), "native building reset accepted")
	await step(150)
	var next_venue: String = str(site._swing29.get_instance_id())
	check(next_venue != venue and host._rows.has(next_venue) and not host._rows.has(venue), "reset retires old owner and rebinds staff to new door")
	if host._rows.has(next_venue):
		var replacement: CharacterBody3D = host._rows[next_venue].actor
		check(replacement.get_instance_id() != previous_staff and replacement.available29(), "new staff has real support after reset")
		var counter: RigidBody3D = host._rows[next_venue].counter.get_ref()
		site._release(counter, counter.global_position, 1.0, Vector3.RIGHT)
		await step(3)
		check(not counter.freeze and not replacement.available29(), "native counter destruction stops service while the building door remains")
	check(not registry._entries.has(venue), "old generation has no admission entry")
	finish()

func finish() -> void:
	if finished: return
	finished = true
	var result := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks.size(),"failures":failures,"evidence":evidence,"resident_population_enabled":false,"performance_accepted":false,"payment_receipts_fabricated":false}
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")+"\n")
	print("STAFF29_RESULT ", JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
