extends SceneTree
const Backend = preload("res://scripts/navigation/preview_engine_navigation.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const Fixture = preload("res://scripts/tests/fixtures/engine_navigation_fixture.gd")
var failures: Array[String] = []
var checks := 0
var fixture: Node3D
var backend: RefCounted
var queue: RefCounted
var reports: Array = []
var worker_state := ""

func summarize(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(); copy["path_points"] = copy.get("path", []).size(); copy.erase("path")
	return copy

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate(); sorted.sort()
	return {"n": sorted.size(), "p50": sorted[sorted.size() / 2], "p95": sorted[int(sorted.size() * .95)], "max": sorted[-1]}

func worker_attempt() -> void: worker_state = backend.state()

func invalid_admission(_point: Vector3, _id: String, _generation: int) -> String: return "true"

func reentrant_admission(_point: Vector3, _id: String, _generation: int) -> bool:
	backend.publish_source(fixture.faces, "current-crop-test-snapshot", 1, 999)
	return true

func benchmark_baked(marker: Dictionary, started: int) -> void:
	marker.done = true; marker.elapsed = Time.get_ticks_usec() - started

func benchmark_callback(marker: Dictionary, started: int) -> void:
	benchmark_baked.call_deferred(marker, started)

func benchmark_voxels() -> void:
	var result: Array = []
	for cell: float in [0.06000000238418579, Backend.CELL_SIZE]:
		var times: Array = []; var polygons: Array = []
		for trial in range(6):
			var mesh: NavigationMesh = backend._new_mesh(cell)
			var geometry := NavigationMeshSourceGeometryData3D.new(); geometry.add_faces(fixture.faces, Transform3D.IDENTITY)
			var marker := {"done": false, "elapsed": 0}
			var started := Time.get_ticks_usec()
			NavigationServer3D.bake_from_source_geometry_data_async(mesh, geometry, benchmark_callback.bind(marker, started))
			while not marker.done: await physics_frame
			check(mesh.get_polygon_count() > 0, "real Recast benchmark has navigation polygons")
			if trial > 0: times.append(marker.elapsed); polygons.append(mesh.get_polygon_count())
		result.append({"cell_metres": cell, "capsule_radius": .36, "capsule_height": 1.9, "bake_wall_us": stats(times), "polygons": polygons, "triangles": fixture.faces.size() / 3})
	reports.append({"same_authored_geometry_recast_before_after": result})

class FixtureActor extends CharacterBody3D:
	var backend: RefCounted
	var request_id := -1
	var goal := Vector3.ZERO
	var agent: NavigationAgent3D
	var arrived := false
	var frames := 0
	var rejected := 0
	var maximum_step := 0.0
	var identity := "fixture:engine-public"
	func setup() -> void:
		set_meta("source_id", identity)
		collision_layer = 2; collision_mask = 1
		floor_snap_length = .25; floor_max_angle = deg_to_rad(45.0)
		var capsule := CapsuleShape3D.new(); capsule.radius = .36; capsule.height = 1.9
		var collision := CollisionShape3D.new(); collision.shape = capsule; collision.position.y = .95
		add_child(collision)
		agent = NavigationAgent3D.new(); agent.radius = .36; agent.height = 1.9
		agent.path_desired_distance = .25; agent.target_desired_distance = .10
		agent.path_max_distance = 1.0; agent.avoidance_enabled = false
		add_child(agent)
		agent.set_navigation_map(backend.map_rid()); agent.target_position = goal
	func _physics_process(delta: float) -> void:
		if arrived or agent == null: return
		# A source update frees the old map immediately. Check the receipt before
		# asking NavigationAgent to query that map; the host must rebind on READY.
		if backend.poll(request_id).status != "READY":
			velocity = Vector3.ZERO
			return
		frames += 1
		var before := global_position
		if global_position.distance_to(goal) < .15:
			arrived = true; velocity = Vector3.ZERO; return
		var next := agent.get_next_path_position()
		var direction := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
		var speed := minf(2.0, direction.length() / maxf(delta, .001))
		direction = direction.normalized()
		var step := direction * speed * delta
		if backend.admit_motion(request_id, global_position, global_position + step):
			velocity.x = direction.x * speed; velocity.z = direction.z * speed
		else:
			rejected += 1; velocity.x = 0; velocity.z = 0
		velocity.y = -2.0 if is_on_floor() else velocity.y - 9.8 * delta
		move_and_slide()
		maximum_step = maxf(maximum_step, global_position.distance_to(before))

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func wait_map() -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		var status: String = backend.state()
		if status == "READY" or status == "EMPTY_MAP": return status == "READY"
		await physics_frame
	return false

func wait_job(id: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		backend.pump(Engine.get_physics_frames())
		var result: Dictionary = backend.poll(id)
		if result.status != "PENDING": return result
		await physics_frame
	return {"status": "TIMEOUT"}

func path_request(owner: RefCounted, from: Vector3, to: Vector3) -> Dictionary:
	var id: int = backend.request_path(owner, from, to, fixture.admit)
	check(id > 0, "request admitted to bounded backend")
	var result: Dictionary = await wait_job(id)
	result["id"] = id
	return result

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/engine_navigation_api_472.json"))
	check(Engine.get_version_info().hash.begins_with("ed1daf0bf"), "locked 4.7.2 engine build")
	for class_name_value: String in manifest.classes:
		var bound_methods := ClassDB.class_get_method_list(class_name_value, true)
		for method: Dictionary in manifest.classes[class_name_value].methods:
			check(ClassDB.class_has_method(class_name_value, method.name), "locked primary API " + class_name_value + "." + str(method.name))
			var found := false
			for bound: Dictionary in bound_methods:
				if bound.name == method.name:
					found = true
					check(bound.args.size() == method.parameters.size(), "locked primary parameter count " + class_name_value + "." + str(method.name))
					for i in mini(bound.args.size(), method.parameters.size()): check(bound.args[i].name == method.parameters[i].name, "locked primary parameter name")
					break
			check(found, "primary bound method present")
	for source: Dictionary in manifest.source_files:
		check(FileAccess.get_sha256("res://" + str(source.path)) == source.sha256, "current authored source SHA " + str(source.path))
	fixture = Fixture.new(); root.add_child(fixture)
	check(fixture.load_data(), "current authoritative fixture data loaded")
	var started := Time.get_ticks_usec(); fixture.rebuild()
	var build_us := Time.get_ticks_usec() - started
	check(fixture.printshop_body_count == 107 and fixture.source_body_count == 131, "107 printshop +24 current crop authored bodies")
	check(fixture.dry_cells == 658 and fixture.water_cells == 303, "authored dry/water mask")
	queue = Queue.new(); backend = Backend.new(queue, fixture.space)
	check(backend.publish_source(fixture.faces, "current-crop-test-snapshot", 1, 1), "async engine bake accepted")
	var public_owner := Queue.Owner.new("fixture:engine-public", 1)
	var staff_owner := Queue.Owner.new("fixture:engine-staff")
	fixture.staff_ids[staff_owner.source_id] = true
	check(is_equal_approx(backend._capsule.radius, .36) and is_equal_approx(backend._capsule.height, 1.9), "physical capsule dimensions preserved")
	var early: int = backend.request_path(public_owner, fixture.anchor("publicApproach"), fixture.anchor("publicInside"), fixture.admit)
	check(backend.poll(early).status == "PENDING", "before bake/map sync is PENDING")
	check(await wait_map(), "real Recast mesh synchronized")
	var closed: Dictionary = await wait_job(early)
	check(closed.status == "NO_PATH", "closed source public door refuses route: " + str(closed))
	reports.append({"closed": summarize(closed), "fixture_build_us": build_us, "triangles": fixture.faces.size() / 3})
	backend.cancel(early)
	fixture.rebuild(1.0, 0.0)
	check(backend.publish_source(fixture.faces, "current-crop-test-snapshot", 1, 2), "actual open door pose published")
	check(await wait_map(), "open-door Recast synchronized")
	var open: Dictionary = await path_request(public_owner, fixture.anchor("publicApproach"), fixture.anchor("publicInside"))
	check(open.status == "READY", "open door/ramp yields admitted physical route: " + str(open))
	reports.append({"open": summarize(open)})
	if open.status == "READY":
		var actor := FixtureActor.new(); actor.backend = backend; actor.request_id = open.id
		actor.position = fixture.anchor("publicApproach") + Vector3.UP * .01; actor.goal = fixture.anchor("publicInside")
		fixture.add_child(actor); actor.setup()
		for frame in range(1200):
			await physics_frame
			if actor.arrived: break
		check(actor.arrived, "physical CharacterBody reaches authored inside anchor")
		check(actor.maximum_step < .10, "no teleport / bounded actual movement")
		check(actor.get_meta("source_id") == public_owner.source_id, "fixture identity preserved")
		reports.append({"movement_arrived": actor.arrived, "frames": actor.frames, "rejected": actor.rejected, "max_step": actor.maximum_step, "position": actor.global_position})
		actor.free()
	var obstacle := BoxShape3D.new(); obstacle.size = Vector3(2, .1, 2)
	var dynamic_ceiling: StaticBody3D = fixture._shape(obstacle, "fixture:dynamic-ceiling", Transform3D(Basis.IDENTITY, fixture.anchor("publicApproach") + Vector3.UP * 1.5))
	await physics_frame; await physics_frame
	check(not backend.admit_motion(open.id, fixture.anchor("publicApproach"), fixture.anchor("publicApproach") + Vector3.RIGHT * .02), "new physical headroom obstacle refuses old READY proposal")
	dynamic_ceiling.free(); await physics_frame; await physics_frame
	check(backend.admit_motion(open.id, fixture.anchor("publicApproach"), fixture.anchor("publicApproach") + Vector3.RIGHT * .02), "motion rechecks current physics after obstacle leaves")
	var thin := BoxShape3D.new(); thin.size = Vector3(.01, 3.0, 2.0)
	var thin_body: StaticBody3D = fixture._shape(thin, "fixture:thin-wall", Transform3D(Basis.IDENTITY, fixture.anchor("publicApproach") + Vector3(.37, 1.5, 0)))
	await physics_frame; await physics_frame
	check(not backend.admit_motion(open.id, fixture.anchor("publicApproach"), fixture.anchor("publicApproach") + Vector3.RIGHT * .02), "continuous radius .36 cast blocks one-centimetre wall before centre touches")
	thin_body.free(); await physics_frame; await physics_frame
	var closed_staff: Dictionary = await path_request(staff_owner, fixture.anchor("doorOutside"), fixture.anchor("spawn"))
	check(closed_staff.status == "NO_PATH", "closed .11m service leaf blocks authorized staff")
	reports.append({"closed_staff": summarize(closed_staff)})
	backend.cancel(closed_staff.id)
	# Current authority can revoke access while the old proposal remains READY.
	fixture.admission_enabled = false
	check(not backend.admit_motion(open.id, fixture.anchor("publicApproach"), fixture.anchor("publicApproach") + Vector3.RIGHT * .02), "changed source admission refuses current movement")
	fixture.admission_enabled = true
	check(not backend.admit_motion(open.id, fixture.anchor("publicApproach"), fixture.anchor("publicInside")), "oversized movement is not a teleport shortcut")
	# Start a real query, then cancel before its deferred completion is consumed.
	var cancel_owner := Queue.Owner.new("fixture:engine-cancel")
	var cancel_id: int = backend.request_path(cancel_owner, fixture.anchor("publicApproach"), fixture.anchor("publicInside"), fixture.admit)
	backend.pump(Engine.get_physics_frames() + 1); backend.cancel(cancel_id)
	await physics_frame; await process_frame
	check(backend.poll(cancel_id).status == "CANCELLED", "cancelled query cannot publish a route")
	check(backend.diagnostics().stale_queries > 0, "actual late query callback rejected")
	# Two accepted versions before the first worker completes retain only latest.
	fixture.rebuild(0.0, 0.0)
	check(backend.publish_source(fixture.faces, "current-crop-test-snapshot", 1, 3), "closing snapshot starts real bake")
	check(backend.poll(open.id).status == "STALE", "old route invalidated immediately at door publication")
	fixture.rebuild(1.0, 1.0)
	check(backend.publish_source(fixture.faces, "current-crop-test-snapshot", 1, 4), "latest open/staff snapshot queued")
	check(backend.diagnostics().bakes_inflight == 1 and backend.diagnostics().queued_snapshots == 1, "bounded one worker and one latest snapshot")
	check(await wait_map(), "latest version eventually synchronizes")
	check(backend.diagnostics().stale_bakes > 0, "obsolete actual bake never publishes")
	check(not backend.publish_source(fixture.faces, "current-crop-test-snapshot", 1, 4), "stale source version rejected")
	check(not backend.publish_source(fixture.faces, "foreign-authority", 1, 5), "foreign authority rejected")
	check(not backend.publish_source(PackedVector3Array([Vector3.ZERO, Vector3(INF, 0, 0), Vector3.ONE]), "current-crop-test-snapshot", 1, 5), "nonfinite geometry rejected")
	check(not backend.publish_source(PackedVector3Array([Vector3(-500, 0, -500), Vector3(500, 0, -500), Vector3(500, 0, 500)]), "current-crop-test-snapshot", 1, 5), "bounded bake area enforced")
	var worker := Thread.new(); worker.start(worker_attempt); worker.wait_to_finish()
	check(worker_state == "INVALID_THREAD", "off-thread host access rejected")
	var staff: Dictionary = await path_request(staff_owner, fixture.anchor("doorOutside"), fixture.anchor("spawn"))
	check(staff.status == "READY", "authored stockroom door accepts authorized staff: " + str(staff))
	var forbidden: Dictionary = await path_request(public_owner, fixture.anchor("doorOutside"), fixture.anchor("spawn"))
	check(forbidden.status == "NO_PATH" and forbidden.reason == "source-admission-refused", "same physical opening does not grant staff authority to public")
	reports.append({"staff": summarize(staff), "public_stockroom": summarize(forbidden)})
	var water_goal := Vector3.INF
	for r in int(fixture.block.surface.rows):
		for c in int(fixture.block.surface.cols):
			if fixture.block.surface.grid[r][c] == 16:
				water_goal = Vector3((int(fixture.block.surface.startCol) + c + .5) * 4.1 - float(fixture.block.originM[0]), -.18, (int(fixture.block.surface.startRow) + r + .5) * 4.1 - float(fixture.block.originM[2]))
				break
		if water_goal.is_finite(): break
	var wet: Dictionary = await path_request(public_owner, fixture.anchor("publicApproach"), water_goal)
	check(wet.status == "NO_PATH", "real source water cell does not become walkable floor")
	var bad_id: int = backend.request_path(public_owner, fixture.anchor("publicApproach"), fixture.anchor("publicInside"), invalid_admission)
	var bad: Dictionary = await wait_job(bad_id)
	check(bad.status == "NO_PATH", "non-boolean admission fails closed")
	var reentry_id: int = backend.request_path(public_owner, fixture.anchor("publicApproach"), fixture.anchor("publicInside"), reentrant_admission)
	var reentry: Dictionary = await wait_job(reentry_id)
	check(reentry.status == "STALE", "provider cannot mutate geometry during validation")
	var dead_owner := Queue.Owner.new("fixture:engine-dead")
	var dead_id: int = backend.request_path(dead_owner, fixture.anchor("publicApproach"), fixture.anchor("publicInside"), fixture.admit)
	dead_owner.dead = true
	check(backend.poll(dead_id).status == "CANCELLED", "dead life cannot consume route")
	backend.cancel(dead_id)
	# Exact current dataset plus an explicitly synthetic low-headroom negative.
	var at: Vector3 = fixture.anchor("publicInside")
	fixture._prism([[at.x - 1, at.z - 1], [at.x + 1, at.z - 1], [at.x + 1, at.z + 1], [at.x - 1, at.z + 1]], at.y + 1.5, at.y + 1.65, "fixture:low-ceiling")
	check(backend.publish_source(fixture.faces, "current-crop-test-snapshot", 1, 5), "low-ceiling negative snapshot")
	check(await wait_map(), "low-ceiling bake synchronized")
	var ceiling: Dictionary = await path_request(public_owner, fixture.anchor("publicApproach"), at)
	check(ceiling.status == "NO_PATH", "1.5m headroom rejects 1.9m actor")
	fixture.rebuild(1.0, 1.0)
	check(backend.publish_source(fixture.faces, "current-crop-test-snapshot", 1, 6), "restore unmodified authored geometry")
	check(await wait_map(), "restored bake synchronized")
	# Real clock and cohorts, repeated current-geometry proposals; no cheap stub.
	var owners: Array = []
	for i in range(24): owners.append(Queue.Owner.new("fixture:engine-load:" + str(i)))
	var ids: Array[int] = []
	for owner: RefCounted in owners: ids.append(backend.request_path(owner, fixture.anchor("publicApproach"), fixture.anchor("publicInside"), fixture.admit))
	var completed := false
	var pending_validation_seen := false
	for frame in range(300):
		backend.pump(Engine.get_physics_frames()); completed = true
		for id: int in ids:
			var receipt: Dictionary = backend.poll(id)
			if receipt.status == "PENDING":
				completed = false
				check(receipt.path.is_empty(), "unvalidated candidate path is never exposed")
				if backend._jobs[id].phase == "VALIDATING": pending_validation_seen = true
		if completed: break
		await physics_frame
	check(completed, "24 jobs finish through actual queue/cohort budget")
	check(pending_validation_seen, "validation itself resumes across admitted slices")
	for id: int in ids:
		check(backend.poll(id).status == "READY", "loaded physical route remains admitted")
		backend.cancel(id)
	var diagnostics: Dictionary = backend.diagnostics()
	var timing: Dictionary = {}
	for key: String in ["publish_us", "bake_submit_us", "bake_wall_us", "query_us", "pump_us", "motion_us"]: timing[key] = stats(diagnostics[key])
	reports.append({"timing": timing, "nav_polygons": diagnostics.nav_polygons, "stale_bakes": diagnostics.stale_bakes, "stale_queries": diagnostics.stale_queries, "max_jobs": 128, "queue": queue.diagnostics()})
	var capacity_owners: Array = []; var capacity_ids: Array[int] = []
	for i in range(128):
		var owner := Queue.Owner.new("fixture:engine-cap:" + str(i)); capacity_owners.append(owner)
		var id: int = backend.request_path(owner, fixture.anchor("publicApproach"), fixture.anchor("publicInside"), fixture.admit)
		if id > 0: capacity_ids.append(id)
	check(backend.diagnostics().jobs == 128 and capacity_ids.size() < 128, "bounded total retained requests including completed receipts")
	for id: int in capacity_ids: backend.cancel(id)
	await benchmark_voxels()
	# Disposal while an actual async bake is alive must not resurrect a map.
	check(backend.publish_source(fixture.faces, "current-crop-test-snapshot", 1, 7), "disposal test bake submitted")
	backend.dispose(); queue.dispose(); fixture.free()
	var dispose_deadline := Time.get_ticks_msec() + 10000
	while backend.diagnostics().bakes_inflight > 0 and Time.get_ticks_msec() < dispose_deadline: await process_frame
	check(backend.state() == "DISPOSED" and not backend.map_rid().is_valid() and backend.diagnostics().jobs == 0, "late worker cannot resurrect disposed map/jobs")
	print(JSON.stringify({"checks": checks, "failures": failures, "reports": reports, "engine": Engine.get_version_info().string, "scope": "headless fixture actors only, no production NPC births/GPU/FPS claim"}))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void: run.call_deferred()
