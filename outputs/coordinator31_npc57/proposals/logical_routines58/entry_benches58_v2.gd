extends SceneTree
var held58: Array[Script] = []
func _initialize() -> void: _start.call_deferred()
func _start() -> void:
	await create_timer(3.0).timeout
	var here: String=get_script().resource_path.get_base_dir()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(here.path_join("PATCH.json")))
	var rows: Dictionary={}
	for row: Dictionary in manifest.files:
		rows[row.path]=row
		if row.base_sha256 != null: assert(FileAccess.get_sha256("res://"+row.path)==row.base_sha256)
		else: assert(not FileAccess.file_exists("res://"+row.path))
	# New resource IDs must exist in the VFS before a preload parses their path.
	assert(ProjectSettings.load_resource_pack(here.path_join("NEW_BENCH_RESOURCES58_V2.zip"),true))
	var parsed: Array=[]
	for rel: String in ["scripts/city/runtime/npc_routine58.gd","scripts/city/runtime/npc_leisure58.gd","scripts/quick_controls/day_night_clock.gd","scripts/shop/npc_economy_visit28.gd","scripts/npc_ambient/ambient_controller28.gd","scripts/city/runtime/npc_threat_life30.gd","scripts/npc_daily_life.gd","scripts/npc_city_daily.gd"]:
		var path: String=here.path_join("patch").path_join(rel)
		assert(FileAccess.get_sha256(path)==rows[rel].sha256)
		var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(path)
		script.take_over_path("res://"+rel)
		var code: int=script.reload()
		if code!=OK or not script.can_instantiate(): quit(2);return
		held58.append(script)
		assert(load("res://"+rel)==script);parsed.append(rel)

	var clock=load("res://scripts/quick_controls/day_night_clock.gd").new()
	clock.set_hour(20.8);clock.running=false
	root.set_meta("mafiozi_visual_clock",clock)
	var scene:Node=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	scene.add_child(load(here.path_join("observer_benches58_v2.gd")).new())
