extends SceneTree
const Trusted = preload("res://scripts/map_editor/trusted_json.gd")
const Registry = preload("res://scripts/map_editor/object_registry.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
var failures: Array[String] = []
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	# Construct exact IEEE64 values: Godot's decimal parser may itself round
	# neighbouring decimal literals to the same value before the test starts.
	var exact_source: float = PackedByteArray([0x66, 0x66, 0x18, 0xa7, 0x44, 0xdd, 0xec, 0x3f]).decode_double(0)
	var adjacent_attack: float = PackedByteArray([0x68, 0x66, 0x18, 0xa7, 0x44, 0xdd, 0xec, 0x3f]).decode_double(0)
	var original := {"owner": 7, "scale": exact_source, "authority": "source"}
	var transported: Dictionary = Trusted.transport(original)
	check(Trusted.matches(original, original), "exact trusted source accepted")
	check(Trusted.matches(original, transported), "exact trusted JSON transport accepted")
	var forged := transported.duplicate(true)
	forged.scale = adjacent_attack
	check(not Trusted.matches(original, forged), "untrusted adjacent scalar rejected without caller normalization")
	forged = transported.duplicate(true)
	forged.owner = "7"
	check(not Trusted.matches(original, forged), "string authority coercion rejected")
	forged = transported.duplicate(true)
	forged.extra = true
	check(not Trusted.matches(original, forged), "extra authority field rejected")
	var world := Node3D.new()
	root.add_child(world)
	var object := MeshInstance3D.new()
	object.mesh = BoxMesh.new()
	world.add_child(object)
	var camera := Camera3D.new()
	world.add_child(camera)
	var registry := Registry.new()
	check(registry.register_object("pine", object, {"kind": "tree", "model": "pine", "source": original, "transform": {"trusted_scale_hint": exact_source}}).ok, "source registered")
	var source: Dictionary = registry.source_document("trusted-transport")
	source.metadata = {"scale": original.scale, "owner": 7}
	var editor := Controller.new()
	world.add_child(editor)
	check(editor.setup(registry, source, camera, func(): return {"ok": true}, func(_doc): return {"ok": true}).ok, "controller setup")
	check(editor.enter_editor().ok, "editor lease entered")
	for cycle in 30:
		var loaded: Dictionary = Trusted.transport(editor.document.to_dictionary())
		loaded.objects[0].transform.position = [cycle, 0, 0]
		check(editor.install_document(loaded).ok, "fresh transport install cycle " + str(cycle))
		check(Trusted.equal(editor.document.get_record("pine").source, original), "trusted source retained exactly " + str(cycle))
		check(Trusted.equal(editor.document.to_dictionary().metadata, source.metadata), "trusted header retained exactly " + str(cycle))
		check(Trusted.equal(editor.document.get_record("pine").transform.trusted_scale_hint, exact_source), "trusted transform metadata retained exactly " + str(cycle))
	var before: Dictionary = editor.document.to_dictionary()
	var attack := before.duplicate(true)
	attack.objects[0].source.scale = adjacent_attack
	check(not editor.install_document(attack).ok, "controller rejects forged immutable scalar")
	check(editor.document.to_dictionary() == before, "forged install changes no model")
	check(not registry.apply_record("pine", attack.objects[0], true).ok, "registry rejects same scalar before scene mutation")
	attack = before.duplicate(true)
	attack.metadata.scale = adjacent_attack
	check(not editor.install_document(attack).ok, "header forgery rejected")
	attack = before.duplicate(true)
	attack.objects[0].transform.trusted_scale_hint = adjacent_attack
	check(not editor.install_document(attack).ok, "transform opaque forgery rejected")
	world.free()
	for failure in failures: push_error(failure)
	print("trusted JSON: ", checks, " checks, failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
