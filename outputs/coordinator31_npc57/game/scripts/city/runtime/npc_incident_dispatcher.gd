extends RefCounted
## Event-driven local perception for committed gunshots.
## One shot performs a bounded snapshot (no per-frame resident scan); accepted
## witness deliveries use a bounded TTL queue with round-robin event fairness.

const MAX_PENDING_EVENTS := 32
const MAX_ROSTER_SNAPSHOT := 512
const MAX_CAPTURE_TIME_US := 4000
const MAX_LOS_QUERIES_PER_EVENT := 48
const MAX_WITNESSES_PER_EVENT := 32
const MAX_DELIVERIES_PER_STEP := 16
const MAX_SEEN_EVENTS := 128
const EVENT_MAX_AGE_ACTIVE_SECONDS := 5.0
const SOURCE_CELLS := 10.0
const SOURCE_METRES_PER_CELL := 4.1
const WITNESS_RADIUS_M := SOURCE_CELLS * SOURCE_METRES_PER_CELL
const AUDIBLE_THROUGH_WALL_M := WITNESS_RADIUS_M * 0.45
const FOV_DOT_MIN := 0.3420201433 # cos(70 degrees), Walk's 140-degree visual FOV.
const LOS_COLLISION_MASK := 5 | 256 # Same native world masks as the committed projectile ray.
const EVENT_SCHEMA := "local_city_incident/v1"

var _weapons_ref: WeakRef
var _population_ref: WeakRef
var _los_override := Callable()
var _queue: Array[Dictionary] = []
var _delivery_cursor := 0
var _roster_cursor := 0
var _seen: Dictionary = {}
var _seen_ring: Array[String] = []
var _ray := PhysicsRayQueryParameters3D.new()
var _disposed := false
var _clock_frame := -1
var _active_seconds := 0.0
var _stats := {
	"admitted": 0, "duplicates": 0, "queue_overflow": 0, "invalid_shots": 0,
	"roster_caps": 0, "roster_time_budget_drops": 0, "candidate_records": 0,
	"distance_rejects": 0, "fov_rejects": 0, "los_queries": 0,
	"los_blocked": 0, "los_budget_drops": 0, "witness_budget_drops": 0,
	"audible_witnesses": 0, "visual_witnesses": 0, "no_perception_events": 0,
	"delivered": 0, "stale_life": 0, "owner_refusals": 0,
	"retryable_refusals": 0, "expired_events": 0, "expired_witnesses": 0,
	"paused_steps": 0, "last_capture_us": 0, "max_capture_us": 0,
	"last_step_us": 0, "max_step_us": 0, "last_step_deliveries": 0,
	"last_reason": ""
}

func configure(weapons: Node, population: RefCounted, los_override: Callable = Callable()) -> Dictionary:
	if _disposed or _weapons_ref != null or not is_instance_valid(weapons) or not is_instance_valid(population):
		return {"ok": false, "reason": "lifetime_or_owners"}
	if not weapons.is_inside_tree() or not weapons.has_signal("shot_emitted"):
		return {"ok": false, "reason": "committed_shot_signal_required"}
	for method: String in ["incident_candidate_count", "incident_candidate_at", "incident_target_current", "incident_can_hear", "incident_submit_witness", "incident_game_paused"]:
		if not population.has_method(method): return {"ok": false, "reason": "population_port:" + method}
	_weapons_ref = weakref(weapons)
	_population_ref = weakref(population)
	_los_override = los_override
	_ray.collision_mask = LOS_COLLISION_MASK
	_ray.hit_from_inside = true
	weapons.shot_emitted.connect(_on_shot)
	return {"ok": true, "event_source": "preview_weapons.shot_emitted", "scan_mode": "committed_shot_only_bounded_snapshot", "server_authority": false}

func _current() -> bool:
	if _disposed or not Thread.is_main_thread() or _weapons_ref == null or _population_ref == null: return false
	var weapons: Variant = _weapons_ref.get_ref()
	var population: Variant = _population_ref.get_ref()
	return is_instance_valid(weapons) and weapons.is_inside_tree() and is_instance_valid(population)

