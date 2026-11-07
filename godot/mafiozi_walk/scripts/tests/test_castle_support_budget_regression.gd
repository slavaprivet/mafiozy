extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	var packed := load("res://scenes/castle.tscn") as PackedScene
	if packed == null:
		print("SUPPORT_BUDGET FAIL scene")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await process_frame
	var castle: Node = scene.get("preview_castle")
	if not is_instance_valid(castle):
		print("SUPPORT_BUDGET FAIL castle")
		quit(1)
		return
	var wall_half := float(castle.call("wall_half"))
	var result: Dictionary = castle.call("apply_explosion", {
		"position": castle.global_position + Vector3(13.0, 6.0, wall_half),
		"radius": 5.5,
		"power": 240.0,
		"direction": Vector3(0.0, -0.2, -1.0),
		"event_id": "support_budget:1",
	})
	for frame: int in 300:
		await physics_frame
	var stats: Dictionary = castle.call("get_stats")
	var pending_at_300 := int(stats.get("support_pending", -1))
	var drain_frames := 0
	while int(stats.get("support_pending", 0)) > 0 and drain_frames < 600:
		await physics_frame
		drain_frames += 1
		stats = castle.call("get_stats")
	var report := {
		"direct": result.get("detached", 0),
		"collapsed": stats.get("collapsed", 0),
		"pending_at_300": pending_at_300,
		"pending_final": stats.get("support_pending", -1),
		"drain_frames_after_300": drain_frames,
		"checks_peak": stats.get("support_checks_peak", -1),
		"work_us_peak": stats.get("support_work_us_peak", -1),
		"state_us_peak": stats.get("support_state_peak_us", -1),
		"state_peak_group": stats.get("support_state_peak_group", ""),
		"falling": stats.get("falling", -1),
		"falling_probes_peak": stats.get("falling_support_probes_peak", -1),
	}
	var failed: Array[String] = []
	if not bool(result.get("ok", false)): failed.append("blast")
	if int(report.collapsed) <= 0: failed.append("no_real_cascade")
	if int(report.pending_at_300) > 32: failed.append("queue_backlog_at_300")
	if int(report.pending_final) != 0: failed.append("queue_not_drained")
	if int(report.checks_peak) > 32: failed.append("check_budget")
	if int(report.work_us_peak) > 4000: failed.append("support_frame_budget")
	if int(report.state_us_peak) > 1500: failed.append("single_state_spike")
	if int(report.falling) > 150: failed.append("rigid_body_cap")
	if int(report.falling_probes_peak) > 24: failed.append("settle_probe_cap")
	print("SUPPORT_BUDGET REPORT ", JSON.stringify(report))
	print("SUPPORT_BUDGET RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0 if failed.is_empty() else 1)
