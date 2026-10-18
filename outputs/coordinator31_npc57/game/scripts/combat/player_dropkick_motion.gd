extends RefCounted
## Source Walk root trajectory proposal only. The existing player remains the
## sole movement, collision and final skeleton owner. No damage is applied.
const DURATION := 1.25
const DESCENT_END := .65
const MAX_AGE_STEP := .075
var sequence := -1
var epoch := -1
var yaw := 0.0
var age := 0.0
var active := false
var landed := false
var horizontal_stopped := false
var reason := ""
var _start_ms := 0.0
var _unit := 1.0
var _base_y := 0.0
var _air_height := 0.0
var _distance := 0.0

static func smooth(value: float, a: float, b: float) -> float:
	var t := clampf((value-a)/(b-a),0.0,1.0)
	return t*t*(3.0-2.0*t)

static func source_distance(at: float, unit: float) -> float:
	return (2.8*smooth(at,0.0,.34)+.35*smooth(at,.34,.58))*unit

func begin(start: Dictionary, now_ms: float, current_epoch: int, unit: float, base_y: float, actual_air_height: float) -> bool:
	if active or start.get("type") != "dropkick" or not start.get("seq") is int or start.seq < 0: return false
	for key: String in ["sourceStartAt","duration","yaw"]:
		if not start.get(key) is float and not start.get(key) is int: return false
		if not is_finite(float(start[key])): return false
	if not is_equal_approx(float(start.duration),DURATION) or not is_finite(now_ms) or now_ms < start.sourceStartAt or now_ms-start.sourceStartAt > 75.0: return false
	if current_epoch < 0 or not is_finite(unit) or unit <= 0.0 or unit > 4.1 or not is_finite(base_y) or not is_finite(actual_air_height) or actual_air_height < .04 or actual_air_height > 6.0: return false
	sequence = start.seq; epoch = current_epoch; yaw = start.yaw
	_start_ms = start.sourceStartAt; _unit = unit; _base_y = base_y; _air_height = actual_air_height
	age = 0.0; _distance = 0.0; landed = false; horizontal_stopped = false; reason = ""; active = true
	return true

func propose(now_ms: float, current_epoch: int) -> Dictionary:
	if not active: return {"valid":false,"reason":"inactive"}
	if current_epoch != epoch or not is_finite(now_ms): cancel("epoch_or_clock"); return {"valid":false,"reason":reason}
	var next_age := (now_ms-_start_ms)/1000.0
	if next_age < age:
		cancel("non_continuous_clock"); return {"valid":false,"reason":reason}
	if next_age-age > MAX_AGE_STEP:
		# A slow impact frame must not teleport the body or cut the visible kick.
		# Discard all remaining horizontal travel; native vertical collision stays.
		horizontal_stopped = true
	age = next_age
	var desired := source_distance(age,_unit)
	var travel := 0.0 if horizontal_stopped else maxf(0.0,desired-_distance)
	_distance = desired
	return {"valid":true,"sequence":sequence,"age":age,"direction":Vector3(sin(yaw),0.0,cos(yaw)),"travel":travel,
		"desired_y":_base_y+_air_height*(1.0-smooth(age,.10,DESCENT_END)),"gravity_fall":age>=DESCENT_END and not landed,"landed":landed,
		"animation_done":age>=DURATION,"motion_done":landed and age>=DURATION}

func stop_horizontal() -> void:
	# Native obstruction consumes root travel without canceling the visible kick.
	# Contact/HP still requires the separate original-foot geometry proof.
	if active: horizontal_stopped = true

func confirm_landing() -> void:
	if active: landed = true

func cancel(why: String) -> void:
	active = false; reason = why

func snapshot() -> Dictionary:
	return {"active":active,"sequence":sequence,"epoch":epoch,"age":age,"landed":landed,"horizontal_stopped":horizontal_stopped,"reason":reason,"source_distance":_distance,"source_scale":_unit}
