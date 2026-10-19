extends RefCounted
## Experimental drop-in for the local velocity suggestion contract only.
## Movement, native collisions, floor/water, debris and passage exceptions stay in57.
const MAX_ACTORS := 384
const RANGE_M := 3.2
const NEIGHBOR_LIMIT := 8
const HORIZON_S := 1.0
const GAP_M := .12
const MAX_ZONE_BITS := 31
class FrameInput extends RefCounted:
	var key: String
	var position: Vector3
	var velocity: Vector3
	var radius := .36
	var height := 1.9
	var priority := 0
	var waiting := false
	var passage31 := ""
var _map := RID()
var _entries: Dictionary = {}
var _frame := -1
var _valid := false
var _callbacks := 0
var _stale_callbacks := 0
var _callback_physics_misses := 0
var _max_callback_age := 0
var _stale_output_holds := 0
var _snapshot_us := 0
var _submit_us := 0
var _max_snapshot_us := 0
var _rejected := 0
var _zone_bits: Dictionary = {}

func _ensure_map() -> void:
	if _map.is_valid(): return
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(_map, true)

func _new_entry(row: FrameInput) -> Dictionary:
	var agent: RID = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_map(agent, _map)
	NavigationServer3D.agent_set_use_3d_avoidance(agent, false)
	NavigationServer3D.agent_set_neighbor_distance(agent, RANGE_M)
	NavigationServer3D.agent_set_max_neighbors(agent, NEIGHBOR_LIMIT)
	NavigationServer3D.agent_set_time_horizon_agents(agent, HORIZON_S)
	NavigationServer3D.agent_set_time_horizon_obstacles(agent, HORIZON_S)
	NavigationServer3D.agent_set_radius(agent, row.radius + GAP_M * .5)
	NavigationServer3D.agent_set_height(agent, row.height)
	NavigationServer3D.agent_set_max_speed(agent, 1.8)
	NavigationServer3D.agent_set_position(agent, row.position)
	NavigationServer3D.agent_set_velocity_forced(agent, row.velocity)
	NavigationServer3D.agent_set_avoidance_callback(agent, _safe_velocity.bind(row.key, agent))
	NavigationServer3D.agent_set_avoidance_enabled(agent, true)
	return {"rid":agent,"seen":_frame,"safe":Vector3.ZERO,"safe_frame":-100,"waiting":row.waiting,"last_requested":Vector3.ZERO,"requested_frame":-100,"max_speed":1.8}

func snapshot(rows: Array, frame: int, _now_ms: int) -> bool:
	if frame == _frame: return _valid
	if frame < _frame or rows.size() > MAX_ACTORS: _rejected += 1; return false
	var started: int = Time.get_ticks_usec()
	_frame = frame; _valid = false; _submit_us = 0
	_ensure_map()
	_zone_bits.clear()
	for row: FrameInput in rows:
		if not row.passage31.is_empty() and not _zone_bits.has(row.passage31):
			if _zone_bits.size() >= MAX_ZONE_BITS: _rejected += 1; return false
			_zone_bits[row.passage31] = 1 << (_zone_bits.size() + 1)
	var seen: Dictionary = {}
	for row: FrameInput in rows:
		if row.key.is_empty() or seen.has(row.key) or not row.position.is_finite() or not row.velocity.is_finite() or row.radius < .1 or row.radius > .75 or row.height < .5 or row.height > 2.9:
			_rejected += 1; continue
		seen[row.key] = true
		if not _entries.has(row.key): _entries[row.key] = _new_entry(row)
		var entry: Dictionary = _entries[row.key]
		entry.seen = frame; entry.waiting = row.waiting
		var agent: RID = entry.rid
		NavigationServer3D.agent_set_position(agent, row.position)
		NavigationServer3D.agent_set_radius(agent, row.radius + GAP_M * .5)
		NavigationServer3D.agent_set_height(agent, row.height)
		NavigationServer3D.agent_set_avoidance_priority(agent, 1.0 if row.priority > 0 else .5)
		# Only peers granted the SAME current native passage permission ignore one another.
		# Outside/other-zone agents remain visible. No blanket avoidance_enabled=false.
		var layer: int = int(_zone_bits.get(row.passage31, 1))
		NavigationServer3D.agent_set_avoidance_layers(agent, layer)
		NavigationServer3D.agent_set_avoidance_mask(agent, 0xffffffff ^ layer if not row.passage31.is_empty() else 0xffffffff)
	for key: String in _entries.keys():
		if not seen.has(key): _remove(key)
	_snapshot_us = Time.get_ticks_usec() - started
	_max_snapshot_us = maxi(_max_snapshot_us, _snapshot_us)
	_valid = true
	return true

