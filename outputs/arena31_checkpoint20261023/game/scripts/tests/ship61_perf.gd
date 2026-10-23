extends SceneTree
## SHIP61 performance probe: no screenshots, no stalls - just the steady frame.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await process_frame
	var host: Node = null
	var host_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < host_deadline:
		host = scene.get("preview_ship")
		if is_instance_valid(host):
			break
		await process_frame
	if not is_instance_valid(host):
		print("SHIP61_PERF_FAIL no_host")
		quit(1)
		return
	for i in 300:
		await process_frame
	print("SHIP61_PERF fps=", Engine.get_frames_per_second(),
		" draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		" physics_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		" process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var model: Node = host.get("preview_model")
	if is_instance_valid(model):
		var meshes := 0
		var visible_meshes := 0
		var tris := 0
		var stack: Array[Node] = [model]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.append(child)
			if node is MeshInstance3D:
				meshes += 1
				var mi := node as MeshInstance3D
				if mi.visible:
					visible_meshes += 1
				if mi.mesh != null and mi.mesh.get_surface_count() > 0:
					var arrays: Array = mi.mesh.surface_get_arrays(0)
					var indices: Variant = arrays[Mesh.ARRAY_INDEX]
					if indices is PackedInt32Array:
						tris += indices.size() / 3
		print("SHIP61_PERF_MODEL meshes=", meshes, " visible=", visible_meshes, " tris=", tris,
			" lights=", model.get("_lantern_lights").size() if model.get("_lantern_lights") != null else -1)
	print("SHIP61_PERF_OK")
	quit(0)
