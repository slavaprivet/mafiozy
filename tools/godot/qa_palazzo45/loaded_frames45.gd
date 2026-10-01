extends "frozen/weapon_observer40.gd"
## Focused full-game input proof. Frozen parent contributes only input/aim and
## read-only native weapon observers; its old eight-building suite is not run.
const EXPECTED45: Dictionary = {
	"scripts/destruction/palazzo/building_support.gd":"762172cb490dc6f929902e4cb6d5377a9079eeb2848bc9f6f644d70bca5f8bf7",
	"scripts/destruction/palazzo/palazzo_glazing.gd":"7187080b0bf558b21a50d94640397b1207d0dacc20af2f5f99a344704fe273a0",
	"scripts/destruction/palazzo/door_close43.gd":"4dfc4a0b512dd4f0e7fe47491de12fdddfffded47c074bb31259839edbdd5f96",
	"data/block.json":"1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
}
var actor45: Dictionary = {}
var frames45: Array[Dictionary] = []
var screenshot_files45: Array[String] = []

func source_receipt45() -> void:
	var pins: Dictionary = {}
	for path: String in EXPECTED45:
		pins[path] = FileAccess.get_sha256("res://" + path)
		check(pins[path] == EXPECTED45[path], "runtime pin: " + path)
	for path: String in ["scenes/main.tscn", "scripts/main.gd", "scripts/preview_player.gd", "scripts/weapons/preview_weapons.gd", "scripts/weapons/rpg_effects.gd", "scripts/weapons/rpg_flight.gd", "scripts/weapons/weapon_projectiles.gd", "scripts/destruction/palazzo/palazzo_live_site.gd", "scripts/destruction/palazzo/palazzo_structural_site.gd", "project.godot"]:
		pins[path] = FileAccess.get_sha256("res://" + path)
		check(not str(pins[path]).is_empty(), "source receipt readable: " + path)
	evidence.source_sha256 = pins
	evidence.engine = Engine.get_version_info()
	evidence.settings = {"physics_ticks":Engine.physics_ticks_per_second, "display":DisplayServer.get_name(), "viewport":root.get_visible_rect().size, "rendering_method":ProjectSettings.get_setting("rendering/renderer/rendering_method", "default")}

func capsule45() -> Dictionary:
	var collision: CollisionShape3D = game.get("_player_capsule") as CollisionShape3D
	var shape: CapsuleShape3D = collision.shape as CapsuleShape3D if is_instance_valid(collision) else null
	return {"actor_id":player.get_instance_id(), "collision_id":collision.get_instance_id() if is_instance_valid(collision) else 0, "shape_id":shape.get_instance_id() if shape != null else 0, "height":shape.height if shape != null else -1.0, "radius":shape.radius if shape != null else -1.0, "layer":player.collision_layer, "mask":player.collision_mask, "authority":str(player.get("_pose_authority"))}

func current45(label: String) -> void:
	check(game._block.buildings.size() == 0 and game._block.decor.size() == 8 and str(game.get_meta("preview_building_mode", "")) == "palazzo_only43", label + ": only Palazzo mode, original eight decor retained")
	check(game.preview_population.hit_owners.size() == 3, label + ": three original NPC HP owners")
	check(capsule45() == actor45, label + ": same original standing capsule, collision masks and authority")
	check(bool(game.preview_transport.ready_for_play) and bool(weapons.ready_for_play) and bool(game.preview_c4.snapshot().get("ready", false)), label + ": transport weapons C4 ready")

func screenshot45(label: String) -> void:
	if not screenshots: return
	await RenderingServer.frame_post_draw
	var path: String = output.get_base_dir().path_join(label + ".png")
	var picture: Image = root.get_texture().get_image()
	if check(picture != null and not picture.is_empty() and picture.save_png(path) == OK, label + ": current gameplay camera screenshot saved"):
		screenshot_files45.append(path)
	# No pose, yaw, camera, collision, or scene edits inside screenshot capture.

