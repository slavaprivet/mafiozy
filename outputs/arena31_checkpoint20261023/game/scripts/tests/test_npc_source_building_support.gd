extends SceneTree
const Support = preload("res://scripts/npc_visual/npc_source_building_support.gd")
const INPUT := "C:/Users/Слава/Desktop/Мафиози/outputs/astra21_npc_registered_building_support/"
const OUT := "C:/Users/Слава/Desktop/Мафиози/outputs/astra21_npc_registered_building_native/"
var checks := 0
var failures: Array = []
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition and failures.size() < 40: failures.append(label)
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var bytes := FileAccess.get_file_as_bytes(INPUT + "support.f64.json")
	var values := FileAccess.get_file_as_bytes(INPUT + "support.f64.bin")
	var oracle := FileAccess.get_file_as_bytes(INPUT + "ORACLE_QUERIES.f64.bin")
	check(Support._hash(oracle) == "45dbd185aeee72eed9a537f65ad328f9733a93737bdbdb207a46434dc02fc470", "source_oracle_bytes")
	var support := Support.new()
	var setup_begin := Time.get_ticks_usec()
	var configured := support.configure(bytes, values)
	var setup_us := Time.get_ticks_usec() - setup_begin
	check(configured.get("ok") == true, "configure:" + str(configured))
	if not configured.get("ok", false): print(configured); quit(1); return
	check(oracle.size() % 48 == 0, "oracle_record_size")
	var count := oracle.size() / 48
	var mismatches := 0
	var max_error := 0.0
	var null_count := 0
	var query_begin := Time.get_ticks_usec()
	for i in count:
		var offset: int = i * 48
		var index := int(oracle.decode_double(offset))
		var x := oracle.decode_double(offset + 8); var z := oracle.decode_double(offset + 16)
		var ref := oracle.decode_double(offset + 24)
		var expected_null: bool = oracle.decode_double(offset + 32) == 1.0
		var expected := oracle.decode_double(offset + 40)
		var answer := support.entry_floor(index, x, z, ref)
		var same: bool = answer.known and (answer.value == null if expected_null else answer.value is float and answer.value == expected)
		if expected_null: null_count += 1
		if not same:
			mismatches += 1
			if answer.get("value") is float: max_error = maxf(max_error, absf(answer.value - expected))
		check(same, "original_floor:" + str(i) + ":" + str(answer) + ":expected=" + str(expected))
		check(answer.get("physical_admission") == false, "no_admission:" + str(i))
	var query_us := Time.get_ticks_usec() - query_begin
	check(not support.entry_floor(-1, 0.0, 0.0).known, "unknown_entry")
	check(not support.floor_at(INF, 0.0).known, "nonfinite")
	var copied := support.collision_collections()
	check(copied.known and copied.collections.size() == 78, "collections")
	var bodies := 0
	for collection: Dictionary in copied.collections: bodies += collection.bodies.size()
	check(bodies == 17086, "all_original_colliders")
	copied.collections[0].bodies.clear()
	check(support.collision_collections().collections[0].bodies.size() > 0, "private_collision_copy")
	check(not support.configure(bytes, values).ok, "configure_once")
	var rejected := Support.new(); var changed := bytes.duplicate(); changed[0] ^= 1
	check(not rejected.configure(changed, values).ok, "bad_bytes")
	check(rejected.configure(bytes, values).ok, "atomic_bad_retry")
	support.invalidate("source_revision_changed")
	check(not support.floor_at(0.0, 0.0).known and not support.collision_collections().known, "stale_snapshot")
	var report := {"status": "PASS_SOURCE_BUILDING_SUPPORT_ONLY" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "source_rows": count, "null_rows": null_count, "mismatches": mismatches, "max_error": max_error, "setup_us": setup_us, "query_total_us": query_us, "colliders": bodies, "helper_sha256": Support._hash(FileAccess.get_file_as_bytes("res://scripts/npc_visual/npc_source_building_support.gd")), "data_sha256": Support.DATA_SHA, "values_sha256": Support.VALUES_SHA, "limits": ["Offline initial source building floors/colliders only", "No rail/landscape composite, live doors, complete registration, actors, physical admission or FPS"]}
	var file := FileAccess.open(OUT + "RESULT.json", FileAccess.WRITE); file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
