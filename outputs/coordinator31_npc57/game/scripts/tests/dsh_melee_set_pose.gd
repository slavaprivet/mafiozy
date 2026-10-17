extends SceneTree
## DSH_MELEE_SET live run
##
## Presents every weapon of the set in the real scene, one after another, and reports
## what the prototype actually did: is the model in the fist, is the two-handed grip
## closed for the weapons that need it, is the tip where the reach test says, and what
## damage profile the weapon carries. One screenshot per weapon, so the models can be
## looked at rather than imagined.

const OUT_DIR := "C:/Users/Слава/Documents/deepseek-harness/default-workspace"
const ORDER := ["sword", "mace", "axe", "sledge", "spear"]

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
	if image == null:
		print("MELEE_SET_SHOT ", name, " no_image")
		return
	print("MELEE_SET_SHOT ", name, " ", image.save_png(OUT_DIR + "/shot_melee_" + name + ".png"))

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main_city.tscn")
	if packed == null:
		print("MELEE_SET_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if _scene.get("preview_ready") == true: break
		await process_frame
	if _scene.get("preview_ready") != true:
		print("MELEE_SET_FAIL not_ready"); quit(1); return
	_player = _scene.get("_player")
	_proto = _scene.get("preview_sword_prototype")
	if _proto == null:
		print("MELEE_SET_FAIL proto_missing"); quit(1); return
	_player.set_mouse_captured(true)
	var weapons: Node = _scene.get("preview_weapons")
	var results: Dictionary = {}
	for id: String in ORDER:
		var equipped: Dictionary = weapons.equip(id) if weapons != null else {}
		await _settle(50)
		var snap: Dictionary = _proto.snapshot()
		var tip: Vector3 = snap.get("blade_tip", Vector3.ZERO)
		var fist: Vector3 = snap.get("sword_origin", Vector3.ZERO)
		# The mask wraps the whole haft, so the visible weapon's reach is measured from
		# the fist to the tip and compared with the length the table declares.
		var reach := fist.distance_to(tip)
		var line := {
			"equipped_ok": bool(equipped.get("ok", false)),
			"weapon": snap.get("weapon", ""),
			"category": snap.get("weapon_category", ""),
			"mass": snap.get("weapon_mass", 0.0),
			"length": snap.get("weapon_length", 0.0),
			"reach_m": reach,
			"grip_error": snap.get("grip_hand_error", 0.0),
			"support_error": snap.get("left_hand_error", 0.0),
			"side": str(snap.get("side", "")),
			"selected": bool(snap.get("selected", false)),
		}
		results[id] = line
		print("MELEE_SET_WEAPON ", id, " ", JSON.stringify(line))
		await _shot(id)
	var verdict := {}
	var failed: Array[String] = []
	for id: String in ORDER:
		var line: Dictionary = results.get(id, {})
		var snap_length := float(line.get("length", 0.0))
		var reach := float(line.get("reach_m", 0.0))
		var ok := bool(line.get("equipped_ok", false)) \
			and str(line.get("weapon", "")) == id \
			and bool(line.get("selected", false)) \
			and float(line.get("grip_error", 9.0)) < 0.12 \
			and reach > snap_length * 0.7
		# The two-handed weapons must have the support hand ON the haft.
		if id in ["axe", "sledge", "spear"]:
			ok = ok and float(line.get("support_error", 9.0)) < 0.20
		verdict[id] = ok
		if not ok: failed.append(id)
	print("MELEE_SET_OBJECTIVE ", JSON.stringify(verdict))
	print("MELEE_SET_RESULT ", "PASS" if failed.is_empty() else "FAIL " + str(failed))
	quit(0)
