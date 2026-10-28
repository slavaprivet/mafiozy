extends SceneTree

const Air = preload("res://scripts/traversal/traversal_airborne_pose.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var short: Dictionary = Air.propose({"grounded":false,"vertical_speed_mps":-1.0,
		"fall_distance_m":.2,"airborne_age_s":.12,"landing_age_s":0.0,"impact_speed_mps":0.0})
	var medium: Dictionary = Air.propose({"grounded":false,"vertical_speed_mps":-6.0,
		"fall_distance_m":1.4,"airborne_age_s":.45,"landing_age_s":0.0,"impact_speed_mps":0.0})
	var fast: Dictionary = Air.propose({"grounded":false,"vertical_speed_mps":-12.0,
		"fall_distance_m":4.0,"airborne_age_s":1.1,"landing_age_s":0.0,"impact_speed_mps":0.0})
	check(short.valid and medium.valid and fast.valid, "finite fall receipts valid")
	check(float(short.long_fall_blend) < float(medium.long_fall_blend) and float(medium.long_fall_blend) < float(fast.long_fall_blend), "pose responds continuously to real downward speed/distance")
	check(medium.phase == "fall" or medium.phase == "long_fall", "medium fall has airborne phase")
	check(fast.phase == "long_fall" and fast.weapon_policy == "holster", "long fall holsters weapon")
	check(float(fast.arms.stream_back_rad) > float(medium.arms.stream_back_rad), "faster fall does not freeze at ordinary-jump pose")
	check(fast.character_physics_input.authority_owned == false, "receipt never steals character-physics authority")

	var first_contact: Dictionary = Air.propose({"grounded":true,"vertical_speed_mps":0.0,
		"fall_distance_m":4.0,"airborne_age_s":1.1,"landing_age_s":0.0,"impact_speed_mps":12.0})
	var low_impact: Dictionary = Air.propose({"grounded":true,"vertical_speed_mps":0.0,
		"fall_distance_m":.6,"airborne_age_s":.3,"landing_age_s":.08,"impact_speed_mps":3.0})
	var high_impact: Dictionary = Air.propose({"grounded":true,"vertical_speed_mps":0.0,
		"fall_distance_m":4.0,"airborne_age_s":1.1,"landing_age_s":.08,"impact_speed_mps":12.0})
	check(is_zero_approx(float(first_contact.landing_compression)), "first supported landing frame is pose-continuous")
	check(float(high_impact.landing_compression) > float(low_impact.landing_compression), "landing compression scales with admitted impact speed")
	check(float(high_impact.pelvis.visual_offset_y_m) < float(low_impact.pelvis.visual_offset_y_m), "high impact requests deeper visual pelvis compression")
	check(high_impact.feet.max_slip_m == .02 and high_impact.head.clearance_required_m == .02, "landing exposes feet/head quality receipts")
	var idle: Dictionary = Air.propose({"grounded":true,"vertical_speed_mps":0.0,
		"fall_distance_m":4.0,"airborne_age_s":1.1,"landing_age_s":.45,"impact_speed_mps":12.0})
	check(idle.phase == "idle" and idle.weapon_policy == "restore" and idle.weapon_restore_on_terminal, "clean terminal restores weapon once")

	for rig_height: float in [1.75,1.9]:
		var scaled: Dictionary = Air.propose({"grounded":true,"vertical_speed_mps":0.0,
			"fall_distance_m":4.0,"airborne_age_s":1.1,"landing_age_s":.08,"impact_speed_mps":12.0}, {"target_height_m":rig_height})
		check(scaled.valid and is_finite(float(scaled.pelvis.visual_offset_y_m)), "%.2fm rig receipt finite" % rig_height)

	var final_60 := _analytic_partition(1.0/60.0, 1.2)
	var final_30 := _analytic_partition(1.0/30.0, 1.2)
	var final_15 := _analytic_partition(1.0/15.0, 1.2)
	check(absf(float(final_60.long_fall_blend)-float(final_30.long_fall_blend)) < .000001 and absf(float(final_60.long_fall_blend)-float(final_15.long_fall_blend)) < .000001, "60/30/15Hz analytic partitions end on identical fall blend")
	check(final_60.phase == final_30.phase and final_60.phase == final_15.phase, "frame-rate partitions preserve phase")
	check(not Air.propose({"grounded":false,"vertical_speed_mps":NAN,"fall_distance_m":1.0,"airborne_age_s":1.0}).valid, "non-finite fall fails closed")

	var costs: Array[int] = []
	for index in 12000:
		var started := Time.get_ticks_usec()
		Air.propose({"grounded":false,"vertical_speed_mps":-8.0,"fall_distance_m":2.8,
			"airborne_age_s":.7,"landing_age_s":0.0,"impact_speed_mps":0.0})
		costs.append(Time.get_ticks_usec()-started)
	costs.sort()
	print("TRAVERSAL_AIRBORNE_POSE_TEST ", JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"sample_cpu_p50_us":costs[costs.size()/2],"sample_cpu_p95_us":costs[int(costs.size()*.95)],
		"scope":"pure traversal fall/landing pose receipts; no gravity, rig writes, character-physics authority, LIVE or FPS"}))
	quit(0 if failures.is_empty() else 1)


func _analytic_partition(delta_s: float, duration_s: float) -> Dictionary:
	var elapsed := 0.0
	var result: Dictionary = {}
	while elapsed < duration_s - .000001:
		elapsed = minf(duration_s, elapsed + delta_s)
		var speed := -9.8 * elapsed
		var distance := .5 * 9.8 * elapsed * elapsed
		result = Air.propose({"grounded":false,"vertical_speed_mps":speed,"fall_distance_m":distance,
			"airborne_age_s":elapsed,"landing_age_s":0.0,"impact_speed_mps":0.0})
	return result


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
