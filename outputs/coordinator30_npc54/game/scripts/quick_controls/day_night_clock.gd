extends RefCounted

## Visual time only: no connection to NPC schedules, saving, or the economy.
const DAY_SECONDS_PER_HOUR := 300.0
const NIGHT_SECONDS_PER_HOUR := 150.0
const CYCLE_SECONDS := 5400.0
const DAY_SECONDS := 3600.0

var hour := 17.5
var running := true


func advance(delta: float) -> bool:
	if not running or not is_finite(delta) or delta <= 0.0 or not is_finite(hour):
		return false
	# Start the real-time axis at dawn. Reducing whole cycles first keeps both
	# huge inputs and boundary crossings bounded, without discarding overshoot.
	var current := fposmod(hour, 24.0)
	var elapsed: float
	if current < 6.0:
		elapsed = 4500.0 + current * NIGHT_SECONDS_PER_HOUR
	elif current < 18.0:
		elapsed = (current - 6.0) * DAY_SECONDS_PER_HOUR
	else:
		elapsed = DAY_SECONDS + (current - 18.0) * NIGHT_SECONDS_PER_HOUR
	var next := fposmod(elapsed + fposmod(delta, CYCLE_SECONDS), CYCLE_SECONDS)
	if next < DAY_SECONDS:
		hour = 6.0 + next / DAY_SECONDS_PER_HOUR
	else:
		hour = fposmod(18.0 + (next - DAY_SECONDS) / NIGHT_SECONDS_PER_HOUR, 24.0)
	return true


func set_hour(value: float) -> bool:
	if not is_finite(value):
		return false
	hour = fposmod(value, 24.0)
	return true


func toggle_running() -> bool:
	running = not running
	return running


func label() -> String:
	if not is_finite(hour):
		return "--:--"
	var minutes := floori(fposmod(hour, 24.0) * 60.0 + 0.00000001) % 1440
	return "%02d:%02d" % [minutes / 60, minutes % 60]
