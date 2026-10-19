extends "res://diagnostic/clocked_main.gd"
## Isolated actual-main seam. Pause-only: no source object or ground mutation.
var editor_water_pause_usec := 0

func _process(delta: float) -> void:
	if not preview_ready or _player == null:
		return
	_position_door_hint()
	if not preview_physics_fault and is_instance_valid(preview_transport) and preview_transport.character_physics != null and preview_transport.character_physics.mode == "FAULTED":
		_show_physics_fault()
	if not preview_dead and not preview_physics_fault and _player.global_position.y < -25.0:
		_die_outside_world()
	var now: int = Time.get_ticks_usec()
	if _water_host != null:
		_water_host.advance(float(now - editor_water_pause_usec) / 1000000.0)
	_samples.append(float(now - _last_frame_usec) / 1000.0)
	_last_frame_usec = now
	_runtime_seconds += delta
	if not _capture_done and not _capture_path.is_empty() and _runtime_seconds > 5.0:
		_capture_done = true
		_save_preview_frame.call_deferred()
	if _samples.size() > 600:
		_samples.pop_front()
	_clock += delta
	if _clock < 1.0:
		return
	_clock = 0.0
	var sorted: Array[float] = _samples.duplicate()
	sorted.sort()
	var p95: float = sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))]
	_stats.text = "%d FPS · p95 %.1f мс" % [Engine.get_frames_per_second(), p95]
