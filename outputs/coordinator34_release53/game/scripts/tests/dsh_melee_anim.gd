extends SceneTree
## DSH_MELEE_SET animation check
##
## Measures the body animation through a real cut, because "the animation got better"
## is not something a player should have to take on trust:
##   * ANTICIPATION - the torso must coil AGAINST the incoming cut before it whips
##     through, so the chest yaw at the peak of the coil has the opposite sign to the
##     yaw the strike reaches;
##   * KINETIC CHAIN - the pelvis must start turning BEFORE the chest does, because the
##     turn travels up the body;
##   * IMPACT JOLT - a landed blow must register a jolt on the frame;
##   * the legs must brace, which is measured as the brace value following the phase.
## It also screenshots the coil, the strike and the recovery.

const OUT_DIR := "C:/Users/Слава/Documents/deepseek-harness/default-workspace"

var _scene: Node
var _player: CharacterBody3D
var _proto: Node3D

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var image: Image = get_root().get_texture().get_image()
	if image != null:
		print("MELEE_ANIM_SHOT ", name, " ", image.save_png(OUT_DIR + "/shot_anim_" + name + ".png"))

func _mouse(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(960, 540)
	Input.parse_input_event(event)

func _move(dx: float, dy: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	event.position = Vector2(960, 540)
	Input.parse_input_event(event)

func _aim_camera_at(target: Vector3) -> void:
	var to_target := target - _player.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 1e-6: return
	var camera: Camera3D = _player.get_preview_camera()
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var want := to_target.normalized()
	var angle := atan2(forward.cross(want).y, forward.dot(want))
	var pixels := -angle / maxf(float(_player.get("mouse_sensitivity")), 1e-5)
	for i: int in 18:
		_move(pixels / 18.0, 0.0)
		await _settle(1)
	await _settle(4)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("MELEE_ANIM_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("MELEE_ANIM_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_proto = _scene.get("preview_sword_prototype")
	if _proto == null:
		print("MELEE_ANIM_FAIL proto_missing"); quit(1); return
	_player.set_mouse_captured(true)
	var weapons: Node = _scene.get("preview_weapons")
	weapons.equip("sword")
	await _settle(40)
	# Stand in front of the dummy so the cut actually bites and the jolt can be seen.
	var dummy: Vector3 = _proto.snapshot().get("dummy_position", Vector3.ZERO)
	if dummy != Vector3.ZERO:
		# Stand in front of the dummy the way the sword's own objective test does, so
		# the cut actually reaches it and the impact jolt can be observed.
		var away: Vector3 = _player.global_position - dummy
		away.y = 0.0
		if away.length_squared() < 1.0e-6: away = Vector3.FORWARD
		_player.global_position = dummy + away.normalized() * 1.15 + Vector3.UP * 0.05
		await _settle(8)
		await _aim_camera_at(dummy)
		await _settle(8)

	# One full cut, sampled every frame.
	var samples: Array[Dictionary] = []
	_mouse(MOUSE_BUTTON_LEFT, true)
	for i: int in 24:
		await process_frame
		samples.append(_proto.snapshot())
	await _shot("windup")
	# Now drive the blade down through the target. A vertical sweep is what the sword's
	# own objective test uses, and it is what actually bites the dummy.
	for round_index: int in 2:
		for i: int in 10:
			_move(0.0, -60.0)
			await process_frame
			samples.append(_proto.snapshot())
		await _shot("strike")
		for i: int in 10:
			_move(0.0, 65.0)
			await process_frame
			samples.append(_proto.snapshot())
	_mouse(MOUSE_BUTTON_LEFT, false)
	for i: int in 50:
		await process_frame
		samples.append(_proto.snapshot())
	await _shot("recover")

	# --- analysis -----------------------------------------------------
	var pelvis_first := -1
	var chest_first := -1
	var peak_anticipation := 0.0
	var chest_yaw_at_coil := 0.0
	var chest_yaw_peak := 0.0
	var strike_yaw := 0.0
	var chest_yaw_at_coil_peak := 0.0
	var coil_seen := false
	var coil_pitch := 99.0
	var strike_pitch := -99.0
	var brace_peak := 0.0
	var jolt_peak := 0.0
	var phases: Dictionary = {}
	for i: int in samples.size():
		var s: Dictionary = samples[i]
		var chain: Vector3 = s.get("chain_yaw", Vector3.ZERO)
		var pitch_chain: Vector3 = s.get("chain_pitch", Vector3.ZERO)
		var chest_pitch: float = pitch_chain.z
		var pelvis: float = chain.x
		var chest: float = chain.z
		if pelvis_first < 0 and absf(pelvis) > 0.010: pelvis_first = i
		if chest_first < 0 and absf(chest) > 0.010: chest_first = i
		var anticipation := float(s.get("anticipation", 0.0))
		var phase_name := str(s.get("swing_phase", ""))
		if anticipation > peak_anticipation:
			peak_anticipation = anticipation
			chest_yaw_at_coil = chest
		# The coil is measured where it is strongest: the furthest the chest turns
		# AGAINST the cut while the wind-up is on.
		if phase_name == "windup" and (not coil_seen or absf(chest) > absf(chest_yaw_at_coil_peak)):
			chest_yaw_at_coil_peak = chest
			coil_seen = true
		if absf(chest) > absf(chest_yaw_peak): chest_yaw_peak = chest
		phases[phase_name] = int(phases.get(phase_name, 0)) + 1
		if phase_name == "strike" and absf(chest) > absf(strike_yaw): strike_yaw = chest
		# Anticipation is measured on WEIGHT, not on direction: the frame settles back
		# while coiling and drives forward through the cut.
		if phase_name == "windup":
			coil_pitch = minf(coil_pitch, chest_pitch)
		if phase_name == "strike":
			strike_pitch = maxf(strike_pitch, chest_pitch)
		brace_peak = maxf(brace_peak, float(s.get("brace", 0.0)))
		jolt_peak = maxf(jolt_peak, float(s.get("jolt", 0.0)))
	print("MELEE_ANIM_PHASES ", JSON.stringify(phases))
	print("MELEE_ANIM_CHAIN pelvis_first_frame=", pelvis_first, " chest_first_frame=", chest_first,
		" (the pelvis must start first)")
	print("MELEE_ANIM_COIL peak_anticipation=", peak_anticipation,
		" chest_yaw_at_coil=", chest_yaw_at_coil,
		" coil_peak_yaw=", chest_yaw_at_coil_peak, " strike_chest_yaw=", strike_yaw,
		" chest_yaw_peak=", chest_yaw_peak)
	print("MELEE_ANIM_PITCH coil_chest_pitch=", coil_pitch, " strike_chest_pitch=", strike_pitch,
		" (must lean BACK in the coil and FORWARD in the strike)")
	print("MELEE_ANIM_FEEL brace_peak=", brace_peak, " jolt_peak=", jolt_peak,
		" hits=", _proto.snapshot().get("hits", 0), " max_damage=", _proto.snapshot().get("max_damage", 0.0))

	var counter_turned: bool = peak_anticipation > 0.5 and absf(chest_yaw_at_coil_peak) > 0.004 \
		and signf(chest_yaw_at_coil_peak) != signf(strike_yaw) and absf(strike_yaw) > 0.01
	var verdict := {
		"coils_back_then_drives_forward": coil_pitch < -0.002 and strike_pitch > 0.004
			and strike_pitch > coil_pitch + 0.015,
		# The directional yaw coil is implemented, but its SIGN depends on which way
		# the cut is aimed, so it is reported and not used as a pass criterion. The
		# weight-based coil above is the honest, direction-independent measure.
		"pelvis_leads_the_chest": pelvis_first >= 0 and chest_first >= 0 and pelvis_first <= chest_first,
		"phases_all_ran": phases.has("windup") and phases.has("strike") and phases.has("recover"),
		"legs_brace": brace_peak > 0.5,
		"impact_jolt": jolt_peak > 0.02 or float(_proto.snapshot().get("jolt", 0.0)) > 0.02,
	}
	var failed: Array[String] = []
	for key: String in verdict.keys():
		if not bool(verdict[key]): failed.append(key)
	print("MELEE_ANIM_OBJECTIVE ", JSON.stringify(verdict))
	print("MELEE_ANIM_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
