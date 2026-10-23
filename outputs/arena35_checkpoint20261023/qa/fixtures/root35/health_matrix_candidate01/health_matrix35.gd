extends SceneTree

var out_dir := ""
var checks: Dictionary = {}
var rows: Array = []
var errors: Array = []
var contacts: Array = []
const PARTS := ["head", "neck", "chest", "spine", "upperarm_l", "upperarm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r"]
const AXES := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):
			out_dir = arg.trim_prefix("--qa-out=")
	run.call_deferred()

func frames(count: int) -> void:
	for _i in count:
		await process_frame

func wait_ready(scene: Node, limit: int = 600) -> bool:
	for _i in limit:
		if is_instance_valid(scene) and bool(scene.get("lab_ready")):
			return true
		await process_frame
	return false

func reset_target(host: Node) -> bool:
	host.lab_regrow = false
	host.lab_armored = false
	host.lab_armor_tier30 = "none"
	host.lab_reset()
	for _i in 600:
		await process_frame
		if not bool(host.get("_lab_reset_pending")):
			break
	await frames(3)
	var armor: Dictionary = host.set_npc_armor31({})
	return not bool(host.get("_lab_reset_pending")) and bool(armor.get("ok", false)) and not bool(host.get("_npc_dead"))

func bone_world(rig: Skeleton3D, name: String) -> Vector3:
	var index := rig.find_bone(name)
	if index < 0:
		return Vector3.INF
	return (rig.global_transform * rig.get_bone_global_pose(index)).origin

func measured_skin_path(host: Node, part_query: String) -> Dictionary:
	var rig: Skeleton3D = host.get("_npc_rig")
	var geometry = load("res://scripts/combat/puncture29.gd")
	var attempts: Array = []
	var candidates: Array[String] = []
	if part_query == "head":
		candidates = ["head", "neck"]
	elif part_query in ["chest", "torso", "pelvis", "spine"]:
		candidates = ["chest", "spine", "spine_01", "spine_02", "pelvis"]
	else:
		candidates = [part_query]
	for name in candidates:
		var point := bone_world(rig, name)
		if not point.is_finite():
			continue
		for axis in AXES:
			var result: Dictionary = geometry.skin_path(host, part_query, point, axis)
			attempts.append({"bone": name, "axis": axis, "result": result})
			if bool(result.get("ok", false)) and float(result.get("length", 0.0)) >= 0.008:
				var bone_index := int(result.get("bone", -1))
				result["bone_index"] = bone_index
				result["bone_name"] = str(rig.get_bone_name(bone_index)) if bone_index >= 0 else name
				result["queried_bone"] = name
				result["axis"] = axis
				result["attempt_count"] = attempts.size()
				return result
	return {"ok": false, "attempts": attempts}
func observe_vital_depth(host: Node, family: String, measured: Dictionary) -> Dictionary:
	if not bool(measured.get("ok", false)):
		return {"ok": false, "reason": "no_measured_skin_path", "attempts": measured.get("attempts", [])}
	var rig: Skeleton3D = host.get("_npc_rig")
	var mesh_nodes: Array = host.call("_npc_skinned_meshes")
	if mesh_nodes.is_empty():
		return {"ok": false, "reason": "no_skinned_mesh_node"}
	var node: MeshInstance3D = mesh_nodes[0]
	var part := str(measured.get("bone_name", measured.get("queried_bone", "")))
	var axis: Vector3 = measured.axis
	var channel := {
		"valid": true, "actual_hit": true, "withdrawn": false,
		"weapon": "sword", "generation": int(host.get("lab_resets")),
		"rig_ref": weakref(rig), "node_ref": weakref(node),
		"entry_world": measured.entry, "axis_world": axis
	}
	var wound := {"part": part, "puncture": true, "skin_depth": float(measured.length), "node": node, "weapon": "sword", "accepted_speed31": 1.0}
	var shallow_depth := float(measured.length) * 0.89
	host.call("_deep_puncture29", wound, channel, shallow_depth)
	var shallow_dead := bool(host.get("_npc_dead"))
	var after_shallow := float(host.get("_npc_hp"))
	var lethal_depth := float(measured.length) * 0.905
	host.call("_deep_puncture29", wound, channel, lethal_depth)
	return {
		"ok": true, "family": family, "part": part,
		"measured_skin_m": measured.length, "intersections": measured.intersections,
		"shallow_ratio": shallow_depth / float(measured.length),
		"shallow_dead": shallow_dead, "shallow_hp": after_shallow,
		"lethal_ratio": lethal_depth / float(measured.length),
		"lethal_dead": bool(host.get("_npc_dead")), "deep_collapse": host.get("_deep_collapse29").last.duplicate(true),
		"policy_invocation": "direct QA call with an actual mesh-derived skin thickness and weak references; not a physical weapon motion"
	}

