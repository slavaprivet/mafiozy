extends Node
## Bounded setup/watch of signed venues; no resident spawn, path planner or HP writer.
const Registry = preload("npc_venue_registry29.gd")
const Swing = preload("res://scripts/city/runtime/npc_city_clone_door_swing.gd")
const Physical = preload("res://scripts/hospital/npc_physical_route51.gd")
const Cache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const Actor = preload("npc_venue_staff_actor29.gd")
const MANIFEST := "res://assets/npc_visual/session/prepared/manifest.json"
const DIRECTORY := "res://assets/npc_visual/session/prepared/"
const MAX_STAFF := 16
var report: Dictionary = {"ok":false,"staff":[],"failures":[]}
var _world: Node3D
var _registry: RefCounted
var _cache: RefCounted
var _probe_body: CharacterBody3D
var _probe: RefCounted
var _rows: Dictionary = {}
var _next_scan := 0.0
var _building := false
var _disposed := false

func prepare29(world: Node3D) -> Dictionary:
	_world = world; _registry = Registry.for_scene(world)
	world.set_meta("venue_staff_mode29", true)
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/venue_staff29.json"))
	if not config is Dictionary: return {"ok":false,"reason":"staff_asset_config"}
	var loaded: Dictionary = Cache.load_verified(FileAccess.get_file_as_bytes(MANIFEST), str(config.manifest_sha256), str(config.bridge_id), str(config.descriptor_sha256), DIRECTORY)
	if not loaded.get("ok", false): return {"ok":false,"reason":"verified_rig_required","detail":loaded}
	_cache = loaded.cache
	_probe_body = CharacterBody3D.new(); _probe_body.name = "StaffPlacementProbe29"
	var capsule := CapsuleShape3D.new(); capsule.radius = .36; capsule.height = 1.9
	var shape := CollisionShape3D.new(); shape.shape = capsule; shape.position.y = .95
	_probe_body.add_child(shape); world.add_child(_probe_body); _probe_body.position = Vector3(0,-500,0)
	_probe_body.collision_layer = 0; _probe_body.collision_mask = 1
	_probe = Physical.new()
	if not _probe.configure(_probe_body): return {"ok":false,"reason":"full_capsule_probe"}
	await _scan29()
	_next_scan = 1.0
	report.ok = not report.staff.is_empty() and report.failures.is_empty()
	return report.duplicate(true)

func _physics_process(delta: float) -> void:
	if _disposed or _cache == null or _building: return
	_next_scan -= delta
	if _next_scan > 0.0: return
	_next_scan = 1.0
	_scan29()

func _scan29() -> void:
	if _building or _disposed: return
	_building = true
	_registry._reap(Time.get_ticks_msec())
	var retired := false
	for venue: Variant in _rows.keys():
		var row: Dictionary = _rows[venue]
		if not is_instance_valid(row.owner.get_ref()) or not is_instance_valid(row.clone.get_ref()) or not is_instance_valid(row.counter.get_ref()):
			if is_instance_valid(row.actor): row.actor.disable29(); row.actor.queue_free()
			_rows.erase(venue)
			retired = true
	if retired: await get_tree().physics_frame
	for owner: Variant in Swing.doors():
		if _disposed or _rows.size() >= MAX_STAFF: break
		if not is_instance_valid(owner) or not owner is Node3D: continue
		var clone: Variant = owner.get("clone_node")
		if not clone is Node3D or not is_instance_valid(clone) or clone.get_parent() != _world or clone.get_meta("dsh_town_extra", false) != true or bool(clone.get_meta("venue_closed29", false)): continue
		var sign: Node = clone.get_node_or_null("TownCloneSign")
		if not sign is Label3D: continue
		var kind: String = Registry.kind_of(sign.text)
		if kind.is_empty(): continue
		var venue: String = str(owner.get_instance_id())
		if _rows.has(venue): continue
		if clone.has_meta("staff_retry29") and Time.get_ticks_msec() < int(clone.get_meta("staff_retry29")): continue
		clone.set_meta("venue_staff_required29", true)
		var result: Dictionary = _install29(owner, clone, venue, kind)
		if not result.get("ok", false):
			clone.set_meta("staff_retry29", Time.get_ticks_msec() + 30000)
			report.failures.append({"venue":venue,"clone":str(clone.name),"reason":result.get("reason")})
		else: report.staff.append(result)
		await get_tree().physics_frame
	_building = false

