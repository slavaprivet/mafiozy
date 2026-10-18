extends RefCounted
## Physical signed service route with shared fair capacity. Owns no payment/HP.
const Drive = preload("res://scripts/hospital/npc_simple_hospital.gd")
const Route = preload("res://scripts/hospital/npc_physical_route51.gd")
const Registry = preload("res://scripts/venues/npc_venue_registry29.gd")
const POLL_MS := 250
const APPROACH_STALL_MS := 15000
var _body: CharacterBody3D
var _scene: Node3D
var _door_owner: Node3D
var _clone: Node3D
var _drive: RefCounted
var _support: RefCounted
var _registry: RefCounted
var _map := RID()
var _id := ""
var _key := ""
var _venue := ""
var _kind := ""
var _door := Vector3.ZERO
var _inward := Vector3.ZERO
var _room := Vector3.ZERO
var _outside := Vector3.ZERO
var _inner := Vector3.ZERO
var _staging := Vector3.ZERO
var _legs: Array[Vector3] = []
var _leg := 0
var _phase := "IDLE"
var _reason := ""
var _entered := false
var _sign_text := "РЕСТОРАН"
var _next_poll := 0
var _next_touch := 0
var _next_door := 0
var _progress_at := 0
var _progress_position := Vector3.ZERO
var _waiting_move := false
var _last_queue: Dictionary = {}
var _emergency_exit29 := false
var _entry_bounds30 := AABB()
var _entry_bounds_valid30 := false
var _exit_door_stage56 := Vector3.ZERO
var _exit_door_state56 := ""
var _entry_door_wait56 := false
var _door_hinge56 := Vector3.ZERO
var _door_radius56 := 0.0
var _door_stage_events56: Array = []

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func supported(body: CharacterBody3D, probe: RefCounted) -> bool:
	if not is_instance_valid(body) or probe == null: return false
	var floor_point: Variant = probe.floor_at(body.global_position, body.global_position.y)
	return floor_point is Vector3 and absf(floor_point.y - body.global_position.y) < .08 and probe.standing(body.global_position)

func begin(scene: Node3D, body: CharacterBody3D, map: RID, id: String, sign_text: String = "РЕСТОРАН") -> bool:
	if not is_instance_valid(scene) or not is_instance_valid(body) or _registry != null: return false
	_kind = Registry.kind_of(sign_text)
	if _kind.is_empty(): return _fail("unsupported_signed_service")
	_sign_text = sign_text; _body = body; _scene = scene; _map = map; _id = id
	_key = Registry.life_key(id, body); _entered = false
	_support = Route.new()
	if not _support.configure(body): return _fail("current_capsule_required")
	_registry = Registry.for_scene(scene)
	var now: int = Time.get_ticks_msec()
	_last_queue = _registry.request(id, body, self, _kind, now)
	if _last_queue.state == "reserved": return _accept(_last_queue)
	if _last_queue.state != "waiting": return _fail(str(_last_queue.get("reason", "admission_refused")))
	_phase = "WAITING"; _reason = "capacity_queue"; _next_poll = now + POLL_MS
	return _prepare_wait()

## Account admission checks the real current registry claim, never a success receipt.
func admission_current56(body: CharacterBody3D, id: String, kind: String, phase: String) -> bool:
	if body != _body or id != _id or kind != _kind or phase != _phase or _registry == null: return false
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion(): return false
	if not _registry.owns(_key, self): return false
	var claim: Dictionary = _registry.ledger.requests.get(_key, {})
	return claim.get("kind") == kind and claim.get("state") == ("waiting" if phase == "WAITING" else "reserved")

func _prepare_wait() -> bool:
	# Virtual waiting is distributed at current positions, never at the target door.
	var wait_point: Vector3 = _body.global_position
	for item: Dictionary in _registry._entries.values():
		var normal: Vector3 = item.normal
		var tangent := Vector3(-normal.z, 0.0, normal.x)
		var offset: Vector3 = wait_point - (item.door as Vector3)
		if absf(offset.dot(tangent)) > 1.4 or absf(offset.dot(normal)) > 3.2: continue
		var found := false
		var direction: float = -1.0 if _body.get_instance_id() % 2 == 0 else 1.0
		for side: float in [direction, -direction]:
			for distance: float in [3.2, 4.4, 5.6]:
				var point: Variant = _support.floor_at(item.door - normal * 3.6 + tangent * distance * side, wait_point.y)
				if point is Vector3 and _support.standing(point): wait_point = point; found = true; break
			if found: break
		if not found: return _fail("no_safe_waiting_point")
		break
	_drive = Drive.new()
	_waiting_move = _flat(wait_point, _body.global_position) > .3
	if not _drive.begin(wait_point, _body, _map, _id, "service_approach"): return _fail("waiting_route_refused")
	_progress_at = Time.get_ticks_msec(); _progress_position = _body.global_position
	return true

