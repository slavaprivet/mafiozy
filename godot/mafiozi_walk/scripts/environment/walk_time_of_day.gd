extends RefCounted
## Pure, presentation-only port of assets/maps/city_rebuild_v1/walk_time_of_day.mjs.
## The caller owns the city clock, weather, interiors and Godot resources.

const POLL_INTERVAL_MS := 250.0
const SMOOTH_RATE := 2.4

const DAY_SKY_HEX := "3d7298"
const DAWN_SKY_HEX := "b66f63"
const DUSK_SKY_HEX := "b2574d"
const NIGHT_SKY_HEX := "0a1930"
const DAY_GROUND_HEX := "51473c"
const NIGHT_GROUND_HEX := "324158"
const DAY_SUN_HEX := "ffe0ad"
const DAWN_SUN_HEX := "ffb071"
const DUSK_SUN_HEX := "ff8c58"


class ClockSample extends RefCounted:
	var hour: Variant = null
	var minute: Variant = null


class Frame extends RefCounted:
	var hour := 12.0
	var daylight := 1.0
	var dawn := 0.0
	var dusk := 0.0
	var warmth := 0.0
	var night := 0.0
	var lamps_scheduled_on := false
	var lamp_power := 0.0
	var phase: StringName = &"day"
	var background := Color.BLACK
	var fog_color := Color.BLACK
	var fog_density := 0.00305
	var ambient_color := Color.BLACK
	var ambient_ground_color := Color.BLACK
	var ambient_intensity := 2.5
	var sun_color := Color.WHITE
	var sun_intensity := 3.5
	var sun_offset := Vector3.ZERO
	var exposure := 1.32
	var environment_intensity := 0.82


var output := Frame.new()
var target := Frame.new()
var samples := 0
var accepted_samples := 0
var rejected_samples := 0
var next_sample_at_ms := -INF
var last_at_ms := 0.0
var qa_offset_hours := 0.0
var disposed := false

var _hour := 12
var _minute := 0
var _initial_hour := 12
var _initial_minute := 0
var _rate := SMOOTH_RATE
var _weather: StringName = &"clear"
var _has_last_at := false
var _ready := false
var _clock_scratch := ClockSample.new()

var _day_sky := _linear_hex(DAY_SKY_HEX)
var _dawn_sky := _linear_hex(DAWN_SKY_HEX)
var _dusk_sky := _linear_hex(DUSK_SKY_HEX)
var _night_sky := _linear_hex(NIGHT_SKY_HEX)
var _day_ground := _linear_hex(DAY_GROUND_HEX)
var _night_ground := _linear_hex(NIGHT_GROUND_HEX)
var _day_sun := _linear_hex(DAY_SUN_HEX)
var _dawn_sun := _linear_hex(DAWN_SUN_HEX)
var _dusk_sun := _linear_hex(DUSK_SUN_HEX)


func _init(initial_hour: Variant = 12, initial_minute: Variant = 0,
		smoothing_rate: Variant = SMOOTH_RATE, weather: StringName = &"clear") -> void:
	if is_valid_city_clock(initial_hour, initial_minute):
		_hour = int(initial_hour)
		_minute = int(initial_minute)
	_initial_hour = _hour
	_initial_minute = _minute
	if _finite_number(smoothing_rate):
		_rate = maxf(0.0, float(smoothing_rate))
	_weather = weather
	_sample_into(target, _hour, _minute, qa_offset_hours, _weather)
	_copy_frame(output, target)


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _integer_number(value: Variant) -> bool:
	return _finite_number(value) and float(value) == floor(float(value))


static func is_valid_city_clock(hour: Variant, minute: Variant) -> bool:
	return _integer_number(hour) and int(hour) >= 0 and int(hour) <= 23 \
		and _integer_number(minute) and int(minute) >= 0 and int(minute) <= 59


static func _linear_hex(value: String) -> Color:
	return Color.from_string(value, Color.BLACK).srgb_to_linear()


static func _clamp01(value: float) -> float:
	return clampf(value, 0.0, 1.0)


