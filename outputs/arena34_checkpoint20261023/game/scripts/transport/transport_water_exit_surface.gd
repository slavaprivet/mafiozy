extends RefCounted

const SOURCE_SHA256 := "531fc5b01dd1ad6ce2fda5b8aac76688cf5f1888fc4f05610a7ef176c259a860"
const WALK_SOURCE_SHA256 := "e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47"
const DEFAULT_RISE_SPEED := .9
const DEFAULT_BODY_HEIGHT := 1.1
const WATER_OFFSET_M := .05
const HORIZONTAL_STEP_M := .12
const VERTICAL_STEP_M := .08
const MAX_DT_S := .1

var _configured := false
var _ground_height: Callable
var _water_at: Callable
var _can_occupy: Callable
var _rise_speed := DEFAULT_RISE_SPEED
var _body_height := DEFAULT_BODY_HEIGHT
var _state: Dictionary = {}

static func can_ascend_from_vehicle(position: Vector3, water_at: Callable, can_occupy: Callable, body_height: float = DEFAULT_BODY_HEIGHT) -> bool:
	if not _finite3(position) or not water_at.is_valid() or not can_occupy.is_valid() or not is_finite(body_height) or body_height <= 0.0:
		return false
	var water := _water_sample(water_at.call(position.x, position.z))
	if water.is_empty(): return false
	var target := maxf(position.y, float(water.level) - WATER_OFFSET_M)
	var steps := maxi(1, ceili((target - position.y) / HORIZONTAL_STEP_M))
	for index in range(steps + 1):
		var probe := Vector3(position.x, position.y + (target - position.y) * float(index) / float(steps), position.z)
		var occupied: Variant = can_occupy.call(probe, body_height)
		if typeof(occupied) != TYPE_BOOL or not bool(occupied): return false
	return true

func configure(position: Vector3, ground_height: Callable, water_at: Callable, can_occupy: Callable, rise_speed: float = DEFAULT_RISE_SPEED, body_height: float = DEFAULT_BODY_HEIGHT) -> Dictionary:
	if not _finite3(position) or not ground_height.is_valid() or not water_at.is_valid() or not can_occupy.is_valid() or not is_finite(rise_speed) or rise_speed <= 0.0 or not is_finite(body_height) or body_height <= 0.0:
		return {"ok": false, "error": "INVALID_CONFIGURATION"}
	var initial_water := _water_sample(water_at.call(position.x, position.z))
	_ground_height = ground_height; _water_at = water_at; _can_occupy = can_occupy
	_rise_speed = rise_speed; _body_height = body_height
	_state = {"x": position.x, "y": position.y, "z": position.z, "grounded": false, "blocked": false, "velocity_y": 0.0, "water": initial_water if not initial_water.is_empty() else null}
	_configured = true
	return {"ok": true, "state": state()}

func update(x: float, z: float, dt: float) -> Dictionary:
	if not _configured: return {"ok": false, "error": "NOT_CONFIGURED"}
	if not is_finite(x) or not is_finite(z) or not is_finite(dt) or dt < 0.0:
		return {"ok": false, "error": "INVALID_UPDATE"}
	var staged: Dictionary = _state.duplicate(true)
	var old := Vector3(float(staged.x), float(staged.y), float(staged.z))
	var time := minf(MAX_DT_S, dt)
	var blocked := false
	var horizontal_steps := maxi(1, ceili(Vector2(x - old.x, z - old.z).length() / HORIZONTAL_STEP_M))
	for index in range(1, horizontal_steps + 1):
		var probe := Vector3(old.x + (x - old.x) * float(index) / float(horizontal_steps), float(staged.y), old.z + (z - old.z) * float(index) / float(horizontal_steps))
		var clear: Variant = _can_occupy.call(probe, _body_height)
		if typeof(clear) != TYPE_BOOL: return {"ok": false, "error": "INVALID_OCCUPANCY_RESULT"}
		if not bool(clear): blocked = true; break
		staged.x = probe.x; staged.z = probe.z
	var floor_value: Variant = _ground_height.call(float(staged.x), float(staged.z), float(staged.y))
	if not _finite_number(floor_value): return {"ok": false, "error": "INVALID_FLOOR_RESULT"}
	var floor_y := float(floor_value)
	var water := _water_sample(_water_at.call(float(staged.x), float(staged.z)))
	var target := maxf(floor_y, float(water.level) - WATER_OFFSET_M) if not water.is_empty() else floor_y
	var delta := clampf(target - float(staged.y), -_rise_speed * time, _rise_speed * time)
	var vertical_steps := maxi(1, ceili(absf(delta) / VERTICAL_STEP_M))
	var from_y := float(staged.y)
	for index in range(1, vertical_steps + 1):
		var probe := Vector3(float(staged.x), from_y + delta * float(index) / float(vertical_steps), float(staged.z))
		var clear: Variant = _can_occupy.call(probe, _body_height)
		if typeof(clear) != TYPE_BOOL: return {"ok": false, "error": "INVALID_OCCUPANCY_RESULT"}
		if not bool(clear): blocked = true; break
		staged.y = probe.y
	staged.water = water if not water.is_empty() else null
	staged.floor_y = floor_y
	staged.grounded = absf(float(staged.y) - target) < 0.000001
	staged.blocked = blocked
	staged.velocity_y = (float(staged.y) - old.y) / time if time > 0.0 else 0.0
	_state = staged
	return {"ok": true, "state": state(), "horizontal_steps": horizontal_steps, "vertical_steps": vertical_steps}

func floor_height(x: float, z: float) -> Dictionary:
	if not _configured or not is_finite(x) or not is_finite(z): return {"ok": false, "error": "NOT_CONFIGURED_OR_INVALID"}
	var value: Variant = _ground_height.call(x, z, float(_state.y))
	if not _finite_number(value): return {"ok": false, "error": "INVALID_FLOOR_RESULT"}
	return {"ok": true, "floor_y": float(value)}

func state() -> Dictionary:
	return _state.duplicate(true) if _configured else {}

func dispose() -> void:
	_configured = false; _ground_height = Callable(); _water_at = Callable(); _can_occupy = Callable(); _state.clear()

static func _water_sample(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return {}
	var water: Dictionary = value
	var depth: Variant = water.get("depth")
	# Source tests only `depth > 0`; positive Infinity is therefore admitted.
	if typeof(depth) not in [TYPE_INT, TYPE_FLOAT] or not (float(depth) > 0.0) or not _finite_number(water.get("level")): return {}
	return water.duplicate(true)

static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

static func _finite3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
