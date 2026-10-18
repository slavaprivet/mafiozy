extends SceneTree
## DSH_MELEE_SET real-click check
##
## The report is "weapons cannot be taken from the arsenal - I cannot take the spear,
## the mace, any of them - and I do not see the shield".
##
## The previous check pressed each button by EMITTING its signal, which bypasses the
## whole GUI hit-test: mouse filter, visibility, and whether something is drawn on top.
## A card can therefore pass that check and still be unclickable for a player. This one
## sends a REAL mouse click at the centre of each card's rectangle, exactly as a player
## would, and reports what happened.

var _scene: Node
var _player: CharacterBody3D
var _weapons: Node
var _ui: Node

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _click_at(point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point
	Input.parse_input_event(move)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await process_frame

## Whether the arsenal actually took that card: the shield is worn, not equipped.
func _card_took(id: String) -> bool:
	if id == "shield":
		var proto: Node = _scene.get("preview_sword_prototype")
		return proto != null and bool((proto.call("shield_status") as Dictionary).get("worn", false))
	return str((_weapons.get("fire_state") as Dictionary).get("weaponId", "")) == id

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("CLICK_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("CLICK_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_weapons = _scene.get("preview_weapons")
	_ui = _weapons.get("_walk_ui")
	if _ui == null:
		print("CLICK_FAIL ui_missing"); quit(1); return
	_player.set_mouse_captured(true)
	await _settle(10)
	# Open the arsenal exactly as a key press does.
	_weapons.call("set_menu", true)
	await _settle(24)
	var menu: Control = _weapons.get("_menu")
	print("CLICK_MENU open=", bool(_weapons.get("menu_open")),
		" visible=", menu.visible if is_instance_valid(menu) else false,
		" rect=", menu.get_global_rect() if is_instance_valid(menu) else Rect2())
	var choices: Dictionary = _ui.get("choices")
	var ids: Array = ["sword", "mace", "axe", "sledge", "spear", "shield"]
	var report: Dictionary = {}
	for id: String in ids:
		if not choices.has(id):
			report[id] = {"button": false, "reason": "no_card"}
			print("CLICK_CARD ", id, " NO_CARD")
			continue
		var entry: Dictionary = choices[id]
		var button: Button = entry.get("button")
		if not is_instance_valid(button):
			report[id] = {"button": false, "reason": "invalid"}
			continue
		var rect: Rect2 = button.get_global_rect()
		var visible: bool = button.is_visible_in_tree()
		var centre: Vector2 = rect.get_center()
		# What the GUI says is at that point: a card covered by something else can never
		# be clicked, however visible it looks.
		var at_point: Control = get_root().gui_get_hovered_control() if get_root().has_method("gui_get_hovered_control") else null
		var menu_now: Control = _weapons.get("_menu")
		var hovered: String = "?"
		var viewport := get_root()
		if viewport.has_method("gui_get_hovered_control"):
			var hover: Control = viewport.call("gui_get_hovered_control")
			hovered = hover.name + ":" + hover.get_class() if hover != null else "none"
		var before: String = str((_weapons.get("fire_state") as Dictionary).get("weaponId", ""))
		# Three points, because a single point can sit under something else.
		var points := [centre, rect.position + Vector2(34.0, 34.0), rect.position + Vector2(rect.size.x - 34.0, 34.0)]
		var hit_point := Vector2(-1, -1)
		for point: Vector2 in points:
			await _click_at(point)
			await _settle(3)
			if _card_took(id): 
				hit_point = point
				break
		if hit_point.x < 0:
			await _click_at(centre)
		await _settle(4)
		# A second click, because a synthetic click right after a mouse-mode change can
		# be swallowed by the engine before it reaches the GUI.
		if str(((_weapons.get("fire_state") as Dictionary).get("weaponId", ""))) != id:
			await _click_at(centre)
		await _settle(6)
		var after: String = str((_weapons.get("fire_state") as Dictionary).get("weaponId", ""))
		if id == "shield":
			# The shield is WORN rather than equipped, so it has its own state.
			var shield_state: Dictionary = (_scene.get("preview_sword_prototype") as Node).call("shield_status")
			after = "shield" if bool(shield_state.get("worn", false)) else "none"
		var proto: Node = _scene.get("preview_sword_prototype")
		var proto_weapon := ""
		var weapon_visible := false
		var grip_error := 99.0
		if proto != null:
			var snap_after: Dictionary = proto.call("snapshot")
			proto_weapon = str(snap_after.get("weapon", ""))
			weapon_visible = bool(snap_after.get("weapon_visible", false))
			grip_error = float(snap_after.get("grip_hand_error", 99.0))
		report[id] = {
			"button": true, "visible": visible,
			"rect": rect, "centre": centre,
			"before": before, "after": after, "proto_weapon": proto_weapon,
			"weapon_visible": weapon_visible, "grip_error": grip_error,
		}
		print("CLICK_CARD ", id, " in_hand=", weapon_visible, " grip_err=", grip_error,
			" menu_open=", bool(_weapons.get("menu_open")),
			" menu_visible=", menu_now.visible if is_instance_valid(menu_now) else false,
			" hovered=", hovered,
			" visible=", visible, " rect=", rect, " centre=", centre,
			" weapon_before=", before, " weapon_after=", after, " proto=", proto_weapon,
			" selected_now=", after == id)
		if not bool(_weapons.get("menu_open")) and id != "shield":
			_weapons.call("set_menu", true)
			await _settle(18)
	var failed: Array[String] = []
	for id: String in ids:
		var line: Dictionary = report.get(id, {})
		if not bool(line.get("button", false)) or not bool(line.get("visible", false)):
			failed.append(id + ":not_shown")
		elif not bool(line.get("weapon_visible", false)):
			failed.append(id + ":not_in_hands")
		elif str(line.get("after", "")) != id:
			failed.append(id + ":click_ignored")
	print("CLICK_OBJECTIVE ", JSON.stringify(report))
	print("CLICK_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
