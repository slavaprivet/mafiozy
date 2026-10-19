extends RefCounted
## Godot 4.7.2 NavigationServer backend. Produces proposals; authority + physics
## admit every connector and every actual movement. Does not create gameplay NPCs.
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const RADIUS := 0.36
const HEIGHT := 1.9
const CELL_SIZE := 0.12000000476837158 # float32 .36 / 3: avoids accidental fourth erosion voxel.
const CELL_HEIGHT := 0.05
## Outdoor proposals must clear the same .738m half-square used by source
## admission. Physical collision remains the original .36m capsule.
const BAKING_RADIUS := 9.0 * CELL_SIZE
const MAX_JOBS := 512
const MAX_FACE_VERTICES := 3000000
const MAX_BAKE_AREA := 1500000.0 # Bounds check only; each actual bake is <100x100m.
const MAX_PATH_POINTS := 4096
const MAX_PATH_METRES := 2000.0
const SAMPLE_METRES := 0.25
var _dsh_ms := 0  # DSH_QUERY_PROBE
var _dsh_samples := 0  # DSH_QUERY_PROBE
var _dsh_clears := 0  # DSH_QUERY_PROBE
var _dsh_admitted := 0  # DSH_QUERY_PROBE
var _dsh_ttl := -1  # DSH_ROUND2: 0 = source behaviour (ask the policy every tick)
var _dsh_reused := 0  # DSH_ROUND2
# DSH_RESID3: start-point query cache for _physics_clear. 0 = original behaviour.
var _dsh_clear_cache := -1
var _dsh_clear_probes := 0
var _dsh_clear_skips := 0
var _dsh_clear_ms := 0
# DSH_MOTION: --city-timing=0 keeps every counter exact and skips only the per-call
# diagnostic sample records. Default 1 = unchanged.
var _dsh_timing := -1
# DSH_NAVSTEP2: --city-navstep-slim=1 enables the allocation-free hot-path variants.
# 0 (default) keeps today's code path and counters.
var _dsh_slim := -1
# DSH_NAVSTEP3: --city-navsplit=0 (default) reads no clock and touches no counter.
# --city-nav-admit-hoist=0 (default) keeps today's exact call sequence.
var _dsh_split := -1
var _dsh_split_on := false
var _dsh_hoist := -1
var _dsh_iter_frame := -1
var _dsh_iter := 0
var _dsh_t := {"admit_us": 0, "clear_us": 0, "clear_shape_us": 0, "clear_cast_us": 0, "clear_entry_us": 0, "move_shape_us": 0, "move_cast_us": 0, "poll_us": 0, "mapi_us": 0, "motion_us": 0, "motion_calls": 0, "admit_calls": 0, "clear_calls": 0, "shape_calls": 0, "skip_calls": 0, "poll_calls": 0, "mapi_calls": 0, "motion_reject": 0}
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

# DSH_MOTION: --city-timing=0 disables only the per-call diagnostic sample records.
# Every counter behind DSH_NAVQ / DSH_NAVSTEP stays exact. Default 1.
func _timing_records() -> bool:
	if _dsh_timing < 0:
		_dsh_timing = 1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-timing="):
				_dsh_timing = maxi(0, int(argument.trim_prefix("--city-timing=")))
	return _dsh_timing != 0

# DSH_NAVSTEP2: --city-navstep-slim=1 enables the allocation-free hot-path variants.
# 0 (default) keeps today's code path.
func _slim_flag() -> int:
	if _dsh_slim < 0:
		_dsh_slim = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-navstep-slim="):
				_dsh_slim = maxi(0, int(argument.trim_prefix("--city-navstep-slim=")))
	return _dsh_slim

# DSH_NAVSTEP3: --city-navsplit=1 only observes; 0 (default) reads no clock.
func _split_flags() -> void:
	_dsh_split = 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--city-navsplit="):
			_dsh_split = maxi(0, int(argument.trim_prefix("--city-navsplit=")))
	_dsh_split_on = _dsh_split == 1

