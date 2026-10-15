extends Node
## NPC-to-NPC passage permission. World, door, player and weapon queries are unchanged.
## The same live zone set drives symmetric native exceptions, local plans and avoidance.
const META := "npc_passage31"
const CELL_M := 8.0
const MAX_ACTORS := 448
const MAX_ZONES := 64
const MAX_PER_ZONE := 32
var _scene: WeakRef
var _frame := -1
var _next_zones := 0
var _entry_count := -1
var _zones: Dictionary = {}
var _cells: Dictionary = {}
var _actors: Dictionary = {}
var _body_zones: Dictionary = {}
var _members: Dictionary = {}
var _pairs: Dictionary = {}
var _max_refresh_us := 0

static func for_scene(scene: Node3D) -> Node:
	if not is_instance_valid(scene): return null
	var found: Variant = scene.get_meta(META) if scene.has_meta(META) else null
	if is_instance_valid(found) and found is Node: return found
	var service: Node = load("res://scripts/navigation/npc_passage31.gd").new()
	service._scene = weakref(scene); service.name = "NpcPassage31"
	scene.set_meta(META, service); scene.add_child(service)
	service.process_physics_priority = -100
	return service

static func _live(value: Variant) -> bool:
	return is_instance_valid(value) and value is CharacterBody3D and value.is_inside_tree() and not value.is_queued_for_deletion() and value.collision_layer == 1

func _physics_process(_delta: float) -> void:
	refresh()

func _collect(scene: Node3D) -> void:
	_actors.clear()
	var population: Variant = scene.get("preview_population")
	var residents: Variant = population.get("residents") if is_instance_valid(population) else null
	var records: Variant = residents.get("_records") if is_instance_valid(residents) else null
	if records is Dictionary:
		var rows: Array = residents.active_records30() if residents.has_method("active_records30") else records.values()
		for record: Dictionary in rows:
			var body: Variant = record.get("body")
			if _actors.size() >= MAX_ACTORS: break
			if _live(body): _actors[body.get_instance_id()] = body
	var staff: Variant = scene.get("preview_venue_staff29")
	var rows: Variant = staff.get("_rows") if is_instance_valid(staff) else null
	if rows is Dictionary:
		for record: Dictionary in rows.values():
			var body: Variant = record.get("actor")
			if _actors.size() >= MAX_ACTORS: break
			if _live(body): _actors[body.get_instance_id()] = body

func _rebuild_zones(entries: Dictionary) -> void:
	_zones.clear(); _cells.clear()
	for key: String in entries:
		if _zones.size() >= MAX_ZONES: break
		var entry: Dictionary = entries[key]
		var owner: Variant = entry.owner.get_ref()
		var clone: Variant = entry.clone.get_ref()
		if not is_instance_valid(owner) or not is_instance_valid(clone) or bool(clone.get_meta("venue_closed29", false)): continue
		var door: Vector3 = entry.door
		var inward: Vector3 = entry.normal
		var tangent := Vector3(-inward.z, 0, inward.x)
		var leaf: Variant = owner.get("leaf")
		var closed: Variant = owner.get("leaf_closed")
		if not is_instance_valid(leaf) or not closed is Transform3D: continue
		var width := 0.0
		for shape: Node in leaf.get_children():
			if not shape is CollisionShape3D or shape.disabled or not shape.shape is BoxShape3D: continue
			var frame: Transform3D = leaf.get_parent_node_3d().global_transform * closed * shape.transform
			var half: Vector3 = shape.shape.size * .5
			for x: float in [-half.x, half.x]:
				for z: float in [-half.z, half.z]: width = maxf(width, absf((frame * Vector3(x,0,z) - door).dot(tangent)))
		if width < .25 or width > 2.5: continue
		# Include capsule centres beside the jamb and both short staging approaches.
		var zone: Dictionary = {"door":door,"normal":inward,"tangent":tangent,"half_width":width+.45,"depth":3.3,"owner":weakref(owner),"clone":weakref(clone)}
		_zones[key] = zone
		var reach: float = 3.3 + width + .45
		for x: int in range(floori((door.x-reach)/CELL_M), floori((door.x+reach)/CELL_M)+1):
			for z: int in range(floori((door.z-reach)/CELL_M), floori((door.z+reach)/CELL_M)+1):
				var cell := Vector2i(x,z)
				if not _cells.has(cell): _cells[cell] = []
				_cells[cell].append(key)