func pane_inventory45() -> Dictionary:
	var rows: Array[Dictionary] = []
	var visible_roots: int = 0
	var visible_edges: int = 0
	var enabled_barriers: int = 0
	for row: Dictionary in host.site._glazing._panes.values():
		var mesh: MeshInstance3D = row.mesh as MeshInstance3D
		var body: StaticBody3D = row.body as StaticBody3D
		var collision: CollisionShape3D = row.collision as CollisionShape3D
		var edges: Array[int] = []
		for child: Node in mesh.find_children("Broken_Glass_Edges", "", true, false):
			if child is Node3D and child.is_visible_in_tree(): edges.append(child.get_instance_id())
		if mesh.is_visible_in_tree(): visible_roots += 1
		visible_edges += edges.size()
		if body.collision_layer != 0 or not collision.disabled: enabled_barriers += 1
		rows.append({"pane_id":body.get_instance_id(), "wall_id":row.wall.get_ref().get_instance_id() if is_instance_valid(row.wall.get_ref()) else 0, "mesh_visible":mesh.is_visible_in_tree(), "visible_cyan_edge_ids":edges, "barrier_layer":body.collision_layer, "collision_disabled":collision.disabled, "broken":row.broken, "support_lost":row.support_lost, "visual_retired":row.visual_retired})
	return {"stats":host.site._glazing.stats(), "rows":rows, "visible_roots":visible_roots, "visible_cyan_edges":visible_edges, "enabled_barriers":enabled_barriers}

func frame_candidates45() -> void:
	frames45.clear()
	for body: RigidBody3D in host.site.pieces:
		var mullions: int = 0
		var other: int = 0
		for child: Node in body.get_children():
			if not child is CollisionShape3D or child.disabled or child.shape == null: continue
			if str(child.get_meta("finished_role", "")) == "mullion": mullions += 1
			else: other += 1
		if mullions > 0 and body.freeze and not bool(body.get_meta("detached", false)):
			frames45.append({"id":body.get_instance_id(), "name":str(body.name), "mullion_shapes":mullions, "other_shapes":other, "start":body.global_position, "minimum_y":body.global_position.y, "detached":false, "support_released":false, "ever_dynamic":false})
	check(not frames45.is_empty(), "real frozen brass-frame collision bodies exist before K")

func sample_frames45() -> void:
	for row: Dictionary in frames45:
		var body: RigidBody3D = instance_from_id(int(row.id)) as RigidBody3D
		if not is_instance_valid(body): continue
		row.minimum_y = minf(float(row.minimum_y), body.global_position.y)
		row.detached = bool(body.get_meta("detached", false))
		row.support_released = bool(body.get_meta("support_released", false))
		row.ever_dynamic = bool(row.ever_dynamic) or not body.freeze
		row.finish = body.global_position

func collapse45() -> void:
	phase = "native_K"
	frame_candidates45()
	var before: int = owned_events("collapse").size()
	key(KEY_K, true)
	await step()
	key(KEY_K, false)
	check(owned_events("collapse").size() == before + 1, "one ordinary K input reaches collapse owner")
	for i: int in 240:
		await step()
		sample_frames45()
	var after: Dictionary = pane_inventory45()
	evidence.after_K = after
	evidence.physical_frames_K = frames45.duplicate(true)
	check(after.stats.panes == 28 and after.stats.support_lost == 28 and after.stats.retired_pane_visuals == 28 and after.stats.broken == 28 and after.stats.queued == 0, "K retires all 28 original pane supports, including already broken RPG pane")
	check(after.visible_roots == 0 and after.visible_cyan_edges == 0 and after.enabled_barriers == 0, "no fixed pane mesh, cyan Broken_Glass_Edges or glass barrier remains after K")
	var fell: int = 0
	var pure_fell: int = 0
	for row: Dictionary in frames45:
		row.drop_m = row.start.y - float(row.minimum_y)
		if row.detached and row.ever_dynamic and row.drop_m > .08:
			fell += 1
			if row.other_shapes == 0: pure_fell += 1
	evidence.physical_frames_K = {"bodies":frames45.duplicate(true), "fallen_frame_bearing_bodies":fell, "fallen_pure_mullion_bodies":pure_fell, "cause":"native K full-collapse command, not proof of unsupported-neighbour release", "manual_release":false}
	check(fell > 0, "actual detached brass-frame collision geometry falls under native physics")
	await screenshot45("03_after_K_same_west_camera")

