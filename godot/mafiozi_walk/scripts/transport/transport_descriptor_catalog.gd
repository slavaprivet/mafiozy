extends RefCounted

const SCHEMA := "mafiozi.transport.descriptors.v1"

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

func _finite_vector(value: Variant) -> bool:
	if not value is Dictionary: return false
	var d: Dictionary = value
	for axis in ["x", "y", "z"]:
		var number: Variant = d.get(axis)
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true
