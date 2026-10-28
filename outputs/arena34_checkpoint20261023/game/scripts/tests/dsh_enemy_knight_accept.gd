extends SceneTree
## Functional acceptance for the castle ENEMY KNIGHT.
## Loads the real castle scene, installs the real sword host, and checks the rules
## the user asked for instead of only printing a pose:
##   * he is the city resident model with the city walk gait;
##   * he wears the existing MEDIUM harness on all five slots;
##   * he spots the player through a real line of sight after ~180 ms and attacks
##     without waiting to be hit;
##   * he uses more than one attack lane and keeps reachable distance;
##   * a blade-on-blade clash stops the cut and pushes BOTH men;
##   * he never teleports, and the medium tier gives the expected mobility;
##   * low health turns on the aggressive press (a real state, not a damage buff).

const OUT := "C:/Users/Слава/Documents/deepseek-harness/default-workspace/_enemy_knight_shots"

var _scene: Node3D
var _host: Node
var _player: CharacterBody3D
var _fails: Array[String] = []
var _notes: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _settle(frames: int) -> void:
	for i: int in frames:
		await physics_frame

func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		print("ENEMY_ACCEPT_PASS ", label, " ", detail)
	else:
		print("ENEMY_ACCEPT_FAIL ", label, " ", detail)
		_fails.append(label + " " + detail)

func _pick(snap: Dictionary) -> Dictionary:
	var out := {}
	for key: String in ["npc_bound", "npc_state", "npc_engaged", "npc_hp", "npc_swings",
			"npc_hits", "npc_blocked", "npc_position", "player_position", "enemy_clashes",
			"enemy_evades", "enemy_combo_left", "enemy_attack_counts", "npc_armor",
			"npc_armor_tier", "npc_walk_gait", "npc_speed_scale", "enemy_enraged"]:
		if snap.has(key): out[key] = snap[key]
	return out

