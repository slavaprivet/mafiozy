extends SceneTree
## DSH_NIGHT58: the night window judged by the PROJECT'S OWN liveness observer.
## It seeds the shared DayClock at the night hour before the scene exists, adds the
## release observer chain (observer_soak58_v5 -> v4 -> v3 -> v2 -> mass -> perf), then
## moves the same clock to the morning hour. The resulting SOAK31.json is consumed by
## audit_spatial_liveness31.py and audit_routine58.py unchanged.
func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var night := 3.0
	var morning := 10.75
	var switch_after := 240.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-night-hour="): night = float(argument.trim_prefix("--qa-night-hour="))
		if argument.begins_with("--qa-morning-hour="): morning = float(argument.trim_prefix("--qa-morning-hour="))
		if argument.begins_with("--qa-night-seconds="): switch_after = float(argument.trim_prefix("--qa-night-seconds="))
	var clock = load("res://scripts/quick_controls/day_night_clock.gd").new()
	clock.set_hour(night)
	clock.running = false
	root.set_meta("mafiozi_visual_clock", clock)
	print("DSH_NIGHT58 stage=seed hour=", night, " running=", clock.running, " switch_after_s=", switch_after, " morning=", morning)
	var scene: Node = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var observer_path: String = get_script().resource_path.get_base_dir().path_join("../qa58_merged_v5/observer_soak58_v5.gd")
	var observer_script: Script = load(observer_path)
	if observer_script == null:
		print("DSH_NIGHT58 stage=failed reason=observer_missing path=", observer_path)
		quit(2)
		return
	scene.add_child(observer_script.new())
	await create_timer(switch_after).timeout
	clock.set_hour(morning)
	print("DSH_NIGHT58 stage=morning hour=", morning)
