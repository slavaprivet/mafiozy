extends RefCounted
## Godot 4.7.2 NavigationServer backend. Produces proposals; authority + physics
## admit every connector and every actual movement. Does not create gameplay NPCs.
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const RADIUS := 0.36
const HEIGHT := 1.9
const CELL_SIZE := 0.12000000476837158 # float32 .36 / 3: avoids accidental fourth erosion voxel.
const CELL_HEIGHT := 0.05
const MAX_JOBS := 128
const MAX_FACE_VERTICES := 180000
const MAX_BAKE_AREA := 20000.0
const MAX_PATH_POINTS := 4096
const MAX_PATH_METRES := 512.0
const SAMPLE_METRES := 0.25
const FLOOR_SKIN := 0.04
var _queue: RefCounted
var _space: Callable
var _capsule := CapsuleShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _jobs: Dictionary = {}
var _by_owner: Dictionary = {}
var _next_job := 0
var _epoch := 0
var _authority := ""
var _generation := 0
var _version := -1
var _map := RID()
var _region := RID()
var _mesh: NavigationMesh
var _baking_token := 0
var _waiting: Dictionary = {}
var _state := "EMPTY"
var _disposed := false
var _busy := false
var _mutation_fault := false
var _version_ok := false
var _last_iteration := 0
var _timing_heads: Dictionary = {}
var _stats := {"bakes": 0, "stale_bakes": 0, "queries": 0, "stale_queries": 0, "validated_samples": 0, "rejected_motion": 0, "publish_us": [], "bake_submit_us": [], "bake_wall_us": [], "query_us": [], "pump_us": [], "motion_us": []}

func _init(queue: RefCounted, physics_space: Callable) -> void:
	_queue = queue; _space = physics_space
	_capsule.radius = RADIUS; _capsule.height = HEIGHT
	_query.shape = _capsule; _query.collision_mask = 1; _query.margin = 0.001
	var version := Engine.get_version_info()
	_version_ok = version.major == 4 and version.minor == 7 and version.patch == 2
	if not _version_ok: _state = "UNVERIFIED_ENGINE"

func _record(key: String, microseconds: int) -> void:
	var values: Array = _stats[key]
	if values.size() < 256: values.append(microseconds)
	else:
		var head: int = _timing_heads.get(key, 0)
		values[head] = microseconds; _timing_heads[key] = (head + 1) % 256

func _free_map() -> void:
	if _region.is_valid(): NavigationServer3D.free_rid(_region)
	if _map.is_valid(): NavigationServer3D.free_rid(_map)
	_region = RID(); _map = RID(); _mesh = null; _last_iteration = 0

## Faces are current authored COLLISION triangles in local metres, Godot winding.
## Never feed render meshes via GPU readback. Caller may reuse/mutate its array
## after return: the accepted snapshot owns a separate PackedVector3Array.
func publish_source(faces: PackedVector3Array, authority: String, generation: int, version: int) -> bool:
	var published_at := Time.get_ticks_usec()
	if not Thread.is_main_thread() or _disposed or not _version_ok: return false
	if _busy: _mutation_fault = true; return false
	if authority.is_empty() or generation < 1 or version < 0 or faces.is_empty() or faces.size() % 3 != 0 or faces.size() > MAX_FACE_VERTICES: return false
	if _authority != "" and (authority != _authority or generation < _generation or (generation == _generation and version <= _version)): return false
	var bounds := AABB(faces[0], Vector3.ZERO)
	for point: Vector3 in faces:
		if not point.is_finite() or point.length_squared() > 1e10: return false
		bounds = bounds.expand(point)
	if bounds.size.x > 256.0 or bounds.size.z > 256.0 or bounds.size.y > 64.0 or bounds.size.x * bounds.size.z > MAX_BAKE_AREA: return false
	_authority = authority; _generation = generation; _version = version; _epoch += 1
	for job: Dictionary in _jobs.values(): _terminal(job, "STALE", "source-version-changed")
	_free_map()
	_state = "BAKING"
	_waiting = {"faces": faces.duplicate(), "epoch": _epoch}
	# One active worker, one replaceable newest snapshot: door motion cannot
	# enqueue an unbounded series of obsolete Recast bakes.
	if _baking_token == 0: _start_bake()
	_record("publish_us", Time.get_ticks_usec() - published_at)
	return true

