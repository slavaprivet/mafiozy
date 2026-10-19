extends "res://test_authored_atomic.gd"
const Workspace = preload("res://scripts/map_editor/editor_workspace.gd")
const Persistence = preload("res://scripts/map_editor/editor_persistence.gd")
const Host = preload("res://scripts/map_editor/editor_host_adapter.gd")
const CatalogUI = preload("res://scripts/map_editor/catalog_ui.gd")
const Brush = preload("res://ground_brush.gd")
const GroundPanel = preload("res://ground_panel.gd")
const GroundPreview = preload("res://ground_preview.gd")
var clipboard_text := ""
var pause_receipt := {}
var resume_count := 0
var persistence_path := ""

func pause_gameplay(request: Dictionary) -> Dictionary:
	paused_owner = true
	pause_receipt = request.duplicate(true)
	pause_receipt.token = "test-only-trusted-owner"
	return {"ok": true, "receipt": pause_receipt.duplicate(true)}
func cancel_pause(_request: Dictionary) -> Dictionary:
	paused_owner = false
	return {"ok": true}
func verify_pause(receipt: Dictionary) -> bool:
	return paused_owner and receipt == pause_receipt
func transaction_ready(_receipt: Dictionary) -> bool:
	return (current_atomic == null or not current_atomic.busy_status().busy) and current_target.renderer._pending.is_empty()
func resume_gameplay(receipt: Dictionary, objects: Dictionary, ground: Dictionary) -> Dictionary:
	if not verify_pause(receipt) or not transaction_ready(receipt): return {"ok": false}
	check(Patch._canonical(objects) == Patch._canonical(current_target.controller.document.to_dictionary()), "Owner receives actual objects on exit")
	check(Patch._canonical(ground) == Patch._canonical(current_target.ground.export_patch()), "Owner receives actual ground on exit")
	paused_owner = false
	resume_count += 1
	return {"ok": true, "owner_id": receipt.owner_id, "request_id": receipt.request_id}
func ground_patch() -> Dictionary:
	return current_target.ground.export_patch()
func read_text() -> String: return clipboard_text
func write_text(value: String) -> bool:
	clipboard_text = value
	return true
func toggle(host: RefCounted) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_K
	key.pressed = true
	check(host.handle_input(key), "K routed through trusted host")

func assembled() -> Dictionary:
	current_atomic = null
	paused_owner = true
	var target := session()
	current_target = target
	check(target.controller.exit_editor().ok, "Synthetic fixture initial editor shut before host mounting")
	var host := Host.new()
	var mounted: Dictionary = host.mount(target.world, {"pause_gameplay": pause_gameplay, "cancel_pause": cancel_pause, "verify_pause": verify_pause, "resume_gameplay": resume_gameplay, "transaction_ready": transaction_ready, "ground_patch": ground_patch})
	check(mounted.ok, "Explicit actual scene owner mounted")
	target.controller._begin_gate = mounted.enter_gate
	target.controller._end_gate = mounted.leave_gate
	var atomic := Atomic.new()
	current_atomic = atomic
	check(atomic.configure(target.controller, target.ground, target.renderer, lease, joint_navigation, requirements, available, admission).ok, "REAL cross-domain importer configured")
	var persistence := Persistence.new()
	check(persistence.configure(target.controller, target.ground, atomic, requirements, available, host.transaction_ready, {"read": read_text, "write": write_text}, persistence_path, persistence_path + ".published.json").ok, "REAL file persistence configured")
	var preview_owner := GroundPreview.new()
	target.world.add_child(preview_owner)
	check(preview_owner.configure(target.ground, lease).ok, "Real editor-only preview owner configured")
	var brush := Brush.new()
	check(brush.setup(target.ground, {"preview_chunks": preview_owner.apply, "physical_apply": target.renderer.apply, "nav_invalidate": target.renderer.validate_navigation, "rollback": target.renderer.rollback}).ok, "Real ground brush uses actual geometry owner and native preview")
	var panel := GroundPanel.new()
	target.world.add_child(panel)
	var workspace := Workspace.new()
	target.world.add_child(workspace)
	check(workspace.setup(target.controller, brush, panel, target.renderer, persistence.handle_action, host.transaction_ready, preview_owner).ok, "Joint UI workspace configured")
	check(host.bind_workspace(workspace).ok, "Input bound to one workspace")
	var ui: Dictionary = CatalogUI.build(catalog, target.registry)
	check(ui.ok and ui.total == catalog.objects.size() and ui.admitted > 0 and ui.admitted <= 242, "Full catalog admission admits only actually registered authored models")
	target.controller.panel.set_catalog(ui.items)
	paused_owner = false
	toggle(host)
	check(target.controller.active and host.gameplay_blocked() and paused_owner, "K acquires owner lease and opens editor")
	target.merge({"host": host, "atomic": atomic, "persistence": persistence, "workspace": workspace, "brush": brush, "ground_panel": panel, "ground_preview": preview_owner})
	return target