static func _smoothstep(value: float, minimum: float, maximum: float) -> float:
	var t := _clamp01((value - minimum) / (maximum - minimum))
	return t * t * (3.0 - 2.0 * t)


static func _normalized_hour(hour: int, minute: int, offset: float) -> float:
	return fposmod(float(hour) + float(minute) / 60.0 + offset, 24.0)


func sample_into(frame: Frame, hour: Variant, minute: Variant = 0,
		offset: Variant = 0.0, weather: StringName = &"clear") -> bool:
	if frame == null or not is_valid_city_clock(hour, minute) or not _finite_number(offset):
		return false
	_sample_into(frame, int(hour), int(minute), float(offset), weather)
	return true


func _sample_into(frame: Frame, hour: int, minute: int, offset: float,
		weather: StringName) -> void:
	var normalized := _normalized_hour(hour, minute, offset)
	var sun_height := sin((normalized - 6.0) / 24.0 * TAU)
	var daylight := _smoothstep(sun_height, -0.2, 0.4)
	var dawn := 1.0 - _smoothstep(absf(normalized - 6.35), 0.15, 1.85)
	var dusk := 1.0 - _smoothstep(absf(normalized - 18.65), 0.15, 2.05)
	_fill_output(frame, normalized, daylight, dawn, dusk, weather)


func _fill_output(frame: Frame, hour: float, daylight: float, dawn: float,
		dusk: float, weather: StringName) -> void:
	daylight = _clamp01(daylight)
	dawn = _clamp01(dawn)
	dusk = _clamp01(dusk)
	var warmth := maxf(dawn * 0.72, dusk)
	var night := 1.0 - daylight
	var scheduled := hour < 7.0 or hour >= 17.0
	var lamp_power := maxf(0.48, night) if scheduled else 0.0

	var background := _night_sky.lerp(_day_sky, daylight)
	if dawn > 0.001:
		background = background.lerp(_dawn_sky, dawn * 0.42)
	if dusk > 0.001:
		background = background.lerp(_dusk_sky, dusk * 0.5)
	var sun_color := _day_sun
	if dawn > 0.001:
		sun_color = sun_color.lerp(_dawn_sun, dawn)
	if dusk > 0.001:
		sun_color = sun_color.lerp(_dusk_sun, dusk)

	frame.hour = hour
	frame.daylight = daylight
	frame.dawn = dawn
	frame.dusk = dusk
	frame.warmth = warmth
	frame.night = night
	frame.lamps_scheduled_on = scheduled
	frame.lamp_power = lamp_power
	frame.phase = &"dawn" if dawn > 0.15 else (&"day" if daylight > 0.62 else (&"dusk" if dusk > 0.15 else &"night"))
	frame.background = background
	frame.fog_color = background
	frame.fog_density = 0.00305 + night * 0.00062 \
		+ (0.00048 if weather == &"rain" else (0.00025 if weather == &"snow" else 0.0))
	frame.ambient_color = Color(
		0.43 + 0.35 * daylight + 0.08 * warmth,
		0.51 + 0.3 * daylight + 0.035 * warmth,
		0.7 + 0.18 * daylight, 1.0)
	frame.ambient_ground_color = _night_ground.lerp(_day_ground, daylight)
	frame.ambient_intensity = 1.32 + 1.18 * daylight + 0.08 * warmth
	frame.sun_color = sun_color
	frame.sun_intensity = 0.42 + 3.08 * daylight + 0.16 * warmth
	frame.sun_offset = Vector3(
		cos(hour / 24.0 * TAU) * 75.0,
		16.0 + daylight * 74.0,
		sin(hour / 24.0 * TAU) * 65.0)
	frame.exposure = 1.16 + daylight * 0.16 + warmth * 0.035
	frame.environment_intensity = 0.46 + daylight * 0.36 + warmth * 0.04


