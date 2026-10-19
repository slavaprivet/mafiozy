extends SceneTree
var out := "D:/MafioziCombat31/coordinator34_merged53/soil_graphical"
var scene: Node
var camera: Camera3D
var report: Dictionary = {}
func _initialize() -> void: _run.call_deferred()
func walk_probe(points: Array[Vector3]) -> bool:
	var body := CharacterBody3D.new()
	body.collision_layer = 0; body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = .32; capsule.height = 1.75
	collision.shape = capsule; collision.position.y = .9; body.add_child(collision); scene.add_child(body)
	body.global_position = points[0]+Vector3.UP*.03
	var reached := true
	for target in points.slice(1):
		var arrived := false
		for tick in 240:
			await physics_frame
			var delta: Vector3 = target-body.global_position; delta.y = 0
			if delta.length()<.15: arrived=true; break
			body.velocity=delta.normalized()*3+Vector3.DOWN; body.move_and_slide()
		if not arrived: reached=false; break
	body.queue_free();return reached
func shot(label: String, at: Vector3, target: Vector3) -> void:
	camera.global_position = at
	camera.look_at(target)
	camera.current = true
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	scene = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	var deadline := Time.get_ticks_msec() + 100000
	while not scene.get("preview_ready") and Time.get_ticks_msec() < deadline: await process_frame
	if not scene.get("preview_ready"): quit(2); return
	var site: Node3D = scene.preview_castle
	var field: Node3D = scene.preview_battlefield
	var props: Node3D = field.get_node("BattlefieldProps")
	scene._stats.visible = false
	var cover: Node3D = field.get_node("GroundCover49")
	camera = Camera3D.new(); scene.add_child(camera)
	var original = load("C:/Users/Слава/Documents/Codex/2026-10-08/task-7/SOIL49_RECOVERY_20261018T154550Z/provenance/terrain.base.gd").new()
	var old_shader := Shader.new()
	old_shader.code = FileAccess.get_file_as_string("C:/Users/Слава/Documents/Codex/2026-10-08/task-7/SOIL49_RECOVERY_20261018T154550Z/provenance/shader.base.gdshader")
	var baseline := ShaderMaterial.new()
	baseline.shader = old_shader
	baseline.set_shader_parameter("macro_map", original._make_grit_texture())
	baseline.set_shader_parameter("soil_detail", load("res://assets/terrain/soil_detail47.png"))
	var candidate: Material = field._terrain_material
	var roots_tested := 0
	var max_root_error := 0.0
	var ground_ray_misses := 0
	for batch in cover._batches:
		if not batch.name.begins_with("Grass"): continue
		var transform: Transform3D = batch.multimesh.get_instance_transform(0)
		var root_at: Vector3 = batch.to_global(transform.origin)
		var query := PhysicsRayQueryParameters3D.create(root_at+Vector3.UP*.35,root_at-Vector3.UP*.15,1)
		var hit := field.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider.has_meta("battlefield_ground"):
			max_root_error = maxf(max_root_error,absf((root_at.y+.024)-float(hit.position.y)))
			roots_tested += 1
		else: ground_ray_misses += 1
	report["root_contact_samples"] = roots_tested
	report["root_contact_max_error"] = max_root_error
	report["root_ray_obstructed_or_missed"] = ground_ray_misses
	var points := [Vector3(7,2.8,157),Vector3(25,6,143),Vector3(36,2.2,235),Vector3(-76,2.2,215)]
	var targets := [Vector3(3,.1,165),Vector3(-8,.4,179),Vector3(32,.2,243),Vector3(-83,.1,226)]
	var labels := ["road","wide","camp","edge"]
	var height_equal := true
	for x in [-85.0,-47.0,0.0,47.0,85.0]:
		for z in [80.0,120.0,157.0,200.0,245.0]:
			height_equal = height_equal and is_equal_approx(field.terrain_height(x,z),original.terrain_height(x,z))
	for after in [false,true]:
		cover.visible = after
		for node in field.get_children():
			if node is MeshInstance3D and node.name.begins_with("Terrain_"): node.material_override = candidate if after else baseline
		for j in points.size():
			var label: String = labels[j]+("_after" if after else "_before")
			await shot(label,site.to_global(points[j]),site.to_global(targets[j]))
			report["drawcalls_"+label] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			report["primitives_"+label] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	# Same camera/material, only submitted instance count differs. This measures
	# geometry reduction without claiming a clean FPS benchmark.
	cover.set_process(false)
	for batch in cover._batches: batch.multimesh.visible_instance_count = -1
	await shot("lod_full_reference",site.to_global(points[1]),site.to_global(targets[1]))
	report["lod_full_primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	cover.set_process(true); cover._update_lod()
	await shot("lod_optimized",site.to_global(points[1]),site.to_global(targets[1]))
	report["lod_optimized_primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var body := CharacterBody3D.new()
	body.collision_layer = 0; body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = .32; capsule.height = 1.75
	shape.shape = capsule; shape.position.y = .9; body.add_child(shape); scene.add_child(body)
	body.global_position = site.to_global(Vector3(0,field.terrain_height(0,146)+.12,146))
	var start := body.global_position
	var on_floor_ticks := 0
	for tick in 180:
		await physics_frame
		body.velocity = Vector3(0,-2,3)
		body.move_and_slide()
		if body.is_on_floor(): on_floor_ticks += 1
	report["walk_distance"] = body.global_position.z-start.z
	report["walk_floor_ticks"] = on_floor_ticks
	# Drive the actual player body's grounded motion; the production cover
	# reads this actor itself, not a synthetic pressure call from this fixture.
	var player: CharacterBody3D = scene._player
	scene._castle_spawn_frames = 0
	player.set_physics_process(false); player.set_process(false)
	var patch := Vector3(18,0,192)
	var best := 0.0
	for x in range(-26,-11,2):
		for z in range(185,205,2):
			var score: float = cover._density(x,z)+cover._density(x,z+3)+cover._density(x,z+6)
			if score > best: best=score; patch = Vector3(x,0,z)
	patch.y = cover._surface_y(patch.x,patch.z)
	report["patch"] = str(patch)
	await shot("grass_upright",site.to_global(patch+Vector3(2.6,2.5,-2.8)),site.to_global(patch+Vector3(0,.15,2.5)))
	player.global_position = site.to_global(patch+Vector3.UP*.12)
	var middle := patch
	var player_start := player.global_position
	for tick in 180:
		await physics_frame
		player.velocity = Vector3(0,-2,2.4); player.move_and_slide()
		if tick == 90: middle = site.to_local(player.global_position)
	report["actual_player_walk"] = player.global_position.z-player_start.z
	report["middle_pressure_after_walk"] = cover.pressure_at(middle)
	await shot("grass_legs",player.global_position+Vector3(1.5,1.0,1.3),player.global_position+Vector3(0,.25,0))
	report["actor_uniform_error"] = (cover._material.get_shader_parameter("actor_position") as Vector3).distance_to(player.global_position)
	player.global_position = site.to_global(Vector3(0,field.terrain_height(0,150)+.1,150))
	await shot("grass_trampled",site.to_global(patch+Vector3(2.6,2.5,-2.8)),site.to_global(patch+Vector3(0,.15,2.5)))
	await create_timer(12.0).timeout
	report["middle_pressure_after_recovery"] = cover.pressure_at(middle)
	await shot("grass_recovered",site.to_global(patch+Vector3(2.6,2.5,-2.8)),site.to_global(patch+Vector3(0,.15,2.5)))
	await shot("grass_detail",site.to_global(patch+Vector3(-.4,.8,-1.4)),site.to_global(patch+Vector3(0,.12,1.0)))
	report["cover_stats"] = cover.get_stats()
	var tent: StaticBody3D = props.get_node("Cover_tent_5")
	await shot("tent_detail",tent.to_global(Vector3(7,2.6,5)),tent.to_global(Vector3(0,1.6,0)))
	report["tent_passage"] = await walk_probe([tent.to_global(Vector3(4,.08,.65)),tent.to_global(Vector3(1,.08,.65)),tent.to_global(Vector3(.8,.08,0))])
	var barrel_at: Vector3 = props.to_global(props._groups.barrel_0.center)
	await shot("barrel_detail",barrel_at+Vector3(1.4,1.0,1.3),barrel_at+Vector3.UP*.4)
	var cart_at: Vector3 = props.to_global(props._groups.camp_cart_left.center)
	await shot("cart_detail",cart_at+Vector3(5,3,4),cart_at+Vector3.UP*1.3)
	report["props_stats"] = props.get_stats()
	var destruction := {}
	for id in ["tent_0","barrel_0"]:
		props.apply_damage(props.to_global(props._groups[id].center),.01,500,"stone")
		await physics_frame; await process_frame
		var hidden := true
		for ref in props._groups[id].indices:
			var batch: MultiMeshInstance3D = props._batches[ref[0]]
			hidden = hidden and batch.multimesh.get_instance_transform(ref[1]).basis.determinant()==0.0
		destruction[id] = hidden and bool(props._groups[id].destroyed) and not is_instance_valid(props._groups[id].collider)
	report["destruction"] = destruction
	report["terrain_stats"] = field.get_stats()
	report["sample_heights_equal"] = height_equal
	report["ready"] = bool(scene.preview_ready)
	var texture: Texture2D = candidate.get_shader_parameter("macro_map")
	report["macro_size"] = [texture.get_width(),texture.get_height()]
	report["pass"] = height_equal and report.ready and report.terrain_stats.terrain_chunks == 9 and report.terrain_stats.terrain_collision_shapes == 9 and report.walk_distance > 7 and on_floor_ticks > 140 and texture.get_width() == 1024 and report.actual_player_walk > 5.5 and report.middle_pressure_after_walk > .35 and report.middle_pressure_after_recovery < .02 and report.cover_stats.tufts > 20000 and report.cover_stats.colliders == 0 and roots_tested > 100 and max_root_error < .005
	report["pass"] = report.pass and report.tent_passage and destruction.tent_0 and destruction.barrel_0 and report.actor_uniform_error<.001 and report.cover_stats.leg_bones_bound and report.lod_optimized_primitives<report.lod_full_primitives*.8
	var f := FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t")); f.close()
	body.queue_free(); original.free()
	quit(0 if report.pass else 2)
