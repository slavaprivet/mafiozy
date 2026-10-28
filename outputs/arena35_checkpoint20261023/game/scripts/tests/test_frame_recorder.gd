extends SceneTree
const Recorder = preload("res://scripts/perf/frame_recorder.gd")
const Adapter = preload("res://scripts/perf/preview_perf_adapter.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func benchmark_record_cost() -> Dictionary:
	# Batch averages of synthetic valid timestamp injection, NOT frame percentiles.
	var recorder = Recorder.new()
	var start_cost := Time.get_ticks_usec()
	recorder.begin_capture({"capacity": 6000, "warmup_us": 0})
	var begin_us := Time.get_ticks_usec() - start_cost
	var stamp := 0
	recorder.record_timestamp(stamp)
	for i in range(10000):
		stamp += 16667
		recorder.record_timestamp(stamp)
	var off: Array = []
	var on: Array = []
	var observed_clock := 0
	for batch in range(64):
		var started := Time.get_ticks_usec()
		for i in range(1000):
			observed_clock = Time.get_ticks_usec()
			stamp += 16667
		off.append(float(Time.get_ticks_usec() - started) / 1000.0)
		started = Time.get_ticks_usec()
		for i in range(1000):
			observed_clock = Time.get_ticks_usec()
			stamp += 16667
			recorder.record_timestamp(stamp)
		on.append(float(Time.get_ticks_usec() - started) / 1000.0)
	off.sort()
	on.sort()
	start_cost = Time.get_ticks_usec()
	var report: Dictionary = recorder.finish_capture()
	var finish_us := Time.get_ticks_usec() - start_cost
	start_cost = Time.get_ticks_usec()
	var serialized := JSON.stringify(report)
	var serialize_us := Time.get_ticks_usec() - start_cost
	return {"qualification": "CPU microbenchmark: 64 batches of 1000 calls; percentile of batch mean microseconds per call, not frame-time or GPU/LIVE",
		"control_batch_mean_us_p50": Recorder.nearest_rank(off, 0.5), "control_batch_mean_us_p95": Recorder.nearest_rank(off, 0.95),
		"record_batch_mean_us_p50": Recorder.nearest_rank(on, 0.5), "record_batch_mean_us_p95": Recorder.nearest_rank(on, 0.95),
		"record_batch_mean_us_max": on.back(), "samples_accepted": report.accepted_total,
		"begin_us": begin_us, "finish_report_us": finish_us, "json_serialize_us": serialize_us, "json_chars": serialized.length(),
		"clock_observed": observed_clock > 0, "warmup_calls": 10000, "context": "headless synthetic monotonic 16667us interval; clock read in both control and record loops"}

func _initialize() -> void:
	var r = Recorder.new()
	check(not r.begin_capture({"capacity": 0}), "zero capacity denied")
	check(not r.begin_capture({"capacity": 100001}), "maximum capacity bounded")
	check(not r.begin_capture({"capacity": 4, "warmup_us": -1}), "negative warmup denied")
	check(not r.begin_capture({"capacity": 4, "warmup_us": 0, "event_capacity": 0}), "zero event capacity denied")
	var context := {"camera": "fixed", "population": 72}
	check(r.begin_capture({"context": context, "capacity": 4, "warmup_us": 100, "event_capacity": 2}), "valid configuration")
	context.population = 0
	check(not r.record_timestamp(1000), "first timestamp only anchors")
	check(not r.record_timestamp(1050), "warmup interval discarded")
	check(not r.record_timestamp(1100), "crossing warmup interval discarded")
	check(r.record_timestamp(1110), "first full post-warmup interval")
	check(not r.record_timestamp(1110), "duplicate clock rejected")
	check(not r.record_timestamp(1000), "backwards clock rejected")
	check(r.record_timestamp(1120), "rejected clock did not re-anchor")
	check(r.record_timestamp(1140), "20us golden sample")
	check(r.record_timestamp(1170), "30us golden sample")
	check(r.record_timestamp(1210), "ring wraps")
	var a: Dictionary = r.report()
	var encoded := JSON.stringify(a)
	var parsed: Variant = JSON.parse_string(encoded)
	check(parsed is Dictionary and parsed.accepted_total == 5, "report JSON round-trip")
	check(a.context.population == 72, "metadata copied")
	check(a.accepted_total == 5 and a.retained_count == 4 and a.overwritten_count == 1, "ring bounds and counters")
	check(a.samples[0].sequence == 2 and a.samples[3].sequence == 5, "chronological ring ordering")
	check(is_equal_approx(a.p50_ms, 0.02) and is_equal_approx(a.p95_ms, 0.04) and is_equal_approx(a.p99_ms, 0.04), "nearest-rank golden 10,20,30,40us")
	check(a.clock_rejected == 2 and a.discarded_warmup_intervals == 2, "warmup and clock diagnostics")
	a.samples[0].interval_us = 999
	check(r.report().samples[0].interval_us == 10, "report mutation cannot affect ring")
	r.begin_capture({"capacity": 2, "warmup_us": 0, "event_capacity": 2})
	r.record_timestamp(0)
	r.record_timestamp(50000)
	check(r.report().spikes_total == 0, "exactly 50ms is not greater than threshold")
	check(r.mark_event_at("loading", 50001), "event timestamp accepted")
	check(not r.mark_event_at("stale", 1), "backwards event rejected")
	r.record_timestamp(100001)
	check(r.report().spikes_retained[0].events_within_interval == ["loading"], "event correlated to interval, no causation claim")
	r.mark_event_at("a", 100002)
	r.mark_event_at("b", 100003)
	check(r.report().events_retained.size() == 2 and r.report().events_retained[0].label == "a", "event ring bounded")
	check(r.snapshot().events_total == 3 and r.snapshot().events_retained_count == 2 and r.snapshot().events_overwritten_count == 1, "marker loss counters explicit")
	r.record_timestamp(100002)
	r.record_timestamp(100003)
	check(r.report().spikes_total == 1 and r.report().spikes_retained.is_empty(), "overwritten spikes still counted")
	r.stop()
	check(not r.record_timestamp(100004), "stop freezes recording")
	r.begin_capture({"capacity": 2, "warmup_us": 0})
	check(r.report().p50_ms == null and r.report().accepted_total == 0, "restart empty percentiles null")
	check(r.snapshot().events_total == 0 and r.snapshot().events_overwritten_count == 0, "restart clears marker totals")
	var m: Dictionary = r.report().monitors_at_report
	check(m.gpu_frame_ms == null and m.scene_triangles == null, "unavailable measurements null")
	check(m.draw_calls_last_frame == null and m.video_memory_bytes == null, "headless render monitors null")
	r.record_timestamp(Time.get_ticks_usec())
	OS.delay_msec(2)
	check(r.record_timestamp(Time.get_ticks_usec()), "real monotonic wall clock path")
	check(not r.begin_capture({"capacity": 2.5}), "fractional capacity rejected")
	check(not r.begin_capture({"warmup_us": "500"}), "string warmup rejected")
	check(not r.begin_capture({"context": []}), "non-dictionary context rejected")
	var before: Dictionary = r.snapshot()
	check(before.accepted_total == 1, "invalid configuration preserves active samples")
	var finished: Dictionary = r.finish_capture()
	check(not finished.running and not r.record_timestamp(Time.get_ticks_usec()), "finish freezes capture")
	check(r.snapshot().accepted_total == finished.accepted_total, "finished snapshot preserved")
	var adapter = Adapter.new()
	root.add_child(adapter)
	check(not adapter.is_processing() and not adapter.is_capturing(), "adapter OFF has no process callback")
	check(adapter.begin_capture({"capacity": 16, "warmup_us": 0, "context": {"scenario": "synthetic"}}), "adapter accepts explicit begin")
	check(adapter.is_processing() and adapter.is_capturing(), "adapter ON processes once")
	check(not adapter.begin_capture({"capacity": -1}) and adapter.is_capturing(), "invalid restart preserves active capture")
	adapter.mark_event("golden-marker")
	adapter._process(0.0)
	var actual: Dictionary = adapter.finish_capture()
	check(not adapter.is_processing() and not adapter.is_capturing() and not actual.running, "adapter finish disables callback")
	check(actual.context.scenario == "synthetic" and actual.context.display_server == "headless" and actual.context.physics_ticks_per_second == Engine.physics_ticks_per_second, "actual adapter metadata")
	check(actual.monitors_at_report.gpu_frame_ms == null, "adapter never fabricates GPU duration")
	adapter.queue_free()
	print(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "qualification": "isolated headless recorder golden tests; no game GPU/LIVE/FPS"}))
	if OS.get_cmdline_user_args().has("--benchmark"):
		print(JSON.stringify(benchmark_record_cost()))
	quit(0 if failures.is_empty() else 1)
