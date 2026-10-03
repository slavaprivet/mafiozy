extends RefCounted
## S01 wall-frame recorder. Caller owns exactly one timestamp per process tick.
const MAX_CAPACITY := 100000
var _samples: Array = []
var _events: Array = []
var _cursor := 0
var _event_cursor := 0
var _count := 0
var _event_count := 0
var _events_total := 0
var _capacity := 6000
var _event_capacity := 128
var _warmup_us := 5000000
var _start_us := -1
var _last_us := -1
var _accepted := 0
var _discarded := 0
var _clock_rejected := 0
var _spikes_total := 0
var _running := false
var _context: Dictionary = {}

func begin_capture(config: Dictionary = {}) -> bool:
	var capacity_value: Variant = config.get("capacity", 6000)
	var warmup_value: Variant = config.get("warmup_us", 5000000)
	var events_value: Variant = config.get("event_capacity", 128)
	var context_value: Variant = config.get("context", {})
	if typeof(capacity_value) != TYPE_INT or typeof(warmup_value) != TYPE_INT or typeof(events_value) != TYPE_INT or typeof(context_value) != TYPE_DICTIONARY:
		return false
	return _begin(context_value, capacity_value, warmup_value, events_value)

func snapshot() -> Dictionary:
	return report()

func finish_capture() -> Dictionary:
	stop()
	return report()

func _begin(context: Dictionary, capacity: int = 6000, warmup_us: int = 5000000, event_capacity: int = 128) -> bool:
	if capacity < 1 or capacity > MAX_CAPACITY or warmup_us < 0 or event_capacity < 1 or event_capacity > 4096:
		return false
	_capacity = capacity
	_event_capacity = event_capacity
	_warmup_us = warmup_us
	_samples.resize(capacity)
	for i in range(capacity):
		_samples[i] = {"from_us": 0, "to_us": 0, "interval_us": 0, "sequence": 0}
	_events.resize(event_capacity)
	_events.fill(null)
	_cursor = 0
	_event_cursor = 0
	_count = 0
	_event_count = 0
	_events_total = 0
	_start_us = -1
	_last_us = -1
	_accepted = 0
	_discarded = 0
	_clock_rejected = 0
	_spikes_total = 0
	# Caller controls metadata; no scene/server inspection or state ownership.
	_context = context.duplicate(true)
	_running = true
	return true

func stop() -> void:
	_running = false

func record_timestamp(timestamp_us: int) -> bool:
	if not _running:
		return false
	if timestamp_us < 0 or (_last_us >= 0 and timestamp_us <= _last_us):
		_clock_rejected += 1
		return false # Never re-anchor to a duplicate/backwards clock.
	if _start_us < 0:
		_start_us = timestamp_us
		_last_us = timestamp_us
		return false
	var previous := _last_us
	_last_us = timestamp_us
	if previous - _start_us < _warmup_us:
		_discarded += 1
		return false # Crossing warmup interval is discarded in full.
	var interval_us := timestamp_us - previous
	var row: Dictionary = _samples[_cursor]
	row.from_us = previous
	row.to_us = timestamp_us
	row.interval_us = interval_us
	row.sequence = _accepted + 1
	_cursor = (_cursor + 1) % _capacity
	_count = mini(_count + 1, _capacity)
	_accepted += 1
	if interval_us > 50000:
		_spikes_total += 1
	return true

func mark_event(label: String) -> void:
	mark_event_at(label, Time.get_ticks_usec())

func mark_event_at(label: String, timestamp_us: int) -> bool:
	if not _running or timestamp_us < 0 or label.is_empty():
		return false
	if _event_count > 0:
		var latest: Dictionary = _events[(_event_cursor - 1 + _event_capacity) % _event_capacity]
		if timestamp_us < int(latest.timestamp_us):
			return false
	_events[_event_cursor] = {"timestamp_us": timestamp_us, "label": label.left(160)}
	_event_cursor = (_event_cursor + 1) % _event_capacity
	_event_count = mini(_event_count + 1, _event_capacity)
	_events_total += 1
	return true

