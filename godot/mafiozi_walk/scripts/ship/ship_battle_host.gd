extends Node3D
## SHIP61: the sea battle host.
##
## Owns the water basin, the ship, the four cannons, the cabin stores, the shared
## F-prompt and the player stations. This is the only node `main.gd` knows about.
##
## Everything is procedural and local: no external assets, no scene scans in the
## frame loop, no network. The ship itself is an AnimatableBody3D platform so the
## player can walk her decks while she sails.

const ShipWaterBasin = preload("res://scripts/ship/ship_water_basin.gd")
const ShipBoat = preload("res://scripts/ship/ship_boat.gd")
const ShipCannons = preload("res://scripts/ship/ship_cannons.gd")
const ShipHud = preload("res://scripts/ship/ship_hud.gd")
## The model is loaded lazily: a partially delivered file must not stop the rest
## of the map from booting while the model is still being written.
const SHIP_MODEL_PATH := "res://scripts/ship/ship_model.gd"

const SHIP_SPAWN := Vector3(115.0, 0.0, 975.0)
const SHIP_YAW_DEG := 0.0
## SHIP63: the identical target hulk lies 45 m to the east, beam to beam.
const TARGET_SPAWN := Vector3(160.0, 0.0, 975.0)
const TARGET_YAW_DEG := 0.0
const START_BALLS := 6
const START_BOARDS := 4
const MAX_BALLS := 30
const MAX_BOARDS := 12
const CRATE_BALLS := 1
const CRATE_BOARDS := 1
const CRATE_COOLDOWN := 1.1
const REACH := 3.6
const REPAIR_REACH := 3.0
const HELM_STAND := Vector3(0.0, 3.06, 11.15)

var world: Node3D
var castle: Node3D
var player: CharacterBody3D

var preview_basin: Node3D
var preview_model: Node3D
var preview_boat: AnimatableBody3D
var preview_cannons: Node3D
var preview_hud: CanvasLayer
var preview_target: Node3D
var preview_powder: Node3D
## Public aliases: QA and the HUD look for these names on the host.
var basin: Node3D
var model: Node3D
var boat: AnimatableBody3D
var cannons: Node3D
var hud: CanvasLayer
var target: Node3D
var powder: Node3D

var balls := START_BALLS
var boards := START_BOARDS
var status := "disabled"
var _installed := false

var _station := ""
var _cannon_index := -1
var _seat_pending := 0
var _hold_owned := false
var _cannon_camera_on := false
var _saved_spring := -1.0
var _gun_camera: Camera3D
var _hud_timer := 0.0
var _aboard_timer := 0.0
var _weapon_hud: Control
var _weapon_hud_hidden := false
var _wake_timer := 0.0
var _crate_timer := 0.0
var _sunk_announced := false
var _water_time := 0.0
var _model_data: Dictionary = {}
var _last_action: Dictionary = {}
var _cannon_messages := 0
var _ball_props: Array[MeshInstance3D] = []
var _carried_ball_mesh: MeshInstance3D
var _dropped_ball: Node3D
var _deck_balls: Array[Node3D] = []
var _carry_phase := 0.0
var _aim_left := false
var _aim_right := false
var _aim_up := false
var _aim_down := false
var _fire_queued := false
var _swim_state := false
var _last_broken_count := 0
var _lever_work_phase := 0.0
var _lever_hold_pos := Vector3.ZERO


func install(world_in: Node3D, castle_in: Node3D) -> Dictionary:
	if _installed:
		return {"ok": false, "reason": "already_installed"}
	if not is_instance_valid(world_in) or not is_instance_valid(castle_in):
		return {"ok": false, "reason": "missing_world_or_castle"}
	var candidate_player := world_in.get("_player") as CharacterBody3D
	if not is_instance_valid(candidate_player):
		return {"ok": false, "reason": "missing_player"}
	world = world_in
	castle = castle_in
	player = candidate_player

	# 1. The model is built first and outside the tree: if it is still being
	# delivered, the castle map must keep its own ground instead of losing it.
	var model_script: Script = load(SHIP_MODEL_PATH)
	if model_script == null:
		status = "model_missing"
		return {"ok": false, "reason": status}
	preview_model = model_script.new()
	preview_model.name = "ShipModel"
	add_child(preview_model)
	_model_data = preview_model.build()
	if not bool(_model_data.get("ok", true)):
		status = "model_failed"
		return {"ok": false, "reason": status}

	# 2. The water and its shore replace the flat CastleGround slab.
	preview_basin = ShipWaterBasin.new()
	preview_basin.name = "ShipWaterBasin"
	add_child(preview_basin)
	var water_result: Dictionary = preview_basin.install(world, castle)
	if not bool(water_result.get("ok", false)):
		status = "water_failed:" + str(water_result.get("reason", "unknown"))
		return {"ok": false, "reason": status, "water": water_result}

	# 3. The hull: an AnimatableBody3D platform with buoyancy, sailing and flooding.
	preview_boat = ShipBoat.new()
	preview_boat.name = "ShipBoat"
	add_child(preview_boat)
	var boat_result: Dictionary = preview_boat.install(world, preview_basin, player, preview_model)
	if not bool(boat_result.get("ok", false)):
		status = "boat_failed:" + str(boat_result.get("reason", "unknown"))
		return {"ok": false, "reason": status, "boat": boat_result}
	preview_boat.moor(Vector3(SHIP_SPAWN.x, preview_basin.water_level(), SHIP_SPAWN.z),
		deg_to_rad(SHIP_YAW_DEG))
	# The boat owns its own motion loop; the host only sets sails and the rudder.
	if preview_boat.has_method("set_autopilot"):
		preview_boat.call("set_autopilot", true)
	if preview_boat.has_method("set_sails"):
		preview_boat.set_sails(false)

	# 4. Four broadside guns.
	preview_cannons = ShipCannons.new()
	preview_cannons.name = "ShipCannons"
	add_child(preview_cannons)
	var cannon_result: Dictionary = preview_cannons.install(world, preview_boat,
		preview_model, player, preview_basin)
	if not bool(cannon_result.get("ok", false)):
		status = "cannons_failed:" + str(cannon_result.get("reason", "unknown"))
		return {"ok": false, "reason": status, "cannons": cannon_result}

	# 4b. The identical target hulk for the live damage test.
	var target_script: Script = load("res://scripts/ship/ship_target.gd")
	if target_script != null:
		preview_target = target_script.new()
		preview_target.name = "TargetShipHost"
		add_child(preview_target)
		var target_result: Dictionary = preview_target.call("install", world, preview_basin, player,
			Vector3(TARGET_SPAWN.x, preview_basin.water_level(), TARGET_SPAWN.z),
			deg_to_rad(TARGET_YAW_DEG))
		if not bool(target_result.get("ok", false)):
			push_warning("SHIP63 target install: " + str(target_result))
			preview_target.queue_free()
			preview_target = null

	# 4c. The EXISTING powder barrels can be loaded onto the deck.
	var powder_script: Script = load("res://scripts/ship/ship_powder_loader.gd")
	if powder_script != null:
		preview_powder = powder_script.new()
		preview_powder.name = "ShipPowderLoader"
		add_child(preview_powder)
		var powder_result: Dictionary = preview_powder.call("install", world, preview_boat, player, preview_basin)
		if not bool(powder_result.get("ok", false)):
			push_warning("SHIP63 powder install: " + str(powder_result))
			preview_powder.queue_free()
			preview_powder = null

	# 4d. Iron balls lying next to the guns: E picks one into the muzzle.
	_build_deck_balls()

	# 5. The HUD (left panel + cannon sight + transient messages).
	preview_hud = ShipHud.new()
	preview_hud.name = "ShipHud"
	add_child(preview_hud)
	var hud_result: Dictionary = preview_hud.install(self)
	if not bool(hud_result.get("ok", true)):
		push_warning("SHIP61 hud install: " + str(hud_result))

	# 6. Put the player on the quarterdeck after the platform has settled: placing
	# him in the same frame as the mooring teleport made the platform velocity fling
	# the character a kilometre downrange.
	_sync_ball_stock()
	_seat_pending = 0 if OS.get_cmdline_user_args().has("--ship-no-seat=1") else 3
	basin = preview_basin
	model = preview_model
	boat = preview_boat
	cannons = preview_cannons
	hud = preview_hud
	target = preview_target
	powder = preview_powder
	# The castle's own startup guard would pull him back to the gate.
	world.set("_castle_spawn_frames", 0)
	process_physics_priority = 100
	_installed = true
	status = "ready"
	if preview_hud != null and preview_hud.has_method("message"):
		preview_hud.call("message", "Корабль «Мафиози» готов к бою", 4.0)
		if is_instance_valid(preview_target):
			preview_hud.call("message", "Учебная цель — на восток, правый борт", 4.0)
	var result := {
		"ok": true,
		"status": status,
		"water": water_result,
		"ship": boat_result,
		"cannons": cannon_result,
		"spawn": preview_boat.global_position,
		"deck": player.global_position,
	}
	print("DSH_SHIP ", JSON.stringify(result))
	return result


