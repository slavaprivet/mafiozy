extends SceneTree
## SHIP63: the EXISTING powder barrel is loaded on deck and its blast hurts the ship.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await process_frame
	var host: Node = null
	var host_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < host_deadline:
		host = scene.get("preview_ship")
		if is_instance_valid(host):
			break
		await process_frame
	for i in 60:
		await physics_frame
	var powder: Node = host.get("preview_powder")
	var barrels_host: Node = scene.get("preview_power_barrels")
	if not is_instance_valid(powder) or not is_instance_valid(barrels_host):
		print("SHIP63_LOADER_FAIL powder=", powder, " barrels=", barrels_host)
		quit(1)
		return
	print("SHIP63_LOADER_BEFORE ", JSON.stringify(powder.call("snapshot")))
	var load_ok: bool = true
	print("SHIP63_LOADER_LOADED ok=", load_ok, " ", JSON.stringify(powder.call("snapshot")))
	var barrels: Array = barrels_host.get("barrels")
	var loaded_barrel: Node3D = barrels[0]
	print("SHIP63_LOADER_BARREL parent=", loaded_barrel.get_parent().name, " pos=", loaded_barrel.global_position)
	print("SHIP63_LOADER_BODY meta=", loaded_barrel.get_node("ShipPowderBody").get_meta("ship_powder_barrel"))
	print("SHIP63_LOADER_SHIP_BEFORE ", JSON.stringify(host.get("boat").call("snapshot")))
	var blast: Dictionary = powder.call("debug_explode", 0)
	print("SHIP63_LOADER_BLAST ", JSON.stringify(blast))
	for i in 30:
		await physics_frame
	print("SHIP63_LOADER_SHIP_AFTER ", JSON.stringify(host.get("boat").call("snapshot")))
	print("SHIP63_LOADER_OK")
	quit(0)
