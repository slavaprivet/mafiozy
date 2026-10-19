extends RefCounted

# Invoke after frame_post_draw: measures displayed weapon and current bones,
# independently of cached _sword_origin/_dir and the attachment's tautological error.
static func sample(sword: Node) -> Dictionary:
	var rig: Skeleton3D = sword.get("_rig")
	var model: Node3D = sword.get("_sword")
	var root: Transform3D = model.global_transform
	var a: Vector3 = root.origin
	var b: Vector3 = root * Vector3(0.06 + float(sword.get("_weapon_length")), 0, 0)
	var chest := _bone(rig, int(sword.get("_bone_chest")))
	var pelvis := _bone(rig, int(sword.get("_bone_pelvis")))
	var head := _bone(rig, int(sword.get("_bone_head")))
	var result := {"display_body_clearance": distance(a,b,chest,pelvis),
		"display_head_clearance": distance(a,b,head,head),
		"self_pose_clear": sword.get("_self_pose_clear"),
		"side": str(sword.call("_active_side")), "held": sword.get("_held")}
	for side in [&"right", &"left"]:
		var arm: Dictionary = sword.call("_arm_set", side)
		var hand: int = arm.hand
		var socket_name := "socket_hand_l" if rig.get_bone_name(hand) == "hand_l" else "socket_hand_r"
		var socket: int = rig.find_bone(socket_name)
		var palm: Vector3 = rig.global_transform * (rig.get_bone_global_pose(hand) * rig.get_bone_rest(socket).origin)
		var elbow := _bone(rig, int(arm.fore))
		var wrist := _bone(rig, hand)
		var local_palm := root.affine_inverse() * palm
		result[str(side) + "_handle_x"] = local_palm.x
		result[str(side) + "_handle_radial"] = Vector2(local_palm.y, local_palm.z).length()
		result[str(side) + "_forearm_torso_distance"] = distance(elbow,wrist,chest,pelvis)
		result[str(side) + "_palm_torso_distance"] = distance(palm,palm,chest,pelvis)
	return result

static func _bone(rig: Skeleton3D, index: int) -> Vector3:
	return rig.global_transform * rig.get_bone_global_pose(index).origin

static func distance(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float:
	var u := a1-a0
	var v := b1-b0
	var r := a0-b0
	var a := u.dot(u)
	var e := v.dot(v)
	var f := v.dot(r)
	var s := 0.0
	var t := 0.0
	if a < 1e-8 and e < 1e-8: return a0.distance_to(b0)
	if a < 1e-8: t = clampf(f/e, 0, 1)
	else:
		var c := u.dot(r)
		if e < 1e-8: s = clampf(-c/a, 0, 1)
		else:
			var cross := u.dot(v)
			var den := a*e-cross*cross
			if den > 1e-8: s = clampf((cross*f-c*e)/den, 0, 1)
			t = (cross*s+f)/e
			if t < 0: t=0; s=clampf(-c/a,0,1)
			elif t > 1: t=1; s=clampf((cross-c)/a,0,1)
	return (a0+u*s).distance_to(b0+v*t)
