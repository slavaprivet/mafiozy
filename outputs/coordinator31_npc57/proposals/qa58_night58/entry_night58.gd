extends SceneTree
## DSH_NIGHT58: the controlled-clock night test that no existing flag can express.
## It seeds the shared DayClock BEFORE the city scene is created (quick_controls
## adopts a pre-seeded clock), so the ordinary routine decides - no fixture feeds
## home_sleep and no resident is teleported. The observer switches the SAME clock to
## the morning hour later, so sleep, wake and the physical exit are the real path.
func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var night := 3.0
	var morning := 10.75
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-night-hour="): night = float(argument.trim_prefix("--qa-night-hour="))
		if argument.begins_with("--qa-morning-hour="): morning = float(argument.trim_prefix("--qa-morning-hour="))
	var clock = load("res://scripts/quick_controls/day_night_clock.gd").new()
	clock.set_hour(night)
	clock.running = false
	root.set_meta("mafiozi_visual_clock", clock)
	print("DSH_NIGHT58 stage=seed hour=", night, " running=", clock.running, " morning=", morning)
	var scene: Node = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var observer: Node = load(get_script().resource_path.get_base_dir().path_join("observer_night58.gd")).new()
	observer.night_hour = night
	observer.morning_hour = morning
	scene.add_child(observer)
