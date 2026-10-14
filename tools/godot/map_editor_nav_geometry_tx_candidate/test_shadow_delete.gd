extends SceneTree
const Geometry = preload("res://scripts/map_editor/nav_geometry_receipt.gd")
const Shadow = preload("res://scripts/map_editor/shadow_navigation_owner.gd")
const Tx = preload("res://scripts/map_editor/ordinary_building_tx.gd")
const HOUSE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void: call_deferred("run")

func release_population(pop: RefCounted, receipt: Dictionary) -> bool:
	var ticket: Dictionary = pop.prepare_editor_resume_atomic(receipt)
	if ticket.is_empty() or pop.commit_editor_resume_atomic(ticket).is_empty() or not pop.finalize_editor_resume_atomic(ticket): return false
	paused = false
	if not pop.flush_editor_resume_atomic(ticket): paused = true; return false
	paused = true
	return true

func run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.preview_resident_walk_enabled = false
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 20000
	while (not main.preview_ready or main.preview_population == null or main.preview_population.navigation.state() != "READY") and Time.get_ticks_msec() < deadline: await physics_frame
	check(main.preview_ready and main.population_status == "ready", "actual-three-residents-and-old-map-ready")
	if not main.preview_ready or main.population_status != "ready": main.free(); finish(); return
	await process_frame
	var pop: RefCounted = main.preview_population
	var nav: RefCounted = pop.navigation
	var old_backend: RefCounted = nav._backend
	var tx := Tx.new()
	check(tx.select(main,HOUSE).get("ok",false), "selected-original-house")
	var geometry := Geometry.new()
	var proposal: Dictionary = geometry.inspect(main,HOUSE,"delete",null)
	check(proposal.get("ok",false) and proposal.building_faces_after == 0, "delete-excludes-only-house-collision-faces")
	var receipt: Dictionary = pop.begin_editor_pause(main)
	check(not receipt.is_empty(), "real-population-pause")
	if receipt.is_empty(): main.free(); finish(); return
	paused = true
	await process_frame
	var shadow := Shadow.new()
	var started: Dictionary = shadow.begin(main,proposal,receipt)
	check(started.get("ok",false), "delete-shadow-bake-under-pause")
	if not started.get("ok",false): main.free(); paused = false; finish(); return
	var ticket: int = started.ticket
	deadline = Time.get_ticks_msec() + 20000
	var ready: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		ready = shadow.poll_ready(ticket)
		if not ready.get("ok",false) or ready.get("map_ready",false): break
		await process_frame
	check(ready.get("ok",false) and ready.get("map_ready",false), "delete-native-map-ready-while-paused")
	if not ready.get("map_ready",false): shadow.abort(ticket); main.free(); paused = false; finish(); return
	check(tx._mutate("delete",null).get("ok",false), "fixture-hides-root-and-disables-two-real-colliders")
	check(geometry.current_stream(main,HOUSE).get("faces",PackedVector3Array()) == proposal.proposed_geometry, "deleted-scene-matches-shadow-source")
	check(release_population(pop,receipt), "population-atomic-release")
	var swapped: Dictionary = shadow.commit_after_released_pause(ticket)
	check(swapped.get("ok",false) and nav._backend != old_backend and nav._static == proposal.proposed_geometry, "delete-map-swapped-before-next-physics")
	paused = false
	var final: Dictionary = shadow.finalize(ticket)
	check(final.get("ok",false) and old_backend._disposed and nav._backend.state() == "READY", "old-native-map-retired-after-resume")
	check(not tx._row.visual.visible and str(tx._row.visual.get_meta("source_id","")) == HOUSE, "visual-source-id-retained-hidden")
	for body: StaticBody3D in tx._row.native_sibling_bodies:
		check(body.collision_layer == 0 and str(body.get_meta("source_id","")) == HOUSE, "deleted-collider-source-id-retained")
	main.free()
	finish()

func finish() -> void:
	print(JSON.stringify({"suite":"ordinary-building-shadow-nav-delete","checks":checks,"failures":failures,"resident_count":3,"production_modified":false,"gpu":false,"ordinary_tx_token_admitted":false}))
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
