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
	assert(ProjectSettings.load_resource_pack(here.path_join("NEW_RESOURCES58.zip"),true))
	var parsed: Array=[]
	for rel: String in ["scripts/city/runtime/npc_routine58.gd","scripts/quick_controls/day_night_clock.gd","scripts/shop/npc_economy_visit28.gd","scripts/npc_ambient/ambient_controller28.gd","scripts/city/runtime/npc_threat_life30.gd","scripts/npc_daily_life.gd","scripts/npc_city_daily.gd"]:
		var path: String=here.path_join("patch").path_join(rel)
		assert(FileAccess.get_sha256(path)==rows[rel].sha256)
		var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(path)
		script.take_over_path("res://"+rel)
		var code: int=script.reload()
		if code!=OK or not script.can_instantiate(): quit(2);return
		held58.append(script)
		assert(load("res://"+rel)==script);parsed.append(rel)
	var out_path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out_path=arg.trim_prefix("--qa-out=")
	assert(not out_path.is_empty())
	var file=FileAccess.open(out_path.path_join("PARSE58.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":parsed.size()==7,"parsed":parsed,"scope":"Native GDScript compile and original resource identity only; no city behavior acceptance"},"\t"));file.close()
	quit(0)
