extends SceneTree

const Pose = preload("res://scripts/traversal/traversal_pose.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var direction := Vector3(.8, 0, .6)
	var root := Vector3(12, .8, -7)
	for kind: String in ["vault", "mantle", "shore"]:
		for height: float in [.4, 1.1, 1.7]:
			var base := {"kind": kind, "root_position": root, "direction": direction,
				"edge_position": root + direction * .6 + Vector3.UP * height,
				"obstacle_height_m": height}
			var entry := base.duplicate(); entry.progress = 0.0
			var middle := base.duplicate(); middle.progress = .45
			var exit := base.duplicate(); exit.progress = 1.0
			var a: Dictionary = Pose.propose(entry)
			var b: Dictionary = Pose.propose(middle)
			var c: Dictionary = Pose.propose(exit)
			check(a.valid and b.valid and c.valid, "%s %.1f valid proposals" % [kind, height])
			check(is_zero_approx(float(a.weight)) and is_zero_approx(float(c.weight)), "%s %.1f base pose at endpoints" % [kind, height])
			check(float(b.weight) > .9 and float(b.legs.l.weight) > 0.0 and float(b.legs.r.weight) > 0.0, "%s %.1f articulated middle" % [kind, height])
			check(b.root_position == root and not b.root_yaw_owned and not b.collision_owned, "%s %.1f does not own root/collision" % [kind, height])
			check(b.palms.l.contact_available and b.palms.r.contact_available, "%s %.1f ledge contacts" % [kind, height])
			check((b.palms.l.contact_world as Vector3).distance_to(b.palms.r.contact_world) > .5, "%s %.1f separated palms" % [kind, height])
			check(b.weapon_policy == "holster" and b.weapon_restore_on_terminal, "%s %.1f explicit traversal weapon policy" % [kind, height])
			check(float(b.pelvis.clearance_required_m) == .03 and float(b.head.clearance_required_m) == .02, "%s %.1f pelvis/head clearance receipts" % [kind, height])
	var reach_sample := {"kind":"mantle", "progress":0.0, "pose_stage":"reach", "pose_stage_progress":1.0,
		"root_position":root, "direction":direction, "edge_position":root+direction*.6+Vector3.UP*1.2,
		"destination_position":root+direction*1.8+Vector3.UP*1.2, "obstacle_height_m":1.2}
	var reach: Dictionary = Pose.propose(reach_sample)
	check(reach.valid and is_equal_approx(float(reach.weight),1.0) and float(reach.palms.l.contact_weight) > .99, "reach establishes both palms at unchanged root before motion")
	var lift_start := reach_sample.duplicate(true); lift_start.pose_stage="traverse"; lift_start.pose_stage_progress=0.0; lift_start.contact_ready=true
	var lift_pose: Dictionary = Pose.propose(lift_start)
	check(is_equal_approx(float(lift_pose.weight),1.0) and float(lift_pose.palms.l.contact_weight) > .99, "contact-ready first lift sample has no pose drop")
	var mantle_middle := lift_start.duplicate(true); mantle_middle.progress=.45
	var mantle_pose: Dictionary = Pose.propose(mantle_middle)
	check(float(mantle_pose.palms.l.contact_weight) > .99 and mantle_pose.contact_window, "mantle hands remain loaded through early carry")
	var shore_middle := mantle_middle.duplicate(true); shore_middle.kind="shore"
	check(float(Pose.propose(shore_middle).palms.r.contact_weight) > .99, "shore hands remain loaded through early carry")
	var vault_middle := mantle_middle.duplicate(true); vault_middle.kind="vault"
	check(is_zero_approx(float(Pose.propose(vault_middle).palms.l.contact_weight)), "low vault releases hands after clearance")
	var vehicle_pose_sample := mantle_middle.duplicate(true); vehicle_pose_sample.support_kind="vehicle"; vehicle_pose_sample.support_id="compact_sedan:parked"
	var vehicle_pose: Dictionary = Pose.propose(vehicle_pose_sample)
	check(vehicle_pose.support_kind == "vehicle" and vehicle_pose.support_id == "compact_sedan:parked" and vehicle_pose.weapon_policy == "holster", "parked-car support identity reaches pose/weapon receipt")
	var right_lead := mantle_middle.duplicate(true); right_lead.lead_side="r"
	var right_pose: Dictionary = Pose.propose(right_lead)
	check(float(right_pose.legs.r.weight) > float(right_pose.legs.l.weight) and right_pose.feet.r.role == "lead", "stable right lead side swaps leg and foot roles")
	var settle_sample := mantle_middle.duplicate(true); settle_sample.progress=1.0; settle_sample.pose_stage="settle"; settle_sample.pose_stage_progress=.30
	var settle: Dictionary = Pose.propose(settle_sample)
	check(float(settle.landing.compression) > .95 and float(settle.pelvis.visual_offset_y_m) < -.05, "post-contact settle supplies compression and visual pelvis receipt")
	check(float(settle.feet.l.plant_weight) > .99 and float(settle.feet.r.plant_weight) > .99, "both landing feet stay planted during peak compression")
	for rig_height: float in [1.75, 1.9]:
		var scaled: Dictionary = Pose.propose(settle_sample, {"target_height_m":rig_height})
		check(scaled.valid and (scaled.feet.l.contact_world as Vector3).is_finite() and is_finite(float(scaled.pelvis.visual_offset_y_m)), "%.2fm rig metrics remain finite" % rig_height)
	var fixed := {"kind":"mantle", "progress":.35, "root_position":root, "direction":direction,
		"obstacle_height_m":1.2, "hand_l_world":Vector3(13,2,-7), "hand_r_world":Vector3(13,2,-6.5)}
	var fixed_pose: Dictionary = Pose.propose(fixed)
	check(fixed_pose.palms.l.contact_explicit and fixed_pose.palms.l.contact_world == fixed.hand_l_world, "explicit left hand anchor preserved")
	var unreachable := Pose.propose(fixed, {"shoulder_l_world":root + Vector3.UP, "arm_l_reach_m":.2})
	check(float(unreachable.palms.l.contact_weight) == 0.0, "unreachable contact released")
	check(not Pose.propose({"kind":"vault", "progress":NAN}).valid, "invalid progress rejected")
	var costs: Array[int] = []
	for _index in 12000:
		var started := Time.get_ticks_usec()
		Pose.propose(mantle_middle, {"target_height_m":1.9})
		costs.append(Time.get_ticks_usec()-started)
	costs.sort()
	print("TRAVERSAL_POSE_TEST ", JSON.stringify({"passed":failures.is_empty(), "checks":checks,
		"failures":failures, "sample_cpu_p50_us":costs[costs.size()/2], "sample_cpu_p95_us":costs[int(costs.size()*.95)],
		"scope":"pure animation/IK proposals; no rig or root writes, no LIVE claim"}))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