func _accept(lease: Dictionary) -> bool:
	var entry: Dictionary = _registry.entry(str(lease.venue))
	if entry.is_empty(): return _fail("venue_retired_before_approach")
	var slot: int = int(lease.slot)
	if slot < 0 or slot >= entry.rooms.size(): return _fail("room_slot_missing")
	_door_owner = entry.owner.get_ref() as Node3D; _clone = entry.clone.get_ref() as Node3D
	_door = entry.door; _inward = entry.normal; _outside = entry.outside; _inner = entry.inner; _room = entry.rooms[slot]
	var measured: Dictionary=Registry._bounds(_clone)
	_entry_bounds_valid30=bool(measured.get("ok",false))
	_entry_bounds30=measured.get("box",AABB())
	_venue = str(lease.venue)
	var live_floor: Variant = _support.floor_at(_room, _room.y)
	if not live_floor is Vector3 or absf(live_floor.y - _room.y) > .08 or not _support.standing(_room):
		_registry.reject_path(_key, _venue, Time.get_ticks_msec(), self)
		return _fail("reserved_room_no_longer_clear")
	_registry.ledger.touch(_key, Time.get_ticks_msec())
	if _drive != null: _drive.cancel()
	_drive = Drive.new(); _legs.clear()
	if not _initially_inside30():
		var tangent := Vector3(-_inward.z, 0.0, _inward.x)
		var side: float = -1.0 if slot % 2 == 0 else 1.0
		var staged := false
		for distance: float in [3.6, 4.8, 6.0]:
			var point: Variant = _support.floor_at(_door - _inward * distance + tangent * side * (2.8 + floori(float(slot) / 2.0) * 1.2), _outside.y)
			if point is Vector3 and _support.standing(point): _staging = point; staged = true; break
		if not staged:
			_registry.reject_path(_key, _venue, Time.get_ticks_msec(), self)
			return _fail("safe_exterior_staging_required")
		_legs.append(_staging); _legs.append(_outside); _legs.append(_inner)
	else: _entered = true
	_legs.append(_room); _leg = 0; _phase = "INBOUND"; _reason = ""
	_progress_at = Time.get_ticks_msec(); _progress_position = _body.global_position
	return _start_leg()

func _fail(reason: String) -> bool:
	_reason = reason
	return false

func _start_leg() -> bool:
	if not _drive.begin(_legs[_leg], _body, _map, _id, "service_approach"): return _fail("physical_leg_refused")
	if _phase == "OUTBOUND" and _exit_door_state56 == "approach" and _leg == 0:
		if not _drive.set_service_arrival56(.025): return _fail("door_stage_tight_arrival_refused56")
	_progress_at = Time.get_ticks_msec(); _progress_position = _body.global_position
	return true

func _door_tick() -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_door or not is_instance_valid(_door_owner) or _flat(_body.global_position, _door) > 2.45: return
	_next_door = now + 250
	if float(_door_owner.get("target")) < 1.0: _door_owner.request_door("public", true, _body.global_position, [])

func _door_open56() -> bool:
	return is_instance_valid(_door_owner) and _door_owner.has_method("door_fraction") and float(_door_owner.door_fraction("public")) >= .999

func _door_event56(event: String) -> void:
	_door_stage_events56.append({"event":event,"frame":Engine.get_physics_frames(),"position":_body.global_position,"stage":_exit_door_stage56,"fraction":float(_door_owner.door_fraction("public")) if is_instance_valid(_door_owner) else -1.0})
	if _door_stage_events56.size() > 24: _door_stage_events56.pop_front()

