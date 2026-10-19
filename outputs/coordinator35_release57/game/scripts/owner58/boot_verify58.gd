extends SceneTree
## Owner58 verification boot: opens the ONE common scene exactly as the shipped
## bootstrap does, adds a read-only watcher (state lines and frame timing), and saves
## a screenshot of the opened build. It touches no body, route, claim or clock.
var _out := ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt-dir="): _out = argument.trim_prefix("--receipt-dir=")
		elif argument.begins_with("--qa-out="): _out = argument.trim_prefix("--qa-out=")
	_start.call_deferred()

func _start() -> void:
	var scene: Node3D = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	root.title = "Мафиози — проверка жителей (owner58)"
	var watcher: Node = load("res://scripts/owner58/owner58_watch.gd").new()
	watcher.name = "Owner58Watch"
	scene.add_child(watcher)
	if DisplayServer.get_name() == "headless" or _out.is_empty(): return
	# One picture of the build the owner is asked to open, taken from the live viewport.
	var deadline: int = Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if scene.get("preview_ready") == true: break
		await process_frame
	for tick: int in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("opened.png"))
