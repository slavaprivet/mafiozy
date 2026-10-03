extends "base_boundary.gd"
## Graphical observation only. The inherited native oracle remains unchanged.
var view_camera: Camera3D
var lighting_ready := false
var captures: Array[Dictionary] = []
var capture_index := 0
var marker := ""
var native_observer: Node
var native_samples: Array[Dictionary] = []
var sampling_assumptions: Array[Dictionary] = []
var last_native: Dictionary = {}

func check(value: bool, label: String) -> void:
	# PNG readback may span several physics frames. Replace the inherited
	# one-frame-per-await assumption with a post-player physics observer.
	if label.begins_with("per-tick serial and native displacement"):
		sampling_assumptions.append({"label":label, "original_value":value})
		return
	super.check(value, label)

func observe_native() -> void:
	if not is_instance_valid(player): return
	var now := {"frame":Engine.get_physics_frames(), "serial":player._ground_move_serial,
		"position":player.global_position, "native_delta":player.get_position_delta(),
		"pose_revision":player._pose_revision}
	if not last_native.is_empty() and absf(now.position.x - last_native.position.x) < 1.0:
		check(now.frame == last_native.frame + 1, "physics observer no missing tick")
		check(now.serial == last_native.serial + 1, "physics observer exactly one native move")
		check((now.position-last_native.position).is_equal_approx(now.native_delta), "physics observer complete native displacement")
	native_samples.append(now)
	last_native = now

func _initialize() -> void:
	boot.call_deferred()

func boot() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--parent-marker="): marker = arg.trim_prefix("--parent-marker=")
	var until := Time.get_ticks_msec() + 10000
	while not FileAccess.file_exists(marker) and Time.get_ticks_msec() < until:
		await process_frame
	if not FileAccess.file_exists(marker):
		push_error("Parent registration marker absent")
		quit(2)
		return
	var selected: Array[Dictionary] = []
	for template: Dictionary in templates:
		if template.kind in ["106mm_static_lip", "120mm_exact_boundary"]:
			selected.append(template)
	templates = selected
	await run()

func box(at: Vector3, size: Vector3, kind: String = "static", layer: int = 1) -> PhysicsBody3D:
	var body := super.box(at, size, kind, layer)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.31, 0.38) if at.y < 0.0 else Color(0.72, 0.48, 0.24)
	material.roughness = 0.95
	visual.material_override = material
	body.add_child(visual)
	if not lighting_ready:
		lighting_ready = true
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
		light.light_energy = 1.5
		world.add_child(light)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.10, 0.13, 0.18)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.6
		world.add_child(environment)
		view_camera = Camera3D.new()
		view_camera.fov = 42.0
		world.add_child(view_camera)
	return body

func tick(count: int = 1) -> void:
	for index: int in count:
		await super.tick()
		if not is_instance_valid(player) or not is_instance_valid(view_camera): continue
		if not is_instance_valid(native_observer):
			native_observer = load("observer.gd").new()
			native_observer.process_physics_priority = 1000
			native_observer.sample = Callable(self, "observe_native")
			world.add_child(native_observer)
		view_camera.global_position = player.global_position + Vector3(3.2, 1.25, 1.5)
		view_camera.look_at(player.global_position + Vector3(0.0, 0.75, -0.12), Vector3.UP)
		view_camera.make_current()
		if player.global_position.z > 0.36 or player.global_position.z < -0.18: continue
		if out.is_empty() or done: continue
		var observed := {"frame":Engine.get_physics_frames(), "position":player.global_position,
			"native_delta":player.get_position_delta(), "on_floor":player.is_on_floor(),
			"velocity":player.velocity, "slide_count":player.get_slide_collision_count(),
			"serial":player._ground_move_serial, "window_focus":root.has_focus(),
			"camera":view_camera.global_transform, "pose_revision":player._pose_revision,
			"locomotion":player._locomotion.get_status()}
		await RenderingServer.frame_post_draw
		if done: continue
		var image := root.get_texture().get_image()
		var path := out.path_join("frame_%04d.png" % capture_index)
		var error := image.save_png(path)
		check(error == OK, "graphical capture written")
		observed["image"] = path.get_file()
		observed["capture_frame"] = Engine.get_physics_frames()
		captures.append(observed)
		capture_index += 1

func finish() -> void:
	if done: return
	FileAccess.open(out.path_join("CAPTURES.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"scope":"Actual imported hero and original player on artificial 106/120 mm component lanes. Not current-world passage, OS-input or performance acceptance.",
		"rendering":RenderingServer.get_current_rendering_method(), "captures":captures,
		"runtime_modified":false, "inherited_boundary_errors":errors,
		"sampling_assumptions":sampling_assumptions, "post_player_physics_samples":native_samples}, "  "))
	await super.finish()