func _new_mesh(voxel_size: float = CELL_SIZE) -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.agent_radius = RADIUS; mesh.agent_height = HEIGHT
	mesh.agent_max_climb = 0.20; mesh.agent_max_slope = 45.0
	mesh.cell_size = voxel_size; mesh.cell_height = CELL_HEIGHT
	mesh.filter_walkable_low_height_spans = true; mesh.filter_ledge_spans = true
	mesh.filter_low_hanging_obstacles = false
	mesh.region_min_size = 0.0; mesh.region_merge_size = 0.0
	mesh.edge_max_error = 0.5
	return mesh

func _start_bake() -> void:
	if _waiting.is_empty() or _disposed: return
	var snapshot := _waiting; _waiting = {}
	var mesh := _new_mesh()
	var geometry := NavigationMeshSourceGeometryData3D.new()
	var started := Time.get_ticks_usec()
	geometry.add_faces(snapshot.faces, Transform3D.IDENTITY)
	_baking_token = int(snapshot.epoch); _stats.bakes += 1
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, geometry, _baked_callback.bind(_baking_token, mesh, geometry, started))
	_record("bake_submit_us", Time.get_ticks_usec() - started)

func _baked_callback(token: int, mesh: NavigationMesh, geometry: NavigationMeshSourceGeometryData3D, started: int) -> void:
	# The server owns its worker lifetime; SceneTree/physics/RIDs are touched only
	# after returning to the main thread. Binding retains resources until done.
	_finish_bake.call_deferred(token, mesh, geometry, started)

func _finish_bake(token: int, mesh: NavigationMesh, _geometry: NavigationMeshSourceGeometryData3D, started: int) -> void:
	_record("bake_wall_us", Time.get_ticks_usec() - started)
	if token != _baking_token:
		_stats.stale_bakes += 1
		return
	_baking_token = 0
	if _disposed: return
	if token != _epoch:
		_stats.stale_bakes += 1
		_start_bake()
		return
	_mesh = mesh
	if mesh.get_polygon_count() == 0:
		_state = "EMPTY_MAP"
		return
	if mesh.get_polygon_count() > 4096:
		_state = "LIMIT_REACHED"
		return
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_map, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(_map, CELL_HEIGHT)
	NavigationServer3D.map_set_use_async_iterations(_map, true)
	NavigationServer3D.map_set_use_edge_connections(_map, false)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_enabled(_region, true)
	NavigationServer3D.region_set_navigation_layers(_region, 1)
	NavigationServer3D.region_set_navigation_mesh(_region, mesh)
	NavigationServer3D.region_set_map(_region, _map)
	NavigationServer3D.map_set_active(_map, true)
	_state = "SYNCING"

func state() -> String:
	if not Thread.is_main_thread(): return "INVALID_THREAD"
	if _state == "SYNCING" and _map.is_valid():
		var iteration := NavigationServer3D.map_get_iteration_id(_map)
		if iteration > 0 and NavigationServer3D.region_get_iteration_id(_region) > 0 and NavigationServer3D.region_get_bounds(_region).size.length_squared() > 0.0 and NavigationServer3D.map_get_closest_point_owner(_map, _mesh.get_vertices()[0]) == _region:
			_last_iteration = iteration; _state = "READY"
	return _state

func map_rid() -> RID:
	return _map if state() == "READY" else RID()

func _owner_valid(job: Dictionary) -> bool:
	var owner: RefCounted = job.owner.get_ref()
	return owner != null and not owner.dead and owner.source_id == job.source_id and owner.life_generation == job.life_generation

func _terminal(job: Dictionary, status: String, reason: String = "") -> void:
	job.status = status; job.reason = reason
	if status != "READY": job.admit = Callable(); job.path = PackedVector3Array()

## Source identity is supplied by the host; this API never invents residents.
## admit(point_metres, source_id, life_generation) checks CURRENT source access.
func request_path(owner: RefCounted, start: Vector3, target: Vector3, admit: Callable, exclude: Array[RID] = []) -> int:
	if not Thread.is_main_thread() or _disposed or _busy or not _version_ok or not _queue is Queue or not owner is Queue.Owner or owner.dead or not start.is_finite() or not target.is_finite() or not admit.is_valid(): return -1
	if start.distance_to(target) > MAX_PATH_METRES or exclude.size() > 16: return -1
	var identity := owner.get_instance_id()
	if _by_owner.has(identity): cancel(int(_by_owner[identity]))
	if _jobs.size() >= MAX_JOBS: return -1
	_next_job += 1
	_jobs[_next_job] = {"id": _next_job, "owner": weakref(owner), "owner_instance": identity, "source_id": owner.source_id, "life_generation": owner.life_generation, "epoch": _epoch, "status": "PENDING", "phase": "QUEUED", "reason": "", "start": start, "target": target, "admit": admit, "exclude": exclude.duplicate(), "path": PackedVector3Array(), "edge": 1, "sample": 0, "iteration": 0}
	_by_owner[identity] = _next_job
	return _next_job

