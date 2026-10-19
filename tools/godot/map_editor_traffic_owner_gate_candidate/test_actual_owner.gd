extends SceneTree
const Gate = preload("res://scripts/map_editor/traffic_owner_gate.gd")
const HOUSE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	for _frame in 120:
		if bool(main.get("preview_ready")): break
		await physics_frame
	check(bool(main.get("preview_ready")), "actual main ready")
	var transport: Node3D = main.get("preview_transport")
	check(is_instance_valid(transport), "actual transport present")
	var body: RigidBody3D = transport.get("body")
	var player: CharacterBody3D = transport.get("player")
	var before := [body.global_transform, body.collision_layer, body.collision_mask,
		player.collision_layer, player.collision_mask]
	var gate := Gate.new()
	var seen: Dictionary = gate.inspect(main, HOUSE)
	check(seen.get("ok", false), "real owner read-only receipt")
	var receipt: Dictionary = seen.get("receipt", {})
	check(gate.verify(receipt), "real owner receipt verifies")
	check(not gate.verify({"owner_instance_id": main.get_instance_id()}), "forged receipt rejected")
	var edit: Dictionary = gate.prepare_geometry_edit(receipt, {"source_id": HOUSE, "action": "move"})
	check(not edit.get("ok", true) and edit.get("error", "") == "traffic_geometry_transaction_owner_missing" and edit.get("token") == null, "no real geometry transaction refuses without token")
	check(before == [body.global_transform, body.collision_layer, body.collision_mask,
		player.collision_layer, player.collision_mask], "car and player collision unchanged")
	var old_layer := body.collision_layer
	body.collision_layer = 0
	check(not gate.verify(receipt), "body collision drift invalidates receipt")
	body.collision_layer = old_layer
	check(gate.verify(receipt), "restored owner verifies")
	var missing: Dictionary = gate.inspect(main, "REBUILD-VISUAL-absent-source")
	check(not missing.get("ok", true) and missing.get("error", "") == "source_building_not_in_live_crop", "absent source refuses")
	main.free()
	print(JSON.stringify({"checks": checks, "failures": failures, "actual_owner_receipt": seen.get("ok", false), "geometry_edit_admitted": false, "gpu": false}))
	if not failures.is_empty():
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