func _on_shot(shot: Dictionary, muzzle: Dictionary, _camera_origin: Vector3, _camera_direction: Vector3) -> void:
	enqueue_shot(shot, muzzle)

## Signal callback: bounded roster read and LOS work is tied to an actual committed shot.
func enqueue_shot(shot: Dictionary, muzzle: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not _current(): return _reject("owners_not_current")
	var shot_id: Variant = shot.get("shotId")
	var sequence: Variant = shot.get("sequence")
	var weapon_id: Variant = shot.get("weaponId")
	var origin: Variant = muzzle.get("origin")
	if not shot_id is String or shot_id.is_empty() or shot_id.length() > 220 or not _valid_shot_sequence(sequence) or not weapon_id is String or weapon_id.is_empty() or not origin is Vector3 or not origin.is_finite():
		_stats.invalid_shots += 1
		return _reject("committed_shot_identity")
	var weapons: Node = _weapons_ref.get_ref()
	var event_id := "gunshot:%d:%s" % [weapons.get_instance_id(), shot_id]
	if _seen.has(event_id):
		_stats.duplicates += 1
		return {"ok": true, "duplicate": true, "event_id": event_id}
	if _queue.size() >= MAX_PENDING_EVENTS:
		_stats.queue_overflow += 1
		return _reject("pending_event_capacity", event_id)
	var population: RefCounted = _population_ref.get_ref()
	var witnesses := _capture_witnesses(population, origin, started)
	_remember(event_id)
	_stats.admitted += 1
	if witnesses.is_empty():
		_stats.no_perception_events += 1
		_stats.last_reason = "no_perception_candidate"
		return {"ok": true, "event_id": event_id, "queued": false, "witnesses": 0}
	var queued := {
		"event_id": event_id, "weapon_id": weapon_id, "origin": origin,
		"created_active_seconds": _active_seconds, "witnesses": witnesses,
		"cursor": 0
	}
	_queue.append(queued)
	_stats.last_reason = "accepted"
	return {"ok": true, "event_id": event_id, "queued": true, "witnesses": witnesses.size(), "pending_events": _queue.size(), "capture_us": int(_stats.last_capture_us), "server_authority": false}

func _valid_shot_sequence(value: Variant) -> bool:
	# Walk emits a float sequence whose value is an integer. Preserve that
	# committed identity while rejecting fractions, NaN and unsafe magnitudes.
	if value is int: return value >= 1
	return value is float and is_finite(value) and value >= 1.0 and value <= 9007199254740991.0 and value == floorf(value)

func _capture_witnesses(population: RefCounted, origin: Vector3, started: int) -> Array[Dictionary]:
	var owner_count := maxi(0, int(population.incident_candidate_count()))
	if owner_count == 0: return []
	if owner_count > MAX_ROSTER_SNAPSHOT: _stats.roster_caps += 1
	var scan_count := mini(owner_count, MAX_ROSTER_SNAPSHOT)
	var start_index := posmod(_roster_cursor, owner_count)
	var nearby: Array[Dictionary] = []
	var visited := 0
	for offset in scan_count:
		if Time.get_ticks_usec() - started >= MAX_CAPTURE_TIME_US:
			_stats.roster_time_budget_drops += scan_count - visited
			break
		var index := (start_index + offset) % owner_count
		visited += 1
		var owner: Variant = population.incident_candidate_at(index)
		if not is_instance_valid(owner) or not owner.has_method("incident_witness_snapshot"): continue
		var observed: Variant = owner.incident_witness_snapshot()
		if not observed is Dictionary or not _eligible_observation(observed) or int(observed.owner_instance_id) != owner.get_instance_id() or not bool(population.incident_target_current(owner, observed)): continue
		var to_source: Vector3 = origin - observed.position
		var distance_sq := to_source.length_squared()
		if not is_finite(distance_sq) or distance_sq > WITNESS_RADIUS_M * WITNESS_RADIUS_M:
			_stats.distance_rejects += 1
			continue
		var facing: Vector3 = observed.forward
		facing.y = 0.0
		to_source.y = 0.0
		var in_fov := to_source.length_squared() <= 0.16 or (facing.length_squared() > 0.0001 and facing.normalized().dot(to_source.normalized()) >= FOV_DOT_MIN)
		if not in_fov: _stats.fov_rejects += 1
		nearby.append({"owner_ref": weakref(owner), "owner_instance_id": owner.get_instance_id(), "observation": observed.duplicate(), "distance_sq": distance_sq, "in_fov": in_fov})
	_stats.candidate_records += visited
	_roster_cursor = (start_index + maxi(1, visited)) % owner_count
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a.distance_sq), float(b.distance_sq)):
			return str(a.observation.source_id) < str(b.observation.source_id)
		return float(a.distance_sq) < float(b.distance_sq))
	var witnesses: Array[Dictionary] = []
	var los_queries := 0
	for candidate_index in nearby.size():
		var candidate: Dictionary = nearby[candidate_index]
		var distance := sqrt(float(candidate.distance_sq))
		var near_hear := distance <= AUDIBLE_THROUGH_WALL_M
		var need_los := bool(candidate.in_fov) or not near_hear
		var clear := false
		if need_los:
			if los_queries >= MAX_LOS_QUERIES_PER_EVENT:
				_stats.los_budget_drops += 1
			else:
				los_queries += 1
				_stats.los_queries += 1
				clear = _line_clear(candidate.observation, origin)
				if not clear: _stats.los_blocked += 1
		var hearing_owner: Variant = candidate.owner_ref.get_ref() if candidate.owner_ref is WeakRef else null
		var can_hear := is_instance_valid(hearing_owner) and bool(population.incident_can_hear(hearing_owner, candidate.observation)) and (near_hear or clear)
		var is_visual := bool(candidate.in_fov) and clear
		if not is_visual and not can_hear: continue
		candidate.kind = "gunshot_visual" if is_visual else "heard_gunfire"
		candidate.line_of_sight = clear
		candidate.visibility_confirmed = is_visual
		witnesses.append(candidate)
		if is_visual: _stats.visual_witnesses += 1
		else: _stats.audible_witnesses += 1
		if witnesses.size() >= MAX_WITNESSES_PER_EVENT:
			_stats.witness_budget_drops += maxi(0, nearby.size() - candidate_index - 1)
			break
	var elapsed := Time.get_ticks_usec() - started
	_stats.last_capture_us = elapsed
	_stats.max_capture_us = maxi(int(_stats.max_capture_us), int(elapsed))
	return witnesses