func poll(id: int) -> Dictionary:
	if not Thread.is_main_thread(): return {"status": "INVALID_THREAD"}
	if not _jobs.has(id): return {"status": "CANCELLED"}
	var job: Dictionary = _jobs[id]
	if not _owner_valid(job): _terminal(job, "CANCELLED", "owner-life-ended")
	if job.epoch != _epoch: _terminal(job, "STALE", "source-version-changed")
	if job.status == "READY" and (state() != "READY" or job.iteration != NavigationServer3D.map_get_iteration_id(_map)): _terminal(job, "STALE", "map-iteration-changed")
	return {"status": job.status, "reason": job.reason, "source_id": job.source_id, "life_generation": job.life_generation, "authority": _authority, "generation": _generation, "version": _version, "epoch": job.epoch, "iteration": job.iteration, "path": job.path.duplicate() if job.status == "READY" else PackedVector3Array()}

func cancel(id: int) -> void:
	if not Thread.is_main_thread(): return
	if _busy: _mutation_fault = true; return
	if not _jobs.has(id): return
	var job: Dictionary = _jobs[id]
	var owner: RefCounted = job.owner.get_ref()
	if owner != null: _queue.cancel(owner)
	_by_owner.erase(job.owner_instance); _jobs.erase(id)

func pump(frame_id: int) -> void:
	if not Thread.is_main_thread() or _disposed or _busy: return
	var current := state()
	if current != "READY" and current != "EMPTY_MAP" and current != "LIMIT_REACHED": return
	_busy = true; _mutation_fault = false
	var started := Time.get_ticks_usec()
	for job: Dictionary in _jobs.values():
		if job.status != "PENDING" or job.phase == "QUERY_WAIT": continue
		if not _owner_valid(job): _terminal(job, "CANCELLED", "owner-life-ended"); continue
		if job.epoch != _epoch: _terminal(job, "STALE", "source-version-changed"); continue
		if current == "EMPTY_MAP": _terminal(job, "NO_PATH", "empty-authoritative-map"); continue
		if current == "LIMIT_REACHED": _terminal(job, "LIMIT_REACHED", "engine-map-polygon-limit"); continue
		var owner: RefCounted = job.owner.get_ref()
		if not _queue.reserve(frame_id, owner): continue
		if job.phase == "QUEUED": _submit_query(job)
		elif job.phase == "VALIDATING": _validate(job)
		_queue.finish()
		if _mutation_fault: _terminal(job, "STALE", "reentrant-authority-mutation")
		if Time.get_ticks_usec() - started >= 4000: break
	_busy = false
	_record("pump_us", Time.get_ticks_usec() - started)

func _submit_query(job: Dictionary) -> void:
	var parameters := NavigationPathQueryParameters3D.new()
	parameters.map = _map; parameters.start_position = job.start; parameters.target_position = job.target
	parameters.path_search_max_polygons = 4096; parameters.path_search_max_distance = MAX_PATH_METRES
	parameters.path_return_max_length = MAX_PATH_METRES
	parameters.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
	var result := NavigationPathQueryResult3D.new()
	job.phase = "QUERY_WAIT"; job.iteration = NavigationServer3D.map_get_iteration_id(_map)
	var started := Time.get_ticks_usec(); _stats.queries += 1
	NavigationServer3D.query_path(parameters, result, _query_callback.bind(job.id, job.epoch, job.iteration, result))
	_record("query_us", Time.get_ticks_usec() - started)

func _query_callback(id: int, epoch: int, iteration: int, result: NavigationPathQueryResult3D) -> void:
	_finish_query.call_deferred(id, epoch, iteration, result)

