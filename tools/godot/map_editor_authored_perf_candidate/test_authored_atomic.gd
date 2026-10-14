extends "res://test_authored_combined.gd"
const Atomic = preload("res://scripts/map_editor/atomic_map_import.gd")

class CommitRejectGround extends "res://ground_document.gd":
	var reject_commit := false
	func commit_prepared_patch(prepared: Dictionary) -> Dictionary:
		if reject_commit: return {"ok": false, "error": "Pure second-domain commit refusal"}
		return super.commit_prepared_patch(prepared)

var paused_owner := true
var ground_nav_ok := true
var joint_prepare_ok := true
var joint_finalize_ok := true
var water_apply_ok := true
var water_finalize_ok := true
var water_rollback_ok := true
var joint_rollback_ok := true
var fail_phase := ""
var lose_lease_phase := ""
var reenter_phase := ""
var current_atomic: RefCounted
var current_target: Dictionary
var current_bundle: Dictionary
var expected_objects: Dictionary
var expected_ground: Dictionary
var object_notifications := 0
var joint_notifications := 0
var reentry_checks := 0
var staged_proofs := 0
var nav_state := "idle"

func lease() -> bool:
	return paused_owner

func water(phase: String, _delta: Dictionary) -> Dictionary:
	return {"ok": (phase != "apply" or water_apply_ok) and (phase != "finalize" or water_finalize_ok) and (phase != "rollback" or water_rollback_ok), "receipt": {"owner": "explicit-water-stage-test"}}

func navigation(_delta: Dictionary) -> Dictionary:
	return {"ok": ground_nav_ok}

func joint_navigation(phase: String, payload: Dictionary) -> Dictionary:
	if phase == "prepare":
		var house: Node3D = current_target.registry._entries[current_target.house_id].root.get_ref()
		for row: Dictionary in payload.objects.objects:
			if row.id == current_target.house_id:
				check(house.global_transform.is_equal_approx(current_target.registry.decode_transform(row.transform)), "Joint navigation sees actual staged native house geometry")
		check(current_target.controller.document.to_dictionary() != payload.objects, "Both models remain unpublished during navigation staging")
		nav_state = "prepared"
		staged_proofs += 1
		return {"ok": joint_prepare_ok, "receipt": {"stage": staged_proofs}}
	if phase == "rollback":
		nav_state = "rolled_back" if joint_rollback_ok else "rollback_pending"
		return {"ok": joint_rollback_ok}
	if phase == "finalize":
		if joint_finalize_ok: nav_state = "finalized"
		return {"ok": joint_finalize_ok}
	return {"ok": false}

func attempt_reentry() -> void:
	check(not current_atomic.install_bundle(current_bundle).ok, "Nested combined import blocked")
	check(not current_target.controller.handle_action("move", {"delta": [1, 0, 0]}).ok, "Controller edits blocked inside owner callback")
	check(not current_target.controller.exit_editor().ok, "Gameplay resume blocked inside owner callback")
	check(not current_target.controller.document.update_record(current_target.house_id, {"label": "nested"}).ok, "Direct normal object mutation API guarded")
	check(not current_target.ground.begin_stroke().ok, "Ground pointer mutation guarded during combined import")
	reentry_checks += 5

func admission(phase: String, _payload: Dictionary) -> Dictionary:
	if phase == reenter_phase: attempt_reentry()
	if phase == lose_lease_phase: paused_owner = false
	return {"ok": phase != fail_phase}

func object_changed() -> void:
	object_notifications += 1
	check(Patch._canonical(current_target.controller.document.to_dictionary()) == Patch._canonical(expected_objects), "Observer sees committed object document")
	check(Patch._canonical(current_target.ground.export_patch()) == Patch._canonical(expected_ground), "Object observer sees simultaneously committed ground document")
	attempt_reentry()

func jointly_changed() -> void:
	joint_notifications += 1
	check(object_notifications == 1, "One coherent object notification before joint notification")
	check(nav_state == "finalized", "Notifications occur only after staged navigation cleanup")