func _seat_on_deck() -> void:
	if not is_instance_valid(preview_boat) or not is_instance_valid(player):
		return
	var at: Vector3 = preview_boat.to_global(HELM_STAND)
	_place_player(at, 0.55)


func _place_player(world_position: Vector3, look_yaw: float) -> void:
	if not is_instance_valid(player):
		return
	player.global_position = world_position
	player.velocity = Vector3.ZERO
	player.set("_camera_yaw", look_yaw)
	player.set("_heading", look_yaw)
	var visual := player.get("_visual") as Node3D
	if is_instance_valid(visual):
		visual.rotation.y = look_yaw + deg_to_rad(float(player.get("visual_yaw_degrees")))
	if player.has_method("_update_camera_rotation"):
		player.call("_update_camera_rotation")


## ------------------------------------------------------------------ prompts
## Called by main.gd from its central prompt dispatcher. Returns
## {"owner":"ship","index":int,"label":String,"world":Vector3} or {}.
func action() -> Dictionary:
	if not _installed or not is_instance_valid(preview_boat) or not is_instance_valid(player):
		return {}
	if not _ship_usable():
		if _station != "":
			_leave_station()
		return {}
	_last_action = {}
	if _station == "" and preview_boat.has_method("boarding_ladder_at"):
		var local: Vector3 = preview_boat.to_local(player.global_position)
		if local.y < 1.35:
			var ladder: Dictionary = preview_boat.call("boarding_ladder_at", player.global_position)
			if not ladder.is_empty():
				return {"owner": "ship", "kind": "ship_board",
					"side": ladder.get("side", 1.0), "z": ladder.get("z", 0.0),
					"label": "Забраться на корабль",
					"world": preview_boat.to_global(Vector3(float(ladder.get("side", 1.0)) * 4.55, 1.2,
						float(ladder.get("z", 0.0))))}
	if _station == "helm":
		_last_action = {"owner": "ship", "kind": "ship_helm", "label": "Покинуть штурвал",
			"world": _helm_world() + Vector3.UP * 0.8}
		return _last_action
	if _station == "cannon" and preview_cannons != null and preview_cannons.has_method("station_world"):
		# No floating «Покинуть пушку» plaque: the cannon panel already says
		# "F — ВСТАТЬ/ПОКИНУТЬ".  F still leaves via _unhandled_input.
		_last_action = {}
		return _last_action

	var feet: Vector3 = player.global_position
	# A cabin exit is a hard escape hatch; nearby crates/boards must not steal F
	# from a player who is trying to get out of the deckhouse.
	var forced_cabin := _cabin_action()
	if str(forced_cabin.get("kind", "")) == "ship_cabin_exit":
		_last_action = forced_cabin
		return forced_cabin
	var best := {}
	var best_distance := 1e20
	# The helm.
	var helm_at := _helm_world()
	if feet.distance_to(helm_at) <= REACH:
		best = {"owner": "ship", "kind": "ship_helm", "label": "Встать за штурвал",
			"world": helm_at + Vector3.UP * 0.8}
		best_distance = feet.distance_to(helm_at)
	# The cabin doorway: the deckhouse is too low to walk in upright, so the
	# hatch interaction lowers/raises the captain instead of blocking him.
	var cabin_action := _cabin_action()
	if not cabin_action.is_empty():
		var cabin_at: Vector3 = cabin_action.get("world", feet)
		var cabin_distance := feet.distance_to(cabin_at)
		if cabin_distance <= REACH and cabin_distance < best_distance:
			best = cabin_action
			best_distance = cabin_distance
	# The four guns.  They are evaluated before the sail winch so standing at a
	# loaded gun cannot be stolen by the nearby lever.
	if preview_cannons != null and preview_cannons.has_method("mount_world"):
		for index in range(4):
			var mount: Vector3 = preview_cannons.call("mount_world", index)
			var distance := feet.distance_to(mount)
			if distance <= REACH and distance < best_distance:
				if is_instance_valid(_carried_ball_mesh) and _carried_ball_mesh.visible:
					best = {"owner": "ship", "kind": "ship_load_hint", "index": index,
						"label": "Зарядить пушку", "key": "E",
						"world": mount + Vector3.UP * 0.9}
				elif preview_cannons.has_method("loaded_at") \
						and bool(preview_cannons.call("loaded_at", index)):
					best = {"owner": "ship", "kind": "ship_cannon", "index": index,
						"label": "Встать за пушку", "world": mount + Vector3.UP * 0.9}
				else:
					continue
				best_distance = distance
	# The sail winch at the mast.  It only wins when it is actually the nearest
	# interaction, so the gun prompt keeps priority at the gun.
	var lever_at := _lever_world()
	if _lever_near() and not (preview_boat.has_method("mast_broken") \
			and bool(preview_boat.call("mast_broken"))):
		if not lever_at.is_zero_approx():
			var distance := feet.distance_to(lever_at)
			if distance < best_distance:
				var open := _sails_open()
				best = {"owner": "ship", "kind": "ship_sail",
					"label": "Свернуть паруса" if open else "Раскрыть паруса",
					"world": lever_at + Vector3.UP * 0.7}
				best_distance = distance
	# The two crates in the cabin.  The ammo crate keeps its prompt, but the
	# prompt shows E and the actual pickup is handled on E only.
	var deck_ball_hint := _nearest_deck_ball()
	if deck_ball_hint != null and not (is_instance_valid(_carried_ball_mesh) \
			and _carried_ball_mesh.visible):
		var ball_distance := feet.distance_to(deck_ball_hint.global_position)
		if best.is_empty() or ball_distance < best_distance:
			return {"owner": "ship", "kind": "ship_deck_ball", "label": "Взять ядро",
				"key": "E", "world": deck_ball_hint.global_position + Vector3.UP * 0.6}
	var ammo_at := _crate_world("ammo")
	if _near_ammo_crate() and _cabin_action().is_empty() and balls > 0 \
			and not (is_instance_valid(_carried_ball_mesh) and _carried_ball_mesh.visible):
		return {"owner": "ship", "kind": "ship_ammo_hint", "label": "Взять ядро",
			"key": "E", "world": ammo_at + Vector3.UP * 0.7}
	var boards_at := _crate_world("boards")
	if not boards_at.is_zero_approx() and feet.distance_to(boards_at) <= REACH:
		var distance := feet.distance_to(boards_at)
		if distance < best_distance:
			best = {"owner": "ship", "kind": "ship_boards",
				"label": "Взять доски (%d)" % CRATE_BOARDS,
				"world": boards_at + Vector3.UP * 0.5}
			best_distance = distance
	# A hole within arm's reach: patch it with a board.
	if preview_boat != null and preview_boat.has_method("nearest_hole_world") and boards > 0:
		var hole: Vector3 = preview_boat.call("nearest_hole_world", feet, REPAIR_REACH)
		if not hole.is_zero_approx():
			var distance := feet.distance_to(hole)
			if distance < best_distance:
				best = {"owner": "ship", "kind": "ship_repair",
					"label": "Заделать пробоину (доски: %d)" % boards,
					"world": hole + Vector3.UP * 0.4}
				best_distance = distance
	# Powder barrels on the deck: loading, unloading, a barrel in reach.
	if is_instance_valid(preview_powder) and preview_powder.has_method("action"):
		var powder_action: Dictionary = preview_powder.call("action")
		if not powder_action.is_empty():
			var powder_at: Vector3 = powder_action.get("world", Vector3.ZERO)
			var powder_distance := feet.distance_to(powder_at)
			if powder_distance < best_distance:
				best = powder_action
				best_distance = powder_distance
	_last_action = best
	return best


