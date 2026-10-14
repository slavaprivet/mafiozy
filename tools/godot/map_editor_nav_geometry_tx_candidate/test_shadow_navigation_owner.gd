extends SceneTree
const Geometry = preload("res://scripts/map_editor/nav_geometry_receipt.gd")
const Shadow = preload("res://scripts/map_editor/shadow_navigation_owner.gd")
const Tx = preload("res://scripts/map_editor/ordinary_building_tx.gd")
const Inventory = preload("res://scripts/map_editor/native_building_inventory.gd")
const HOUSE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void: call_deferred("run")

func selected_fingerprint(tx: RefCounted, inspector: RefCounted) -> Array:
	var rows: Array = inspector.fingerprint(tx._row.visual)
	for body: StaticBody3D in tx._row.native_sibling_bodies: rows.append_array(inspector.fingerprint(body))
	return rows

func release_population(pop: RefCounted, receipt: Dictionary) -> bool:
	var ticket: Dictionary = pop.prepare_editor_resume_atomic(receipt)
	if ticket.is_empty(): return false
	if pop.commit_editor_resume_atomic(ticket).is_empty(): return false
	if not pop.finalize_editor_resume_atomic(ticket): return false
	paused = false
	if not pop.flush_editor_resume_atomic(ticket):
		paused = true
		return false
	paused = true # Same call stack; no next physics tick before nav map swap.
	return true

func run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.preview_resident_walk_enabled = false
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 20000
	while (not main.preview_ready or main.preview_population == null or main.preview_population.navigation.state() != "READY") and Time.get_ticks_msec() < deadline:
		await physics_frame
	check(main.preview_ready and main.population_status == "ready", "real-main-three-residents-ready")
	if not main.preview_ready or main.population_status != "ready": main.free(); finish(); return
	await process_frame
	var pop: RefCounted = main.preview_population
	var nav: RefCounted = pop.navigation
	var old_backend: RefCounted = nav._backend
	var old_map: RID = old_backend.map_rid()
	var tx := Tx.new()
	check(tx.select(main, HOUSE).get("ok", false), "real-ordinary-building-selected")
	var inspector := Inventory.new()
	var original := selected_fingerprint(tx, inspector)
	var old_faces: PackedVector3Array = nav._static.duplicate()
	var geometry := Geometry.new()
	var proposal: Dictionary = geometry.inspect(main, HOUSE, "move", Vector3(1.25, 0, -0.5))
	check(proposal.get("ok", false), "exact-source-move-proposal")
	var pause_receipt: Dictionary = pop.begin_editor_pause(main)
	check(not pause_receipt.is_empty(), "real-resident-policy-nav-pause-acquired")
	if pause_receipt.is_empty(): main.free(); finish(); return
	paused = true
	await process_frame
	check(pop.verify_editor_pause(pause_receipt), "three-owner-pause-verifies")
	var shadow := Shadow.new()
	var missing_lease: Dictionary = shadow.begin(main,proposal)
	check(not missing_lease.get("ok",false) and missing_lease.get("error","") == "PAUSED_TREE_REQUIRES_REAL_RESIDENT_LEASE", "paused-bake-refuses-missing-resident-lease")
	var stale_receipt: Dictionary = pause_receipt.duplicate(true)
	stale_receipt.serial = -1
	var stale_lease: Dictionary = shadow.begin(main,proposal,stale_receipt)
	check(not stale_lease.get("ok",false) and stale_lease.get("error","") == "PAUSED_TREE_REQUIRES_REAL_RESIDENT_LEASE", "paused-bake-refuses-stale-resident-lease")
	var started: Dictionary = shadow.begin(main, proposal, pause_receipt)
	check(started.get("ok", false) and not started.get("map_ready", true), "async-shadow-bake-submitted-while-tree-paused")
	if not started.get("ok", false): main.free(); finish(); return
	var ticket: int = started.ticket
	var ready: Dictionary = {}
	var bake_deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < bake_deadline:
		ready = shadow.poll_ready(ticket)
		if not ready.get("ok", false) or ready.get("map_ready", false): break
		await process_frame
	check(ready.get("ok", false) and ready.get("map_ready", false) and int(ready.get("iteration",0)) > 0, "paused-shadow-map-native-ready-receipt")
	if not ready.get("map_ready", false): shadow.abort(ticket); main.free(); finish(); return
	check(old_backend._held_completions.is_empty() and shadow._shadow._held_completions.is_empty() and shadow._shadow._baking_token == 0, "ready-receipt-has-no-stale-bake-callback-tail")
	check(nav._backend == old_backend and nav._static == old_faces and selected_fingerprint(tx, inspector) == original, "bake-does-not-touch-live-scene-or-map")
	var before_scene: Dictionary = tx._capture_state()
	check(tx._mutate("move", Vector3(1.25,0,-0.5)).get("ok",false), "fixture-applies-real-root-and-two-siblings")
	check(geometry.current_stream(main,HOUSE).get("faces",PackedVector3Array()) == proposal.proposed_geometry, "new-colliders-exactly-match-ready-map")
	var denied_early: Dictionary = shadow.commit_after_released_pause(ticket)
	check(not denied_early.get("ok",false) and denied_early.get("error","") == "RESIDENT_NAV_PAUSE_NOT_FULLY_RELEASED", "map-swap-refused-before-population-release")
	check(release_population(pop,pause_receipt), "resident-atomic-finalize-and-flush")
	var swapped: Dictionary = shadow.commit_after_released_pause(ticket)
	check(swapped.get("ok", false) and swapped.get("navigation_swap_committed",false), "ready-map-swapped-under-root-pause")
	check(nav._backend != old_backend and nav._backend.state() == "READY" and nav._static == proposal.proposed_geometry, "live-host-points-at-ready-new-map")
	check(old_map.is_valid() and old_backend.map_rid() == old_map, "old-map-retained-for-reversible-rollback")
	paused = false
	await process_frame
	var second: Dictionary = pop.begin_editor_pause(main)
	check(not second.is_empty(), "three-resident-pause-reacquired-for-undo")
	if not second.is_empty():
		paused = true
		tx._restore(before_scene)
		check(geometry.current_stream(main,HOUSE).get("faces",PackedVector3Array()) == old_faces, "scene-restored-before-map-rollback")
		check(release_population(pop,second), "undo-population-atomic-release")
		var rolled: Dictionary = shadow.rollback_after_scene_restore(ticket)
		check(rolled.get("ok",false) and nav._backend == old_backend and nav._static == old_faces, "old-map-and-source-geometry-rolled-back")
		check(selected_fingerprint(tx, inspector) == original, "root-mesh-material-and-colliders-preserved")
	paused = false
	main.free()
	finish()

func finish() -> void:
	print(JSON.stringify({"suite":"ordinary-building-shadow-nav-owner","checks":checks,"failures":failures,"resident_count":3,"production_modified":false,"gpu":false,"ordinary_tx_token_admitted":false}))
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
