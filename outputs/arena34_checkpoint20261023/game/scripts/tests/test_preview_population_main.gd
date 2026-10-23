extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled = true
	scene.preview_resident_walk_enabled = false # This test owns explicit route orders.
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 15000
	while not scene.preview_ready and Time.get_ticks_msec() < deadline: await physics_frame
	check(scene.preview_ready, "main ready with opted-in residents")
	var population: RefCounted = scene.preview_population
	if population != null and scene.population_status == "pending_placement":
		# The accepted packet is BEFORE_NATIVE_RESOLVER. These three raw births
		# are all road cells. Correct source policy must keep them invisible until
		# the separate original placement algorithm resolves their source state.
		check(population.occupants().is_empty(), "unresolved road births stay invisible")
		for row: Dictionary in population.residents.snapshot().rows:
			check(row.status == "PENDING_PLACEMENT" and row.position == null, "no fabricated placement " + row.source_id)
		check(scene._current_door_occupants().size() == 1, "no phantom door occupants")
		check(scene.transport_status == "ready", "pending residents preserve vehicle")
		var pending: Dictionary = population.snapshot()
		scene.free()
		check(population.status == "disposed", "pending scene tears down owned resources")
		print(JSON.stringify({"checks": checks, "failures": failures, "population": pending, "movement_gate": "NOT_RUN_PENDING_SOURCE_PLACEMENT", "scope": "source placement fail-closed acceptance only; not live NPC completion"}))
		quit(0 if failures.is_empty() else 1); return
	check(population != null and scene.population_status == "ready", "actual root population admitted: " + str(population.snapshot() if population != null else {}))
	if population == null or scene.population_status != "ready":
		print(JSON.stringify({"checks": checks, "failures": failures})); scene.free(); quit(1); return
	check(population.occupants().size() == 3, "exactly three source residents")
	check(scene._current_door_occupants().size() == 4, "door sees player and all residents")
	check(scene._current_door_occupants().size() == 4, "occupants do not accumulate")
	check(scene.transport_status == "ready", "vehicle still initialized")
	while population.navigation.state() != "READY" and Time.get_ticks_msec() < deadline: await physics_frame
	check(population.navigation.state() == "READY", "main pumps actual navigation bake")
	var targets := {}; var origins := {}
	for row: Dictionary in population.residents.snapshot().rows:
		origins[row.source_id] = row.position
		check(row.life_generation == 1 and row.source_id in ["resident_72", "resident_169", "resident_252"], "retained identity " + row.source_id)
		# Explicit QA orders exercise the seam; this is not a replacement agenda.
		for direction: Vector3 in [Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT, Vector3.BACK]:
			var target: Vector3 = row.position + direction * 2.0
			target.y = population.policy.support_height(target, row.source_id, 1)
			if target.is_finite() and population.request_walk(row.source_id, target) >= 0:
				targets[row.source_id] = target; break
		check(targets.has(row.source_id), "source-admitted physical QA target " + row.source_id)
	deadline = Time.get_ticks_msec() + 10000
	var all_arrived := false
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		all_arrived = true
		for row: Dictionary in population.residents.snapshot().rows:
			if row.status != "ARRIVED": all_arrived = false
		if all_arrived: break
	check(all_arrived, "main alone drives real movement to all targets")
	for row: Dictionary in population.residents.snapshot().rows:
		check(row.position.distance_to(origins[row.source_id]) > 1.7, "no stationary fake gait " + row.source_id)
	var interior: Node3D = scene._printshop
	scene._player.set_mouse_captured(true) # Explicit QA control acquisition.
	scene._player.global_position = interior.anchor("publicApproach")
	scene._player.velocity = Vector3.ZERO
	var before: float = interior.door_fraction("public")
	var key := InputEventKey.new(); key.physical_keycode = KEY_E; key.pressed = true
	scene._unhandled_input(key)
	check(population.navigation.state() == "DOOR_TRANSITION", "root E invalidates paths before door motion")
	check(interior.door_fraction("public") == before, "no first-frame door rotation before invalidation")
	await physics_frame; await physics_frame
	for row: Dictionary in population.residents.snapshot().rows:
		check(row.status == "STALE", "old resident path stops on door change " + row.source_id)
	deadline = Time.get_ticks_msec() + 7000
	while population.navigation.state() != "READY" and Time.get_ticks_msec() < deadline: await physics_frame
	check(population.navigation.state() == "READY", "root publishes settled door geometry")
	var snapshot: Dictionary = population.snapshot()
	scene.free()
	check(population.status == "disposed", "main disposes population and owned nav")
	print(JSON.stringify({"checks": checks, "failures": failures, "population": snapshot, "scope": "actual main headless; explicit QA orders, not autonomous agenda or GPU acceptance"}))
	quit(0 if failures.is_empty() else 1)
