extends RefCounted
## Standalone source-clock seam. It never saves, networks or reads scene state.
## advance() performs at most one source minute per call, matching a delayed
## browser timer without a catch-up burst.

var hour := 12
var minute := 0
var elapsed_seconds := 0.0
var ticks := 0
var disposed := false


func _init(initial_hour: Variant = 12, initial_minute: Variant = 0) -> void:
	if _valid_clock(initial_hour, initial_minute):
		hour = int(initial_hour)
		minute = int(initial_minute)


static func _finite_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value))


static func _valid_clock(candidate_hour: Variant, candidate_minute: Variant) -> bool:
	return _finite_integer(candidate_hour) and int(candidate_hour) >= 0 and int(candidate_hour) <= 23 \
		and _finite_integer(candidate_minute) and int(candidate_minute) >= 0 and int(candidate_minute) <= 59


func advance(delta_seconds: Variant) -> bool:
	if disposed or not (delta_seconds is int or delta_seconds is float) \
			or not is_finite(float(delta_seconds)) or float(delta_seconds) < 0.0:
		return false
	elapsed_seconds += float(delta_seconds)
	if elapsed_seconds < 1.0:
		return false
	# A late host call is one source timer callback, never a backlog replay.
	elapsed_seconds = 0.0
	var total := (hour * 60 + minute + 1) % 1440
	hour = total / 60
	minute = total % 60
	ticks += 1
	return true


func sample_into(target: RefCounted) -> bool:
	if disposed or target == null or not "hour" in target or not "minute" in target:
		return false
	target.set("hour", hour)
	target.set("minute", minute)
	return true


func set_clock(candidate_hour: Variant, candidate_minute: Variant) -> bool:
	if disposed or not _valid_clock(candidate_hour, candidate_minute):
		return false
	hour = int(candidate_hour)
	minute = int(candidate_minute)
	elapsed_seconds = 0.0
	return true


func dispose() -> void:
	disposed = true
