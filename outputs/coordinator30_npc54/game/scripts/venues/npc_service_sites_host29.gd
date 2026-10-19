extends Node
## One optional host for eight new physical service copies and one damage bridge.
const Site29 = preload("npc_compact_service_site29.gd")
const DamageBridge = preload("res://scripts/destruction/modular30/native_building_damage_bridge.gd")
const DATA := "res://data/venue_sites29.json"
var _world: WeakRef
var _sites: Dictionary = {}
var _damage: RefCounted
var _disposed := false
var _binding_ready := false
var report: Dictionary = {"ok":false,"status":"not_prepared","placements":[]}

func _ready() -> void:
	set_physics_process(false)

func prepare(world: Node3D, block: Dictionary) -> Dictionary:
	if _world != null or not is_instance_valid(world) or not world.global_transform.is_equal_approx(Transform3D.IDENTITY): return {"ok":false,"reason":"one_identity_world_required"}
	_world = weakref(world)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not data is Dictionary or data.get("schema") != "mafiozi.venues29.compact-sites/v1" or not data.get("entries") is Array: return {"ok":false,"reason":"site_plan_required"}
	if FileAccess.get_sha256("res://data/city_block.json") != str(data.get("source_sha256", "")): return {"ok":false,"reason":"source_map_sha_changed"}
	if data.entries.size() != 8: return {"ok":false,"reason":"eight_reviewed_new_sites_required"}
	# World terrain/decor/old sites must reach the physics server before new-site QA.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _disposed or not is_instance_valid(world): return {"ok":false,"reason":"world_retired"}
	var outcomes: Array = []
	for definition: Dictionary in data.entries:
		var checked: Dictionary = _placement(world, block, definition)
		if not checked.get("ok", false):
			outcomes.append({"source_id":definition.id,"ok":false,"reason":checked.get("reason")}); continue
		var site: Node3D = Site29.new()
		site.name = "CompactService29_" + str(definition.id)
		site.source_id = str(definition.id); site.service_kind = str(definition.kind); site.service_sign = str(definition.sign)
		site.native_ground29 = checked.ground
		site.transform = checked.frame
		site.set_meta("dsh_town_extra", true); site.set_meta("venue_capacity29", int(definition.capacity)); site.set_meta("venue_closed29", true)
		world.add_child(site)
		var bound: Dictionary = site.bind_service(world)
		if not bound.get("ok", false):
			outcomes.append({"source_id":definition.id,"ok":false,"reason":"site_contract_failed","detail":bound}); site.queue_free(); continue
		_sites[str(definition.id)] = weakref(site)
		outcomes.append({"source_id":definition.id,"ok":true,"kind":definition.kind,"position":definition.position,"native_ground_bodies":checked.ground.size(),"owned_sections":site.pieces.size(),"pooled_fragments":site.pooled_fragments.size(),"door_bound":true})
		await get_tree().physics_frame # Cold placement and support work remain staged.
		if _disposed or not is_instance_valid(world): return {"ok":false,"reason":"world_retired"}
	report = {"ok":_sites.size() == data.entries.size(),"status":"geometry_ready_native_acceptance_pending","requested":data.entries.size(),"built":_sites.size(),"placements":outcomes,"resident_count_changed":false,"source_map_mutated":false,"destruction_owner":"inherited_palazzo_structural_site"}
	return report.duplicate(true)

func _placement(world: Node3D, block: Dictionary, definition: Dictionary) -> Dictionary:
	var source: Variant = definition.get("position")
	if not source is Array or source.size() != 3: return {"ok":false,"reason":"position"}
	var origin := Vector3(float(source[0]), float(source[1]), float(source[2]))
	var yaw: float = float(definition.get("yaw", NAN))
	if not origin.is_finite() or not is_finite(yaw): return {"ok":false,"reason":"finite_frame"}
	var frame := Transform3D(Basis(Vector3.UP, yaw), origin)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ground: Array[StaticBody3D] = []
	var excluded: Array[RID] = []
	# Exact source-grid footprint is resampled at <=1m, then supported by real rays.
	for x: int in range(-5, 6):
		for z: int in range(-4, 5):
			if not _dry_source(block, frame * Vector3(x, 0, z), true): return {"ok":false,"reason":"footprint_not_unprotected_grass"}
	var floor_samples: Array[Vector3] = []
	for x: float in [-3.9, 0.0, 3.9]:
		for z: float in [-3.4, 0.0, 3.4]: floor_samples.append(Vector3(x, 0, z))
	for x: float in [-5.2, -4.0, -2.8, 0.0, 2.8, 4.0, 5.2]: floor_samples.append(Vector3(x, 0, 7.1))
	var road_distance: float = float(definition.get("road_distance_from_centre_m", 0))
	if road_distance < 7.5 or road_distance > 22.0: return {"ok":false,"reason":"bounded_road_approach"}
	for distance: int in range(4, ceili(road_distance) + 1):
		for x: float in [-.5, 0.0, .5]: floor_samples.append(Vector3(x, 0, distance))
	for local: Vector3 in floor_samples:
		var point: Vector3 = frame * local
		if not _dry_source(block, point): return {"ok":false,"reason":"approach_not_dry_walkable"}
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point - Vector3.UP, 1)
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or not hit.get("collider") is StaticBody3D or (hit.normal as Vector3).dot(Vector3.UP) < .95 or absf(float(hit.position.y) - origin.y) > .025: return {"ok":false,"reason":"real_level_dry_floor_required"}
		var body: StaticBody3D = hit.collider
		if body.get_script() != null or body.has_meta("source_id"): return {"ok":false,"reason":"terrain_not_foreign_building"}
		if not ground.has(body): ground.append(body); excluded.append(body.get_rid())
	# Entire shell and open side/door apron must be free before creation.
	for box: Dictionary in [{"size":Vector3(8.7, 3.7, 7.8),"at":Vector3(0, 1.95, 0)}, {"size":Vector3(12.0, 2.3, road_distance - 3.5),"at":Vector3(0, 1.25, (road_distance + 3.5) * .5)}]:
		var query := PhysicsShapeQueryParameters3D.new(); var shape := BoxShape3D.new(); shape.size = box.size
		query.shape = shape; query.transform = frame * Transform3D(Basis.IDENTITY, box.at); query.collision_mask = 1 | 2 | 512; query.exclude = excluded
		if not space.intersect_shape(query, 1).is_empty(): return {"ok":false,"reason":"shell_or_approach_obstructed"}
	return {"ok":true,"frame":frame,"ground":ground}