func _finish_query(id: int, epoch: int, iteration: int, result: NavigationPathQueryResult3D) -> void:
	if _disposed or not _jobs.has(id) or epoch != _epoch:
		_stats.stale_queries += 1
		return
	var job: Dictionary = _jobs[id]
	if job.status != "PENDING" or not _owner_valid(job): _stats.stale_queries += 1; return
	if state() != "READY" or NavigationServer3D.map_get_iteration_id(_map) != iteration:
		_terminal(job, "STALE", "map-iteration-changed")
		return
	var proposal: PackedVector3Array = result.path
	if proposal.size() > MAX_PATH_POINTS or result.path_length > MAX_PATH_METRES:
		_terminal(job, "LIMIT_REACHED", "engine-proposal-limit"); return
	if proposal.is_empty():
		_terminal(job, "NO_PATH", "engine-no-complete-proposal"); return
	var last: Vector3 = proposal[-1]; var target: Vector3 = job.target
	if Vector2(last.x - target.x, last.z - target.z).length() > 0.15 or absf(last.y - target.y) > 0.30:
		_terminal(job, "NO_PATH", "engine-returned-partial-path"); return
	var path := PackedVector3Array([job.start])
	for point: Vector3 in proposal:
		if not point.is_finite(): _terminal(job, "NO_PATH", "invalid-engine-point"); return
		if point.distance_to(path[-1]) > 0.001: path.append(point)
	if target.distance_to(path[-1]) > 0.001: path.append(target)
	job.path = path; job.phase = "VALIDATING"

func _physics_clear(from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var space: Variant = _space.call() if _space.is_valid() else null
	if not space is PhysicsDirectSpaceState3D: return false
	_query.exclude = exclude
	_query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * (HEIGHT * 0.5 + FLOOR_SKIN))
	_query.motion = Vector3.ZERO
	if not space.intersect_shape(_query, 1).is_empty(): return false
	_query.motion = to - from
	var fractions: PackedFloat32Array = space.cast_motion(_query)
	return fractions.size() == 2 and fractions[0] >= 0.9999

func _admitted(job: Dictionary, point: Vector3) -> bool:
	if not job.admit.is_valid(): return false
	var result: Variant = job.admit.call(point, job.source_id, job.life_generation)
	return result is bool and result and not _mutation_fault and _owner_valid(job)

func _validate(job: Dictionary) -> void:
	if job.iteration != NavigationServer3D.map_get_iteration_id(_map):
		_terminal(job, "STALE", "map-iteration-changed"); return
	var path: PackedVector3Array = job.path
	if path.size() == 1:
		_terminal(job, "READY" if _admitted(job, path[0]) and _physics_clear(path[0], path[0], job.exclude) else "NO_PATH", "stationary-admission")
		return
	while job.edge < path.size() and not _queue.expired():
		var from: Vector3 = path[job.edge - 1]; var to: Vector3 = path[job.edge]
		var count := maxi(1, int(ceil(from.distance_to(to) / SAMPLE_METRES)))
		var a := from.lerp(to, float(job.sample) / count)
		var b := from.lerp(to, float(job.sample + 1) / count)
		_stats.validated_samples += 1
		if not _admitted(job, a) or not _admitted(job, b): _terminal(job, "NO_PATH", "source-admission-refused"); return
		if not _physics_clear(a, b, job.exclude): _terminal(job, "NO_PATH", "physical-capsule-refused"); return
		job.sample += 1
		if job.sample == count: job.edge += 1; job.sample = 0
	if job.edge == path.size(): _terminal(job, "READY")

## The movement controller must call this on each bounded proposed step, even
## after a READY proposal. This neither moves nor teleports an actor.
func admit_motion(id: int, from: Vector3, to: Vector3) -> bool:
	var started := Time.get_ticks_usec()
	if not Thread.is_main_thread() or _busy or _disposed or not _jobs.has(id) or not from.is_finite() or not to.is_finite() or from.distance_to(to) > SAMPLE_METRES: return false
	var job: Dictionary = _jobs[id]
	if job.status != "READY" or job.epoch != _epoch or not _owner_valid(job) or state() != "READY": return false
	if job.iteration != NavigationServer3D.map_get_iteration_id(_map):
		_terminal(job, "STALE", "map-iteration-changed"); return false
	_busy = true; _mutation_fault = false
	var allowed := _admitted(job, from) and _admitted(job, to) and _physics_clear(from, to, job.exclude)
	_busy = false
	_record("motion_us", Time.get_ticks_usec() - started)
	if not allowed: _stats.rejected_motion += 1
	return allowed

func diagnostics() -> Dictionary:
	var result := _stats.duplicate(true)
	result.merge({"state": state(), "epoch": _epoch, "jobs": _jobs.size(), "bakes_inflight": 1 if _baking_token != 0 else 0, "queued_snapshots": 0 if _waiting.is_empty() else 1, "map_iteration": _last_iteration, "nav_polygons": _mesh.get_polygon_count() if _mesh != null else 0})
	return result

func dispose() -> void:
	if not Thread.is_main_thread(): return
	if _busy: _mutation_fault = true; return
	if _disposed: return
	for id: int in _jobs.keys(): cancel(id)
	_disposed = true; _epoch += 1; _waiting = {}; _state = "DISPOSED"
	_free_map(); _space = Callable()
