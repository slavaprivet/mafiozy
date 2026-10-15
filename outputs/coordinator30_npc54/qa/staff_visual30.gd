extends SceneTree
var _out := ""
var _failures: Array[String] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): _out = arg.trim_prefix("--qa-out=")
	_start.call_deferred()

func _start() -> void:
	var scene: Node3D = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	var deadline: int = Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		var population: RefCounted = scene.get("preview_population")
		if scene.get("preview_ready") == true and population != null and population.get("city_ready") == true: break
		await process_frame
	var staff: Node = scene.get("preview_venue_staff29")
	if not is_instance_valid(staff):
		# Resolve the existing host by script; no gameplay population or service edits.
		for child: Node in scene.get_children():
			if child.get_script() != null and child.get_script().resource_path.ends_with("npc_venue_staff_host29.gd"):
				staff = child; break
	if not is_instance_valid(staff):
		_finish({"ok":false,"reason":"staff_host_missing"}); return
	var camera := Camera3D.new()
	scene.add_child(camera); camera.current = true; camera.fov = 55.0
	var saved: Array[String] = []
	var kinds: Dictionary = {}
	for row: Dictionary in staff.report.staff:
		var kind: String = str(row.kind)
		if kinds.has(kind): continue
		kinds[kind] = true
		var point: Vector3 = row.staff_point
		var service: Vector3 = row.service_point
		var outward: Vector3 = (service - point).normalized()
		var side: Vector3 = outward.cross(Vector3.UP)
		camera.global_position = point + outward * 3.0 + side * 1.1 + Vector3.UP * 1.55
		camera.look_at(point + Vector3.UP * 1.05, Vector3.UP)
		for frame in 12: await physics_frame
		await RenderingServer.frame_post_draw
		var name: String = kind + "_staff.png"
		var error: Error = root.get_texture().get_image().save_png(_out.path_join(name))
		if error == OK: saved.append(name)
		else: _failures.append("capture:"+kind)
	_finish({"ok":saved.size()==4 and _failures.is_empty(),"staff_count":staff._rows.size(),"images":saved,"failures":_failures,"visual_review_pending":true,"real_service_animation_test":"staff30 cycle receipts"})

func _finish(result: Dictionary) -> void:
	if not _out.is_empty():
		var file := FileAccess.open(_out.path_join("STAFF_VISUAL30.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t")); file.close()
	print("STAFF_VISUAL30 ",JSON.stringify(result))
	quit(0 if result.get("ok",false) else 1)
