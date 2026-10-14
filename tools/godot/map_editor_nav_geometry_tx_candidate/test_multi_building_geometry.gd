extends SceneTree
const Geometry = preload("res://scripts/map_editor/nav_geometry_receipt.gd")
const Shadow = preload("res://scripts/map_editor/shadow_navigation_owner.gd")
const Tx = preload("res://scripts/map_editor/ordinary_building_tx.gd")
const Inventory = preload("res://scripts/map_editor/native_building_inventory.gd")
const HOUSE_012 := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-012"
const HOUSE_013 := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"
var checks := 0
var failures: Array[String] = []
var geometry := Geometry.new()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void: call_deferred("run")

func selected_fingerprint(tx: RefCounted) -> Array:
	var inventory := Inventory.new()
	var rows: Array = inventory.fingerprint(tx._row.visual)
	for body: StaticBody3D in tx._row.native_sibling_bodies: rows.append_array(inventory.fingerprint(body))
	return rows

func release_population(pop: RefCounted, receipt: Dictionary) -> bool:
	var ticket: Dictionary = pop.prepare_editor_resume_atomic(receipt)
	if ticket.is_empty() or pop.commit_editor_resume_atomic(ticket).is_empty() or not pop.finalize_editor_resume_atomic(ticket): return false
	paused = false
	if not pop.flush_editor_resume_atomic(ticket): paused = true; return false
	paused = true
	return true

func apply_action(main: Node3D, tx: RefCounted, source_id: String, action: String, value: Variant, label: String) -> bool:
	var pop: RefCounted = main.preview_population
	var nav: RefCounted = pop.navigation
	var proposal: Dictionary = geometry.inspect(main,source_id,action,value)
	check(proposal.get("ok",false), label + ":geometry-proposed")
	if not proposal.get("ok",false): return false
	var old_backend: RefCounted = nav._backend
	var receipt: Dictionary = pop.begin_editor_pause(main)
	check(not receipt.is_empty(),label + ":three-resident-pause")
	if receipt.is_empty(): return false
	paused = true
	await process_frame
	var shadow := Shadow.new()
	var start: Dictionary = shadow.begin(main,proposal,receipt)
	check(start.get("ok",false),label + ":shadow-started-paused")
	if not start.get("ok",false): return false
	var ticket: int = start.ticket
	var deadline := Time.get_ticks_msec() + 20000
	var ready: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		ready = shadow.poll_ready(ticket)
		if not ready.get("ok",false) or ready.get("map_ready",false): break
		await process_frame
	check(ready.get("ok",false) and ready.get("map_ready",false),label + ":native-map-ready-paused")
	if not ready.get("map_ready",false): return false
	var changed: Dictionary = tx._mutate(action,value) if action not in ["undo","redo","restore"] else {"ok":true}
	if action in ["undo","redo","restore"]: tx._restore(value)
	check(changed.get("ok",false),label + ":scene-mutated")
	var current: Dictionary = geometry.current_stream(main,source_id)
	check(current.get("ok",false) and current.get("faces",PackedVector3Array()) == proposal.proposed_geometry,label + ":exact-current-collision-soup")
	if not current.get("ok",false) or current.faces != proposal.proposed_geometry: return false
	check(release_population(pop,receipt),label + ":population-atomic-release")
	var swapped: Dictionary = shadow.commit_after_released_pause(ticket)
	check(swapped.get("ok",false) and nav._backend != old_backend and nav._static == proposal.proposed_geometry,label + ":ready-map-swapped")
	if not swapped.get("ok",false): return false
	paused = false
	var committed: Dictionary = shadow.finalize(ticket)
	check(committed.get("ok",false) and old_backend._disposed and nav._backend.state() == "READY",label + ":old-map-retired")
	return committed.get("ok",false)