func _safe_velocity(velocity: Vector3, key: String, exact_rid: RID) -> void:
	if not _entries.has(key) or _entries[key].rid != exact_rid:
		_stale_callbacks += 1; return
	_callbacks += 1
	if not Engine.is_in_physics_frame(): _callback_physics_misses += 1
	var entry: Dictionary = _entries[key]
	entry.safe = velocity if velocity.is_finite() else Vector3.ZERO
	entry.safe_frame = Engine.get_physics_frames()

func steer(key: String, direction: Vector3, speed: float) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not _valid or not _entries.has(key) or not direction.is_finite() or not is_finite(speed) or speed < 0.0:
		return {"direction":Vector3.ZERO,"ratio":0.0,"waiting":true,"reason":"no_current_snapshot","replan":false}
	var entry: Dictionary = _entries[key]
	var desired: Vector3 = Vector3(direction.x,0,direction.z).normalized() * speed
	if entry.waiting: desired = Vector3.ZERO
	if not is_equal_approx(float(entry.max_speed), maxf(speed,.001)):
		NavigationServer3D.agent_set_max_speed(entry.rid, maxf(speed,.001)); entry.max_speed = maxf(speed,.001)
	NavigationServer3D.agent_set_velocity(entry.rid, desired)
	entry.last_requested = desired; entry.requested_frame = _frame
	var safe: Vector3 = entry.safe
	safe.y = 0.0
	if int(entry.safe_frame) >= 0: _max_callback_age = maxi(_max_callback_age, _frame - int(entry.safe_frame))
	if _frame - int(entry.safe_frame) > 1: _stale_output_holds += 1
	if entry.waiting or _frame - int(entry.safe_frame) > 1: safe = Vector3.ZERO
	var magnitude: float = minf(safe.length(), speed)
	var result := {"direction":safe.normalized() if magnitude > .0001 else Vector3.ZERO,"ratio":magnitude/maxf(speed,.0001),"waiting":magnitude <= .0001,"reason":"portal_fifo_wait" if entry.waiting else "native_rvo","replan":false}
	_submit_us += Time.get_ticks_usec() - started
	return result

func _remove(key: String) -> void:
	var agent: RID = _entries[key].rid
	NavigationServer3D.agent_set_avoidance_callback(agent, Callable())
	NavigationServer3D.agent_set_avoidance_enabled(agent, false)
	NavigationServer3D.free_rid(agent)
	_entries.erase(key)

func dispose() -> void:
	for key: String in _entries.keys(): _remove(key)
	if _map.is_valid(): NavigationServer3D.free_rid(_map); _map = RID()
	_valid = false

func _notification(what: int) -> void:
	# During PREDELETE the instance can no longer dispatch its own methods.
	if what != NOTIFICATION_PREDELETE: return
	for entry: Dictionary in _entries.values():
		NavigationServer3D.agent_set_avoidance_callback(entry.rid, Callable())
		NavigationServer3D.agent_set_avoidance_enabled(entry.rid, false)
		NavigationServer3D.free_rid(entry.rid)
	if _map.is_valid(): NavigationServer3D.free_rid(_map)

func diagnostics() -> Dictionary:
	return {"actors":_entries.size(),"frame":_frame,"snapshot_us":_snapshot_us,"submit_us":_submit_us,"max_snapshot_us":_max_snapshot_us,"callbacks":_callbacks,"stale_callbacks":_stale_callbacks,"callback_physics_misses":_callback_physics_misses,"max_callback_age_frames":_max_callback_age,"stale_output_holds":_stale_output_holds,"active_zone_bits":_zone_bits.size(),"rejected":_rejected,"server_compute_us_included":false,"cadence":"native_each_physics_frame"}