# DSH_NAVSTEP3: --city-nav-admit-hoist=1 resolves the map iteration id once per physics
# frame. Navigation maps publish between frames (the async map sync never runs inside
# _physics_process), and every rebuild of this map goes through publish_source, which
# bumps _epoch and makes any older job STALE before its iteration id could be consulted.
# _free_map()/_activate_tiles() also drop the cache. 0 (default) calls the server.
func _hoist_flag() -> int:
	if _dsh_hoist < 0:
		_dsh_hoist = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-nav-admit-hoist="):
				_dsh_hoist = maxi(0, int(argument.trim_prefix("--city-nav-admit-hoist=")))
	return _dsh_hoist

func _iter_current() -> int:
	var frame := Engine.get_physics_frames()
	if _dsh_iter_frame == frame: return _dsh_iter
	_dsh_iter_frame = frame
	_dsh_iter = NavigationServer3D.map_get_iteration_id(_map)
	return _dsh_iter

func _map_iteration() -> int:
	if _hoist_flag() == 1:
		if _dsh_split_on:
			var hoisted := Time.get_ticks_usec()
			var value := _iter_current()
			_dsh_t["mapi_calls"] = int(_dsh_t["mapi_calls"]) + 1
			_dsh_t["mapi_us"] = int(_dsh_t["mapi_us"]) + Time.get_ticks_usec() - hoisted
			return value
		return _iter_current()
	if _dsh_split_on:
		var started := Time.get_ticks_usec()
		var plain := NavigationServer3D.map_get_iteration_id(_map)
		_dsh_t["mapi_calls"] = int(_dsh_t["mapi_calls"]) + 1
		_dsh_t["mapi_us"] = int(_dsh_t["mapi_us"]) + Time.get_ticks_usec() - started
		return plain
	return NavigationServer3D.map_get_iteration_id(_map)

func _dsh_t_add(key: String, started: int) -> void:  # DSH_NAVSTEP3
	_dsh_t[key] = int(_dsh_t[key]) + Time.get_ticks_usec() - started

func split_counters() -> Dictionary:  # DSH_NAVSTEP3
	return _dsh_t.duplicate()

## Integer voxel-aligned 96m tiles. One async Recast worker, one newest snapshot.
## Partial maps are never exposed as READY; actual source + physics still own
## every inherited path validation and movement step.
const TILE_CELLS := 800
const TILE_METRES := TILE_CELLS * CELL_SIZE
const BORDER := 12.0 * CELL_SIZE
const MAX_TILES := 256
const MAX_TILE_VERTICES := 180000
const MAX_TILE_POLYGONS := 8192
const MAX_INDEX_REFERENCES := 2000000
const PREPARE_BUDGET_US := 2000
var _build := {}
var _tile_cache := {}
var _regions: Array[RID] = []
var _meshes: Array[NavigationMesh] = []
var _worker_key := ""
var _tile_stats := {"prepared_triangles":0,"index_references":0,"tiles":0,"baked":0,"reused":0,"empty":0,"prepare_us_max":0,"polygons":0}

func _free_map() -> void:
	for region: RID in _regions:
		if region.is_valid(): NavigationServer3D.free_rid(region)
	_regions.clear(); _meshes.clear()
	if _map.is_valid(): NavigationServer3D.free_rid(_map)
	_region=RID(); _map=RID(); _mesh=null; _last_iteration=0
	_dsh_iter_frame = -1  # DSH_NAVSTEP3: the cached iteration id belongs to the freed map

