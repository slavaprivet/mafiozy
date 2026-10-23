extends RefCounted

const WATER_EXIT_SOURCE_SHA256 := "531fc5b01dd1ad6ce2fda5b8aac76688cf5f1888fc4f05610a7ef176c259a860"
const SEATS_SOURCE_SHA256 := "1e6b2178bee7ed6ec51ecbb5d99e13772942c8fb71a2f3cc7579ad2aa3537779"
const ENTRY_SOURCE_SHA256 := "342a3f959cd7d82bfa5759f1706d6471bc32998fdb49be79361a2556ab3245b6"
const DESCRIPTORS_SHA256 := "99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a"
const VISUAL_EXPORTER_SHA256 := "7e6c2f9b23bc47e17a28da84b6279214949b729a2b49255c42fa18c45a5d4f47"
const DESCRIPTOR_EXPORTER_SHA256 := "766f6df08c622565413a17e31e3b09341981455918f94c006e665e2ea0b6d53c"
const CATALOG_SHA256 := "85614568d1a4b23391618e84e8de250c9b872a9215353734d3f7e1f7638d3e97"
const SEAT_IDS := [&"front_left", &"front_right", &"rear_left", &"rear_right"]

static func water_departure_point(vehicle_transform: Transform3D, seat: Dictionary, distance: float, progress: float) -> Dictionary:
	var common := _validate(vehicle_transform, seat)
	if not bool(common.ok): return common
	if not is_finite(distance) or not is_finite(progress): return _error("PROGRESS_OR_DISTANCE")
	var p := clampf(progress, 0.0, 1.0)
	var seat_blend := _smooth(((1.0 - p) - .25) / .5)
	var anchor: Vector3 = common.anchor
	var approach: Vector3 = common.approach
	# Descriptors store the source's 1.9 m candidate. Its second candidate is
	# another .5 m along source side; native X is source-side negated.
	approach.x -= float(common.source_side) * (distance - 1.9)
	var local := approach.lerp(anchor, seat_blend)
	# Source discards the dry doorway arc and preserves the seat-root height.
	local.y = anchor.y
	return _receipt(vehicle_transform, seat, local, {"progress": p, "seat_blend": seat_blend})

static func water_seat_point(vehicle_transform: Transform3D, seat: Dictionary) -> Dictionary:
	var common := _validate(vehicle_transform, seat)
	if not bool(common.ok): return common
	return _receipt(vehicle_transform, seat, common.anchor, {})

static func _receipt(vehicle_transform: Transform3D, seat: Dictionary, local: Vector3, extra: Dictionary) -> Dictionary:
	var world := vehicle_transform * local
	if not _finite3(world): return _error("WORLD_TRANSFORM")
	var out := {"ok": true, "seat_id": StringName(seat.id), "door_id": StringName(seat.door_id), "local_position_m": local, "world_position_m": world}
	out.merge(extra)
	return out

static func _validate(vehicle_transform: Transform3D, seat: Dictionary) -> Dictionary:
	if not _finite_transform(vehicle_transform): return _error("VEHICLE_TRANSFORM")
	var seat_id_value: Variant = seat.get("id"); var door_id_value: Variant = seat.get("door_id")
	if typeof(seat_id_value) not in [TYPE_STRING, TYPE_STRING_NAME] or typeof(door_id_value) not in [TYPE_STRING, TYPE_STRING_NAME]: return _error("SEAT_ID_TYPE")
	var seat_id := StringName(seat_id_value); var door_id := StringName(door_id_value)
	if seat_id not in SEAT_IDS or door_id != seat_id: return _error("SEAT_ID")
	var anchor_value: Variant = seat.get("anchor_local_m"); var approach_value: Variant = seat.get("approach_local_m")
	if not anchor_value is Dictionary or not approach_value is Dictionary: return _error("ANCHORS")
	var anchor := _vector(anchor_value); var approach := _vector(approach_value)
	if not bool(anchor.ok) or not bool(approach.ok): return _error("ANCHORS")
	var source_side: Variant = seat.get("source_side")
	if typeof(source_side) not in [TYPE_INT, TYPE_FLOAT] or absf(float(source_side)) != 1.0: return _error("SOURCE_SIDE")
	return {"ok": true, "anchor": anchor.value, "approach": approach.value, "source_side": float(source_side)}

static func _vector(value: Dictionary) -> Dictionary:
	for axis in ["x", "y", "z"]:
		var number: Variant = value.get(axis)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)): return _error("VECTOR")
	return {"ok": true, "value": Vector3(float(value.x), float(value.y), float(value.z))}

static func _smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _finite_transform(value: Transform3D) -> bool:
	return _finite3(value.origin) and _finite3(value.basis.x) and _finite3(value.basis.y) and _finite3(value.basis.z)

static func _finite3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

static func _error(code: String) -> Dictionary:
	return {"ok": false, "error": code}