func update(now_ms: Variant, clock_source: Variant = null,
		weather: StringName = &"") -> Frame:
	if disposed:
		return output
	var now := float(now_ms) if _finite_number(now_ms) else 0.0
	if now >= next_sample_at_ms:
		next_sample_at_ms = now + POLL_INTERVAL_MS
		samples += 1
		if _read_clock(clock_source):
			accepted_samples += 1
		else:
			rejected_samples += 1
	if not weather.is_empty():
		_weather = weather
	_sample_into(target, _hour, _minute, qa_offset_hours, _weather)
	var dt := 0.0 if not _has_last_at else minf(0.1, maxf(0.0, (now - last_at_ms) / 1000.0))
	last_at_ms = now
	_has_last_at = true
	if not _ready:
		output.daylight = target.daylight
		output.dawn = target.dawn
		output.dusk = target.dusk
		_ready = true
	else:
		var ease := 1.0 - exp(-dt * _rate)
		output.daylight = lerpf(output.daylight, target.daylight, ease)
		output.dawn = lerpf(output.dawn, target.dawn, ease)
		output.dusk = lerpf(output.dusk, target.dusk, ease)
	_fill_output(output, target.hour, output.daylight, output.dawn, output.dusk, _weather)
	return output


func _read_clock(source: Variant) -> bool:
	var candidate: Variant = source
	if source is Callable:
		var reader: Callable = source
		if not reader.is_valid():
			return false
		candidate = reader.call()
	elif source is Object and source.has_method("sample_into"):
		_clock_scratch.hour = null
		_clock_scratch.minute = null
		if source.sample_into(_clock_scratch) != true:
			return false
		candidate = _clock_scratch
	if candidate is Dictionary:
		if not is_valid_city_clock(candidate.get("hour"), candidate.get("minute")):
			return false
		_hour = int(candidate.hour)
		_minute = int(candidate.minute)
		return true
	if candidate is ClockSample and is_valid_city_clock(candidate.hour, candidate.minute):
		_hour = int(candidate.hour)
		_minute = int(candidate.minute)
		return true
	return false


func reset(clock: Variant = null, now_ms: Variant = 0.0) -> Frame:
	if disposed:
		return output
	_hour = _initial_hour
	_minute = _initial_minute
	if clock is Dictionary and is_valid_city_clock(clock.get("hour"), clock.get("minute")):
		_hour = int(clock.hour)
		_minute = int(clock.minute)
	next_sample_at_ms = -INF
	last_at_ms = 0.0
	_has_last_at = false
	_ready = false
	samples = 0
	accepted_samples = 0
	rejected_samples = 0
	return update(now_ms, {"hour": _hour, "minute": _minute})


func set_offset(hours: Variant) -> bool:
	if not _finite_number(hours):
		return false
	qa_offset_hours = float(hours)
	return true


func write_diagnostics(into: Dictionary) -> Dictionary:
	into["sample_interval_ms"] = POLL_INTERVAL_MS
	into["smoothing_rate"] = _rate
	into["samples"] = samples
	into["accepted_samples"] = accepted_samples
	into["rejected_samples"] = rejected_samples
	into["next_sample_at_ms"] = next_sample_at_ms
	into["last_at_ms"] = last_at_ms if _has_last_at else null
	into["qa_offset_hours"] = qa_offset_hours
	into["disposed"] = disposed
	return into


func dispose() -> void:
	disposed = true


func _copy_frame(destination: Frame, source: Frame) -> void:
	destination.hour = source.hour
	destination.daylight = source.daylight
	destination.dawn = source.dawn
	destination.dusk = source.dusk
	destination.warmth = source.warmth
	destination.night = source.night
	destination.lamps_scheduled_on = source.lamps_scheduled_on
	destination.lamp_power = source.lamp_power
	destination.phase = source.phase
	destination.background = source.background
	destination.fog_color = source.fog_color
	destination.fog_density = source.fog_density
	destination.ambient_color = source.ambient_color
	destination.ambient_ground_color = source.ambient_ground_color
	destination.ambient_intensity = source.ambient_intensity
	destination.sun_color = source.sun_color
	destination.sun_intensity = source.sun_intensity
	destination.sun_offset = source.sun_offset
	destination.exposure = source.exposure
	destination.environment_intensity = source.environment_intensity