func _zone_at(at: Vector3) -> String:
	var keys: Array = _cells.get(Vector2i(floori(at.x/CELL_M), floori(at.z/CELL_M)), [])
	for key: String in keys:
		var zone: Dictionary = _zones[key]
		var owner: Variant = zone.owner.get_ref(); var clone: Variant = zone.clone.get_ref()
		if not is_instance_valid(owner) or not is_instance_valid(clone) or bool(clone.get_meta("venue_closed29", false)): continue
		var offset: Vector3 = at - (zone.door as Vector3)
		if absf(offset.y) < 1.0 and absf(offset.dot(zone.normal)) <= zone.depth and absf(offset.dot(zone.tangent)) <= zone.half_width: return key
	return ""

func refresh() -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _frame: return
	_frame = frame
	var started: int = Time.get_ticks_usec()
	var scene: Variant = _scene.get_ref() if _scene != null else null
	if not is_instance_valid(scene): _clear_pairs(); return
	var registry: Variant = scene.get_meta("npc_venue_registry29") if scene.has_meta("npc_venue_registry29") else null
	var entries: Dictionary = registry._entries if is_instance_valid(registry) else {}
	var now: int = Time.get_ticks_msec()
	if entries.size() != _entry_count or now >= _next_zones:
		_entry_count = entries.size(); _next_zones = now+1000; _rebuild_zones(entries)
	_collect(scene); _body_zones.clear(); _members.clear()
	for id: int in _actors:
		var body: CharacterBody3D = _actors[id]
		var zone: String = _zone_at(body.global_position)
		if zone.is_empty(): continue
		if not _members.has(zone): _members[zone] = []
		if _members[zone].size() >= MAX_PER_ZONE: continue
		_body_zones[id] = zone; _members[zone].append(body)
	var wanted: Dictionary = {}
	for members: Array in _members.values():
		for a: int in range(members.size()):
			for b: int in range(a+1, members.size()):
				var first: CharacterBody3D = members[a]; var second: CharacterBody3D = members[b]
				var first_id: int = first.get_instance_id(); var second_id: int = second.get_instance_id()
				var pair: String = str(mini(first_id,second_id))+":"+str(maxi(first_id,second_id))
				wanted[pair] = true
				if _pairs.has(pair): continue
				var add_first: bool = not first.get_collision_exceptions().has(second)
				var add_second: bool = not second.get_collision_exceptions().has(first)
				if add_first: first.add_collision_exception_with(second)
				if add_second: second.add_collision_exception_with(first)
				_pairs[pair] = {"first":weakref(first),"second":weakref(second),"add_first":add_first,"add_second":add_second}
	for key: String in _pairs.keys():
		if not wanted.has(key): _remove_pair(key)
	_max_refresh_us = maxi(_max_refresh_us, Time.get_ticks_usec()-started)

func _remove_pair(key: String) -> void:
	var pair: Dictionary = _pairs[key]
	var first: Variant = pair.first.get_ref(); var second: Variant = pair.second.get_ref()
	if is_instance_valid(first) and is_instance_valid(second):
		if pair.add_first: first.remove_collision_exception_with(second)
		if pair.add_second: second.remove_collision_exception_with(first)
	_pairs.erase(key)

func _clear_pairs() -> void:
	for key: String in _pairs.keys(): _remove_pair(key)

## Capability derives from the same measured, live doorway used by native pairs.
func supports_venue31(venue: String) -> bool:
	refresh()
	if not _zones.has(venue): return false
	var zone: Dictionary = _zones[venue]
	var owner: Variant = zone.owner.get_ref(); var clone: Variant = zone.clone.get_ref()
	return is_instance_valid(owner) and is_instance_valid(clone) and not owner.is_queued_for_deletion() and not clone.is_queued_for_deletion() and not bool(clone.get_meta("venue_closed29", false))

func body_zone(body: CharacterBody3D) -> String:
	refresh()
	return str(_body_zones.get(body.get_instance_id(), "")) if _live(body) else ""

func query_exclusions(body: CharacterBody3D, at: Vector3) -> Array[RID]:
	var result: Array[RID] = [body.get_rid()]
	refresh()
	if not _live(body) or not _actors.has(body.get_instance_id()): return result
	var zone: String = _zone_at(at)
	if zone.is_empty(): return result
	for peer: Variant in _members.get(zone, []):
		if peer != body and _live(peer): result.append(peer.get_rid())
	return result

func diagnostics() -> Dictionary:
	return {"actors":_actors.size(),"zones":_zones.size(),"in_passage":_body_zones.size(),"pairs":_pairs.size(),"max_refresh_us":_max_refresh_us,"max_per_zone":MAX_PER_ZONE}

func _exit_tree() -> void:
	_clear_pairs()
