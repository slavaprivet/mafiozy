extends SceneTree
## Root integration adapter. No source takeover: uses the merged project's files.
func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var here:String=get_script().resource_path.get_base_dir()
	var script_name:String="stream31.gd" if "--streams31=1" in OS.get_cmdline_user_args() else "fixture31.gd"
	var fixture:Node=load(here.path_join(script_name)).new()
	fixture.candidate=true
	root.add_child(fixture)