func run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.preview_resident_walk_enabled = false
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 20000
	while (not main.preview_ready or main.preview_population == null or main.preview_population.navigation.state() != "READY") and Time.get_ticks_msec() < deadline: await physics_frame
	check(main.preview_ready and main.population_status == "ready" and main.preview_population.occupants().size() == 3,"actual-main-three-residents-ready")
	if not main.preview_ready or main.population_status != "ready": main.free(); finish(); return
	await process_frame
	var ordinary: Array[String] = [
		"REBUILD-VISUAL-old_town_narrow_townhouse_v1-013",
		"REBUILD-VISUAL-old_town_narrow_townhouse_v1-005",
		"REBUILD-VISUAL-gun_shop-001", "REBUILD-VISUAL-pawnshop-001",
		"REBUILD-VISUAL-old_town_narrow_townhouse_v1-004",
		"REBUILD-VISUAL-old_town_narrow_townhouse_v1-012",
		"REBUILD-VISUAL-old_town_narrow_townhouse_v1-007"]
	var total_siblings := 0
	for source_id: String in ordinary:
		var plan: Dictionary = geometry.inspect(main,source_id,"move",Vector3(0.25,0,0))
		check(plan.get("ok",false),"ordinary-source-proposed:" + source_id)
		if plan.get("ok",false): total_siblings += plan.sibling_indices.size()
	check(total_siblings == 16,"all-seven-ordinary-source-colliders-accounted")
	check(not geometry.inspect(main,"REBUILD-VISUAL-print_shop-001","move",Vector3(1,0,0)).get("ok",false),"printshop-protected-source-refused")
	var tx012 := Tx.new()
	check(tx012.select(main,HOUSE_012).get("ok",false),"house012-selected")
	var original012: Dictionary = tx012._capture_state()
	var fingerprint012: Array = selected_fingerprint(tx012)
	if not await apply_action(main,tx012,HOUSE_012,"rotate",deg_to_rad(27.0),"012-rotate"): main.free(); finish(); return
	var rotated012: Dictionary = tx012._capture_state()
	var rotated_fingerprint012: Array = selected_fingerprint(tx012)
	check(rotated_fingerprint012 != fingerprint012,"012-visible-and-collider-yaw-changed")
	if not await apply_action(main,tx012,HOUSE_012,"undo",original012,"012-undo"): main.free(); finish(); return
	check(selected_fingerprint(tx012) == fingerprint012,"012-undo-exact-model-material-shape-and-ID")
	if not await apply_action(main,tx012,HOUSE_012,"redo",rotated012,"012-redo"): main.free(); finish(); return
	check(selected_fingerprint(tx012) == rotated_fingerprint012,"012-redo-exact-rotated-root-and-colliders")
	var tx013 := Tx.new()
	check(tx013.select(main,HOUSE_013).get("ok",false),"house013-selected-after-other-building-redo")
	var original013: Dictionary = tx013._capture_state()
	var fingerprint013: Array = selected_fingerprint(tx013)
	if not await apply_action(main,tx013,HOUSE_013,"move",Vector3(0.8,0,-0.35),"013-move"): main.free(); finish(); return
	var moved013: Dictionary = tx013._capture_state()
	var moved_fingerprint013: Array = selected_fingerprint(tx013)
	if not await apply_action(main,tx013,HOUSE_013,"delete",null,"013-delete"): main.free(); finish(); return
	check(not tx013._row.visual.visible,"013-deleted-visual-hidden-source-retained")
	if not await apply_action(main,tx013,HOUSE_013,"undo",moved013,"013-undo-delete"): main.free(); finish(); return
	check(selected_fingerprint(tx013) == moved_fingerprint013,"013-undo-delete-exact-moved-state")
	if not await apply_action(main,tx013,HOUSE_013,"undo",original013,"013-undo-move"): main.free(); finish(); return
	check(selected_fingerprint(tx013) == fingerprint013,"013-undo-move-exact-original-state")
	check(main.preview_population.occupants().size() == 3 and main.preview_population.navigation.state() == "READY","three-residents-and-final-map-remain-ready")
	main.free()
	finish()

func finish() -> void:
	if paused: paused = false
	print(JSON.stringify({"suite":"all-ordinary-building-nav-geometry","checks":checks,"failures":failures,"supported_buildings":7,"real_residents":3,"production_modified":false,"gpu":false,"ordinary_tx_token_admitted":false}))
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