func step(delta: float = 0.0) -> void:
	if not _current(): return
	var population: RefCounted = _population_ref.get_ref()
	if bool(population.incident_game_paused()):
		_stats.paused_steps += 1
		return
	var frame := Engine.get_physics_frames()
	if frame != _clock_frame:
		_clock_frame = frame
		if is_finite(delta) and delta > 0.0 and delta <= 0.05: _active_seconds += delta
	var started := Time.get_ticks_usec()
	_expire_oldest()
	var attempts := 0
	var delivered_this_step := 0
	while attempts < MAX_DELIVERIES_PER_STEP and not _queue.is_empty():
		var index := _next_delivery_index()
		if index < 0: break
		var queued: Dictionary = _queue[index]
		var witnesses: Array = queued.witnesses
		var cursor := int(queued.cursor)
		if cursor >= witnesses.size():
			_remove_event(index)
			continue
		var candidate: Dictionary = witnesses[cursor]
		var owner: Variant = candidate.owner_ref.get_ref() if candidate.owner_ref is WeakRef else null
		if not is_instance_valid(owner) or owner.get_instance_id() != int(candidate.owner_instance_id) or not owner.has_method("incident_witness_snapshot"):
			_stats.stale_life += 1
			queued.cursor = cursor + 1
			_attempt_finished(index)
			attempts += 1
			continue
		var current_observation: Variant = owner.incident_witness_snapshot()
		if not current_observation is Dictionary or not _same_life(candidate.observation, current_observation) or not bool(population.incident_target_current(owner, current_observation)):
			_stats.stale_life += 1
			queued.cursor = cursor + 1
			_attempt_finished(index)
			attempts += 1
			continue
		var event := _make_witness_event(queued, candidate, current_observation)
		var receipt: Variant = population.incident_submit_witness(owner, event)
		attempts += 1
		delivered_this_step += 1
		if receipt is Dictionary and bool(receipt.get("accepted", false)):
			_stats.delivered += 1
			queued.cursor = cursor + 1
			_attempt_finished(index)
		elif receipt is Dictionary and bool(receipt.get("retryable", false)) and int(candidate.get("attempts", 0)) < 4:
			candidate.attempts = int(candidate.get("attempts", 0)) + 1
			_stats.retryable_refusals += 1
			_stats.last_reason = str(receipt.get("reason", "owner_busy"))
			_advance_delivery_cursor(index)
		else:
			_stats.owner_refusals += 1
			_stats.last_reason = str(receipt.get("reason", "owner_refused")) if receipt is Dictionary else "owner_result"
			queued.cursor = cursor + 1
			_attempt_finished(index)
	_expire_oldest()
	var elapsed := Time.get_ticks_usec() - started
	_stats.last_step_us = elapsed
	_stats.max_step_us = maxi(int(_stats.max_step_us), int(elapsed))
	_stats.last_step_deliveries = delivered_this_step

