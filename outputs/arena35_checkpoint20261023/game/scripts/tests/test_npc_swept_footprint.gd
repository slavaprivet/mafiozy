extends SceneTree
const Sweep = preload("res://scripts/navigation/npc_swept_footprint.gd")
const ORACLE = "res://scripts/tests/fixtures/npc_sweep_oracle.json"
var checks := 0
var failures: Array[String] = []
var contacts: Array = []
var mode := "none"
var reentrant_sweep: RefCounted
var reentrant_result := true
var worker_set_result := true
var worker_overlap_result := false

func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok: failures.append(name)

func decode_exact(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size() == 1 and value.has("$f64le"):
			var bytes: PackedByteArray = str(value["$f64le"]).hex_decode()
			assert(bytes.size() == 8)
			return bytes.decode_double(0)
		var decoded: Dictionary = {}
		for key: Variant in value: decoded[key] = decode_exact(value[key])
		return decoded
	if value is Array:
		var decoded: Array = []
		for child: Variant in value: decoded.append(decode_exact(child))
		return decoded
	return value

func contact(c: float, r: float) -> bool:
	contacts.append([c, r])
	match mode:
		"yes": return true
		"no": return false
		"half": return c + r >= 0.0
		"pattern": return int(floor(absf(c * 17.0 + r * 31.0))) % 3 == 0
	return false

func reentrant_contact(_c: float, _r: float) -> bool:
	reentrant_result = reentrant_sweep.set_segment({"r": 99.0, "c": 99.0}, {"r": 100.0, "c": 100.0})
	return false

func invalid_contact(_c: float, _r: float) -> String:
	return "not-a-contact-boolean"

func worker_attempt(sweep: RefCounted) -> void:
	worker_set_result = sweep.set_segment({"r": 9.0, "c": 9.0}, {"r": 10.0, "c": 10.0})
	worker_overlap_result = sweep.overlaps([])

func parity(oracle: Dictionary) -> void:
	var sweep := Sweep.new()
	for row: Dictionary in oracle.cases:
		contacts.clear()
		mode = str(row.filter)
		check(sweep.set_segment(row.from, row.to, row.radius), row.name + " valid segment")
		var predicate := Callable() if mode == "none" else contact
		var actual := sweep.overlaps(row.polygon, predicate)
		check(actual == bool(row.overlap), row.name + " exact overlap decision")
		var box := sweep.bounds()
		for key: String in ["minC", "minR", "maxC", "maxR"]:
			check(box[key] == row.bounds[key], row.name + " exact scalar64 bound " + key)
		check(contacts.size() == row.contacts.size(), row.name + " exact callback count/order")
		for i in mini(contacts.size(), row.contacts.size()):
			# Exact equality, not approximate tolerance: same double-precision algebra.
			check(contacts[i][0] == row.contacts[i][0] and contacts[i][1] == row.contacts[i][1], row.name + " exact contact coordinates " + str(i))
		check(sweep.last_error.is_empty(), row.name + " source-domain query has no host error")

func negatives() -> void:
	var sweep := Sweep.new()
	var point := {"r": 0.0, "c": 0.0}
	var polygon := [[-0.1, -0.1], [0.1, -0.1], [0.1, 0.1], [-0.1, 0.1]]
	check(sweep.overlaps(polygon), "query before set fails closed")
	for invalid in [null, {}, {"r": 0}, {"r": NAN, "c": 0}, {"r": INF, "c": 0}, {"r": "0", "c": 0}, {"r": true, "c": 0}, {"r": 1e300, "c": 0}, Vector2.ZERO]:
		check(not sweep.set_segment(invalid, point), "invalid endpoint rejected " + str(invalid))
		check(sweep.overlaps(polygon), "invalid set cannot reuse prior clear segment")
	for radius in [-0.1, NAN, INF, "0.18", true, 1e300]:
		check(not sweep.set_segment(point, point, radius), "invalid radius rejected " + str(radius))
	check(sweep.set_segment(point, point), "valid segment recovers after invalid")
	for invalid in [{}, "polygon", [1], [[0]], [[0, 0, 0]], [[NAN, 0]], [[INF, 0]], [[true, 0]], [["0", 0]], [[1e300, 0]]]:
		check(sweep.overlaps(invalid) and sweep.last_error == "invalid-polygon", "invalid polygon fails closed")
	check(not sweep.overlaps([]), "source empty polygon is empty")
	check(not sweep.overlaps(null), "source absent polygon is empty")
	check(sweep.overlaps(polygon, invalid_contact) and sweep.last_error == "invalid-contact-result", "invalid callback return fails closed")
	reentrant_sweep = sweep
	var before := sweep.bounds()
	check(sweep.overlaps(polygon, reentrant_contact), "reentry cannot clear collision")
	check(not reentrant_result and sweep.last_error == "reentrant-access", "nested mutation denied")
	check(sweep.bounds() == before, "nested set cannot mutate outer hull")
	reentrant_sweep = null
	# Endpoint/obstacle ownership: no source record is retained or mutated.
	var start := {"r": 0.0, "c": 0.0}
	sweep.set_segment(start, point)
	start.r = 100.0
	check(sweep.bounds().minR == -0.18, "endpoint state copied into reusable scratch")
	var copy := polygon.duplicate(true)
	sweep.overlaps(polygon)
	check(polygon == copy, "query never rewrites authored polygon")
	var box := sweep.bounds()
	box.minR = -999.0
	check(sweep.bounds().minR == -0.18, "diagnostics detached from scratch state")
	var thread := Thread.new()
	var thread_before := sweep.bounds()
	check(thread.start(worker_attempt.bind(sweep)) == OK, "worker negative test started")
	thread.wait_to_finish()
	check(not worker_set_result and worker_overlap_result, "worker calls cannot authorize movement")
	check(sweep.bounds() == thread_before, "worker denial leaves scalar hull unchanged")

func benchmark(oracle: Dictionary) -> Dictionary:
	var samples: Array = []
	var actual_rows: Array = []
	for row: Dictionary in oracle.cases:
		if str(row.origin).ends_with("printshop_interior.json") and str(row.name).ends_with(":cross"):
			actual_rows.append(row)
	var sweep := Sweep.new()
	var blocked := 0
	for batch in range(70):
		var started := Time.get_ticks_usec()
		for row: Dictionary in actual_rows:
			sweep.set_segment(row.from, row.to, row.radius)
			if sweep.overlaps(row.polygon): blocked += 1
		if batch >= 10: samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	check(blocked == actual_rows.size() * 70, "actual body-centre benchmark intersections preserved")
	return {"qualification": "Headless module-only CPU; batch percentiles for actual polygons, no NPC/nav/rendering/FPS",
		"pairs_per_batch": actual_rows.size(), "batches": samples.size(),
		"set_and_overlap_batch_us_p50": samples[29], "set_and_overlap_batch_us_p95": samples[56],
		"set_and_overlap_batch_us_max": samples.back(), "mean_pair_us_at_p50": float(samples[29]) / actual_rows.size(),
		"scratch_points": 8, "scratch_hull_capacity": 16}

func _initialize() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	check(data is Dictionary and data.get("schema") == "mafiozi.npc-sweep-oracle/v1", "immutable source fixture loaded")
	if not failures.is_empty():
		print(JSON.stringify({"failures": failures}))
		quit(1)
		return
	var root := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	check(data.get("numericEncoding") == "ieee754-f64le-hex", "fixture preserves binary64 inputs and outputs")
	data.cases = decode_exact(data.cases)
	for source: Dictionary in data.sources:
		check(FileAccess.get_sha256(root.path_join(source.path)) == source.sha256, "fixture source SHA " + str(source.path))
	parity(data)
	negatives()
	var costs := benchmark(data)
	print("NPC_SWEPT_FOOTPRINT_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "cases": data.cases.size(), "actual_bodies": data.actualBodyCount, "benchmark": costs}))
	quit(0 if failures.is_empty() else 1)