func _dry_source(block: Dictionary, point: Vector3, grass: bool = false) -> bool:
	var surface: Dictionary = block.surface
	var origin: Array = block.originM
	var col: int = floori((point.x + float(origin[0])) / float(surface.cellSize)) - int(surface.startCol)
	var row: int = floori((point.z + float(origin[2])) / float(surface.cellSize)) - int(surface.startRow)
	if row < 0 or row >= surface.grid.size() or col < 0 or col >= surface.grid[row].size(): return false
	var tile: int = int(surface.grid[row][col])
	return not bool(surface.masks.protectedMask[row][col]) and bool(surface.masks.walkableMask[row][col]) and (tile == 8 if grass else tile not in [16, 19])

func bind_weapons() -> Dictionary:
	var world: Variant = _world.get_ref() if _world != null else null
	if _disposed or _damage != null or not is_instance_valid(world) or not is_instance_valid(world.get("preview_weapons")): return {"ok":false,"reason":"current_weapons_required"}
	_damage = DamageBridge.new()
	var result: Dictionary = _damage.configure(world.preview_weapons, Callable(self, "_blast"), Callable(self, "_glass"), {"breach_radius_m":.8,"glass_blast_port":Callable(self, "_glass_blast")})
	_binding_ready = bool(result.get("ok", false))
	set_physics_process(_binding_ready)
	return result

func current_sites() -> Array:
	var result: Array = []
	if _disposed: return result
	for key: Variant in _sites.keys():
		var site: Variant = _sites[key].get_ref()
		if not is_instance_valid(site) or not site.is_inside_tree() or site.is_queued_for_deletion(): _sites.erase(key); continue
		if site.site_ready and not site.rebuilding: result.append(site)
	return result

func _site_for(event: Dictionary) -> Node3D:
	if not _binding_ready or not _sites.has(str(event.get("source_id", ""))): return null
	var site: Variant = _sites[str(event.source_id)].get_ref()
	if not is_instance_valid(site) or not site.is_inside_tree() or site.is_queued_for_deletion() or not site.site_ready or site.rebuilding: return null
	return site as Node3D

func _blast(event: Dictionary) -> Dictionary:
	var site: Node3D = _site_for(event)
	if site == null: return {"ok":false,"reason":"foreign_or_retired_site"}
	var collider: Variant = event.get("collider")
	if not site.owns_collider(collider) and (not is_instance_valid(site._glazing) or not site._glazing.owns_collider(collider)): return {"ok":false,"reason":"owned_native_contact_required"}
	return site.apply_explosion(event)

func _glass(event: Dictionary) -> Dictionary:
	var site: Node3D = _site_for(event)
	return site._glazing.apply_bullet(event) if site != null and is_instance_valid(site._glazing) else {"ok":false,"reason":"owned_glazing_required"}

func _glass_blast(event: Dictionary) -> Dictionary:
	var results: Array = []
	for site: Node3D in current_sites():
		if is_instance_valid(site._glazing): results.append(site._glazing.apply_blast(event))
	return {"ok":true,"sites":results}

func _physics_process(delta: float) -> void:
	var world: Variant = _world.get_ref() if _world != null else null
	if _disposed or not is_instance_valid(world) or not world.preview_ready or world.preview_dead or world.preview_physics_fault: return
	var actor: Variant = world.get("_player"); var capsule: Variant = world.get("_player_capsule")
	if not actor is CharacterBody3D or not is_instance_valid(actor) or not capsule is CollisionShape3D or not is_instance_valid(capsule) or not actor.is_on_floor(): return
	if actor._pose_authority != &"on_foot" or not actor._free_mouse_look: return
	for site: Node3D in current_sites():
		if site.global_position.distance_squared_to(actor.global_position) <= 324.0: site.push_from_actor(actor, capsule, delta)

func snapshot() -> Dictionary:
	var stats: Array = []
	for site: Node3D in current_sites(): stats.append(site.get_stats())
	return {"report":report.duplicate(true),"sites":stats,"native_binding":_binding_ready,"damage":_damage.snapshot() if _damage != null else {}}

func dispose() -> void:
	if _disposed: return
	_disposed = true; _binding_ready = false; set_physics_process(false)
	if _damage != null: _damage.dispose(); _damage = null
	for ref: WeakRef in _sites.values():
		var site: Variant = ref.get_ref()
		if is_instance_valid(site): site.queue_free()
	_sites.clear(); _world = null

func _exit_tree() -> void:
	dispose()
