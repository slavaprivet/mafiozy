extends SceneTree
## Opt-in checkpoint-native negative fixture. No positive root admission.
const Receipt = preload("res://scripts/map_editor/printshop_interior_owner.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		failures.append("frozen actual-main scene unavailable")
		finish()
		return
	var main: Node3D = scene.instantiate()
	root.add_child(main)
	await process_frame
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_editor/catalog.json"))
	if not parsed is Dictionary:
		failures.append("frozen catalog unavailable")
		main.queue_free()
		finish()
		return
	var owner := Receipt.new()
	var begun: Dictionary = owner.begin(main, parsed)
	check(not begun.ok and begun.get("error") == Receipt.HOLD, "complete actual Printshop capture remains HOLD without revision/seal")
	check(begun.get("nodes", 0) > 0 and begun.get("meshCache", 0) > 0 and begun.get("materialCache", 0) > 0 and begun.get("doors", 0) == 2, "interior node, generated mesh/material and two door identities captured")
	check(owner.verified_root() == null, "no borrowed root is issued")
	var verified: Dictionary = owner.verify()
	check(not verified.ok and verified.get("error") == Receipt.HOLD, "unchanged snapshot still cannot prove unobserved writer history")
	main.queue_free()
	await process_frame
	check(not owner.verify().ok and owner.verified_root() == null, "owner lifetime loss remains fail-closed")
	finish()

func finish() -> void:
	for failure: String in failures: push_error(failure)
	print("PRINTSHOP_INTERIOR_OWNER_QA ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "verifiedRoots": 0, "productionWired": false, "gpuAccepted": false}))
	quit(0 if failures.is_empty() else 1)
