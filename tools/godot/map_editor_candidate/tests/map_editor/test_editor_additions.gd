extends SceneTree

const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const Registry = preload("res://scripts/map_editor/object_registry.gd")
const Store = preload("res://scripts/map_editor/map_store.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func gate_begin() -> Dictionary:
	return {"ok": true}

func gate_end(_document: Dictionary) -> Dictionary:
	return {"ok": true}

func fixture(include_guard: bool = false) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var visual := Node3D.new()
	world.add_child(visual)
	visual.transform = Transform3D(Basis.from_euler(Vector3(0, 0.4, 0)).scaled(Vector3(2, 2, 2)), Vector3(3, 0, 4))
	visual.set_meta("source_id", "template")
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = StandardMaterial3D.new()
	mesh.material_override.albedo_color = Color(0.3, 0.6, 0.8)
	mesh.position = Vector3(0, 1, 0)
	mesh.set_meta("source_id", "template")
	visual.add_child(mesh)
	var body := StaticBody3D.new()
	world.add_child(body)
	body.position = Vector3(3, -1, 6)
	body.collision_layer = 5
	body.collision_mask = 7
	body.set_meta("source_id", "template")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	var index := Registry.new()
	index.register_object("template", visual, {"kind": "decor", "model": "verified-lamp", "source": {"id": 42}}, [body])
	if include_guard:
		var guard := Node3D.new()
		world.add_child(guard)
		guard.position = Vector3(200, 0, 0)
		index.register_object("protected", guard, {"kind": "building", "source": {"id": 99}}, [], false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 10, 20)
	camera.make_current()
	var controller := Controller.new()
	world.add_child(controller)
	controller.setup(index, index.source_document("copy-test"), camera, gate_begin, gate_end)
	return {"world": world, "visual": visual, "mesh": mesh, "body": body, "shape": shape, "index": index, "controller": controller}

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var a := fixture()
	var index: RefCounted = a.index
	var controller: Node = a.controller
	var baseline: Transform3D = a.visual.global_transform
	var baseline_body: Transform3D = a.body.global_transform
	check(controller.enter_editor().ok, "Editor entered")
	controller.selected_id = "template"
	check(controller.handle_action("move", {"delta": [10, 0, 0]}).ok, "Original template moved")
	var frame := Transform3D(baseline.basis, Vector3(20, 0, 30))
	var copy: Dictionary = index.create_copy("template", "editor:direct", frame)
	check(copy.ok, "Direct copy of moved template")
	if not copy.ok:
		a.world.queue_free()
		quit(1)
		return
	check(copy.record.id == "editor:direct" and copy.record.template_id == "template" and copy.record.source.id == 42, "New stable ID/template provenance retained")
	var entry: Dictionary = index._entries["editor:direct"]
	var clone: Node3D = entry.root.get_ref()
	var clone_mesh: MeshInstance3D = clone.get_child(0)
	var clone_body: StaticBody3D = entry.participants[1].node.get_ref()
	check(clone_mesh.mesh == a.mesh.mesh and clone_mesh.material_override == a.mesh.material_override, "Geometry and materials shared, not copied or reduced")
	check(clone_mesh.position == a.mesh.position, "Visual internal offsets unchanged")
	check(clone.global_transform.is_equal_approx(frame), "Moved original does not contaminate clone frame")
	var expected_body := frame * baseline.affine_inverse() * baseline_body
	check(clone_body.global_transform.is_equal_approx(expected_body), "Detached collision internal offset preserved")
	check(clone_body.get_child(0).shape == a.shape.shape and clone_body.collision_layer == 5 and clone_body.collision_mask == 7, "Shared collision shape and layers preserved")
	check(clone.get_meta("source_id") == "editor:direct" and clone_body.get_meta("source_id") == "editor:direct", "Participant runtime source identity rebound")
	check(clone_mesh.get_meta("source_id", "") == "editor:direct", "Nested visual runtime source identity rebound")
	# Add the registered direct copy to the document before testing host actions.
	check(controller.document.add_record(copy.record).ok, "Direct copy admitted into document")
	check(controller.handle_action("undo").ok and not clone.visible and clone_body.collision_layer == 0, "Undo add hides clone and disables detached body")
	check(controller.handle_action("redo").ok and clone.visible and clone_body.collision_layer == 5, "Redo add restores same clone/resources")
	controller.selected_id = "template"
	check(controller.handle_action("delete").ok, "Original template deleted")
	var deleted_copy: Dictionary = index.create_copy("template", "editor:from-deleted", frame)
	check(deleted_copy.ok, "Deleted source retains admitted catalog template")
	if deleted_copy.ok:
		var restored_entry: Dictionary = index._entries["editor:from-deleted"]
		check(restored_entry.root.get_ref().visible and restored_entry.participants[1].node.get_ref().collision_layer == 5, "Copy of deleted source restores visible and collidable baseline")
		index.discard_copy("editor:from-deleted")
		check(not index.has_object("editor:from-deleted"), "Discard removes failed/uncommitted copy identity")
	check(clone.visible and clone_body.collision_layer == 5, "Deleting original does not affect clone")
	check(controller.handle_action("undo").ok, "Original restored")
	var added: Dictionary = controller.handle_action("add", {"catalog_id": "template"})
	check(added.ok, "Catalog add succeeds")
	var added_id: String = controller.selected_id
	if added.ok:
		var added_root: Node3D = index._entries[added_id].root.get_ref()
		check(added_root.global_basis.is_equal_approx(baseline.basis), "Catalog add preserves authored instance scale/orientation")
		check(controller.handle_action("undo").ok and not added_root.visible, "Catalog add undo")
		check(controller.handle_action("redo").ok and added_root.visible, "Catalog add redo")
	# Saving must reconstruct copies after a new gameplay scene/index is built.
	var exported := Store.export_json(controller.document)
	var parsed := Store.import_json(exported.text)
	check(exported.ok and parsed.ok, "Copied map serializes safely")
	var b := fixture()
	check(b.controller.enter_editor().ok, "Fresh editor entered")
	var installed: Dictionary = b.controller.install_document(parsed.document)
	if not installed.ok: print("REVIEW FRESH LOAD: ", installed)
	check(installed.ok, "Fresh scene reconstructs saved added objects from trusted template IDs")
	if installed.ok:
		check(b.index.ids().has("editor:direct") and b.index.ids().has(added_id), "Fresh index owns reconstructed clone identities")
		check(Controller._json_equal(b.controller.document.to_dictionary(), parsed.document), "Fresh document matches admitted saved clone JSON while retaining trusted source")
		var accepted: Dictionary = b.controller.document.to_dictionary()
		var forged: Dictionary = parsed.document.duplicate(true)
		for row: Dictionary in forged.objects:
			if row.id == "editor:direct": row.source.id = 999
		check(not b.controller.install_document(forged).ok and b.controller.document.to_dictionary() == accepted, "Copied source authority cannot be forged on import")
		b.controller.selected_id = "template"
		check(b.controller.handle_action("delete").ok, "Delete original after fresh reconstruction")
		var deleted_saved: Dictionary = Store.import_json(Store.export_json(b.controller.document).text)
		var d := fixture()
		d.controller.enter_editor()
		check(d.controller.install_document(deleted_saved.document).ok and not d.visual.visible and d.index._entries["editor:direct"].root.get_ref().visible, "Fresh save with deleted original preserves independent clones")
		d.world.queue_free()
	# Missing protected originals fail final scene preflight after clones have
	# been staged. All new copies must roll back, keeping old document/history.
	var c := fixture(true)
	c.controller.enter_editor()
	var old_c: Dictionary = c.controller.document.to_dictionary()
	var old_count: int = c.world.get_child_count()
	var rejected: Dictionary = c.controller.install_document(parsed.document)
	check(not rejected.ok and c.index.ids().size() == 2 and c.world.get_child_count() == old_count and c.controller.document.to_dictionary() == old_c, "Failed post-creation preflight rolls back copies, nodes and document")
	c.world.queue_free()
	var before: Dictionary = controller.document.to_dictionary()
	check(not controller.handle_action("add", {"catalog_id": "untrusted"}).ok and controller.document.to_dictionary() == before, "Unknown catalog ID leaves scene/document unchanged")
	check(not index.create_copy("template", "editor:direct", frame).ok, "Duplicate clone identity rejected")
	a.world.queue_free()
	b.world.queue_free()
	if failures.is_empty():
		print("PASS map editor additions: shared resource copy, offsets, identities, moved/deleted originals, undo/redo, catalog add parity, fresh save reconstruction")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