func run() -> void:
	root.size = Vector2i(1280, 720)
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	factory = Factory.new()
	check(factory.configure(catalog), "Actual authored catalog configured")
	topology = JSON.parse_string(FileAccess.get_file_as_string("res://data/topology_for_placement.json"))
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	topology.palette = block.surface.palette.duplicate(true)
	origin = Vector3(block.originM[0], block.originM[1], block.originM[2])
	for tile in Ground.SOURCE_TILES: shared_materials[str(tile)] = SurfaceMaterials.create_material(block.surface, tile, origin)
	for name in Ground.NAMED_LAYERS: shared_materials["layer:" + name] = StandardMaterial3D.new()
	persistence_path = "user://maps/tests/assembly-%d.json" % Time.get_ticks_usec()
	var source := assembled()
	source.controller.selected_id = source.house_id
	check(source.workspace.handle_action("move", {"delta": [4, 0, 7]}).ok, "UI moves native complete house")
	check(source.workspace.handle_action("add", {"catalog_id": source.house_id}).ok, "UI adds trusted native complete clone")
	var clone_id: String = source.controller.selected_id
	check(source.workspace.set_mode("ground").ok and source.brush.active and source.ground_panel._active, "UI switches to actual ground mode")
	check(source.workspace.handle_action("ground_tile", {"tile": 8}).ok, "UI chooses grass brush")
	var cell := Vector2i.ZERO
	for row in range(200):
		for col in range(180):
			if source.ground.is_editable(row, col) and source.ground.cell_state(row, col).tile == 0:
				cell = Vector2i(col, row)
				break
		if cell != Vector2i.ZERO: break
	var before: Dictionary = source.ground.cell_state(cell.y, cell.x)
	check(source.workspace.handle_action("camera_top").ok, "Ground mode UI routes top camera action")
	source.controller.camera.global_position = Vector3((cell.x + 0.5) * Ground.CELL_SIZE - origin.x, 80, (cell.y + 0.5) * Ground.CELL_SIZE - origin.z)
	await process_frame
	var pointer := InputEventMouseButton.new()
	pointer.position = Vector2(root.size) * 0.5
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	check(source.host.handle_input(pointer) and source.brush.is_painting(), "Native LMB through host/workspace begins visible ground brush stroke")
	check(source.ground_preview._chunks.size() == 1 and is_instance_valid(source.ground_preview._cursor), "Actual pointer makes native pending-cell and cursor markers")
	pointer.pressed = false
	check(source.host.handle_input(pointer), "Native LMB release through workspace commits ground brush stroke")
	check(source.ground.cell_state(cell.y, cell.x).tile == 8 and source.renderer._pending.is_empty(), "Actual pointer brush updates physical strips and finalizes through workspace")
	check(source.ground_preview._chunks.is_empty(), "Committed stroke clears pending visual markers")
	check(source.workspace.handle_action("ground_undo").ok and source.ground.cell_state(cell.y, cell.x).tile == before.tile, "UI ground undo uses real renderer")
	check(source.workspace.handle_action("ground_redo").ok and source.ground.cell_state(cell.y, cell.x).tile == 8, "UI ground redo uses real renderer")
	check(source.workspace.handle_action("save", {"label": "Живая сборка редактора"}).ok, "UI saves BOTH domains to real file")
	check(source.workspace.handle_action("export").ok and not clipboard_text.is_empty(), "UI exports BOTH domains to file and text adapter")
	var desired_objects: Dictionary = source.controller.document.to_dictionary()
	var desired_ground: Dictionary = source.ground.export_patch()
	toggle(source.host)
	check(not source.controller.active and not source.host.gameplay_blocked() and not paused_owner, "K returns both current documents to owner and resumes test gameplay")
	check(source.ground_preview._chunks.is_empty() and source.ground_preview._cursor == null, "K exit removes all editor-only terrain markers")
	source.world.free()
	var target := assembled()
	var load_start := Time.get_ticks_usec()
	check(target.workspace.handle_action("load").ok, "UI fresh file load runs REALAtomic")
	var load_usec := Time.get_ticks_usec() - load_start
	check(target.registry.ids().size() == 243 and target.registry.has_object(clone_id), "Fresh UI session reconstructs native trusted clone")
	check(Patch._canonical(target.controller.document.to_dictionary()) == Patch._canonical(desired_objects) and Patch._canonical(target.ground.export_patch()) == Patch._canonical(desired_ground), "Fresh UI file load restores exact object/terrain data")
	target.controller.selected_id = target.house_id
	check(target.workspace.handle_action("move", {"delta": [1, 0, 0]}).ok, "UI current scene differs before negative import")
	var old := snapshot(target)
	fail_phase = "ground_staged"
	var rejected: Dictionary = target.workspace.handle_action("import")
	fail_phase = ""
	check(not rejected.ok and target.controller.active and paused_owner and target.host.gameplay_blocked(), "UI phase refusal keeps editor paused and open")
	restored(target, old, "UI staged failure")
	fail_phase = "before_commit"
	joint_rollback_ok = false
	var held_rollback: Dictionary = target.workspace.handle_action("import")
	check(not held_rollback.ok and held_rollback.get("retry_rollback", false) and target.atomic.busy_status().busy, "UI owner rollback refusal holds actual staged transaction")
	toggle(target.host)
	check(target.controller.active and paused_owner and target.host.gameplay_blocked(), "K cannot resume with refused native owner rollback")
	fail_phase = ""
	joint_rollback_ok = true
	var rollback_retry: Dictionary = target.workspace.handle_action("retry_pending")
	check(rollback_retry.ok and rollback_retry.get("rolled_back", false) and not target.atomic.busy_status().busy, "UI retry_pending reaches actual cross-owner rollback receipt")
	restored(target, old, "UI retried owner rollback")
	joint_finalize_ok = false
	var pending: Dictionary = target.workspace.handle_action("import")
	check(not pending.ok and pending.get("committed", false) and target.atomic.busy_status().busy, "UI cleanup failure retains committed transaction")
	toggle(target.host)
	check(target.controller.active and paused_owner and target.host.gameplay_blocked(), "K cannot escape pending combined cleanup")
	check(not target.workspace.handle_action("move", {"delta": [9, 0, 0]}).ok, "Pending cleanup blocks new UI geometry edits")
	joint_finalize_ok = true
	var retried: Dictionary = target.workspace.handle_action("retry_pending")
	check(retried.ok and not target.atomic.busy_status().busy, "UI retry_pending reaches persistence and REALAtomic finalizer")
	if retried.ok:
		toggle(target.host)
		check(not target.controller.active and not paused_owner, "K exit admitted after actual joint finalization")
	print(JSON.stringify({"suite": "actual-editor-assembly", "checks": checks, "failures": failures, "actualObjects": 242, "freshObjects": 243, "ground": "200x180", "loadCpuUsec": load_usec, "gpu": false, "productionWired": false}))
	target.world.free()
	quit(0 if failures.is_empty() else 1)