## Conservative horizontal circle around the actual leaf hinge contains every
## door pose. Stage outside it plus the current capsule and native sweep margin;
## do not assume all signed sites have the compact site's 1.6m leaf.
func _prepare_door_stage56() -> bool:
	if not is_instance_valid(_door_owner): return _fail("door_stage_owner_missing56")
	var leaf: Variant = _door_owner.get("leaf")
	var closed: Variant = _door_owner.get("leaf_closed")
	var hinge: Variant = _door_owner.get("hinge")
	if not leaf is Node3D or not closed is Transform3D or not hinge is Vector3: return _fail("door_stage_frame_missing56")
	var parent: Node3D = leaf.get_parent_node_3d()
	_door_hinge56 = parent.to_global(hinge); _door_radius56 = 0.0
	for child: Node in leaf.get_children():
		if not child is CollisionShape3D or child.disabled: continue
		if not child.shape is BoxShape3D: return _fail("door_stage_unknown_leaf_shape56")
		var half: Vector3 = child.shape.size*.5
		var frame: Transform3D = parent.global_transform*closed*child.transform
		for x: float in [-half.x,half.x]:
			for y: float in [-half.y,half.y]:
				for z: float in [-half.z,half.z]:
					_door_radius56 = maxf(_door_radius56,_flat(frame*Vector3(x,y,z),_door_hinge56))
	if _door_radius56 <= 0.0 or not _support.shape.shape is CapsuleShape3D: return _fail("door_stage_capsule_required56")
	var capsule: float = _support.shape.shape.radius
	var tangent := Vector3(-_inward.z,0,_inward.x)
	for depth: float in [2.3,2.2,2.1,2.0]:
		for side: float in [0.0,.4,-.4,.8,-.8]:
			var point: Variant = _support.floor_at(_door+_inward*depth+tangent*side,_inner.y)
			if not point is Vector3 or _flat(point,_door) > 2.4: continue
			if _flat(point,_door_hinge56) < _door_radius56+capsule+.12: continue
			if absf(point.y-_inner.y) > .1 or not _entry_bounds30.has_point(point+Vector3.UP*.3) or not _support.standing(point): continue
			_exit_door_stage56 = point
			return true
	return _fail("supported_door_stage_missing56")

func _restart_exit_stage56() -> bool:
	if not _prepare_door_stage56(): return false
	_drive.cancel(); _legs.assign([_exit_door_stage56,_inner,_outside]); _leg = 0
	_exit_door_state56 = "approach"; _phase = "OUTBOUND"
	_door_event56("physical_stage_begin")
	return _start_leg()

func _stage_safe56() -> bool:
	return _flat(_body.global_position,_exit_door_stage56) <= .04 and _flat(_body.global_position,_door) <= 2.45 and _flat(_body.global_position,_door_hinge56) >= _door_radius56+float(_support.shape.shape.radius)+.08 and supported(_body,_support)

func depth_inside() -> float:
	return (_body.global_position - _door).dot(_inward) if is_instance_valid(_body) else -INF

## The inner half-plane extends across the whole city. A fresh admission also
## needs this measured venue envelope and the supported interior floor level.
## Once entered through the portal, the existing owned exit remains authoritative.
func _inside_envelope30() -> bool:
	return _entry_bounds_valid30 and is_instance_valid(_body) and _entry_bounds30.has_point(_body.global_position+Vector3.UP*.3) and absf(_body.global_position.y-_inner.y)<.1

func _initially_inside30() -> bool:
	return depth_inside()>.55 and _inside_envelope30() and supported(_body,_support)

func needs_exit() -> bool:
	return is_instance_valid(_clone) and not _clone.is_queued_for_deletion() and (_entered or (depth_inside()>-.8 and _inside_envelope30()))

func is_inside() -> bool:
	return _phase == "INSIDE" and _lease_current() and _physical_inside() and (not _registry.staffed29(_venue) or _registry.service_owner29(_key, _venue, self))

func _physical_inside() -> bool:
	return is_instance_valid(_clone) and depth_inside() > .55 and _flat(_body.global_position, _room) <= .40 and absf(_body.global_position.y - _room.y) < .1 and supported(_body, _support)

func is_outside() -> bool:
	return is_instance_valid(_body) and depth_inside() < -1.1 and _flat(_body.global_position, _outside) <= .40 and supported(_body, _support)

func outside_point() -> Vector3:
	return _outside

func _lease_current() -> bool:
	if _registry == null or _venue.is_empty() or not _registry.owns(_key, self): return false
	_registry.refresh(_body, Time.get_ticks_msec())
	if _registry.entry(_venue).is_empty(): return false
	var row: Dictionary = _registry.ledger.requests.get(_key, {})
	return row.get("state") == "reserved" and str(row.get("venue", "")) == _venue

func begin_exit() -> bool:
	if not is_instance_valid(_body) or _drive == null or not needs_exit(): return false
	_exit_door_state56 = ""; _entry_door_wait56 = false
	# Loss of an ordinary claim/controller is NOT a catastrophe permission.
	if not _lease_current():
		if not _emergency_allowed29(): return false
		_emergency_exit29 = true
		_drive.cancel(); _legs = [_outside]; _leg = 0; _phase = "OUTBOUND"
		return _start_leg()
	_drive.cancel(); _legs.clear(); _exit_door_state56 = ""; _entry_door_wait56 = false
	if depth_inside() > .55:
		if not _prepare_door_stage56(): return false
		_legs.append(_exit_door_stage56); _legs.append(_inner); _exit_door_state56 = "approach"
	_legs.append(_outside); _leg = 0; _phase = "OUTBOUND"
	if not _registry.ledger.portal_request(_key, _venue):
		_phase = "PORTAL_WAIT_OUT"; _waiting_move = false; _next_poll = Time.get_ticks_msec() + POLL_MS
		return true
	return _start_leg()

