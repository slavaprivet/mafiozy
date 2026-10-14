extends "res://test_full_registry_perf.gd"
const AuthoredFactoryPerf = preload("res://authored_factory_perf.gd")
const AuthoredRegistryPerf = preload("res://authored_registry_perf.gd")
func authored_factory_class() -> Script: return AuthoredFactoryPerf
func authored_registry_class() -> Script: return AuthoredRegistryPerf

func exercise_editor_actions(session: Dictionary, templates: Array) -> void:
	# Same actual composite/controller, original GLB/procedural/parking resources.
	# Source-owner gates remain explicit fixtures; not a production pause proof.
	for id: String in templates:
		session.controller.selected_id = id
		var original: Dictionary = session.controller.document.get_record(id)
		check(session.controller.handle_action("rotate", {"degrees": 17.0}).ok, "actual family rotate " + id)
		var rotated: Dictionary = session.controller.document.get_record(id)
		check(not Trusted.equal(original.transform, rotated.transform), "rotation changes native record " + id)
		check(session.controller.handle_action("undo").ok, "rotation undo " + id)
		check(Trusted.equal(original, session.controller.document.get_record(id)), "rotation undo restores exact opaque/native record " + id)
		check(session.controller.handle_action("redo").ok, "rotation redo " + id)
		check(Trusted.equal(rotated, session.controller.document.get_record(id)), "rotation redo restores exact updated record " + id)
		check(session.controller.handle_action("delete").ok, "actual family deletion " + id)
		check(not session.controller.document.has_record(id), "deleted family absent from saved model " + id)
		var deleted_bounds: Variant = session.composite.world_bounds(id)
		check(deleted_bounds == null or (deleted_bounds is AABB and deleted_bounds.size == Vector3.ZERO), "deleted family unpickable " + id)
		check(session.controller.handle_action("undo").ok, "deletion undo " + id)
		check(Trusted.equal(rotated, session.controller.document.get_record(id)), "deletion undo exact source record " + id)
		check(session.controller.handle_action("redo").ok, "deletion redo " + id)
		check(not session.controller.document.has_record(id), "redo removes family again " + id)
		check(session.controller.handle_action("undo").ok, "restore source family for fresh-load parity " + id)
		check(Trusted.equal(rotated, session.controller.document.get_record(id)), "source family intact before serialization " + id)
	check(session.controller.handle_action("camera_top").ok, "full map top view action")
	check(session.controller.camera.mode == "top", "actual native editor top mode")
	check(session.controller.handle_action("camera_fly").ok, "full map fly action")
	check(session.controller.camera.mode == "fly", "actual native editor fly mode")
