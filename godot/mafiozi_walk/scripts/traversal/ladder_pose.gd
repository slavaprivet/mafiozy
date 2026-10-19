class_name NativeLadderPose
extends RefCounted
## Detailed rung-locked pose proposal. It owns no root, collision or skeleton writes.


static func propose(descriptor: Dictionary, sample: Dictionary, rig: Dictionary = {}) -> Dictionary:
	if not bool(descriptor.get("valid", false)) or not sample.get("root_position") is Vector3:
		return _invalid("invalid_sample")
	var position: Vector3 = sample.root_position
	var travelled := float(sample.get("travelled_m", NAN))
	var direction := -1 if int(sample.get("direction", 1)) < 0 else 1
	var sliding := bool(sample.get("sliding", false))
	var mount := float(sample.get("mount_progress", 1.0))
	var dismount := float(sample.get("dismount_progress", 0.0))
	if not position.is_finite() or not is_finite(travelled) or not is_finite(mount) or not is_finite(dismount):
		return _invalid("invalid_sample")
	var enter := _smooth(mount)
	var exit := 1.0 - _smooth(dismount)
	var weight := enter * exit
	var phase := travelled / float(descriptor.rung_spacing) * PI * float(direction)
	var cycle := sin(phase)
	var width := maxf(.62, float(descriptor.width))
	var contacts := {"hand_l":{}, "hand_r":{}, "foot_l":{}, "foot_r":{}}
	if sliding:
		contacts.hand_l = _contact(_rail(descriptor, position, 1.0, 1.37, width, .38), 1.0, rig, "hand_l")
		contacts.hand_r = _contact(_rail(descriptor, position, -1.0, 1.37, width, .38), 1.0, rig, "hand_r")
		contacts.foot_l = _contact(_rail(descriptor, position, .13, .11, 1.0, .38), 1.0, rig, "foot_l")
		contacts.foot_r = _contact(_rail(descriptor, position, -.13, .11, 1.0, .38), 1.0, rig, "foot_r")
	else:
		# A half-rung offset makes the two sides genuinely oppose one another.
		# Integer offsets only selected different rung targets while preserving the
		# same fractional contact weight, so both hands released together.
		var hand_l_offset := .5 if direction < 0 else 0.0
		var hand_r_offset := 0.0 if direction < 0 else .5
		contacts.hand_l = _rung_contact(descriptor, position, width * .2, 1.35, hand_l_offset, .3, rig, "hand_l")
		contacts.hand_r = _rung_contact(descriptor, position, -width * .2, 1.35, hand_r_offset, .3, rig, "hand_r")
		contacts.foot_l = _rung_contact(descriptor, position, width * .15, .18, hand_r_offset, .1, rig, "foot_l")
		contacts.foot_r = _rung_contact(descriptor, position, -width * .15, .18, hand_l_offset, .1, rig, "foot_r")
	for key: String in contacts:
		contacts[key].weight = float(contacts[key].weight) * weight
	var rotations := {"chest":Vector3(.055 if sliding else .12,0,0), "neck":Vector3(-.035 if sliding else -.075,0,0), "head":Vector3(-.045 if sliding else -.085,0,0)}
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var limb := cycle * sign * float(direction)
		if sliding:
			rotations["upperarm_"+side] = Vector3(-1.72,0,sign*.08)
			rotations["forearm_"+side] = Vector3(-.36,0,0)
			rotations["thigh_"+side] = Vector3(-.18,0,sign*.025)
			rotations["shin_"+side] = Vector3(.3,0,0)
			rotations["foot_"+side] = Vector3(-.08,0,0)
		else:
			rotations["upperarm_"+side] = Vector3(-1.66-limb*.2,0,sign*.075)
			rotations["forearm_"+side] = Vector3(-.43+limb*.09,0,0)
			rotations["thigh_"+side] = Vector3(-.48+limb*.31,0,sign*.045)
			rotations["shin_"+side] = Vector3(.7-limb*.3,0,0)
			rotations["foot_"+side] = Vector3(-.1+limb*.08,0,0)
	var phase_name := "slide" if sliding else "climb-up" if direction > 0 else "climb-down"
	var transition_phase := "dismount" if dismount > 0.0 else "mount" if mount < 1.0 else "attached"
	return {"provider":"GODOT_LADDER_POSE_V1", "valid":true, "reason":"valid", "phase_name":phase_name,
		"transition_phase":transition_phase, "phase":phase, "direction":direction, "sliding":sliding,
		"weight":weight, "root_position":position, "requested_yaw_rad":float(descriptor.yaw_rad),
		"root_owned":false, "root_yaw_owned":false, "collision_owned":false,
		"bone_translation_owned":false, "bone_scale_owned":false, "weapon_policy":"holster",
		"rotations":rotations, "contacts":contacts}


static func _rung_contact(descriptor: Dictionary, position: Vector3, side: float, nominal_height: float,
		phase_offset: float, depth: float, rig: Dictionary, key: String) -> Dictionary:
	var spacing := float(descriptor.rung_spacing)
	var base := (descriptor.lower as Vector3).y + .18
	var relative := (position.y + nominal_height - base) / spacing + phase_offset
	var rung := roundi(relative)
	var normal: Vector3 = descriptor.normal
	var right: Vector3 = descriptor.right
	var target: Vector3 = position - normal * depth + right * side
	target.y = base + float(rung) * spacing
	var fraction: float = relative - floor(relative)
	var weight := _smooth_range(absf(fraction - .5), .035, .16)
	return _contact(target, weight, rig, key)


static func _rail(descriptor: Dictionary, position: Vector3, side: float, height: float, width: float, depth: float) -> Vector3:
	return position - descriptor.normal * depth + descriptor.right * side * width * .5 + Vector3.UP * height


static func _contact(target: Vector3, weight: float, rig: Dictionary, key: String) -> Dictionary:
	var available := target.is_finite()
	var anchor_key := key + "_anchor_world"
	var reach_key := key + "_reach_m"
	if available and rig.get(anchor_key) is Vector3 and is_finite(float(rig.get(reach_key, INF))):
		available = (rig[anchor_key] as Vector3).distance_to(target) <= float(rig[reach_key])
	return {"available":available, "world":target, "weight":weight if available else 0.0}


static func _smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t*t*(3.0-2.0*t)


static func _smooth_range(value: float, minimum: float, maximum: float) -> float:
	return _smooth((value-minimum)/maxf(.000001,maximum-minimum))


static func _invalid(reason: String) -> Dictionary:
	return {"provider":"GODOT_LADDER_POSE_V1", "valid":false, "reason":reason,
		"root_owned":false, "root_yaw_owned":false, "collision_owned":false,
		"bone_translation_owned":false, "bone_scale_owned":false, "weapon_policy":"external"}
