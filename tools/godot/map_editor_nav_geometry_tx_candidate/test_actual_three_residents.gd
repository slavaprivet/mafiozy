extends SceneTree
const Receipt = preload("res://scripts/map_editor/nav_geometry_receipt.gd")
const Tx = preload("res://scripts/map_editor/ordinary_building_tx.gd")
const Inventory = preload("res://scripts/map_editor/native_building_inventory.gd")
const HOUSE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "pinned-actual-main-scene-loads")
	if scene == null: finish(); return
	var main: Node3D = scene.instantiate()
	root.add_child(main)
	for _frame in 240:
		if bool(main.get("preview_ready")): break
		await physics_frame
	check(bool(main.get("preview_ready")), "actual-main-ready")
	if not bool(main.get("preview_ready")): main.free(); finish(); return
	var pop: RefCounted = main.get("preview_population")
	check(pop != null and pop.occupants().size() == 3, "actual-three-source-residents")
	var tx := Tx.new()
	var selection: Dictionary = tx.select(main, HOUSE)
	check(selection.get("ok", false) and selection.get("sibling_bodies", -1) == 2, "ordinary-transaction-selects-real-house-and-siblings")
	var inventory := Inventory.new()
	var before := inventory.fingerprint(main)
	var nav_before: PackedVector3Array = pop.navigation._static.duplicate()
	var receipt := Receipt.new()
	var move_plan: Dictionary = receipt.inspect(main, HOUSE, "move", Vector3(1.25, 0, -0.5))
	check(move_plan.get("ok", false) and move_plan.get("read_only", false) and not move_plan.get("owner_lease", true), "real-collision-move-plan-is-read-only")
	if move_plan.get("ok", false):
		check(move_plan.old_geometry == nav_before, "old-stream-exact-native-nav-capture")
		check(move_plan.proposed_geometry != nav_before and move_plan.building_faces_before == move_plan.building_faces_after, "proposed-move-replaces-exact-building-faces")
		check(move_plan.sibling_indices == [0, 1], "source-collision-indices-preserved")
	var delete_plan: Dictionary = receipt.inspect(main, HOUSE, "delete", null)
	check(delete_plan.get("ok", false), "real-collision-delete-plan")
	if delete_plan.get("ok", false):
		check(delete_plan.old_geometry == nav_before and delete_plan.building_faces_after == 0, "delete-omits-selected-source-faces")
		check(delete_plan.old_faces - delete_plan.new_faces == delete_plan.building_faces_before, "delete-preserves-every-other-nav-face")
	check(inventory.fingerprint(main) == before and pop.navigation._static == nav_before, "read-only-plans-do-not-change-game-or-nav")
	var denied: Dictionary = receipt.acquire_owner_lease(move_plan)
	check(not denied.get("ok", false) and not denied.get("owner_lease", true) and denied.get("error", "") == "NO_ATOMIC_NAV_PUBLISH_AND_READY_RECEIPT_UNDER_EDITOR_PAUSE", "no-false-owner-lease-or-resume")
	main.free()
	finish()

func finish() -> void:
	print(JSON.stringify({"suite":"ordinary-building-real-nav-geometry","checks":checks,"failures":failures,"owner_lease_admitted":false,"production_modified":false,"gpu":false}))
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