func owner_for(target: Dictionary, bundle: Dictionary) -> RefCounted:
	current_target = target
	current_bundle = bundle
	current_atomic = Atomic.new()
	check(current_atomic.configure(target.controller, target.ground, target.renderer, lease, joint_navigation, requirements, available, admission).ok, "Real owners and receipt adapters configured")
	var admitted := Bundle.validate(target.baseline, bundle, requirements, available, target.ground.validate_patch)
	check(admitted.ok, "Combined candidate validated before staged test")
	expected_objects = admitted.document
	expected_ground = admitted.ground_patch
	object_notifications = 0
	joint_notifications = 0
	target.controller.document.changed.connect(object_changed)
	current_atomic.committed.connect(jointly_changed)
	return current_atomic

func exact_scene(target: Dictionary, scene_checkpoint: Dictionary) -> bool:
	if target.registry.ids() != scene_checkpoint.entries.keys(): return false
	for id: String in scene_checkpoint.entries:
		var entry: Dictionary = scene_checkpoint.entries[id]
		if target.registry._entries[id].deleted != entry.deleted: return false
		for item: Dictionary in entry.participants:
			var node: Node3D = item.node.get_ref()
			if not is_instance_valid(node) or not node.global_transform.is_equal_approx(item.frame) or node.visible != item.visible: return false
		for item: Dictionary in entry.bodies:
			var body: CollisionObject3D = item.node.get_ref()
			if not is_instance_valid(body) or body.collision_layer != item.layer or body.collision_mask != item.mask: return false
	return true

func snapshot(target: Dictionary) -> Dictionary:
	return {"scene": target.registry.capture_install_checkpoint(), "objects": target.controller.document.capture_install_checkpoint(), "ground": target.ground.capture_install_checkpoint(), "chunks": target.renderer._chunks.duplicate(), "rows": target.renderer._rows.duplicate(), "cache": target.renderer._mesh_cache.duplicate(), "filters": floor_filters(target)}

func floor_filters(target: Dictionary) -> Array:
	var result: Array = []
	for row: Node3D in target.renderer._rows.values():
		for body: StaticBody3D in row.get_children(): result.append({"body": weakref(body), "layer": body.collision_layer, "mask": body.collision_mask, "shape": body.get_child(0).shape})
	return result

func restored(target: Dictionary, saved: Dictionary, label: String) -> void:
	check(exact_scene(target, saved.scene), label + ": source poses, clone membership, deleted flags and body filters exact")
	check(target.controller.document.capture_install_checkpoint() == saved.objects, label + ": object data/order/undo/redo exact")
	check(target.ground.capture_install_checkpoint() == saved.ground, label + ": ground data/stroke/undo/redo exact")
	check(target.renderer._chunks == saved.chunks and target.renderer._rows == saved.rows and target.renderer._mesh_cache == saved.cache, label + ": same old render nodes, MultiMesh resources and mesh cache")
	for item: Dictionary in saved.filters:
		var body: StaticBody3D = item.body.get_ref()
		check(is_instance_valid(body) and body.collision_layer == item.layer and body.collision_mask == item.mask and body.get_child(0).shape == item.shape, label + ": old floor shape/filter exact")
	check(object_notifications == 0 and joint_notifications == 0, label + ": no intermediate notification escaped")

func fault_session() -> Dictionary:
	var result := session()
	result.renderer.free()
	var ground := CommitRejectGround.new()
	ground.setup_baseline(topology, origin)
	result.ground = ground
	result.renderer = Renderer.new()
	result.world.add_child(result.renderer)
	check(result.renderer.configure(ground, shared_materials, lease, water, navigation).ok, "Real renderer configured against rejecting second-domain model")
	return result

