extends SceneTree
const Candidate = preload("res://candidate/printshop_placement.gd")
const Finish = preload("res://scripts/preview_interior_finish.gd")
class Owner extends Node3D:
	var candidate: Node3D
	var inject_reentry := false
	func held() -> bool:
		if inject_reentry: candidate.rollback_placement(RefCounted.new())
		return true
	func prepare(_request: Dictionary) -> Dictionary: return {"ok": true, "receipt": RefCounted.new()}
	func validate(_receipt: RefCounted, _request: Dictionary) -> Dictionary: return {"ok": true}
	func commit(_receipt: RefCounted, _request: Dictionary) -> Dictionary: return {"ok": true}
	func rollback(_receipt: RefCounted, _request: Dictionary) -> Dictionary: return {"ok": true}
	func can_resume(_frame: Transform3D) -> Dictionary: return {"ok": true}

func _initialize() -> void: call_deferred("run")
func run() -> void:
	# Minimal node fixture isolates the actual transaction methods. It is NOT an asset admission.
	var owner := Owner.new()
	root.add_child(owner)
	var placement := Node3D.new()
	placement.set_meta("source_id", Candidate.SOURCE_ID)
	owner.add_child(placement)
	var visual := Node3D.new()
	placement.add_child(visual)
	var candidate := Candidate.new()
	owner.add_child(candidate)
	candidate.ready_for_use = true
	candidate._visual = visual
	owner.candidate = candidate
	var callbacks := {"held": owner.held, "prepare": owner.prepare, "validate": owner.validate, "commit": owner.commit, "rollback": owner.rollback, "can_resume": owner.can_resume}
	var configure: Dictionary = candidate.configure_placement_owner(owner, placement, callbacks)
	var before: Dictionary = candidate.placement_state()
	var forged: Dictionary = candidate.rollback_placement(RefCounted.new())
	var after_forged: Dictionary = candidate.placement_state()
	# Reset only test fixture state, not a proposed production repair.
	candidate._retained = false
	var begin: Dictionary = candidate.begin_editor_placement()
	owner.inject_reentry = true
	var ending: Dictionary = candidate.end_editor_placement()
	var after_end: Dictionary = candidate.placement_state()
	owner.inject_reentry = false
	var extra := CollisionShape3D.new()
	extra.shape = BoxShape3D.new()
	placement.add_child(extra)
	var addition_live: bool = candidate._live()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = 1
	var changes := {"multimesh": 0, "shader_material": 0, "mesh": 0}
	mm.changed.connect(func() -> void: changes.multimesh += 1)
	mm.mesh.changed.connect(func() -> void: changes.mesh += 1)
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(10, 0, 0)))
	var after_mm_set: int = changes.multimesh
	mm.mesh.size = Vector3(4, 4, 4)
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform float value = 1.0;"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.changed.connect(func() -> void: changes.shader_material += 1)
	material.set_shader_parameter("value", 99.0)
	# Actual source finish uniforms are explicit numeric values; no GPU reflection needed.
	var actual_material := ShaderMaterial.new()
	actual_material.shader = Finish.shared_shader("brick", false)
	actual_material.set_shader_parameter("source_origin_m", Vector3(3, 0, 7))
	actual_material.set_shader_parameter("source_albedo_linear", Vector3(.2, .4, .6))
	actual_material.set_shader_parameter("source_roughness", .82)
	var actual_snapshot := {}
	var uniform_names := ["source_origin_m", "source_albedo_linear", "source_roughness"]
	for uniform_name in uniform_names:
		actual_snapshot[uniform_name] = actual_material.get_shader_parameter(uniform_name)
	var actual_changed := {"count": 0}
	actual_material.changed.connect(func() -> void: actual_changed.count += 1)
	var detected := {}
	for uniform_name in uniform_names:
		var original: Variant = actual_snapshot[uniform_name]
		actual_material.set_shader_parameter(uniform_name, original + Vector3.ONE if original is Vector3 else original + 1.0)
		detected[uniform_name] = actual_material.get_shader_parameter(uniform_name) != original
		actual_material.set_shader_parameter(uniform_name, original)
	print(JSON.stringify({"actual_finish_uniform_snapshot_detects_each": detected, "actual_finish_changed_signals": actual_changed.count, "known_numeric_parameters_cpu_exact": true, "source_compiled_lifecycle": "HOLD after reload even if resource identity and file hash restored"}))
	print(JSON.stringify({"fixture":"minimal actual transaction methods, not original GLB admission", "configure": configure, "forged_rollback": forged, "before": before, "after_forged": after_forged, "begin": begin, "end_with_held_callback_reentry": ending, "after_end": after_end, "added_collision_child_live": addition_live, "multimesh_transform_changed_signals": after_mm_set, "nested_mesh_changed": changes.mesh, "forwarded_multimesh_changed": changes.multimesh, "shader_parameter_changed_signals": changes.shader_material, "gpu": false}))
	owner.free()
	quit(0)