func step(delta: float) -> String:
	if not is_instance_valid(_body) or _drive == null: return "blocked"
	var now: int = Time.get_ticks_msec()
	if _phase == "SERVICE_WAIT":
		if not _lease_current(): _reason = "service_wait_lease_lost"; return "blocked"
		if not _registry.staff_available29(_venue): _reason = "staff_unavailable"; return "blocked"
		_drive.hold(delta)
		if _registry.service_request29(_key, _venue, self):
			var entry: Dictionary = _registry.entry(_venue)
			_room = entry.service_point29; _legs.assign([_room]); _leg = 0; _phase = "SERVICE_APPROACH"
			return "walking" if _start_leg() else "blocked"
		return "waiting"
	if _phase in ["PORTAL_WAIT_IN", "PORTAL_WAIT_OUT"]:
		if not _lease_current(): _reason = "portal_lease_lost"; return "blocked"
		if _waiting_move:
			var wait_result: String = _drive.step(delta)
			if wait_result == "blocked": _reason = "portal_wait_retreat_blocked"; return "blocked"
			if wait_result == "arrived": _waiting_move = false
		else: _drive.hold(delta)
		if now >= _next_poll:
			_next_poll = now + POLL_MS
			if _registry.ledger.portal_request(_key, _venue):
				_phase = "INBOUND" if _phase == "PORTAL_WAIT_IN" else "OUTBOUND"
				return "walking" if _start_leg() else "blocked"
		return "walking"
	if _phase == "WAITING":
		if _waiting_move:
			var waiting_result: String = _drive.step(delta)
			if waiting_result == "blocked": _reason = "waiting_route_blocked"; return "blocked"
			if waiting_result == "arrived": _waiting_move = false
		else: _drive.hold(delta)
		if now >= _next_poll:
			_next_poll = now + POLL_MS
			_last_queue = _registry.poll(_key, now, self)
			if _last_queue.state == "reserved": return "walking" if _accept(_last_queue) else "blocked"
			if _last_queue.state != "waiting": _reason = "capacity_queue_expired_or_retired"; return "blocked"
		return "waiting"
	if not _lease_current() and not (_phase == "OUTBOUND" and _emergency_exit29 and _emergency_allowed29()):
		_reason = "venue_closed_exit_required" if _emergency_allowed29() else "venue_lease_lost"
		return "blocked"
	if now >= _next_touch:
		_next_touch = now + 1000; _registry.ledger.touch(_key, now, _entered)
	_door_tick()
	if not _entered and _initially_inside30(): _entered = true
	# The ordinary lease/portal remains held while gravity settles the same body.
	# Request intent is insufficient: only the real fully-open leaf admits a cross.
	if _phase == "OUTBOUND" and _exit_door_state56 == "opening":
		_drive.hold(delta)
		if not _stage_safe56(): return "walking" if _restart_exit_stage56() else "blocked"
		if not _door_open56() or not _support.standing(_inner): return "walking"
		_exit_door_state56 = "crossing"; _leg += 1; _door_event56("fully_open_crossing")
		return "walking" if _start_leg() else "blocked"
	if _phase == "OUTBOUND" and _exit_door_state56 == "crossing" and depth_inside() > .0 and not _door_open56():
		# A real closure after an attention interruption must physically retreat.
		_door_event56("closure_physical_backoff")
		return "walking" if _restart_exit_stage56() else "blocked"
	if _phase == "INBOUND" and _entry_door_wait56:
		_drive.hold(delta)
		if not needs_exit() and now-_progress_at > APPROACH_STALL_MS:
			_registry.reject_path(_key,_venue,now,self); _reason = "exterior_approach_no_progress"; return "blocked"
		if not _door_open56() or not _support.standing(_inner): return "walking"
		_entry_door_wait56 = false; _leg += 1; _door_event56("fully_open_entry")
		return "walking" if _start_leg() else "blocked"
	var result: String = _drive.step(delta)
	if _flat(_body.global_position, _progress_position) > .1:
		_progress_at = now; _progress_position = _body.global_position
	# Outside no-progress retires this approach and temporarily excludes this site.
	# Inside/exit keeps the capacity until actual exit or lifecycle cancellation.
	if _phase == "INBOUND" and not needs_exit() and now - _progress_at > APPROACH_STALL_MS:
		_registry.reject_path(_key, _venue, now, self); _reason = "exterior_approach_no_progress"; return "blocked"
	if result == "blocked":
		_reason = _drive.last_reason()
		if not needs_exit(): _registry.reject_path(_key, _venue, now, self)
		return "blocked"
	if result != "arrived": return "walking"
	if _phase == "OUTBOUND" and _exit_door_state56 == "approach" and _leg == 0:
		if not _stage_safe56(): return "walking" if _restart_exit_stage56() else "blocked"
		_exit_door_state56 = "opening"; _door_event56("safe_stage_arrived")
		return "walking"
	if _phase == "INBOUND" and _leg == 1 and not _entered:
		_entry_door_wait56 = true
		return "walking"
	if _phase == "INBOUND" and _leg == 0 and not _entered:
		_leg += 1
		if not _registry.ledger.portal_request(_key, _venue):
			_phase = "PORTAL_WAIT_IN"; _waiting_move = false; _next_poll = now + POLL_MS
			return "walking"
		return "walking" if _start_leg() else "blocked"
	if _leg < _legs.size() - 1:
		_leg += 1
		return "walking" if _start_leg() else "blocked"
	if _phase == "SERVICE_APPROACH":
		if not _physical_inside() or not _registry.service_owner29(_key, _venue, self): _reason = "service_slot_not_verified"; return "blocked"
		_phase = "INSIDE"
		return "entered"
	if _phase == "INBOUND":
		if not _physical_inside(): _reason = "interior_not_verified"; return "blocked"
		_entered = true; _phase = "INSIDE"; _registry.ledger.touch(_key, now, true)
		_registry.ledger.portal_release(_key, _venue)
		if _registry.staffed29(_venue):
			_phase = "SERVICE_WAIT"; _registry.service_request29(_key, _venue, self)
			return "waiting"
		return "entered"
	if _phase == "OUTBOUND":
		if not is_outside(): _reason = "exterior_not_verified"; return "blocked"
		_phase = "OUTSIDE"; _registry.release(_key, now, "physical_exit", self)
		return "exited"
	return "walking"

