extends SceneTree
## Real castle scene: combat and fall deaths share the articulated corpse view.

func _initialize() -> void:
	_run.call_deferred()

func _ready_scene() -> Node:
	var scene: Node = load("res://scenes/castle.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and scene.get("preview_ready") != true:
		await physics_frame
	return scene

func _run() -> void:
	var failures: Array[String] = []
	var scene := await _ready_scene()
	var sword: Node = scene.get("preview_sword_prototype")
	var player: CharacterBody3D = scene.get("_player")
	if not is_instance_valid(sword) or not is_instance_valid(player):
		print("HERO_DEATH FAIL setup")
		quit(1)
		return
	var armor: Node = scene.get_node_or_null("CastleArmorEquipment")
	if not is_instance_valid(armor) or not bool((armor.call("equip_ground", "light_torso") as Dictionary).get("ok", false)):
		failures.append("armor_setup")
	var before := player.global_position
	var rig: Skeleton3D = sword.get("_rig")
	var head_bone := rig.find_bone("head") if is_instance_valid(rig) else -1
	var pelvis_bone := rig.find_bone("pelvis") if is_instance_valid(rig) else -1
	var upright_before := 0.0
	if head_bone >= 0 and pelvis_bone >= 0:
		upright_before = (rig.global_transform * rig.get_bone_global_pose(head_bone)).origin.y \
			- (rig.global_transform * rig.get_bone_global_pose(pelvis_bone)).origin.y
	sword.call("_kill_player", before + Vector3.UP * 1.1, Vector3.RIGHT, 65.0)
	var view: Node = scene.get("hero_death_presentation")
	var physics: Dictionary = sword.call("snapshot").get("player_death_physics31", {})
	if not bool(scene.get("preview_dead")) or not bool(physics.get("started", false)):
		failures.append("combat_not_physical")
	if not is_instance_valid(view) or view.get("cause") != "combat" \
			or view.get("title").text != "Пал в бою" \
			or scene.get_viewport().get_camera_3d() != view.get("camera"):
		failures.append("combat_view")
	if player.get("_pose_authority") != &"dead": failures.append("combat_control_enabled")
	sword.call("_kill_player", before, Vector3.DOWN, 30.0, "fall")
	if scene.get("hero_death_presentation") != view or view.get("cause") != "combat":
		failures.append("combat_death_reentered")
	for frame: int in 60: await physics_frame
	if player.global_position.distance_to(before) < 0.05: failures.append("combat_body_frozen")
	if head_bone >= 0 and pelvis_bone >= 0:
		var upright_after := (rig.global_transform * rig.get_bone_global_pose(head_bone)).origin.y \
			- (rig.global_transform * rig.get_bone_global_pose(pelvis_bone)).origin.y
		print("HERO_DEATH_POSE before=", upright_before, " after=", upright_after)
		if upright_after > upright_before * 0.8:
			failures.append("combat_body_stayed_upright")
	if is_instance_valid(view) and view.get("camera").global_position.y - player.global_position.y < 2.0:
		failures.append("camera_not_above_corpse")
	if reload_current_scene() != OK:
		failures.append("reload_failed")
	else:
		var deadline := Time.get_ticks_msec() + 120000
		while Time.get_ticks_msec() < deadline and (current_scene == null \
				or current_scene.get("preview_ready") != true):
			await physics_frame
		scene = current_scene
		if not is_instance_valid(scene):
			failures.append("fall_scene_missing")
		else:
			var balloon_deadline := Time.get_ticks_msec() + 30000
			while Time.get_ticks_msec() < balloon_deadline \
					and not is_instance_valid(scene.get("preview_balloon")):
				await physics_frame
			var balloon: Node = scene.get("preview_balloon")
			if is_instance_valid(balloon): balloon.call("_die")
			else: failures.append("balloon_not_installed")
			view = scene.get("hero_death_presentation")
			sword = scene.get("preview_sword_prototype")
			physics = sword.call("snapshot").get("player_death_physics31", {})
			if not bool(scene.get("preview_dead")) or not bool(physics.get("started", false)):
				failures.append("fall_not_physical")
			if not is_instance_valid(view) or view.get("cause") != "fall" \
					or view.get("title").text != "Разбился":
				failures.append("fall_view")
			sword.call("_kill_player", Vector3.ZERO, Vector3.RIGHT, 65.0, "combat")
			if scene.get("hero_death_presentation") != view or view.get("cause") != "fall":
				failures.append("fall_death_reentered")
	print("HERO_DEATH ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
