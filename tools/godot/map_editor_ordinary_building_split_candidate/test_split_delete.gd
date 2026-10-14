extends SceneTree
const Tx = preload("res://scripts/map_editor/split_ordinary_building_tx.gd")
const Terrain = preload("res://scripts/map_editor/terrain_owner.gd")
const Traffic = preload("res://scripts/map_editor/traffic_owner.gd")
const HOUSE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-012"
const MOVE_DELTA := Vector3(1.5, 0, -0.5)

class PauseToken extends RefCounted:
	var population: RefCounted
	var receipt: Dictionary
	func _init(owner: RefCounted, pause_receipt: Dictionary) -> void:
		population = owner
		receipt = pause_receipt.duplicate(true)
	func verify() -> Dictionary:
		var okay: bool = population != null and population.verify_editor_pause(receipt)
		return {"ok": okay, "ready": okay, "pending": false}
	func commit(_change: Dictionary) -> Dictionary: return verify()
	func rollback() -> Dictionary: return verify()

class FaultTrafficToken extends RefCounted:
	var actual: RefCounted
	func _init(token: RefCounted) -> void: actual = token
	func verify() -> Dictionary: return actual.verify()
	func commit(change: Dictionary) -> Dictionary:
		var published: Dictionary = actual.commit(change)
		if published.get("ok", false): return {"ok": false, "ready": false, "pending": false, "error": "injected-after-publication"}
		return published
	func rollback() -> Dictionary: return actual.rollback()

var checks := 0
var failures: Array[String] = []
var _action := "delete"

func _initialize() -> void: call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func release_population(population: RefCounted, receipt: Dictionary) -> bool:
	var ticket: Dictionary = population.prepare_editor_resume_atomic(receipt)
	if ticket.is_empty() or population.commit_editor_resume_atomic(ticket).is_empty(): return false
	if not population.finalize_editor_resume_atomic(ticket): return false
	paused = false
	if not population.flush_editor_resume_atomic(ticket):
		paused = true
		return false
	paused = true
	return true

func traffic_fault_provider(request: Dictionary, traffic: RefCounted) -> Dictionary:
	var answer: Dictionary = traffic.lease(request)
	if answer.get("ok", false): answer.token = FaultTrafficToken.new(answer.token)
	return answer