## main.gd calls this with the dictionary returned by action().
func interact(action_data: Variant) -> bool:
	if not _installed:
		return false
	if not _ship_usable():
		_message("Корабль затонул — управление недоступно", 2.2)
		return false
	var kind := ""
	var index := -1
	if action_data is Dictionary:
		kind = str(action_data.get("kind", ""))
		index = int(action_data.get("index", -1))
	else:
		kind = str(action_data)
	if kind == "powder" or (action_data is Dictionary and str(action_data.get("owner", "")) == "powder"):
		if is_instance_valid(preview_powder) and preview_powder.has_method("interact"):
			var powder_ok := bool(preview_powder.call("interact", action_data))
			if powder_ok and preview_powder.has_method("last_notice"):
				var notice := str(preview_powder.call("last_notice"))
				if not notice.is_empty():
					_message(notice, 2.6)
			return powder_ok
		return false
	match kind:
		"ship_board":
			var side := float(action_data.get("side", 1.0))
			var z := float(action_data.get("z", 4.2))
			player.global_position = preview_boat.to_global(Vector3(side * 3.15, 1.88, z))
			player.velocity = Vector3.ZERO
			if player.has_method("set_swimming"):
				player.call("set_swimming", false)
			return true
		"ship_helm":
			_toggle_helm()
			return true
		"ship_sail":
			_toggle_sails()
			return true
		"ship_cabin_enter":
			_enter_cabin()
			return true
		"ship_cabin_exit":
			_exit_cabin()
			return true
		"ship_cannon":
			_toggle_cannon(index)
			return true
		"ship_ammo":
			_take_from_crate("ammo")
			return true
		"ship_boards":
			_take_from_crate("boards")
			return true
		"ship_repair":
			return _repair_hull()
	return false


func _toggle_helm() -> void:
	if not _ship_usable():
		if _station != "":
			_leave_station()
		_message("Корабль затонул — штурвал не слушается", 2.2)
		return
	if _station == "helm":
		_leave_station()
		return
	if preview_boat == null or not preview_boat.has_method("steer"):
		return
	if preview_cannons != null and preview_cannons.has_method("leave"):
		preview_cannons.call("leave")
	_station = "helm"
	_cannon_index = -1
	_hold_player(true)
	# The player stands just behind the wheel, facing the bow.
	var stand: Vector3 = preview_boat.to_global(HELM_STAND)
	_place_player(stand, _ship_yaw())
	_message("Вы за штурвалом. A/D — руль, F — покинуть", 3.0)
	_update_hud(true)


func _cabin_action() -> Dictionary:
	if _station != "" or not is_instance_valid(preview_boat) or not is_instance_valid(player):
		return {}
	var local: Vector3 = preview_boat.to_local(player.global_position)
	# Anywhere inside the cabin: F lifts the captain out, even if a seam
	# blocks the stairs.  The walk-up route is fixed in ship_boat too.
	if local.y < 1.35 and local.z > 6.00 and local.z < 12.40 and absf(local.x) < 3.30:
		return {"owner": "ship", "kind": "ship_cabin_exit", "label": "Подняться на палубу",
			"world": preview_boat.to_global(Vector3(0.0, 2.65, 6.65))}
	if absf(local.x) > 1.40 or local.z < 5.35 or local.z > 7.20:
		return {}
	if local.y > 1.15:
		return {"owner": "ship", "kind": "ship_cabin_enter", "label": "Спуститься в каюту",
			"world": preview_boat.to_global(Vector3(0.0, 1.90, 6.15))}
	if local.z > 5.70:
		return {"owner": "ship", "kind": "ship_cabin_exit", "label": "Подняться на палубу",
			"world": preview_boat.to_global(Vector3(0.0, 1.10, 6.55))}
	return {}


func _enter_cabin() -> void:
	_place_player(preview_boat.to_global(Vector3(0.0, 0.78, 7.10)), _ship_yaw())
	_message("Спустились в каюту. F у двери — подняться", 2.6)


func _exit_cabin() -> void:
	_place_player(preview_boat.to_global(Vector3(0.0, 2.65, 6.65)), _ship_yaw())
	_message("Поднялись на палубу", 2.0)


func _toggle_sails() -> void:
	if not _ship_usable():
		_message("Корабль затонул — паруса не поднять", 2.2)
		return
	if preview_boat.has_method("mast_broken") and bool(preview_boat.call("mast_broken")):
		_message("Мачта сломана — паруса не действуют", 2.4)
		return
	if preview_boat == null or not preview_boat.has_method("toggle_sails"):
		return
	var open: bool = bool(preview_boat.call("toggle_sails"))
	_message("Паруса раскрыты — полный вперёд" if open else "Паруса свёрнуты — корабль останавливается", 2.8)
	_update_hud(true)


func _toggle_cannon(index: int) -> void:
	if preview_cannons == null:
		return
	if not _ship_usable():
		_message("Корабль затонул — пушки мертвы", 2.2)
		return
	if index < 0:
		index = _nearest_cannon_index()
	if _station == "cannon" and _cannon_index == index:
		_leave_station()
		return
	if preview_cannons.has_method("loaded_at") and not bool(preview_cannons.call("loaded_at", index)):
		_message("Сначала заряди пушку: E с ядром в руках", 2.2)
		return
	if preview_boat != null and preview_boat.has_method("steer"):
		preview_boat.call("steer", 0.0)
	_station = "cannon"
	_cannon_index = maxi(0, index)
	# The gun itself must be manned: loading and firing are refused otherwise.
	if preview_cannons.has_method("man"):
		preview_cannons.call("man", _cannon_index)
	_hold_player(true)
	var station: Vector3 = preview_cannons.call("station_world", _cannon_index)
	var look := _cannon_look_yaw(_cannon_index)
	_place_player(station, look)
	# A gun is served from inside the ship: the long third-person boom ends up
	# inside the hull, so the view moves to the gunner's eye while he is mounted.
	_set_cannon_camera(true)
	_message("Пушка %d. A/D — поворот, W/S — угол, E — зарядить, ЛКМ — выстрел" % (_cannon_index + 1), 3.4)
	_update_hud(true)


