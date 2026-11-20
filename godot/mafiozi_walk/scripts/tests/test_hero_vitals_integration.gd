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
	var sites_label: Label = hud.get("_sites_label")
	if sites_label.text == "Ран нет":
		failures.append("old_injury_labeled_clean")
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
	if sites_label.text != "Ран нет" or not missing_label.text.is_empty():
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
	if four.wound_count != 4 or five.wound_count != 4 or five.bleed_percent <= four.bleed_percent:
		failures.append("bounded_fifth_cut")
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
	print("HERO_VITALS ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