func _point29(seed: Vector3, floor_y: float) -> Variant:
	var point: Variant = _probe.floor_at(seed, floor_y)
	return point if point is Vector3 and absf(point.y - floor_y) < .34 and _probe.standing(point) else null

func _install29(owner: Node3D, clone: Node3D, venue: String, kind: String) -> Dictionary:
	if _registry.ledger.venues.has(venue) and not _registry.ledger.venues[venue].slots.is_empty(): return {"ok":false,"reason":"existing_capacity_claims_preserved"}
	var entry: Dictionary = _registry._build(owner, clone, kind, _probe_body)
	if entry.is_empty(): return {"ok":false,"reason":"physical_entry"}
	var normal: Vector3 = entry.normal
	var tangent := Vector3(-normal.z, 0, normal.x)
	var door: Vector3 = entry.door
	var y: float = entry.inner.y
	var staff_point: Variant = null
	var service_point: Variant = null
	var staff_depth := 6.0
	var compact: bool = clone.get_script() != null and clone.get_script().resource_path.ends_with("npc_compact_service_site29.gd")
	for depth: float in ([6.0] if compact else [6.0, 5.6, 5.2, 4.8, 4.4]):
		staff_point = _point29(door + normal * depth, y)
		service_point = _point29(door + normal * (depth - 2.0), y)
		if staff_point is Vector3 and service_point is Vector3: staff_depth = depth; break
	if not staff_point is Vector3 or not service_point is Vector3:
		var samples: Array = []
		for depth: float in [2.2, 3.0, 3.8, 4.6, 5.4, 6.2]:
			for offset: float in [-2.4, -1.2, 0.0, 1.2, 2.4]: samples.append({"depth":depth,"offset":offset,"clear":_point29(door+normal*depth+tangent*offset,y) is Vector3})
		print("STAFF29_LAYOUT_REJECT ", JSON.stringify({"clone":str(clone.name),"door":door,"normal":normal,"floor_y":y,"samples":samples}))
		return {"ok":false,"reason":"staff_or_counter_customer_clearance"}
	var rooms: Array[Vector3] = []
	var capacity: int = int(clone.get_meta("venue_capacity29", Registry.DEFAULT_CAPACITY[kind]))
	for depth: float in [2.2, 3.4, 4.6]:
		for side: float in [-1.0, 1.0]:
			var point: Variant = _point29(door + normal * depth + tangent * side * 1.6, y)
			if point is Vector3: rooms.append(point)
			if rooms.size() >= capacity: break
		if rooms.size() >= capacity: break
	if not compact and rooms.size() < capacity:
		for depth: float in [2.2, 3.4]:
			for side: float in [-1.0, 1.0]:
				var point: Variant = _point29(door + normal * depth + tangent * side * 2.8, y)
				if point is Vector3: rooms.append(point)
				if rooms.size() >= capacity: break
			if rooms.size() >= capacity: break
	if rooms.size() != capacity: return {"ok":false,"reason":"all_waiting_slots_must_fit"}
	var support_ray := PhysicsRayQueryParameters3D.create(staff_point + Vector3.UP * .15, staff_point - Vector3.UP * .1, 1)
	var hit: Dictionary = _world.get_world_3d().direct_space_state.intersect_ray(support_ray)
	var floor_body: Variant = hit.get("collider")
	if not floor_body is RigidBody3D or not clone.has_method("owns_collider") or not clone.owns_collider(floor_body): return {"ok":false,"reason":"owned_native_floor_required"}
	var counter: RigidBody3D
	for body: Variant in clone.get("pieces"):
		if is_instance_valid(body) and str(body.name).begins_with("ServiceCounter"): counter = body; break
	var counter_center: Vector3 = door + normal * (staff_depth - 1.0); counter_center.y = y + .45
	var basis := Basis(tangent, Vector3.UP, -normal)
	var counter_query := PhysicsShapeQueryParameters3D.new(); var counter_box := BoxShape3D.new()
	counter_box.size = Vector3(1.8,.88,.55); counter_query.shape = counter_box
	counter_query.transform = Transform3D(basis,counter_center + Vector3.UP * .015)
	counter_query.collision_mask = 1
	var excluded: Array[RID] = [floor_body.get_rid(), _probe_body.get_rid()]
	if counter != null: excluded.append(counter.get_rid())
	counter_query.exclude = excluded
	if not _world.get_world_3d().direct_space_state.intersect_shape(counter_query,1).is_empty(): return {"ok":false,"reason":"owned_counter_volume_obstructed"}
	var appearance: Dictionary = _cache.instantiate_actor()
	if not appearance.get("ok", false): return {"ok":false,"reason":"rig_instance"}
	var staff: CharacterBody3D = Actor.new(); _world.add_child(staff)
	if not staff.configure29(clone, _registry, venue, staff_point, normal, appearance, kind):
		staff.queue_free(); return {"ok":false,"reason":"rig_binding"}
	if counter == null:
		# The old Palazzo copies retain their native floor owner. This small furniture
		# collider/visual belongs to that existing body and leaves with its fragment.
		counter = floor_body
		_box29(counter, Vector3(1.8,.9,.55), Transform3D(basis,counter_center), Color("80654e"), true)
	var device_at: Vector3 = door + normal * (staff_depth - .75); device_at.y = y + .99
	if kind == "hospital":
		preload("npc_medic_style30.gd").case30(counter,Transform3D(basis,device_at))
	else:
		_box29(counter, Vector3(.44,.18,.30), Transform3D(basis,device_at), Color("263a3f"))
		_box29(counter, Vector3(.32,.015,.17), Transform3D(basis,device_at + Vector3.UP * .10), Color("62b5c2"))
	var label := Label3D.new(); label.text = "МЕДИК" if kind == "hospital" else "КАССИР"
	label.font_size = 40; label.pixel_size = .004; label.modulate = Color("e9e1c7")
	counter.add_child(label); label.global_transform = Transform3D(basis, counter_center - normal * .29 + Vector3.UP * .1)
	var layout: Dictionary = {"rooms":rooms,"service_point":service_point,"staff":weakref(staff),"counter":weakref(counter)}
	staff._counter29 = weakref(counter)
	clone.set_meta("venue_staff_layout29", layout)
	entry.rooms = rooms; entry.service_point29 = service_point; entry.staff29 = weakref(staff)
	_registry.install_staff29(venue, owner, clone, entry)
	_rows[venue] = {"owner":weakref(owner),"clone":weakref(clone),"counter":weakref(counter),"actor":staff}
	return {"ok":true,"venue":venue,"kind":kind,"waiting_slots":rooms.size(),"staff_point":staff_point,"service_point":service_point,"canonical_bones":28}

func _box29(owner: RigidBody3D, size: Vector3, frame: Transform3D, color: Color, collision: bool = false) -> void:
	var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size
	var material := StandardMaterial3D.new(); material.albedo_color = color; mesh.material = material
	visual.mesh = mesh; owner.add_child(visual); visual.global_transform = frame
	if collision:
		var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size
		shape.shape = box; owner.add_child(shape); shape.global_transform = frame

func dispose29() -> void:
	_disposed = true
	for row: Dictionary in _rows.values():
		if is_instance_valid(row.actor): row.actor.disable29(); row.actor.queue_free()
	_rows.clear()
	if _cache != null: _cache.dispose(); _cache = null
	if is_instance_valid(_probe_body): _probe_body.queue_free()