func publish_source(faces: PackedVector3Array, authority: String, generation: int, version: int) -> bool:
	var started:=Time.get_ticks_usec()
	if not Thread.is_main_thread() or _disposed or not _version_ok: return false
	if _busy: _mutation_fault=true; return false
	if authority.is_empty() or generation<1 or version<0 or faces.is_empty() or faces.size()%3!=0 or faces.size()>MAX_FACE_VERTICES: return false
	if _authority!="" and (authority!=_authority or generation<_generation or (generation==_generation and version<=_version)): return false
	_authority=authority; _generation=generation; _version=version; _epoch+=1
	for job: Dictionary in _jobs.values(): _terminal(job,"STALE","source-version-changed")
	_free_map(); _state="PREPARING"
	_build={"faces":faces.duplicate(),"epoch":_epoch,"stage":"BOUNDS","cursor":0,"bounds":AABB(faces[0],Vector3.ZERO),"tiles":{},"keys":[],"next":0,"references":0}
	_waiting={}
	_tile_stats={"prepared_triangles":0,"index_references":0,"tiles":0,"baked":0,"reused":0,"empty":0,"prepare_us_max":0,"polygons":0}
	_record("publish_us",Time.get_ticks_usec()-started)
	return true

func _new_mesh(voxel_size: float=CELL_SIZE) -> NavigationMesh:
	var mesh:=NavigationMesh.new()
	mesh.agent_radius=BAKING_RADIUS; mesh.agent_height=HEIGHT
	mesh.agent_max_climb=.20; mesh.agent_max_slope=45.0
	mesh.cell_size=voxel_size; mesh.cell_height=CELL_HEIGHT
	mesh.filter_walkable_low_height_spans=true; mesh.filter_ledge_spans=true
	mesh.filter_low_hanging_obstacles=false
	mesh.region_min_size=0.0; mesh.region_merge_size=0.0
	mesh.edge_max_error=.5; mesh.border_size=BORDER
	return mesh

func _tile_fail(reason: String) -> void:
	_state="LIMIT_REACHED"; _tile_stats.reason=reason; _build={}; _free_map()

func _prepare_tiles() -> void:
	if _build.is_empty() or _disposed: return
	var started:=Time.get_ticks_usec()
	var faces: PackedVector3Array=_build.faces
	while _build.stage in ["BOUNDS","PARTITION"]:
		var cursor: int=_build.cursor
		if cursor>=faces.size():
			if _build.stage=="BOUNDS":
				var bounds: AABB=_build.bounds
				if bounds.size.x>1536.0 or bounds.size.z>1536.0 or bounds.size.y>64.0 or bounds.size.x*bounds.size.z>1500000.0: _tile_fail("city-source-bounds"); return
				_build.x0=int(floor(bounds.position.x/TILE_METRES)); _build.z0=int(floor(bounds.position.z/TILE_METRES))
				_build.x1=int(floor(bounds.end.x/TILE_METRES)); _build.z1=int(floor(bounds.end.z/TILE_METRES))
				if (int(_build.x1)-int(_build.x0)+1)*(int(_build.z1)-int(_build.z0)+1)>MAX_TILES: _tile_fail("city-tile-count"); return
				_build.cursor=0; _build.stage="PARTITION"
				continue
			_build.keys=_build.tiles.keys(); _build.keys.sort(); _build.stage="TILES"
			_tile_stats.tiles=_build.keys.size(); _tile_stats.index_references=_build.references
			for key: String in _tile_cache.keys():
				if not _build.tiles.has(key): _tile_cache.erase(key)
			_state="BAKING"
			break
		var a: Vector3=faces[cursor]; var b: Vector3=faces[cursor+1]; var c: Vector3=faces[cursor+2]
		if _build.stage=="BOUNDS":
			for point: Vector3 in [a,b,c]:
				if not point.is_finite() or point.length_squared()>1e10: _tile_fail("invalid-collision-coordinate"); return
				_build.bounds=_build.bounds.expand(point)
		else:
			var x0:=maxi(int(_build.x0),int(floor((minf(a.x,minf(b.x,c.x))-BORDER)/TILE_METRES)))
			var x1:=mini(int(_build.x1),int(floor((maxf(a.x,maxf(b.x,c.x))+BORDER)/TILE_METRES)))
			var z0:=maxi(int(_build.z0),int(floor((minf(a.z,minf(b.z,c.z))-BORDER)/TILE_METRES)))
			var z1:=mini(int(_build.z1),int(floor((maxf(a.z,maxf(b.z,c.z))+BORDER)/TILE_METRES)))
			for z in range(z0,z1+1):
				for x in range(x0,x1+1):
					var key:=str(x)+":"+str(z)
					if not _build.tiles.has(key): _build.tiles[key]={"indices":[],"x":x,"z":z}
					var tile: Dictionary=_build.tiles[key]
					tile.indices.append(cursor); _build.references+=1
					if tile.indices.size()*3>MAX_TILE_VERTICES or int(_build.references)>MAX_INDEX_REFERENCES: _tile_fail("tile-source-budget-no-triangles-dropped"); return
			_tile_stats.prepared_triangles+=1
		_build.cursor=cursor+3
		if Time.get_ticks_usec()-started>=PREPARE_BUDGET_US: break
	_tile_stats.prepare_us_max=maxi(int(_tile_stats.prepare_us_max),Time.get_ticks_usec()-started)

