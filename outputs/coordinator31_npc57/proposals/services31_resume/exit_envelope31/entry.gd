extends SceneTree
var kept:Array=[]
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	var here:String=get_script().resource_path.get_base_dir()
	if "--candidate31=1" in OS.get_cmdline_user_args():
		var script:=GDScript.new()
		script.source_code=FileAccess.get_file_as_string(here.path_join("patch/scripts/hospital/npc_restaurant_visit28.gd"))
		script.take_over_path("res://scripts/hospital/npc_restaurant_visit28.gd")
		assert(script.reload()==OK);assert(script.can_instantiate());kept.append(script)
	root.add_child(load(here.path_join("fixture.gd")).new())
