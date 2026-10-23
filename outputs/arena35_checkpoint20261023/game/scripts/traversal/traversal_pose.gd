class_name NativeTraversalPose
extends RefCounted
## Pure pose/IK proposal for vault, mantle and shore motion. The rig host owns
## base-pose reset, bone rotations, IK and all root/collision transforms.

const PROVIDER := "GODOT_TRAVERSAL_POSE_V1"
const SOURCE_HEIGHT_M := 1.9


static func propose(sample: Dictionary, rig: Dictionary = {}) -> Dictionary:
	var progress := float(sample.get("progress", NAN))
	var kind := str(sample.get("kind", ""))
	if not is_finite(progress) or kind not in ["vault", "mantle", "shore"]:
		return {"valid": false, "reason": "invalid_sample"}
	var root: Vector3 = sample.get("root_position", sample.get("start", Vector3.ZERO))
	var direction: Vector3 = sample.get("direction", Vector3.ZERO)
	if not root.is_finite() or not direction.is_finite():
		return {"valid": false, "reason": "invalid_vectors"}
	direction.y = 0.0
	if direction.length_squared() < .00000001:
		var yaw := float(sample.get("yaw_rad", 0.0))
		direction = Vector3(-sin(yaw), 0.0, -cos(yaw))
	direction = direction.normalized()
	var right := Vector3(direction.z, 0.0, -direction.x)
	var p := clampf(progress, 0.0, 1.0)
	var stage := str(sample.get("pose_stage", "traverse"))
	if stage not in ["reach", "traverse", "settle"]:
		return {"valid": false, "reason": "invalid_pose_stage"}
	var stage_progress := clampf(float(sample.get("pose_stage_progress", 0.0)), 0.0, 1.0)
	var target_height := float(rig.get("target_height_m", SOURCE_HEIGHT_M))
	if not is_finite(target_height) or target_height <= 0.0:
		return {"valid": false, "reason": "invalid_rig_height"}
	var unit := target_height / SOURCE_HEIGHT_M
	var obstacle_height := float(sample.get("obstacle_height_m", sample.get("rise_m", .8)))
	if not is_finite(obstacle_height):
		obstacle_height = .8
	var normalized_height := clampf(obstacle_height / unit, .15, 1.85)
	var vault := kind == "vault"
	var shore := kind == "shore"
	var contact_ready := bool(sample.get("contact_ready", false))
	var compression := 0.0
	if stage == "settle":
		compression = _smooth(0.0, .30, stage_progress) * (1.0 - _smooth(.48, 1.0, stage_progress))
	var weight := 0.0
	if stage == "reach":
		weight = _smooth(0.0, 1.0, stage_progress)
	elif stage == "settle":
		weight = compression
	else:
		var fade_start := .68 if vault else .82
		weight = (1.0 if contact_ready else _smooth(0.0, .22, p)) * (1.0 - _smooth(fade_start, 1.0, p))
	var pull := _smooth(.12, .52, p)
	var over := _smooth(.36, .77, p)
	var chest := (.35 if vault else .22) + over * .2
	if stage == "reach":
		chest = (.22 if vault else .16) * weight
	elif stage == "settle":
		chest = .30 * compression
	var palms := {}
	for side: String in ["l", "r"]:
		var sign_value := -1.0 if side == "l" else 1.0
		palms[side] = _palm_proposal(side, sign_value, root, direction, right, unit,
			vault, shore, pull, over, p, stage, stage_progress, sample, rig)
	var lead_side := str(sample.get("lead_side", "l"))
	if lead_side not in ["l", "r"]:
		lead_side = "l"
	var lead_fold := 0.0 if stage == "reach" else (.78 * compression if stage == "settle" else _leg_fold(p, true))
	var trail_fold := 0.0 if stage == "reach" else (.72 * compression if stage == "settle" else _leg_fold(p, false))
	var left_fold := lead_fold if lead_side == "l" else trail_fold
	var right_fold := trail_fold if lead_side == "l" else lead_fold
	var destination_value: Variant = sample.get("destination_position", sample.get("destination_feet", root))
	var destination := destination_value as Vector3 if destination_value is Vector3 else root
	if not destination.is_finite(): destination = root
	var feet := {
		"l": _foot_proposal("l", lead_side == "l", destination, direction, right, unit, p, stage, stage_progress),
		"r": _foot_proposal("r", lead_side == "r", destination, direction, right, unit, p, stage, stage_progress),
	}
	var contact_window := float(palms.l.contact_weight) > 0.0 or float(palms.r.contact_weight) > 0.0
	return {
		"provider": PROVIDER,
		"valid": true,
		"reason": "proposal",
		"kind": kind,
		"progress": p,
		"pose_stage": stage,
		"pose_stage_progress": stage_progress,
		"weight": weight,
		"root_position": root,
		"root_yaw_owned": false,
		"collision_owned": false,
		"spine": {"chest_pitch_rad": chest, "neck_pitch_rad": -chest * .55, "head_pitch_rad": -chest * .35},
		"legs": {
			"l": _leg_angles(left_fold, true, vault),
			"r": _leg_angles(right_fold, false, vault),
		},
		"palms": palms,
		"feet": feet,
		"lead_side": lead_side,
		"support_kind": str(sample.get("support_kind", "static")),
		"support_id": str(sample.get("support_id", "")),
		"contact_window": contact_window,
		"pelvis": {"root_owned": false, "visual_offset_y_m": -.065 * unit * compression,
			"clearance_required_m": .03, "clearance_receipt_required": stage != "reach",
			"edge_crossed":stage == "settle" or (stage == "traverse" and p >= .52)},
		"head": {"clearance_required_m": .02, "clearance_receipt_required": true},
		"landing": {"compression": compression, "contact_pending": stage == "traverse" and p < 1.0,
			"settle_duration_s": .28, "max_foot_slip_m": .02},
		"weapon_policy": "holster",
		"weapon_restore_on_terminal": true,
		"obstacle_height_m": obstacle_height,
		"normalized_obstacle_height": normalized_height,
	}


