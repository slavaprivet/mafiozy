extends SceneTree
const Tx = preload("res://scripts/map_editor/ordinary_building_tx.gd")
const Owner = preload("res://scripts/map_editor/terrain_owner.gd")
const Inventory = preload("res://scripts/map_editor/native_building_inventory.gd")
const HOUSE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"
class FixtureToken extends RefCounted:
	var fail_commit := false
	func verify() -> Dictionary: return {"ok": true, "ready": true, "pending": false}
	func commit(_change: Dictionary) -> Dictionary: return {"ok": not fail_commit, "ready": not fail_commit, "pending": false}
	func rollback() -> Dictionary: return {"ok": true, "ready": true, "pending": false}
var checks := 0
var failures: Array[String] = []
var terrain: RefCounted
var main: Node3D
var deny_traffic := false
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func synthetic(_request: Dictionary, domain: String) -> Dictionary:
	var token := FixtureToken.new()
	token.fail_commit = deny_traffic and domain == "traffic"
	return {"ok": true, "token": token}
func real_terrain(request: Dictionary) -> Dictionary: return terrain.issue(request, main)
func grants() -> Dictionary:
	return {"pause": Callable(self, "synthetic").bind("pause"), "terrain": Callable(self, "real_terrain"), "navigation": Callable(self, "synthetic").bind("navigation"), "traffic": Callable(self, "synthetic").bind("traffic")}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	for frame in 120:
		if bool(main.get("preview_ready")): break
		await physics_frame
	check(bool(main.get("preview_ready")), "actual pinned main ready")
	terrain = Owner.new()
	var tx := Tx.new()
	check(tx.select(main, HOUSE).get("ok", false), "ordinary actual house selected")
	paused = true
	await process_frame
	var request := {"source_id": HOUSE, "action": "move", "old_frame": tx._row.visual.global_transform, "body_count": tx._row.native_sibling_bodies.size(), "owner_instance_id": main.get_instance_id()}
	var admitted: Dictionary = terrain.issue(request, main)
	print("TERRAIN_ADMISSION ", admitted.get("error", "ok"))
	check(admitted.get("ok", false) and admitted.get("owner", "") == "actual-main-terrain-water-collision", "real owner receipt issued")
	if not admitted.get("ok", false):
		print(JSON.stringify({"checks": checks, "failures": failures, "actualTerrainWaterCollisionReceipt": false}))
		quit(1)
		return
	if admitted.get("ok", false):
		check(admitted.token.verify().get("ok", false), "real receipt verifies")
		check(admitted.get("terrain_strips", 0) > 0 and admitted.get("water_cells", 0) == 303, "real strips and water count")
	var fingerprint := Inventory.new()
	var original := fingerprint.fingerprint(main)
	check(tx.move(Vector3(1.25, 0, -0.5), grants()).get("ok", false), "actual terrain receipt admits dry move")
	var moved := fingerprint.fingerprint(main)
	var vertical: Dictionary = tx.move(Vector3(0, 0.5, 0), grants())
	check(not vertical.get("ok", false) and vertical.get("rolled_back", false), "vertical support failure rolls back")
	check(fingerprint.fingerprint(main) == moved, "vertical failure exact scene restoration")
	var water_overlap: Dictionary = tx.move(Vector3(-28.7, 0, 0), grants())
	check(not water_overlap.get("ok", false) and water_overlap.get("rolled_back", false), "actual water footprint failure rolls back")
	check(fingerprint.fingerprint(main) == moved, "water failure exact scene restoration")
	var crop: Dictionary = tx.move(Vector3(1000, 0, 0), grants())
	check(not crop.get("ok", false) and crop.get("rolled_back", false), "out-of-crop terrain failure rolls back")
	check(fingerprint.fingerprint(main) == moved, "crop failure exact scene restoration")
	deny_traffic = true
	var traffic: Dictionary = tx.move(Vector3(0.25, 0, 0), grants())
	check(not traffic.get("ok", false) and traffic.get("rolled_back", false), "later traffic failure rolls back real terrain receipt")
	check(fingerprint.fingerprint(main) == moved, "later failure exact scene restoration")
	deny_traffic = false
	var strips: Array = admitted.token.snapshot[1]
	request.old_frame = tx._row.visual.global_transform
	var shape: BoxShape3D = strips[0][8]
	var old_size := shape.size
	shape.size = old_size + Vector3(0.01, 0, 0)
	check(not admitted.token.verify().get("ok", true), "same resource shape mutation revokes receipt")
	check(not terrain.issue(request, main).get("ok", true), "mutated physical floor refuses new receipt")
	shape.size = old_size
	check(terrain.issue(request, main).get("ok", false), "restored physical floor readmitted")
	var water_material: ShaderMaterial = admitted.token.snapshot[10]
	var old_depth: Variant = water_material.get_shader_parameter("default_depth")
	water_material.set_shader_parameter("default_depth", 9.0)
	check(not admitted.token.verify().get("ok", true), "same water material mutation revokes receipt")
	water_material.set_shader_parameter("default_depth", old_depth)
	check(terrain.issue(request, main).get("ok", false), "restored native water readmitted")
	check(tx.undo(grants()).get("ok", false), "real terrain owner permits undo")
	check(fingerprint.fingerprint(main) == original, "undo exact scene restoration")
	paused = false
	main.free()
	var report := {"checks": checks, "failures": failures, "actualTerrainWaterCollisionReceipt": true, "otherOwnersSynthetic": true, "productionModified": false, "gpu": false}
	print(JSON.stringify(report))
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