func _start_tile() -> void:
	if _disposed or _build.is_empty() or _build.stage!="TILES" or _baking_token!=0: return
	if int(_build.next)>=_build.keys.size(): _activate_tiles(); return
	var key: String=_build.keys[int(_build.next)]
	var tile: Dictionary=_build.tiles[key]
	# Materialization is bounded to one tile. The global arrays are never fed
	# into a giant Recast bake. Index lists retain every relevant triangle.
	var started:=Time.get_ticks_usec()
	var faces: PackedVector3Array=_build.faces
	var local:=PackedVector3Array(); local.resize(tile.indices.size()*3)
	var output:=0
	for index: int in tile.indices:
		local[output]=faces[index]; local[output+1]=faces[index+1]; local[output+2]=faces[index+2]; output+=3
	var bounds: AABB=_build.bounds
	var low_y: float=floorf(bounds.position.y/CELL_HEIGHT)*CELL_HEIGHT-HEIGHT
	var high_y: float=ceilf(bounds.end.y/CELL_HEIGHT)*CELL_HEIGHT+HEIGHT
	var box:=AABB(Vector3(float(tile.x)*TILE_METRES-BORDER,low_y,float(tile.z)*TILE_METRES-BORDER),Vector3(TILE_METRES+2.0*BORDER,high_y-low_y,TILE_METRES+2.0*BORDER))
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(local.to_byte_array())
	var signature:=hash.finish().hex_encode()+":"+str(box)+":"+str([BAKING_RADIUS,BORDER,CELL_SIZE,CELL_HEIGHT,HEIGHT])
	if _tile_cache.has(key) and _tile_cache[key].signature==signature:
		_meshes.append(_tile_cache[key].mesh); _build.next+=1; _tile_stats.reused+=1
		_record("bake_submit_us",Time.get_ticks_usec()-started)
		return
	var mesh:=_new_mesh(); mesh.filter_baking_aabb=box
	var geometry:=NavigationMeshSourceGeometryData3D.new()
	geometry.add_faces(local,Transform3D.IDENTITY)
	_baking_token=_epoch; _worker_key=key; _stats.bakes+=1
	NavigationServer3D.bake_from_source_geometry_data_async(mesh,geometry,_tile_callback.bind(_epoch,key,signature,mesh,geometry,started))
	_record("bake_submit_us",Time.get_ticks_usec()-started)

func _tile_callback(epoch: int, key: String, signature: String, mesh: NavigationMesh, geometry: NavigationMeshSourceGeometryData3D, started: int) -> void:
	_finish_tile.call_deferred(epoch,key,signature,mesh,geometry,started)

func _finish_tile(epoch: int, key: String, signature: String, mesh: NavigationMesh, _geometry: NavigationMeshSourceGeometryData3D, started: int) -> void:
	_record("bake_wall_us",Time.get_ticks_usec()-started)
	if epoch!=_baking_token or key!=_worker_key: _stats.stale_bakes+=1; return
	_baking_token=0; _worker_key=""
	if _disposed or epoch!=_epoch or _build.is_empty(): _stats.stale_bakes+=1; return
	if mesh.get_polygon_count()>MAX_TILE_POLYGONS: _tile_fail("tile-polygon-budget"); return
	_tile_cache[key]={"signature":signature,"mesh":mesh}
	_meshes.append(mesh); _build.next+=1; _tile_stats.baked+=1
	if mesh.get_polygon_count()==0: _tile_stats.empty+=1

