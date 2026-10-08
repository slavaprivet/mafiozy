extends Node3D
## Isolated automatic source-input replay; no gameplay solver or sampler edits.
const Fx = preload("res://water_contact_fx.gd")
const ExistingWaterMaterial = preload("res://demo_support/preview_water_material.gd")
var fx: Node3D
var actor: MeshInstance3D
var time := 0.0
var screenshot_path := ""
var _capture_frames := 0
var _water_record := {"level":0.0,"depth":1.0,"floor":-1.0}
var _seed := 842
var water_material: RefCounted

func _water(x: float, z: float) -> Variant:
	return _water_record if x > 0 and x < 6 and absf(z) < 4 else null

func _random() -> float:
	_seed = (_seed * 1664525 + 1013904223) & 0xffffffff
	return float(_seed) / 4294967296.0

func _box(label: String, size: Vector3, position_value: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new(); item.name = label
	var mesh := BoxMesh.new(); mesh.size = size; item.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = .8
	item.material_override = material; item.position = position_value; add_child(item)
	return item

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): screenshot_path = arg.trim_prefix("--capture=")
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-45,-25,0); light.light_energy = 1.5; add_child(light)
	var world := WorldEnvironment.new(); var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR; environment.background_color = Color("14212b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_color = Color("bdd6df"); environment.ambient_light_energy = .5
	world.environment = environment; add_child(world)
	_box("Dry shore",Vector3(5,.3,8),Vector3(-2.5,-.15,0),Color("806b51"))
	_box("Lake floor",Vector3(6,.2,8),Vector3(3,-1.1,0),Color("284e55"))
	var water := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(6,8); water.mesh = plane; water.position = Vector3(3,0,0)
	# Byte-exact existing Walk water shader copied as isolated demo support only.
	water_material = ExistingWaterMaterial.new(); water.material_override = water_material.material_for()
	water.material_override.set_shader_parameter("default_depth",1.0); add_child(water)
	actor = _box("Hero feet input marker",Vector3(.18,.4,.18),Vector3(.35,1.2,0),Color("ddb765"))
	var camera := Camera3D.new(); camera.position = Vector3(2,1.6,2.8); add_child(camera); camera.look_at(Vector3(.55,.15,0)); camera.current = true
	var label := Label.new(); label.position = Vector2(20,18); label.text = "WALK → GODOT / HERO WATER CONTACT\nSource replay: impact • recontact foam • shore clipping • wake\nIsolated demo; full city integration pending"; add_child(label)
	fx = Fx.new(); add_child(fx); fx.setup({"waterAt":_water,"random":_random})
	fx.advance(.05,{"hero":{"id":"hero","position":Vector3(.35,1,0)}})
	fx.advance(.05,{"hero":{"id":"hero","position":Vector3(.35,-.2,0),"velocity":Vector3(0,-6,0)}})

func _process(delta: float) -> void:
	if screenshot_path != "":
		# Deterministic screenshot: fixed sim advance independent of display FPS.
		if _capture_frames < 14: fx.advance(1.0/60,{"hero":{"id":"hero","position":Vector3(.35,-.2,0)}})
		_capture_frames += 1
		water_material.update(fx.simulator.now); water_material.set_water_ripples(fx.get_ripples())
		actor.position = Vector3(.35,0,0)
		if _capture_frames == 16: _capture()
		return
	time += delta
	var cycle := fmod(time,7)
	var position_value := Vector3(.35,-.2,0)
	if cycle > 2 and cycle < 5: position_value.x += (cycle-2)*.8
	if cycle > 6: position_value.y = 1
	actor.position = position_value + Vector3(0,.2,0)
	fx.advance(delta,{"hero":{"id":"hero","position":position_value}})
	water_material.update(fx.simulator.now); water_material.set_water_ripples(fx.get_ripples())

func _capture() -> void:
	set_process(false)
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var err := picture.save_png(screenshot_path)
	var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	fx.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var without := get_viewport().get_texture().get_image()
	var second_err := without.save_png(screenshot_path.get_basename() + "_WITHOUT_FX.png")
	var without_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("WATER_FX_CAPTURE=" + JSON.stringify({"error":err,"without_error":second_err,"width":picture.get_width(),"height":picture.get_height(),"stats":fx.stats(),"renderObjects":objects,"renderDrawCalls":calls,"renderPrimitives":primitives,"withoutFxDrawCalls":without_calls,"effectDrawCallDelta":calls-without_calls}))
	fx.dispose(); fx.free(); get_tree().quit(0 if err == OK else 1)