func _ordered(ring: Array, cursor: int, count: int, capacity: int) -> Array:
	var rows: Array = []
	for i in range(count):
		rows.append(ring[(cursor - count + i + capacity) % capacity].duplicate(true))
	return rows

static func nearest_rank(sorted_values: Array, fraction: float) -> Variant:
	if sorted_values.is_empty():
		return null
	return sorted_values[maxi(0, mini(sorted_values.size() - 1, int(ceil(fraction * sorted_values.size())) - 1))]

func report() -> Dictionary:
	var rows := _ordered(_samples, _cursor, _count, _capacity)
	var events := _ordered(_events, _event_cursor, _event_count, _event_capacity)
	var values: Array = []
	var spikes: Array = []
	var event_index := 0
	for row: Dictionary in rows:
		values.append(float(row.interval_us) / 1000.0)
		if int(row.interval_us) > 50000:
			var labels: Array = []
			# Both rings are chronological. Visit each retained marker at most once.
			while event_index < events.size() and int(events[event_index].timestamp_us) <= int(row.from_us):
				event_index += 1
			while event_index < events.size() and int(events[event_index].timestamp_us) <= int(row.to_us):
				labels.append(events[event_index].label)
				event_index += 1
			spikes.append({"sequence": row.sequence, "from_us": row.from_us, "to_us": row.to_us, "interval_ms": float(row.interval_us) / 1000.0, "events_within_interval": labels})
	values.sort()
	return {"schema_version": 1, "provenance": "Artist21 S01 implementation; not recovered Astra1 package",
		"measurement": "main_loop_wall_intervals_us", "percentile_method": "nearest_rank_ceil_p_times_n",
		"context": _context.duplicate(true), "engine": Engine.get_version_info().string,
		"debug_build": OS.is_debug_build(), "display_server": DisplayServer.get_name(),
		"running": _running, "warmup_us": _warmup_us, "discarded_warmup_intervals": _discarded,
		"clock_rejected": _clock_rejected, "accepted_total": _accepted, "retained_count": _count,
		"overwritten_count": _accepted - _count, "capacity": _capacity, "event_capacity": _event_capacity,
		"events_total": _events_total, "events_retained_count": _event_count, "events_overwritten_count": _events_total - _event_count,
		"event_association_qualification": "Empty labels do not prove no event; overwritten markers are unavailable",
		"p50_ms": nearest_rank(values, 0.50), "p95_ms": nearest_rank(values, 0.95), "p99_ms": nearest_rank(values, 0.99),
		"spike_threshold_ms": 50, "spikes_total": _spikes_total, "spikes_retained": spikes,
		"samples": rows, "events_retained": events, "monitors_at_report": monitors(),
		"qualification": "Wall loop spacing includes pacing/stalls; not GPU time, presentation latency, release or full-city acceptance"}

static func monitors() -> Dictionary:
	var headless := DisplayServer.get_name() == "headless"
	var tracked_video_bytes := 0.0 if headless else Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var tracked_static_bytes := Performance.get_monitor(Performance.MEMORY_STATIC) if OS.is_debug_build() else 0.0
	# GPU durations are unavailable through this collector. Primitive count is
	# rendered vertices/indices including passes, not unique scene triangles.
	return {"gpu_frame_ms": null, "gpu_frame_reason": "No supported GPU timing source wired",
		"draw_calls_last_frame": null if headless else Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_primitives_last_frame": null if headless else Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"scene_triangles": null, "scene_triangles_reason": "Render primitive monitor is not a unique triangle census",
		"video_memory_bytes": tracked_video_bytes if tracked_video_bytes > 0.0 else null,
		"video_memory_reason": "Positive engine-tracked value only; zero/unsupported is unavailable, not certified board usage",
		"static_memory_bytes": tracked_static_bytes if tracked_static_bytes > 0.0 else null,
		"availability": "Render monitors unavailable in headless; static memory debug only; monitor snapshot can lag up to one second"}