func _activate_tiles() -> void:
	var polygons:=0
	for mesh: NavigationMesh in _meshes: polygons+=mesh.get_polygon_count()
	_tile_stats.polygons=polygons
	if polygons==0: _state="EMPTY_MAP"; _build={}; return
	if polygons>262144: _tile_fail("city-polygon-budget"); return
	_map=NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_map,CELL_SIZE)
	NavigationServer3D.map_set_cell_height(_map,CELL_HEIGHT)
	NavigationServer3D.map_set_use_async_iterations(_map,true)
	# Recast border trimming yields cell-aligned shared edges. Edge connection
	# tolerance only stitches adjacent tile regions; physics rechecks all paths.
	NavigationServer3D.map_set_use_edge_connections(_map,true)
	NavigationServer3D.map_set_edge_connection_margin(_map,CELL_SIZE*.5)
	for mesh: NavigationMesh in _meshes:
		if mesh.get_polygon_count()==0: continue
		var region:=NavigationServer3D.region_create()
		NavigationServer3D.region_set_enabled(region,true)
		NavigationServer3D.region_set_navigation_layers(region,1)
		NavigationServer3D.region_set_navigation_mesh(region,mesh)
		NavigationServer3D.region_set_map(region,_map)
		_regions.append(region)
	NavigationServer3D.map_set_active(_map,true)
	_build={}; _state="SYNCING"

func state() -> String:
	if not Thread.is_main_thread(): return "INVALID_THREAD"
	if _state=="SYNCING" and _map.is_valid():
		var iteration:=NavigationServer3D.map_get_iteration_id(_map)
		if iteration<=0: return _state
		for region: RID in _regions:
			if NavigationServer3D.region_get_iteration_id(region)<=0 or NavigationServer3D.region_get_bounds(region).size.length_squared()<=0.0: return _state
		# Region bake completion precedes the async MAP iteration publishing its
		# polygons. Do not expose a transient empty/partial map to path callers.
		for mesh: NavigationMesh in _meshes:
			if mesh.get_polygon_count()==0: continue
			var point: Vector3=mesh.get_vertices()[0]
			if not NavigationServer3D.map_get_closest_point_owner(_map,point) in _regions or NavigationServer3D.map_get_closest_point(_map,point).distance_to(point)>CELL_SIZE: return _state
		_last_iteration=iteration; _state="READY"
	return _state

func map_rid() -> RID:
	return _map if state()=="READY" else RID()

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

# DSH_MOTION: status-only sibling of poll(). Identical owner/epoch/iteration checks and
# identical terminal transitions; no result Dictionary is built and the proposal array
# is not returned. Steady-state callers that read only `status` use this.
func poll_status(id: int) -> String:
	if _dsh_split < 0: _split_flags()  # DSH_NAVSTEP3
	var dsh_p0 := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
	if not Thread.is_main_thread(): return "INVALID_THREAD"
	if not _jobs.has(id): return "CANCELLED"
	var job: Dictionary = _jobs[id]
	if not _owner_valid(job): _terminal(job, "CANCELLED", "owner-life-ended")
	if job.epoch != _epoch: _terminal(job, "STALE", "source-version-changed")
	# DSH_NAVSTEP2: --city-navstep-slim=1 tests the already resolved _state first.
	# state() returns _state unchanged for every value except "SYNCING", so
	# `_state == "READY" or state() == "READY"` is that same predicate without the
	# call and the String compare on the steady-state path. state() keeps its exact
	# call site and short-circuit: it is still reached only for a READY job.
	if _dsh_slim < 0: _dsh_slim = _slim_flag()
	if job.status == "READY":
		var dsh_ready: bool = (_state == "READY" or state() == "READY") if _dsh_slim == 1 else state() == "READY"
		# DSH_NAVSTEP3: --city-nav-admit-hoist=1 uses the frame's iteration id.
		if not dsh_ready or job.iteration != _map_iteration(): _terminal(job, "STALE", "map-iteration-changed")
	if _dsh_split_on:
		_dsh_t["poll_calls"] = int(_dsh_t["poll_calls"]) + 1
		_dsh_t_add("poll_us", dsh_p0)
	return job.status

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
	if _state in ["PREPARING","BAKING"]:
		_prepare_tiles(); _start_tile()
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
	parameters.path_search_max_polygons = 8192; parameters.path_search_max_distance = MAX_PATH_METRES
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