func run() -> void:
	var action := "move" if OS.get_cmdline_user_args().has("--move") else "delete"
	var fault := OS.get_cmdline_user_args().has("--fault")
	_action = action
	var value: Variant = MOVE_DELTA if action == "move" else null
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.preview_resident_walk_enabled = false
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 20000
	while (not main.preview_ready or main.preview_population == null or main.preview_population.navigation.state() != "READY") and Time.get_ticks_msec() < deadline:
		await physics_frame
	check(main.preview_ready and main.population_status == "ready", "actual-main-three-residents-ready")
	if not main.preview_ready or main.population_status != "ready": main.free(); finish(); return
	var tx := Tx.new()
	check(tx.select(main, HOUSE).get("ok", false), "ordinary-house-bound-to-actual-source")
	if tx._state != "SELECTED_READONLY": main.free(); finish(); return
	var original: Array = tx._capture_fingerprint()
	var original_frame: Transform3D = tx._row.visual.global_transform
	var population: RefCounted = main.preview_population
	var old_backend: RefCounted = population.navigation._backend
	var terrain := Terrain.new()
	var traffic := Traffic.new()
	check(traffic.configure(main).get("ok", false), "real-transport-owner-configured")
	var pause_receipt: Dictionary = population.begin_editor_pause(main)
	check(not pause_receipt.is_empty(), "real-population-pause-acquired")
	if pause_receipt.is_empty(): main.free(); finish(); return
	paused = true
	await process_frame
	check(not tx.begin_split("delete", null, {}).get("ok", false), "missing-pause-receipt-refused")
	check(not tx.begin_split("rotate", 0.2, pause_receipt).get("ok", false), "unimplemented-rotate-refused")
	var opened: Dictionary = tx.begin_split(action, value, pause_receipt)
	print("MAP_EDITOR_SPLIT_OPEN ", JSON.stringify(opened))
	check(opened.get("ok", false) and not opened.get("map_ready", true), "paused-delete-shadow-bake-started")
	if not opened.get("ok", false): main.free(); finish(); return
	var ready: Dictionary = {}
	deadline = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		ready = tx.poll_split_ready()
		if not ready.get("ok", false) or ready.get("map_ready", false): break
		await process_frame
	check(ready.get("ok", false) and ready.get("map_ready", false), "native-shadow-ready-while-paused")
	check(tx._capture_fingerprint() == original and population.navigation._backend == old_backend,
		"bake-leaves-live-building-and-nav-unchanged")
	if not ready.get("map_ready", false): main.free(); finish(); return
	var pause_token := PauseToken.new(population, pause_receipt)
	var leases := {
		"pause": func(_request: Dictionary) -> Dictionary: return {"ok": true, "token": pause_token},
		"terrain": Callable(terrain, "issue").bind(main),
		"traffic": Callable(self, "traffic_fault_provider").bind(traffic) if fault else Callable(traffic, "lease")
	}
	var scene_commit: Dictionary = tx.commit_split_scene(leases)
	print("MAP_EDITOR_SPLIT_SCENE ", JSON.stringify(scene_commit), " traffic_clear=", traffic.last_clear_error)
	if fault:
		check(not scene_commit.get("ok", false) and scene_commit.get("rolled_back", false),
			"post-publication-traffic-fault-rolls-back-scene-and-owners")
		check(tx._capture_fingerprint() == original and tx._history.is_empty() and traffic._revision == 0 and traffic._published.is_empty(),
			"failed-transaction-retains-original-geometry-history-and-traffic")
		check(population.navigation._backend == old_backend, "failed-transaction-retains-original-navigation")
		check(tx.abort_split_before_scene_commit().get("ok", false), "ready-shadow-aborted-after-clean-rollback")
		check(release_population(population, pause_receipt), "resident-owners-released-after-clean-rollback")
		paused = false
		leases.clear(); pause_token = null; tx = null; terrain = null; traffic = null; population = null; old_backend = null
		main.free()
		await process_frame
		finish()
		return
	check(scene_commit.get("ok", false) and scene_commit.get("population_release_required", false),
		"root-and-sibling-colliders-staged-with-real-terrain-traffic")
	if not scene_commit.get("ok", false):
		tx.abort_split_before_scene_commit()
		release_population(population, pause_receipt)
		paused = false
		main.free()
		finish()
		return
	check(tx._row.visual.visible == (action == "move") and traffic._revision == 1 and tx._history.is_empty(),
		"scene-and-traffic-staged-but-undo-history-not-published")
	if action == "move":
		check(tx._row.visual.global_transform.origin == original_frame.origin + MOVE_DELTA,
			"actual-building-root-moved-with-source-delta")
	check(not tx.publish_split_after_population_release().get("ok", false), "early-nav-swap-refused")
	check(release_population(population, pause_receipt), "atomic-population-release-and-flush")
	var swapped: Dictionary = tx.publish_split_after_population_release()
	check(swapped.get("ok", false) and swapped.get("navigation_swap_committed", false),
		"ready-navigation-map-published-after-release")
	check(population.navigation._backend != old_backend, "real-nav-backend-swapped")
	paused = false
	var done: Dictionary = tx.finish_split_after_resume()
	check(done.get("ok", false) and done.get("history", 0) == 1 and tx._deleted == (action == "delete"),
		"transaction-and-history-finalized-after-resume")
	leases.clear()
	pause_token = null
	tx = null
	terrain = null
	traffic = null
	population = null
	old_backend = null
	main.free()
	await process_frame
	finish()

func finish() -> void:
	print("MAP_EDITOR_SPLIT_", _action.to_upper(), " ", JSON.stringify({"checks": checks, "failures": failures,
		"production_modified": false, "gpu": false, "k_integrated": false}))
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