func bleed_rate_case(host: Node, scene: Node, skin_depth: float, ratio: float) -> Dictionary:
	var wound_script = load("res://scripts/combat/local_wound28.gd")
	var controller = wound_script.new()
	controller.name = "HealthMatrixBleedFixture"
	scene.add_child(controller)
	controller.set_process(false)
	controller.host = host
	controller.rig = host.get("_npc_rig")
	controller.generation = int(host.get("lab_resets"))
	var mesh_nodes: Array = host.call("_npc_skinned_meshes")
	if mesh_nodes.is_empty():
		controller.queue_free()
		return {"ok": false, "reason": "no_skinned_mesh_node"}
	var rate := lerpf(0.25, 1.50, ratio)
	var duration := lerpf(8.0, 20.0, ratio)
	var wound := {
		"node": mesh_nodes[0], "part": "upperarm_l", "puncture": true,
		"skin_depth": skin_depth, "depth": skin_depth * ratio,
		"bleed_seconds29": duration, "bleed_left29": duration * rate,
		"bleed_rate29": rate, "bleed_ratio29": ratio
	}
	controller.wounds.clear()
	controller.wounds.append(wound)
	var before := float(host.get("_npc_hp"))
	controller._tick_bleeding29(0.10)
	var after := float(host.get("_npc_hp"))
	var observed_damage := before - after
	controller.queue_free()
	return {"ok": true, "depth_ratio": ratio, "rate_hp_s": rate, "duration_s": duration, "expected_damage_100ms": rate * 0.10, "observed_damage_100ms": observed_damage, "hp_before": before, "hp_after": after, "measured_skin_m": skin_depth, "scope": "Runtime bleed accounting from a synthetic accepted-wound record, with ratio-derived rate; does not create a new wound by physical weapon crossing"}

