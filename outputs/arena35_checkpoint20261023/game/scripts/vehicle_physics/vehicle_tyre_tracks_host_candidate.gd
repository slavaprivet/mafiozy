class_name NativeVehicleTyreTracksHostCandidate
extends Node3D
## TEST_ONLY integration seam. One host per native vehicle, attached beside the
## moving body; render pool is top-level so its segment poses remain world-space.

const Provider = preload("res://scripts/vehicle_physics/vehicle_tyre_contact_provider_fast_candidate.gd")
const Tracks = preload("res://scripts/vehicle_physics/vehicle_tyre_tracks_paged_candidate.gd")

var _body: NativeVehicleBody
var _tracks: NativeVehicleTyreTracksPagedCandidate
var _vehicle_id := ""
var _life_generation := -1
var _last_tick := -1
var _rows: Array[Dictionary] = []

func configure(body: NativeVehicleBody) -> bool:
	if _body != null or body == null or not is_instance_valid(body) \
			or body.profile == null or not is_inside_tree() or not body.is_inside_tree():
		return false
	var vehicle_id := str(body.profile.vehicle_id)
	var life_generation := int(body.profile.life_generation)
	if vehicle_id.is_empty() or life_generation < 1:
		return false
	var tracks := Tracks.new()
	tracks.name = "NativeTyreTracks"
	tracks.top_level = true
	add_child(tracks)
	tracks.global_transform = Transform3D.IDENTITY
	if not tracks.configure(vehicle_id, life_generation):
		tracks.queue_free()
		return false
	_body = body
	_tracks = tracks
	_vehicle_id = vehicle_id
	_life_generation = life_generation
	return true

func _physics_process(delta: float) -> void:
	if _tracks == null:
		return
	if _body == null or not is_instance_valid(_body) or not is_instance_valid(_tracks) \
			or not _body.is_inside_tree() or _body.profile == null \
			or str(_body.profile.vehicle_id) != _vehicle_id \
			or int(_body.profile.life_generation) != _life_generation:
		dispose()
		queue_free()
		return
	# Same direct published tick/velocity used by the lower-allocation adapter;
	# snapshot_state() duplicates several arrays not needed for presentation.
	var tick: int = _body._physics_tick
	if tick <= _last_tick:
		return
	_last_tick = tick
	var velocity: Vector3 = _body._last_linear_velocity if tick > 0 else _body.linear_velocity
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if not Provider.collect_into(_body, tick, _rows):
		_rows.clear()
	if not _tracks.step(delta, tick, planar_speed, _rows):
		dispose()
		queue_free()

func stats() -> Dictionary:
	return {"configured": _body != null and is_instance_valid(_body),
		"vehicle_id": _vehicle_id, "life_generation": _life_generation,
		"last_tick": _last_tick,
		"tracks": _tracks.stats() if _tracks != null and is_instance_valid(_tracks) else {}}

func dispose() -> void:
	set_physics_process(false)
	_rows.clear()
	_body = null
	if _tracks != null and is_instance_valid(_tracks):
		_tracks.dispose()
	_tracks = null
	_vehicle_id = ""
	_life_generation = -1
	_last_tick = -1
