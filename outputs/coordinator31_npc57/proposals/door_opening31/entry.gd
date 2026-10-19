extends SceneTree
var candidates:Array=[]
func _initialize()->void:_start.call_deferred()
func _start()->void:
	var here:String=get_script().resource_path.get_base_dir()
	if OS.get_cmdline_user_args().has("--candidate31=1"):
		for rel:String in ["scripts/city/runtime/npc_city_clone_door_swing.gd","scripts/hospital/npc_door_clearance31.gd","scripts/hospital/npc_simple_hospital.gd"]:
			var script:=GDScript.new()
			var source:String=FileAccess.get_file_as_string(here.path_join("patch").path_join(rel))
			source=source.replace("res://scripts/hospital/npc_door_clearance31.gd",here.path_join("patch/scripts/hospital/npc_door_clearance31.gd"))
			script.source_code=source;script.take_over_path("res://"+rel)
			assert(script.reload()==OK);assert(script.can_instantiate());candidates.append(script)
	var fixture:Node=load(here.path_join("fixture31.gd")).new();root.add_child(fixture)
