extends SceneTree
const Registry = preload("res://scripts/map_editor/object_registry.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const Document = preload("res://scripts/map_editor/map_document.gd")
class CountingDocument:
	extends "res://scripts/map_editor/map_document.gd"
	var full_clones := 0
	func to_dictionary() -> Dictionary:
		full_clones += 1
		return super.to_dictionary()
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var doc := Document.new()
	doc.add_record({"id": "test", "kind": "building", "source": {"authority": "server", "id": 42}})
	var before := doc.to_dictionary()
	var candidate := doc.preview_update_record("test", {"transform": {"position": [1, 2, 3]}})
	check(candidate.ok and doc.to_dictionary() == before, "record preview immutable")
	candidate.record.source.authority = "mutated"
	check(doc.get_record("test").source.authority == "server", "preview detached opaque fields")
	doc.update_record("test", {"transform": {"position": [5, 0, 0]}})
	doc.undo()
	check(doc.can_redo(), "redo branch exists before failure")
	var signals := [0]
	doc.changed.connect(func(): signals[0] += 1)
	var failed := doc.transact_record_action("update", "test", {"transform": {"position": [9, 0, 0]}}, func(): return {"ok": false, "error": "dependency invalidated"})
	check(not failed.ok and doc.to_dictionary() == before and doc.can_redo() and signals[0] == 0, "failed scene commit restores exact record/history without signal")
	var redo_before := doc.peek_redo_operation()
	failed = doc.transact_record_action("redo", "test", {}, func(): return {"ok": false})
	check(not failed.ok and doc.peek_redo_operation() == redo_before and doc.to_dictionary() == before, "failed redo preserves history")
	var seen := [false]
	check(doc.transact_record_action("redo", "test", {}, func():
		seen[0] = doc.get_record("test").transform.position == [5, 0, 0] and signals[0] == 0
		return {"ok": true}).ok and seen[0] and signals[0] == 1, "scene sees staged model; signal only after consistency")
	var world := Node3D.new()
	root.add_child(world)
	var registry := Registry.new()
	var shared := BoxMesh.new()
	var nodes: Array[Node3D] = []
	var bodies: Array[StaticBody3D] = []
	for index in 242:
		var node := Node3D.new()
		world.add_child(node)
		node.position = Vector3(index * 3, 0, 0)
		var mesh := MeshInstance3D.new()
		mesh.mesh = shared
		node.add_child(mesh)
		var body := StaticBody3D.new()
		body.collision_layer = 5
		body.collision_mask = 7
		world.add_child(body)
		body.position = node.position + Vector3(0, -1, 0)
		var source_record := {"kind": "building", "model": "shared_source", "source": {"id": index, "authority": "server", "opaque": "unchanged".repeat(100), "rooms": [1, 2, 3]}}
		check(registry.register_object("source:%d" % index, node, source_record, [body], index != 1).ok, "register synthetic native source")
		nodes.append(node)
		bodies.append(body)
	var game := Camera3D.new()
	world.add_child(game)
	var controller := Controller.new()
	controller.document = CountingDocument.new()
	world.add_child(controller)
	check(controller.setup(registry, registry.source_document("hotpath"), game, func(): return {"ok": true}, func(_data): return {"ok": true}).ok, "controllersetup242")
	await process_frame
	check(controller.enter_editor().ok, "editor lease")
	controller.selected_id = "source:0"
	controller.document.full_clones = 0
	var times: Array[int] = []
	for iteration in 50:
		var started := Time.get_ticks_usec()
		check(controller.handle_action("move", {"delta": [1, 0, 0]}).ok, "move single record")
		check(controller.handle_action("undo").ok, "undo single record")
		if iteration >= 10: times.append(Time.get_ticks_usec() - started)
	check(controller.document.full_clones == 0, "hotactions never clone full document")
	check(registry.debug_record_cost().last_entries_visited == 1, "registry only addressed entry")
	check(nodes[0].position == Vector3.ZERO and bodies[0].position == Vector3(0, -1, 0), "visual collider exactrestore")
	var stable_history := controller.document.peek_redo_operation()
	controller.selected_id = "source:1"
	check(not controller.handle_action("move", {"delta": [1, 0, 0]}).ok and controller.document.peek_redo_operation() == stable_history, "locked rejects before history mutation")
	var forged := controller.document.get_record("source:0")
	forged.source.authority = "client"
	check(not registry.apply_record("source:0", forged).ok and nodes[0].position == Vector3.ZERO, "record source authority tamper rejected")
	forged = controller.document.get_record("source:0")
	forged.source.id = "0"
	check(not registry.apply_record("source:0", forged).ok, "numeric string not coerced")
	forged = JSON.parse_string(JSON.stringify(controller.document.get_record("source:0")))
	check(registry.apply_record("source:0", forged, true).ok, "JSON integerfloat semantic source parity")
	controller.selected_id = "source:0"
	bodies[0].free()
	check(not controller.handle_action("move", {"delta": [1, 0, 0]}).ok and controller.document.peek_redo_operation() == stable_history and nodes[0].position == Vector3.ZERO, "invalidated targeteddependency atomic rejection")
	# Unrelated invalid dependency does not force world traversal for another object.
	controller.selected_id = "source:2"
	check(controller.handle_action("move", {"delta": [1, 0, 0]}).ok, "independent valid entry editable")
	times.sort()
	print("native synthetic242 hot move+undo: p50=%dus p95=%dus; samples=%d" % [times[times.size() / 2], times[int(ceil(times.size() * 0.95)) - 1], times.size()])
	print("record_hotpath: %d checks, %d failures" % [checks, failures])
	world.free()
	quit(1 if failures else 0)

