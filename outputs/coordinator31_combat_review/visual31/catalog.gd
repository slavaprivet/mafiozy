extends SceneTree
## Small render-only catalogue. Does not start the castle or modify gameplay.
var out_dir := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-out="): out_dir = arg.trim_prefix("--visual-out=")
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12,0.14,0.17)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8,0.85,1.0)
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25,-30,0)
	key.light_energy = 1.8
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(35,150,0)
	fill.light_energy = 0.7
	world.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.8
	world.add_child(camera)
	camera.position = Vector3(3.3,0.3,10)
	camera.look_at(Vector3(3.3,0.3,0))
	camera.make_current()
	var sword: Node3D = load("res://scripts/weapons/sword_prototype.gd").new()
	var report: Dictionary = {}
	var ids := ["sword","mace","axe","sledge","spear","shield"]
	for i in ids.size():
		var item: Node3D
		if ids[i] == "shield": item = sword.call("_build_shield_model", world)
		else: item = sword.call("_build_weapon_model", world, ids[i])
		item.position = Vector3(float(i % 3) * 2.5 + 0.45, 1.8-float(i / 3)*1.6,0)
		item.rotation.x = 0.28
		report[ids[i]] = item.get_meta("visual_budget31",{})
		_label(world,ids[i],item.position+Vector3(0.45,-0.6,0))
	var bow: Node3D = load("res://scripts/weapons/bow_prototype.gd").new()
	bow.call("_build_materials")
	bow.call("_build_shared_meshes")
	var bow_model: Node3D = bow.call("_build_bow",world)
	bow_model.position = Vector3(1.2,-1.65,0)
	bow_model.rotation.y = PI*0.5
	bow_model.visible = true
	var string_a: MeshInstance3D = bow.get("_string_a")
	var string_b: MeshInstance3D = bow.get("_string_b")
	var tip_a: Vector3 = bow.call("_limb_point",1.0,1.0)
	var tip_b: Vector3 = bow.call("_limb_point",1.0,-1.0)
	bow.call("_stretch",string_a,bow_model.to_global(tip_a),bow_model.to_global(Vector3(0,0,-0.1)))
	bow.call("_stretch",string_b,bow_model.to_global(Vector3(0,0,-0.1)),bow_model.to_global(tip_b))
	report["bow"] = bow_model.get_meta("visual_budget31",{})
	report["bow"]["live_strings_retained"] = is_instance_valid(string_a) and is_instance_valid(string_b) and string_a.get_parent()==bow_model and string_b.get_parent()==bow_model
	_label(world,"bow",Vector3(1.2,-2.45,0))
	var blade: ArrayMesh = load("res://scripts/weapons/weapon_model_finish31.gd").sword_blade()
	var arrays := blade.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var outward := 0
	var inward := 0
	for i in vertices.size():
		var radial := Vector3(0,vertices[i].y,vertices[i].z)
		if radial.length_squared() < 0.000001: continue
		if normals[i].dot(radial)>0: outward+=1
		else: inward+=1
	report["sword_blade_normals"] = {"outward":outward,"inward":inward}
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	if not out_dir.is_empty():
		root.get_texture().get_image().save_png(out_dir.path_join("catalog_front.png"))
		var file := FileAccess.open(out_dir.path_join("visual_report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("WEAPON_VISUAL31 ",JSON.stringify(report))
	sword.free()
	bow.free()
	quit(0 if inward==0 and report.bow.live_strings_retained else 1)

func _label(world: Node3D, title: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = title
	label.font_size = 48
	label.pixel_size = 0.003
	label.position = at
	label.no_depth_test = true
	world.add_child(label)
