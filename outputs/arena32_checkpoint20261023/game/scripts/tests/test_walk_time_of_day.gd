extends SceneTree

const TimeOfDay = preload("res://scripts/environment/walk_time_of_day.gd")
const PreviewClock = preload("res://scripts/environment/preview_city_clock.gd")
const EnvironmentAdapter = preload("res://scripts/environment/walk_environment_adapter.gd")
const ORACLE := "res://scripts/tests/fixtures/walk_time_of_day_oracle.json"

var checks := 0
var failures: Array[String] = []
var maximum_error := 0.0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value and failures.size() < 40:
		failures.append(label)


func close(actual: float, expected: float, label: String, epsilon := 0.000001) -> void:
	var error := absf(actual - expected)
	maximum_error = maxf(maximum_error, error)
	check(error <= epsilon, "%s: %.12f != %.12f" % [label, actual, expected])


func color_hex(color: Color) -> String:
	return color.linear_to_srgb().to_html(false)


func independent_smooth(value: float, minimum: float, maximum: float) -> float:
	var t := clampf((value - minimum) / (maximum - minimum), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func test_oracle(oracle: Dictionary) -> void:
	check(oracle.schema == "mafiozi.walk-time-of-day-oracle/v1", "oracle schema")
	check(oracle.poll_interval_ms == TimeOfDay.POLL_INTERVAL_MS, "poll interval pinned")
	check(oracle.smoothing_rate == TimeOfDay.SMOOTH_RATE, "smoothing pinned")
	var sampler := TimeOfDay.new()
	for sample: Dictionary in oracle.samples:
		var frame := TimeOfDay.Frame.new()
		check(sampler.sample_into(frame, sample.hour, sample.minute), sample.id + " admitted")
		for field: String in ["daylight", "dawn", "dusk", "night", "lamp_power", "fog_density",
				"ambient_intensity", "sun_intensity", "exposure", "environment_intensity"]:
			close(float(frame.get(field)), float(sample[field]), sample.id + ":" + field)
		check(frame.phase == StringName(sample.phase), sample.id + ":phase")
		check(color_hex(frame.background) == sample.background, sample.id + ":background")
		check(color_hex(frame.ambient_color) == sample.ambient_color, sample.id + ":ambient")
		check(color_hex(frame.ambient_ground_color) == sample.ambient_ground_color, sample.id + ":ground")
		check(color_hex(frame.sun_color) == sample.sun_color, sample.id + ":sun")
		var expected_offset := Vector3(float(sample.sun_offset[0]), float(sample.sun_offset[1]), float(sample.sun_offset[2]))
		close(frame.sun_offset.distance_to(expected_offset), 0.0, sample.id + ":sun_offset")
	sampler.dispose()


func test_properties() -> void:
	var sampler := TimeOfDay.new()
	var frame := TimeOfDay.Frame.new()
	for minute_of_day in range(0, 1440, 15):
		var hour := minute_of_day / 60
		var minute := minute_of_day % 60
		check(sampler.sample_into(frame, hour, minute), "quarter-hour accepted")
		var fractional := float(minute_of_day) / 60.0
		var sun_height := sin((fractional - 6.0) / 24.0 * TAU)
		var daylight := independent_smooth(sun_height, -0.2, 0.4)
		var dawn := 1.0 - independent_smooth(absf(fractional - 6.35), 0.15, 1.85)
		var dusk := 1.0 - independent_smooth(absf(fractional - 18.65), 0.15, 2.05)
		var warmth := maxf(dawn * 0.72, dusk)
		close(frame.daylight, daylight, "property daylight")
		close(frame.dawn, dawn, "property dawn")
		close(frame.dusk, dusk, "property dusk")
		close(frame.night, 1.0 - daylight, "property night")
		close(frame.lamp_power, maxf(0.48, 1.0 - daylight) if fractional < 7.0 or fractional >= 17.0 else 0.0, "property lamp")
		close(frame.exposure, 1.16 + daylight * 0.16 + warmth * 0.035, "property exposure")
	for invalid in [[null, 0], [true, 0], ["12", 0], [12.5, 0], [-1, 0], [24, 0],
			[12, null], [12, false], [12, "30"], [12, 30.5], [12, -1], [12, 60], [NAN, 0], [12, INF]]:
		check(not TimeOfDay.is_valid_city_clock(invalid[0], invalid[1]), "strict invalid clock")
	check(TimeOfDay.is_valid_city_clock(0, 0), "clock minimum")
	check(TimeOfDay.is_valid_city_clock(23.0, 59.0), "integral decoded float")
	check(not sampler.sample_into(frame, 24, 0), "sample rejects hour 24")
	check(not sampler.sample_into(frame, 12, 0, "1"), "sample rejects string offset")
	check(sampler.sample_into(frame, 0, 0, -1.0) and is_equal_approx(frame.hour, 23.0), "negative QA wrap")
	check(sampler.sample_into(frame, 23, 0, 1.0) and is_zero_approx(frame.hour), "positive QA wrap")
	var clear_fog := frame.fog_density
	check(sampler.sample_into(frame, 12, 0, 0.0, &"rain"), "rain sample")
	close(frame.fog_density, 0.00353, "rain fog")
	check(sampler.sample_into(frame, 12, 0, 0.0, &"snow"), "snow sample")
	close(frame.fog_density, 0.00330, "snow fog")
	check(clear_fog > 0.0, "finite fog")
	sampler.dispose()


func test_controller_and_provider() -> void:
	var invalid_startup := TimeOfDay.new("9", null)
	close(invalid_startup.update(0.0, null).hour, 12.0, "invalid startup holds noon")
	check(invalid_startup.rejected_samples == 1, "invalid startup diagnostic")
	invalid_startup.dispose()
	var clock := PreviewClock.new(0, 0)
	var controller := TimeOfDay.new(0, 0)
	var output_id := controller.output.get_instance_id()
	var target_id := controller.target.get_instance_id()
	var first = controller.update(0.0, clock)
	check(first.get_instance_id() == output_id, "stable initial output")
	check(controller.accepted_samples == 1, "first provider sample")
	controller.update(249.0, clock)
	check(controller.samples == 1, "no early provider read")
	controller.update(250.0, clock)
	check(controller.samples == 2, "250ms provider read")
	controller.update(10000.0, clock)
	check(controller.samples == 3, "late frame has one provider read")
	check(controller.output.get_instance_id() == output_id and controller.target.get_instance_id() == target_id, "stable controller frames")
	check(not clock.advance(0.999), "provider below one second")
	check(clock.advance(0.001) and clock.minute == 1, "provider one minute tick")
	check(clock.advance(8.0) and clock.minute == 2, "provider delayed call no catch-up")
	check(clock.set_clock(23, 59) and clock.advance(1.0) and clock.hour == 0 and clock.minute == 0, "provider day wrap")
	check(not clock.set_clock("12", 0), "provider strict schema")

	var held := TimeOfDay.new(9, 30)
	held.update(0.0, {"hour": 9, "minute": 30})
	for invalid in [{}, {"hour": "17", "minute": 0}, {"hour": 24, "minute": 0}, null]:
		held.update(float((held.samples + 1) * 250), invalid)
		close(held.target.hour, 9.5, "invalid holds last good")
	check(held.rejected_samples == 4, "rejected diagnostics")
	check(held.set_offset(15.0), "finite offset accepted")
	held.update(1500.0, {"hour": 9, "minute": 30})
	close(held.target.hour, 0.5, "controller offset wrap")
	check(not held.set_offset("12") and is_equal_approx(held.qa_offset_hours, 15.0), "invalid offset retained")
	var diagnostics := {}
	check(held.write_diagnostics(diagnostics) == diagnostics and diagnostics.samples == held.samples, "caller-owned diagnostics reused")

	var smoothing := TimeOfDay.new(0, 0)
	smoothing.update(0.0, {"hour": 0, "minute": 0})
	smoothing.update(250.0, {"hour": 12, "minute": 0})
	var day_zero := smoothing.output.daylight
	smoothing.update(350.0, {"hour": 12, "minute": 0})
	check(smoothing.output.daylight > day_zero and smoothing.output.daylight < 1.0, "exponential smoothing advances")
	var held_day := smoothing.output.daylight
	smoothing.update(350.0, {"hour": 12, "minute": 0})
	close(smoothing.output.daylight, held_day, "dt0 smoothing")
	for timestamp in range(450, 4051, 100): smoothing.update(float(timestamp), {"hour": 12, "minute": 0})
	check(smoothing.output.daylight > 0.999, "smoothing converges")
	var disposed_hour := smoothing.output.hour
	smoothing.dispose(); smoothing.dispose()
	check(smoothing.update(9000.0, {"hour": 22, "minute": 0}).get_instance_id() == smoothing.output.get_instance_id(), "disposed stable output")
	close(smoothing.output.hour, disposed_hour, "disposed no-op")
	held.dispose(); controller.dispose(); clock.dispose()


func test_environment_adapter() -> void:
	var host := Node3D.new()
	get_root().add_child(host)
	var environment := Environment.new()
	var atmosphere := ProceduralSkyMaterial.new()
	var sun := DirectionalLight3D.new()
	host.add_child(sun)
	var sampler := TimeOfDay.new()
	var frame := TimeOfDay.Frame.new()
	sampler.sample_into(frame, 18, 39)
	var adapter := EnvironmentAdapter.new()
	check(adapter.configure(environment, atmosphere, sun), "adapter configures")
	check(adapter.apply(frame), "adapter applies exterior")
	check(environment.fog_enabled and environment.fog_mode == Environment.FOG_MODE_EXPONENTIAL, "exponential fog mapping")
	close(environment.fog_density, frame.fog_density, "adapter fog")
	close(environment.tonemap_exposure, frame.exposure, "adapter exposure")
	close(sun.light_energy, frame.sun_intensity, "adapter sun energy")
	check(sun.basis.is_finite() and sun.light_color.is_equal_approx(frame.sun_color), "adapter sun direction/color")
	var before := [environment.fog_density, environment.tonemap_exposure, atmosphere.sky_top_color, sun.light_energy, sun.basis]
	sampler.sample_into(frame, 0, 0)
	check(not adapter.apply(frame, true), "interior apply skipped")
	check(before == [environment.fog_density, environment.tonemap_exposure, atmosphere.sky_top_color, sun.light_energy, sun.basis], "interior channels untouched")
	check(adapter.applied_frames == 1 and adapter.skipped_interior_frames == 1, "adapter diagnostics")
	adapter.dispose(); adapter.dispose()
	check(not adapter.apply(frame), "disposed adapter no-op")
	sampler.dispose(); host.free()


func benchmark() -> Dictionary:
	var sampler := TimeOfDay.new()
	var frame := TimeOfDay.Frame.new()
	var iterations := 250000
	var sink := 0.0
	var started := Time.get_ticks_usec()
	for index in iterations:
		var minute_of_day := index % 1440
		sampler.sample_into(frame, minute_of_day / 60, minute_of_day % 60, 0.0, &"rain" if index % 3 == 0 else &"clear")
		sink += frame.daylight + frame.lamp_power
	var elapsed := Time.get_ticks_usec() - started
	check(is_finite(sink), "benchmark sink")
	var controller := TimeOfDay.new()
	var clock := PreviewClock.new()
	var stable_id := controller.output.get_instance_id()
	started = Time.get_ticks_usec()
	for index in 100000:
		controller.update(float(index) * 16.0, clock)
	var controller_elapsed := Time.get_ticks_usec() - started
	check(controller.output.get_instance_id() == stable_id, "benchmark stable controller output")
	var result := {"sample_iterations": iterations, "sample_total_us": elapsed,
		"sample_mean_us": float(elapsed) / iterations, "controller_iterations": 100000,
		"controller_total_us": controller_elapsed, "controller_mean_us": float(controller_elapsed) / 100000.0,
		"stable_frame_id": stable_id, "scope": "headless CPU; no GPU, LIVE or full-scene FPS"}
	controller.dispose(); clock.dispose(); sampler.dispose()
	return result


func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	check(parsed is Dictionary, "oracle parses")
	if not parsed is Dictionary:
		print(JSON.stringify({"checks": checks, "failures": failures}))
		quit(1)
		return
	test_oracle(parsed)
	test_properties()
	test_controller_and_provider()
	test_environment_adapter()
	var perf := benchmark()
	print("WALK_TIME_OF_DAY_NATIVE ", JSON.stringify({"passed": failures.is_empty(), "checks": checks,
		"failures": failures, "max_scalar_error": maximum_error, "performance": perf,
		"engine": Engine.get_version_info().string, "integration": false, "live": false}))
	quit(0 if failures.is_empty() else 1)
