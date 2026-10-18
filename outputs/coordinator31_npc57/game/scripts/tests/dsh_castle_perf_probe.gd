extends SceneTree
## DSH_OPT: a measuring instrument for the castle, not a pass/fail gate.
##
## The acceptance test (dsh_castle_perf.gd) counts frames from three viewpoints. This probe
## explains WHY the frame costs what it costs: it measures frame time distribution (p95,
## worst frame), draw calls, objects and primitives, then removes one cost at a time
## (bricks, decoration, sun shadows, ambient occlusion, point lights) and measures again.
## It also fires one gate blast and times the frames that the breach actually costs.
##
## Usage (graphics, no vsync):
##   godot --path <game> --script res://scripts/tests/dsh_castle_perf_probe.gd -- [--probe-out=DIR]

var _scene: Node
var _castle: Node3D
var _camera: Camera3D
var _out_dir := ""
var _tag := "probe_"
var _brick_nodes: Array[Node] = []
var _decor_nodes: Array[MeshInstance3D] = []
var _sun: DirectionalLight3D
var _env: Environment
var _omni_lights: Array[Node] = []

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _measure(seconds: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var last := started
	var times: Array[float] = []
	while Time.get_ticks_usec() - started < int(seconds * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
	var sorted_times := times.duplicate()
	sorted_times.sort()
	var count: int = sorted_times.size()
	var avg := 0.0
	for value: float in sorted_times:
		avg += value
	avg = avg / maxf(1.0, float(count))
	var p95: float = sorted_times[clampi(int(float(count) * 0.95), 0, count - 1)] if count > 0 else 0.0
	var p99: float = sorted_times[clampi(int(float(count) * 0.99), 0, count - 1)] if count > 0 else 0.0
	return {
		"fps": float(count) / maxf(0.01, elapsed),
		"frames": count,
		"avg_ms": avg,
		"p95_ms": p95,
		"p99_ms": p99,
		"max_ms": (sorted_times[count - 1] as float) if count > 0 else 0.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"cpu_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
	}

func _shot(name: String) -> void:
	if _out_dir == "": return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("PROBE_SHOT_FAIL ", name)
		return
	var path := _out_dir.path_join("%s%s.png" % [_tag, name])
	image.save_png(path)
	print("PROBE_SHOT ", path)

func _report(label: String, measured: Dictionary) -> void:
	print("PROBE ", label, " ", JSON.stringify(measured))

func _find_parts() -> void:
	for child: Node in _castle.find_children("*", "", true, false):
		if child is MultiMeshInstance3D and String(child.name).begins_with("Bricks"):
			_brick_nodes.append(child)
		elif child is MeshInstance3D and not (child is MultiMeshInstance3D):
			_decor_nodes.append(child)
		elif child is DirectionalLight3D:
			_sun = child
		elif child is OmniLight3D:
			_omni_lights.append(child)
	var world_env := _castle.get_node_or_null("CastleSky") as WorldEnvironment
	if world_env != null:
		_env = world_env.environment

func _set_bricks_visible(visible: bool) -> void:
	for node: Node in _brick_nodes:
		(node as MultiMeshInstance3D).visible = visible

func _set_decor_visible(visible: bool) -> void:
	for node: MeshInstance3D in _decor_nodes:
		node.visible = visible

func _set_omni_visible(visible: bool) -> void:
	for node: Node in _omni_lights:
		(node as OmniLight3D).visible = visible

func _camera_view(base: Vector3, half: float, name: String) -> void:
	match name:
		"courtyard":
			_camera.global_position = base + Vector3(0.0, 6.0, 20.0)
			_camera.look_at(base + Vector3(0.0, 8.0, half), Vector3.UP)
		"gate":
			_camera.global_position = base + Vector3(0.0, 4.0, half + 18.0)
			_camera.look_at(base + Vector3(0.0, 6.0, half), Vector3.UP)
		"whole":
			_camera.global_position = base + Vector3(half + 90.0, 55.0, half + 90.0)
			_camera.look_at(base + Vector3(0.0, 10.0, 0.0), Vector3.UP)

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-out="):
			_out_dir = argument.trim_prefix("--probe-out=")
		if argument.begins_with("--probe-size="):
			var size_parts: PackedStringArray = argument.trim_prefix("--probe-size=").split("x")
			if size_parts.size() == 2:
				root.size = Vector2i(int(size_parts[0]), int(size_parts[1]))
				print("PROBE_SIZE ", size_parts[0], "x", size_parts[1])
		if argument.begins_with("--probe-tag="):
			_tag = argument.trim_prefix("--probe-tag=")
		if argument == "--probe-no-msaa":
			root.msaa_3d = Viewport.MSAA_DISABLED
			print("PROBE_MSAA off")
	if _out_dir == "":
		_out_dir = "C:/Users/Слава/Documents/deepseek-harness/default-workspace"
	var load_started := Time.get_ticks_usec()
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("PROBE_FAIL scene")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true:
			break
		await process_frame
	_castle = _scene.get("preview_castle")
	if _castle == null:
		print("PROBE_FAIL castle")
		quit(1)
		return
	var load_ms := float(Time.get_ticks_usec() - load_started) / 1000.0
	print("PROBE_LOAD_MS ", load_ms)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_find_parts()
	print("PROBE_PARTS bricks=", _brick_nodes.size(), " decor=", _decor_nodes.size(),
		" omni=", _omni_lights.size(), " sun=", _sun != null, " env=", _env != null)
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 1200.0
	_scene.add_child(_camera)
	_camera.current = true
	var half: float = float(_castle.call("wall_half"))
	var base: Vector3 = _castle.global_position
	# ---------- three acceptance viewpoints
	for view_name: String in ["courtyard", "gate", "whole"]:
		_camera_view(base, half, view_name)
		await _settle(40)
		var measured: Dictionary = await _measure(2.5)
		measured["view"] = view_name
		_report("VIEW", measured)
		await _shot(view_name)
		print("PROBE_CHUNKS ", view_name, " ", JSON.stringify(_castle.call("render_stats")))
	# ---------- cost attribution at the gate, where the frame is slowest
	_camera_view(base, half, "gate")
	await _settle(40)
	var baseline: Dictionary = await _measure(1.5)
	_report("ABLATE_baseline", baseline)
	_set_bricks_visible(false)
	await _settle(10)
	_report("ABLATE_no_bricks", await _measure(1.5))
	_set_bricks_visible(true)
	_set_decor_visible(false)
	await _settle(10)
	_report("ABLATE_no_decor", await _measure(1.5))
	_set_decor_visible(true)
	if _sun != null:
		_sun.shadow_enabled = false
		await _settle(10)
		_report("ABLATE_no_sun_shadow", await _measure(1.5))
		_sun.shadow_enabled = true
	if _env != null:
		_env.ssao_enabled = false
		await _settle(10)
		_report("ABLATE_no_ssao", await _measure(1.5))
		_env.ssao_enabled = true
		_env.glow_enabled = false
		await _settle(10)
		_report("ABLATE_no_glow", await _measure(1.5))
		_env.glow_enabled = true
	_set_omni_visible(false)
	await _settle(10)
	_report("ABLATE_no_omni", await _measure(1.5))
	_set_omni_visible(true)
	# Multisampling: the project runs 4x MSAA AND TAA at once. TAA already resolves edges,
	# so the samples are a bandwidth cost that can be measured rather than assumed.
	root.msaa_3d = Viewport.MSAA_DISABLED
	await _settle(10)
	_report("ABLATE_no_msaa", await _measure(1.5))
	root.msaa_3d = Viewport.MSAA_4X
	root.use_taa = false
	await _settle(10)
	_report("ABLATE_no_taa", await _measure(1.5))
	root.use_taa = true
	if _env != null:
		_env.fog_enabled = false
		await _settle(10)
		_report("ABLATE_no_fog", await _measure(1.5))
		_env.fog_enabled = true
	await _settle(10)
	# ---------- one breach at the gate: the frame the destruction actually costs
	var breach_at: Vector3 = base + Vector3(0.0, 5.0, half)
	var breach_started := Time.get_ticks_usec()
	var result: Dictionary = _castle.call("apply_explosion", {
		"position": breach_at, "radius": 4.0, "power": 260.0,
		"direction": Vector3(0.0, 0.0, -1.0), "event_id": "probe:1",
	})
	var breach_us := Time.get_ticks_usec() - breach_started
	print("PROBE_BREACH_APPLY_MS ", float(breach_us) / 1000.0)
	print("PROBE_BREACH ", JSON.stringify(result))
	_report("BREACH_frames", await _measure(2.5))
	await _shot("breach")
	print("PROBE_DONE")
	quit(0)
