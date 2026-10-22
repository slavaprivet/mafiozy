extends SceneTree
## DSH_CASTLE: what does the castle actually cost?
## Counts the things that decide the frame: draw-call carriers (MeshInstance3D and
## MultiMesh), collision bodies, lights, and the time the build itself takes.

var _scene: Node

func _initialize() -> void:
	_run()

func _run() -> void:
	var started := Time.get_ticks_msec()
	var packed: PackedScene = load("res://scenes/castle.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	var built_ms := Time.get_ticks_msec() - started
	var castle: Node = _scene.get("preview_castle")
	if castle == null:
		print("BUDGET_FAIL no castle"); quit(1); return
	# Let the deferred frees from the build finish before anything is counted, or the batched
	# originals are still in the tree and the numbers lie.
	for settle: int in 3:
		await process_frame

	var meshes: Array[Node] = castle.find_children("*", "MeshInstance3D", true, false)
	var multimeshes: Array[Node] = castle.find_children("*", "MultiMeshInstance3D", true, false)
	var bodies: Array[Node] = castle.find_children("*", "StaticBody3D", true, false)
	var lights: Array[Node] = castle.find_children("*", "Light3D", true, false)
	var rigid: Array[Node] = castle.find_children("*", "RigidBody3D", true, false)
	var total_nodes: int = castle.find_children("*", "", true, false).size()
	var visible_meshes := 0
	var with_shadow := 0
	for node: Node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null: continue
		if mesh_instance.visible: visible_meshes += 1
		if mesh_instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: with_shadow += 1
	var light_energy := 0.0
	for node: Node in lights:
		var light := node as Light3D
		if light != null and light.visible: light_energy += light.light_energy
	var stats: Dictionary = castle.call("get_stats")
	print("BUDGET built_ms=", built_ms,
		" bricks=", stats.get("bricks", 0),
		" nodes=", total_nodes,
		" mesh_instances=", meshes.size(), " visible=", visible_meshes, " shadow_casters=", with_shadow,
		" multimeshes=", multimeshes.size(),
		" static_bodies=", bodies.size(),
		" lights=", lights.size(), " light_energy=", snappedf(light_energy, 0.01),
		" rigid=", rigid.size())
	print("BUDGET_DONE")
	quit(0)