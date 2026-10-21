extends RefCounted
## Scene-scoped geometry catalogue only. The home controller owns life/bed claims.
const META := "npc_home_registry58"
var _scene: WeakRef
var _host: WeakRef
var _slots: Dictionary = {}
var _homes: Dictionary = {}

func configure(scene: Node3D, host: Node) -> bool:
	if _scene != null or not is_instance_valid(scene) or not is_instance_valid(host): return false
	_scene = weakref(scene); _host = weakref(host)
	scene.set_meta(META, self)
	return true

func register_house(house: Node3D) -> bool:
	if _scene == null or not is_instance_valid(house) or house.get_parent() != _scene.get_ref(): return false
	if not house.habitable58() or not is_instance_valid(house._swing29): return false
	if house.residents58.is_empty() or house.residents58.size() > 3 or house.beds58.size() != house.residents58.size(): return false
	var bed_ids: Dictionary = {}
	for bed: Dictionary in house.beds58:
		if not str(bed.get("source_id", "")) in house.residents58 or bed_ids.has(str(bed.get("bed_id", ""))): return false
		if not bed.get("bed_node") is WeakRef or not house.intact58(bed.bed_node.get_ref()): return false
		if not bed.get("bed_support") is WeakRef or not house.intact58(bed.bed_support.get_ref()): return false
		bed_ids[str(bed.bed_id)] = true
	var home_id: String = str(house.source_id)
	var owner: Node3D = house._swing29
	var normal: Vector3 = house.global_basis * Vector3.FORWARD
	var door: Vector3 = house.to_global(Vector3(0, .24, 3.5))
	var base: Dictionary = {"home_id":home_id, "house":weakref(house), "door_owner":weakref(owner), "door":door, "normal":normal, "outside":house.to_global(Vector3(0, 0, 5.3)), "inner":house.to_global(Vector3(0, .24, 2.55)), "bounds":house.global_transform * AABB(Vector3(-4, .24, -3.5), Vector3(8, 2.8, 7)), "revision":int(house.rebuild_generation), "house_frame58":house.global_transform}
	_homes[home_id] = base
	for bed: Dictionary in house.beds58:
		var row: Dictionary = base.duplicate()
		row.source_id = bed.source_id; row.bed_id = bed.bed_id
		row.bed_node = bed.bed_node; row.bed_support = bed.bed_support
		row.bed_approach = house.to_global(bed.approach); row.bed_surface = house.to_global(bed.surface)
		row.bed_face = house.global_basis * Vector3.FORWARD; row.bed_right = house.global_basis * Vector3.RIGHT
		_slots[str(bed.source_id)] = row
	return true

func route_current(row: Dictionary) -> bool:
	var scene: Variant = _scene.get_ref() if _scene != null else null
	var house: Variant = row.house.get_ref() if row.get("house") is WeakRef else null
	var owner: Variant = row.door_owner.get_ref() if row.get("door_owner") is WeakRef else null
	if not is_instance_valid(scene) or not is_instance_valid(house) or not is_instance_valid(owner): return false
	if scene.is_queued_for_deletion() or house.is_queued_for_deletion() or owner.is_queued_for_deletion(): return false
	if not house.is_inside_tree() or house.get_parent() != scene or house.source_id != row.get("home_id"): return false
	if int(house.rebuild_generation) != int(row.get("revision", -1)) or house.global_transform != row.get("house_frame58"): return false
	# A broken bed/floor/roof invalidates sleep without discarding a still-live
	# door. The physical exit keeps its door stages until the leaf itself is lost.
	return house.site_ready and not house.rebuilding and owner == house._swing29 and owner._available()

func _home_current(row: Dictionary) -> bool:
	return route_current(row) and row.house.get_ref().habitable58()

func assigned(source_id: String) -> Dictionary:
	var row: Dictionary = _slots.get(source_id, {})
	if not row.is_empty() and current(row): return row.duplicate()
	# A rebuilt house has new native bodies and a new revision. Publish only the
	# new geometry; old slots still fail current() and cannot keep a sleeper alive.
	var host: Variant = _host.get_ref() if _host != null else null
	if is_instance_valid(host):
		for house: Node3D in host.current_sites():
			if source_id in house.residents58 and house.habitable58():
				register_house(house)
				row = _slots.get(source_id, {})
				return row.duplicate() if not row.is_empty() and current(row) else {}
	return {}

func current(slot: Dictionary) -> bool:
	if slot.is_empty() or not _home_current(slot): return false
	var stored: Dictionary = _slots.get(str(slot.get("source_id", "")), {})
	if stored.is_empty() or stored.get("bed_id") != slot.get("bed_id") or stored.get("revision") != slot.get("revision"): return false
	var house: Node3D = slot.house.get_ref()
	for key: String in ["bed_node", "bed_support"]:
		var body: Variant = slot[key].get_ref() if slot.get(key) is WeakRef else null
		var canonical: Variant = stored[key].get_ref() if stored.get(key) is WeakRef else null
		if body != canonical or not house.intact58(body): return false
	return true

func passage_entries() -> Dictionary:
	var result: Dictionary = {}
	for home_id: String in _homes:
		var row: Dictionary = _homes[home_id]
		if route_current(row): result["home58:" + home_id] = {"owner":row.door_owner, "clone":row.house, "door":row.door, "normal":row.normal}
	return result

## A distant guide is topology, not permission to enter a private house.
## Reject only intermediate checkpoints inside a live home while the exact
## requested endpoint is outside it. The existing radial repair and capsule
## solver still prove the alternative; no floor/world/door query is bypassed.
func guide_checkpoint_allowed58(point: Vector3, endpoint: Vector3) -> bool:
	if not point.is_finite() or not endpoint.is_finite() or _homes.size()>288: return false
	for row: Dictionary in _homes.values():
		if not route_current(row): continue
		var bounds: AABB=row.bounds
		if bounds.has_point(point+Vector3.UP*.3) and not bounds.has_point(endpoint+Vector3.UP*.3): return false
	return true

func snapshot() -> Dictionary:
	var assigned_count := 0
	for row: Dictionary in _slots.values():
		if current(row): assigned_count += 1
	return {"homes":_homes.size(), "beds":_slots.size(), "available_beds":assigned_count, "distribution":[3, 3, 2, 2]}

func dispose() -> void:
	var scene: Variant = _scene.get_ref() if _scene != null else null
	if is_instance_valid(scene) and scene.get_meta(META, null) == self: scene.remove_meta(META)
	_slots.clear(); _homes.clear(); _host = null; _scene = null