func _physics_clear(from: Vector3, to: Vector3, exclude: Array[RID], job: Dictionary = {}) -> bool:
	_dsh_clears += 1  # DSH_QUERY_PROBE: 1 intersect_shape + 1 cast_motion per call
	var dsh_c0 := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
	var space: Variant = _space.call() if _space.is_valid() else null
	if not space is PhysicsDirectSpaceState3D: return false
	# DSH_RESID3: only the swept cast repeats for a start point this same job already
	# proved clear; see _clear_cache() and CLEAR_CACHE_EPS_M.
	var cache_on: bool = _clear_cache() > 0 and not job.is_empty()
	var cached := false
	if cache_on:
		cached = job.has("clear_to") and int(job.get("clear_epoch", -1)) == _epoch and (job.get("clear_to") as Vector3).distance_to(from) <= CLEAR_CACHE_EPS_M
	_query.exclude = exclude
	_query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * (HEIGHT * 0.5 + FLOOR_SKIN))
	if _dsh_split_on:
		_dsh_t["clear_calls"] = int(_dsh_t["clear_calls"]) + 1
		_dsh_t_add("clear_entry_us", dsh_c0)
	if cached:
		_dsh_clear_skips += 1
		if _dsh_split_on: _dsh_t["skip_calls"] = int(_dsh_t["skip_calls"]) + 1
	else:
		_dsh_clear_probes += 1
		_query.motion = Vector3.ZERO
		var dsh_s0 := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
		if not space.intersect_shape(_query, 1).is_empty():
			if cache_on: job.erase("clear_to"); job.erase("clear_epoch")
			return false
		if _dsh_split_on:
			_dsh_t["shape_calls"] = int(_dsh_t["shape_calls"]) + 1
			_dsh_t_add("clear_shape_us", dsh_s0)
	_query.motion = to - from
	var dsh_k0 := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
	var fractions: PackedFloat32Array = space.cast_motion(_query)
	if _dsh_split_on: _dsh_t_add("clear_cast_us", dsh_k0)
	var allowed: bool = fractions.size() == 2 and fractions[0] >= 0.9999
	if cache_on:
		if allowed:
			job["clear_to"] = to; job["clear_epoch"] = _epoch
		else:
			job.erase("clear_to"); job.erase("clear_epoch")
	return allowed

func _admitted(job: Dictionary, point: Vector3) -> bool:
	if not job.admit.is_valid(): return false
	var result: Variant = job.admit.call(point, job.source_id, job.life_generation)
	return result is bool and result and not _mutation_fault and _owner_valid(job)

