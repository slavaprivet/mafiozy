extends SceneTree

var scene: Node3D
var castle: Node3D
var catapult: Node3D
var camera: Camera3D
var out := ""
var directory := ""
var errors: Array[String] = []
var results := []

func _initialize() -> void: call_deferred("_run")

func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))

func living(group: String) -> int:
	var count := 0
	for cell: Dictionary in castle.get("_cells"):
		if cell.group == group and cell.alive: count += 1
	return count

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-dir="): directory = arg.trim_prefix("--qa-dir=")
	scene = load("res://scenes/castle.tscn").instantiate(); root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 75000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline: await process_frame
	castle = scene.get("preview_castle"); catapult = scene.get("preview_catapult")
	if not is_instance_valid(castle) or not is_instance_valid(catapult): errors.append("not_ready"); finish(); return
	await ticks(30)
	camera = Camera3D.new(); scene.add_child(camera); camera.current = true; camera.far = 500; camera.fov = 63
	for probe: Dictionary in [
		{"name": "layered_gate_wall", "group": "entrance_bastion31", "cart": Vector3(14.35, 0.05, 48), "aim": Vector3(14.35, 7, 68), "camera": Vector3(5, 6.5, 53)},
		{"name": "column_foot", "group": "gate_bypass_pier", "cart": Vector3(-4, 0.05, 45), "aim": Vector3(-10, 3.8, 63), "camera": Vector3(-17, 6, 53)},
		{"name": "keep_wall", "group": "keep", "cart": Vector3(33, 0.05, -8), "aim": Vector3(13, 6.5, -8), "camera": Vector3(26, 7, 3)},
	]:
		var cart: Node3D = catapult.get("_cart")
		cart.global_position = castle.to_global(probe.cart)
		camera.global_position = castle.to_global(probe.camera); camera.look_at(castle.to_global(probe.aim), Vector3.UP)
		await ticks(20); await shot(probe.name + "_before")
		var before := living(probe.group)
		catapult._set_stone_on_spoon()
		for frame: int in 180:
			await physics_frame
			if catapult.snapshot().stone_on_spoon: break
		catapult.aim_at(castle.to_global(probe.aim)); catapult._fire()
		var fired := false
		for frame: int in 480:
			await physics_frame
			if catapult.snapshot().flying: fired = true
			if fired and not catapult.snapshot().flying: break
		var impact: Dictionary = catapult.snapshot().last_impact
		await ticks(120); await shot(probe.name + "_after")
		var after := living(probe.group)
		if not fired or not impact.get("ok", false) or after >= before: errors.append(probe.name + "_shot_failed")
		results.append({"case": probe.name, "fired": fired, "before": before, "after": after, "impact": impact})
	finish()

func finish() -> void:
	var f := FileAccess.open(out, FileAccess.WRITE); f.store_string(JSON.stringify({"passed": errors.is_empty(), "errors": errors, "results": results}, "\t")); f.close()
	print("PROJECTILES55 ", JSON.stringify({"passed": errors.is_empty(), "errors": errors})); quit(0 if errors.is_empty() else 1)
