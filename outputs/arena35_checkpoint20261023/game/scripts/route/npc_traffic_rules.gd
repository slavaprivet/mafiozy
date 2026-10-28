extends RefCounted
## Pure source traffic rule/phase port. Caller owns current native occupancy;
## the pinned route owner must fail closed if those queries are unavailable.
var _rows := {}
var _controls := {}
var _configured := false

static func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	return hash.finish().hex_encode()

func configure(packet: Dictionary, config_bytes: PackedByteArray) -> Dictionary:
	if _configured or packet.get("traffic_config_sha256","") != _sha(config_bytes): return {"ok":false,"reason":"traffic_config_pin"}
	var parsed: Variant = JSON.parse_string(config_bytes.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("schema") != "artist24.actual-seven-traffic-controls/v1" or not parsed.get("controls") is Array or not packet.get("controls") is Array: return {"ok":false,"reason":"traffic_config_schema"}
	if parsed.controls.size()!=packet.controls.size() or parsed.controls.is_empty(): return {"ok":false,"reason":"complete_control_set_required"}
	for control: Dictionary in packet.controls:
		var key: String=str(control.get("control_key",""))
		if key.is_empty() or _controls.has(key): return {"ok":false,"reason":"unique_control_required"}
		_controls[key]=control.duplicate(true)
	for row: Dictionary in parsed.controls:
		var key: String=str(row.get("key",""))
		if not _controls.has(key) or _rows.has(key) or row.get("route_control")!=_controls[key]: return {"ok":false,"reason":"canonical_control_mismatch"}
		if row.get("kind") not in ["junction","pedestrian_crossing","road_end_turnaround"] or not row.get("crosswalk_ids") is Array or not row.get("pedestrian_zones") is Array or not row.get("vehicle_zones") is Array: return {"ok":false,"reason":"unsupported_control"}
		if row.kind=="junction" and (not row.get("connected",false) or not row.get("yield_ids") is Array or not row.get("conflict_ids") is Array or row.get("rule") not in ["priority_right","yield","signal","priority"]): return {"ok":false,"reason":"invalid_junction"}
		_rows[key]=row.duplicate(true)
	_configured=true
	return {"ok":true,"count":_rows.size(),"scope":"pure_original_rules_with_current_native_occupancy_required"}

static func phase_at(time_s: float, axis: int, offset: float) -> String:
	var t: float=fposmod(time_s+offset,44.0)
	if axis==0: return "green" if t<17.0 else "amber" if t<20.0 else "red"
	return "green" if t>=22.0 and t<39.0 else "amber" if t>=39.0 and t<42.0 else "red"

func evaluate(control: Dictionary, time_s: float, occupied_pedestrian: bool, occupied_vehicle: bool) -> Dictionary:
	var key: String=str(control.get("control_key",""))
	if not _configured or not is_finite(time_s) or not _controls.has(key) or _controls[key]!=control: return {"allowed":false,"reason":"unknown_or_changed_control"}
	var row: Dictionary=_rows[key]
	if occupied_pedestrian and not row.crosswalk_ids.is_empty(): return {"allowed":false,"reason":"pedestrian_crossing"}
	if row.kind=="junction":
		if row.rule=="signal":
			var phase: String=phase_at(time_s,int(row.axis),float(row.offset))
			if phase!="green": return {"allowed":false,"reason":"traffic_signal","phase":phase}
		if occupied_vehicle:
			if not row.yield_ids.is_empty(): return {"allowed":false,"reason":"yield_to_traffic"}
			if not row.conflict_ids.is_empty(): return {"allowed":false,"reason":"junction_occupied"}
	elif row.kind=="road_end_turnaround" and occupied_vehicle and not row.conflict_edge_ids.is_empty():
		return {"allowed":false,"reason":"yield_to_oncoming"}
	return {"allowed":true,"reason":"clear","rule":row.rule}

func zones(control: Dictionary) -> Dictionary:
	var key: String=str(control.get("control_key",""))
	if not _configured or not _controls.has(key) or _controls[key]!=control: return {}
	var row: Dictionary=_rows[key]
	return {"pedestrians":row.pedestrian_zones.duplicate(true),"vehicles":row.vehicle_zones.duplicate(true)}
