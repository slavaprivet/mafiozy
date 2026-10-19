extends RefCounted
## One registry per scene, one cheap door inventory per second, geometry once/site.
## A sign alone is not admission: immutable physical door, floor and capsule remain.
const Capacity = preload("npc_venue_capacity29.gd")
const Swing = preload("res://scripts/city/runtime/npc_city_clone_door_swing.gd")
const Physical = preload("res://scripts/hospital/npc_physical_route51.gd")
const META := "npc_venue_registry29"
const DEFAULT_CAPACITY := {"restaurant":6,"shop":4,"bank":2,"hospital":4}
const MAX_SITES := 64
const MAX_DISCOVERIES := 2
const MAX_CANDIDATES := 16
var ledger := Capacity.new()
var _scene: WeakRef
var _entries: Dictionary = {}
var _actors: Dictionary = {}
var _next_refresh := 0
var _next_reap := 0
var _blocked_until: Dictionary = {}
var _departures29: Dictionary = {}
var _discovery_retry29: Dictionary = {}

static func for_scene(scene: Node3D) -> RefCounted:
	if not is_instance_valid(scene): return null
	var existing: Variant = scene.get_meta(META) if scene.has_meta(META) else null
	if existing is RefCounted: return existing
	var registry: RefCounted = load("res://scripts/venues/npc_venue_registry29.gd").new()
	registry._scene = weakref(scene)
	scene.set_meta(META, registry)
	return registry

static func kind_of(sign: String) -> String:
	var text: String = sign.to_upper()
	if text.contains("БОЛЬНИЦ"): return "hospital"
	if text.contains("РЕСТОРАН"): return "restaurant"
	if text.contains("МАГАЗИН"): return "shop"
	if text.contains("БАНК"): return "bank"
	return ""

static func life_key(id: String, body: CharacterBody3D) -> String:
	return id + ":body:" + str(body.get_instance_id()) if is_instance_valid(body) else ""

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func refresh(body: CharacterBody3D, now: int, preferred_kind: String = "") -> void:
	if now < _next_refresh: return
	_next_refresh = now + 1000
	var scene: Node3D = _scene.get_ref() as Node3D
	if not is_instance_valid(scene): return
	var found: Dictionary = {}
	var discoveries := 0
	var catalog: Array = Swing.doors()
	# Cheap real-anchor sort BEFORE the bounded expensive geometry discovery.
	catalog.sort_custom(func(a: Variant, b: Variant) -> bool: return _owner_distance29(a, body.global_position) < _owner_distance29(b, body.global_position))
	for owner: Variant in catalog:
		if not owner is Node3D or not is_instance_valid(owner) or owner.is_queued_for_deletion(): continue
		var clone: Variant = owner.get("clone_node")
		if not clone is Node3D or not is_instance_valid(clone) or clone.is_queued_for_deletion() or clone.get_parent() != scene or clone.get_meta("dsh_town_extra", false) != true: continue
		if bool(clone.get_meta("venue_closed29", false)):
			if _entries.has(str(owner.get_instance_id())): unregister(str(owner.get_instance_id()), "closed29")
			continue
		var sign_node: Node = clone.get_node_or_null("TownCloneSign")
		if not sign_node is Label3D: continue
		var kind: String = kind_of(sign_node.text)
		if kind.is_empty(): continue
		var venue: String = str(owner.get_instance_id())
		found[venue] = true
		if _entries.has(venue):
			if _entries[venue].kind != kind or _entries[venue].transform != clone.global_transform: unregister(venue, "sign_or_transform_changed")
			else: continue
		if _entries.size() >= MAX_SITES or discoveries >= MAX_DISCOVERIES: continue
		if not preferred_kind.is_empty() and kind != preferred_kind: continue
		if int(_discovery_retry29.get(venue, 0)) > now: continue
		discoveries += 1
		var entry: Dictionary = _build(owner, clone, kind, body)
		if entry.is_empty():
			_discovery_retry29[venue] = now + 30000
			continue
		_discovery_retry29.erase(venue)
		_entries[venue] = entry
		ledger.register(venue, kind, entry.rooms.size())
		var door_callback: Callable = unregister.bind(venue, "door_removed")
		var clone_callback: Callable = unregister.bind(venue, "building_removed")
		if not owner.tree_exiting.is_connected(door_callback): owner.tree_exiting.connect(door_callback, CONNECT_ONE_SHOT)
		if not clone.tree_exiting.is_connected(clone_callback): clone.tree_exiting.connect(clone_callback, CONNECT_ONE_SHOT)
	for venue: Variant in _discovery_retry29.keys():
		if not found.has(venue) or int(_discovery_retry29[venue]) <= now: _discovery_retry29.erase(venue)
	for venue: Variant in _entries.keys():
		if not found.has(venue): unregister(str(venue), "registry_removed")
	_refresh_waiters29(now)
	_reap(now)