func run() -> void:
	root.size = Vector2i(1280, 720)
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	factory = Factory.new()
	check(factory.configure(catalog), "Native verified GLB catalog admitted")
	topology = JSON.parse_string(FileAccess.get_file_as_string("res://data/topology_for_placement.json"))
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	topology.palette = block.surface.palette.duplicate(true)
	origin = Vector3(block.originM[0], block.originM[1], block.originM[2])
	for tile in Ground.SOURCE_TILES: shared_materials[str(tile)] = SurfaceMaterials.create_material(block.surface, tile, origin)
	for name in Ground.NAMED_LAYERS: shared_materials["layer:" + name] = StandardMaterial3D.new()
	var source := session()
	source.controller.selected_id = source.house_id
	source.controller.handle_action("move", {"delta": [4, 0, 7]})
	source.controller.handle_action("rotate", {"degrees": 10.0})
	source.controller.handle_action("add", {"catalog_id": source.house_id})
	var clone_id: String = source.controller.selected_id
	var painted := Vector2i(-1, -1)
	for row in range(200):
		for col in range(180):
			if source.ground.is_editable(row, col) and source.ground.cell_state(row, col).tile == 0:
				painted = Vector2i(col, row)
				break
		if painted.x >= 0: break
	source.ground.begin_stroke()
	source.ground.set_tile(painted.y, painted.x, 8)
	source.ground.set_named_layer(painted.y, painted.x, "dirt")
	check(source.renderer.commit_stroke().ok, "Native source terrain edited")
	var created := Bundle.create(source.baseline, source.controller.document.to_dictionary(), requirements, "Atomic native map", source.ground.export_patch(), source.ground.validate_patch)
	check(created.ok, "Object and ground bundle prepared")
	var path := "user://maps/tests/atomic-%d.json" % Time.get_ticks_usec()
	check(BundleStore.save_bundle(created.bundle, source.baseline, requirements, available, path, source.ground.validate_patch).ok, "Combined real source file saved")
	var target := session()
	var disk := BundleStore.load_bundle(target.baseline, requirements, available, path, target.ground.validate_patch)
	check(disk.ok, "Fresh-session disk admission succeeds")
	var atomic := owner_for(target, disk.bundle)
	reenter_phase = "before_commit"
	var started := Time.get_ticks_usec()
	var result: Dictionary = atomic.install_bundle(disk.bundle)
	var success_usec := Time.get_ticks_usec() - started
	check(result.ok and result.committed and target.registry.has_object(clone_id) and target.registry.ids().size() == 243, "Atomic fresh install reconstructs native 243 objects")
	check(object_notifications == 1 and joint_notifications == 1 and target.ground.cell_state(painted.y, painted.x).tile == 8, "Both domains published exactly once after complete success")
	check(paused_owner and target.controller.active and not atomic._busy, "Import never resumes gameplay itself; editor lease released only to owner")
	reenter_phase = ""
	var failing := session()
	failing.controller.selected_id = failing.house_id
	failing.controller.handle_action("move", {"delta": [-2, 0, 1]})
	failing.controller.handle_action("add", {"catalog_id": failing.house_id})
	failing.controller.handle_action("delete")
	failing.controller.handle_action("undo")
	failing.ground.begin_stroke()
	failing.ground.set_tile(painted.y, painted.x, 14)
	failing.renderer.commit_stroke()
	var old_floor: StaticBody3D = failing.renderer._rows[painted.y].get_child(0)
	old_floor.collision_layer = 5
	old_floor.collision_mask = 9
	var house_body: CollisionObject3D = failing.registry._entries[failing.house_id].bodies[0].node.get_ref()
	house_body.collision_layer = 3
	house_body.collision_mask = 7
	atomic = owner_for(failing, disk.bundle)
	var saved := snapshot(failing)
	var corrupted: Dictionary = disk.bundle.duplicate(true)
	corrupted.label = "tampered envelope"
	result = atomic.install_bundle(corrupted)
	check(not result.ok and result.get("rollback_ok", false), "Tampered file cannot stage either native domain")
	restored(failing, saved, "file validation rejection")
	for phase: String in ["prepared", "objects_staged", "ground_staged", "before_commit"]:
		fail_phase = phase
		result = atomic.install_bundle(disk.bundle)
		check(not result.ok and result.get("rollback_ok", false) and not atomic._busy, "Owner refusal rolled back at " + phase)
		restored(failing, saved, phase)
	fail_phase = ""
	ground_nav_ok = false
	result = atomic.install_bundle(disk.bundle)
	check(not result.ok and result.get("rollback_ok", false), "Actual ground nav gate rejection rolls back both staged scenes")
	restored(failing, saved, "ground nav rejection")
	ground_nav_ok = true
	joint_prepare_ok = false
	result = atomic.install_bundle(disk.bundle)
	check(not result.ok and result.get("rollback_ok", false) and nav_state == "rolled_back", "Combined nav receipt refusal rolls back both domains")
	restored(failing, saved, "joint nav rejection")
	joint_prepare_ok = true
	joint_prepare_ok = false
	joint_rollback_ok = false
	result = atomic.install_bundle(disk.bundle)
	check(not result.ok and result.get("retry_rollback", false) and atomic.busy_status().busy, "Navigation rollback denial retains owned receipt and paused retry")
	joint_rollback_ok = true
	joint_prepare_ok = true
	result = atomic.retry_rollback()
	check(result.get("rollback_ok", false) and not atomic.busy_status().busy, "All navigation owners must confirm rollback before unlock")
	restored(failing, saved, "nav rollback retry")
	lose_lease_phase = "before_commit"
	result = atomic.install_bundle(disk.bundle)
	check(not result.ok and result.get("retry_rollback", false) and atomic._busy and failing.controller.atomic_install_active, "Lost paused lease cannot silently mutate or resume; rollback remains owned")
	paused_owner = true
	lose_lease_phase = ""
	result = atomic.retry_rollback()
	check(result.get("rollback_ok", false) and not atomic._busy, "Owner stop permits exact deferred rollback")
	restored(failing, saved, "lease-loss rollback")
	# Water ownership and postcommit resource cleanup are real renderer hooks.
	source.ground.begin_stroke()
	source.ground.set_tile(painted.y, painted.x, 16)
	source.renderer.commit_stroke()
	var water_bundle := Bundle.create(source.baseline, source.controller.document.to_dictionary(), requirements, "Atomic water map", source.ground.export_patch(), source.ground.validate_patch)
	current_bundle = water_bundle.bundle
	water_apply_ok = false
	water_rollback_ok = false
	result = atomic.install_bundle(water_bundle.bundle)
	check(not result.ok and result.get("retry_rollback", false) and atomic.busy_status().busy and failing.renderer._pending.get("scene_restored", false), "Water rollback denial keeps receipt even after restoring old core terrain")
	water_rollback_ok = true
	result = atomic.retry_rollback()
	check(result.get("rollback_ok", false) and not atomic.busy_status().busy and failing.renderer._pending.is_empty(), "Water rollback retry confirms owner before unlocking either domain")
	restored(failing, saved, "water apply rejection")
	water_apply_ok = true
	var water_admitted := Bundle.validate(failing.baseline, water_bundle.bundle, requirements, available, failing.ground.validate_patch)
	expected_objects = water_admitted.document
	expected_ground = water_admitted.ground_patch
	water_finalize_ok = false
	result = atomic.install_bundle(water_bundle.bundle)
	check(not result.ok and result.get("committed", false) and result.get("retry_finalize", false) and atomic._busy, "Postcommit water cleanup refusal preserves both committed models and paused owner")
	check(Patch._canonical(failing.controller.document.to_dictionary()) == Patch._canonical(expected_objects) and Patch._canonical(failing.ground.export_patch()) == Patch._canonical(expected_ground) and object_notifications == 0, "Cleanup failure is not a partial commit and emits no premature notification")
	check(not atomic.retry_rollback().ok and not failing.controller.exit_editor().ok, "Cleanup-pending owner cannot restore only one domain or resume gameplay")
	water_finalize_ok = true
	joint_finalize_ok = false
	result = atomic.retry_finalize()
	check(not result.ok and result.get("committed", false) and atomic._context.ground_finalized and object_notifications == 0, "Navigation cleanup retry retains committed model pair after ground resources finalized")
	joint_finalize_ok = true
	result = atomic.retry_finalize()
	check(result.ok and not atomic._busy and object_notifications == 1 and joint_notifications == 1, "Cleanup retry finalizes receipts and emits exactly one coherent notification")
	var second_failure := fault_session()
	atomic = owner_for(second_failure, disk.bundle)
	var fault_saved := snapshot(second_failure)
	second_failure.ground.reject_commit = true
	result = atomic.install_bundle(disk.bundle)
	check(not result.ok and result.get("rollback_ok", false), "Pure second-model commit refusal restores first silent model before any observer")
	restored(second_failure, fault_saved, "second-domain commit refusal")
	for suffix in ["", ".bak", ".tmp"]:
		var file: String = ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	print("ATOMIC_MAP_IMPORT_QA ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "sourceObjects": 242, "freshObjects": 243, "groundRows": 200, "groundCols": 180, "verifiedSourceLoads": factory.loads, "successfulImportCpuUsec": success_usec, "stagedGeometryProofs": staged_proofs, "reentryGuardsVerified": reentry_checks, "atomicImportReadyInCandidate": failures.is_empty(), "scope": "Isolated native scenes/full source ground. Trusted staged water/nav/lease callbacks and module ownership required; no LIVE/GPU/gameplay acceptance."}))
	for item: Dictionary in [source, target, failing, second_failure]: item.world.queue_free()
	quit(0 if failures.is_empty() else 1)
