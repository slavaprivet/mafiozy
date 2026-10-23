extends RefCounted
## Source parking dimensions are in navigation cells (4.1 metres per cell).
## This is only the source geometric prefilter; exit/navigation authority remains external.
const METRES_PER_CELL := 4.1
const SOURCE_FIT_FACTOR := 8.2
const SOURCE_FIT_SLACK_M := .05
const SOURCE_OVERLAP_SLACK_CELLS := .035

func source_slot_from_bay(bay: Dictionary) -> Dictionary:
	if not _number(bay.get("yaw_rad")) or not _number(bay.get("width_m")) or not _number(bay.get("length_m")) or not bay.get("position_m") is Dictionary:
		return {}
	var position: Dictionary = bay.position_m
	if not _number(position.get("x")) or not _number(position.get("z")) or float(bay.width_m) <= 0.0 or float(bay.length_m) <= 0.0:
		return {}
	return {"r": float(position.z) / METRES_PER_CELL, "c": float(position.x) / METRES_PER_CELL,
		"angle": PI * 1.5 - float(bay.yaw_rad), "widthM": float(bay.width_m), "lengthM": float(bay.length_m),
		"id": bay.get("parking_id", ""), "lotId": bay.get("lot_id", "")}

func source_bay_fits(half_length_cells: float, half_width_cells: float, slot: Dictionary) -> bool:
	if not is_finite(half_length_cells) or not is_finite(half_width_cells) or half_length_cells <= 0.0 or half_width_cells <= 0.0 or not _number(slot.get("lengthM")) or not _number(slot.get("widthM")):
		return false
	return half_length_cells * SOURCE_FIT_FACTOR <= float(slot.lengthM) + SOURCE_FIT_SLACK_M and half_width_cells * SOURCE_FIT_FACTOR <= float(slot.widthM) + SOURCE_FIT_SLACK_M

func source_boxes_overlap(a: Dictionary, b: Dictionary) -> Dictionary:
	if not _valid_box(a) or not _valid_box(b): return {"code": "INVALID", "overlap": true}
	var dr: float = float(b.r) - float(a.r)
	var dc: float = float(b.c) - float(a.c)
	for angle in [float(a.angle), float(a.angle) + PI * .5, float(b.angle), float(b.angle) + PI * .5]:
		var sr: float = sin(angle)
		var sc: float = cos(angle)
		var projection: float = absf(dr * sr + dc * sc)
		var a_extent: float = absf(cos(float(a.angle) - angle)) * float(a.halfLength) + absf(sin(float(a.angle) - angle)) * float(a.halfWidth)
		var b_extent: float = absf(cos(float(b.angle) - angle)) * float(b.halfLength) + absf(sin(float(b.angle) - angle)) * float(b.halfWidth)
		if projection > a_extent + b_extent + SOURCE_OVERLAP_SLACK_CELLS:
			return {"code": "OK", "overlap": false}
	return {"code": "OK", "overlap": true}

func _valid_box(value: Dictionary) -> bool:
	for field in ["r", "c", "angle", "halfLength", "halfWidth"]:
		if not _number(value.get(field)): return false
	return float(value.halfLength) > 0.0 and float(value.halfWidth) > 0.0

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