static func _leg_fold(progress: float, lead: bool) -> float:
	var tuck := _smooth(.07 if lead else .2, .42 if lead else .55, progress)
	var unfold := 1.0 - _smooth(.53 if lead else .64, .94, progress)
	return tuck * unfold


static func _leg_angles(fold: float, left: bool, vault: bool) -> Dictionary:
	return {
		"weight": fold,
		"thigh_pitch_rad": -(1.32 if vault else 1.52) * fold,
		"thigh_roll_rad": (-.1 if left else .1) * fold,
		"shin_pitch_rad": (1.7 if vault else 1.92) * fold,
		"foot_pitch_rad": -.28 * fold,
	}


static func _palm_proposal(side: String, sign_value: float, root: Vector3, direction: Vector3,
		right: Vector3, unit: float, vault: bool, shore: bool, pull: float, over: float,
		progress: float, stage: String, stage_progress: float, sample: Dictionary, rig: Dictionary) -> Dictionary:
	var palm_height := (1.08 if vault else 1.27 + float(sample.get("normalized_obstacle_height", sample.get("obstacle_height_m", .8))) * .14) - pull * (.42 if shore else .32)
	var palm_depth := .43 - over * .24
	var fallback := root + direction * (palm_depth * unit) + right * (sign_value * .27 * unit) + Vector3.UP * (palm_height * unit)
	var explicit_key := "hand_l_world" if side == "l" else "hand_r_world"
	var explicit: Variant = sample.get(explicit_key)
	var contact := Vector3.ZERO
	var explicit_valid := explicit is Vector3 and (explicit as Vector3).is_finite()
	var edge: Variant = sample.get("edge_position", sample.get("edge"))
	var edge_valid := edge is Vector3 and (edge as Vector3).is_finite()
	if explicit_valid:
		contact = explicit
	elif edge_valid:
		contact = (edge as Vector3) + Vector3.UP * (.025 * unit) + right * (sign_value * .27 * unit) + direction * (.025 * unit)
	var contact_weight := 0.0
	if explicit_valid or edge_valid:
		if stage == "reach":
			contact_weight = _smooth(0.0, 1.0, stage_progress)
		elif stage == "settle":
			contact_weight = 0.0
		elif explicit_valid:
			contact_weight = 1.0
		elif vault:
			contact_weight = 1.0 - _smooth(.18, .4, progress)
		else:
			# Mantle and shore hands bear weight until the pelvis has crossed the
			# edge.  Release only near the end of carry, before physical landing.
			contact_weight = 1.0 - _smooth(.64, .82, progress)
		var shoulder_key := "shoulder_%s_world" % side
		var reach_key := "arm_%s_reach_m" % side
		var shoulder: Variant = rig.get(shoulder_key)
		var reach := float(rig.get(reach_key, NAN))
		if shoulder is Vector3 and (shoulder as Vector3).is_finite() and is_finite(reach) and reach > 0.0:
			var distance := (shoulder as Vector3).distance_to(contact)
			var near_ratio := .86 if explicit_valid else .3
			contact_weight *= 1.0 - _smooth(reach * near_ratio, reach * .995, distance)
		var above_feet := 1.0 - _smooth(.35 * unit, .8 * unit, root.y + .8 * unit - contact.y)
		contact_weight *= above_feet
	return {"side": side, "fallback_world": fallback, "contact_world": contact,
		"contact_available": explicit_valid or edge_valid, "contact_explicit": explicit_valid,
		"contact_weight": clampf(contact_weight, 0.0, 1.0), "palm_pitch_rad": -PI * .5}


static func _foot_proposal(side: String, lead: bool, destination: Vector3, direction: Vector3,
		right: Vector3, unit: float, progress: float, stage: String, stage_progress: float) -> Dictionary:
	var sign_value := -1.0 if side == "l" else 1.0
	var target := destination + right * (sign_value * .115 * unit) + direction * ((.055 if lead else -.035) * unit)
	var plant_weight := 0.0
	if stage == "settle":
		plant_weight = 1.0 - _smooth(.72, 1.0, stage_progress)
	elif stage == "traverse":
		plant_weight = _smooth(.82, 1.0, progress)
	return {"side":side, "role":"lead" if lead else "trail", "contact_world":target,
		"contact_available":true, "plant_weight":plant_weight, "max_slip_m":.02}


static func _smooth(start: float, finish: float, value: float) -> float:
	var t := clampf((value - start) / (finish - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
