class_name NativeLadderDescriptor
extends RefCounted
## Pure World roof-ladder descriptor normalization. All values are Godot metres.

const DEFAULT_WIDTH_M := .8
const DEFAULT_RUNG_SPACING_M := .28
const MIN_WIDTH_M := .65
const MAX_WIDTH_M := 1.5
const MIN_RUNG_SPACING_M := .18
const MAX_RUNG_SPACING_M := .4
const MIN_HEIGHT_M := 2.0
const MIN_LANDING_INSET_M := .35
const CREST_RISE_M := .12
const STEP_OFF_M := .75


static func normalize(value: Dictionary) -> Dictionary:
	var lower_result := _vector(value.get("lower"))
	var upper_result := _vector(value.get("upper"))
	if not lower_result.valid or not upper_result.valid:
		return _invalid("invalid_endpoints")
	var lower: Vector3 = lower_result.value
	var upper: Vector3 = upper_result.value
	if upper.y - lower.y < MIN_HEIGHT_M:
		return _invalid("ladder_too_short")
	var width := float(value.get("width", DEFAULT_WIDTH_M))
	var rung_spacing := float(value.get("rung_spacing", value.get("rungSpacing", DEFAULT_RUNG_SPACING_M)))
	if not is_finite(width) or width < MIN_WIDTH_M or width > MAX_WIDTH_M:
		return _invalid("invalid_width")
	if not is_finite(rung_spacing) or rung_spacing < MIN_RUNG_SPACING_M or rung_spacing > MAX_RUNG_SPACING_M:
		return _invalid("invalid_rung_spacing")
	var normal_result := _vector(value.get("normal", value.get("outward")))
	if not normal_result.valid:
		return _invalid("invalid_normal")
	var normal: Vector3 = normal_result.value
	normal.y = 0.0
	if normal.length_squared() < .000001:
		return _invalid("invalid_normal")
	normal = normal.normalized()
	if Vector2(lower.x - upper.x, lower.z - upper.z).dot(Vector2(normal.x, normal.z)) < MIN_LANDING_INSET_M:
		return _invalid("landing_not_inward")
	var right := Vector3(normal.z, 0.0, -normal.x)
	var crest := Vector3(lower.x, upper.y + CREST_RISE_M, lower.z)
	var landing := Vector3(upper.x, upper.y + CREST_RISE_M, upper.z)
	var route: Array[Vector3] = [lower, crest, landing, upper]
	var route_exclude_rids: Array[RID] = _rid_array(value.get("route_exclude_rids", []))
	return {
		"valid": true,
		"reason": "valid",
		"id": str(value.get("id", "roof-ladder")),
		"lower": lower,
		"upper": upper,
		"normal": normal,
		"right": right,
		"width": width,
		"rung_spacing": rung_spacing,
		"yaw_rad": atan2(-normal.x, -normal.z),
		"path": route,
		"step_off_point": upper - normal * STEP_OFF_M,
		"aperture_width_m": maxf(1.0, width + .3),
		"route_exclude_rids": route_exclude_rids,
	}


static func _vector(value: Variant) -> Dictionary:
	var result := Vector3.ZERO
	if value is Vector3:
		result = value
	elif value is Vector2:
		result = Vector3(value.x, 0.0, value.y)
	elif value is Dictionary and value.has("x") and value.has("z"):
		result = Vector3(float(value.x), float(value.get("y", 0.0)), float(value.z))
	else:
		return {"valid": false, "value": Vector3.ZERO}
	return {"valid": result.is_finite(), "value": result}


static func _rid_array(value: Variant) -> Array[RID]:
	var result: Array[RID] = []
	if value is Array:
		for item: Variant in value:
			if item is RID and (item as RID).is_valid() and not result.has(item):
				result.append(item)
	return result


static func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
