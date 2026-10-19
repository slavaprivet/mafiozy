extends SceneTree

var scene: Node3D
var castle: Node3D
var out := ""
var errors: Array[String] = []
var results := {}

func _initialize() -> void: call_deferred("_run")

func ray(a: Vector3, b: Vector3) -> Dictionary:
	return root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(castle.to_global(a), castle.to_global(b), 1))

func explode(hit: Dictionary, label: String) -> Dictionary:
	if hit.is_empty(): return {"ok": false, "reason": "no_physical_hit"}
	return castle.apply_explosion({"position": hit.position, "radius": 0.85, "power": 52.0, "direction": Vector3.FORWARD, "event_id": label})

func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
	scene = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 75000
	while scene.get("preview_ready") != true and Time.get_ticks_msec() < deadline: await process_frame
	castle = scene.get("preview_castle")
	if not is_instance_valid(castle): errors.append("castle_not_ready"); finish(); return
	await ticks(8)
	var groups := {}
	for cell: Dictionary in castle.get("_cells"):
		var group: String = cell.group
		groups[group] = int(groups.get(group, 0)) + 1
	results.groups = groups
	# Actual surface contacts at the foot of a long column and edge of a deep bastion.
	for probe: Dictionary in [
		{"name": "gate_bypass_pier_foot", "group": "gate_bypass_pier", "from": Vector3(10, 1.5, 60), "to": Vector3(10, 1.5, 65)},
		{"name": "bastion_edge", "group": "entrance_bastion31", "from": Vector3(-16.1, 7.14, 75), "to": Vector3(-16.1, 7.14, 68)},
	]:
		var before := 0
		for cell: Dictionary in castle.get("_cells"):
			if cell.group == probe.group and cell.alive: before += 1
		var hit := ray(probe.from, probe.to)
		var response := explode(hit, probe.name)
		await ticks(3)
		var after := 0
		for cell: Dictionary in castle.get("_cells"):
			if cell.group == probe.group and cell.alive: after += 1
		results[probe.name] = {"hit": not hit.is_empty(), "before": before, "after": after, "response": response}
		if hit.is_empty() or after >= before: errors.append(probe.name + "_unbreakable")
	# First layer damage must leave physical collision on every surviving stone nearby.
	var first_hit := ray(Vector3(22.2, 4.6, 64), Vector3(22.2, 4.6, 72))
	results.first_breach = explode(first_hit, "first_skin")
	await ticks(3)
	var survivors := 0
	var missing := 0
	var target := Vector3.ZERO
	for cell: Dictionary in castle.get("_cells"):
		var p: Vector3 = cell.at
		if not cell.alive or cell.group != "south" or absf(p.x - 22.2) > 2.0 or absf(p.y - 4.6) > 1.5: continue
		survivors += 1
		var hit := ray(Vector3(p.x, p.y, 64), Vector3(p.x, p.y, 72))
		if hit.is_empty(): missing += 1; target = p
	results.remaining_skin = {"survivors": survivors, "without_collision": missing, "example": target}
	if survivors == 0 or missing > 0: errors.append("surviving_wall_without_collision")
	# Repeated physical impacts from the same side must reach the remaining masonry.
	var total := 0
	for repeat: int in 4:
		var hit := ray(Vector3(23, 4.59, 64), Vector3(23, 4.59, 72))
		if hit.is_empty(): break
		var response := explode(hit, "second_skin_%d" % repeat)
		total += int(response.get("detached", 0))
		await ticks(3)
	results.repeat_detached = total
	if total == 0: errors.append("second_skin_no_followup_hit")
	results.stats = castle.get_stats()
	finish()

func finish() -> void:
	var report := {"passed": errors.is_empty(), "errors": errors, "results": results}
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "\t")); f.close()
	print("WALLS55 ", JSON.stringify({"passed": errors.is_empty(), "errors": errors}))
	quit(0 if errors.is_empty() else 1)
