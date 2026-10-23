extends SceneTree
const Predicates = preload("res://scripts/npc_visual/npc_source_contact_predicates.gd")
const OUT := "C:/Users/Слава/Desktop/Мафиози/outputs/astra21_npc_source_contact_predicates/"
var checks := 0
var failures: Array = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("$f64"):
			var bytes := PackedByteArray(value["$f64"])
			if bytes.size() != 8: failures.append("invalid_oracle_f64"); return NAN
			return bytes.decode_double(0)
		var result := {}
		for key: String in value: result[key] = decode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(decode(item))
		return result
	return value

func digest(bytes: PackedByteArray) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes)
	return h.finish().hex_encode()

func _init() -> void:
	var bytes := FileAccess.get_file_as_bytes(OUT + "ORACLE.json")
	var packet: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	for source: Dictionary in packet.sources:
		check(digest(FileAccess.get_file_as_bytes("C:/Users/Слава/Desktop/Мафиози/" + source.frozen_path)) == source.sha256, "source_bytes:" + source.path)
	var rows: Array = decode(packet.cases)
	var counts := {"polygon": 0, "vehicle": 0, "train": 0}
	var vehicle: Dictionary = {}
	for i in rows.size():
		var row: Dictionary = rows[i]
		var before := row.duplicate(true)
		var answer: Dictionary
		match row.kind:
			"polygon": answer = Predicates.contains_polygon(row.polygon, row.c, row.r)
			"vehicle":
				answer = Predicates.vehicle_blocks(row.record, row.x, row.z, row.y, row.height)
				if row.record.visible: vehicle = row
			"train": answer = Predicates.train_blocks(row.cars, row.x, row.z)
			_: answer = {}
		counts[row.kind] += 1
		check(answer.get("known") == true and answer.get("blocked") == row.expected, "source_predicate:" + str(i))
		check(answer.get("physical_admission") == false, "no_admission:" + str(i))
		check(row == before, "input_immutable:" + str(i))
	check(not Predicates.contains_polygon([[0.0, NAN]], 0.0, 0.0).known, "malformed_polygon")
	check(not Predicates.contains_polygon([[0.0]], 0.0, 0.0).known, "missing_polygon_axis")
	check(not Predicates.contains_polygon([], INF, 0.0).known, "nonfinite_query")
	check(Predicates.contains_polygon([], 0.0, 0.0).known and not Predicates.contains_polygon([], 0.0, 0.0).blocked, "source_empty_polygon")
	check(not Predicates.vehicle_blocks({}, 0.0, 0.0, 0.0).known, "unknown_vehicle_visibility")
	check(not Predicates.vehicle_blocks({"visible": true}, 0.0, 0.0, 0.0).known, "missing_visible_profile")
	check(Predicates.vehicle_blocks({"visible": false}, 0.0, 0.0, 0.0).known and not Predicates.vehicle_blocks({"visible": false}, 0.0, 0.0, 0.0).blocked, "source_hidden_short_circuit")
	check(not Predicates.train_blocks([{}], 0.0, 0.0).known, "missing_train_snapshot")
	check(not Predicates.train_blocks([], NAN, 0.0).known, "nonfinite_train_query")
	var bad: Dictionary = vehicle.record.duplicate(true); bad.half_width = -1.0
	check(not Predicates.vehicle_blocks(bad, 0.0, 0.0, 0.0).known, "invalid_dimensions")
	var samples: Array = []
	for i in 1030:
		var begin := Time.get_ticks_usec()
		Predicates.vehicle_blocks(vehicle.record, vehicle.x, vehicle.z, vehicle.y, vehicle.height)
		if i >= 30: samples.append(Time.get_ticks_usec() - begin)
	samples.sort()
	var report := {"status": "PASS_SOURCE_MATHEMATICAL_COMPONENT_ONLY" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "cases": rows.size(), "kinds": counts, "oracle_sha256": digest(bytes), "helper_sha256": digest(FileAccess.get_file_as_bytes("res://scripts/npc_visual/npc_source_contact_predicates.gd")), "cpu_vehicle_us": {"p50": samples[499], "p95": samples[949], "max": samples.back(), "warmups": 30, "samples": 1000}, "limits": packet.limits}
	var file := FileAccess.open(OUT + "RESULT.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