func _nearest_cannon_index() -> int:
	if preview_cannons == null or not preview_cannons.has_method("mount_world") or not is_instance_valid(player):
		return 0
	var best := 0
	var best_distance := INF
	for index in range(4):
		var mount: Vector3 = preview_cannons.call("mount_world", index)
		var distance := player.global_position.distance_to(mount)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _cannon_look_yaw(index: int) -> float:
	if preview_cannons == null or not preview_cannons.has_method("mount_world") or not is_instance_valid(preview_boat):
		return _ship_yaw()
	var mount: Vector3 = preview_cannons.call("mount_world", index)
	var outward := mount - preview_boat.global_position
	outward.y = 0.0
	if outward.length_squared() < 0.01:
		return _ship_yaw()
	outward = outward.normalized()
	return atan2(-outward.x, -outward.z)


func _leave_station() -> void:
	if _station == "":
		return
	if _station == "cannon" and preview_cannons != null and preview_cannons.has_method("leave"):
		preview_cannons.call("leave")
	_set_cannon_camera(false)
	if _station == "helm" and preview_boat != null and preview_boat.has_method("steer"):
		preview_boat.call("steer", 0.0)
	_station = ""
	_cannon_index = -1
	_aim_left = false
	_aim_right = false
	_aim_up = false
	_aim_down = false
	_fire_queued = false
	_hold_player(false)
	_restore_weapon_after_station()
	_update_hud(true)


func _restore_weapon_after_station() -> void:
	if not is_instance_valid(world):
		return
	var weapons: Variant = world.get("preview_weapons")
	if not is_instance_valid(weapons) or not (weapons is Node):
		return
	var node := weapons as Node
	# A barrel/stone carry makes the weapon host ignore Q entirely.  Release it
	# when the player leaves the gun, then put the sword back if hands are empty.
	if node.has_method("end_catapult_stone_carry"):
		node.call("end_catapult_stone_carry")
	if node.has_method("snapshot"):
		var state: Dictionary = node.call("snapshot")
		if str(state.get("weaponId", "none")) == "none" and node.has_method("equip"):
			node.call("equip", "sword")


func _set_held_weapon_visible(visible_now: bool) -> void:
	if not is_instance_valid(world):
		return
	var weapons: Variant = world.get("preview_weapons")
	if not is_instance_valid(weapons) or not (weapons is Node):
		return
	var node := weapons as Node
	var presentation: Variant = node.get("presentation")
	if is_instance_valid(presentation) and presentation.has_method("invalidate_pose"):
		if not visible_now:
			presentation.call("invalidate_pose")
	if visible_now:
		if node.has_method("end_catapult_stone_carry"):
			node.call("end_catapult_stone_carry")
	else:
		if node.has_method("begin_catapult_stone_carry"):
			node.call("begin_catapult_stone_carry")
		if is_instance_valid(presentation) and presentation.has_method("invalidate_pose"):
			presentation.call("invalidate_pose")


func _set_cannon_camera(on: bool) -> void:
	if on == _cannon_camera_on:
		return
	_cannon_camera_on = on
	if not is_instance_valid(player):
		return
	var visual := player.get("_visual") as Node3D
	var player_camera := player.get("_camera") as Camera3D
	if on:
		if is_instance_valid(visual):
			visual.visible = false
		_set_held_weapon_visible(false)
		if not is_instance_valid(_gun_camera):
			_gun_camera = Camera3D.new()
			_gun_camera.name = "ShipGunCamera"
			_gun_camera.fov = 70.0
			_gun_camera.near = 0.05
			_gun_camera.far = 500.0
			add_child(_gun_camera)
		_gun_camera.current = true
	else:
		_set_held_weapon_visible(true)
		if is_instance_valid(visual):
			visual.visible = true
		if is_instance_valid(_gun_camera):
			_gun_camera.current = false
		if is_instance_valid(player_camera):
			player_camera.current = true


## A gunner looks straight down his own barrel: the camera follows the aimed
## muzzle, so the HUD crosshair is where the ball will go.
func _update_gun_camera() -> void:
	if not _cannon_camera_on or not is_instance_valid(_gun_camera) or preview_cannons == null:
		return
	var mount: Vector3 = preview_cannons.call("mount_world", _cannon_index)
	var muzzle: Vector3 = mount
	if preview_cannons.has_method("_muzzle_world"):
		var value: Variant = preview_cannons.call("_muzzle_world", _cannon_index)
		if value is Vector3:
			muzzle = value
	var direction := muzzle - mount
	if direction.length_squared() < 0.04 and is_instance_valid(preview_boat):
		direction = mount - preview_boat.global_position
	direction = direction.normalized()
	# First-person gunner: use the cannon's own outward firing direction (the
	# muzzle-mount vector points inboard on the port battery).  Camera sits
	# behind the breech and above the barrel, looking over it at the target.
	var forward := direction
	if preview_cannons.has_method("state"):
		var gun_state: Dictionary = preview_cannons.call("state")
		var state_dir: Variant = gun_state.get("direction", null)
		if state_dir is Vector3 and (state_dir as Vector3).length_squared() > 0.01:
			forward = (state_dir as Vector3).normalized()
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = direction
	forward = forward.normalized()
	var eye := mount - forward * 2.35 + Vector3.UP * 1.35
	_gun_camera.global_position = eye
	var look := muzzle + forward * 35.0 + Vector3.UP * 0.10
	_gun_camera.look_at(look, Vector3.UP)


func _hold_player(hold: bool) -> void:
	if not is_instance_valid(player):
		return
	if _hold_owned == hold:
		return
	_hold_owned = hold
	if player.has_method("set_vehicle_hold"):
		player.call("set_vehicle_hold", hold)
	if player.has_method("set_station_hold"):
		player.call("set_station_hold", hold)
	if not hold:
		player.velocity = Vector3.ZERO


func _take_from_crate(kind: String) -> void:
	if _crate_timer > 0.0:
		_message("Ящик ещё открыт", 1.0)
		return
	_crate_timer = CRATE_COOLDOWN
	if kind == "ammo":
		if balls <= 0:
			_message("В ящике не осталось ядер", 1.6)
			return
		if is_instance_valid(_carried_ball_mesh) and _carried_ball_mesh.visible:
			_message("Ядро уже в руках — заряди его в пушку", 1.8)
			return
		balls -= 1
		_sync_ball_stock()
		_set_carry_ball(true)
		_message("Взял ядро (1) — неси к пушке, E — зарядить", 2.8)
	else:
		var space := MAX_BOARDS - boards
		var taken := mini(CRATE_BOARDS, space)
		if taken <= 0:
			_message("Досок больше не унести", 1.6)
			return
		boards += taken
		_message("Взято досок: %d (всего %d)" % [taken, boards], 2.2)
	_update_hud(true)


func _repair_hull() -> bool:
	if boards <= 0:
		_message("Нет досок — возьмите в каюте", 2.0)
		return false
	if preview_boat == null or not preview_boat.has_method("nearest_hole_world"):
		return false
	var hole: Vector3 = preview_boat.call("nearest_hole_world", player.global_position, REPAIR_REACH)
	if hole.is_zero_approx():
		return false
	if bool(preview_boat.call("repair_at", hole)):
		boards -= 1
		_message("Пробоина заделана. Осталось досок: %d" % boards, 2.2)
		_update_hud(true)
		return true
	return false


## ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	# Keyboard-layout independent station input.  Raw `is_key_pressed(KEY_A)` is
	# dead on a Cyrillic layout, which is exactly why the gun would not traverse.
	if not _installed or _station != "cannon":
		return
	if event is InputEventMouseMotion and Input.is_physical_key_pressed(KEY_E):
		# Holding E aims the gun with the mouse; the barrel itself is the sight.
		var motion := event as InputEventMouseMotion
		preview_cannons.call("aim", motion.relative.x * 0.0018, -motion.relative.y * 0.0012)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or event.echo:
		return
	var key := event as InputEventKey
	var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	var pressed := key.pressed
	match code:
		KEY_A, KEY_LEFT:
			_aim_left = pressed
		KEY_D, KEY_RIGHT:
			_aim_right = pressed
		KEY_W, KEY_UP:
			_aim_up = pressed
		KEY_S, KEY_DOWN:
			_aim_down = pressed
		KEY_F:
			if pressed:
				_leave_station()
				get_viewport().set_input_as_handled()
		KEY_E, KEY_R:
			if pressed:
				_load_manning_cannon()
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _installed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _station == "cannon" and preview_cannons != null and preview_cannons.has_method("manning") \
				and bool(preview_cannons.call("manning")):
			_fire_manning_cannon()
			get_viewport().set_input_as_handled()
			return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var water_key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if _station == "" and water_key == KEY_G and is_instance_valid(_carried_ball_mesh) \
			and _carried_ball_mesh.visible:
		_drop_carried_ball()
		get_viewport().set_input_as_handled()
		return
	if _station == "" and water_key == KEY_E and not (is_instance_valid(_carried_ball_mesh) \
			and _carried_ball_mesh.visible):
		var deck_ball := _nearest_deck_ball()
		if deck_ball != null and _pickup_deck_ball(deck_ball):
			get_viewport().set_input_as_handled()
			return
	if _station == "" and water_key == KEY_E and is_instance_valid(_carried_ball_mesh) \
			and _carried_ball_mesh.visible:
		var near_gun := _nearest_cannon_index()
		if near_gun >= 0 and _load_cannon_at(near_gun):
			get_viewport().set_input_as_handled()
			return
	if _station == "" and water_key == KEY_E and is_instance_valid(_dropped_ball):
		if _pickup_dropped_ball():
			get_viewport().set_input_as_handled()
			return
	if _station == "" and water_key == KEY_E and _near_ammo_crate():
		_take_from_crate("ammo")
		get_viewport().set_input_as_handled()
		return
	if _station == "" and water_key == KEY_E and is_instance_valid(preview_powder) \
			and preview_powder.has_method("pick_up_nearest"):
		if bool(preview_powder.call("pick_up_nearest")):
			get_viewport().set_input_as_handled()
			return
	if _station == "cannon" and (event.keycode == KEY_R or event.physical_keycode == KEY_R):
		_load_manning_cannon()
		get_viewport().set_input_as_handled()
		return
	if _station == "cannon" and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
		_load_manning_cannon()
		get_viewport().set_input_as_handled()
		return
	if _station == "cannon" and (event.keycode == KEY_F or event.physical_keycode == KEY_F):
		_leave_station()
		get_viewport().set_input_as_handled()
		return
	if _station == "helm" and (event.keycode == KEY_F or event.physical_keycode == KEY_F):
		_leave_station()
		get_viewport().set_input_as_handled()
		return


func _fire_manning_cannon() -> void:
	if preview_cannons == null:
		return
	if not _ship_usable():
		_message("Корабль затонул — стрелять некому", 2.0)
		return
	if not bool(preview_cannons.call("loaded")):
		_message("Пушка не заряжена — возьми ядро из ящика и нажми E", 2.2)
		return
	var shot: Dictionary = preview_cannons.call("fire")
	if bool(shot.get("ok", false)):
		_fire_queued = false
		_message("Выстрел!", 1.4)
	else:
		_message("Осечка", 1.4)


func _load_cannon_at(index: int) -> bool:
	if preview_cannons == null or not preview_cannons.has_method("load_at"):
		return false
	if index < 0 or not (is_instance_valid(_carried_ball_mesh) and _carried_ball_mesh.visible):
		return false
	if preview_cannons.has_method("mount_world"):
		var mount: Vector3 = preview_cannons.call("mount_world", index)
		if player.global_position.distance_to(mount) > 3.0:
			return false
	if not bool(preview_cannons.call("load_at", index)):
		_message("Пушка уже заряжена", 1.4)
		return false
	_set_carry_ball(false)
	_message("Ядро заряжено — теперь F, чтобы встать за пушку", 2.4)
	return true


func _load_manning_cannon() -> void:
	if preview_cannons == null:
		return
	if not _ship_usable():
		_message("Корабль затонул — пушки мертвы", 2.0)
		return
	if bool(preview_cannons.call("loaded")):
		_message("Уже заряжено", 1.2)
		return
	if preview_cannons.has_method("state"):
		var gun_state: Dictionary = preview_cannons.call("state")
		if bool(gun_state.get("loading", false)):
			_message("Идёт заряжание", 1.2)
			return
	if not (is_instance_valid(_carried_ball_mesh) and _carried_ball_mesh.visible):
		_message("Сначала возьми ядро из ящика (F)", 2.2)
		return
	# The ball left the crate when it was picked up; loading only consumes the
	# carried prop, not a second inventory count.
	_sync_ball_stock()
	var started := true
	if preview_cannons.has_method("load_ball"):
		started = bool(preview_cannons.call("load_ball"))
	if not started:
		_message("Не удалось зарядить", 1.6)
		return
	_set_carry_ball(false)
	_sync_ball_props()
	if _cannon_index >= 0 and _cannon_index < _ball_props.size() and is_instance_valid(_ball_props[_cannon_index]):
		_ball_props[_cannon_index].visible = false
	_message("Ядро загружено. Осталось ядер: %d" % balls, 2.0)
	_update_hud(true)


func _sync_ball_stock() -> void:
	if preview_cannons != null and preview_cannons.has_method("set_ball_stock"):
		preview_cannons.call("set_ball_stock", balls)
	_sync_ball_props()


## One iron ball on the deck beside each gun.  E feeds it into the muzzle; the
## prop disappears with the shot, so the gun visibly eats the ball.
func _set_carry_ball(on: bool) -> void:
	var weapons: Variant = world.get("preview_weapons") if is_instance_valid(world) else null
	if not on:
		if is_instance_valid(_carried_ball_mesh):
			_carried_ball_mesh.visible = false
		if is_instance_valid(weapons) and (weapons as Node).has_method("end_catapult_stone_carry"):
			(weapons as Node).call("end_catapult_stone_carry")
		return
	if not is_instance_valid(player):
		return
	if is_instance_valid(weapons) and (weapons as Node).has_method("begin_catapult_stone_carry"):
		(weapons as Node).call("begin_catapult_stone_carry")
	if not is_instance_valid(_carried_ball_mesh):
		var visual := player.get("_visual") as Node3D
		if not is_instance_valid(visual):
			return
		var mesh := SphereMesh.new()
		mesh.radius = 0.17
		mesh.height = 0.34
		mesh.radial_segments = 12
		mesh.rings = 6
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.10, 0.10, 0.12)
		material.metallic = 0.55
		material.roughness = 0.45
		mesh.material = material
		_carried_ball_mesh = MeshInstance3D.new()
		_carried_ball_mesh.name = "CarriedCannonball"
		_carried_ball_mesh.mesh = mesh
		_carried_ball_mesh.position = Vector3(0.0, 1.12, 0.48)
		visual.add_child(_carried_ball_mesh)
	_carried_ball_mesh.visible = true
	_carry_phase = 0.0