func unregister(venue: String, reason: String = "removed") -> void:
	var site: Dictionary = _entries.get(venue, {})
	var clone: Variant = site.get("clone").get_ref() if site.get("clone") is WeakRef else null
	var owner: Variant = site.get("owner").get_ref() if site.get("owner") is WeakRef else null
	var closed: bool = is_instance_valid(clone) and bool(clone.get_meta("venue_closed29", false))
	var removed_door: bool = reason == "door_removed" or (reason == "retired" and (not is_instance_valid(owner) or owner.is_queued_for_deletion()))
	if is_instance_valid(clone) and not clone.is_queued_for_deletion() and (closed or removed_door):
		for key: Variant in ledger.requests:
			if str(ledger.requests[key].get("venue", "")) == venue and _actors.has(key):
				_departures29[key] = {"venue":venue,"reason":"closed29" if closed else "door_removed","controller":_actors[key].controller,"body":_actors[key].body}
	_entries.erase(venue)
	ledger.unregister(venue, Time.get_ticks_msec())
	# No success receipt is produced here. A living controller sees lease_lost.

func _build(owner: Node3D, clone: Node3D, kind: String, body: CharacterBody3D) -> Dictionary:
	if not is_instance_valid(body): return {}
	var leaf: Variant = owner.get("leaf")
	var closed: Variant = owner.get("leaf_closed")
	var anchor: Variant = owner.get("anchor")
	if not leaf is Node3D or not is_instance_valid(leaf) or not closed is Transform3D or not anchor is Vector3 or not anchor.is_finite(): return {}
	var parent: Node3D = leaf.get_parent_node_3d()
	if not is_instance_valid(parent): return {}
	var normal: Vector3 = parent.global_basis * closed.basis.z
	normal.y = 0.0
	if normal.length() < .5: return {}
	normal = normal.normalized()
	var bounds: Dictionary = _bounds(clone)
	if not bounds.get("ok", false): return {}
	if ((bounds.box as AABB).get_center() - anchor).dot(normal) < 0.0: normal = -normal
	var probe: RefCounted = Physical.new()
	if not probe.configure(body): return {}
	var outside: Variant = probe.floor_at(anchor - normal * 1.65, anchor.y + .2)
	var inner: Variant = probe.floor_at(anchor + normal * .85, anchor.y + .2)
	if not outside is Vector3 or not inner is Vector3: return {}
	var rooms: Array[Vector3] = []
	var tangent := Vector3(-normal.z, 0.0, normal.x)
	var capacity: int = clampi(int(clone.get_meta("venue_capacity29", DEFAULT_CAPACITY[kind])), 1, 9)
	# Every admitted occupant gets a distinct supported room point, never the same
	# central destination. 1.2 m separation is above the current .72 m capsule width.
	for depth: float in [2.2, 3.4, 4.6]:
		for offset: float in [0.0, -1.2, 1.2]:
			var point: Variant = probe.floor_at(anchor + normal * depth + tangent * offset, inner.y)
			if point is Vector3 and absf(point.y - inner.y) < .34 and (bounds.box as AABB).grow(-.25).has_point(point + Vector3.UP * .3) and probe.standing(point): rooms.append(point)
			if rooms.size() >= capacity: break
		if rooms.size() >= capacity: break
	if rooms.is_empty(): return {}
	return {"owner":weakref(owner),"clone":weakref(clone),"kind":kind,"door":anchor,"normal":normal,"outside":outside,"inner":inner,"rooms":rooms,"transform":clone.global_transform}

static func _bounds(clone: Node3D) -> Dictionary:
	var stack: Array[Node] = [clone]
	var box := AABB()
	var found := false
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and node.mesh != null:
			var part: AABB = node.global_transform * node.get_aabb()
			box = box.merge(part) if found else part; found = true
		for child: Node in node.get_children(): stack.append(child)
	return {"ok":found,"box":box}

