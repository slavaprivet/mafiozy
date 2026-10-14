extends SceneTree
## Unrun opt-in negative fixture on the real checkpoint three-resident scene.
## FaultPolicy is a deliberate failure injector only for the rollback branch;
## it is not a resident/source-authority implementation or a positive lease.
class FaultPolicy extends RefCounted:
	var resident: RefCounted
	func access_version() -> int: return 1
	func begin_editor_pause(_owner: Node) -> Dictionary:
		resident._editor_pause_fault = true
		return {}
	func dispose() -> void: pass

var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func spawn() -> Node3D:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled = true
	scene.preview_resident_walk_enabled = false
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if scene.preview_ready and scene.preview_population != null and scene.preview_population.navigation != null and scene.preview_population.navigation.state() == "READY": break
		await physics_frame
	if not scene.preview_ready or scene.preview_population == null or scene.population_status != "ready" or scene.preview_population.navigation.state() != "READY":
		failures.append("actual_checkpoint_three_residents_or_nav_not_ready")
		scene.free()
		return null
	return scene
func drop(scene: Node3D) -> void:
	if is_instance_valid(scene): scene.free()
	paused = false
func run() -> void:
	var scene: Node3D = await spawn()
	if scene == null: print(JSON.stringify({"checks":checks,"failures":failures})); quit(1); return
	var population: RefCounted = scene.preview_population
	var receipt: Dictionary = population.begin_editor_pause(scene)
	check(not receipt.is_empty(), "policy-disposal lease acquired")
	if not receipt.is_empty():
		paused = true
		population.policy.dispose()
		check(not population.verify_editor_pause(receipt), "policy disposal invalidates lease")
		paused = false
		check(not population.end_editor_pause(receipt) and paused, "policy disposal ends in terminal HOLD")
		check(population.navigation._editor_pause_active, "policy failure does not release nav")
	drop(scene)
	scene = await spawn()
	if scene == null: print(JSON.stringify({"checks":checks,"failures":failures})); quit(1); return
	population = scene.preview_population
	receipt = population.begin_editor_pause(scene)
	check(not receipt.is_empty(), "resident-drift lease acquired")
	if not receipt.is_empty():
		paused = true
		var body: CharacterBody3D = population.residents._records["resident_72"].body
		body.position.x += 0.5
		paused = false
		check(not population.end_editor_pause(receipt) and paused, "resident drift preflight terminal HOLD")
		check(population.navigation._editor_pause_active, "resident drift keeps nav held before replay")
	drop(scene)
	scene = await spawn()
	if scene == null: print(JSON.stringify({"checks":checks,"failures":failures})); quit(1); return
	population = scene.preview_population
	receipt = population.begin_editor_pause(scene)
	check(not receipt.is_empty(), "dependency-swap lease acquired")
	if not receipt.is_empty():
		paused = true
		population.residents._navigation = RefCounted.new()
		check(not population.verify_editor_pause(receipt), "resident navigation dependency swap detected")
		paused = false
		check(not population.end_editor_pause(receipt) and paused, "dependency swap terminal HOLD")
	drop(scene)
	scene = await spawn()
	if scene == null: print(JSON.stringify({"checks":checks,"failures":failures})); quit(1); return
	population = scene.preview_population
	receipt = population.begin_editor_pause(scene)
	check(not receipt.is_empty(), "queued-body lease acquired")
	if not receipt.is_empty():
		paused = true
		population.residents._records["resident_72"].body.queue_free()
		check(not population.verify_editor_pause(receipt), "queued deletion detected before free")
		paused = false
		check(not population.end_editor_pause(receipt) and paused, "queued deletion terminal HOLD")
	drop(scene)
	scene = await spawn()
	if scene == null: print(JSON.stringify({"checks":checks,"failures":failures})); quit(1); return
	population = scene.preview_population
	population.navigation._geometry_valid = false # Force nav begin refusal after resident/policy acquisition.
	receipt = population.begin_editor_pause(scene)
	check(receipt.is_empty(), "nav begin refused")
	check(not paused and not population.residents._editor_pause_active and not population.policy._editor_pause_active and not population._editor_pause_terminal_hold, "failed nav begin rolls resident/policy back under live tree")
	drop(scene)
	scene = await spawn()
	if scene == null: print(JSON.stringify({"checks":checks,"failures":failures})); quit(1); return
	population = scene.preview_population
	receipt = population.begin_editor_pause(scene)
	check(not receipt.is_empty(), "queue-drift lease acquired")
	if not receipt.is_empty():
		paused = true
		population.navigation._queue._stats.admitted += 1 # Direct queue-state drift.
		check(not population.verify_editor_pause(receipt), "queue drift invalidates nav composition")
		paused = false
		check(not population.end_editor_pause(receipt) and paused, "queue drift forces terminal HOLD")
		check(population.navigation._backend._editor_paused and population.navigation._queue._editor_pause_active, "queue drift does not release backend or queue")
	drop(scene)
	scene = await spawn()
	if scene == null: print(JSON.stringify({"checks":checks,"failures":failures})); quit(1); return
	population = scene.preview_population
	var fault := FaultPolicy.new()
	fault.resident = population.residents
	# The resident's admission/support callables still point to the original
	# policy. Retain it so the injected failure occurs AFTER resident acquire.
	var original_policy: RefCounted = population.policy
	population.policy = fault # Negative injection: policy begin faults earlier resident lease.
	receipt = population.begin_editor_pause(scene)
	check(receipt.is_empty(), "injected policy begin refused")
	check(paused and population._editor_pause_terminal_hold, "failed rollback cannot leave live gameplay")
	check(original_policy != null, "original callback owner retained during injection")
	drop(scene)
	print(JSON.stringify({"checks":checks,"failures":failures,"scope":"negative protocol only; three preview residents, no full cohort or K"}))
	quit(0 if failures.is_empty() else 1)
