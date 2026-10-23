extends RefCounted

# Source findHoodInteraction/findTrunkInteraction. Profiles are exact output
# from vehicle_compartments.access_profile(), never inferred from body bounds.
static func query(kind: String, profile: Dictionary, vehicle_transform: Transform3D, actor_feet: Vector3, signed_speed: float, context: Dictionary = {}) -> Dictionary:
	if kind not in ["hood", "trunk"] or not actor_feet.is_finite() or not vehicle_transform.origin.is_finite() or not is_finite(signed_speed): return {}
	if not vehicle_transform.basis.x.is_finite() or not vehicle_transform.basis.y.is_finite() or not vehicle_transform.basis.z.is_finite(): return {}
	if absf(vehicle_transform.basis.determinant()-1.0) > .001 or absf(vehicle_transform.basis.x.length_squared()-1.0) > .001 or absf(vehicle_transform.basis.y.length_squared()-1.0) > .001 or absf(vehicle_transform.basis.z.length_squared()-1.0) > .001: return {}
	if context.get("occupied", false) or context.get("transition", false) or context.get("blocked", false) or context.get("destroying", false) or context.get("wrecked", false) or absf(signed_speed) > .5: return {}
	if kind == "trunk" and context.get("detached", false): return {}
	for key in ["width", "handleY", "accessZ" if kind == "hood" else "rearZ"]:
		var value: Variant = profile.get(key)
		if not (value is float or value is int) or not is_finite(float(value)): return {}
	if float(profile.width) <= 0.0: return {}
	var supplied_side: Variant = profile.get("accessSide", 0.0)
	var supplied_amount: Variant = context.get("amount", 0.0)
	if not (supplied_side is float or supplied_side is int) or not (supplied_amount is float or supplied_amount is int): return {}
	if not is_finite(float(supplied_amount)): return {}
	var side_offset := float(supplied_side) if kind == "hood" else 0.0
	if not is_finite(side_offset): return {}
	var forward := (-vehicle_transform.basis.z).slide(Vector3.UP)
	if forward.length_squared() < .000001: return {}
	var yaw := atan2(-forward.x, -forward.z)
	# Walk source planar metric ignores pitch/roll and handle height. Native
	# source basis wrapper flips local X/Z; actual handle uses full transform.
	var delta := actor_feet - vehicle_transform.origin
	var native_side := delta.x * cos(yaw) - delta.z * sin(yaw)
	var native_front := delta.x * sin(yaw) + delta.z * cos(yaw)
	var side := -native_side; var front := -native_front
	var plane := float(profile.accessZ) if kind == "hood" else float(profile.rearZ)
	var sign_out := (1.0 if profile.get("front", true) else -1.0) if kind == "hood" else -1.0
	if (front-plane)*sign_out < .10 - .0000001: return {}
	if absf(side) > float(profile.width)*.5 + (.30 if kind == "hood" else .32): return {}
	if absf(delta.y) > 1.8: return {}
	var near := Vector2(side-side_offset, front-plane).length()
	if near > (1.5 if kind == "hood" else 1.45): return {}
	var detached := bool(context.get("detached", false))
	var action := "repair" if detached else ("close" if context.get("target_open", false) else "open")
	return {"kind":kind, "near":near, "action":action, "sector_anchor_m":vehicle_transform * Vector3(-side_offset,float(profile.handleY),-plane), "anchor_scope":"sector_only_visual_handle_owned_by_root", "repair_available":kind == "hood" and (float(context.get("amount", 0.0)) >= .9 or detached) and absf(signed_speed) <= .2}
