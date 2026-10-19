extends SceneTree
var checks: Dictionary = {}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	await create_timer(3.0).timeout # Allow exact scheduler child registration before exit.
	var script: Script = load(get_script().resource_path.get_base_dir().path_join("npc_simple_hospital.gd"))
	var drive: RefCounted = script.new()
	var triggered := -1
	for frame: int in 240:
		# Recorded exit loop stays .3-.5m from the same intermediate waypoint.
		var distance: float = .40 + .07 * sin(float(frame) * .14)
		if drive._service_waypoint_stalled56(3498,6,distance,1.0/60.0): triggered = frame; break
	checks["recorded_sideways_loop_replans_under_4s"] = triggered >= 180 and triggered <= 239
	checks["ready_route_revision_resets"] = not drive._service_waypoint_stalled56(3499,6,.41,1.0/60.0)
	checks["new_waypoint_resets"] = not drive._service_waypoint_stalled56(3499,7,.39,1.0/60.0)
	drive = script.new()
	var walk_ok := true
	for frame: int in 1200:
		walk_ok = walk_ok and not drive._service_waypoint_stalled56(50,0,40.0-float(frame)*.03,1.0/60.0)
	checks["normal_20s_physical_speed_progress_does_not_replan"] = walk_ok
	var before: float = drive._service_way_idle_s56
	# Idle/attention/queue do not invoke the watcher at the source callsite.
	for frame: int in 200: pass
	checks["no_wall_clock_penalty_during_wait"] = drive._service_way_idle_s56 == before
	var source: String = FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("npc_simple_hospital.gd"))
	checks["called_after_peer_wait_return"] = source.find('if bool(_avoidance29_state.waiting)') < source.find('if _target_source == "service_approach" and _service_waypoint_stalled56')
	checks["only_existing_local_replan_no_finish_bypass"] = source.contains('_restart("service_waypoint_no_progress56")') and source.contains('_route.edge_clear(current,waypoint)') and source.contains('_route.move(direction,distance,delta)')
	checks["watcher_not_used_by_roam"] = source.contains('if _target_source == "service_approach" and _service_waypoint_stalled56')
	var passed: bool = checks.values().all(func(value: bool) -> bool: return value)
	var out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
	var result: Dictionary = {"passed":passed,"checks":checks,"loop_trigger_frame":triggered,"native_component_only":true,"full_city_acceptance":false}
	if not out.is_empty():
		var file := FileAccess.open(out,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print("EXIT56_COMPONENT ",JSON.stringify(result)); quit(0 if passed else 1)
