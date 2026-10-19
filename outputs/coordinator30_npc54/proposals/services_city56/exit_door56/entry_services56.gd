extends SceneTree
var _candidate_scripts56: Array = []

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var directory: String = get_script().resource_path.get_base_dir()
	var rows: Array = []
	for name: String in ["npc_simple_hospital.gd","npc_restaurant_visit28.gd"]:
		var source: String = directory.path_join(name)
		var target: String = "res://scripts/hospital/"+name
		var candidate: GDScript = load(source)
		assert(candidate != null and candidate.can_instantiate())
		var row: Dictionary = {"candidate":source,"target":target,"candidate_sha256":FileAccess.get_sha256(source),"shared_disk_sha256":FileAccess.get_sha256(target),"source_sha256":candidate.source_code.sha256_text()}
		candidate.take_over_path(target)
		assert(ResourceLoader.get_cached_ref(target) == candidate)
		_candidate_scripts56.append(candidate); rows.append(row)
	var out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
	assert(not out.is_empty())
	var receipt := FileAccess.open(out.path_join("CANDIDATE_OVERLAY56.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"shared_files_modified":false,"runtime_candidate_overlay":true,"ordinary_merged_acceptance":false,"scripts":rows},"\t")); receipt.close()
	var scene: Node = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.add_child(load(get_script().resource_path.get_base_dir().path_join("observer_services56.gd")).new())
