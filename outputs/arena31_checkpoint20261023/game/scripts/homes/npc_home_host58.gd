extends "res://scripts/venues/npc_service_sites_host29.gd"
## Reuse the current placement, damage bridge and rubble lifecycle for houses.
const HomeSite58 = preload("npc_home_site58.gd")
const HomeRegistry58 = preload("npc_home_registry58.gd")
const HOME_DATA58 := "res://data/homes58.json"
var registry58: RefCounted

func prepare(world: Node3D, block: Dictionary) -> Dictionary:
	if _world != null or not is_instance_valid(world) or not world.global_transform.is_equal_approx(Transform3D.IDENTITY): return {"ok":false, "reason":"one_identity_world_required"}
	_world = weakref(world)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(HOME_DATA58))
	if not data is Dictionary or data.get("schema") != "mafiozi.homes58/v1" or not data.get("entries") is Array: return {"ok":false, "reason":"home_plan_required"}
	if FileAccess.get_sha256("res://data/city_block.json") != str(data.get("source_sha256", "")): return {"ok":false, "reason":"source_map_sha_changed"}
	if data.entries.size() != 4: return {"ok":false, "reason":"four_reviewed_houses_required"}
	var assigned_ids: Dictionary = {}
	for definition: Dictionary in data.entries:
		var residents: Variant = definition.get("residents")
		if not residents is Array or residents.is_empty() or residents.size() > 3: return {"ok":false, "reason":"one_to_three_residents"}
		for source_id: String in residents:
			if assigned_ids.has(source_id): return {"ok":false, "reason":"duplicate_home_assignment"}
			assigned_ids[source_id] = true
	for index: int in range(1, 11):
		if not assigned_ids.has("resident_" + str(index)): return {"ok":false, "reason":"first_ten_assignment_required"}
	if assigned_ids.size() != 10: return {"ok":false, "reason":"first_ten_only"}
	registry58 = HomeRegistry58.new()
	if not registry58.configure(world, self): return {"ok":false, "reason":"home_registry"}
	await get_tree().physics_frame
	await get_tree().physics_frame
	var outcomes: Array = []
	for definition: Dictionary in data.entries:
		if _disposed or not is_instance_valid(world): return {"ok":false, "reason":"world_retired"}
		var checked: Dictionary = _placement(world, block, definition)
		if not checked.get("ok", false):
			outcomes.append({"source_id":definition.id, "ok":false, "reason":checked.get("reason")}); continue
		var house: Node3D = HomeSite58.new()
		house.name = "ResidentHome58_" + str(definition.number)
		house.source_id = str(definition.id); house.service_kind = "home"; house.service_sign = "ДОМ " + str(definition.number)
		house.home_number58 = int(definition.number); house.residents58.assign(definition.residents)
		house.native_ground29 = checked.ground; house.transform = checked.frame
		house.set_meta("dsh_town_extra", true); house.set_meta("venue_closed29", true)
		world.add_child(house)
		var bound: Dictionary = house.bind_service(world)
		if not bound.get("ok", false) or not registry58.register_house(house):
			outcomes.append({"source_id":definition.id, "ok":false, "reason":"home_geometry_or_registry", "detail":bound}); house.queue_free(); continue
		_sites[str(definition.id)] = weakref(house)
		outcomes.append({"source_id":definition.id, "ok":true, "residents":definition.residents, "position":definition.position, "owned_sections":house.pieces.size(), "beds":house.beds58.size(), "native_ground_bodies":checked.ground.size()})
		await get_tree().physics_frame
	var inventory: Dictionary = registry58.snapshot()
	report = {"ok":_sites.size() == 4 and int(inventory.beds) == 10 and int(inventory.available_beds) == 10, "requested":4, "built":_sites.size(), "placements":outcomes, "registry":inventory, "status":"geometry_ready_native_acceptance_pending", "destruction_owner":"inherited_palazzo_structural_site"}
	return report.duplicate(true)

func dispose() -> void:
	if registry58 != null: registry58.dispose(); registry58 = null
	super.dispose()
