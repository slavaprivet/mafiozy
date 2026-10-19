extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var valid := true
	for path: String in ["res://scripts/city/runtime/npc_threat_world30.gd","res://scripts/city/runtime/npc_threat_life30.gd","res://scripts/city/runtime/npc_threat_route30.gd","res://scripts/npc_ambient/ambient_pose28.gd","res://scripts/npc_ambient/ambient_props28.gd"]:
		var script: Script=load(path)
		valid=valid and script!=null and script.can_instantiate()
	await create_timer(4.0).timeout
	print("THREAT30_PARSE ",valid)
	quit(0 if valid else 1)
