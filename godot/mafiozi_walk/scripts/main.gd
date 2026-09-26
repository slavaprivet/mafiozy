extends Node3D
## First visible migration checkpoint: exact authored assets, external walking only.

const PlayerController = preload("res://scripts/preview_player.gd")
var _block: Dictionary = {}
var _origin: Vector3
var _player: CharacterBody3D
var _spawn: Vector3
var _stats: Label
var _clock: float = 0.0
var _samples: Array[float] = []
var _runtime_seconds: float = 0.0
var _capture_done: bool = false
var _capture_path: String = ""

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	if not parsed is Dictionary:
		push_error("Preview block is unavailable")
		return
	_block = parsed
	_origin = _v3(_block["originM"])
	_build_lighting()
	_build_surface()
	for record: Dictionary in _block["buildings"]:
		_add_asset(record)
	for record: Dictionary in _block["decor"]:
		_add_asset(record)
	_spawn = _v3(_block["hero"]["spawnLocalM"])
	_player = PlayerController.new()
	_player.position = _spawn
	add_child(_player)
	_build_hud()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-capture="):
			_capture_path = argument.trim_prefix("--preview-capture=")
	print("MAFIOZI_PREVIEW_READY buildings=%d decor=%d source_colliders=%d" % [_block["counts"]["buildings"], _block["counts"]["decor"], _block["counts"]["collisionBodies"]])

func _v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _build_lighting() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var atmosphere: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("738eaf")
	atmosphere.sky_horizon_color = Color("c6cfce")
	atmosphere.ground_bottom_color = Color("484c46")
	atmosphere.ground_horizon_color = Color("bec7c7")
	sky.sky_material = atmosphere
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff0d8")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)

func _build_surface() -> void:
	var surface: Dictionary = _block["surface"]
	var grid: Array = surface["grid"]
	var palette: Dictionary = surface["palette"]
	var cell: float = float(surface["cellSize"])
	var groups: Dictionary = {}
	for row in range(grid.size()):
		for col in range(grid[row].size()):
			var key: String = str(int(grid[row][col]))
			if not groups.has(key):
				groups[key] = []
			groups[key].append(Vector3((int(surface["startCol"]) + col + 0.5) * cell - _origin.x, float(palette[key]["heightM"]) - 0.02, (int(surface["startRow"]) + row + 0.5) * cell - _origin.z))
	for key: String in groups:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(cell, 0.04, cell)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(str(palette[key]["colorSrgb"]))
		material.roughness = 0.9 if bool(palette[key]["solid"]) else 0.25
		mesh.material = material
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = groups[key].size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, groups[key][i]))
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = "Surface_" + str(palette[key]["kind"])
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	# Merge consecutive dry cells into physical strips. No floor is created on water.
	for row in range(grid.size()):
		var col: int = 0
		while col < grid[row].size():
			var key: String = str(int(grid[row][col]))
			if not bool(palette[key]["solid"]):
				col += 1
				continue
			var first: int = col
			while col < grid[row].size() and str(int(grid[row][col])) == key:
				col += 1
			var body: StaticBody3D = StaticBody3D.new()
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = Vector3((col - first) * cell, 0.16, cell)
			var collision: CollisionShape3D = CollisionShape3D.new()
			collision.shape = shape
			body.position = Vector3((int(surface["startCol"]) + (first + col) * 0.5) * cell - _origin.x, float(palette[key]["heightM"]) - 0.08, (int(surface["startRow"]) + row + 0.5) * cell - _origin.z)
			body.add_child(collision)
			add_child(body)