func _validate(job: Dictionary) -> void:
	# DSH_QUERY_PROBE (temporary): path-validation query rate.
	if _dsh_ms == 0:
		_dsh_ms = Time.get_ticks_msec(); _dsh_samples = 0; _dsh_clears = 0; _dsh_admitted = 0
	elif Time.get_ticks_msec() - _dsh_ms >= 1000:
		var dsh_dt := float(Time.get_ticks_msec() - _dsh_ms) / 1000.0
		print("DSH_NAVQ admitted/s=","%.0f" % (float(_dsh_admitted)/dsh_dt)," clears/s=","%.0f" % (float(_dsh_clears)/dsh_dt)," validate/s=","%.0f" % (float(_dsh_samples)/dsh_dt)," validated_total=",_stats.validated_samples," queries=",_stats.queries)
		_dsh_ms = Time.get_ticks_msec(); _dsh_samples = 0; _dsh_clears = 0; _dsh_admitted = 0
	# DSH_RESID3 (temporary): how often the start-point intersect_shape is skipped.
	if _dsh_clear_ms == 0:
		_dsh_clear_ms = Time.get_ticks_msec(); _dsh_clear_probes = 0; _dsh_clear_skips = 0
	elif Time.get_ticks_msec() - _dsh_clear_ms >= 1000:
		var dsh_clear_dt := float(Time.get_ticks_msec() - _dsh_clear_ms) / 1000.0
		print("DSH_RESID3 clear_cache=",_clear_cache()," probes/s=","%.0f" % (float(_dsh_clear_probes)/dsh_clear_dt)," skipped/s=","%.0f" % (float(_dsh_clear_skips)/dsh_clear_dt)," clears/s=","%.0f" % (float(_dsh_clear_probes + _dsh_clear_skips)/dsh_clear_dt))
		_dsh_clear_ms = Time.get_ticks_msec(); _dsh_clear_probes = 0; _dsh_clear_skips = 0
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
		_dsh_admitted += 2; _dsh_samples += 1  # DSH_QUERY_PROBE
		if not _admitted(job, a) or not _admitted(job, b): _terminal(job, "NO_PATH", "source-admission-refused"); return
		if not _physics_clear(a, b, job.exclude, job): _terminal(job, "NO_PATH", "physical-capsule-refused"); return
		job.sample += 1
		if job.sample == count: job.edge += 1; job.sample = 0
	if job.edge == path.size(): _terminal(job, "READY")


# DSH_ROUND2: the source policy proves STATIC terrain, floors and solid squares. The
# path was already validated sample by sample when it was built, so re-proving the
# same static geometry on every tick is redundant; only the swept capsule test has
# to run every tick because bodies move. Re-ask every N ticks, staggered per job.
func _admit_ttl() -> int:
	if _dsh_ttl < 0:
		_dsh_ttl = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-admit-ttl="):
				_dsh_ttl = maxi(0, int(argument.trim_prefix("--city-admit-ttl=")))
	return _dsh_ttl

func _admit_phase(job: Dictionary) -> int:
	var value := 0
	var text_id: String = str(job.get("source_id", ""))
	for index in text_id.length():
		value = (value * 31 + text_id.unicode_at(index)) & 0x7fffffff
	return value

# DSH_RESID3: in admit_motion `from` is meant to be the previous step's already
# admitted `to`, and consecutive path-validation samples chain the same way. The
# previous successful call on this same job already ran the capsule start-point
# intersect_shape for the same job exclusions, so that one query is skipped while
# `from` stays within CLEAR_CACHE_EPS_M of the point it proved clear. 0 (default)
# keeps the original intersect_shape + cast_motion pair on every call.
const CLEAR_CACHE_EPS_M := 0.002

func _clear_cache() -> int:
	if _dsh_clear_cache < 0:
		_dsh_clear_cache = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-clear-cache="):
				_dsh_clear_cache = maxi(0, int(argument.trim_prefix("--city-clear-cache=")))
	return _dsh_clear_cache
