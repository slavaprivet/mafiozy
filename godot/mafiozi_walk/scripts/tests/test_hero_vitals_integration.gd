extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await physics_frame
	var vitals: RefCounted = scene.get("hero_vitals")
	var hud: CanvasLayer = scene.get("hero_vitals_hud")
	if vitals == null or not is_instance_valid(hud):
		print("HERO_VITALS FAIL setup")
		quit(1)
		return
	var failures: Array[String] = []
	var initial: Dictionary = vitals.snapshot()
	if initial.hp != 100.0 or initial.bleed_percent != 0:
		failures.append("initial_state")
	hud.call("_process", 0.3)
	var weapon_label: Label = hud.get("_weapon_label")
	var weapons: Node = scene.get("preview_weapons")
	if weapon_label.text != "Без оружия": failures.append("initial_weapon_label")
	if is_instance_valid(weapons):
		var equipped: Dictionary = weapons.call("equip", "sword")
		if bool(equipped.get("ok", false)):
			if not weapon_label.text.contains("меч"): failures.append("held_weapon_label")
			var held_blade: Node = scene.get("preview_sword_prototype")
			if is_instance_valid(held_blade) and bool(held_blade.call("drop_sword_to_ground")):
				hud.call("_process", 0.3)
				if weapon_label.text != "Без оружия": failures.append("dropped_weapon_label")
			else:
				failures.append("weapon_drop_setup")
			if bool((weapons.call("equip", "none") as Dictionary).get("ok", false)) \
					and weapon_label.text != "Без оружия":
				failures.append("stowed_weapon_label")
		else:
			failures.append("weapon_equip_failed")
	vitals.apply_damage(18.0, "forearm_r", "slice", true)
	var first: Dictionary = vitals.snapshot()
	if first.hp != 82.0 or first.wound_count != 1 or first.bleed_percent <= 0 \
			or not bool(first.parts.arm_l.bleeding):
		failures.append("first_cut")
	vitals.apply_damage(24.0, "thigh_l", "slice", true)
	var second: Dictionary = vitals.snapshot()
	if second.wound_count != 2 or second.bleed_percent <= first.bleed_percent \
			or not bool(second.parts.leg_r.bleeding):
		failures.append("second_cut")
	var before_bleed := float(second.hp)
	for tick: int in 10:
		vitals.step(0.1)
	if float(vitals.snapshot().hp) >= before_bleed:
		failures.append("bleed_did_not_drain_hp")
	vitals.sync_body({"hand_r": 0.0}, {"hand_r": true}, {"hand": 22.0})
	var lost: Dictionary = vitals.snapshot()
	if not bool(lost.segments.hand_l.severed) or bool(lost.segments.forearm_l.severed) \
			or bool(lost.segments.upperarm_l.severed) or not lost.severed_labels.has("левая кисть") \
			or lost.body_split or lost.wound_count != 3:
		failures.append("severed_part")
	var missing_label: Label = hud.get("_lost_label")
	if not missing_label.text.contains("левая кисть"):
		failures.append("missing_part_label")
	vitals.note_burning(1.1)
	if not vitals.snapshot().burning:
		failures.append("burn_status_missing")
	var burn_label: Label = hud.get("_burn_label")
	if not burn_label.text.contains("горение"):
		failures.append("burn_icon_missing")
	if not is_equal_approx(float(hud.call("snapshot").hp), float(lost.hp)):
		failures.append("hud_not_synced")
	for tick: int in 130:
		vitals.step(0.1)
	var stopped: Dictionary = vitals.snapshot()
	if stopped.bleed_percent != 0 or stopped.wound_count != 0 or stopped.burning:
		failures.append("bleeding_did_not_stop")
	var status_label: Label = hud.get("_status_label")
	if status_label.text != "Ранен": failures.append("old_injury_status")
	var stable_hp := float(stopped.hp)
	vitals.step(1.0)
	if not is_equal_approx(float(vitals.snapshot().hp), stable_hp):
		failures.append("expired_wound_still_drains")
	vitals.mark_dead()
	if vitals.snapshot().hp != 0.0:
		failures.append("death_state")
	vitals.reset()
	var reborn: Dictionary = vitals.snapshot()
	if reborn.hp != 100.0 or reborn.wound_count != 0 or reborn.bleed_percent != 0 \
			or bool(reborn.segments.hand_l.severed) or reborn.burning:
		failures.append("respawn_reset")
	if status_label.text != "Здоров" or not missing_label.text.is_empty():
		failures.append("respawn_hud_not_clean")
	vitals.sync_body({"head": 0.0}, {"head": true}, {"head": 50.0})
	if not bool(vitals.snapshot().segments.head.severed) or not vitals.snapshot().severed_labels.has("голова"):
		failures.append("head_loss_not_shown")
	vitals.reset()
	vitals.sync_body({}, {}, {}, {}, {"chest": true})
	if vitals.snapshot().body_split:
		failures.append("uncommitted_torso_split_shown")
	vitals.sync_body({"chest": 0.0}, {"chest": true}, {"chest": 96.0}, {}, {"chest": true})
	if not vitals.snapshot().body_split:
		failures.append("committed_torso_split_missing")
	vitals.reset()
	for part: String in ["hand_r", "hand_l", "foot_r", "foot_l"]:
		vitals.apply_damage(2.0, part, "slice", true)
	var four: Dictionary = vitals.snapshot()
	vitals.apply_damage(20.0, "thigh_l", "slice", true)
	var five: Dictionary = vitals.snapshot()
	if four.wound_count != 4 or five.wound_count != 5 or five.bleed_percent <= four.bleed_percent:
		failures.append("fifth_cut_counted")
	for tick: int in 40: vitals.step(0.1)
	vitals.apply_damage(2.0, "hand_r", "slice", true)
	if vitals.snapshot().wound_count != 6: failures.append("repeat_cut_counted")
	for tick: int in 40: vitals.step(0.1)
	if vitals.snapshot().wound_count != 1 or float(vitals.snapshot().bleed_hp_per_second) <= 0.0:
		failures.append("staggered_wound_expiry")
	for tick: int in 40: vitals.step(0.1)
	if vitals.snapshot().wound_count != 0 or vitals.snapshot().bleed_percent != 0:
		failures.append("last_wound_expiry")
	vitals.reset()
	for cut: int in 40: vitals.apply_damage(2.0, "forearm_r", "slice", true)
	var many: Dictionary = vitals.snapshot()
	vitals.apply_damage(2.0, "forearm_r", "slice", true)
	var extra: Dictionary = vitals.snapshot()
	if many.wound_count != 40 or extra.wound_count != 41 \
			or float(extra.bleed_hp_per_second) <= float(many.bleed_hp_per_second) \
			or float(extra.bleed_hp_per_second) >= 6.0:
		failures.append("many_cuts_bounded_monotonic")
	vitals.reset()
	var sword: Node = scene.get("preview_sword_prototype")
	var player: Node = scene.get("_player")
	var fire_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < fire_deadline and not is_instance_valid(scene.get("preview_fire")):
		await physics_frame
	var fire: Node = scene.get("preview_fire")
	if is_instance_valid(fire) and is_instance_valid(player):
		var fuel := Node3D.new()
		fuel.name = "TestHeroFireFuel"
		scene.add_child(fuel)
		fuel.global_position = player.global_position + Vector3(0.0, 0.0, -1.0)
		fire.call("register", fuel, 1.2)
		var fuel_rows: Array = fire.get("_fuel")
		var fuel_row: Dictionary = fuel_rows.back()
		if not fire.call("_light", fuel_row):
			failures.append("fire_ignition_failed")
		else:
			var blocker := StaticBody3D.new()
			blocker.collision_layer = 1
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.5, 2.0, 0.12)
			collision.shape = shape
			blocker.add_child(collision)
			scene.add_child(blocker)
			blocker.global_position = player.global_position + Vector3(0.0, 0.5, -0.5)
			await physics_frame
			fire.call("_tick_actor_fire")
			if not is_equal_approx(float(vitals.snapshot().hp), 100.0) or vitals.snapshot().burning:
				failures.append("fire_crossed_wall")
			blocker.queue_free()
			await physics_frame
			fire.call("_tick_actor_fire")
			if not is_equal_approx(float(vitals.snapshot().hp), 98.0) or not vitals.snapshot().burning:
				failures.append("fire_contact_not_shared")
			vitals.step(0.8)
			if vitals.snapshot().burning:
				failures.append("fire_status_stuck")
		fire.call("_char", fuel_row)
		fuel.queue_free()
		vitals.reset()
	else:
		failures.append("fire_host_missing")
	if is_instance_valid(sword) and is_instance_valid(player):
		var blunt: Dictionary = sword.call("apply_catapult_stone_impact31", player, 10,
			player.global_position + Vector3.UP, Vector3(0.0, -2.0, 0.0))
		if not bool(blunt.get("applied", false)) or not is_equal_approx(float(vitals.snapshot().hp), 90.0):
			failures.append("combat_damage_not_shared")
		if vitals.snapshot().wound_count != 0:
			failures.append("blunt_created_bleeding")
	else:
		failures.append("combat_host_missing")
	vitals.apply_damage(84.0, "chest", "blunt", false)
	vitals.apply_damage(2.0, "forearm_r", "slice", true)
	vitals.apply_damage(2.0, "thigh_l", "slice", true)
	for tick: int in 90:
		if bool(scene.get("preview_dead")): break
		vitals.step(0.1)
	if not bool(scene.get("preview_dead")) or vitals.snapshot().hp != 0.0:
		failures.append("bleedout_did_not_kill")
	if reload_current_scene() != OK:
		failures.append("scene_reload_failed")
	else:
		var next_deadline := Time.get_ticks_msec() + 120000
		while Time.get_ticks_msec() < next_deadline and (current_scene == null \
				or current_scene.get("preview_ready") != true):
			await physics_frame
		var fresh: RefCounted = current_scene.get("hero_vitals") if current_scene != null else null
		if fresh == null or fresh.snapshot().hp != 100.0 or fresh.snapshot().wound_count != 0:
			failures.append("scene_respawn_not_clean")
		else:
			var live_sword: Node = current_scene.get("preview_sword_prototype")
			var live_player: Node3D = current_scene.get("_player")
			var live_hud: CanvasLayer = current_scene.get("hero_vitals_hud")
			if not is_instance_valid(live_sword) or not is_instance_valid(live_player):
				failures.append("real_sever_setup")
			else:
				var hit_at := live_player.global_position + Vector3.UP * 1.2
				live_sword.call("_apply_player_damage", 60.0, hit_at, Vector3.RIGHT,
					"slice", "hand_r", null, Vector3.ZERO, -1.0)
				var actual: Dictionary = live_sword.call("snapshot")
				var hero: Dictionary = fresh.snapshot()
				if not (actual.get("player_severed", []) as Array).has("hand_r") \
						or not bool(hero.segments.hand_l.severed) \
						or not str(live_hud.get("_lost_label").text).contains("левая кисть"):
					failures.append("real_hand_sever_not_in_hud")
				if hero.wound_count != 1:
					failures.append("sever_counted_twice")
				live_sword.call("_apply_player_damage", 999.0, hit_at, Vector3.RIGHT,
					"slice", "head", null, Vector3.ZERO, -1.0)
				actual = live_sword.call("snapshot")
				hero = fresh.snapshot()
				if not (actual.get("player_severed", []) as Array).has("head") \
						or not bool(hero.segments.head.severed) \
						or not str(live_hud.get("_lost_label").text).contains("голова") \
						or hero.body_split:
					failures.append("real_head_sever_not_in_hud")
				if reload_current_scene() != OK:
					failures.append("torso_scene_reload_failed")
				else:
					var torso_deadline := Time.get_ticks_msec() + 120000
					while Time.get_ticks_msec() < torso_deadline and (current_scene == null \
							or current_scene.get("preview_ready") != true):
						await physics_frame
					var torso_sword: Node = current_scene.get("preview_sword_prototype") if current_scene != null else null
					var torso_player: Node3D = current_scene.get("_player") if current_scene != null else null
					var torso_vitals: RefCounted = current_scene.get("hero_vitals") if current_scene != null else null
					if not is_instance_valid(torso_sword) or not is_instance_valid(torso_player) or torso_vitals == null:
						failures.append("real_torso_setup")
					else:
						torso_sword.call("_apply_player_damage", 999.0,
							torso_player.global_position + Vector3.UP * 1.2, Vector3.RIGHT,
							"slice", "chest", null, Vector3.ZERO, -1.0)
						if not bool(current_scene.get("preview_dead")) or torso_vitals.snapshot().body_split:
							failures.append("false_real_torso_split")
	print("HERO_VITALS ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
