extends SceneTree
const Policy = preload("res://scripts/npc_visual/preview_resident_world_policy.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
var scene: Node3D
var policy: RefCounted
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func point_at(r: float, c: float) -> Vector3: return Vector3(c * 4.1 - 395.65, 0, r * 4.1 - 45.1)
func clear_body(point: Vector3) -> bool:
	var shape := BoxShape3D.new(); shape.size = Vector3(1.476, 1.9, 1.476)
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape
	query.collision_mask = 1; query.transform.origin = point + Vector3.UP * .975
	return scene.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preview_transport_enabled = false; scene.preview_start_at_vehicle = false; scene.preview_residents_enabled = false
	root.add_child(scene)
	await physics_frame; await physics_frame
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc_visual/session/" + Policy.PACKET_SHA + ".json"))
	var owners := {}; var states := {}
	for row: Dictionary in packet.rows:
		owners[row.source_id] = Queue.Owner.new(row.source_id, 1); states[row.source_id] = "ordinary_outdoor"
	var trust := {"accepted": true, "packet_sha256": Policy.PACKET_SHA, "block_sha256": Policy.BLOCK_SHA, "session_id": Policy.SESSION}
	var altered := trust.duplicate(); altered.accepted = false
	var rejected := Policy.new()
	check(not rejected.configure(scene, packet.rows, owners, altered, {"version": 1, "states": states}).ok, "root acceptance mandatory")
	altered = trust.duplicate(); altered.packet_sha256 = "384f1f2d2b673bde13a49cfdff2f88b4e84469801b1f572624c53259a472901d"
	check(not rejected.configure(scene, packet.rows, owners, altered, {"version": 1, "states": states}).ok, "historical source rejected")
	var changed: Array = packet.rows.duplicate(true); changed[0].source_raw.c += 1
	check(not rejected.configure(scene, changed, owners, trust, {"version": 1, "states": states}).ok, "unreceipted position change rejected")
	check(not rejected.configure(scene, packet.rows, {}, trust, {"version": 1, "states": states}).ok, "owner records mandatory")
	check(not rejected.configure(scene, packet.rows, owners, trust, {"version": 1, "states": {"resident_72": true}}).ok, "blanket boolean grant rejected")
	var unsupported := states.duplicate(); unsupported.resident_72 = "staff"
	check(not rejected.configure(scene, packet.rows, owners, trust, {"version": 1, "states": unsupported}).ok, "cannot invent private role rights")
	policy = Policy.new()
	var started := Time.get_ticks_usec()
	var configured: Dictionary = policy.configure(scene, packet.rows, owners, trust, {"version": 1, "states": states})
	var configure_us := Time.get_ticks_usec() - started
	check(configured.ok, "actual source configure " + str(configured))
	if not configured.ok: print(JSON.stringify({"checks":checks,"failures":failures})); scene.free(); quit(1); return
	check(policy.callbacks().source_admit.is_valid() and policy.callbacks().support_height.is_valid(), "callbacks ready")
	var surface: Dictionary = scene.get("_block").surface
	for row: Dictionary in packet.rows:
		var point := point_at(row.source_raw.r, row.source_raw.c)
		var r := int(row.source_raw.r); var c := int(row.source_raw.c) - 76
		check(surface.grid[r][c] == 0 and surface.masks.roadMask[r][c] == 1, "actual source pending point lies on road " + row.source_id)
		check(not policy.source_admit(point, row.source_id, 1, .738, "placement"), "ordinary road blocked " + row.source_id)
		check(is_nan(policy.support_height(point, row.source_id, 1)), "road support never upgrades permission " + row.source_id)
	check(scene.find_children("npc_resident_*", "CharacterBody3D", true, false).is_empty(), "policy never creates or relocates residents")
	var valid := Vector3.INF; var target := Vector3.INF; var water := Vector3.INF; var corner := Vector3.INF
	for r in 31:
		for c in 31:
			var point := point_at(r + .5, c + 76.5)
			if surface.grid[r][c] == 16 and not water.is_finite(): water = point
			if not valid.is_finite() and policy.source_admit(point, "resident_72", 1, .738, "target") and is_finite(policy.support_height(point, "resident_72", 1)) and clear_body(point):
				for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
					var other := point + direction * 2
					if policy.source_admit(other, "resident_72", 1, .738, "route") and is_finite(policy.support_height(other, "resident_72", 1)) and clear_body(other): valid = point; target = other; break
			if not corner.is_finite() and policy._point_allowed(point):
				for offset: Vector3 in [Vector3.RIGHT * 1.8, Vector3.LEFT * 1.8, Vector3.FORWARD * 1.8, Vector3.BACK * 1.8]:
					var edge := point + offset
					if policy._point_allowed(edge) and not policy.source_admit(edge, "resident_72", 1, .738, "route"): corner = edge; break
	check(valid.is_finite() and target.is_finite(), "actual dry source pair two metres apart; no residents placed")
	check(water.is_finite() and not policy.source_admit(water, "resident_72", 1, .738, "route") and is_nan(policy.support_height(water, "resident_72", 1)), "actual water denied without invented floor")
	check(corner.is_finite(), "square corner rejects despite clear centre")
	check(not policy.source_admit(valid, "unknown", 1, .738, "route"), "unknown identity denied")
	check(not policy.source_admit(valid, "resident_72", 2, .738, "route"), "wrong lifetime denied")
	check(not policy.source_admit(valid, "resident_72", 1, .36, "route"), "cannot shrink source footprint")
	check(not policy.source_admit(valid, "resident_72", 1, .738, "combat"), "unknown purpose denied")
	check(not policy.source_admit(Vector3(NAN, 0, 0), "resident_72", 1, .738, "route"), "nonfinite denied")
	check(not policy.source_admit(point_at(31, 100), "resident_72", 1, .738, "route"), "half open crop row")
	check(not policy.source_admit(point_at(10, 107), "resident_72", 1, .738, "route"), "half open crop column")
	check(is_nan(policy.support_height(valid + Vector3.UP * 5, "unknown", 1)), "unknown owner no roof fallback")
	var printshop: Node3D = scene.get("_printshop")
	check(not policy.source_admit(printshop.anchor("publicInside"), "resident_72", 1, .738, "route"), "no unreceipted interior visitation")
	if valid.is_finite():
		var floor_y: float = policy.support_height(valid, "resident_72", 1)
		check(absf(floor_y) < .0001, "support actual source ground")
		# TEST obstacle in the actual collision world, never a resident placement.
		var blocker := StaticBody3D.new(); var collision := CollisionShape3D.new(); var shape := BoxShape3D.new()
		shape.size = Vector3(1, .1, 1); collision.shape = shape; blocker.add_child(collision); scene.add_child(blocker)
		blocker.position = valid + Vector3.UP * .15; await physics_frame
		check(is_nan(policy.support_height(valid, "resident_72", 1)), "current unknown support/low roof denied")
		blocker.free(); await physics_frame
		check(is_finite(policy.support_height(valid, "resident_72", 1)), "no stale ray memo after obstacle removal")
		var ray := PhysicsRayQueryParameters3D.create(valid + Vector3.UP * .3, valid - Vector3.UP * .3, 1)
		var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
		var floor_body: StaticBody3D = hit.collider; var floor_shape: CollisionShape3D = floor_body.get_child(0)
		floor_shape.disabled = true; await physics_frame
		check(is_nan(policy.support_height(valid, "resident_72", 1)), "removed actual support is unknown")
		floor_shape.disabled = false; await physics_frame
		var saved_position := floor_body.position; floor_body.position.y += .1; await physics_frame
		check(is_nan(policy.support_height(valid, "resident_72", 1)), "moved floor invalidates original source identity")
		floor_body.position = saved_position; await physics_frame
		var duplicate := floor_body.duplicate(); scene.add_child(duplicate)
		check(not rejected.configure(scene, packet.rows, owners, trust, {"version": 1, "states": states}).ok, "duplicate source floor identity refuses configuration")
		duplicate.free(); await physics_frame
	check(policy.update_access(2, {"resident_72": "deny"}), "current access revision accepted")
	check(not policy.source_admit(valid, "resident_72", 1, .738, "route") and is_nan(policy.support_height(valid, "resident_72", 1)), "revoked actor denied")
	check(not policy.source_admit(valid, "resident_169", 1, .738, "route"), "missing access state means unknown")
	check(not policy.update_access(2, states), "stale access snapshot rejected")
	check(policy.update_access(3, states), "explicit current revision restores ordinary outdoor only")
	var timings: Array[int] = []
	var support_timings: Array[int] = []
	for i in 1000:
		started = Time.get_ticks_usec(); policy.source_admit(valid, "resident_72", 1, .738, "route"); timings.append(Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec(); policy.support_height(valid, "resident_72", 1); support_timings.append(Time.get_ticks_usec() - started)
	owners.resident_72.dead = true
	check(not policy.source_admit(valid, "resident_72", 1, .738, "route"), "dead owner denied")
	owners.resident_72.dead = false
	check(not policy.source_admit(valid, "resident_72", 1, .738, "route"), "observed death cannot revive same lifetime")
	policy.dispose(); policy.dispose()
	check(not policy.source_admit(valid, "resident_169", 1, .738, "route") and is_nan(policy.support_height(valid, "resident_169", 1)), "disposed callbacks fail closed")
	timings.sort(); support_timings.sort()
	print(JSON.stringify({"checks":checks,"failures":failures,"pending_original_ids":owners.keys(),"probe_only_dry_pair":[valid,target],"source_floors":configured.get("source_floors"),"configure_us":configure_us,"admit_us":{"p50":timings[500],"p95":timings[950],"max":timings[-1]},"support_us":{"p50":support_timings[500],"p95":support_timings[950],"max":support_timings[-1]},"scope":"actual main headless; zero resident births; no full FPS claim"}))
	scene.free(); quit(0 if failures.is_empty() else 1)
func _initialize() -> void: call_deferred("run")