## The movement controller must call this on each bounded proposed step, even
## after a READY proposal. This neither moves nor teleports an actor.
func admit_motion(id: int, from: Vector3, to: Vector3) -> bool:
	var started := Time.get_ticks_usec()
	if _dsh_split < 0: _split_flags()  # DSH_NAVSTEP3
	var dsh_m0 := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
	if not Thread.is_main_thread() or _busy or _disposed or not _jobs.has(id) or not from.is_finite() or not to.is_finite() or from.distance_to(to) > SAMPLE_METRES: return false
	var job: Dictionary = _jobs[id]
	# DSH_NAVSTEP3: --city-nav-admit-hoist=1 tests the already resolved _state first,
	# the same exact predicate --city-navstep-slim=1 uses in poll_status: state()
	# returns _state unchanged for every value except "SYNCING". 0 (default) is today.
	var dsh_ready: bool = (_state == "READY" or state() == "READY") if _hoist_flag() == 1 else state() == "READY"
	if job.status != "READY" or job.epoch != _epoch or not _owner_valid(job) or not dsh_ready: return false
	if job.iteration != _map_iteration():
		_terminal(job, "STALE", "map-iteration-changed"); return false
	_busy = true; _mutation_fault = false
	# `from` is the previous step's already-admitted `to` (or was admitted by path
	# validation when the job was created), so the source policy is asked only for the
	# new position. The swept capsule check still spans the whole motion.
	var allowed := false
	var ttl := _admit_ttl()
	if ttl > 0 and bool(job.get("admit_ok", false)) and Engine.get_physics_frames() < int(job.get("admit_due", 0)):
		_dsh_reused += 1
		allowed = true
	else:
		var dsh_a0 := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
		allowed = _admitted(job, to)
		if _dsh_split_on:
			_dsh_t["admit_calls"] = int(_dsh_t["admit_calls"]) + 1
			_dsh_t_add("admit_us", dsh_a0)
		if allowed and ttl > 0:
			job["admit_ok"] = true
			job["admit_due"] = Engine.get_physics_frames() + 1 + (_admit_phase(job) % ttl)
		else:
			job.erase("admit_ok"); job.erase("admit_due")
	if allowed:
		var dsh_c1 := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
		var dsh_pre_shape := int(_dsh_t["clear_shape_us"]) if _dsh_split_on else 0  # DSH_NAVSTEP3
		var dsh_pre_cast := int(_dsh_t["clear_cast_us"]) if _dsh_split_on else 0  # DSH_NAVSTEP3
		allowed = _physics_clear(from, to, job.exclude, job)
		if _dsh_split_on:
			_dsh_t_add("clear_us", dsh_c1)
			# DSH_NAVSTEP3: the move-call share of the two inner native queries, so the
			# split is not polluted by the pump's own path-validation clears.
			_dsh_t["move_shape_us"] = int(_dsh_t["move_shape_us"]) + int(_dsh_t["clear_shape_us"]) - dsh_pre_shape
			_dsh_t["move_cast_us"] = int(_dsh_t["move_cast_us"]) + int(_dsh_t["clear_cast_us"]) - dsh_pre_cast
	_busy = false
	if _dsh_split_on:
		_dsh_t["motion_calls"] = int(_dsh_t["motion_calls"]) + 1
		_dsh_t_add("motion_us", dsh_m0)
		if not allowed: _dsh_t["motion_reject"] = int(_dsh_t["motion_reject"]) + 1
	# DSH_MOTION: --city-timing=0 (default 1) skips only this per-call diagnostic sample.
	if _timing_records(): _record("motion_us", Time.get_ticks_usec() - started)
	if not allowed: _stats.rejected_motion += 1
	return allowed

func diagnostics() -> Dictionary:
	var result := _stats.duplicate(true)
	result.merge({"state":state(),"epoch":_epoch,"jobs":_jobs.size(),"bakes_inflight":1 if _baking_token!=0 else 0,"queued_snapshots":0 if _build.is_empty() else 1,"map_iteration":_last_iteration,"nav_polygons":_tile_stats.polygons,"tiles":_tile_stats.duplicate(true),"regions":_regions.size(),"cache_tiles":_tile_cache.size(),"proposal_only":true})
	return result

func dispose() -> void:
	if not Thread.is_main_thread(): return
	if _busy: _mutation_fault = true; return
	if _disposed: return
	for id: int in _jobs.keys(): cancel(id)
	_disposed = true; _epoch += 1; _waiting = {}; _state = "DISPOSED"
	_free_map(); _space = Callable(); _build={}; _tile_cache.clear()