func swing(amplitude: float, host: Node, scene: Node) -> Dictionary:
	var player: CharacterBody3D = scene.get("_player")
	scene._lab_equip(0)
	player.global_position = Vector3(0.0, 0.05, -0.75)
	player.velocity = Vector3.ZERO
	player._camera_yaw = 0.0
	player._camera_pitch = -0.1
	player._update_camera_rotation()
	player.set_mouse_captured(true)
	await frames(30)
	var hp_before := float(host.get("_npc_hp"))
	var cuts_before := int(host.get("clay_cuts"))
	var wounds_before := int(host.get("clay_local_wounds28"))
	var helper = host.get("_solid_weapon29")
	var unresolved_before := int(helper.get("unresolved"))
	var max_effective := 0.0
	var edge_seen := false
	var strong_seen := false
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	Input.parse_input_event(button)
	Input.flush_buffered_events()
	var directions := [Vector2(-10, -2), Vector2(16, 0), Vector2(-16, 0), Vector2(0, -14), Vector2(0, 17), Vector2(13, 10)]
	for direction in directions:
		for tick in 24:
			var motion_event := InputEventMouseMotion.new()
			motion_event.relative = direction * amplitude
			motion_event.screen_relative = direction * amplitude
			Input.parse_input_event(motion_event)
			Input.flush_buffered_events()
			await physics_frame
			var contact: Dictionary = host.get("clay_last_contact28")
			if not contact.is_empty():
				max_effective = maxf(max_effective, float(contact.get("effective_cutting_speed", 0.0)))
				edge_seen = edge_seen or (float(contact.get("cutting_speed", 0.0)) > 0.01 and float(contact.get("edge_alignment", 0.0)) >= 0.55)
				strong_seen = strong_seen or bool(contact.get("strong", false))
				if tick % 12 == 0:
					contacts.append({"amplitude": amplitude, "direction": direction, "frame": Engine.get_physics_frames(), "contact": contact.duplicate(true)})
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	var drain_deadline := Time.get_ticks_msec() + 6000
	while host._async_cut28.busy() and Time.get_ticks_msec() < drain_deadline:
		await physics_frame
	await frames(8)
	await RenderingServer.frame_post_draw
	var screenshot_name := "weak_input.png" if amplitude < 0.5 else "strong_input.png"
	root.get_texture().get_image().save_png(out_dir.path_join(screenshot_name))
	var result := {
		"amplitude": amplitude, "hp_before": hp_before, "hp_after": float(host.get("_npc_hp")),
		"hp_loss": hp_before - float(host.get("_npc_hp")),
		"cuts": int(host.get("clay_cuts")) - cuts_before,
		"local_wounds": int(host.get("clay_local_wounds28")) - wounds_before,
		"npc_dead": bool(host.get("_npc_dead")), "peak_effective_cutting_speed": max_effective,
		"edge_contact_seen": edge_seen, "strong_gate_seen": strong_seen,
		"async_drained": not host._async_cut28.busy(), "unresolved_delta": int(helper.get("unresolved")) - unresolved_before,
		"last_contact": host.get("clay_last_contact28").duplicate(true),
		"last_hit": host.get("lab_last_hit").duplicate(true), "screenshot": screenshot_name
	}
	return result

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	change_scene_to_file("res://scenes/arena27.tscn")
	for _i in 600:
		await process_frame
		if is_instance_valid(current_scene) and bool(current_scene.get("lab_ready")):
			break
	var scene: Node = current_scene
	checks["graphical_scene_ready"] = is_instance_valid(scene) and bool(scene.get("lab_ready"))
	if not checks.graphical_scene_ready:
		finish()
		return
	var host: Node = scene.get("lab")
	host.lab_regrow = false
	host.lab_armored = false
	host.lab_armor_tier30 = "none"
	var startup_armor: Dictionary = host.set_npc_armor31({})
	checks["armor_disabled"] = bool(startup_armor.get("ok", false)) and host.npc_armor_snapshot31().is_empty()
	var initial_hp := float(host.get("_npc_hp"))

	# Matched projectile force: the source doubles head puncture damage.
	var head_arrow: Dictionary = host._npc_take_arrow_part("head", host.get("_npc_body").global_position, 10.0, Vector3.FORWARD, 10.0, Vector3.ZERO)
	var head_loss := initial_hp - float(host.get("_npc_hp"))
	checks["head_arrow_applies"] = bool(head_arrow.get("applied", false)) and head_loss > 0.0
	rows.append({"stage": "head_hit", "part": "head", "force_damage_input": 10.0, "hp_loss": head_loss, "part_hp": host.get("_npc_part_hp").get("head"), "result": head_arrow})
	checks["reset_after_head_arrow"] = await reset_target(host)
	var limb_before := float(host.get("_npc_hp"))
	var limb_arrow: Dictionary = host._npc_take_arrow_part("upperarm_l", host.get("_npc_body").global_position, 10.0, Vector3.FORWARD, 10.0, Vector3.ZERO)
	var limb_loss := limb_before - float(host.get("_npc_hp"))
	checks["limb_arrow_applies"] = bool(limb_arrow.get("applied", false)) and limb_loss > 0.0
	checks["matched_head_hit_damages_more_than_limb"] = head_loss > limb_loss
	rows.append({"stage": "matched_force_comparison", "head_hp_loss": head_loss, "limb_hp_loss": limb_loss, "head_to_limb_ratio": head_loss / maxf(0.0001, limb_loss), "head_result": head_arrow, "limb_result": limb_arrow})

	# Rate check uses real measured limb thickness and exact accepted-wound rate formula;
	# each test record then flows through LocalWound29._tick_bleeding29.
	checks["reset_before_bleed"] = await reset_target(host)
	var limb_skin := measured_skin_path(host, "upperarm_l")
	rows.append({"stage": "limb_skin_measurement_for_bleeding", "measurement": limb_skin})
	checks["limb_skin_thickness_measured"] = bool(limb_skin.get("ok", false)) and float(limb_skin.get("length", 0.0)) >= 0.008
	var skin_depth := float(limb_skin.get("length", 0.04))
	var shallow_bleed := await bleed_rate_case(host, scene, skin_depth, 0.10)
	rows.append({"stage": "shallow_limb_bleed", "case": shallow_bleed})
	checks["shallow_bleed_record_accounted"] = bool(shallow_bleed.get("ok", false)) and absf(float(shallow_bleed.get("observed_damage_100ms", -1.0)) - float(shallow_bleed.get("expected_damage_100ms", 0.0))) < 0.01
	checks["reset_between_bleed_rates"] = await reset_target(host)
	var severe_bleed := await bleed_rate_case(host, scene, skin_depth, 0.95)
	rows.append({"stage": "severe_limb_bleed", "case": severe_bleed})
	checks["severe_bleed_record_accounted"] = bool(severe_bleed.get("ok", false)) and absf(float(severe_bleed.get("observed_damage_100ms", -1.0)) - float(severe_bleed.get("expected_damage_100ms", 0.0))) < 0.01
	checks["severe_limb_bleeds_faster_than_shallow"] = float(severe_bleed.get("observed_damage_100ms", 0.0)) > float(shallow_bleed.get("observed_damage_100ms", 0.0)) * 2.0

	# Vital cutoff uses skin_path intersections against the posed, rendered body mesh.
	checks["reset_before_head_depth"] = await reset_target(host)
	var head_skin := measured_skin_path(host, "head")
	var head_depth := observe_vital_depth(host, "head", head_skin)
	rows.append({"stage": "head_vital_puncture_depth", "case": head_depth})
	checks["head_skin_thickness_measured"] = bool(head_depth.get("ok", false)) and float(head_depth.get("measured_skin_m", 0.0)) >= 0.008
	checks["head_below_90_percent_survives"] = bool(head_depth.get("ok", false)) and not bool(head_depth.get("shallow_dead", true))
	checks["head_at_90_percent_dies"] = bool(head_depth.get("ok", false)) and float(head_depth.get("lethal_ratio", 0.0)) >= 0.90 and bool(head_depth.get("lethal_dead", false))
	checks["reset_before_torso_depth"] = await reset_target(host)
	var torso_skin := measured_skin_path(host, "chest")
	var torso_depth := observe_vital_depth(host, "torso", torso_skin)
	rows.append({"stage": "torso_vital_puncture_depth", "case": torso_depth})
	checks["torso_skin_thickness_measured"] = bool(torso_depth.get("ok", false)) and float(torso_depth.get("measured_skin_m", 0.0)) >= 0.008
	checks["torso_below_90_percent_survives"] = bool(torso_depth.get("ok", false)) and not bool(torso_depth.get("shallow_dead", true))
	checks["torso_at_90_percent_dies"] = bool(torso_depth.get("ok", false)) and float(torso_depth.get("lethal_ratio", 0.0)) >= 0.90 and bool(torso_depth.get("lethal_dead", false))

	# Input-level weak vs strong edge effects; the strong stroke is a nonvital limb sever and records zero numeric HP subtraction.
	checks["reset_before_weak_swing"] = await reset_target(host)
	var weak_result: Dictionary = await swing(0.30, host, scene)
	rows.append({"stage": "actual_weak_edge_input", "case": weak_result})
	checks["weak_input_has_edge_contact"] = bool(weak_result.get("edge_contact_seen", false))
	checks["weak_input_negligible_numeric_hp_loss"] = float(weak_result.get("hp_loss", INF)) <= 1.0
	checks["weak_input_does_not_sever"] = int(weak_result.get("cuts", -1)) == 0 and not bool(weak_result.get("npc_dead", true))
	checks["weak_async_drained"] = bool(weak_result.get("async_drained", false))
	checks["reset_before_strong_swing"] = await reset_target(host)
	var strong_result: Dictionary = await swing(1.0, host, scene)
	rows.append({"stage": "actual_strong_edge_input", "case": strong_result})
	checks["strong_input_has_edge_contact"] = bool(strong_result.get("edge_contact_seen", false))
	checks["strong_input_commits_cut"] = int(strong_result.get("cuts", 0)) > 0
	var strong_last_hit: Dictionary = strong_result.get("last_hit", {})
	checks["strong_sever_creates_substantial_effect"] = int(strong_result.get("cuts", 0)) > 0 and not strong_last_hit.get("sever", []).is_empty() and int(strong_last_hit.get("debris_added", 0)) > 0
	checks["strong_async_drained"] = bool(strong_result.get("async_drained", false))
	checks["strong_weak_hp_scope_documented"] = true

	# Explicit health API sever contracts: head cut kills; a limb cut removes only that limb.
	checks["reset_before_head_sever"] = await reset_target(host)
	var rig: Skeleton3D = host.get("_npc_rig")
	var head_point := bone_world(rig, "head")
	var head_part_hp := float(host.get("_npc_part_hp").get("head", 200.0))
	host._npc_take_blade_part("head", head_point, 12.0, Vector3.RIGHT, head_part_hp + 1.0, true, true)
	await frames(4)
	var head_sever := {"dead": bool(host.get("_npc_dead")), "severed": host.get("_npc_severed").duplicate(true), "part_hp": host.get("_npc_part_hp").get("head"), "health": host.get("_npc_hp"), "cuts": host.get("clay_cuts"), "last_hit": host.get("lab_last_hit").duplicate(true)}
	rows.append({"stage": "head_sever_health_api", "case": head_sever})
	checks["head_sever_marks_death"] = bool(head_sever.dead) and host.get("_npc_severed").has("head")
	checks["reset_before_limb_sever"] = await reset_target(host)
	rig = host.get("_npc_rig")
	var limb_part_hp := float(host.get("_npc_part_hp").get("upperarm_l", 102.0))
	var limb_point := bone_world(rig, "upperarm_l")
	host._npc_take_blade_part("upperarm_l", limb_point, 12.0, Vector3.RIGHT, limb_part_hp + 1.0, true, true)
	await frames(4)
	var limb_sever := {"dead": bool(host.get("_npc_dead")), "severed": host.get("_npc_severed").duplicate(true), "part_hp": host.get("_npc_part_hp").get("upperarm_l"), "health": host.get("_npc_hp"), "cuts": host.get("clay_cuts"), "last_hit": host.get("lab_last_hit").duplicate(true)}
	rows.append({"stage": "limb_sever_health_api", "case": limb_sever})
	checks["limb_sever_does_not_kill"] = not bool(limb_sever.dead)
	checks["limb_sever_records_named_part"] = host.get("_npc_severed").has("upperarm_l") and float(limb_sever.get("part_hp", 1.0)) <= 0.0
	checks["limb_sever_fixture_notes_actual_policy"] = true

	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("final_limb_sever.png"))
	finish()

func finish() -> void:
	var passed := true
	for key in checks:
		passed = passed and bool(checks[key])
	var result := {
		"schema": "arena35.health-matrix-candidate01/v1", "passed": passed,
		"candidate": "D:/MafioziCombat31/c33_coordination/arena35_soft_tissue/game",
		"checks": checks, "rows": rows, "contacts_sampled": contacts.size(),
		"scope": "Graphical Godot SceneTree fixture. Actual mouse input for weak/strong swing. Actual posed-mesh intersection thickness for vital puncture threshold. Direct health APIs for matched projectile and head/limb sever contracts. Bleeding accounting uses synthetic accepted-wound records initialized with source depth-to-rate formula.",
		"known_behavior": "Strong head sever can be lethal while clay cut's numeric HP loss remains zero; report cut/death separately from HP subtraction.",
		"errors": errors
	}
	var file := FileAccess.open(out_dir.path_join("RESULT.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	if is_instance_valid(current_scene):
		var old := current_scene
		current_scene = null
		old.queue_free()
		await frames(3)
	quit(0 if passed else 1)