func passage45() -> void:
	phase = "native_W_passage"
	# Independent setup INSIDE the former front-left window. The foundation is
	# exited downhill; this does not add a separate unaccepted step-up mechanic.
	pose(Vector3(-3.0, .34, 1.25), PI)
	await step(20)
	var start: Vector3 = host.site.to_local(player.global_position)
	check(start.z < 2.0 and absf(start.x + 3.0) < .5, "independent passage setup is inside destroyed front-left opening")
	await screenshot45("04_passage_start")
	var trace: Array[Dictionary] = []
	var reached: bool = false
	key(KEY_W, true)
	for i: int in 210:
		await step()
		var local: Vector3 = host.site.to_local(player.global_position)
		var contacts: Array[Dictionary] = []
		for index: int in player.get_slide_collision_count():
			var contact: KinematicCollision3D = player.get_slide_collision(index)
			var collider: Object = contact.get_collider()
			contacts.append({"id":collider.get_instance_id() if is_instance_valid(collider) else 0, "normal":contact.get_normal()})
		trace.append({"tick":i, "local":local, "velocity":player.velocity, "on_floor":player.is_on_floor(), "contacts":contacts})
		if local.z > 4.15 and absf(local.x + 3.0) < .7:
			reached = true
			break
	key(KEY_W, false)
	await step(4)
	var stop: Vector3 = host.site.to_local(player.global_position)
	evidence.passage = {"setup_local":Vector3(-3.0,.34,1.25), "start":start, "finish":stop, "trace":trace, "reached":reached, "native_input":"Input.parse_input_event physical KEY_W, ordinary player physics", "placement_calls_during_proof":0, "collision_edits":false, "jump_or_dive":false, "capsule":capsule45()}
	check(reached and stop.z - start.z > 2.0, "ordinary W carries the real capsule through former front-left wall plane among actual debris")
	check(capsule45() == actor45, "passage preserves original standing shape, actor, masks and on-foot authority")
	await screenshot45("05_passage_end")

func reset45() -> void:
	phase = "native_J"
	var generation: int = int(host.site.get_stats().generation)
	var old_ids: Array[int] = []
	for row: Dictionary in host.site._glazing._panes.values(): old_ids.append(row.body.get_instance_id())
	var before: int = owned_events("reset").size()
	key(KEY_J, true)
	await step()
	key(KEY_J, false)
	await step(90)
	var state: Dictionary = pane_inventory45()
	var reused: Array[int] = []
	for row: Dictionary in state.rows:
		if old_ids.has(int(row.pane_id)): reused.append(int(row.pane_id))
	check(owned_events("reset").size() == before + 1 and int(host.site.get_stats().generation) == generation + 1, "ordinary J creates exactly one new owned generation")
	check(state.stats.panes == 28 and state.stats.broken == 0 and state.stats.retired_pane_visuals == 0 and state.visible_roots == 28 and state.enabled_barriers == 28 and reused.is_empty(), "J restores 28 new intact panes, without resurrecting old retired identities")
	evidence.after_J = state
	current45("after J")