func request(id: String, body: CharacterBody3D, controller: RefCounted, kind: String, now: int) -> Dictionary:
	refresh(body, now, kind)
	var key: String = life_key(id, body)
	if not _actors.has(key) and _actors.size() >= Capacity.MAX_REQUESTS: return {"state":"rejected","reason":"all_active_owners_bound"}
	if ledger.requests.has(key) and str(ledger.requests[key].kind) != kind: return {"state":"rejected","reason":"other_service_owned"}
	if ledger.requests.has(key) and _actors.has(key) and _actors[key].controller.get_ref() != controller: return {"state":"rejected","reason":"other_visit_controller_owned"}
	if _departures29.has(key): return {"state":"rejected","reason":"physical_emergency_exit_owned"}
	var rows: Array = _candidate_rows29(key, kind, body.global_position, now)
	_actors[key] = {"body":weakref(body),"controller":weakref(controller)}
	return ledger.request(key, kind, rows, now)

func poll(key: String, now: int, controller: RefCounted = null) -> Dictionary:
	if controller != null and not owns(key, controller): return {"state":"lost","reason":"controller_retired"}
	if _actors.has(key):
		var body: Variant = _actors[key].body.get_ref()
		if body is CharacterBody3D and is_instance_valid(body): refresh(body, now)
	_reap(now)
	return ledger.poll(key, now)

func entry(venue: String) -> Dictionary:
	if not _entries.has(venue): return {}
	var value: Dictionary = _entries[venue]
	var owner: Variant = value.owner.get_ref()
	var clone: Variant = value.clone.get_ref()
	if is_instance_valid(clone) and bool(clone.get_meta("venue_closed29", false)):
		unregister(venue, "closed29"); return {}
	if not is_instance_valid(owner) or not is_instance_valid(clone) or owner.is_queued_for_deletion() or clone.is_queued_for_deletion():
		unregister(venue, "retired"); return {}
	return value

func owns(key: String, controller: RefCounted) -> bool:
	return _actors.has(key) and _actors[key].controller.get_ref() == controller and ledger.requests.has(key)

func release(key: String, now: int, reason: String, controller: RefCounted = null) -> void:
	if controller != null:
		var current_owner: Variant = _actors[key].controller.get_ref() if _actors.has(key) else null
		if current_owner != controller: return
	_departures29.erase(key)
	ledger.release(key, now, reason)
	_actors.erase(key)

func reject_path(key: String, venue: String, now: int, controller: RefCounted = null) -> void:
	if controller != null and not owns(key, controller): return
	_blocked_until[key + ":" + venue] = now + 30000
	release(key, now, "physical_approach_blocked", controller)

func _reap(now: int) -> void:
	if now < _next_reap: return
	_next_reap = now + 1000
	for key: Variant in _actors.keys():
		var refs: Dictionary = _actors[key]
		var body: Variant = refs.body.get_ref()
		if (not ledger.requests.has(key) and not _departures29.has(key)) or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or refs.controller.get_ref() == null: release(str(key), now, "owner_retired")
	for key: Variant in _blocked_until.keys():
		if int(_blocked_until[key]) <= now: _blocked_until.erase(key)
	ledger.maintain(now)

func snapshot() -> Dictionary:
	return ledger.snapshot()

static func _owner_distance29(owner: Variant, position: Vector3) -> float:
	if not is_instance_valid(owner) or not owner is Node3D: return INF
	var anchor: Variant = owner.get("anchor")
	return _flat(position, anchor) if anchor is Vector3 and anchor.is_finite() else INF

func _candidate_rows29(key: String, kind: String, position: Vector3, now: int) -> Array:
	var rows: Array = []
	for venue: Variant in _entries.keys():
		var entry: Dictionary = self.entry(str(venue))
		if entry.is_empty(): continue
		if entry.kind != kind or int(_blocked_until.get(key + ":" + str(venue), 0)) > now: continue
		# Rank actual outside doorway endpoints, never centres or nearest walls.
		rows.append({"venue":venue,"cost":_flat(position, entry.outside)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cost < b.cost)
	if rows.size() > MAX_CANDIDATES: rows.resize(MAX_CANDIDATES)
	return rows

func _refresh_waiters29(now: int) -> void:
	for key: Variant in ledger.requests.keys():
		var request: Dictionary = ledger.requests.get(key, {})
		if request.get("state") != "waiting" or not _actors.has(key): continue
		var body: Variant = _actors[key].body.get_ref()
		if not body is CharacterBody3D or not is_instance_valid(body): continue
		request.candidates = _candidate_rows29(str(key), str(request.kind), body.global_position, now)
	# Sequence, original enqueue and bounded deadline are deliberately unchanged.
	ledger._promote(now)

func departure_allowed29(key: String, controller: RefCounted, body: CharacterBody3D, venue: String) -> bool:
	if not _departures29.has(key) or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion(): return false
	var row: Dictionary = _departures29[key]
	return row.controller.get_ref() == controller and row.body.get_ref() == body and str(row.venue) == venue and row.reason in ["closed29", "door_removed"]