func _update_carried_ball(delta: float) -> void:
	if not is_instance_valid(_carried_ball_mesh) or not _carried_ball_mesh.visible:
		return
	_carry_phase += delta * 4.0
	_carried_ball_mesh.position = Vector3(0.0, 1.12 + sin(_carry_phase) * 0.035, 0.48)
	_carried_ball_mesh.rotation.z = sin(_carry_phase * 0.6) * 0.10


func _near_ammo_crate() -> bool:
	if not is_instance_valid(player) or not is_instance_valid(preview_boat):
		return false
	# The crate is inside the cabin.  Standing on the helm deck above it must
	# not let the player take a ball through the cabin ceiling/wall.
	var local: Vector3 = preview_boat.to_local(player.global_position)
	if local.y > 1.35:
		return false
	var at := _crate_world("ammo")
	return not at.is_zero_approx() and player.global_position.distance_to(at) <= REACH


func _drop_carried_ball() -> void:
	if not (is_instance_valid(_carried_ball_mesh) and _carried_ball_mesh.visible):
		return
	_set_carry_ball(false)
	if is_instance_valid(_dropped_ball):
		_dropped_ball.queue_free()
	var body := RigidBody3D.new()
	body.name = "DroppedCannonball"
	body.mass = 8.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.24
	mesh.height = 0.48
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.10, 0.12)
	mat.metallic = 0.65
	mat.roughness = 0.38
	mi.material_override = mat
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.24
	shape.shape = sphere
	body.add_child(shape)
	if is_instance_valid(preview_boat):
		preview_boat.add_child(body)
		body.global_position = player.global_position + Vector3.UP * 0.35
	else:
		add_child(body)
		body.global_position = player.global_position + Vector3.UP * 0.35
	_dropped_ball = body
	_message("Ядро сброшено (E — поднять)", 2.0)


func _pickup_dropped_ball() -> bool:
	if not is_instance_valid(_dropped_ball) or not is_instance_valid(player):
		return false
	if player.global_position.distance_to(_dropped_ball.global_position) > 2.4:
		return false
	_dropped_ball.queue_free()
	_dropped_ball = null
	_set_carry_ball(true)
	_message("Поднял ядро", 1.4)
	return true


func _build_deck_balls() -> void:
	_ball_props.clear()
	_deck_balls.clear()
	if not is_instance_valid(preview_boat) or preview_cannons == null:
		return
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.20
	ball_mesh.height = 0.40
	ball_mesh.radial_segments = 12
	ball_mesh.rings = 6
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color(0.10, 0.10, 0.12)
	ball_mat.metallic = 0.65
	ball_mat.roughness = 0.38
	for index in range(4):
		var mount: Vector3 = preview_cannons.call("mount_world", index)
		var local := preview_boat.to_local(mount)
		var side := 1.0 if local.x >= 0.0 else -1.0
		var ball := MeshInstance3D.new()
		ball.name = "DeckBall%d" % index
		ball.mesh = ball_mesh
		ball.material_override = ball_mat
		ball.position = Vector3(side * 2.15, 1.99, local.z - 0.35)
		preview_boat.add_child(ball)
		_deck_balls.append(ball)


func _nearest_deck_ball() -> Node3D:
	if not is_instance_valid(player):
		return null
	var best: Node3D = null
	var best_d := 2.2
	for ball: Node3D in _deck_balls:
		if not is_instance_valid(ball) or not ball.visible:
			continue
		var d: float = player.global_position.distance_to(ball.global_position)
		if d < best_d:
			best = ball
			best_d = d
	return best


func _pickup_deck_ball(ball: Node3D) -> bool:
	if not is_instance_valid(ball) or not is_instance_valid(player):
		return false
	if player.global_position.distance_to(ball.global_position) > 2.2:
		return false
	ball.queue_free()
	_set_carry_ball(true)
	_message("Взял ядро — E у пушки зарядить", 1.8)
	return true


func _sync_ball_props() -> void:
	var loaded := false
	var loading := false
	if preview_cannons != null and preview_cannons.has_method("state"):
		var state: Dictionary = preview_cannons.call("state")
		loaded = bool(state.get("loaded", false))
		loading = bool(state.get("loading", false))
	for index in range(_ball_props.size()):
		var ball := _ball_props[index]
		if not is_instance_valid(ball):
			continue
		var eaten := index == _cannon_index and (loaded or loading)
		ball.visible = balls > index and not eaten


## ------------------------------------------------------------------ frame loop
func _physics_process(delta: float) -> void:
	if not _installed or not is_instance_valid(player):
		return
	# Clear a stale hold left by an interrupted station/vehicle.  This runs only
	# while the flag is actually set, so it cannot freeze normal walking.
	if _station == "" and bool(player.get("_vehicle_hold")):
		var balloon: Variant = world.get("preview_balloon") if is_instance_valid(world) else null
		if not (is_instance_valid(balloon) and bool(balloon.get("_aboard"))):
			if player.has_method("set_vehicle_hold"):
				player.call("set_vehicle_hold", false)
			if player.has_method("set_station_hold"):
				player.call("set_station_hold", false)
	if _seat_pending > 0:
		_seat_pending -= 1
		if _seat_pending == 0:
			_seat_on_deck()
	# SHIP63: a dead gunner must never stay welded to his station.
	if _station != "" and (bool(world.get("preview_dead")) or bool(world.get("preview_physics_fault"))):
		_seat_pending = 0
		_leave_station()
		_message("Вас убили — место покинуто", 2.4)
	# A fall through a deck opening must not leave the player in the water under
	# a moving hull: pull him back onto the main deck, inside the ship.
	if _station == "" and not bool(world.get("preview_dead")) and not bool(world.get("preview_physics_fault")):
		_recover_underdeck()
	_update_swimming(delta)
	if is_instance_valid(preview_boat):
		var broken: Variant = preview_boat.get("_broken_parts")
		if broken is Array:
			var count := (broken as Array).size()
			if count > _last_broken_count:
				_last_broken_count = count
				var has_mast := (broken as Array).has("mast")
				_message("Мачта сломана — паруса мертвы" if has_mast else "Часть корабля разрушена!", 1.8)
	_update_carried_ball(delta)
	_crate_timer = maxf(0.0, _crate_timer - delta)
	_wake_timer = maxf(0.0, _wake_timer - delta)
	_water_time += delta
	if _station == "helm" and is_instance_valid(preview_boat):
		var stand: Vector3 = preview_boat.to_global(HELM_STAND)
		player.global_position = stand
		player.velocity = Vector3.ZERO
		var axis := 0.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			axis -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			axis += 1.0
		preview_boat.call("steer", axis)
	elif _station == "cannon" and preview_cannons != null:
		var station: Vector3 = preview_cannons.call("station_world", _cannon_index)
		player.global_position = station
		player.velocity = Vector3.ZERO
		var turn := 0.0
		var elevate := 0.0
		if _aim_left:
			turn -= 1.0
		if _aim_right:
			turn += 1.0
		if _aim_up:
			elevate += 1.0
		if _aim_down:
			elevate -= 1.0
		if turn == 0.0:
			if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
				turn -= 1.0
			if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
				turn += 1.0
		if elevate == 0.0:
			if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
				elevate += 1.0
			if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
				elevate -= 1.0
		if turn != 0.0 or elevate != 0.0:
			preview_cannons.call("aim", turn * 0.9 * delta, elevate * 0.55 * delta)
		_update_gun_camera()
		if _fire_queued and preview_cannons != null and bool(preview_cannons.call("loaded")):
			_fire_manning_cannon()
	elif is_instance_valid(preview_boat) and preview_boat.has_method("climb_assist"):
		preview_boat.call("climb_assist", player, delta)

	if is_instance_valid(preview_boat):
		if preview_boat.has_method("is_sunk") and bool(preview_boat.call("is_sunk")):
			_on_ship_sunk()
		else:
			_wake(delta)
	# Falling overboard: the harbour is deep and the player is not a fish.
	if player.global_position.y < _water_level() - 0.9 and _station == "":
		if is_instance_valid(preview_boat) and player.global_position.distance_to(preview_boat.global_position) > 9.0:
			_rescue_player()
	_hud_timer -= delta
	_aboard_timer -= delta
	if _aboard_timer <= 0.0:
		_aboard_timer = 0.4
		_update_weapon_hud()
	if _hud_timer <= 0.0:
		_hud_timer = 0.12
		_update_hud(false)


