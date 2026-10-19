extends SceneTree

class Sample:
	extends Node
	var player: Node
	var bow: Node
	var phase := ""
	var rows: Array = []
	var physics_yaw := 0.0
	var previous_yaw := 0.0
	func _physics_process(_dt: float) -> void:
		if is_instance_valid(player): physics_yaw = player._visual.global_rotation.y
	func _process(dt: float) -> void:
		if phase.is_empty() or not is_instance_valid(player): return
		var yaw: float = player._visual.global_rotation.y
		var forward: Vector3 = -player._camera.global_basis.z
		rows.append({"phase":phase,"dt":dt,"position":[player.position.x,player.position.y,player.position.z],"yaw":yaw,"heading":player._heading,"physics_correction_degrees":rad_to_deg(absf(wrapf(yaw-physics_yaw,-PI,PI))),"render_step_degrees":rad_to_deg(absf(wrapf(yaw-previous_yaw,-PI,PI))),"camera_error_degrees":rad_to_deg(absf(wrapf(yaw-atan2(forward.x,forward.z),-PI,PI))),"bow_owns":is_instance_valid(bow) and bow.has_method("owns_player_facing") and bow.owns_player_facing(),"bow_selected":is_instance_valid(bow) and bow._selected})
		previous_yaw = yaw

var game: Node
var player: Node
var bow: Node
var storage: Node
var probe: Sample
var out := ""
var weapon := "bow"
var checks: Array = []
var errors: Array[String] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out = arg.trim_prefix("--qa-out=")
		if arg.begins_with("--weapon="): weapon = arg.trim_prefix("--weapon=")
	run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func check(name_: String, passed: bool, evidence: Variant = null) -> void:
	checks.append({"name":name_,"passed":passed,"evidence":evidence})
	if not passed: errors.append(name_)

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = down
	Input.parse_input_event(event)

func tap(code: int) -> void:
	key(code,true); await frames(2); key(code,false); await frames(2)

func button(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
	Input.parse_input_event(event)

func motion(dx: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx,0); Input.parse_input_event(event)

func owns() -> bool:
	return is_instance_valid(bow) and bow.has_method("owns_player_facing") and bow.owns_player_facing()

func phase(label: String, code: int, expect_bow: bool) -> void:
	var initial: Vector3 = player.global_position
	key(code,true); await frames(45)
	probe.previous_yaw = player._visual.global_rotation.y
	var first := probe.rows.size()
	probe.phase = label; await frames(90); probe.phase = ""
	key(code,false); await frames(12)
	var moved: float = Vector2(player.global_position.x-initial.x,player.global_position.z-initial.z).length()
	var max_correction := 0.0; var max_step := 0.0; var max_error := 0.0
	var mismatch := 0
	for i in range(first,probe.rows.size()):
		var row: Dictionary = probe.rows[i]
		max_correction = maxf(max_correction,row.physics_correction_degrees)
		max_step = maxf(max_step,row.render_step_degrees)
		max_error = maxf(max_error,row.camera_error_degrees)
		if bool(row.bow_owns) != expect_bow: mismatch += 1
	var metrics := {"movement_m":moved,"max_physics_correction_degrees":max_correction,"max_render_step_degrees":max_step,"max_camera_error_degrees":max_error,"ownership_mismatch":mismatch,"samples":probe.rows.size()-first}
	check(label+"_walking",moved>4.0,metrics)
	check(label+"_ownership",mismatch==0,metrics)
	if expect_bow:
		check(label+"_stable",max_correction<0.05 and max_step<0.05 and max_error<0.5,metrics)

func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://scenes/castle.tscn").instantiate()
	root.add_child(game); current_scene = game
	while game.get("preview_ready") != true: await process_frame
	await frames(100); game._castle_spawn_frames = 0
	player = game._player; storage = game.preview_castle.armory_storage
	var acquired: Dictionary = storage.acquire_or_select(weapon)
	check("acquired_"+weapon,bool(acquired.get("ok",false)),acquired)
	if weapon != "bow":
		var acquired_bow: Dictionary = storage.acquire_or_select("bow")
		check("acquired_back_bow",bool(acquired_bow.get("ok",false)),acquired_bow)
		storage.select_carried(weapon)
	bow = game.preview_bow_prototype
	player.global_position = Vector3(0,.1,990); player.velocity = Vector3.ZERO
	player._camera_yaw = 0; player._camera_pitch = -.24
	player._update_camera_rotation(); player.set_mouse_captured(true)
	await frames(90)
	check("viewport_1280x720",root.size==Vector2i(1280,720),str(root.size))
	var before: float = player._camera_yaw
	motion(10); await frames(2)
	var delivered: float = -wrapf(float(player._camera_yaw)-before,-PI,PI)/float(player.mouse_sensitivity)
	check("mouse_1to1",absf(delivered-10)<.05,delivered)
	motion(-10); await frames(45)
	probe = Sample.new(); probe.player = player; probe.bow = bow
	probe.process_priority = 300; probe.process_physics_priority = 300; root.add_child(probe)
	for item in [["back",KEY_S],["left",KEY_A],["right",KEY_D],["forward",KEY_W]]:
		await phase(weapon+"_"+str(item[0]),int(item[1]),weapon=="bow")
	button(true); await frames(50)
	await phase(weapon+"_back_aimed",KEY_S,weapon=="bow")
	button(false); await frames(20)
	# A real mouse turn, then ordinary movement in the new camera frame.
	for i in 10: motion(20); await frames(2)
	await frames(90)
	await phase(weapon+"_back_turned",KEY_S,weapon=="bow")
	if weapon != "bow":
		var selected: Dictionary = storage.select_carried("bow")
		check("select_bow",bool(selected.get("ok",false)),selected)
		await frames(90)
		await phase(weapon+"_to_bow_back",KEY_S,true)
		selected = storage.select_carried(weapon)
		check("select_melee_again",bool(selected.get("ok",false)),selected)
		await frames(60)
		await phase(weapon+"_after_bow_back",KEY_S,false)
	else:
		storage.weapons.set_menu(true); await frames(4)
		check("menu_releases_facing",not owns())
		storage.weapons.set_menu(false); player.set_mouse_captured(true); await frames(4)
		check("menu_close_restores_facing",owns())
		player.set_mouse_captured(false); await frames(4)
		check("cursor_releases_facing",not owns())
		player.set_mouse_captured(true); await frames(4)
		check("cursor_capture_restores_facing",owns())
		await tap(KEY_G); await frames(8)
		check("g_drop_releases_facing",bow._grounded and not owns(),bow.snapshot())
		await tap(KEY_E); await frames(40)
		check("e_pickup_restores_facing",not bow._grounded and owns(),bow.snapshot())
	var result := {"passed":errors.is_empty(),"weapon":weapon,"checks":checks,"errors":errors,"rows":probe.rows,"scope":"Native synthetic WASD/RMB/G/E/mouse events, rack API setup, menu and cursor ownership gates. Movement and render/physics ownership only; no hit/contact/performance claim."}
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("MOTION53_RESULT "+JSON.stringify({"passed":errors.is_empty(),"weapon":weapon,"checks":checks,"errors":errors}))
	quit(0 if errors.is_empty() else 2)
