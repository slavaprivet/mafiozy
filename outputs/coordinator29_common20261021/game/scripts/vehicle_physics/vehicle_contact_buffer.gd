class_name NativeVehicleContactBuffer
extends RefCounted

const DEFAULT_CAPACITY := 32
var _capacity := DEFAULT_CAPACITY
var _physics_ticks := PackedInt64Array()
var _sequences := PackedInt64Array()
var _life_generations := PackedInt64Array()
var _vehicle_ids := PackedStringArray()
var _counterpart_ids := PackedStringArray()
var _points := PackedVector3Array()
var _normals := PackedVector3Array()
var _relative_velocities := PackedVector3Array()
var _impulses := PackedFloat32Array()
var _head := 0
var _size := 0
var overflow_total := 0
var high_water := 0
var _gap_since_drain := false

func _init(capacity := DEFAULT_CAPACITY) -> void:
	_capacity = clampi(capacity, 4, 128)
	_physics_ticks.resize(_capacity)
	_sequences.resize(_capacity)
	_life_generations.resize(_capacity)
	_vehicle_ids.resize(_capacity)
	_counterpart_ids.resize(_capacity)
	_points.resize(_capacity)
	_normals.resize(_capacity)
	_relative_velocities.resize(_capacity)
	_impulses.resize(_capacity)

func push_contact(vehicle_id: String, life_generation: int, physics_tick: int, sequence: int,
		counterpart_id: String, point_m: Vector3, normal: Vector3,
		relative_velocity_mps: Vector3, impulse_proxy_ns: float) -> bool:
	if _size == _capacity:
		overflow_total += 1
		_gap_since_drain = true
		return false
	var index := (_head + _size) % _capacity
	_physics_ticks[index] = physics_tick
	_sequences[index] = sequence
	_life_generations[index] = life_generation
	_vehicle_ids[index] = vehicle_id
	_counterpart_ids[index] = counterpart_id
	_points[index] = point_m
	_normals[index] = normal
	_relative_velocities[index] = relative_velocity_mps
	_impulses[index] = impulse_proxy_ns
	_size += 1
	high_water = maxi(high_water, _size)
	return true

func drain() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.resize(_size)
	for i in _size:
		var index := (_head + i) % _capacity
		result[i] = {
			"vehicle_id": _vehicle_ids[index], "life_generation": _life_generations[index],
			"physics_tick": _physics_ticks[index], "contact_sequence": _sequences[index],
			"counterpart_id": _counterpart_ids[index], "point_m": _points[index],
			"normal": _normals[index], "relative_velocity_mps": _relative_velocities[index],
			"impulse_proxy_ns": _impulses[index], "proposal_only": true,
		}
	_head = 0
	_size = 0
	_gap_since_drain = false
	return result

func size() -> int:
	return _size

func capacity() -> int:
	return _capacity

func has_gap() -> bool:
	return _gap_since_drain

func clear() -> void:
	_head = 0
	_size = 0
	_gap_since_drain = false

func reset_lifetime() -> void:
	clear()
	overflow_total = 0
	high_water = 0