func _process(_delta: float) -> void:
	pass


func _update_weapon_hud() -> void:
	# SHIP77: do not hide the arsenal bar while aboard.  It used to vanish as
	# soon as the player stepped on the ship, so Q opened an invisible menu and
	# no weapon could be selected.  The ship card sits left, the weapon bar
	# bottom-right; both fit together.
	if not is_instance_valid(_weapon_hud):
		var weapons: Variant = world.get("preview_weapons") if is_instance_valid(world) else null
		if weapons is Node:
			_weapon_hud = (weapons as Node).get("_walk_ui") as Control
		if not is_instance_valid(_weapon_hud):
			return
	_weapon_hud_hidden = false
	_weapon_hud.visible = true


func _wake(_delta: float) -> void:
	if _wake_timer > 0.0:
		return
	_wake_timer = 0.35
	if preview_boat == null or preview_basin == null or not preview_basin.has_method("add_ripple"):
		return
	var speed := 0.0
	if preview_boat.has_method("speed"):
		speed = float(preview_boat.call("speed"))
	if speed < 0.6:
		return
	var stern: Vector3 = preview_boat.to_global(Vector3(0.0, 0.0, 12.0))
	var bow: Vector3 = preview_boat.to_global(Vector3(0.0, 0.0, -12.0))
	preview_basin.call("add_ripple", stern, 1.0)
	preview_basin.call("add_ripple", bow, 0.55)


func _on_ship_sunk() -> void:
	if _sunk_announced:
		return
	_sunk_announced = true
	_leave_station()
	if preview_boat.has_method("set_sails"):
		preview_boat.call("set_sails", false)
	if preview_boat.has_method("steer"):
		preview_boat.call("steer", 0.0)
	_message("Корабль тонет! Команда покидает борт", 4.0)
	_rescue_player()
	_update_hud(true)


func _rescue_player() -> void:
	if preview_basin == null or not preview_basin.has_method("shore_respawn"):
		return
	var shore: Vector3 = preview_basin.call("shore_respawn", player.global_position)
	player.global_position = shore
	player.velocity = Vector3.ZERO
	_message("Вас выбросило на берег", 2.4)


## ------------------------------------------------------------------ helpers
func _water_level() -> float:
	if preview_basin != null and preview_basin.has_method("water_level"):
		return float(preview_basin.call("water_level"))
	return -0.55


func _ship_yaw() -> float:
	if preview_boat == null:
		return 0.0
	return preview_boat.global_rotation.y


func _sails_open() -> bool:
	if preview_boat != null and preview_boat.has_method("sails_open"):
		return bool(preview_boat.call("sails_open"))
	return false


func _helm_world() -> Vector3:
	if preview_model != null and preview_model.has_method("anchors"):
		var anchors: Dictionary = preview_model.call("anchors")
		var helm: Dictionary = anchors.get("helm", {})
		var node: Node3D = helm.get("node")
		if is_instance_valid(node):
			return node.global_position
	return preview_boat.global_position if is_instance_valid(preview_boat) else Vector3.ZERO


func _lever_near() -> bool:
	if not is_instance_valid(player):
		return false
	var lever := _lever_world()
	if lever.is_zero_approx():
		return false
	var flat := Vector2(player.global_position.x - lever.x, player.global_position.z - lever.z).length()
	return flat <= 2.8 and absf(player.global_position.y - lever.y) <= 3.2


func _lever_world() -> Vector3:
	if preview_model != null and preview_model.has_method("anchors"):
		var anchors: Dictionary = preview_model.call("anchors")
		var lever: Dictionary = anchors.get("sail_lever", {})
		var node: Node3D = lever.get("node")
		if is_instance_valid(node):
			return node.global_position
	return Vector3.ZERO


func _crate_world(kind: String) -> Vector3:
	if preview_model == null or not preview_model.has_method("anchors"):
		return Vector3.ZERO
	var anchors: Dictionary = preview_model.call("anchors")
	var crates: Dictionary = anchors.get("crates", {})
	var crate: Dictionary = crates.get(kind, {})
	var node: Node3D = crate.get("node")
	if is_instance_valid(node):
		return node.global_position
	return Vector3.ZERO


func _message(text: String, seconds: float = 2.6) -> void:
	if preview_hud != null and preview_hud.has_method("message"):
		preview_hud.call("message", text, seconds)


func _update_hud(force: bool) -> void:
	if preview_hud == null or not preview_hud.has_method("update_state"):
		return
	var state := snapshot()
	preview_hud.call("update_state", state)
	if _station == "cannon" and preview_hud.has_method("set_cannon") and preview_cannons != null:
		preview_hud.call("set_cannon", preview_cannons.call("state"))
	elif preview_hud.has_method("set_cannon"):
		preview_hud.call("set_cannon", {})


func snapshot() -> Dictionary:
	var ship_state: Dictionary = {}
	if preview_boat != null and preview_boat.has_method("snapshot"):
		ship_state = preview_boat.call("snapshot")
	var water_state: Dictionary = {}
	if preview_basin != null and preview_basin.has_method("snapshot"):
		water_state = preview_basin.call("snapshot")
	var cannon_state: Dictionary = {}
	if preview_cannons != null and preview_cannons.has_method("snapshot"):
		cannon_state = preview_cannons.call("snapshot")
	var target_state: Dictionary = {}
	if is_instance_valid(preview_target) and preview_target.has_method("snapshot"):
		target_state = preview_target.call("snapshot")
	var powder_state: Dictionary = {}
	if is_instance_valid(preview_powder) and preview_powder.has_method("snapshot"):
		powder_state = preview_powder.call("snapshot")
	return {
		"status": status,
		"station": _station,
		"cannon_index": _cannon_index,
		"usable": _ship_usable(),
		"aboard": _player_aboard(),
		"hud": {"balls": balls, "boards": boards},
		"balls": balls,
		"boards": boards,
		"water": water_state,
		"ship": ship_state,
		"cannons": cannon_state,
		"target": target_state,
		"powder": powder_state,
		"player": player.global_position if is_instance_valid(player) else Vector3.ZERO,
	}


func _update_lever_work(delta: float) -> void:
	# The winch used to pin the player whenever W was held within 2.8 m, which
	# made the deck around the mast feel frozen and killed the walk animation.
	# Sail handling is now F-only; proximity never captures movement.
	_reset_lever_work()
	return


func _reset_lever_work() -> void:
	if not is_instance_valid(player):
		return
	_lever_hold_pos = Vector3.ZERO
	var visual := player.get("_visual") as Node3D
	if is_instance_valid(visual):
		visual.rotation.x = 0.0
		visual.rotation.z = 0.0


