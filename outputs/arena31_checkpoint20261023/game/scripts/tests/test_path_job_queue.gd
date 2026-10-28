extends SceneTree
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
var checks := 0
var failures: Array[String] = []
var now_us := 0
var reentry_queue: RefCounted
var reentry_result := true
var worker_result := true

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func clock() -> int:
	return now_us

func json_equal(a: Variant, b: Variant) -> bool:
	# Godot JSON parses numbers as doubles. Compare integer-valued microseconds
	# exactly, with no tolerance; do not confuse booleans with numeric values.
	if (a is int or a is float) and (b is int or b is float):
		return a == b
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not json_equal(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not json_equal(a[i], b[i]): return false
		return true
	return typeof(a) == typeof(b) and a == b

func reentrant_clock() -> int:
	reentry_result = reentry_queue.reserve(99)
	return now_us

func worker_attempt(queue: RefCounted) -> void:
	worker_result = queue.reserve(1)

func metrics(owner: Queue.Owner) -> Dictionary:
	return {"attempt_us": owner.attempt_us, "admitted_us": owner.admitted_us,
		"wait_start_us": owner.wait_start_us, "last_wait_us": owner.last_wait_us,
		"last_cpu_us": owner.last_cpu_us, "total_cpu_us": owner.total_cpu_us,
		"quanta": owner.quanta, "search_pending": owner.search_pending,
		"continuation": owner.continuation, "search_kind": owner.search_kind, "request_at": owner.request_at}

func run_parity(scenario: Dictionary) -> void:
	now_us = 0
	var queue := Queue.new(clock, bool(scenario.native))
	var owners: Array = []
	for i in range(int(scenario.count)):
		var owner := Queue.Owner.new("owner:" + str(i))
		owner.search_pending = true
		owner.continuation = {"fixture": true}
		owner.search_kind = "fixture"
		owner.request_at = 42
		owners.append(owner)
	var results: Array = []
	var snapshot_index := 0
	for op: Dictionary in scenario.ops:
		if op.has("now"):
			now_us = int(op.now)
		var owner: Queue.Owner = owners[int(op.id)] if op.has("id") and int(op.id) >= 0 else null
		match str(op.op):
			"reserve": results.append(queue.reserve(int(op.frame), owner))
			"finish": check(queue.finish(), scenario.name + " finish accepted")
			"expired": results.append(queue.expired())
			"cancel": check(queue.cancel(owner), scenario.name + " cancel accepted")
			"flags":
				if op.has("dead"): owner.dead = bool(op.dead)
				if op.has("queued"): owner.empire_route_queued = bool(op.queued)
				if op.has("pending"): owner.empire_pending_route = bool(op.pending)
			"checkpoint":
				var actual := queue.diagnostics()
				check(json_equal(actual, scenario.snapshots[snapshot_index]), scenario.name + " exact snapshot " + str(snapshot_index))
				if not json_equal(actual, scenario.snapshots[snapshot_index]) and failures.size() < 4:
					print("PARITY_DIFF ", scenario.name, " actual=", JSON.stringify(actual), " expected=", JSON.stringify(scenario.snapshots[snapshot_index]))
				snapshot_index += 1
	check(results == scenario.results, scenario.name + " all admission/expiry results equal source")
	for i in owners.size():
		check(json_equal(metrics(owners[i]), scenario.owner_metrics[i]), scenario.name + " owner metrics " + str(i))
	check(queue.dispose(), scenario.name + " dispose")

func host_contract_tests() -> void:
	now_us = 0
	reentry_queue = Queue.new(reentrant_clock)
	check(reentry_queue.reserve(1), "outer call admitted")
	check(not reentry_result and reentry_queue.rejected_calls == 1, "clock cannot reenter scheduler")
	reentry_queue.dispose()
	reentry_queue = null
	var queue := Queue.new(clock)
	var first := Queue.Owner.new("stable-id", 1)
	var replacement := Queue.Owner.new("stable-id", 2)
	check(queue.reserve(1, first), "first life admitted")
	queue.finish()
	queue.cancel(first)
	check(queue.reserve(1, replacement), "new source life has separate object identity")
	queue.finish()
	check(not queue.reserve(1, replacement), "same object not readmitted in frame")
	check(not queue.reserve(1, Queue.Owner.new("", 1)), "empty source ID rejected")
	check(not queue.reserve(1, Queue.Owner.new("bad", 0)), "invalid life rejected")
	now_us = 100
	queue.finish()
	check(queue.reserve(2, replacement), "active slice before bad clock")
	now_us = 99
	check(not queue.reserve(3, replacement), "backwards host clock rejected")
	check(queue.expired(), "invalid clock stops planner slice")
	queue.dispose()
	check(not queue.reserve(3), "disposed queue cannot authorize work")
	now_us = 0
	queue = Queue.new(clock)
	var thread := Thread.new()
	check(thread.start(worker_attempt.bind(queue)) == OK, "thread test started")
	thread.wait_to_finish()
	check(not worker_result and queue.diagnostics().count == 0, "worker cannot mutate main-thread scheduler")
	queue.dispose()
	# Strong owner references bounded by queue 512 + cohort 8 + served 8 + current 1.
	now_us = 0
	queue = Queue.new(clock)
	var refs: Array = []
	for i in range(600):
		var owner := Queue.Owner.new("bound:" + str(i))
		refs.append(weakref(owner))
		queue.reserve(1, owner)
		queue.finish()
	var alive := 0
	for reference: WeakRef in refs:
		if reference.get_ref() != null: alive += 1
	check(alive <= 529, "bounded retained owners after overflow")
	queue.dispose()
	alive = 0
	for reference: WeakRef in refs:
		if reference.get_ref() != null: alive += 1
	check(alive == 0, "dispose releases all owners")

func benchmark() -> Array:
	var reports: Array = []
	for size in [16, 96, 512]:
		now_us = 0
		var queue := Queue.new(clock)
		var owners: Array = []
		for i in range(size): owners.append(Queue.Owner.new("bench:" + str(i)))
		var costs: Array = []
		var max_queue := 0
		for frame in range(170):
			var started := Time.get_ticks_usec()
			for owner: Queue.Owner in owners:
				if queue.reserve(frame, owner):
					now_us += 1000
					queue.finish()
			var elapsed := Time.get_ticks_usec() - started
			if frame >= 10: costs.append(elapsed)
			max_queue = maxi(max_queue, int(queue.diagnostics().queue_size))
			now_us += 10000
		costs.sort()
		for owner: Queue.Owner in owners:
			check(owner.quanta > 0, "benchmark all continuously eligible owners served " + str(size))
		reports.append({"owners": size, "frames": costs.size(), "queue_size_max": max_queue,
			"scheduler_frame_us_p50": costs[int(ceil(costs.size() * 0.5)) - 1], "scheduler_frame_us_p95": costs[int(ceil(costs.size() * 0.95)) - 1],
			"scheduler_frame_us_max": costs.back(), "calls_per_frame": size,
			"qualification": "Headless module CPU only; synthetic 1ms search costs, no geometry/NPC/rendering; not game FPS"})
		queue.dispose()
	return reports

func _initialize() -> void:
	var oracle_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--oracle="): oracle_path = argument.trim_prefix("--oracle=")
	check(not oracle_path.is_empty() and FileAccess.file_exists(oracle_path), "explicit exact-source oracle exists")
	if not failures.is_empty():
		print(JSON.stringify({"failures": failures}))
		quit(1)
		return
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	var source_path := ProjectSettings.globalize_path("res://").path_join("../../world.html").simplify_path()
	check(FileAccess.get_sha256(source_path) == str(oracle.source_sha256), "oracle matches current local Walk source bytes")
	for scenario: Dictionary in oracle.scenarios: run_parity(scenario)
	host_contract_tests()
	var costs := benchmark()
	var report := {"checks": checks, "failures": failures, "source_sha256": oracle.source_sha256,
		"slice_sha256": oracle.slice_sha256, "scenarios": oracle.scenarios.size(), "benchmarks": costs}
	print("PATH_JOB_QUEUE_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