func _add_asset(record: Dictionary) -> void:
	var resource: PackedScene = load(str(record["path"])) as PackedScene
	if resource == null:
		push_error("Missing authored asset: " + str(record["id"]))
		return
	var parent: Node3D = Node3D.new()
	parent.name = str(record["id"])
	parent.set_meta("source_id", record["id"])
	var transform_data: Dictionary = record["transform"]
	parent.position = _v3(record["positionLocalM"])
	parent.rotation.y = deg_to_rad(float(transform_data.get("yawDegrees", 0)))
	var uniform: float = float(transform_data.get("uniformScale", 1))
	var horizontal: Array = transform_data.get("horizontalScale", [1, 1])
	parent.scale = Vector3(uniform * float(horizontal[0]), uniform, uniform * float(horizontal[1]))
	var visual: Node3D = resource.instantiate() as Node3D
	visual.position = _v3(transform_data.get("modelLocalOffsetM", [0, 0, 0]))
	parent.add_child(visual)
	add_child(parent)
	_hide_helpers(visual, record.get("effectiveHiddenNodeNames", []))
	for data: Dictionary in record.get("collisionBodiesM", []):
		var points: PackedVector3Array = PackedVector3Array()
		for point: Array in data["polygonXZ"]:
			points.append(Vector3(float(point[0]), float(data["minY"]), float(point[1])))
			points.append(Vector3(float(point[0]), float(data["maxY"]), float(point[1])))
		var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		shape.points = points
		var body: StaticBody3D = StaticBody3D.new()
		body.set_meta("source_id", record["id"])
		var collider: CollisionShape3D = CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)

func _hide_helpers(node: Node, names: Array) -> void:
	for original: String in names:
		if str(node.name) == original or str(node.name) == original.validate_node_name():
			if node is Node3D:
				node.visible = false
	for child: Node in node.get_children():
		_hide_helpers(child, names)

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.07, 0.9)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.border_width_left = 3
	style.border_color = Color("dfb968")
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	panel.add_child(stack)
	var title: Label = Label.new()
	title.text = "МАФИОЗИ  /  GODOT"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ebc77f"))
	stack.add_child(title)
	var stage: Label = Label.new()
	stage.text = "Первый квартал · перенос в процессе\nАнимации и игровые системы ещё переносятся"
	stack.add_child(stage)
	_stats = Label.new()
	_stats.add_theme_color_override("font_color", Color("aabec8"))
	stack.add_child(_stats)
	var controls: Label = Label.new()
	controls.text = "WASD — идти   Shift — бег   Space — прыжок\nПКМ + мышь — камера   Tab — захват мыши   Esc — освободить"
	controls.position = Vector2(24, 640)
	controls.add_theme_color_override("font_shadow_color", Color.BLACK)
	controls.add_theme_constant_override("shadow_offset_x", 1)
	controls.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(controls)

func _process(delta: float) -> void:
	if _player == null:
		return
	if _player.position.y < -12:
		_player.position = _spawn
		_player.velocity = Vector3.ZERO
	_samples.append(delta * 1000.0)
	_runtime_seconds += delta
	if not _capture_done and not _capture_path.is_empty() and _runtime_seconds > 5.0:
		_capture_done = true
		_save_preview_frame.call_deferred()
	if _samples.size() > 600:
		_samples.pop_front()
	_clock += delta
	if _clock < 1.0:
		return
	_clock = 0.0
	var sorted: Array[float] = _samples.duplicate()
	sorted.sort()
	var p95: float = sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))]
	_stats.text = "8 зданий · 8 фонарей · %d FPS · кадр p95 %.1f мс\nПоказ квартала; полный городской FPS ещё не проверен" % [Engine.get_frames_per_second(), p95]
	if not _capture_path.is_empty() and _runtime_seconds < 12.0:
		print("PREVIEW_FRAME_SAMPLE ", JSON.stringify({"elapsed_seconds": _runtime_seconds, "fps": Engine.get_frames_per_second(), "frame_p95_ms": p95, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "limits": "Static small debug preview, not full gameplay or exported release benchmark"}))

func _save_preview_frame() -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var result: Error = frame.save_png(_capture_path)
	print("PREVIEW_CAPTURE ", result, " ", _capture_path)
