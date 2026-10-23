extends SceneTree
## Real imported building, actual source colliders and Godot physics. No GPU.
const Interior = preload("res://scripts/preview_printshop_interior.gd")
var failures: Array[String] = []
var checks: int = 0
var world: Node3D
var adapter: Node3D
var data: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: " + label)

func _run() -> void:
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/printshop_interior.json"))
	var record: Dictionary
	for item: Dictionary in block.buildings:
		if item.id == Interior.SOURCE_ID:
			record = item
	world = Node3D.new()
	root.add_child(world)
	var placement := Node3D.new()
	placement.position = vec(record.positionLocalM)
	placement.rotation.y = deg_to_rad(float(record.transform.yawDegrees))
	placement.scale = Vector3(record.transform.horizontalScale[0], 1.0, record.transform.horizontalScale[1]) * float(record.transform.uniformScale)
	world.add_child(placement)
	var visual: Node3D = load(str(record.path)).instantiate()
	visual.position = vec(record.transform.modelLocalOffsetM)
	placement.add_child(visual)
	adapter = Interior.new()
	world.add_child(adapter)
	var bad: Dictionary = record.duplicate(true)
	bad.id = "another-building"
	check(not adapter.attach_existing(visual, bad, data), "wrong building fails closed")
	bad = record.duplicate(true)
	bad.binding.sha256 = "changed"
	check(not adapter.attach_existing(visual, bad, data), "wrong GLB fails closed")
	var corrupt: Dictionary = data.duplicate(true)
	corrupt.geometry[0].attributes.position.values[0] = NAN
	check(not adapter.attach_existing(visual, record, corrupt), "non-finite geometry fails closed")
	check(adapter.get_child_count() == 0 and not visual.has_meta("printshop_interior_attached"), "failed package creates no nodes or source mutations")
	corrupt = data.duplicate(true)
	corrupt.originM[0] += 1.0
	check(not adapter.attach_existing(visual, record, corrupt), "changed source origin fails closed")
	visual.position.x += 0.25
	check(not adapter.attach_existing(visual, record, data), "changed actual visual placement fails closed")
	visual.position.x -= 0.25
	check(adapter.attach_existing(visual, record, data), "real GLB attaches: " + str(adapter.errors))
	if not adapter.ready_for_use:
		_finish()
		return
	check(not adapter.attach_existing(visual, record, data), "duplicate attach rejected")
	check(data.floors.size() == 1 and data.rooms.size() == 3, "one source floor, three source rooms")
	check(data.replaceCollisionSourceIndices.size() == 3 and int(data.replaceCollisionSourceIndices[2]) == 2, "only three source envelope replacements")
	await physics_frame
	await physics_frame
	var public_anchor: Vector3 = vec(data.doors.public.anchor)
	var direction: Vector3 = (adapter.anchor("publicApproach") - adapter.anchor("publicInside")).normalized()
	direction.y = 0.0
	direction = direction.normalized()
	var public_out: Vector3 = public_anchor + direction * 1.4
	var public_in: Vector3 = public_anchor - direction * 1.4
	var service_in: Vector3 = adapter.anchor("doorInside")
	var service_out: Vector3 = adapter.anchor("doorOutside")
	check(blocked(public_out, public_in), "closed public leaf blocks full capsule")
	check(blocked(service_in, service_out), "closed stockroom leaf blocks full capsule")
	check(blocked(adapter.anchor("work"), adapter.anchor("customer")), "source counter remains solid")
	var before_nodes: int = adapter.find_children("*", "", true, false).size()
	var timings: Array[float] = []
	var update_costs: Array[float] = []
	for cycle: int in range(100):
		var start: int = Time.get_ticks_usec()
		check(adapter.request_door("public", true, public_out, []).accepted, "public open " + str(cycle))
		check(adapter.request_door("service", true, service_in, []).accepted, "service open " + str(cycle))
		for step: int in range(7):
			var update_start: int = Time.get_ticks_usec()
			adapter.advance(0.1, [{"position": public_out, "radius": 0.36, "height": 1.9}])
			update_costs.append(float(Time.get_ticks_usec() - update_start) / 1000.0)
		await physics_frame
		await physics_frame
		check(is_equal_approx(adapter.door_fraction("public"), 1.0) and is_equal_approx(adapter.door_fraction("service"), 1.0), "open completed " + str(cycle))
		check(not blocked(public_out, public_in), "opened public capsule passage " + str(cycle))
		check(not blocked(service_in, service_out), "opened service capsule passage " + str(cycle))
		check(adapter.request_door("public", false, public_out, []).accepted, "public close " + str(cycle))
		check(adapter.request_door("service", false, service_in, []).accepted, "service close " + str(cycle))
		for step: int in range(7):
			adapter.advance(0.1, [])
		await physics_frame
		await physics_frame
		check(blocked(public_out, public_in) and blocked(service_in, service_out), "closed colliders restored " + str(cycle))
		timings.append(float(Time.get_ticks_usec() - start) / 1000.0)
	check(adapter.find_children("*", "", true, false).size() == before_nodes, "100 cycles allocate no new scene nodes")
	check(not bool(adapter.nearest_action(public_out).opening), "closed action exposes actual target")
	adapter.request_door("public", true, public_out, [])
	check(bool(adapter.nearest_action(public_out).opening), "immediate second input sees opening target before motion")
	adapter.request_door("public", false, public_out, [])
	check(not bool(adapter.nearest_action(public_out).opening), "rapid toggle reverses desired action without fraction ambiguity")
	check(not adapter.request_door("public", true, public_out + Vector3(30, 0, 0), []).accepted, "out of range rejected")
	check(not adapter.request_door("service", true, service_out, []).accepted, "service opens only from exact source staff anchor")
	check(not adapter.request_door("service", true, service_in, [{"position": Vector3(NAN, 0, 0), "radius": 0.36, "height": 1.9}]).accepted, "malformed occupant fails closed")
	var service_middle: Vector3 = (service_in + service_out) * 0.5
	service_middle = vec(data.doors.service.anchor) + (service_out - service_in).normalized() * 1.15
	check(not adapter.request_door("service", true, service_in, [{"position": service_middle, "radius": 0.36, "height": 1.9}]).accepted, "occupied service sweep refuses motion")
	check(adapter.request_door("service", true, service_in, []).accepted, "resume after obstacle removed")
	for step: int in range(7):
		adapter.advance(0.1, [])
	check(adapter.request_door("service", false, service_in, []).accepted, "closing requested")
	for step: int in range(7):
		adapter.advance(0.1, [{"position": service_middle, "radius": 0.36, "height": 1.9}])
	check(adapter.door_fraction("service") > 0.0, "new moving obstruction stops closing")
	for key: String in ["spawn", "work", "customer", "publicInside"]:
		var p: Vector3 = adapter.anchor(key)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.2, 0), p - Vector3(0, 0.2, 0)))
		check(not hit.is_empty() and absf(float(hit.position.y) - p.y) < 0.02, "exact source floor under " + key)
	var f: Dictionary = data.floors[0]
	var r: Array = f.rect
	var frame: Transform3D = adapter._matrix(data.frames.storeysToPreview)
	var cx: float = (float(r[0]) + float(r[2])) * 0.5
	var cz: float = (float(r[1]) + float(r[3])) * 0.5
	for segment: Array in [[Vector3(r[0] + 0.4, 1, cz), Vector3(r[0] - 0.4, 1, cz)], [Vector3(r[2] - 0.4, 1, cz), Vector3(r[2] + 0.4, 1, cz)], [Vector3(cx, 1, r[1] + 0.4), Vector3(cx, 1, r[1] - 0.4)], [Vector3(cx, 1, r[3] - 0.4), Vector3(cx, 1, r[3] + 0.4)]]:
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(frame * segment[0], frame * segment[1]))
		check(not hit.is_empty(), "room wall stays closed outside actual door opening")
	# Original instance colours are linear; rendered MultiMesh keeps them and enables colour use.
	var color_batches: int = 0
	for node: Node in adapter.find_children("*", "MultiMeshInstance3D", true, false):
		if node.multimesh.use_colors:
			color_batches += 1
			check(node.multimesh.mesh.surface_get_material(0).vertex_color_use_as_albedo, "source instance colours enabled")
	check(color_batches >= 8, "furnishing colours preserved instead of white defaults")
	adapter.restore_original()
	check(adapter.get_child_count() == 0 and not visual.has_meta("printshop_interior_attached"), "restore removes all generated nodes and marker")
	print("CYCLE_TIMES include headless physics synchronization, not gameplay FPS: " + str(timings.slice(0, 3)))
	update_costs.sort()
	print("HEADLESS door advance CPU ms with one real-size occupant p50=" + str(update_costs[update_costs.size() / 2]) + " p95=" + str(update_costs[int(update_costs.size() * 0.95)]))
	_finish()

func blocked(from: Vector3, to: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3(0, 0.965, 0))
	query.motion = to - from
	query.margin = 0.005
	var result: PackedFloat32Array = world.get_world_3d().direct_space_state.cast_motion(query)
	return result[0] < 0.999

func vec(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _finish() -> void:
	var report := {"pass": failures.is_empty(), "checks": checks, "failures": failures, "cycles": 100, "limits": "Headless actual Godot physics, not GPU visual/FPS or seller/economy acceptance."}
	print(JSON.stringify(report))
	var file := FileAccess.open("res://../../outputs/godot_printshop_interior_headless.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  ") + "\n")
	world.free()
	quit(0 if failures.is_empty() else 1)
