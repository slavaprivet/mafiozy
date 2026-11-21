extends SceneTree

const ResidentCard = preload("res://scripts/npc_visual/npc_resident_card_canvas29.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var label := Label3D.new()
	label.position = Vector3(0.27, 1.6, -8.0)
	root.add_child(label)
	var card: Control = ResidentCard.new()
	root.add_child(card)
	await process_frame
	var main_script: GDScript = load("res://scripts/main.gd")
	if main_script == null:
		_fail("main script could not be loaded")
		return
	var viewport_size := root.get_visible_rect().size
	var raw_fraction_seen := false
	var snapped_motion_seen := false
	var card_motion_seen := false
	var previous := Vector2(-1.0, -1.0)
	var previous_card := Vector2(-1.0, -1.0)
	for step in 32:
		# Include a stationary camera and fractional camera/source motion.
		camera.position.x = 0.0 if step == 0 else float(step) * 0.013
		label.position.x = 0.27 if step < 16 else 0.27 + float(step - 15) * 0.019
		var projected := camera.unproject_position(label.global_position)
		var hint: Vector2 = main_script.call("_pixel_aligned_hint_position", projected, Vector2(180.0, 36.0), viewport_size)
		if not _integral(hint):
			_fail("interaction plaque has a fractional pixel position")
			return
		if projected.distance_to(projected.round()) > 0.01:
			raw_fraction_seen = true
		card.claim(label)
		card._process(0.0)
		if not card.visible or not _integral(card.position):
			_fail("resident name card is hidden or has a fractional pixel position")
			return
		if step > 0 and hint != previous:
			snapped_motion_seen = true
		if step > 0 and card.position != previous_card:
			card_motion_seen = true
		previous = hint
		previous_card = card.position
	if not raw_fraction_seen or not snapped_motion_seen or not card_motion_seen:
		_fail("camera motion did not exercise fractional projection and pixel movement")
		return
	print("SCREEN_LABEL_PIXEL_POSITIONS PASS: stationary and moving camera/source")
	quit(0)

func _integral(point: Vector2) -> bool:
	return point == point.round()

func _fail(reason: String) -> void:
	push_error("SCREEN_LABEL_PIXEL_POSITIONS FAIL: " + reason)
	quit(1)