func _make_witness_event(queued: Dictionary, candidate: Dictionary, current_observation: Dictionary) -> Dictionary:
	var visible := str(candidate.kind) == "gunshot_visual"
	var event := {
		"schema": EVENT_SCHEMA, "kind": str(candidate.kind), "event_id": str(queued.event_id),
		"audible": true, "visibility_confirmed": visible,
		"line_of_sight": bool(candidate.line_of_sight), "fov_confirmed": bool(candidate.in_fov),
		"source_identified": false, "distance_m": sqrt(float(candidate.distance_sq)),
		"witness_source_id": str(current_observation.source_id),
		"witness_life_generation": int(current_observation.life_generation),
		"witness_session_id": str(current_observation.session_id),
		"witness_body_instance_id": int(current_observation.body_instance_id),
		"witness_role_scope": str(current_observation.role_scope),
		"created_active_seconds": float(queued.created_active_seconds),
		"authority": "local_presentation", "server_ack": false,
		"hp_changed": false, "money_changed": false
	}
	# Heard gunfire has no location/weapon attribution; visual sighting proves only
	# that the muzzle event was visible, not a shooter identity or server authority.
	if visible:
		event["origin"] = queued.origin
		event["weapon_id"] = str(queued.weapon_id)
	return event

func _eligible_observation(value: Dictionary) -> bool:
	if value.get("eligible", false) != true or not value.get("position") is Vector3 or not value.position.is_finite() or not value.get("forward") is Vector3 or not value.forward.is_finite(): return false
	if str(value.get("source_id", "")).is_empty() or str(value.get("session_id", "")).is_empty() or not value.get("life_generation") is int or int(value.life_generation) < 1 or not value.get("owner_instance_id") is int or not value.get("body_instance_id") is int: return false
	if value.get("role_scope", "") != "ordinary_unarmed_civilian" or not value.get("body") is Node3D or not is_instance_valid(value.body) or not value.get("token") is Dictionary: return false
	if str(value.token.get("source_id", "")) != str(value.source_id) or str(value.token.get("session_id", "")) != str(value.session_id) or int(value.token.get("life_generation", -1)) != int(value.life_generation) or value.token.get("body") != value.body: return false
	if value.body.get_instance_id() != int(value.body_instance_id): return false
	return true

func _same_life(before: Dictionary, current: Dictionary) -> bool:
	return _eligible_observation(current) and int(current.get("owner_instance_id", -1)) == int(before.get("owner_instance_id", -2)) and str(current.get("source_id", "")) == str(before.source_id) and str(current.get("session_id", "")) == str(before.session_id) and int(current.get("life_generation", -1)) == int(before.life_generation) and int(current.get("body_instance_id", -1)) == int(before.get("body_instance_id", -2)) and str(current.get("role_scope", "")) == str(before.get("role_scope", ""))

