extends SceneTree
## Opt-in, unrun actual-main fixture. This tests only the three preview residents.
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled = true
	scene.preview_resident_walk_enabled = false
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 20000
	while (not scene.preview_ready or scene.preview_population == null or scene.preview_population.navigation == null or scene.preview_population.navigation.state() != "READY") and Time.get_ticks_msec() < deadline:
		await physics_frame
	var population: RefCounted = scene.preview_population
	check(scene.preview_ready and population != null and scene.population_status == "ready", "actual preview population ready")
	if population == null or scene.population_status != "ready":
		print(JSON.stringify({"checks":checks,"failures":failures,"scope":"three-preview-resident seam only"}))
		scene.free(); quit(1); return
	check(population.occupants().size() == 3, "exact local cohort")
	var receipt: Dictionary = population.begin_editor_pause(scene)
	check(not receipt.is_empty(), "owner-held population and nav admission")
	if receipt.is_empty():
		print(JSON.stringify({"checks":checks,"failures":failures,"scope":"three-preview-resident seam only"}))
		scene.free(); quit(1); return
	paused = true
	check(population.verify_editor_pause(receipt), "immediate exact verification")
	for i in 3: await process_frame
	check(population.verify_editor_pause(receipt), "held across process frames")
	paused = false
	check(population.end_editor_pause(receipt), "synchronous end before physics")
	check(not population.end_editor_pause(receipt), "stale receipt rejected")
	await physics_frame
	var denied_receipt: Dictionary = population.begin_editor_pause(scene)
	check(not denied_receipt.is_empty(), "second lease admitted")
	if not denied_receipt.is_empty():
		paused = true
		var before: Dictionary = population.residents.snapshot()
		check(population.residents.request_walk("resident_72", Vector3.ZERO) == -1, "direct host mutator rejected")
		check(population.residents.snapshot() == before, "direct host mutator did not change resident")
		check(not population.verify_editor_pause(denied_receipt), "rejected mutator faults receipt")
		paused = false
		check(not population.end_editor_pause(denied_receipt), "faulted lease cannot resume")
		paused = true
	var result := {"checks":checks,"failures":failures,"scope":"three-preview-resident owner seam; not full cohort, active routes, source agenda, or K acceptance"}
	scene.free()
	paused = false
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
