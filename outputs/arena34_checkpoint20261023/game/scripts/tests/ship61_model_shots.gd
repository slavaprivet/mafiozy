extends SceneTree
## SHIP61 model screenshots.  Renders the procedural ship on a water placeholder
## with the castle lighting recipe and saves five views plus a cannon close-up.
##
## Run WITHOUT --headless:
##   godot --path <game> --resolution 1600x900 --script res://scripts/tests/ship61_model_shots.gd
## Saves into DSH_SHOT_DIR or .../default-workspace/shots_ship61.

const ShipModel := preload("res://scripts/ship/ship_model.gd")
const WaterMaterial := preload("res://scripts/preview_water_material.gd")

var _stage: Node3D
var _camera: Camera3D
var _ship: Node3D
var _out_dir := ""
var _water: RefCounted
var _sun: DirectionalLight3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	_out_dir = OS.get_environment("DSH_SHOT_DIR")
	if _out_dir == "":
		_out_dir = "C:/Users/Слава/Documents/deepseek-harness/default-workspace/shots_ship61"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_stage = Node3D.new()
	_stage.name = "Ship61ShotStage"
	root.add_child(_stage)
	_build_environment()
	_build_water()

	_ship = ShipModel.new()
	_ship.name = "Ship"
	_stage.add_child(_ship)
	var built: Dictionary = _ship.build()
	_ship.set_sail_amount(1.0)
	# Show the guns working: the fore starboard barrel is trained out and elevated.
	var cannons: Array = built.get("cannons", [])
	if cannons.size() >= 3:
		var pivot: Node3D = cannons[2]["pivot"]
		var barrel: Node3D = cannons[2]["barrel"]
		pivot.rotation.y = deg_to_rad(10.0)
		barrel.rotation.x = deg_to_rad(14.0)
		var meshes := 0
		for child: Node in barrel.get_children():
			if child is MeshInstance3D:
				meshes += 1
		print("SHIP61_SHOTS_CANNON index=2 barrel_meshes=", meshes,
			" pivot_yaw=", rad_to_deg(pivot.rotation.y), " elevation=", rad_to_deg(barrel.rotation.x))
	_ship.call("shake", 0.0)
	var hull_node: MeshInstance3D = _ship.get_node_or_null("Visual/Static/M_hull")
	if hull_node != null:
		print("SHIP61_SHOTS_HULL visible=", hull_node.is_visible_in_tree(),
			" surfaces=", hull_node.mesh.get_surface_count())

	_camera = Camera3D.new()
	_camera.name = "ShotCamera"
	_camera.fov = 55.0
	_camera.near = 0.05
	_camera.far = 700.0
	_stage.add_child(_camera)
	_camera.current = true
	await _settle(20)
	await create_timer(2.4).timeout
	await _settle(10)

	var shots := [
		{"name": "side", "pos": Vector3(28.0, 7.4, 8.2), "look": Vector3(0.0, 4.0, -1.5), "fov": 52.0},
		{"name": "bow", "pos": Vector3(8.5, 5.8, -21.0), "look": Vector3(0.0, 3.0, -12.0), "fov": 58.0},
		{"name": "deck", "pos": Vector3(1.2, 5.30, 13.1), "look": Vector3(0.0, 2.40, -5.5), "fov": 64.0},
		{"name": "cabin", "pos": Vector3(0.30, 1.95, 11.85), "look": Vector3(0.0, 1.15, 7.2), "fov": 74.0},
		{"name": "top", "pos": Vector3(11.0, 9.6, -11.5), "look": Vector3(0.0, 5.2, -1.2), "fov": 52.0},
		{"name": "cannon", "pos": Vector3(7.6, 3.4, 0.8), "look": Vector3(4.1, 2.5, -4.2), "fov": 45.0},
	]
	for shot: Dictionary in shots:
		_camera.fov = float(shot["fov"])
		_camera.global_position = shot["pos"]
		_camera.look_at(shot["look"], Vector3.UP)
		await _settle(14)
		var image: Image = root.get_texture().get_image()
		if image == null:
			print("SHOTS_FAIL image_", shot["name"])
			continue
		var path: String = _out_dir.path_join("ship61_model_%s.png" % str(shot["name"]))
		var error: int = image.save_png(path)
		print("DSHOT_SAVED ", path, " err=", error)
	# Extra: furled sails from the same bow-quarter angle, proves the furling state.
	_ship.set_sail_amount(0.0)
	await create_timer(2.0).timeout
	await _settle(6)
	_camera.fov = 52.0
	_camera.global_position = Vector3(24.0, 8.6, -20.0)
	_camera.look_at(Vector3(0.0, 4.8, -4.0), Vector3.UP)
	await _settle(14)
	var furled: Image = root.get_texture().get_image()
	if furled != null:
		var furled_path: String = _out_dir.path_join("ship61_model_furled.png")
		furled.save_png(furled_path)
		print("DSHOT_SAVED ", furled_path)
	print("SHIP61_MODEL_SHOTS_DONE out=", _out_dir)
	quit(0)

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.47, 0.72)
	sky_material.sky_horizon_color = Color(0.78, 0.80, 0.80)
	sky_material.ground_bottom_color = Color(0.25, 0.26, 0.24)
	sky_material.ground_horizon_color = Color(0.62, 0.63, 0.60)
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.14
	var sky := Sky.new()
	sky.sky_material = sky_material
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_sky_contribution = 0.7
	settings.ambient_light_energy = 0.95
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 0.85
	settings.ssao_enabled = true
	settings.ssao_radius = 2.4
	settings.ssao_intensity = 1.35
	settings.glow_enabled = true
	settings.glow_intensity = 0.38
	settings.fog_enabled = true
	settings.fog_light_color = Color(0.72, 0.75, 0.80)
	settings.fog_density = 0.0012
	settings.fog_aerial_perspective = 0.3
	var world := WorldEnvironment.new()
	world.name = "Ship61ShotSky"
	world.environment = settings
	_stage.add_child(world)
	if root.world_3d != null:
		root.world_3d.environment = settings
	_sun = DirectionalLight3D.new()
	_sun.name = "Ship61ShotSun"
	_sun.light_energy = 0.9
	_sun.light_color = Color(1.0, 0.95, 0.86)
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.05
	_sun.shadow_blur = 1.4
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_max_distance = 120.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.rotation_degrees = Vector3(-38.0, 128.0, 0.0)
	_stage.add_child(_sun)
	print("SHIP61_SHOTS_SUN_DIR ", _sun.transform.basis * Vector3(0.0, 0.0, -1.0))

func _build_water() -> void:
	_water = WaterMaterial.new()
	var material: ShaderMaterial = _water.material_for(Vector3.ZERO, false)
	var plane := PlaneMesh.new()
	plane.size = Vector2(700.0, 700.0)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	var water := MeshInstance3D.new()
	water.name = "WaterPlaceholder"
	water.mesh = plane
	water.material_override = material
	water.position.y = -0.55
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(water)