func _line_clear(observation: Dictionary, origin: Vector3) -> bool:
	if _los_override.is_valid():
		var result: Variant = _los_override.call(observation, origin)
		if result is bool: return result
		if result is Dictionary and result.get("blocked") is bool: return not result.blocked
		return false
	var weapons: Node = _weapons_ref.get_ref()
	var body: Variant = observation.get("body")
	var scene: Variant = weapons.get("scene")
	if not is_instance_valid(body) or not is_instance_valid(scene) or not scene is Node3D or not scene.is_inside_tree(): return false
	var from: Vector3 = observation.position + Vector3.UP * 1.45
	if from.distance_squared_to(origin) <= 0.0001: return true
	_ray.from = from
	_ray.to = origin
	var excluded: Array[RID] = [body.get_rid()]
	var shooter: Variant = weapons.get("player")
	if is_instance_valid(shooter) and shooter is CollisionObject3D: excluded.append(shooter.get_rid())
	_ray.exclude = excluded
	return scene.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()

func _next_delivery_index() -> int:
	if _queue.is_empty(): return -1
	var size := _queue.size()
	var start := posmod(_delivery_cursor, size)
	for offset in size:
		var index := (start + offset) % size
		if int(_queue[index].get("cursor", 0)) < (_queue[index].get("witnesses", []) as Array).size(): return index
	return -1

func _attempt_finished(index: int) -> void:
	if index < 0 or index >= _queue.size(): return
	var queued: Dictionary = _queue[index]
	if int(queued.cursor) >= (queued.witnesses as Array).size(): _remove_event(index)
	else: _advance_delivery_cursor(index)

func _advance_delivery_cursor(index: int) -> void:
	if _queue.is_empty(): _delivery_cursor = 0
	else: _delivery_cursor = (index + 1) % _queue.size()

func _remove_event(index: int) -> void:
	if index < 0 or index >= _queue.size(): return
	_queue.remove_at(index)
	if _queue.is_empty(): _delivery_cursor = 0
	else:
		if index < _delivery_cursor: _delivery_cursor -= 1
		_delivery_cursor = posmod(_delivery_cursor, _queue.size())

func _expire_oldest() -> void:
	while not _queue.is_empty():
		var queued: Dictionary = _queue[0]
		if not is_finite(_active_seconds) or _active_seconds - float(queued.created_active_seconds) <= EVENT_MAX_AGE_ACTIVE_SECONDS: break
		_stats.expired_witnesses += maxi(0, (queued.witnesses as Array).size() - int(queued.cursor))
		_stats.expired_events += 1
		_remove_event(0)

func _remember(event_id: String) -> void:
	_seen[event_id] = true
	_seen_ring.append(event_id)
	if _seen_ring.size() > MAX_SEEN_EVENTS:
		_seen.erase(_seen_ring.pop_front())

func _reject(reason: String, event_id: String = "") -> Dictionary:
	_stats.last_reason = reason
	return {"ok": false, "reason": reason, "event_id": event_id}

func snapshot() -> Dictionary:
	var result := _stats.duplicate(true)
	result.merge({
		"ready": _current(), "pending_events": _queue.size(), "seen_event_ids": _seen.size(),
		"scan_mode": "committed_shot_only", "max_pending_events": MAX_PENDING_EVENTS,
		"max_roster_snapshot": MAX_ROSTER_SNAPSHOT, "max_capture_time_us": MAX_CAPTURE_TIME_US,
		"max_los_queries_per_event": MAX_LOS_QUERIES_PER_EVENT,
		"max_witnesses_per_event": MAX_WITNESSES_PER_EVENT,
		"max_deliveries_per_step": MAX_DELIVERIES_PER_STEP,
		"active_seconds": _active_seconds, "server_authority": false
	}, true)
	return result

func dispose() -> void:
	if _disposed: return
	_disposed = true
	if _weapons_ref != null:
		var weapons: Variant = _weapons_ref.get_ref()
		if is_instance_valid(weapons) and weapons.has_signal("shot_emitted") and weapons.shot_emitted.is_connected(_on_shot): weapons.shot_emitted.disconnect(_on_shot)
	_queue.clear()
	_seen.clear()
	_seen_ring.clear()
	_weapons_ref = null
	_population_ref = null
	_los_override = Callable()