func _update_swimming(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(preview_basin):
		return
	if _station != "" or bool(world.get("preview_dead")):
		player.call("set_swimming", false)
		return
	var water: float = preview_basin.water_level()
	var pos: Vector3 = player.global_position
	var in_ladder := false
	if is_instance_valid(preview_boat) and preview_boat.has_method("in_boarding_zone"):
		in_ladder = bool(preview_boat.call("in_boarding_zone", pos))
	var swimming := _swim_state
	var depth := 0.0
	if preview_basin.has_method("depth_at"):
		depth = float(preview_basin.call("depth_at", pos.x, pos.z))
	# Hysteresis: small bobbing at the surface must not toggle stand/swim every
	# frame (that reset the stroke phase and made the character jerk).
	if swimming:
		# Reaching wadeable ground ends the swim immediately, so the player walks
		# out onto the beach instead of being held at water level.
		if player.is_on_floor() and (depth < 0.55 or pos.y > water - 0.35):
			swimming = false
		elif pos.y > water + 0.55 or (player.is_on_floor() and pos.y > water + 0.02):
			swimming = false
	else:
		if pos.y < water - 0.06 or (depth > 0.45 and pos.y < water + 0.42 and not _player_aboard()):
			swimming = true
	if in_ladder:
		swimming = false
	_swim_state = swimming
	player.call("set_swimming", swimming, water - 0.10)


func _recover_overboard() -> void:
	if not is_instance_valid(preview_boat) or not is_instance_valid(player) or not is_instance_valid(preview_basin):
		return
	# A player on a boarding ladder is deliberately between shore/water and the
	# deck; do not teleport him away from the ladder he is climbing.
	if preview_boat.has_method("in_boarding_zone") and bool(preview_boat.call(
			"in_boarding_zone", player.global_position)):
		return
	var water: float = preview_basin.water_level()
	if player.global_position.y >= water + 0.10:
		return
	if player.global_position.distance_to(preview_boat.global_position) > 22.0:
		return
	var safe: Vector3 = preview_boat.to_global(HELM_STAND)
	player.global_position = safe
	player.velocity = Vector3.ZERO
	_message("Поднят из-за борта на палубу", 2.6)


func _recover_underdeck() -> void:
	if not is_instance_valid(preview_boat) or not is_instance_valid(player):
		return
	# Never rescue a swimmer back onto the ship.  The under-deck rescue is only
	# for a body that actually fell and is standing inside the hull.
	if _swim_state or bool(player.get("_swimming")):
		return
	if not player.is_on_floor():
		return
	# In the water the swimmer is allowed to be under the hull footprint; the
	# under-deck rescue must not fire there or it would throw him back on deck.
	if is_instance_valid(preview_basin) and player.global_position.y < preview_basin.water_level() + 0.10:
		return
	var local: Vector3 = preview_boat.to_local(player.global_position)
	# Inside the hull footprint but below the walking deck: the player has
	# fallen through a deck opening (and may be resting on the new safety sole
	# at y≈1.06).  The cabin well z>4.3 is a legitimate low surface, so it is
	# excluded; everything else below 1.35 is a fall.
	if absf(local.x) > 4.2 or absf(local.z) > 13.6:
		return
	var in_cabin_well := local.z > 4.30 and local.z < 12.40
	if local.y >= 1.35 or in_cabin_well:
		return
	var safe: Vector3 = preview_boat.to_global(HELM_STAND)
	player.global_position = safe
	player.velocity = Vector3.ZERO
	_message("Поднят на палубу — не проваливайтесь", 2.6)


func _player_aboard() -> bool:
	if not is_instance_valid(preview_boat) or not is_instance_valid(player):
		return false
	var local: Vector3 = preview_boat.to_local(player.global_position)
	# On deck, in the cabin or on the fighting top.  Swimming beside the hull,
	# standing on the shore or hanging on a boarding ladder must not show the
	# ship panel.
	if absf(local.x) > 4.10 or absf(local.z) > 13.8:
		return false
	if local.y < 0.42:
		return false
	return local.y > -0.30 and local.y < 8.50


func _ship_usable() -> bool:
	if not is_instance_valid(preview_boat):
		return false
	if preview_boat.has_method("is_sunk") and bool(preview_boat.call("is_sunk")):
		return false
	if preview_boat.has_method("usable") and not bool(preview_boat.call("usable")):
		return false
	return true


## Called by the existing powder-barrel host when a charge explodes.  The shot
## that ignites a deck barrel therefore puts a real 260-point hole in the hull.
func apply_powder_blast(at: Vector3) -> Dictionary:
	if not is_instance_valid(preview_boat) or not preview_boat.has_method("apply_hit"):
		return {"ok": false, "reason": "no_boat"}
	var distance := preview_boat.global_position.distance_to(at)
	if distance > 12.0:
		return {"ok": false, "reason": "far", "distance": distance}
	var direction := (preview_boat.global_position - at)
	direction.y = 0.25
	direction = direction.normalized()
	# A charge sits on the deck; the hull that it opens is just below it.  Aim
	# the hit at the waterline band, otherwise the blast only snaps a deck part
	# and the ship never takes water.
	var hull_point := at - Vector3.UP * 1.15
	var hit: Variant = preview_boat.call("apply_hit", hull_point, 260.0, direction * 12.0, "powder")
	_message("Порох рванул на палубе — пробоина!", 3.0)
	return {"ok": true, "distance": distance, "at": at, "hull_point": hull_point, "hit": hit}


## QA and the HUD both steer through the host.
func steer(axis: float) -> void:
	if not _ship_usable():
		return
	if preview_boat != null and preview_boat.has_method("steer"):
		preview_boat.call("steer", axis)


func set_sails(open: bool) -> void:
	if open and not _ship_usable():
		return
	if preview_boat != null and preview_boat.has_method("set_sails"):
		preview_boat.call("set_sails", open)


func toggle_sails() -> bool:
	if not _ship_usable():
		return false
	if preview_boat != null and preview_boat.has_method("toggle_sails"):
		return bool(preview_boat.call("toggle_sails"))
	return false


## ------------------------------------------------------------------ QA hooks
func debug_fire_at(world_point: Vector3) -> Dictionary:
	if preview_cannons == null:
		return {"ok": false, "reason": "no_cannons"}
	if preview_cannons.has_method("debug_fire_at"):
		return preview_cannons.call("debug_fire_at", world_point)
	return {"ok": false, "reason": "no_debug_fire"}


## QA hook: put the hull back on the deep-water berth with the port battery
## bearing on the south wall, so a damage scenario is repeatable.
func debug_reset_ship() -> void:
	if not is_instance_valid(preview_boat):
		return
	_leave_station()
	preview_boat.call("moor", Vector3(115.0, _water_level(), 975.0), 0.0)
	if preview_boat.has_method("set_sails"):
		preview_boat.call("set_sails", false)
	if preview_boat.has_method("steer"):
		preview_boat.call("steer", 0.0)


func debug_hit_ship(count: int = 1) -> Dictionary:
	if preview_boat == null or not preview_boat.has_method("apply_hit"):
		return {"ok": false, "reason": "no_boat"}
	var at: Vector3 = preview_boat.to_global(Vector3(-4.2, 0.4, -2.0))
	var axis: Vector3 = preview_boat.to_global(Vector3(-1.0, 0.0, 0.0)) - preview_boat.global_position
	var result: Dictionary = {}
	for index in maxi(1, count):
		result = preview_boat.call("apply_hit", at + Vector3(0.0, float(index) * 0.6, 0.0),
			120.0, -axis.normalized() * 8.0, "cannonball")
	return result


func debug_set_station(kind: String, index: int = 0) -> void:
	if kind == "helm":
		_toggle_helm()
	elif kind == "cannon":
		_toggle_cannon(index)
	elif kind == "leave":
		_leave_station()


func dispose() -> void:
	_leave_station()
	if preview_hud != null and preview_hud.has_method("dispose"):
		preview_hud.call("dispose")
	_installed = false