func run() -> void:
	begin_usec = Time.get_ticks_usec()
	output = "res://tests/frames45/report.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa45-out="): output = arg.trim_prefix("--qa45-out=").path_join("loaded_frames45.json")
	screenshots = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	create_timer(58.0).timeout.connect(func() -> void:
		if not finished:
			check(false, "58 second bounded gameplay fixture watchdog")
			finish())
	check(screenshots, "GPU gameplay screenshot run required; headless is not visual acceptance")
	source_receipt45()
	if not failures.is_empty(): finish(); return
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if not check(packed != null, "actual main scene loads"): finish(); return
	game = packed.instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	for i: int in 1500:
		await process_frame
		if game.preview_ready: break
	if not check(game.preview_ready, "full game ready"): finish(); return
	player = game._player
	weapons = game.preview_weapons
	camera = player.get_preview_camera()
	host = game.get("preview_palazzo")
	if not check(is_instance_valid(host) and host.get("status") == "ready" and is_instance_valid(host.site.get("_glazing")), "actual prepared Palazzo host and glazing ready"): finish(); return
	await step(8)
	if not player._free_mouse_look:
		mouse(MOUSE_BUTTON_LEFT, true)
		await step()
		mouse(MOUSE_BUTTON_LEFT, false)
		await step(2)
	if not check(player._free_mouse_look, "real click enables ordinary gameplay input"): finish(); return
	actor45 = capsule45()
	check(is_equal_approx(float(actor45.height),1.9) and is_equal_approx(float(actor45.radius),.30) and actor45.authority == "on_foot", "original full standing player capsule 1.9m height / .30m radius (unchanged production shape)")
	current45("initial")
	evidence.initial_panes = pane_inventory45()
	evidence.initial_host = host.snapshot()
	weapons.rpg_effects.connect("native_impact", on_terminal)
	weapons.connect("shot_emitted", on_shot)
	phase = "native_RPG"
	pose(Vector3(-14,.11,0), -PI * .5)
	await step(15)
	var panel: RigidBody3D = west_panel()
	var pane: Dictionary = pane_target(panel)
	if not check(not pane.is_empty(), "native ray finds actual west glass quadrant"): finish(); return
	if not check(weapons.equip("rpg").get("ok",false), "existing native inventory equips RPG"): finish(); return
	if not await native_reload_round("RPG45"): finish(); return
	target = pane.point
	mouse(MOUSE_BUTTON_RIGHT, true)
	if not check(await settle_aim(pane.body, "before screenshot"), "real mouse aim settles on real pane"): finish(); return
	await screenshot45("01_before_RPG")
	var event: Dictionary = await fire_rpg(pane.body, pane.point, "RPG45 actual pane")
	evidence.rpg = {"event":event, "terminals":terminals.duplicate(true), "launches":emitted_shots.duplicate(true), "synthetic_positive_receipt":false}
	if not check(not event.is_empty(), "authenticated real projectile damage observed"): finish(); return
	await step(90)
	evidence.after_RPG = pane_inventory45()
	check(pane.body.collision_layer == 0, "actual RPG pane fracture removes glass barrier")
	await screenshot45("02_after_RPG_same_west_camera")
	await collapse45()
	await passage45()
	await reset45()
	evidence.final_host = host.snapshot()
	finish()

func finish() -> void:
	if finished: return
	finished = true
	tracking = false
	for code: Key in [KEY_W, KEY_R, KEY_K, KEY_J]: key(code, false)
	mouse(MOUSE_BUTTON_LEFT, false)
	mouse(MOUSE_BUTTON_RIGHT, false)
	var report: Dictionary = {"schema":"frames45_loaded_gameplay/v1", "status":"FOCUSED_GAMEPLAY_PASS" if failures.is_empty() else "FAIL", "checks":checks, "failures":failures, "elapsed_usec":Time.get_ticks_usec()-begin_usec, "evidence":evidence, "screenshots":screenshot_files45, "native_RPG_input":true, "synthetic_positive_damage":false, "fixture_body_release_or_collision_edits":false, "unsupported_mullion_causal_proof":"SEPARATE Buildings3 frames44 exact-three-component-blast comparative native fixture required; K gravity does not prove support solver", "loaded_performance_accepted":false, "manual_OS_input_verified":false, "limits":["Only one native RPG impact, one full K collapse, one W passage and one J reset.","Initial placements are explicit test setup. W proof never teleports; rubble collision remains enabled.","Native viewport/input injection invokes real gameplay; this is not physical keyboard automation.","Functional run does not establish matched before/after FPS or every arbitrary window damage pattern."]}
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	else:
		print("FRAMES45 report write failed: ", output)
	print("FRAMES45 ", report.status, " checks=", checks, " failures=", failures.size(), " report=", output)
	quit(0 if failures.is_empty() else 2)
