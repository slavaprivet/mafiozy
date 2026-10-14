extends "res://test_full_all_perf.gd"
const PagedController = preload("res://paged_editor_controller.gd")
const CatalogUI = preload("res://scripts/map_editor/catalog_ui.gd")
func controller_class() -> Script: return PagedController
func controller_catalogue(index: RefCounted) -> Array:
	var built: Dictionary = CatalogUI.build(catalog, index)
	check(built.ok, "full actual registry supplies catalog UI")
	if not built.ok: return []
	check(built.total == catalog.objects.size(), "every source catalog row visible, not just first160")
	for item: Dictionary in built.items:
		check(index.has_object(item.id), "catalog ID resolves actual owner: " + str(item.id))
		check(item.available == index.is_editable(item.id), "catalog availability is genuine registry state: " + str(item.id))
	return built.items
func _capture_node(node: Node, rows: Array) -> void:
	if node is Node3D: rows.append([node.get_instance_id(), var_to_bytes(node.global_transform), node.visible])
	if node is MeshInstance3D:
		rows.append([node.mesh, node.material_override, node.material_overlay, node.cast_shadow])
	if node is CollisionObject3D: rows.append([node.collision_layer, node.collision_mask])
	if node is CollisionShape3D:
		rows.append([node.shape, node.disabled])
		if node.shape is ConvexPolygonShape3D: rows.append(node.shape.points.to_byte_array())
	for child in node.get_children(true): _capture_node(child, rows)
func _native_snapshot(session: Dictionary, id: String) -> Dictionary:
	var owner: RefCounted = session.composite._owner(id)
	var rows: Array = []
	var frame := Transform3D.IDENTITY
	if owner == session.authored:
		var root_node: Node3D = owner._entries[id].root.get_ref()
		frame = root_node.global_transform
		for participant: Dictionary in owner._entries[id].participants:
			_capture_node(participant.node.get_ref(), rows)
	else:
		var factory: RefCounted = owner._factory
		var procedural: bool = owner == session.procedural
		frame = factory.object_transform(id) if procedural else factory.current_state(id).frame
		for part: Dictionary in factory._parts[id]:
			var batch: Dictionary = factory._batches[part.batch]
			var multi: MultiMesh = batch.mesh if procedural else batch.multimesh
			var shadows: Array = batch.transforms if procedural else batch.cpu_transforms
			# Exact CPU submission shadow, not Dummy renderer instance readback.
			rows.append([batch.node, multi, multi.mesh, batch.node.material_override, batch.node.cast_shadow, multi.instance_count, var_to_bytes(shadows[part.index])])
	return {"frame": frame, "frame_bytes": var_to_bytes(frame), "rows": rows, "bounds_bytes": var_to_bytes(session.composite.world_bounds(id))}
func exercise_editor_actions(session: Dictionary, templates: Array) -> void:
	super.exercise_editor_actions(session, templates)
	var panel: CanvasLayer = session.controller.panel
	var visited := {}
	for page in panel._page_count:
		panel.set_page(page)
		check(panel._visible_items.size() <= 160, "bounded native panel page " + str(page))
		for item: Dictionary in panel._visible_items:
			check(not visited.has(item.id), "source catalog identity appears once: " + str(item.id))
			visited[item.id] = true
	check(visited.size() == catalog.objects.size(), "all original objects reachable through pages")
	var protected_count := 0
	for item: Dictionary in panel._catalog:
		if item.available: continue
		protected_count += 1
		var previous_selected: String = session.controller.selected_id
		var original: Dictionary = session.controller.document.get_record(item.id)
		check(not session.controller.handle_action("select_existing", {"catalog_id": item.id}).ok, "protected actual owner cannot be selected for edit " + str(item.id))
		check(session.controller.selected_id == previous_selected and Trusted.equal(original, session.controller.document.get_record(item.id)), "protected owner record/selection remains exact " + str(item.id))
	check(protected_count == 38, "all six special and32 railway owners stay protected")
	var prior_selection: String = session.controller.selected_id
	check(not session.controller.handle_action("select_existing", {"catalog_id": "absent-untrusted-id"}).ok and session.controller.selected_id == prior_selection, "absent catalog ID cannot replace selection")
	session.controller.atomic_install_active = true
	check(not session.controller.handle_action("select_existing", {"catalog_id": templates[0]}).ok and session.controller.selected_id == prior_selection, "atomic install blocks explicit catalog selection")
	session.controller.atomic_install_active = false
	session.controller.active = false
	check(not session.controller.handle_action("select_existing", {"catalog_id": templates[0]}).ok and session.controller.selected_id == prior_selection, "inactive session blocks explicit catalog selection")
	session.controller.active = true
	for id: String in templates:
		panel._search.text = id
		panel._refresh()
		check(panel._visible_items.size() == 1 and panel._visible_items[0].id == id, "exact source-ID search " + id)
		if panel._visible_items.size() != 1: continue
		panel._catalog_selected(0)
		panel.action_requested.emit("select_existing", {"catalog_id": panel._selected_id})
		check(session.controller.selected_id == id, "catalog action selects actual current family " + id)
		var original: Dictionary = session.controller.document.get_record(id)
		var native_before: Dictionary = _native_snapshot(session, id)
		check(session.controller.handle_action("move", {"delta": [1,0,2]}).ok, "catalog-selected original family moves " + id)
		var native_moved: Dictionary = _native_snapshot(session, id)
		check(native_moved.frame == Composite.decode_transform(session.controller.document.get_record(id).transform) and native_moved.frame != native_before.frame, "actual owner frame follows selected record " + id)
		check(session.controller.handle_action("undo").ok and Trusted.equal(original, session.controller.document.get_record(id)), "catalog-selected family undo exact " + id)
		check(_native_snapshot(session, id) == native_before, "catalog move undo restores exact native frame/collision/mesh or CPU MM shadow " + id)
		check(session.controller.handle_action("delete").ok, "catalog-selected family deletes " + id)
		check(session.composite.world_bounds(id) == null, "deleted catalog-selected object is unpickable " + id)
		var before_selection: String = session.controller.selected_id
		check(not session.controller.handle_action("select_existing", {"catalog_id": id}).ok and session.controller.selected_id == before_selection, "deleted source catalog ID cannot change selection " + id)
		check(session.controller.handle_action("undo").ok and Trusted.equal(original, session.controller.document.get_record(id)), "catalog-selected family restored for fresh load " + id)
		check(_native_snapshot(session, id) == native_before, "catalog delete undo restores exact native object state " + id)
	panel._search.text = ""
	panel._refresh()
