extends SceneTree

const Catalog = preload("res://scripts/transport/transport_descriptor_catalog.gd")
const SOURCE = "res://data/transport/vehicle_descriptors.v1.json"
const TEMP = "user://transport_parking_catalog_contract_test.json"
var checks := 0
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _load_candidate(candidate: Dictionary) -> Dictionary:
	var file := FileAccess.open(TEMP, FileAccess.WRITE)
	if file == null: return {"ok": false, "error": "WRITE"}
	file.store_string(JSON.stringify(candidate))
	file.close()
	var catalog := Catalog.new()
	var ok := catalog.load_file(TEMP)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	return {"ok": ok, "error": catalog.error, "lots": catalog.parking.size()}

func _initialize() -> void:
	var file := FileAccess.open(SOURCE, FileAccess.READ)
	if file == null:
		print("TRANSPORT_PARKING_CONTRACT missing source")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		print("TRANSPORT_PARKING_CONTRACT invalid source")
		quit(1)
		return
	var source: Dictionary = parsed
	var normal := _load_candidate(source)
	_check(normal.ok and normal.lots == 59, "source 39 lots and 59 bays loads")
	for mode in ["bay_count", "lot_count", "kind_count", "missing_lot_id", "wrong_building", "zero_width", "nan_yaw", "wrong_exit", "wrong_scale", "mixed_kind"]:
		var candidate: Dictionary = source.duplicate(true)
		match mode:
			"bay_count": candidate.parking.stats.bays = 58
			"lot_count": candidate.parking.stats.lots = 38
			"kind_count": candidate.parking.stats.hospitalLots = 0
			"missing_lot_id": candidate.parking.bays[0].erase("lot_id")
			"wrong_building": candidate.parking.bays[0].building_id = "someone-else"
			"zero_width": candidate.parking.bays[0].width_m = 0.0
			"nan_yaw": candidate.parking.bays[0].yaw_rad = "NaN"
			"wrong_exit": candidate.parking.bays[0].exit_rule = "free"
			"wrong_scale": candidate.parking.metres_per_cell = 3.0
			"mixed_kind": candidate.parking.bays[1].kind = "residential"
		var result := _load_candidate(candidate)
		_check(not result.ok and result.error == "PARKING_CONTRACT", mode + " rejected")
	var started := Time.get_ticks_usec()
	var bench_ok := true
	for i in 10:
		var catalog := Catalog.new()
		if not catalog.load_file(SOURCE): bench_ok = false
	var ten_load_us := Time.get_ticks_usec() - started
	_check(bench_ok, "ten complete source descriptor loads")
	print("TRANSPORT_PARKING_CONTRACT ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty(), "ten_load_us": ten_load_us, "scope": "parking descriptor admission only; source routes and physical occupancy remain host-owned"}))
	quit(0 if failures.is_empty() else 1)
