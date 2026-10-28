extends SceneTree

const Descriptor = preload("res://scripts/traversal/ladder_descriptor.gd")
const Controller = preload("res://scripts/traversal/ladder_controller.gd")
const Probe = preload("res://scripts/traversal/ladder_probe.gd")
const Motion = preload("res://scripts/traversal/ladder_motion.gd")
const Policy = preload("res://scripts/traversal/ladder_source_collision_policy.gd")
const FIXTURE := "res://scripts/tests/fixtures/printshop_ladder_source.json"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var interior_text := FileAccess.get_file_as_string("res://data/printshop_interior.json").replace("\r\n", "\n")
	var interior: Dictionary = JSON.parse_string(interior_text)
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	check(data.schema == "mafiozi-source-ladder-v1", "source ladder schema")
	check(data.interiorSha256 == interior_text.sha256_text(), "exact accepted interior pin")
	check(data.sourceId == interior.sourceId and data.assetSha256 == interior.assetSha256, "same source ID and bound asset")
	check(data.originM == block.originM and data.transform == interior.transform, "same native preview origin and source transform")
	var descriptor: Dictionary = Descriptor.normalize(data.descriptor)
	check(descriptor.valid and descriptor.id == data.sourceId, "descriptor admits source ID")
	for i in 4:
		check(descriptor.path[i].distance_to(_v(data.descriptor.path[i])) < .000001, "source path point retained %d" % i)
	check(descriptor.step_off_point.distance_to(descriptor.upper-descriptor.normal*.75) < .000001, "source roof step-off retained")
	check(data.rails.size() == 2 and descriptor.route_exclude_rids.is_empty(), "both rails retained without guessed RID exclusions")
	for rail: Dictionary in data.rails:
		check(str(rail.storeyPart).begins_with("Roof_Ladder_Rail_Collision_"), "exact authored rail role")
		var found := false
		for body: Dictionary in interior.staticBodies:
			if body.get("storeyPart", "") == rail.storeyPart:
				found = body.polygonXZ == rail.polygonXZ and body.minY == rail.minY and body.maxY == rail.maxY
		check(found, "rail geometry matches accepted interior")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	check(scene.preview_ready and scene.printshop_status == "ready", "actual accepted main fixture ready")
	var controller := Controller.new()
	controller.configure(scene.get_world_3d().direct_space_state, 1, scene._player.get_rid())
	check(controller.register_ladders([data.descriptor]).registered == 1, "source descriptor registers")
	var candidate: Dictionary = controller.nearest_prompt(descriptor.lower)
	check(not candidate.is_empty() and candidate.end == "lower", "source lower endpoint provides E candidate")
	var started: Dictionary = controller.try_begin(descriptor.lower,candidate,&"interact")
	var probe := Probe.new()
	probe.configure(scene.get_world_3d().direct_space_state,1,scene._player.get_rid())
	var route := probe.inspect_route(Motion.route_points(Motion.begin(descriptor.lower,descriptor,"lower")),descriptor,"upper")
	var overlaps: Array = []
	if route.has("blocked_position"):
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .33
		capsule.height = 1.9
		query.shape = capsule
		query.collision_mask = 1
		query.transform.origin = route.blocked_position+Vector3.UP*.962
		for hit: Dictionary in scene.get_world_3d().direct_space_state.intersect_shape(query,16):
			var collider: CollisionObject3D = hit.collider
			var entry := {"path":str(collider.get_path()),"source_id":collider.get_meta("source_id",""),"kind":collider.get_meta("interior_kind","")}
			var shape: CollisionShape3D = collider.get_child(0)
			if shape.shape is ConvexPolygonShape3D:
				var points: PackedVector3Array = shape.shape.points
				var bounds := AABB(points[0],Vector3.ZERO)
				for p: Vector3 in points: bounds = bounds.expand(p)
				entry.bounds = str(bounds)
			overlaps.append(entry)
	check(not started.started and started.reason == "route_blocked", "unbound current host fails closed rather than passing through its envelope")
	var records: Array = []
	var native_bodies: Array = []
	for node: Node in scene.get_node("PrintshopInterior").get_children():
		if node is StaticBody3D and node.get_meta("interior_kind", "") == "source-static":
			native_bodies.append(node)
	check(native_bodies.size() == interior.staticBodies.size(), "actual source static-body sequence cardinality")
	for i in mini(native_bodies.size(),interior.staticBodies.size()):
		var body: Dictionary = interior.staticBodies[i]
		var expected := PackedVector3Array()
		for p: Array in body.polygonXZ:
			expected.append(Vector3(p[0],body.minY,p[1]))
			expected.append(Vector3(p[0],body.maxY,p[1]))
		var collision: CollisionShape3D = native_bodies[i].get_child(0)
		check(collision.shape is ConvexPolygonShape3D and collision.shape.points == expected, "exact geometry proves source index %d" % i)
		records.append({"rid":native_bodies[i].get_rid(),"building_entry_id":body.get("buildingEntryId",""),"storey_part":body.get("storeyPart","")})
	var near_excludes := Policy.excludes(descriptor.lower,descriptor,records)
	check(near_excludes.size() == data.routeCollisionPolicy.ignoredStaticBodyIndices.size(), "exact source conditional exclude set")
	for index: float in data.routeCollisionPolicy.railStaticBodyIndices:
		check(not near_excludes.has(native_bodies[int(index)].get_rid()), "source rail remains blocking")
	check(not Policy.near_path(descriptor.step_off_point,descriptor), "source step-off is outside exclusion corridor")
	check(Policy.excludes(descriptor.step_off_point,descriptor,records).is_empty(), "source body exclusions stop before roof step-off")
	check(Policy.excludes(descriptor.lower+descriptor.normal*.52,descriptor,records).is_empty(), "outside corridor collision intact")
	check(Policy.excludes(descriptor.lower,descriptor,[{"rid":native_bodies[0].get_rid(),"building_entry_id":"foreign"}]).is_empty(), "other building never excluded")
	var conditional: Dictionary = _inspect_source_policy(probe,Motion.route_points(Motion.begin(descriptor.lower,descriptor,"lower")),descriptor,records)
	var roof_support: Array = []
	for offset: Vector3 in [Vector3.ZERO,Vector3(.22,0,0),Vector3(-.22,0,0),Vector3(0,0,.22),Vector3(0,0,-.22)]:
		var ray := PhysicsRayQueryParameters3D.create(descriptor.step_off_point+offset+Vector3.UP*.24,descriptor.step_off_point+offset-Vector3.UP*.28,1,[scene._player.get_rid()])
		var hit := scene.get_world_3d().direct_space_state.intersect_ray(ray)
		roof_support.append({"offset":offset,"position":hit.get("position"),"normal":hit.get("normal"),"kind":hit.collider.get_meta("interior_kind","") if not hit.is_empty() else "missing"})
	check(not conditional.clear and conditional.reason == "landing_unsupported" and conditional.samples == 304, "source conditional sweep is clear but exact authored roof endpoint lacks native support")
	for receipt: Dictionary in roof_support:
		check(receipt.kind == "source-floor-ceiling" and absf(receipt.position.y-6.47)<.00001 and receipt.normal.y>.99, "actual five-ray support proves 11.5cm authored endpoint gap")
	var settled_path := Motion.route_points(Motion.begin(descriptor.lower,descriptor,"lower"))
	settled_path.append(Vector3(descriptor.step_off_point.x,roof_support[0].position.y,descriptor.step_off_point.z))
	var settled: Dictionary = _inspect_source_policy(probe,settled_path,descriptor,records)
	check(settled.clear, "query-derived final physical settling sweep and support are clear (test only)")
	check(not Policy.near_path(Vector3(NAN,0,0),descriptor), "nonfinite query fails closed")
	check(not Policy.near_path(descriptor.lower,{"id":"","path":descriptor.path}), "anonymous ladder fails closed")
	check(not Policy.near_path(descriptor.lower,{"id":descriptor.id,"path":[descriptor.lower,Vector3(INF,0,0)]}), "malformed path fails closed")
	var descending: Dictionary = _inspect_source_policy(probe,Motion.route_points(Motion.begin(descriptor.upper,descriptor,"upper")),descriptor,records)
	check(descending.clear, "actual authored descent under exact source conditional policy: " + str(descending.reason))
	var costs: Array[int] = []
	var bind_began := Time.get_ticks_usec()
	var bound: Array[RID] = Policy.bind_current(descriptor,records)
	var bind_us := Time.get_ticks_usec()-bind_began
	check(bound == near_excludes, "prebound current source RIDs preserve exact source eligible set")
	check(Policy.excludes_bound(descriptor.step_off_point,descriptor,bound).is_empty(), "prebound policy still releases outside corridor")
	for i in 288:
		var began := Time.get_ticks_usec()
		Policy.excludes_bound(descriptor.lower,descriptor,bound)
		if i>=32: costs.append(Time.get_ticks_usec()-began)
	costs.sort()
	print("PRINTSHOP_LADDER_SOURCE_TEST ",JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,
		"actual_route":started,"inspection":route,"overlaps":overlaps,"source_policy_ascent":conditional,"source_policy_descent":descending,"roof_support":roof_support,"test_only_settled_ascent":settled,"policy_cpu_us":{"p50":costs[128],"p95":costs[243],"samples":256,"one_time_bind_us":bind_us},"scope":"source descriptor against accepted native interior; no player hookup or LIVE; regression PASS does not mean playable ascent"}))
	controller.dispose()
	scene.free()
	quit(0 if failures.is_empty() else 1)

func _inspect_source_policy(probe: RefCounted, path: Array, descriptor: Dictionary, records: Array) -> Dictionary:
	var accepted := 0
	for i in range(1,path.size()):
		var a: Vector3 = path[i-1]
		var b: Vector3 = path[i]
		var count := maxi(1,int(ceil(a.distance_to(b)/.04)))
		for sample in range(count+1):
			var feet := a.lerp(b,float(sample)/count)
			var result: Dictionary = probe.inspect_sweep_samples([{"root_position":feet}],descriptor,{"exclude":Policy.excludes(feet,descriptor,records)})
			if not result.clear:
				return {"clear":false,"reason":"source_policy_capsule_blocked","position":feet,"samples":accepted}
			accepted += 1
	var support: bool = probe.landing_supported(path[-1])
	return {"clear":support,"reason":"clear" if support else "landing_unsupported","samples":accepted}

func _v(value: Dictionary) -> Vector3:
	return Vector3(float(value.x),float(value.y),float(value.z))

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
