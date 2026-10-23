extends SceneTree

const Descriptor = preload("res://scripts/traversal/ladder_descriptor.gd")
const Pose = preload("res://scripts/traversal/ladder_pose.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var descriptor: Dictionary = Descriptor.normalize({"id":"pose", "lower":Vector3(4,0,-2), "upper":Vector3(4,5,-3.9), "outward":Vector3(0,0,1)})
	var root := Vector3(4,2.4,-2)
	for direction: int in [1,-1]:
		var pose: Dictionary = Pose.propose(descriptor,{"root_position":root,"travelled_m":2.4,"direction":direction,"sliding":false,"mount_progress":1.0,"dismount_progress":0.0})
		check(pose.valid and pose.phase_name == ("climb-up" if direction>0 else "climb-down"), "directional climb phase")
		check(pose.weapon_policy == "holster" and not pose.root_owned and not pose.root_yaw_owned and not pose.collision_owned, "pose has explicit holster and no physical ownership")
		check(not pose.bone_translation_owned and not pose.bone_scale_owned, "pose never owns bone translation or scale")
		check(pose.contacts.hand_l.world is Vector3 and pose.contacts.hand_r.world is Vector3, "both hand targets remain finite rung contacts")
		var opposed_hands := 0
		var opposed_feet := 0
		var both_hands_released := 0
		var both_feet_released := 0
		for index in 113:
			var travelled := float(index) * float(descriptor.rung_spacing) / 56.0
			var sampled: Dictionary = Pose.propose(descriptor,{"root_position":root+Vector3.UP*travelled,"travelled_m":travelled,
				"direction":direction,"sliding":false,"mount_progress":1.0,"dismount_progress":0.0})
			var hl := float(sampled.contacts.hand_l.weight); var hr := float(sampled.contacts.hand_r.weight)
			var fl := float(sampled.contacts.foot_l.weight); var fr := float(sampled.contacts.foot_r.weight)
			if (hl >= .8 and hr <= .2) or (hr >= .8 and hl <= .2): opposed_hands += 1
			if (fl >= .8 and fr <= .2) or (fr >= .8 and fl <= .2): opposed_feet += 1
			if hl < .2 and hr < .2: both_hands_released += 1
			if fl < .2 and fr < .2: both_feet_released += 1
		check(opposed_hands > 0 and opposed_feet > 0, "left/right rung grip weights genuinely oppose in both directions")
		check(both_hands_released == 0 and both_feet_released == 0, "each limb pair retains a planted side during exchange")
	var slide: Dictionary = Pose.propose(descriptor,{"root_position":root,"travelled_m":2.4,"direction":-1,"sliding":true,"mount_progress":1.0,"dismount_progress":0.0})
	check(slide.phase_name == "slide" and is_equal_approx(float(slide.contacts.hand_l.world.y),float(slide.contacts.hand_r.world.y)), "slide hands share rail height")
	check(absf(float(slide.contacts.foot_l.world.x)-float(slide.contacts.foot_r.world.x)) < .15, "slide feet stay together")
	var mount: Dictionary = Pose.propose(descriptor,{"root_position":root,"travelled_m":0.0,"direction":1,"mount_progress":.5,"dismount_progress":0.0})
	var dismount: Dictionary = Pose.propose(descriptor,{"root_position":root,"travelled_m":5.0,"direction":1,"mount_progress":1.0,"dismount_progress":.5})
	check(mount.transition_phase == "mount" and float(mount.weight) > 0.0 and float(mount.weight) < 1.0, "mount smooth blend")
	check(dismount.transition_phase == "dismount" and float(dismount.weight) > 0.0 and float(dismount.weight) < 1.0, "dismount smooth blend")
	var unreachable: Dictionary = Pose.propose(descriptor,{"root_position":root,"travelled_m":1.0,"direction":1}, {"hand_l_anchor_world":Vector3(50,50,50),"hand_l_reach_m":.2})
	check(not unreachable.contacts.hand_l.available and is_zero_approx(float(unreachable.contacts.hand_l.weight)), "unreachable hand contact releases")
	var start := Time.get_ticks_usec()
	var sink := 0.0
	for index in 200000:
		var sample: Dictionary = Pose.propose(descriptor,{"root_position":Vector3(4,float(index%500)/100.0,-2),"travelled_m":float(index%500)/100.0,"direction":1 if index%2 else -1,"sliding":index%7==0})
		sink += float(sample.weight)
	var elapsed := Time.get_ticks_usec()-start
	check(is_finite(sink), "pose benchmark remains finite")
	print("LADDER_POSE_TEST ", JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"samples":200000,"elapsed_us":elapsed,"us_per_sample":float(elapsed)/200000.0,"scope":"pure pose proposals; no rig/root writes"}))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