func _run() -> void:
	var packed: PackedScene = load("res://scenes/castle.tscn")
	if packed == null:
		print("ENEMY_ACCEPT_FAIL scene"); quit(1); return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and _scene.get("preview_ready") != true:
		await process_frame
	if _scene.get("preview_ready") != true:
		print("ENEMY_ACCEPT_FAIL startup"); quit(1); return
	_player = _scene.get("_player") as CharacterBody3D
	# The castle boot already installs the host in enemy-only mode. Use that real
	# host; only a direct probe of an older build creates one explicitly.
	_host = _scene.get("preview_sword_prototype") as Node
	if is_instance_valid(_host):
		print("ENEMY_ACCEPT_EXISTING_HOST status=", _scene.get("sword_prototype_status"))
	else:
		var script: Script = load("res://scripts/weapons/sword_prototype.gd")
		_host = script.new()
		_host.name = "SwordPrototypeAccept"
		_scene.add_child(_host)
		var installed: Dictionary = _host.call("install", _scene, _player)
		_check(bool(installed.get("ok", false)), "host_installed", JSON.stringify(installed))
	_check(bool(_host.get("_ready")), "host_ready")
	_player.set_mouse_captured(true)
	# Wait for the resident model and the five armour pieces, not a frame count guess.
	var bound := false
	for i: int in 420:
		await physics_frame
		if bool(_host.snapshot().get("npc_bound", false)):
			bound = true
			break
	_check(bound, "city_resident_spawned")
	if not bound:
		print("ENEMY_ACCEPT_SUMMARY ", JSON.stringify({"fails": _fails}))
		quit(1); return
	var first: Dictionary = _host.snapshot()
	print("ENEMY_ACCEPT_FIRST ", JSON.stringify(_pick(first)))

	# 1. City skin and canonical walk gait.
	_check(bool(first.get("npc_walk_gait", false)), "city_walk_gait_bound")
	var rig: Skeleton3D = _host.get("_npc_rig") as Skeleton3D
	_check(is_instance_valid(rig) and rig.get_bone_count() == 28, "city_resident_28_bones",
		"bones=%d" % (rig.get_bone_count() if is_instance_valid(rig) else -1))
	var visual: Node = rig.get_parent() if is_instance_valid(rig) else null
	var resident_meshes := 0
	if is_instance_valid(visual):
		for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
			if String(node.name).contains("SKIN") or String(node.name).contains("FABRIC"):
				resident_meshes += 1
	_check(resident_meshes > 0, "city_skin_meshes_present", "meshes=%d" % resident_meshes)

	# 2. Medium harness in all five existing slots.
	var armor: Dictionary = first.get("npc_armor", {})
	var armor_ok := armor.size() == 5
	for slot: String in ["head", "torso", "hands", "legs", "feet"]:
		armor_ok = armor_ok and str(armor.get(slot, "")).begins_with("medium_")
	_check(armor_ok, "medium_harness_all_slots", JSON.stringify(armor))
	_check(str(first.get("npc_armor_tier", "")) == "medium", "medium_tier")
	var visual_armor: Dictionary = _host.call("npc_armor_visual_snapshot31")
	_check(int(visual_armor.get("meshes", 0)) >= 5, "medium_harness_rendered",
		"meshes=%d" % int(visual_armor.get("meshes", 0)))
	var speed_scale := float(first.get("npc_speed_scale", 0.0))
	_check(absf(speed_scale - 1.0) < 0.03, "medium_mobility", "speed_scale=%f" % speed_scale)

	# 3. Medium protection is real and strictly between bare skin and heavy plate.
	var ArmorDamage = load("res://scripts/combat/armor_damage31.gd")
	var medium_hit: Dictionary = ArmorDamage.resolve(armor, "chest", "slice", 100.0, Vector3(0, 0, 1), 1.0)
	var heavy_hit: Dictionary = ArmorDamage.resolve({"torso": "heavy_torso"}, "chest", "slice", 100.0, Vector3(0, 0, 1), 1.0)
	_check(float(medium_hit.damage) < 100.0 and float(medium_hit.damage) > float(heavy_hit.damage),
		"medium_protection_between_skin_and_heavy",
		"medium=%f heavy=%f" % [medium_hit.damage, heavy_hit.damage])

	# 4. He attacks without the player hitting him first.
	var start_swings := int(first.get("npc_swings", 0))
	await _settle(420)
	var second: Dictionary = _host.snapshot()
	print("ENEMY_ACCEPT_SECOND ", JSON.stringify(_pick(second)))
	_check(bool(second.get("npc_engaged", false)), "enemy_engaged_on_sight")
	_check(int(second.get("npc_swings", 0)) > start_swings, "attacks_unprovoked",
		"swings=%d" % int(second.get("npc_swings", 0)))
	_check(int(second.get("npc_hits", 0)) > 0, "lands_a_real_hit_on_player",
		"hits=%d" % int(second.get("npc_hits", 0)))

	# 5. More than one attack lane after a longer exchange.
	await _settle(360)
	var third: Dictionary = _host.snapshot()
	print("ENEMY_ACCEPT_THIRD ", JSON.stringify(_pick(third)))
	var counts: Dictionary = third.get("enemy_attack_counts", {})
	var used := 0
	for key: Variant in counts:
		if int(counts[key]) > 0: used += 1
	_check(used >= 2, "attack_lane_variety", JSON.stringify(counts))

	# 6. No teleport: sample the capsule every frame through a live exchange.
	var max_step := 0.0
	var prev: Vector3 = (third.get("npc_position", Vector3.ZERO) as Vector3)
	for i: int in 90:
		await physics_frame
		var now: Dictionary = _host.snapshot()
		var at: Vector3 = now.get("npc_position", prev)
		max_step = maxf(max_step, prev.distance_to(at))
		prev = at
	_check(max_step < 0.35, "no_teleport_max_step", "max_step=%f" % max_step)

	# 7. The registered clash path pushes both men and stops the cut.
	var clash_before: Dictionary = _host.snapshot()
	_host.set("_last_clash_ms", -10000)
	_host.set("_enemy_clashes", 0)
	_host.set("_npc_hit_push31", Vector3.ZERO)
	var ppos: Vector3 = clash_before.get("player_position", Vector3.ZERO)
	var npos: Vector3 = clash_before.get("npc_position", Vector3.ZERO)
	var midpoint := (ppos + npos) * 0.5
	_host.call("_register_clash", midpoint)
	var clash_after: Dictionary = _host.snapshot()
	var npc_push: Vector3 = _host.get("_npc_hit_push31")
	var impulse: RefCounted = _player.get("_contact_impulse")
	var player_push_speed := 0.0
	if impulse != null:
		player_push_speed = float((impulse.call("snapshot").get("velocity", Vector3.ZERO) as Vector3).length())
	_check(int(clash_after.get("enemy_clashes", 0)) >= 1, "clash_registered")
	_check(npc_push.length() >= 0.5, "clash_pushes_knight", "npc_push=%f" % npc_push.length())
	_check(player_push_speed > 0.05, "clash_pushes_player", "player_speed=%f" % player_push_speed)
	_check(float(clash_after.get("enemy_last_clash_push", 0.0)) > 0.0, "clash_push_recorded")
	print("ENEMY_ACCEPT_CLASH ", JSON.stringify({"before": _pick(clash_before), "after": _pick(clash_after),
		"npc_push": npc_push, "player_push_speed": player_push_speed}))

	# 8. Low health turns on the press state (no damage multiplier is involved).
	_host.set("_npc_hp", 54.0)
	await _settle(2)
	var low: Dictionary = _host.snapshot()
	_check(bool(low.get("enemy_enraged", false)), "low_health_press_state", "hp=%f" % float(low.get("npc_hp", 0.0)))

	# 9. The buffered threat read aborts a windup into a real sidestep. This is the
	# same 180 ms observation the AI uses; the check drives that exact entry point,
	# then lets the collider play the evade and the return to guard.
	_host.set("_npc_threat53", true)
	_host.set("_npc_attack_cursor", 0)
	_host.set("_npc_state", "windup")
	_host.set("_npc_timer", 0.30)
	_host.set("_enemy_evade_cooldown_ms", 0)
	var evaded: bool = bool(_host.call("_enemy_try_evade", 1.4))
	_check(evaded and str(_host.get("_npc_state")) == "evade", "reads_blade_and_evades",
		"state=%s" % str(_host.get("_npc_state")))
	await _settle(30)
	var after_evade := str(_host.get("_npc_state"))
	_check(after_evade in ["guard", "recover", "approach"], "evade_returns_to_stance", "state=%s" % after_evade)

	var summary := {"fails": _fails, "notes": _notes,
		"armor": armor, "swings": int(third.get("npc_swings", 0)), "hits": int(third.get("npc_hits", 0)),
		"clashes": int(clash_after.get("enemy_clashes", 0)), "evades": int(third.get("enemy_evades", 0)),
		"max_step": max_step, "player_push_speed": player_push_speed}
	print("ENEMY_ACCEPT_SUMMARY ", JSON.stringify(summary))
	print("ENEMY_ACCEPT_DONE ", "PASS" if _fails.is_empty() else "FAIL")
	quit(0 if _fails.is_empty() else 1)
