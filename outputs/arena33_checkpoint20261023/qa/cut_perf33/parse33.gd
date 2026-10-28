extends SceneTree
func _initialize():
	run.call_deferred()
func run():
	await create_timer(2).timeout
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out=arg.trim_prefix("--qa-out=")
	var checks := {}
	for path in ["res://scripts/combat/wound_surface_query33.gd","res://scripts/combat/contact_build31.gd","res://scripts/combat/local_wound28.gd","res://scripts/combat/async_cut28.gd"]:
		var script=load(path)
		checks[path]=script!=null and script.can_instantiate()
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":not false in checks.values(),"checks":checks},"\t"))
	quit(0 if not false in checks.values() else 1)
