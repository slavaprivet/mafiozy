extends SceneTree

var scene: Node3D
var castle: Node3D
var player: CharacterBody3D
var out := ""
var errors: Array[String] = []
var results := {}

func _initialize() -> void: call_deferred("_run")
func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func aim(normal: Vector3) -> void:
	player.set("_camera_yaw", atan2(-normal.x, -normal.z))
	player.set_mouse_captured(true)

func ray(a: Vector3, b: Vector3) -> Dictionary:
	return root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(castle.to_global(a), castle.to_global(b), 1))

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
	scene = load("res://scenes/castle.tscn").instantiate(); root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 75000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline: await process_frame
	castle = scene.get("preview_castle"); player = scene.get("_player")
	if not is_instance_valid(castle) or not is_instance_valid(player): errors.append("not_ready"); finish(); return
	await ticks(150)
	var stairs := []
	for normal: Vector3 in [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]:
		var lateral := Vector3(-normal.z, 0, normal.x)
		var foot := normal * (68.0 - 2.2 - 74.0 * 0.36 - 1.0) + lateral * (68.0 * 0.42)
		player.global_position = castle.to_global(foot + Vector3.UP * 0.3); player.velocity = Vector3.ZERO
		aim(normal); await ticks(10)
		Input.action_press(player.ACTION_FORWARD)
		var best_y := 0.0
		for frame: int in 940:
			await physics_frame
			best_y = maxf(best_y, castle.to_local(player.global_position).y)
			if best_y >= 18.5: break
		Input.action_release(player.ACTION_FORWARD)
		stairs.append({"normal": normal, "best_y": best_y, "position": castle.to_local(player.global_position)})
		if best_y < 18.5: errors.append("stairs_blocked:" + str(normal))
	results.stairs = stairs
	# Gate passage is blocked when shut and physically clear after normal opening.
	castle.set_gate(false); await ticks(120)
	var shut := ray(Vector3(0, 3, 64), Vector3(0, 3, 73))
	castle.set_gate(true); await ticks(120)
	var opened := ray(Vector3(0, 3, 64), Vector3(0, 3, 73))
	results.gate = {"shut_solid": not shut.is_empty(), "open_clear": opened.is_empty()}
	if shut.is_empty() or not opened.is_empty(): errors.append("gate_collision_regression")
	# A breach at walking height must remove both visible skins and their barriers.
	var hit := ray(Vector3(40, 1.3, 64), Vector3(40, 1.3, 72))
	if hit.is_empty(): errors.append("wall_missing_before_breach")
	else: castle.apply_explosion({"position": hit.position, "radius": 2.3, "power": 240, "direction": Vector3.BACK})
	await ticks(400)
	player.global_position = castle.to_global(Vector3(40, 0.3, 64)); player.velocity = Vector3.ZERO; aim(Vector3.BACK)
	await ticks(10); Input.action_press(player.ACTION_FORWARD)
	await ticks(180); Input.action_release(player.ACTION_FORWARD)
	var reached: Vector3 = castle.to_local(player.global_position)
	results.breach = {"player_end": reached, "neighbor_still_solid": not ray(Vector3(46, 1.3, 64), Vector3(46, 1.3, 72)).is_empty()}
	if reached.z < 70.0: errors.append("player_cannot_cross_breach")
	if not results.breach.neighbor_still_solid: errors.append("untouched_neighbor_intangible")
	# Preserve the existing one-tile floor destruction rule.
	var floor_before := 0
	for cell: Dictionary in castle.get("_cells"):
		if cell.group == "keep_floor" and cell.alive: floor_before += 1
	castle.apply_explosion({"position": castle.to_global(Vector3(0, 0.12, -8)), "radius": 1.0, "power": 40, "direction": Vector3.DOWN})
	await ticks(3)
	var floor_after := 0
	for cell: Dictionary in castle.get("_cells"):
		if cell.group == "keep_floor" and cell.alive: floor_after += 1
	results.floor = {"before": floor_before, "after": floor_after}
	if floor_before - floor_after != 1: errors.append("floor_tile_scope_changed")
	finish()

func finish() -> void:
	var f := FileAccess.open(out, FileAccess.WRITE); f.store_string(JSON.stringify({"passed": errors.is_empty(), "errors": errors, "results": results}, "\t")); f.close()
	print("NAVIGATION55 ", JSON.stringify({"passed": errors.is_empty(), "errors": errors}))
	if is_instance_valid(scene): scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
