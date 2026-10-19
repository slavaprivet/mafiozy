extends SceneTree
const Diag = preload("res://scripts/npc_visual/npc_resident_diag.gd")
const Focus = preload("res://scripts/npc_visual/npc_resident_focus29.gd")
class TestWorld extends Node3D:
	var _player: CharacterBody3D
var scene: TestWorld
var body: CharacterBody3D
var camera: Camera3D
var output := ""
var results: Array[Dictionary] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-out="): output = argument.trim_prefix("--qa-out=")
	_run.call_deferred()

func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var solid := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var resource := BoxShape3D.new(); resource.size = size; shape.shape = resource
	solid.add_child(shape); scene.add_child(solid); solid.position = at
	var mesh := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size = size
	mesh.mesh = cube; solid.add_child(mesh)
	return solid

func paint(hp: float, dead: bool = false) -> Label3D:
	Diag.refresh_after_hit(body, "Житель", {"source_id":"resident_1", "hp":hp, "max_hp":60.0, "dead":dead})
	return body.get_node("DshResidentName") as Label3D

func capture(name: String, hp: float) -> void:
	var label: Label3D
	for tick in 45:
		await physics_frame
		label = paint(hp)
	var count: int = Focus.diagnostics().ray_queries
	for index in 286: Focus.focused(body)
	var actual: float = label.get_meta("card29_display_ratio", -1.0)
	results.append({"case":name, "passed":label.visible and absf(actual-hp/60.0)<.002 and Focus.diagnostics().ray_queries==count,
		"visible":label.visible, "text":label.get_node("ResidentHealth29").text, "hp_ratio":label.get_meta("hp_ratio"),
		"display_ratio":actual, "286_checks_extra_rays":Focus.diagnostics().ray_queries-count})
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(output.path_join(name+".png"))

func _run() -> void:
	await create_timer(2.0).timeout
	scene = TestWorld.new(); root.add_child(scene); current_scene = scene
	var env := WorldEnvironment.new(); var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR; environment.background_color = Color("526778")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = .7; env.environment = environment; scene.add_child(env)
	var light := DirectionalLight3D.new(); scene.add_child(light); light.rotation_degrees = Vector3(-40,-25,0)
	box(Vector3(0,-.1,0),Vector3(20,.2,20))
	scene._player = CharacterBody3D.new(); scene.add_child(scene._player); scene._player.position = Vector3(0,0,3.5)
	camera = Camera3D.new(); scene.add_child(camera); camera.position = Vector3(0,1.8,4)
	camera.look_at(Vector3(0,1.25,0)); camera.current = true
	body = CharacterBody3D.new(); body.set_meta("source_id","resident_1"); scene.add_child(body)
	var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new()
	capsule.radius = .36; capsule.height = 1.9; shape.shape = capsule; shape.position.y = .95; body.add_child(shape)
	var mesh := MeshInstance3D.new(); var visual := CapsuleMesh.new()
	visual.radius = .31; visual.height = 1.85; mesh.mesh = visual; mesh.position.y = .95; body.add_child(mesh)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await physics_frame; await physics_frame
	await capture("full_health",60.0)
	await capture("half_health",30.0)
	await capture("low_health",6.0)
	scene._player.position.z = 8.0
	await physics_frame; results.append({"case":"far_hidden", "passed":not paint(60.0).visible})
	scene._player.position.z = 3.5; camera.look_at(Vector3(4,1.25,0))
	await physics_frame; results.append({"case":"look_away_hidden", "passed":not paint(60.0).visible})
	camera.look_at(Vector3(0,1.25,0)); var wall: StaticBody3D = box(Vector3(0,1.5,2),Vector3(2,3,.2))
	await physics_frame; await physics_frame
	results.append({"case":"wall_hidden", "passed":not paint(60.0).visible})
	wall.queue_free(); await physics_frame; await physics_frame
	results.append({"case":"dead_hidden", "passed":not paint(0.0,true).visible})
	var passed: bool = results.all(func(row: Dictionary) -> bool: return row.passed)
	var file := FileAccess.open(output.path_join("FOCUS29.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"native_rays":true,"presentation_fixture_only":true,"cases":results},"\t")); file.close()
	print("FOCUS29_FIXTURE ",JSON.stringify(results)); quit(0 if passed else 1)
