extends "res://landmarks_resource_factory.gd"
## Independent optimization layer; inherited frozen source/safety/resource code is unchanged.
var _owner_index := {}
var _plans := {}
var cold_plan_builds := 0

func configure(directory: String, admitted_manifest_sha: String) -> Dictionary:
	var result := super.configure(directory, admitted_manifest_sha)
	if not result.get("ok"): return result
	for key in _records: _owner_index[key] = []
	for part: Dictionary in _parts.values(): _owner_index[part.owner].append(part.id)
	return result

func _prepare_owner(key: String) -> Dictionary:
	var owned := []
	var detached := []
	var bounds_inputs := []
	var resource_keys := {}
	for id: String in _owner_index[key]:
		var part: Dictionary = _parts[id]
		var frame := source_transform(part.worldMatrix)
		var item := {"part_id": id, "source_frame": frame, "frame": frame, "visible": part.visible}
		if part.has("detachedDependency"):
			detached.append(item)
			continue
		var index := owned.size()
		owned.append(item)
		if part.has("geometry"):
			var primitive := Mesh.PRIMITIVE_LINES if part.type == "LineSegments" else Mesh.PRIMITIVE_TRIANGLES
			resource_keys[_geometry_key(part.geometry, primitive)] = true
		if not part.has("geometry") or part.type == "Sprite" or not part.visible: continue
		var local_bounds: AABB
		if part.has("matrices"):
			if multimesh_resource(id) == null: return fail("Invalid source instances")
			resource_keys[id] = true
			local_bounds = _instance_bounds[id]
		else:
			var primitive := Mesh.PRIMITIVE_LINES if part.type == "LineSegments" else Mesh.PRIMITIVE_TRIANGLES
			var mesh := mesh_resource(part.geometry, primitive)
			if mesh == null: return fail("Invalid source mesh")
			local_bounds = mesh.get_aabb()
		bounds_inputs.append({"index": index, "bounds": local_bounds})
	var result := {"ok": true, "owned": owned, "detached": detached, "bounds_inputs": bounds_inputs, "resource_keys": resource_keys.keys()}
	_plans[key] = result
	cold_plan_builds += 1
	return result

func placement_plan(key: String, candidate: Dictionary = {}) -> Dictionary:
	if not _records.has(key): return fail("Unknown editor source key")
	var cached: Dictionary = _plans.get(key, {})
	if cached.is_empty():
		cached = _prepare_owner(key)
		if not cached.get("ok"): return cached
	# Retain the frozen factory's changed-resource admission, even after bounds caching.
	if not _poisoned.is_empty():
		for resource_key in cached.resource_keys:
			if _poisoned.has(resource_key): return fail("Changed resource requires new original-source admission")
	var current: Dictionary = candidate if not candidate.is_empty() else _current[key]
	var owned: Array = cached.owned.duplicate(true)
	var detached: Array = cached.detached.duplicate(true)
	for item: Dictionary in owned:
		item.frame = current.delta * item.source_frame
		item.visible = item.visible and not current.deleted
	var bounds := AABB()
	var has_bounds := false
	if not current.deleted:
		for input: Dictionary in cached.bounds_inputs:
			var moved: AABB = owned[input.index].frame * input.bounds
			bounds = bounds.merge(moved) if has_bounds else moved
			has_bounds = true
	return {"ok": true, "key": key, "source_record": source_record(key), "owned_parts": owned, "detached_dependencies": detached, "source_collider_recipe": _manifest.recipes.get(_records[key].get("collisionRecipe", ""), {}).duplicate(true), "owner_required": true, "culling_aabb": bounds, "has_visible_bounds": has_bounds}

func dispose() -> void:
	_owner_index.clear()
	_plans.clear()
	cold_plan_builds = 0
	super.dispose()
