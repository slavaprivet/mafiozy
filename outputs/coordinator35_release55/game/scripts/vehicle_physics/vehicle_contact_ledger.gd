class_name NativeVehicleContactLedger
extends RefCounted

const DEFAULT_CAPACITY := 64
const EMPTY_TICK := -9223372036854775807
var _capacity := DEFAULT_CAPACITY
var _keys := PackedStringArray()
var _last_seen_ticks := PackedInt64Array()
var _active := PackedByteArray()
var _accepted_tick := PackedInt64Array()
var overflow_total := 0
var suppressed_total := 0
var high_water := 0
var _used := 0

func _init(capacity := DEFAULT_CAPACITY) -> void:
	_capacity = clampi(capacity, 8, 256)
	_keys.resize(_capacity)
	_last_seen_ticks.resize(_capacity)
	_active.resize(_capacity)
	_accepted_tick.resize(_capacity)
	for i in _capacity:
		_last_seen_ticks[i] = EMPTY_TICK
		_accepted_tick[i] = EMPTY_TICK

func begin_tick(physics_tick: int) -> void:
	for i in _capacity:
		if _active[i] != 0 and physics_tick - _last_seen_ticks[i] > 2:
			_active[i] = 0

func accept(counterpart_id: String, physics_tick: int) -> bool:
	var slot := _slot(counterpart_id)
	if slot < 0:
		overflow_total += 1
		return false
	_last_seen_ticks[slot] = physics_tick
	if _active[slot] != 0:
		suppressed_total += 1
		return false
	_active[slot] = 1
	_accepted_tick[slot] = physics_tick
	return true

func _slot(key: String) -> int:
	var start := posmod(hash(key), _capacity)
	var reusable := -1
	for offset in _capacity:
		var index := (start + offset) % _capacity
		if _keys[index].is_empty():
			if reusable < 0: reusable = index
			break
		if _keys[index] == key:
			return index
		if _active[index] == 0 and reusable < 0:
			reusable = index
	if reusable < 0:
		return -1
	if _keys[reusable].is_empty():
		_used += 1
		high_water = maxi(high_water, _used)
	_keys[reusable] = key
	_last_seen_ticks[reusable] = EMPTY_TICK
	_accepted_tick[reusable] = EMPTY_TICK
	_active[reusable] = 0
	return reusable

func reset_lifetime() -> void:
	_used = 0
	overflow_total = 0
	suppressed_total = 0
	high_water = 0
	for i in _capacity:
		_keys[i] = ""
		_last_seen_ticks[i] = EMPTY_TICK
		_accepted_tick[i] = EMPTY_TICK
		_active[i] = 0

func status() -> Dictionary:
	return {"capacity": _capacity, "used": _used, "high_water": high_water,
		"overflow_total": overflow_total, "suppressed_total": suppressed_total}
