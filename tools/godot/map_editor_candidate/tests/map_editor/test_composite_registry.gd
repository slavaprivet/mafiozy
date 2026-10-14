extends SceneTree
const Composite = preload("res://scripts/map_editor/composite_registry.gd")
const Registry = preload("res://scripts/map_editor/object_registry.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
class FaultRegistry extends "res://scripts/map_editor/object_registry.gd":
	var fail_real := false
	var fail_restore := false
	var real_calls := 0
	var targeted_calls := 0
	var restore_calls := 0
	func apply_document(document: Dictionary, dry_run: bool = false) -> Dictionary:
		if not dry_run: real_calls += 1
		var result := super.apply_document(document, dry_run)
		return {"ok": false, "error": "Owner fails after actual mutation"} if not dry_run and fail_real and result.ok else result
	func apply_record(id: String, record: Variant, dry_run: bool = false) -> Dictionary:
		targeted_calls += 1
		return super.apply_record(id, record, dry_run)
	func restore_install_checkpoint(cp: Dictionary) -> Dictionary:
		restore_calls += 1
		return {"ok": false, "error": "Owner restoration refused"} if fail_restore else super.restore_install_checkpoint(cp)
var failures: Array = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func gate_begin() -> Dictionary: return {"ok": true}
func gate_end(_doc: Dictionary) -> Dictionary: return {"ok": true}
func object(world: Node3D, owner: RefCounted, id: String, z: float, editable: bool = true) -> Node3D:
	var root_node := Node3D.new()
	world.add_child(root_node)
	root_node.position = Vector3(0, 0, z)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = StandardMaterial3D.new()
	root_node.add_child(mesh)
	var body := StaticBody3D.new()
	world.add_child(body)
	body.position = root_node.position
	body.collision_layer = 3
	body.collision_mask = 5
	var collider := CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	body.add_child(collider)
	check(owner.register_object(id, root_node, {"kind": "decor", "model": "trusted-box", "source": {"identity": id}}, [body], editable).ok, "Trusted actual Node owner registered " + id)
	return root_node
func run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var a := FaultRegistry.new()
	var b := FaultRegistry.new()
	var first := object(world, a, "authored", 4)
	var second := object(world, b, "procedural-contract", 8)
	object(world, b, "locked", 14, false)
	var registry := Composite.new()
	check(registry.configure([{"owner_id": "authored", "registry": a}, {"owner_id": "procedural", "registry": b}], "joint", {"source": "trusted"}).ok, "Explicit two-owner composition configured")
	check(not registry.configure([], "joint").ok, "Reconfiguration forbidden")
	var duplicate := Composite.new()
	check(not duplicate.configure([{"owner_id": "x", "registry": a}, {"owner_id": "y", "registry": a}], "joint").ok, "Repeated owner refused")
	var ambiguous := FaultRegistry.new()
	object(world, ambiguous, "authored", 30)
	check(not Composite.new().configure([{"owner_id": "x", "registry": a}, {"owner_id": "y", "registry": ambiguous}], "joint").ok, "Duplicate global identity refused before admission")
	var baseline := registry.source_document("joint")
	check(baseline.objects.size() == 3 and baseline.metadata.registry_owners.size() == 2, "Exact records and namespaced owner source headers merged")
	var detached := registry.source_document("joint")
	detached.objects[0].source.identity = "tamper"
	check(registry.source_document("joint").objects[0].source.identity == "authored", "Merged source detached from caller mutation")
	check(registry.pick(Vector3.ZERO, Vector3(0, 0, 1)) == "authored", "Nearest bounds picked across owners")
	check(registry.pick(Vector3.ZERO, Vector3.ZERO).is_empty(), "Invalid ray rejected")
	var record: Dictionary = baseline.objects[0].duplicate(true)
	record.transform.position[0] = 2
	a.targeted_calls = 0
	b.targeted_calls = 0
	check(registry.apply_record("authored", record).ok and a.targeted_calls == 2 and b.targeted_calls == 0, "Targeted dispatch visits one owner only")
	check(first.position.x == 2 and second.position.x == 0, "Other owner geometry unchanged")
	check(registry.apply_record("authored", null).ok and registry.pick(Vector3.ZERO, Vector3(0, 0, 1)) == "procedural-contract", "Deleted nearest object skipped")
	check(registry.apply_document(baseline).ok, "Both actual owners restored via trusted bulk document")
	var moved: Dictionary = baseline.duplicate(true)
	moved.objects[0].transform.position[0] = 7
	moved.objects[1].transform.position[0] = 9
	var metadata_bad := moved.duplicate(true)
	metadata_bad.metadata.source = "forged"
	check(not registry.apply_document(metadata_bad).ok and first.position.x == 0, "Untrusted global source header refused")
	var source_bad := moved.duplicate(true)
	source_bad.objects[1].source.identity = "forged"
	check(not registry.apply_document(source_bad).ok and a.real_calls == 1 and first.position.x == 0, "All-owner provenance preflight blocks earlier owner mutation")
	var locked_bad := moved.duplicate(true)
	locked_bad.objects.pop_back()
	check(not registry.apply_document(locked_bad).ok and first.position.x == 0, "Protected owner deletion refused before any real apply")
	b.fail_real = true
	a.restore_calls = 0
	b.restore_calls = 0
	var failure: Dictionary = registry.apply_document(moved)
	check(not failure.ok and failure.rollback_ok and a.restore_calls == 1 and b.restore_calls == 1 and first.position.x == 0 and second.position.x == 0, "Second owner partial failure restores BOTH exact native geometries")
	a.fail_restore = true
	failure = registry.apply_document(moved)
	check(not failure.ok and not failure.rollback_ok and failure.retry_rollback and registry.busy_status().busy, "Refused rollback retains busy recovery receipt")
	check(not registry.apply_record("authored", record).ok and not registry.create_copy("authored", "editor:blocked", Transform3D.IDENTITY).ok, "Pending rollback blocks fresh mutations")
	a.fail_restore = false
	b.fail_real = false
	check(registry.retry_rollback().ok and not registry.busy_status().busy and first.position.x == 0 and second.position.x == 0, "Owner repair and retry restores both owners")
	var checkpoint := registry.capture_install_checkpoint()
	var copied := registry.create_copy("procedural-contract", "editor:b", Transform3D(Basis.IDENTITY, Vector3(10, 0, 0)))
	check(copied.ok and registry.has_object("editor:b") and b.has_object("editor:b") and not a.has_object("editor:b"), "Clone routes through trusted template owner")
	check(not registry.create_copy("authored", "editor:b", Transform3D.IDENTITY).ok and not registry.create_copy("locked", "editor:locked", Transform3D.IDENTITY).ok, "Global copy collision and protected template remain refused")
	check(registry.restore_install_checkpoint(checkpoint).ok and not registry.has_object("editor:b") and not b.has_object("editor:b"), "Joint checkpoint discards new child clones and restores global inventory")
	check(not Composite.new().restore_install_checkpoint(checkpoint).ok, "Foreign checkpoint issuer rejected")
	var forged := {"ok": true, "issuer": registry.get_instance_id(), "token": RefCounted.new()}
	check(not registry.restore_install_checkpoint(forged).ok, "Unissued token rejected even with correct issuer integer")
	var old_parent := first.get_parent()
	var other := Node3D.new()
	world.add_child(other)
	first.reparent(other)
	check(not registry.restore_install_checkpoint(checkpoint).ok and registry.busy_status().busy, "Reparented native dependency cannot be claimed as exact rollback")
	first.reparent(old_parent)
	check(registry.retry_rollback().ok, "Owner reattachment permits safe retry")
	registry.release_checkpoint(checkpoint)
	check(not registry.restore_install_checkpoint(checkpoint).ok, "Released checkpoint cannot be replayed")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 10, 20)
	var controller := Controller.new()
	world.add_child(controller)
	check(controller.setup(registry, baseline, camera, gate_begin, gate_end).ok and controller.enter_editor().ok, "Actual controller accepts composite full registry API")
	controller.selected_id = "procedural-contract"
	check(controller.handle_action("move", {"delta": [1, 0, 0]}).ok and second.position.x == 1, "Controller hot record action routes owned geometry")
	check(controller.handle_action("undo").ok and second.position.x == 0, "Controller history undo routes same owner")
	check(controller.handle_action("add", {"catalog_id": "authored"}).ok and registry.ids().size() == 4, "Controller clone adds global index entry")
	check(controller.exit_editor().ok, "Controller returns composite source document")
	world.free()
	print(JSON.stringify({"suite": "composite-registry", "checks": checks, "failures": failures, "realProceduralV3": false}))
	quit(0 if failures.is_empty() else 1)
