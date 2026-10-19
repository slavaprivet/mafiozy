extends SceneTree
## DSH_MELEE_SET arsenal-click check
##
## The user reports that pressing a weapon in the arsenal does not select it. This
## opens the real arsenal, presses each weapon's own BUTTON - the same signal a mouse
## click fires - and reports what the host did with it. It separates "the button is
## not reachable" from "the host refuses the equip".

var _scene: Node
var _player: CharacterBody3D
var _weapons: Node

func _initialize() -> void:
	_run()

func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("ARSENAL_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("ARSENAL_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_weapons = _scene.get("preview_weapons")
	if _weapons == null:
		print("ARSENAL_FAIL host_missing"); quit(1); return
	var ui: Node = _weapons.get("_walk_ui")
	if ui == null:
		print("ARSENAL_FAIL ui_missing"); quit(1); return
	# Open the arsenal the way the player does: with the mouse captured, so the MENU
	# takes the cursor for itself.
	_player.set_mouse_captured(true)
	await _settle(6)
	_weapons.call("set_menu", true)
	await _settle(12)
	var menu: Control = _weapons.get("_menu")
	print("ARSENAL_OPEN menu_open=", _weapons.get("menu_open"), " menu_visible=",
		menu.visible if is_instance_valid(menu) else false,
		" mouse_mode=", Input.mouse_mode, " free_mouse_look=", _player.get("_free_mouse_look"))
	var choices: Dictionary = ui.get("choices")
	print("ARSENAL_CHOICES count=", choices.size(), " keys=", choices.keys())
	var results: Dictionary = {}
	for id: String in ["sword", "mace", "axe", "sledge", "spear"]:
		if not choices.has(id):
			results[id] = "NO_BUTTON"
			continue
		var entry: Dictionary = choices[id]
		var button: Button = entry.get("button")
		var reachable: bool = is_instance_valid(button) and button.visible and not button.disabled
		# The same signal a real click emits.
		if reachable: button.pressed.emit()
		await _settle(10)
		var state: Dictionary = _weapons.get("fire_state")
		var proto: Node = _scene.get("preview_sword_prototype")
		var snap: Dictionary = proto.snapshot() if proto != null else {}
		results[id] = {
			"button_visible": reachable,
			"host_weapon": str(state.get("weaponId", "")),
			"proto_weapon": str(snap.get("weapon", "")),
			"selected": bool(snap.get("selected", false)),
		}
		print("ARSENAL_CLICK ", id, " ", JSON.stringify(results[id]))
		# Reopen for the next one, as a player would.
		if not bool(_weapons.get("menu_open")):
			_weapons.call("set_menu", true)
			await _settle(6)
	var failed: Array[String] = []
	for id: String in results.keys():
		var line: Variant = results[id]
		if typeof(line) != TYPE_DICTIONARY:
			failed.append(id)
			continue
		if not bool(line.get("button_visible", false)) \
				or str(line.get("host_weapon", "")) != id \
				or str(line.get("proto_weapon", "")) != id:
			failed.append(id)
	print("ARSENAL_OBJECTIVE ", JSON.stringify(results))
	print("ARSENAL_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
