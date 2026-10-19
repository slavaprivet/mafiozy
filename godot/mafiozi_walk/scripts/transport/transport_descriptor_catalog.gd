extends RefCounted

const SCHEMA := "mafiozi.transport.descriptors.v1"
const SOURCE_PARKING_LOTS := 39
const SOURCE_PARKING_BAYS := 59

var error := ""
var document: Dictionary = {}
var profiles: Dictionary = {}
var parking: Dictionary = {}

func load_file(path: String = "res://data/transport/vehicle_descriptors.v1.json") -> bool:
	error = ""
	document.clear(); profiles.clear(); parking.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "OPEN_FAILED:%s" % FileAccess.get_open_error(); return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		error = "INVALID_JSON"; return false
	var candidate: Dictionary = parsed
	if candidate.get("schema", "") != SCHEMA:
		error = "SCHEMA"; return false
	var coordinate: Dictionary = candidate.get("coordinate_system", {})
	if coordinate.get("units", "") != "metres" or coordinate.get("up", "") != "+Y" or coordinate.get("forward", "") != "-Z":
		error = "COORDINATE_SYSTEM"; return false
	var lifecycle: Dictionary = candidate.get("lifecycle_contract", {})
	if int(lifecycle.get("hold_duration_us", 0)) != 300000 or lifecycle.get("births", "") != "explicit_authoritative_roster_only":
		error = "LIFECYCLE"; return false
	for value in candidate.get("profiles", []):
		if not value is Dictionary:
			error = "PROFILE_TYPE"; return false
		var profile: Dictionary = value
		var id := String(profile.get("profile_id", ""))
		if id.is_empty() or profiles.has(id) or not _valid_profile(profile):
			error = "PROFILE:%s" % id; return false
		profiles[id] = profile
	var parking_block: Dictionary = candidate.get("parking", {})
	if not _valid_parking_block(parking_block):
		error = "PARKING_CONTRACT"; return false
	for value in parking_block.get("bays", []):
		if not value is Dictionary:
			error = "PARKING_TYPE"; return false
		var bay: Dictionary = value
		var id := String(bay.get("parking_id", ""))
		if id.is_empty() or parking.has(id) or not _finite_vector(bay.get("position_m", {})):
			error = "PARKING:%s" % id; return false
		parking[id] = bay
	if profiles.is_empty() or parking.is_empty():
		error = "EMPTY"; return false
	document = candidate
	return true

func profile(id: String) -> Dictionary:
	return (profiles.get(id, {}) as Dictionary).duplicate(true)

func parking_bay(id: String) -> Dictionary:
	return (parking.get(id, {}) as Dictionary).duplicate(true)

func seat(profile_id: String, seat_id: String) -> Dictionary:
	var p: Dictionary = profiles.get(profile_id, {})
	for value in p.get("seats", []):
		if value is Dictionary and value.get("id", "") == seat_id: return (value as Dictionary).duplicate(true)
	return {}

func _valid_profile(profile: Dictionary) -> bool:
	if int(profile.get("seat_count", 0)) not in [2, 4]: return false
	if not _finite_vector(profile.get("body_half_extents_m", {})): return false
	var ids: Dictionary = {}; var doors: Dictionary = {}
	for value in profile.get("doors", []):
		if not value is Dictionary: return false
		var door: Dictionary = value; var id := String(door.get("id", ""))
		if id.is_empty() or doors.has(id): return false
		doors[id] = true
	for value in profile.get("seats", []):
		if not value is Dictionary: return false
		var seat_value: Dictionary = value; var id := String(seat_value.get("id", ""))
		if id.is_empty() or ids.has(id) or not doors.has(seat_value.get("door_id", "")): return false
		if not _finite_vector(seat_value.get("anchor_local_m", {})) or not _finite_vector(seat_value.get("approach_local_m", {})): return false
		ids[id] = true
	if ids.size() != int(profile.get("seat_count", -1)): return false
	return ids.has("front_left") and bool((seat(profile.get("profile_id", ""), "front_left") if profiles.has(profile.get("profile_id", "")) else _find_seat(profile, "front_left")).get("can_drive", false))

func _find_seat(profile: Dictionary, id: String) -> Dictionary:
	for value in profile.get("seats", []):
		if value is Dictionary and value.get("id", "") == id: return value
	return {}

func _valid_parking_block(block: Dictionary) -> bool:
	if block.get("source_version") != 1 or block.get("metres_per_cell") != 4.1: return false
	var stats: Variant = block.get("stats")
	var bays: Variant = block.get("bays")
	if not stats is Dictionary or not bays is Array: return false
	if not _whole_positive(stats.get("lots")) or not _whole_positive(stats.get("bays")) or bays.size() != int(stats.bays): return false
	if int(stats.lots) != SOURCE_PARKING_LOTS or int(stats.bays) != SOURCE_PARKING_BAYS: return false
	var lots: Dictionary = {}
	var kinds := {"hospital": 0, "residential": 0}
	for value in bays:
		if not value is Dictionary: return false
		var bay: Dictionary = value
		var id: Variant = bay.get("parking_id")
		var lot_id: Variant = bay.get("lot_id")
		var building_id: Variant = bay.get("building_id")
		var kind: Variant = bay.get("kind")
		var layout: Variant = bay.get("layout")
		if not id is String or id.is_empty() or not lot_id is String or lot_id.is_empty() or not building_id is String or building_id.is_empty(): return false
		if not id.begins_with(lot_id + ":bay:") or lot_id != "parking:" + building_id: return false
		if kind not in ["hospital", "residential"] or layout not in ["parallel", "perpendicular"]: return false
		if bay.get("exit_rule") != "yield_to_road_and_pedestrians" or not _finite_vector(bay.get("position_m")): return false
		for number in [bay.get("yaw_rad"), bay.get("width_m"), bay.get("length_m")]:
			if not (number is int or number is float) or not is_finite(float(number)): return false
		if float(bay.width_m) <= 0.0 or float(bay.length_m) <= 0.0: return false
		if lots.has(lot_id):
			if lots[lot_id] != kind: return false
		else:
			lots[lot_id] = kind
			kinds[kind] += 1
	if lots.size() != int(stats.lots): return false
	for kind in kinds:
		if not _whole_nonnegative(stats.get(kind + "Lots")) or kinds[kind] != int(stats[kind + "Lots"]): return false
	return true

func _whole_positive(value: Variant) -> bool:
	return _whole_nonnegative(value) and int(value) > 0

func _whole_nonnegative(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) == floor(float(value))

func _finite_vector(value: Variant) -> bool:
	if not value is Dictionary: return false
	var d: Dictionary = value
	for axis in ["x", "y", "z"]:
		var number: Variant = d.get(axis)
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true