func attention_pause29() -> bool:
	if not is_instance_valid(_body) or _drive == null or _phase in ["CANCELLED", "OUTSIDE", "IDLE"]: return false
	if _entry_door_wait56 or _exit_door_state56 == "opening": return true
	if _phase == "INSIDE" or (_phase in ["WAITING", "PORTAL_WAIT_IN", "PORTAL_WAIT_OUT"] and not _waiting_move): return true
	return _drive.attention_pause29()

func attention_hold29(delta: float) -> void:
	stand(delta)
	var now: int = Time.get_ticks_msec()
	if _registry != null and now >= _next_touch:
		_next_touch = now + 1000; _registry.ledger.touch(_key, now, _entered)
	_progress_at = now; _progress_position = _body.global_position
	_door_tick()

func attention_resume29() -> bool:
	_progress_at = Time.get_ticks_msec(); _progress_position = _body.global_position
	_next_poll = 0
	if _entry_door_wait56 or _exit_door_state56 == "opening": return true
	return _drive.attention_resume29() if _drive != null else false

func stand(delta: float) -> void:
	if _drive != null: _drive.hold(delta)

func hold(delta: float) -> void:
	stand(delta)

func cancel() -> void:
	if _drive != null: _drive.cancel()
	if _registry != null: _registry.release(_key, Time.get_ticks_msec(), "lifecycle_cancel", self)
	_phase = "CANCELLED"

func last_reason() -> String:
	return _reason

func snapshot() -> Dictionary:
	return {"phase":_phase,"reason":_reason,"sign":_sign_text,"venue":_venue,"clone":str(_clone.name) if is_instance_valid(_clone) else "","door":_door,"inward":_inward,"room":_room,"outside":_outside,"leg":_leg,"legs":_legs.size(),"entered":_entered,"queue":_last_queue,"capacity":_registry.snapshot() if _registry != null else {}}

func _emergency_allowed29() -> bool:
	if _registry == null or not is_instance_valid(_clone) or _clone.is_queued_for_deletion(): return false
	return _registry.departure_allowed29(_key, self, _body, _venue)

func service_ready29() -> bool:
	return is_inside()

func publish_service_dwell29(kind: String) -> bool:
	if not is_inside() or kind != _kind: return false
	_body.set_meta("npc_service_dwell29", {"active":true,"frame":Engine.get_physics_frames(),"body_id":_body.get_instance_id(),"kind":kind})
	return true
