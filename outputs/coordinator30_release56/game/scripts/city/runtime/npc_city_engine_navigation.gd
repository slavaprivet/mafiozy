extends RefCounted
## Godot 4.7.2 NavigationServer backend. Produces proposals; authority + physics
## admit every connector and every actual movement. Does not create gameplay NPCs.
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const Work29 = preload("res://scripts/navigation/npc_navigation_work29.gd")
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
# DSH_NAVDEDUPE: --city-nav-validate-dedupe=1 (default) reuses the admit answer this
# same _validate() call already produced for the identical point; 0 runs today's two
# calls per sample. _dsh_dedupe_skips is the proof metric of the DSH_NAVQ line below.
var _dsh_validate_dedupe := -1
var _dsh_dedupe_skips := 0
# DSH_WALKFAST: --city-nav-validate-m=F is the spacing of the PRE-FLIGHT validation grid
# that _validate() walks along a proposed path (SAMPLE_METRES = 0.25 today). It is NOT the
# movement granularity: admit_motion() still refuses any real step > SAMPLE_METRES and still
# runs the swept capsule + source policy per step. -1.0 = unresolved. The DSH_NAVQ line
# prints the density and the validated metres per second.
var _dsh_validate_m := -1.0
# DSH_WALKFAST: the previous window's _stats.rejected_motion, so DSH_NAVQ can print the
# per-second rate of real movement refusals (the "hole between probes" signal) for free.
var _dsh_rejected_last := 0
# DSH_NAVFAIR: --city-nav-fair=1 (default) serves a SLICE of each PENDING job per pump()
# instead of letting the first one burn the whole 4000 us bucket (which is what keeps the
# queue 154-203 deep and a leg waiting ~18 s). --city-nav-fair=0 resolves the slice to 0:
# the loop's new break is then inert and today's run-to-deadline is exactly restored.
# _dsh_visits counts _validate() calls (= slices served) in the window.
var _dsh_nav_fair := -1
var _dsh_nav_fair_slice := 0
var _dsh_visits := 0
# DSH_NAVFAIR: acceptance telemetry of the same window - incoming jobs, completed legs and
# the request -> READY wait in a 256-entry integer ring, plus the unique moving residents.
var _dsh_requests := 0
var _dsh_ready := 0
var _dsh_wait_ring := PackedInt32Array()
var _dsh_wait_cursor := 0
var _dsh_wait_filled := 0
var _dsh_wait_max := 0
var _dsh_moving_ids := {}
# DSH_NAVTAIL: --city-nav-pump-tail-guard=1 (default) and --city-nav-pending-scan=1
# (default) are the two cheaper-for-the-same-service levers inside pump(); 0 on
# either one restores today's exact path for that lever. _dsh_tail_refused counts
# the walk entries the tail guard skipped (each of them could only have been a
# reserve() refusal that serves nothing) and is printed on the DSH_NAVQ line.
# _pending_ids is the PENDING-only walk list, ascending by job id: see _terminal()
# and _pending_forget() for why that set is exact, and _pending_compact() for how
# the ids retired during a walk leave it.
var _dsh_pump_tail := -1
var _dsh_pending_scan := -1
var _dsh_tail_refused := 0
var _pending_ids: Array[int] = []
var _pending_retired := 0
var _pending_scan_active := false
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
var _dsh_t := {"admit_us": 0, "clear_us": 0, "clear_shape_us": 0, "clear_cast_us": 0, "clear_entry_us": 0, "move_shape_us": 0, "move_cast_us": 0, "poll_us": 0, "mapi_us": 0, "motion_us": 0, "motion_calls": 0, "admit_calls": 0, "reused": 0, "clear_calls": 0, "shape_calls": 0, "skip_calls": 0, "poll_calls": 0, "mapi_calls": 0, "motion_reject": 0}
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
var _route_lookahead_m := -1.0
var _validation_refusals: Array[Dictionary] = []
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
		_dsh_timing = 0  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-timing="):
				_dsh_timing = maxi(0, int(argument.trim_prefix("--city-timing=")))
	return _dsh_timing != 0

# DSH_NAVSTEP2: --city-navstep-slim=1 enables the allocation-free hot-path variants.
# 0 (default) keeps today's code path.
func _slim_flag() -> int:
	if _dsh_slim < 0:
		_dsh_slim = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
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
# Exact immutable-prefix certificate. Routes still use a NEW global map and STALE.
const MAX_DOOR_VERTICES := 4096
var _components := {}
var _component_stats := {"fast_publications":0,"fallbacks":0,"certified_reuses":0,"dirty_tiles":0,"fallback_reason":"","publish_us_max":0,"update_us_max":0}
var _tile_stats := {"prepared_triangles":0,"index_references":0,"tiles":0,"baked":0,"reused":0,"empty":0,"prepare_us_max":0,"polygons":0}

func _free_map() -> void:
	for region: RID in _regions:
		if region.is_valid(): NavigationServer3D.free_rid(region)
	_native_zero_reset()
	_regions.clear(); _meshes.clear()
	if _map.is_valid(): NavigationServer3D.free_rid(_map)
	_region=RID(); _map=RID(); _mesh=null; _last_iteration=0
	_dsh_iter_frame = -1  # DSH_NAVSTEP3: the cached iteration id belongs to the freed map
	_reset_ready_proof()

func publish_source(faces: PackedVector3Array, authority: String, generation: int, version: int) -> bool:
	var started:=Time.get_ticks_usec()
	if not Thread.is_main_thread() or _disposed or not _version_ok: return false
	if _busy: _mutation_fault=true; return false
	if authority.is_empty() or generation<1 or version<0 or faces.is_empty() or faces.size()%3!=0 or faces.size()>MAX_FACE_VERTICES: return false
	if _authority!="" and (authority!=_authority or generation<_generation or (generation==_generation and version<=_version)): return false
	_components={} # A generic source publication cannot preserve a component certificate.
	_authority=authority; _generation=generation; _version=version; _epoch+=1
	for job: Dictionary in _jobs.values(): _terminal(job,"STALE","source-version-changed")
	_free_map(); _state="PREPARING"
	_build={"faces":faces.duplicate(),"epoch":_epoch,"stage":"BOUNDS","cursor":0,"bounds":AABB(faces[0],Vector3.ZERO),"tiles":{},"keys":[],"next":0,"references":0}
	_waiting={}
	_tile_stats={"prepared_triangles":0,"index_references":0,"tiles":0,"baked":0,"reused":0,"empty":0,"prepare_us_max":0,"polygons":0}
	_record("publish_us",Time.get_ticks_usec()-started)
	return true

## This API is used only by the existing-world host after capturing exact static
## collisions and the current physical door leaves. No path/cookie is retained.
func publish_components(static_faces: PackedVector3Array, door_faces: PackedVector3Array, authority: String, generation: int, version: int) -> bool:
	if not Thread.is_main_thread() or _disposed or not _version_ok: return false
	if _busy: _mutation_fault=true; return false
	if authority.is_empty() or generation<1 or version<0 or static_faces.is_empty() or static_faces.size()%3!=0 or door_faces.size()%3!=0 or static_faces.size()+door_faces.size()>MAX_FACE_VERTICES: return false
	if _authority!="" and (authority!=_authority or generation<_generation or (generation==_generation and version<=_version)): return false
	var component_started:=Time.get_ticks_usec()
	var bytes:=static_faces.to_byte_array()
	var reason:="no-ready-certificate"
	if state()=="READY" and _baking_token==0 and not _components.is_empty() and authority==_authority and generation==_generation:
		if bytes!=_components.static_bytes: reason="static-prefix-changed"
		elif door_faces.size()>MAX_DOOR_VERTICES: reason="door-certificate-budget"
		else:
			var prepared:=_component_update(static_faces,door_faces)
			if not prepared.is_empty():
				var started:=Time.get_ticks_usec()
				_authority=authority; _generation=generation; _version=version; _epoch+=1
				for job: Dictionary in _jobs.values(): _terminal(job,"STALE","source-version-changed")
				_free_map(); _state="BAKING"; _waiting={}
				prepared.epoch=_epoch; _build=prepared
				_tile_stats={"prepared_triangles":int(door_faces.size()/3),"index_references":prepared.references,"tiles":prepared.keys.size(),"baked":0,"reused":0,"empty":0,"prepare_us_max":0,"polygons":0}
				_component_stats.fast_publications+=1; _component_stats.dirty_tiles=prepared.dirty
				var inclusive:=Time.get_ticks_usec()-component_started
				_component_stats.publish_us_max=maxi(int(_component_stats.publish_us_max),inclusive)
				_record("publish_us",inclusive)
				return true
			reason="bounds-domain-cache-or-budget-changed"
	var faces:=static_faces.duplicate(); faces.append_array(door_faces)
	if not publish_source(faces,authority,generation,version): return false
	_component_stats.fallbacks+=1; _component_stats.fallback_reason=reason
	# Bootstrap metadata is consumed only after the unchanged legacy full partition.
	# Excessively large dynamic input remains legacy and earns no certificate.
	if door_faces.size()<=MAX_DOOR_VERTICES:
		_build.component_bytes=bytes; _build.static_count=static_faces.size()
		_build.static_bounds=AABB(static_faces[0],Vector3.ZERO)
	_component_stats.publish_us_max=maxi(int(_component_stats.publish_us_max),Time.get_ticks_usec()-component_started)
	return true

func _component_update(static_faces: PackedVector3Array, door_faces: PackedVector3Array) -> Dictionary:
	var update_started:=Time.get_ticks_usec()
	var bounds: AABB=_components.static_bounds
	for p: Vector3 in door_faces:
		if not p.is_finite() or p.length_squared()>1e10: return {}
		bounds=bounds.expand(p)
	# Exact global bounds imply the same snapped vertical filter, tile domain and
	# all immutable bake settings from this script. A changed domain uses legacy.
	if bounds!=_components.bounds: return {}
	var dynamic: Dictionary={}; var references:=0
	for cursor in range(0,door_faces.size(),3):
		var a: Vector3=door_faces[cursor]; var b: Vector3=door_faces[cursor+1]; var c: Vector3=door_faces[cursor+2]
		var x0:=maxi(int(_components.x0),int(floor((minf(a.x,minf(b.x,c.x))-BORDER)/TILE_METRES)))
		var x1:=mini(int(_components.x1),int(floor((maxf(a.x,maxf(b.x,c.x))+BORDER)/TILE_METRES)))
		var z0:=maxi(int(_components.z0),int(floor((minf(a.z,minf(b.z,c.z))-BORDER)/TILE_METRES)))
		var z1:=mini(int(_components.z1),int(floor((maxf(a.z,maxf(b.z,c.z))+BORDER)/TILE_METRES)))
		for z in range(z0,z1+1):
			for x in range(x0,x1+1):
				var key:=str(x)+":"+str(z)
				if not _components.tiles.has(key): return {}
				if not dynamic.has(key): dynamic[key]={"indices":[],"faces":PackedVector3Array()}
				dynamic[key].indices.append(static_faces.size()+cursor)
				dynamic[key].faces.append_array(PackedVector3Array([a,b,c])); references+=1
				if references>MAX_INDEX_REFERENCES or Time.get_ticks_usec()-update_started>=PREPARE_BUDGET_US: return {}
	var tiles: Dictionary={}; var dirty:=0
	for key: String in _components.keys:
		var previous: Dictionary=_components.tiles[key]
		if not _tile_cache.has(key) or _tile_cache[key].signature!=previous.signature or _tile_cache[key].mesh!=previous.mesh: return {}
		var indices: Array=previous.indices
		var dynamic_indices: Array=dynamic[key].indices if dynamic.has(key) else []
		var dynamic_bytes: PackedByteArray=dynamic[key].faces.to_byte_array() if dynamic.has(key) else PackedByteArray()
		var count:=int(previous.static_count)+dynamic_indices.size()
		# Removed/added keys, including dynamic-only tiles, take the full partition.
		if count==0 or count*3>MAX_TILE_VERTICES: return {}
		references+=int(previous.static_count)
		if references>MAX_INDEX_REFERENCES: return {}
		var reuse: bool=dynamic_bytes==previous.door_bytes
		if not reuse:
			indices=indices.slice(0,int(previous.static_count)); indices.append_array(dynamic_indices); dirty+=1
		if Time.get_ticks_usec()-update_started>=PREPARE_BUDGET_US: return {}
		tiles[key]={"indices":indices,"x":previous.x,"z":previous.z,"static_count":previous.static_count,"door_bytes":dynamic_bytes,"component_reuse":reuse}
	_component_stats.update_us_max=maxi(int(_component_stats.update_us_max),Time.get_ticks_usec()-update_started)
	var faces:=static_faces.duplicate(); faces.append_array(door_faces)
	return {"faces":faces,"stage":"TILES","cursor":faces.size(),"bounds":bounds,"static_bounds":_components.static_bounds,"static_count":static_faces.size(),"component_bytes":_components.static_bytes,"tiles":tiles,"keys":_components.keys.duplicate(),"next":0,"references":references,"x0":_components.x0,"z0":_components.z0,"x1":_components.x1,"z1":_components.z1,"component_fast":true,"dirty":dirty}

func _component_snapshot() -> void:
	_components={}
	if not _build.has("component_bytes"): return
	var saved: Dictionary={}
	var faces: PackedVector3Array=_build.faces
	for key: String in _build.keys:
		var tile: Dictionary=_build.tiles[key]
		var door_bytes: PackedByteArray=tile.door_bytes
		if not _tile_cache.has(key): return
		saved[key]={"indices":tile.indices,"static_count":tile.static_count,"door_bytes":door_bytes,"x":tile.x,"z":tile.z,"signature":_tile_cache[key].signature,"mesh":_tile_cache[key].mesh}
	_components={"static_bytes":_build.component_bytes,"static_bounds":_build.static_bounds,"bounds":_build.bounds,"x0":_build.x0,"z0":_build.z0,"x1":_build.x1,"z1":_build.z1,"keys":_build.keys.duplicate(),"tiles":saved}

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
			if _build.has("static_count") and cursor<int(_build.static_count): _build.static_bounds=_build.bounds
		else:
			var x0:=maxi(int(_build.x0),int(floor((minf(a.x,minf(b.x,c.x))-BORDER)/TILE_METRES)))
			var x1:=mini(int(_build.x1),int(floor((maxf(a.x,maxf(b.x,c.x))+BORDER)/TILE_METRES)))
			var z0:=maxi(int(_build.z0),int(floor((minf(a.z,minf(b.z,c.z))-BORDER)/TILE_METRES)))
			var z1:=mini(int(_build.z1),int(floor((maxf(a.z,maxf(b.z,c.z))+BORDER)/TILE_METRES)))
			for z in range(z0,z1+1):
				for x in range(x0,x1+1):
					var key:=str(x)+":"+str(z)
					if not _build.tiles.has(key): _build.tiles[key]={"indices":[],"x":x,"z":z,"static_count":0,"door_bytes":PackedByteArray()}
					var tile: Dictionary=_build.tiles[key]
					tile.indices.append(cursor); _build.references+=1
					if _build.has("static_count"):
						if cursor<int(_build.static_count): tile.static_count+=1
						else: tile.door_bytes.append_array(PackedVector3Array([a,b,c]).to_byte_array())
					if tile.indices.size()*3>MAX_TILE_VERTICES or int(_build.references)>MAX_INDEX_REFERENCES: _tile_fail("tile-source-budget-no-triangles-dropped"); return
			_tile_stats.prepared_triangles+=1
		_build.cursor=cursor+3
		if Time.get_ticks_usec()-started>=PREPARE_BUDGET_US: break
	_tile_stats.prepare_us_max=maxi(int(_tile_stats.prepare_us_max),Time.get_ticks_usec()-started)

func _start_tile() -> void:
	if _disposed or _build.is_empty() or _build.stage!="TILES" or _baking_token!=0: return
	# Exact certified cache hits need no rematerialization/hash and are consumed in
	# one bounded batch. Dirty tiles retain the original full soup/signature/bake.
	var reuse_started:=Time.get_ticks_usec()
	while bool(_build.get("component_fast",false)) and int(_build.next)<_build.keys.size():
		var reuse_key: String=_build.keys[int(_build.next)]
		if not bool(_build.tiles[reuse_key].get("component_reuse",false)): break
		_meshes.append(_tile_cache[reuse_key].mesh); _build.next+=1; _tile_stats.reused+=1; _component_stats.certified_reuses+=1
		if Time.get_ticks_usec()-reuse_started>=PREPARE_BUDGET_US: return
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
		# Opt-in intended construction mode. Setter is queued; getter is NOT observed yet.
		if _native_zero_enabled(): NavigationServer3D.region_set_use_async_iterations(region,false)
		NavigationServer3D.region_set_enabled(region,true)
		NavigationServer3D.region_set_navigation_layers(region,1)
		NavigationServer3D.region_set_navigation_mesh(region,mesh)
		NavigationServer3D.region_set_map(region,_map)
		_regions.append(region)
	if _native_zero_enabled(): _native_zero_record_birth()
	NavigationServer3D.map_set_active(_map,true)
	_component_snapshot()
	_build={}; _state="SYNCING"

func state() -> String:
	if not Thread.is_main_thread(): return "INVALID_THREAD"
	if _state=="SYNCING" and _map.is_valid():
		if _ready_budget_enabled(): return _bounded_map_ready()
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
		if _native_zero_enabled(): _native_zero_commit_ready(iteration)
	return _state

func map_rid() -> RID:
	if state()!="READY" or not Work29.bind_map(_map,_queue):return RID()
	return _map

func _owner_valid(job: Dictionary) -> bool:
	var owner: RefCounted = job.owner.get_ref()
	return owner != null and not owner.dead and owner.source_id == job.source_id and owner.life_generation == job.life_generation

func _terminal(job: Dictionary, status: String, reason: String = "") -> void:
	# DSH_NAVTAIL: this is the only place `status` is ever written, so a job leaves
	# the pending list exactly when its status leaves PENDING; _pending_ids therefore
	# stays equal to { id : _jobs[id].status == "PENDING" } and ascending by id.
	var dsh_pending: bool = job.status == "PENDING" or bool(job.get("route_prefix_queued", false))
	job.status = status; job.reason = reason
	job["route_prefix_queued"] = false
	if status != "READY": job.admit = Callable(); job.path = PackedVector3Array()
	# DSH_NAVFAIR: a READY job is a leg the resident may now walk; its wait is
	# request -> READY in whole milliseconds (256-entry integer ring, _nav_wait_push).
	if status == "READY":
		_dsh_ready += 1
		_nav_wait_push(Time.get_ticks_msec() - int(job.get("created_ms", Time.get_ticks_msec())))
	if dsh_pending: _pending_forget(int(job.get("id", 0)))

## Source identity is supplied by the host; this API never invents residents.
## admit(point_metres, source_id, life_generation) checks CURRENT source access.
func request_path(owner: RefCounted, start: Vector3, target: Vector3, admit: Callable, exclude: Array[RID] = []) -> int:
	if not Thread.is_main_thread() or _disposed or _busy or not _version_ok or not _queue is Queue or not owner is Queue.Owner or owner.dead or not start.is_finite() or not target.is_finite() or not admit.is_valid(): return -1
	if start.distance_to(target) > MAX_PATH_METRES or exclude.size() > 16: return -1
	var identity := owner.get_instance_id()
	if _by_owner.has(identity): cancel(int(_by_owner[identity]))
	if _jobs.size() >= MAX_JOBS: return -1
	_next_job += 1
	_jobs[_next_job] = {"id": _next_job, "created_ms": Time.get_ticks_msec(), "owner": weakref(owner), "owner_instance": identity, "source_id": owner.source_id, "life_generation": owner.life_generation, "epoch": _epoch, "status": "PENDING", "phase": "QUEUED", "reason": "", "start": start, "target": target, "admit": admit, "exclude": exclude.duplicate(), "path": PackedVector3Array(), "edge": 1, "sample": 0, "iteration": 0}
	_by_owner[identity] = _next_job
	_dsh_requests += 1  # DSH_NAVFAIR: incoming path jobs of this window
	if _pending_scan_flag() == 1: _pending_ids.append(_next_job)  # DSH_NAVTAIL
	return _next_job

## A daily route already has one bounded native proposal. Validate its existing
## segments through the same queue as request_path(), exposing only completed
## segments to the mover. No query or new job is needed for each waypoint.
func request_proven_route(owner: RefCounted, route: PackedVector3Array, admit: Callable, exclude: Array[RID], map: RID, iteration: int, static_corridor: Callable = Callable()) -> int:
	if not Thread.is_main_thread() or _disposed or _busy or state() != "READY" or map != _map or iteration != _map_iteration() or route.size() < 2 or route.size() > 512: return -1
	if static_corridor.is_valid():
		var object: Object=static_corridor.get_object()
		if object!=admit.get_object() or static_corridor.get_method()!="_route_static_corridor" or admit.get_method()!="_route_admit_pinned" or not object.get_script() is Script or object.get_script().resource_path!="res://scripts/npc_visual/preview_resident_host.gd":return -1
	var metres := 0.0
	for index in route.size():
		if not route[index].is_finite(): return -1
		if index > 0:
			var leg := route[index - 1].distance_to(route[index])
			if leg < 0.001 or leg > 5.1: return -1
			metres += leg
			if metres > MAX_PATH_METRES: return -1
	if _by_owner.has(owner.get_instance_id()): return -1
	var id := request_path(owner, route[0], route[-1], admit, exclude)
	if id < 0: return -1
	if state() != "READY" or map != _map or iteration != _map_iteration():
		cancel(id)
		return -1
	var job: Dictionary = _jobs[id]
	job.path = route.duplicate()
	job.phase = "VALIDATING"
	job.iteration = iteration
	if static_corridor.is_valid():job["static_corridor"]=static_corridor
	job["streaming_route"] = true
	job["route_verified_edge"] = 0
	job["route_desired_edge"] = 1
	job["route_prefix_queued"] = true
	return id

func route_prefix_version(id: int) -> int:
	if not _jobs.has(id): return -1
	var job: Dictionary = _jobs[id]
	if not bool(job.get("streaming_route", false)) or job.status != "READY": return -1
	return int(job.get("route_verified_edge", 0))

## Called by the physical mover as it advances through the verified prefix.
## Demand stays two waypoints ahead and never grants an unvalidated waypoint.
func _route_lookahead_metres() -> float:
	if _route_lookahead_m<0.0:
		_route_lookahead_m=0.0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-route-lookahead-m="):
				_route_lookahead_m=clampf(float(argument.trim_prefix("--city-route-lookahead-m=")),0.0,5.1)
	return _route_lookahead_m

func demand_route_prefix(id: int, current_edge: int) -> bool:
	if not Thread.is_main_thread() or _disposed or _busy or not _jobs.has(id): return false
	var job: Dictionary = _jobs[id]
	if not bool(job.get("streaming_route", false)) or job.status != "READY" or not _owner_valid(job) or job.epoch != _epoch or job.iteration != _map_iteration(): return false
	if current_edge < 0 or current_edge > int(job.get("route_verified_edge", 0)): return false
	var desired: int = mini(job.path.size() - 1, maxi(int(job.get("route_desired_edge", 1)), current_edge + 2))
	# Waypoint spacing varies. A two-point frontier can provide only centimetres
	# near a destination and charge another full queue wait for each pair.
	# Ask for a bounded distance along the same exact path; validation, queue
	# budget and every real movement proof remain unchanged. Default is legacy.
	var lookahead:=_route_lookahead_metres()
	if lookahead>0.0:
		var distance:=0.0
		var limit:=mini(job.path.size()-1,current_edge+32)
		for edge in range(current_edge+1,limit+1):
			distance+=job.path[edge-1].distance_to(job.path[edge])
			if distance>lookahead: break
			desired=maxi(desired,edge)
	job["route_desired_edge"] = desired
	job["route_prefix_demand_frame"] = Engine.get_physics_frames()
	if desired > int(job.get("route_verified_edge", 0)) and not bool(job.get("route_prefix_queued", false)):
		job["route_prefix_queued"] = true
		job["route_prefix_queued_frame"] = Engine.get_physics_frames()
		if _pending_scan_flag() == 1: _pending_ids.append(id)
	return true

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
	var ready_path := PackedVector3Array()
	if job.status == "READY":
		ready_path = job.path.slice(0, int(job.get("route_verified_edge", job.path.size() - 1)) + 1) if bool(job.get("streaming_route", false)) else job.path.duplicate()
	return {"status": job.status, "reason": job.reason, "source_id": job.source_id, "life_generation": job.life_generation, "authority": _authority, "generation": _generation, "version": _version, "epoch": job.epoch, "iteration": job.iteration, "path": ready_path, "route_prefix_version": int(job.get("route_verified_edge", 0)), "route_frontier_pending": bool(job.get("streaming_route", false)) and int(job.get("route_verified_edge", 0)) < job.path.size() - 1,"validation_refusal":job.get("validation_refusal",{}).duplicate(true)}

func cancel(id: int) -> void:
	if not Thread.is_main_thread(): return
	if _busy: _mutation_fault = true; return
	if not _jobs.has(id): return
	var job: Dictionary = _jobs[id]
	var owner: RefCounted = job.owner.get_ref()
	if owner != null: _queue.cancel(owner)
	_by_owner.erase(job.owner_instance); _jobs.erase(id)
	_pending_forget(id)  # DSH_NAVTAIL: cancel() is refused while _busy, so no walk runs

func pump(frame_id: int) -> void:
	if not Thread.is_main_thread() or _disposed or _busy: return
	if _state in ["PREPARING","BAKING"]:
		_prepare_tiles(); _start_tile()
	var current := state()
	if current != "READY" and current != "EMPTY_MAP" and current != "LIMIT_REACHED": return
	_busy = true; _mutation_fault = false
	var started := Time.get_ticks_usec()
	# DSH_NAVTAIL: two independent levers on this walk; both default to 1 and both 0
	# is today's exact path.
	# 1) --city-nav-pump-tail-guard=1 leaves the walk the moment the 4000 us bucket is
	#    spent. Today the budget break at the bottom is reachable only after a
	#    SUCCESSFUL _queue.reserve(); once the served work has spent the bucket,
	#    reserve() refuses on its own `_used >= 4000` condition, so every remaining
	#    entry of the walk is a refusal (~3-5 us) that cannot serve anything. The same
	#    clock test at the TOP of the body therefore removes no service in that regime:
	#    with the bucket spent today serves nothing either, and the owners this skips
	#    are booked into _queue/_batch one pump later, exactly like the refused ones.
	# 2) --city-nav-pending-scan=1 walks the maintained _pending_ids list instead of
	#    the `_jobs.values()` copy of every job; 0 keeps today's exact walk below.
	var dsh_tail: bool = _pump_tail_flag() == 1
	if _pending_scan_flag() == 1:
		# _pending_ids holds exactly the ids whose status is PENDING, ascending by id:
		# the same jobs `for job in _jobs.values()` yields, in the same relative order.
		# It cannot change while this walk runs - request_path()/cancel()/
		# publish_source()/dispose() all bail out on _busy, and _terminal() defers its
		# erase into _pending_retired while _pending_scan_active is set. Ids retired
		# during the walk stay in the list (the status test below skips them, exactly as
		# today's copy does) and are compacted right after it, so the composition of the
		# served jobs is identical by construction, entry for entry and in the same order.
		_pending_scan_active = true
		var dsh_count := _pending_ids.size()
		var dsh_at := 0
		while dsh_at < dsh_count:
			if dsh_tail and Time.get_ticks_usec() - started >= 4000:
				_dsh_tail_refused += dsh_count - dsh_at
				break
			var job: Dictionary = _jobs[_pending_ids[dsh_at]]
			dsh_at += 1
			if (job.status != "PENDING" and not (job.status == "READY" and bool(job.get("route_prefix_queued", false)))) or job.phase == "QUERY_WAIT": continue
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
		_pending_scan_active = false
		if _pending_retired > 0: _pending_compact()
	else:
		# --city-nav-pending-scan=0: today's exact walk - the same _jobs.values() copy,
		# the same order, the same body, with the tail guard above it.
		var dsh_values: Array = _jobs.values()
		var dsh_values_size := dsh_values.size()
		var dsh_seen := 0
		for job: Dictionary in dsh_values:
			if dsh_tail and Time.get_ticks_usec() - started >= 4000:
				_dsh_tail_refused += dsh_values_size - dsh_seen
				break
			dsh_seen += 1
			if (job.status != "PENDING" and not (job.status == "READY" and bool(job.get("route_prefix_queued", false)))) or job.phase == "QUERY_WAIT": continue
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
	# The caller already reserved the existing authority Queue. Failed capacity
	# leaves QUEUED intact and consumes only this small cohort admission.
	if not Work29.can_submit():return
	var parameters := NavigationPathQueryParameters3D.new()
	parameters.map = _map; parameters.start_position = job.start; parameters.target_position = job.target
	parameters.path_search_max_polygons = 8192; parameters.path_search_max_distance = MAX_PATH_METRES
	parameters.path_return_max_length = MAX_PATH_METRES
	parameters.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
	var iteration: int=NavigationServer3D.map_get_iteration_id(_map)
	var started: int=Time.get_ticks_usec()
	var ticket: int=Work29.submit(parameters,self,&"_finish_query",[job.id,job.epoch,iteration])
	if ticket<=0:return
	job.phase="QUERY_WAIT";job.iteration=iteration;_stats.queries+=1
	_record("query_us",Time.get_ticks_usec()-started)

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

func _validation_refused(job: Dictionary, reason: String, stage: String, a: Vector3, b: Vector3) -> void:
	# Capture exact operands before _terminal clears the path. Bounded diagnostics
	# only: no repeated admission, no new grant and no body/claim changes.
	var refusal := {"job_id":int(job.id),"reason":reason,"stage":stage,"a":a,"b":b,"frame":Engine.get_physics_frames(),"epoch":int(job.epoch),"iteration":int(job.iteration),"edge":int(job.edge),"sample":int(job.sample),"source_id":str(job.source_id),"life_generation":int(job.life_generation),"owner_instance":int(job.owner_instance),"start":job.start,"target":job.target}
	var callback: Object=job.admit.get_object() if job.admit.is_valid() else null
	if is_instance_valid(callback) and callback.has_method("_route_admit_pinned"):
		var records: Variant=callback.get("_records")
		var record: Dictionary=records.get(job.source_id,{}) if records is Dictionary else {}
		var body: Variant=record.get("body")
		if body is CharacterBody3D and is_instance_valid(body):
			refusal["body"]=body.global_position
			refusal["body_to_a_m"]=body.global_position.distance_to(a)
			refusal["body_to_b_m"]=body.global_position.distance_to(b)
		var source_callback: Variant=callback.get("_admit")
		if source_callback is Callable and source_callback.is_valid():
			var policy: Object=source_callback.get_object()
			if is_instance_valid(policy) and policy.has_method("current_errand_cookie"):
				refusal["policy_reason_observation"]=str(policy.get("_last_reason"))
	job["validation_refusal"]=refusal
	_validation_refusals.append(refusal)
	if _validation_refusals.size()>16: _validation_refusals.pop_front()
	_terminal(job,"NO_PATH",reason)

func _validate(job: Dictionary) -> void:
	if job.get("static_corridor") is Callable and job.static_corridor.is_valid():
		_validate_static_corridor(job);return
	if bool(job.get("streaming_route",false)):
		job["route_prefix_served_frame"]=Engine.get_physics_frames()
		job["route_prefix_visits"]=int(job.get("route_prefix_visits",0))+1
	# DSH_QUERY_PROBE (temporary): path-validation query rate.
	if _dsh_ms == 0:
		_dsh_ms = Time.get_ticks_msec(); _dsh_samples = 0; _dsh_clears = 0; _dsh_admitted = 0; _dsh_rejected_last = _stats.rejected_motion
	elif Time.get_ticks_msec() - _dsh_ms >= 1000:
		var dsh_dt := float(Time.get_ticks_msec() - _dsh_ms) / 1000.0
		print("DSH_NAVQ admitted/s=","%.0f" % (float(_dsh_admitted)/dsh_dt)," clears/s=","%.0f" % (float(_dsh_clears)/dsh_dt)," validate/s=","%.0f" % (float(_dsh_samples)/dsh_dt)," validated_total=",_stats.validated_samples," queries=",_stats.queries," dedupe_skips/s=","%.0f" % (float(_dsh_dedupe_skips)/dsh_dt)," tail_refused/s=","%.0f" % (float(_dsh_tail_refused)/dsh_dt)," pending_scan=",("ids" if _pending_scan_flag() == 1 else "jobs")," pending=",(_pending_ids.size() if _pending_scan_flag() == 1 else -1)," validate_m=","%.2f" % _validate_metres()," validated_m/s=","%.0f" % (float(_dsh_samples)/dsh_dt*_validate_metres())," blocked_between_probes/s=","%.0f" % (float(_stats.rejected_motion-_dsh_rejected_last)/dsh_dt))
		# DSH_NAVFAIR: acceptance telemetry of the same one-second window. wait_ms is
		# request -> READY (the queue rage the owner reported) from the integer ring;
		# moving_unique counts distinct jobs whose real motion was admitted.
		print("DSH_NAVQ fair visits/s=","%.0f" % (float(_dsh_visits)/dsh_dt)," requests/s=","%.0f" % (float(_dsh_requests)/dsh_dt)," ready/s=","%.0f" % (float(_dsh_ready)/dsh_dt)," wait_ms_p50=",_nav_wait_pct(.50)," wait_ms_p95=",_nav_wait_pct(.95)," wait_ms_max=",_dsh_wait_max," moving_unique=",_dsh_moving_ids.size()," fair_slice=",_nav_fair_slice())
		_dsh_visits = 0; _dsh_requests = 0; _dsh_ready = 0; _dsh_wait_max = 0; _dsh_moving_ids.clear()
		_dsh_ms = Time.get_ticks_msec(); _dsh_samples = 0; _dsh_clears = 0; _dsh_admitted = 0; _dsh_dedupe_skips = 0; _dsh_tail_refused = 0; _dsh_rejected_last = _stats.rejected_motion
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
	# DSH_NAVDEDUPE: `a` of the next iteration of this edge is from.lerp(to,
	# float(job.sample+1)/count) after the increment at the bottom of the loop - the same
	# expression with the same operands as this iteration's `b`, i.e. the same Vector3 bit
	# for bit. Inside one synchronous _validate() call nothing can change the answer for
	# that point (see the file header of apply_nav_validate_dedupe.py), so the answer is
	# carried instead of re-asked. The exact `a == dsh_prev_point` test reuses only a
	# literally identical point; everything else calls _admitted() exactly as today.
	var dsh_dedupe := _validate_dedupe_flag()
	# DSH_NAVFAIR: this visit spends at most dsh_slice probes and then returns the job to
	# the queue, where the next PENDING job gets the rest of the same 4000 us bucket. The
	# cursor IS the existing job.edge/job.sample pair, so the probe sequence of a job is
	# exactly today's, only spread over several visits. dsh_slice == 0 (--city-nav-fair=0)
	# leaves both new statements inert and is today's run-to-deadline.
	var dsh_slice: int = _nav_fair_slice()
	var dsh_probes := 0
	_dsh_visits += 1
	# DSH_NAVFAIR: with a slice the carried DSH_NAVDEDUPE point lives on the JOB, so the
	# a == prev b reuse survives a visit boundary (the divisor is call-invariant, so the two
	# points stay bit-identical). At --city-nav-fair=0 these three lines are today's
	# call-local false / ZERO / false exactly.
	var dsh_have_prev: bool = dsh_slice > 0 and bool(job.get("dsh_have_prev", false))
	var dsh_prev_point: Vector3 = Vector3(job.get("dsh_prev_point", Vector3.ZERO)) if dsh_slice > 0 else Vector3.ZERO
	var dsh_prev_ok: bool = dsh_slice > 0 and bool(job.get("dsh_prev_ok", false))
	while job.edge < path.size() and not _queue.expired():
		if bool(job.get("streaming_route", false)) and int(job.edge) > int(job.get("route_desired_edge", 1)): break
		if dsh_slice > 0 and dsh_probes >= dsh_slice: break  # DSH_NAVFAIR: one slice per visit
		dsh_probes += 1
		var from: Vector3 = path[job.edge - 1]; var to: Vector3 = path[job.edge]
		var count := maxi(1, int(ceil(from.distance_to(to) / _validate_metres())))  # DSH_WALKFAST
		var a := from.lerp(to, float(job.sample) / count)
		var b := from.lerp(to, float(job.sample + 1) / count)
		_stats.validated_samples += 1
		_dsh_admitted += 2; _dsh_samples += 1  # DSH_QUERY_PROBE
		# DSH_NAVDEDUPE: same point, same synchronous call - reuse the answer.
		var dsh_ok_a: bool
		if dsh_dedupe == 1 and dsh_have_prev and a == dsh_prev_point:
			dsh_ok_a = dsh_prev_ok
			_dsh_dedupe_skips += 1
		else:
			dsh_ok_a = _admitted(job, a)
		if not dsh_ok_a: _validation_refused(job,"source-admission-refused","source_a",a,b); return
		var dsh_ok_b := _admitted(job, b)
		dsh_prev_point = b; dsh_prev_ok = dsh_ok_b; dsh_have_prev = true
		if not dsh_ok_b: _validation_refused(job,"source-admission-refused","source_b",a,b); return
		if not _physics_clear(a, b, job.exclude, job): _validation_refused(job,"physical-capsule-refused","capsule_sweep",a,b); return
		job.sample += 1
		if job.sample == count: job.edge += 1; job.sample = 0
	# DSH_NAVFAIR: keep the carried DSH_NAVDEDUPE point for the next visit (slice on only).
	if dsh_slice > 0:
		job["dsh_have_prev"] = dsh_have_prev; job["dsh_prev_point"] = dsh_prev_point; job["dsh_prev_ok"] = dsh_prev_ok
	if bool(job.get("streaming_route", false)):
		var verified_edge: int = int(job.edge) - 1
		if verified_edge > int(job.get("route_verified_edge", 0)):
			job["route_verified_edge"] = verified_edge
		if job.status == "PENDING" and verified_edge >= 1:
			job.status = "READY"
			_dsh_ready += 1
			_nav_wait_push(Time.get_ticks_msec() - int(job.created_ms))
		if job.edge == path.size(): job.phase = "COMPLETE"
		if verified_edge >= int(job.get("route_desired_edge", 1)) or job.edge == path.size():
			if bool(job.get("route_prefix_queued", false)): _pending_forget(int(job.id))
			job["route_prefix_queued"] = false
		return
	if job.edge == path.size(): _terminal(job, "READY")


# DSH_ROUND2: the source policy proves STATIC terrain, floors and solid squares. The
# path was already validated sample by sample when it was built, so re-proving the
# same static geometry on every tick is redundant; only the swept capsule test has
# to run every tick because bodies move. Re-ask every N ticks, staggered per job.
func _admit_ttl() -> int:
	if _dsh_ttl < 0:
		# DSH_ADMITTTL: the TTL is counted in PHYSICS FRAMES while admit_motion() runs once
		# per city step times the LOD stride - an effective gap of ~7 frames. A TTL below that
		# period can never reuse for most of the cohort (measured: 9.9% instead of 62% at ttl=8),
		# and the price of one admit call is flat (1052 us), so the bucket is pure call count.
		# 24 covers ~3 periods; --city-admit-ttl=8 restores the accepted value.
		_dsh_ttl = 48  # DSH_TTL48: measured -505 us/step; --city-admit-ttl=24 restores the shorter proof  # DSH_ADMITTTL: accepted default (rollback --city-admit-ttl=8)
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-admit-ttl="):
				_dsh_ttl = maxi(0, int(argument.trim_prefix("--city-admit-ttl=")))
	return _dsh_ttl

# DSH_WALKCHEAP: --city-walk-far-ttl=N. A movement step of a FAR (sim-LOD batched) resident may
# reuse the already proven static source geometry for N physics frames instead of the shared
# _admit_ttl() window. The swept capsule still runs on every step (bodies move), the proof is
# still dropped by version/proposals/geometry invalidation, and N=0 makes a far step use
# _admit_ttl() exactly as today: `ttl = maxi(ttl, _walk_far_ttl())`.
static var _dsh_walk_far_ttl := -1  # DSH_WALKCHEAP

func _walk_far_ttl() -> int:  # DSH_WALKCHEAP
	if _dsh_walk_far_ttl < 0:
		_dsh_walk_far_ttl = 96  # DSH_WALKCHEAP: ~1.6 s at 60 Hz, ~3.4x the accepted DSH_ADMITTTL window
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-walk-far-ttl="):
				_dsh_walk_far_ttl = maxi(0, int(argument.trim_prefix("--city-walk-far-ttl=")))
	return _dsh_walk_far_ttl

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
		_dsh_clear_cache = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-clear-cache="):
				_dsh_clear_cache = maxi(0, int(argument.trim_prefix("--city-clear-cache=")))
	return _dsh_clear_cache

# DSH_NAVDEDUPE: --city-nav-validate-dedupe=1 (default) reuses the admit answer this same
# _validate() call already proved for the identical point; 0 keeps today's two calls per
# sample. Cached like every other lever in this file and read once per _validate() call.
func _validate_dedupe_flag() -> int:
	if _dsh_validate_dedupe < 0:
		_dsh_validate_dedupe = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-nav-validate-dedupe="):
				_dsh_validate_dedupe = maxi(0, int(argument.trim_prefix("--city-nav-validate-dedupe=")))
	return _dsh_validate_dedupe

# DSH_WALKFAST: --city-nav-validate-m=F sets the pre-flight sample spacing. 1.0 (default)
# walks one probe per metre instead of four. The value is clamped to at least SAMPLE_METRES,
# so --city-nav-validate-m=0.25 returns exactly the SAMPLE_METRES constant and the pre-flight
# grid, the swept-capsule pair and every terminal string are then the ones of today. Read
# once per _validate() call, so the divisor is a constant inside the loop and DSH_NAVDEDUPE's
# `a == dsh_prev_point` reuse stays exact at every density.
func _validate_metres() -> float:  # DSH_WALKFAST
	if _dsh_validate_m < 0.0:
		_dsh_validate_m = 0.5  # DSH_VALIDATE05: measured knee - walking x1.8 for +6% step; =1.0 buys +303us more  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-nav-validate-m="):
				_dsh_validate_m = maxf(SAMPLE_METRES, float(argument.trim_prefix("--city-nav-validate-m=")))
	return _dsh_validate_m

# DSH_NAVFAIR: --city-nav-fair-slice=N is how many path probes one _validate() visit may
# spend before it returns the job to the queue (2 by default). --city-nav-fair=0 resolves
# the slice to 0, i.e. today's run-until-the-bucket-expires. The probes themselves, their
# order and the a/b pair inside one probe are untouched: the cursor is the existing
# job.edge/job.sample pair, so a sliced visit resumes exactly where the last one stopped.
func _nav_fair_slice() -> int:  # DSH_NAVFAIR
	if _dsh_nav_fair < 0:
		_dsh_nav_fair = 0  # DSH_NAVFAIROFF: measured -6% wait, no life gain (visits/s x3 but moving_unique 33->26)  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		_dsh_nav_fair_slice = 2
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-nav-fair="):
				_dsh_nav_fair = maxi(0, int(argument.trim_prefix("--city-nav-fair=")))
			elif argument.begins_with("--city-nav-fair-slice="):
				_dsh_nav_fair_slice = maxi(1, int(argument.trim_prefix("--city-nav-fair-slice=")))
	return _dsh_nav_fair_slice if _dsh_nav_fair == 1 else 0

# DSH_NAVFAIR: one integer push per COMPLETED leg (request -> READY). No allocation after
# the first resize; the ring is sorted only when the DSH_NAVQ line is printed.
func _nav_wait_push(wait_ms: int) -> void:  # DSH_NAVFAIR
	if _dsh_wait_ring.size() != 256: _dsh_wait_ring.resize(256)
	if wait_ms < 0: wait_ms = 0
	_dsh_wait_ring[_dsh_wait_cursor] = wait_ms
	_dsh_wait_cursor = (_dsh_wait_cursor + 1) % 256
	if _dsh_wait_filled < 256: _dsh_wait_filled += 1
	if wait_ms > _dsh_wait_max: _dsh_wait_max = wait_ms

# DSH_NAVFAIR: integer percentile of the filled part of the ring (0 when empty).
func _nav_wait_pct(ratio: float) -> int:  # DSH_NAVFAIR
	if _dsh_wait_filled <= 0: return 0
	var dsh_sorted := _dsh_wait_ring.slice(0, _dsh_wait_filled)
	dsh_sorted.sort()
	return int(dsh_sorted[mini(dsh_sorted.size() - 1, int(float(dsh_sorted.size()) * ratio))])

# DSH_NAVTAIL: --city-nav-pump-tail-guard=1 (default) leaves pump()'s walk as soon
# as the 4000 us bucket is spent, instead of running the rest of the list through
# reserve() refusals; 0 keeps today's order (the trailing break only, after a
# successful reserve). Cached like every other lever in this file.
func _pump_tail_flag() -> int:
	if _dsh_pump_tail < 0:
		_dsh_pump_tail = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-nav-pump-tail-guard="):
				_dsh_pump_tail = maxi(0, int(argument.trim_prefix("--city-nav-pump-tail-guard=")))
	return _dsh_pump_tail

# DSH_NAVTAIL: --city-nav-pending-scan=1 (default) walks the maintained _pending_ids
# list - one entry per PENDING job - instead of allocating the `_jobs.values()` copy
# of every job (~284 entries), of which only the PENDING ones can be served at all;
# 0 keeps today's exact walk. Cached like every other lever in this file.
func _pending_scan_flag() -> int:
	if _dsh_pending_scan < 0:
		_dsh_pending_scan = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-nav-pending-scan="):
				_dsh_pending_scan = maxi(0, int(argument.trim_prefix("--city-nav-pending-scan=")))
	return _dsh_pending_scan

# DSH_NAVTAIL: the only door out of _pending_ids. The list is maintained only while
# the pending walk is enabled, so at --city-nav-pending-scan=0 it stays empty and
# this costs one cached flag read. Erasing an id while pump() walks the list would
# shift the entries the walk has not reached yet, so during that walk the id is only
# counted here and _pending_compact() drops it right after the walk returns.
func _pending_forget(id: int) -> void:
	if id <= 0 or _pending_ids.is_empty() or _pending_scan_flag() == 0: return
	if _pending_scan_active:
		_pending_retired += 1
		return
	_pending_ids.erase(id)

# DSH_NAVTAIL: drop every id _pending_forget() retired during the walk, in place and
# without allocating. Every job whose status is no longer PENDING has left the list;
# the compaction keeps _pending_ids ascending by id (the order the walk relies on).
func _pending_compact() -> void:
	_pending_retired = 0
	var write := 0
	for read in _pending_ids.size():
		var dsh_id: int = _pending_ids[read]
		var dsh_job: Dictionary = _jobs.get(dsh_id, {})
		if not dsh_job.is_empty() and (dsh_job.status == "PENDING" or (dsh_job.status == "READY" and bool(dsh_job.get("route_prefix_queued", false)))):
			_pending_ids[write] = dsh_id
			write += 1
	_pending_ids.resize(write)
## The movement controller must call this on each bounded proposed step, even
## after a READY proposal. This neither moves nor teleports an actor.
func admit_motion(id: int, from: Vector3, to: Vector3, far: bool = false) -> bool:  # DSH_WALKCHEAP
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
	# A previous admission includes live access, route-cookie and floor checks.
	# Without a complete invalidation contract it cannot grant another motion.
	# Keep the legacy TTL options inert; every real step asks the current source.
	var dsh_a0 := Time.get_ticks_usec() if _dsh_split_on else 0
	allowed = _admitted(job, to)
	job["last_motion_stage"]="source_admitted" if allowed else "source_refused"
	if _dsh_split_on:
		_dsh_t["admit_calls"] = int(_dsh_t["admit_calls"]) + 1
		_dsh_t_add("admit_us", dsh_a0)
	job["last_motion_frame"]=Engine.get_physics_frames()
	job["last_motion_from"]=from; job["last_motion_to"]=to
	job.erase("admit_ok"); job.erase("admit_due")
	if allowed:
		var dsh_c1 := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
		var dsh_pre_shape := int(_dsh_t["clear_shape_us"]) if _dsh_split_on else 0  # DSH_NAVSTEP3
		var dsh_pre_cast := int(_dsh_t["clear_cast_us"]) if _dsh_split_on else 0  # DSH_NAVSTEP3
		allowed = _physics_clear(from, to, job.exclude, job)
		job["last_motion_stage"]="admitted" if allowed else "capsule_refused"
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
	# DSH_NAVFAIR: one distinct job whose REAL motion was admitted = one unique moving
	# resident in this window (one live job per resident). Cleared once per DSH_NAVQ line.
	if allowed: _dsh_moving_ids[id] = true
	return allowed

func diagnostics() -> Dictionary:
	var result := _stats.duplicate(true)
	result["validation_refusals"]=_validation_refusals.duplicate(true)
	result["components"]=_component_stats.duplicate(true)
	result["ready_proof"]={"enabled":_ready_budget_enabled(),"cursor":_ready_proof_cursor,"mesh_count":_meshes.size(),"slice_us_max":_ready_proof_us_max,"checks":_ready_proof_checks,"resets":_ready_proof_resets,"slice_budget_us":READY_PROOF_SLICE_US}
	result.merge({"state":state(),"epoch":_epoch,"jobs":_jobs.size(),"bakes_inflight":1 if _baking_token!=0 else 0,"queued_snapshots":0 if _build.is_empty() else 1,"map_iteration":_last_iteration,"nav_polygons":_tile_stats.polygons,"tiles":_tile_stats.duplicate(true),"regions":_regions.size(),"cache_tiles":_tile_cache.size(),"proposal_only":true})
	return result

func dispose() -> void:
	if not Thread.is_main_thread(): return
	if _busy: _mutation_fault = true; return
	if _disposed: return
	for id: int in _jobs.keys(): cancel(id)
	_disposed = true; _epoch += 1; _waiting = {}; _state = "DISPOSED"
	_free_map(); _space = Callable(); _build={}; _tile_cache.clear(); _components={}


# A completed bake does not yet prove publication in the asynchronous map.
# Keep every original region/closest-owner/distance predicate, but spend one
# bounded slice per physics frame. Partial proof never exposes the map.
var _ready_budget_flag := -1
var _ready_proof_map := RID()
var _ready_proof_epoch := -1
var _ready_proof_iteration := -1
var _ready_proof_cursor := 0
var _ready_proof_frame := -1
var _ready_proof_us_max := 0
var _ready_proof_checks := 0
var _ready_proof_resets := 0
const READY_PROOF_SLICE_US := 4000

func _ready_budget_enabled() -> bool:
	if _ready_budget_flag<0:
		_ready_budget_flag=1
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--city-ready-budget="):
				_ready_budget_flag=1 if arg.trim_prefix("--city-ready-budget=")=="1" else 0
	return _ready_budget_flag==1

func _reset_ready_proof() -> void:
	_ready_proof_map=RID(); _ready_proof_epoch=-1; _ready_proof_iteration=-1
	_ready_proof_cursor=0; _ready_proof_frame=-1

func _bounded_map_ready() -> String:
	var frame:=Engine.get_physics_frames()
	if frame==_ready_proof_frame: return _state
	_ready_proof_frame=frame
	var started:=Time.get_ticks_usec()
	var iteration:=NavigationServer3D.map_get_iteration_id(_map)
	if iteration<=0: return _state
	if _ready_proof_map!=_map or _ready_proof_epoch!=_epoch or _ready_proof_iteration!=iteration:
		_ready_proof_map=_map; _ready_proof_epoch=_epoch; _ready_proof_iteration=iteration
		_ready_proof_cursor=0; _ready_proof_resets+=1
	for region: RID in _regions:
		if NavigationServer3D.region_get_iteration_id(region)<=0 or NavigationServer3D.region_get_bounds(region).size.length_squared()<=0.0:
			_ready_proof_cursor=0; return _state
	while _ready_proof_cursor<_meshes.size():
		if Time.get_ticks_usec()-started>=READY_PROOF_SLICE_US: break
		var mesh: NavigationMesh=_meshes[_ready_proof_cursor]
		if mesh.get_polygon_count()>0:
			var point: Vector3=mesh.get_vertices()[0]
			_ready_proof_checks+=1
			if not NavigationServer3D.map_get_closest_point_owner(_map,point) in _regions or NavigationServer3D.map_get_closest_point(_map,point).distance_to(point)>CELL_SIZE:
				_ready_proof_cursor=0
				_ready_proof_us_max=maxi(_ready_proof_us_max,Time.get_ticks_usec()-started)
				return _state
		_ready_proof_cursor+=1
	_ready_proof_us_max=maxi(_ready_proof_us_max,Time.get_ticks_usec()-started)
	# No callback occurs inside a slice. The final fresh iteration prevents
	# joining evidence from different asynchronous map publications.
	if NavigationServer3D.map_get_iteration_id(_map)!=iteration:
		_ready_proof_cursor=0; _ready_proof_iteration=-1; return _state
	if _ready_proof_cursor==_meshes.size():
		_last_iteration=iteration; _state="READY"
		if _native_zero_enabled(): _native_zero_commit_ready(iteration)
	return _state

func _validate_static_corridor(job: Dictionary) -> void:
	if job.iteration!=_map_iteration():_terminal(job,"STALE","map-iteration-changed");return
	var path: PackedVector3Array=job.path
	while job.edge<path.size() and int(job.edge)<=int(job.route_desired_edge) and not _queue.expired():
		var a: Vector3=path[job.edge-1];var b: Vector3=path[job.edge]
		var started:=Time.get_ticks_usec()
		var proof: Variant=job.static_corridor.call(a,b,job.source_id,job.life_generation,int(job.edge),_validate_metres())
		if not proof is Dictionary or not proof.get("ok",false) or proof.get("source_id")!=job.source_id or proof.get("life_generation")!=job.life_generation or proof.get("map")!=_map or proof.get("iteration")!=job.iteration or not proof.get("exclude") is Array:
			_validation_refused(job,"static-corridor-refused","corridor",a,b);return
		var exclusions: Array[RID]=[]
		if proof.exclude.size()>128:_validation_refused(job,"static-corridor-exclusion-overflow","corridor",a,b);return
		for rid: Variant in proof.exclude:
			if not rid is RID or not rid.is_valid():_validation_refused(job,"invalid-static-corridor-exclusion","corridor",a,b);return
			exclusions.append(rid)
		if not _owner_valid(job) or job.epoch!=_epoch or job.iteration!=_map_iteration():_terminal(job,"STALE","corridor-authority-changed");return
		if not _physics_clear(a,b,exclusions):_validation_refused(job,"static-corridor-capsule-refused","capsule_sweep",a,b);return
		if _mutation_fault or not _owner_valid(job) or job.epoch!=_epoch or job.iteration!=_map_iteration():_terminal(job,"STALE","corridor-authority-changed");return
		var spent:=Time.get_ticks_usec()-started
		_stats["corridor_edges"]=int(_stats.get("corridor_edges",0))+1
		_stats["corridor_us_total"]=int(_stats.get("corridor_us_total",0))+spent
		_stats["corridor_us_max"]=maxi(int(_stats.get("corridor_us_max",0)),spent)
		job.edge+=1;job.sample=0
		job.route_verified_edge=int(job.edge)-1
	if job.status=="PENDING" and int(job.route_verified_edge)>=1:
		job.status="READY";_dsh_ready+=1;_nav_wait_push(Time.get_ticks_msec()-int(job.created_ms))
	if job.edge==path.size():job.phase="COMPLETE"
	if int(job.route_verified_edge)>=int(job.route_desired_edge) or job.edge==path.size():
		if bool(job.route_prefix_queued):_pending_forget(int(job.id))
		job.route_prefix_queued=false


# INITIAL admission zero-distance membership accelerator. Default OFF. Every
# refused/uncertain case returns false so the caller uses its original map query.
# This API never grants a route/cookie and never memoizes physical or owner proof.
const NATIVE_ZERO_GRID_METRES: float=96.0
const NATIVE_ZERO_MAX_REGIONS: int=256
const NATIVE_ZERO_MAX_CANDIDATES: int=4
const NATIVE_ZERO_MAX_REFERENCES: int=4096
const NATIVE_ZERO_INDEX_BUDGET_US: int=2000
var _native_zero_flag: int=-1
var _native_zero_birth: Dictionary={}
var _native_zero_certificate: Dictionary={}
var _native_zero_index_stats: Dictionary={"attempts":0,"committed":0,"refused":0,"build_us":0,"build_us_max":0,"last_reason":"","references":0}

func _native_zero_enabled() -> bool:
	if _native_zero_flag<0:
		_native_zero_flag=1 # Certified native birth/query + matched default286 PASS.
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--city-initial-admission-budget="):
				_native_zero_flag=1 if argument.trim_prefix("--city-initial-admission-budget=")=="1" else 0
	return _native_zero_flag==1

func _native_zero_reset() -> void:
	_native_zero_birth={};_native_zero_certificate={}
	_native_zero_index_stats.references=0

func _native_zero_record_birth() -> void:
	# Called ONLY by _activate_tiles directly after freshly creating all regions.
	# Async false was intentionally QUEUED before their mesh/map setters, all in
	# this same main-thread call. No immediate native getter proves application.
	_native_zero_birth={"map":_map,"epoch":_epoch,"regions":_regions.duplicate(),"queued_async_false":true,"expected_first_iteration":1}
	_native_zero_certificate={}

func _native_zero_birth_current(map: RID) -> bool:
	return not _native_zero_birth.is_empty() and bool(_native_zero_birth.queued_async_false) and map==_map and map==_native_zero_birth.map and _epoch==int(_native_zero_birth.epoch) and _regions==_native_zero_birth.regions

func _native_zero_region_current(region: RID, map: RID, bounds: AABB) -> bool:
	return region.is_valid() and not NavigationServer3D.region_get_use_async_iterations(region) and NavigationServer3D.region_get_iteration_id(region)==1 and NavigationServer3D.region_get_map(region)==map and NavigationServer3D.region_get_transform(region)==Transform3D.IDENTITY and NavigationServer3D.region_get_enabled(region) and NavigationServer3D.region_get_navigation_layers(region)==1 and NavigationServer3D.region_get_bounds(region)==bounds

func _native_zero_index_result(started: int, reason: String, certificate: Dictionary={}) -> void:
	var elapsed: int=Time.get_ticks_usec()-started
	_native_zero_index_stats.build_us+=elapsed
	_native_zero_index_stats.build_us_max=maxi(int(_native_zero_index_stats.build_us_max),elapsed)
	_native_zero_index_stats.last_reason=reason
	if certificate.is_empty():
		_native_zero_index_stats.refused+=1;_native_zero_certificate={};_native_zero_index_stats.references=0
	else:
		_native_zero_index_stats.committed+=1;_native_zero_certificate=certificate
		_native_zero_index_stats.references=int(certificate.references)

func _native_zero_commit_ready(iteration: int) -> void:
	# Runs only AFTER all original region/mesh-owner/distance READY proofs passed.
	# Cold construction cost belongs to this transition and is explicitly counted.
	var started: int=Time.get_ticks_usec()
	_native_zero_index_stats.attempts+=1
	if not Thread.is_main_thread() or _disposed or _busy or not _version_ok or _state!="READY" or iteration<=0 or not _native_zero_birth_current(_map) or NavigationServer3D.map_get_iteration_id(_map)!=iteration:
		_native_zero_index_result(started,"birth_or_current_ready_required");return
	if _regions.is_empty() or _regions.size()>NATIVE_ZERO_MAX_REGIONS:
		_native_zero_index_result(started,"region_count_bound");return
	var cells: Dictionary={};var references: int=0
	for region: RID in _native_zero_birth.regions:
		if Time.get_ticks_usec()-started>=NATIVE_ZERO_INDEX_BUDGET_US:
			_native_zero_index_result(started,"cold_index_budget");return
		var bounds: AABB=NavigationServer3D.region_get_bounds(region)
		if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x<=0.0 or bounds.size.z<=0.0 or not _native_zero_region_current(region,_map,bounds):
			_native_zero_index_result(started,"fresh_sync_birth_region_required");return
		var x0: int=int(floor(bounds.position.x/NATIVE_ZERO_GRID_METRES));var x1: int=int(floor(bounds.end.x/NATIVE_ZERO_GRID_METRES))
		var z0: int=int(floor(bounds.position.z/NATIVE_ZERO_GRID_METRES));var z1: int=int(floor(bounds.end.z/NATIVE_ZERO_GRID_METRES))
		if (x1-x0+1)*(z1-z0+1)>16:
			_native_zero_index_result(started,"single_region_index_domain");return
		var descriptor: Dictionary={"region":region,"bounds":bounds}
		for z in range(z0,z1+1):
			for x in range(x0,x1+1):
				references+=1
				if references>NATIVE_ZERO_MAX_REFERENCES:
					_native_zero_index_result(started,"index_reference_bound");return
				var key: Vector2i=Vector2i(x,z)
				if not cells.has(key):cells[key]=[]
				cells[key].append(descriptor)
	if Time.get_ticks_usec()-started>=NATIVE_ZERO_INDEX_BUDGET_US or not _native_zero_birth_current(_map) or NavigationServer3D.map_get_iteration_id(_map)!=iteration:
		_native_zero_index_result(started,"index_budget_or_epoch_changed");return
	_native_zero_index_result(started,"",{"map":_map,"epoch":_epoch,"iteration":iteration,"regions":_native_zero_birth.regions.duplicate(),"cells":cells,"references":references,"observed_all_async_false":true,"observed_all_first_iteration":1})

func native_published_point_zero(map: RID, iteration: int, point: Vector3) -> bool:
	# Pure bool query: no index construction, cache insertion, actor/goal/route
	# writes or diagnostic counter writes occur here. Point0 stays with its caller.
	if not Thread.is_main_thread() or not _native_zero_enabled() or _disposed or _busy or not _version_ok or _state!="READY" or not point.is_finite() or point.length_squared()>1e10 or point==Vector3.ZERO or not map.is_valid() or _native_zero_certificate.is_empty():return false
	if not _native_zero_birth_current(map) or map!=_native_zero_certificate.map or _epoch!=int(_native_zero_certificate.epoch) or iteration!=int(_native_zero_certificate.iteration) or _regions!=_native_zero_certificate.regions or NavigationServer3D.map_get_iteration_id(map)!=iteration:return false
	var key: Vector2i=Vector2i(int(floor(point.x/NATIVE_ZERO_GRID_METRES)),int(floor(point.z/NATIVE_ZERO_GRID_METRES)))
	var candidates: Array=_native_zero_certificate.cells.get(key,[])
	if candidates.is_empty() or candidates.size()>NATIVE_ZERO_MAX_CANDIDATES:return false
	for descriptor: Dictionary in candidates:
		var bounds: AABB=descriptor.bounds
		if point.x<bounds.position.x or point.x>bounds.end.x or point.z<bounds.position.z or point.z>bounds.end.z:continue
		var region: RID=descriptor.region
		if not _native_zero_region_current(region,map,bounds):continue
		var closest: Vector3=NavigationServer3D.region_get_closest_point(region,point)
		if closest!=point:continue
		# Region sync is main-thread; no callbacks/await can mutate publication in
		# this query. Fresh final map/region proof still refuses any changed scope.
		if NavigationServer3D.map_get_iteration_id(map)==iteration and _native_zero_birth_current(map) and _native_zero_region_current(region,map,bounds):return true
	return false

func snapshot_native_published_zero() -> Dictionary:
	# Construction metrics only, not per-query hits or current physical proof.
	return {"enabled":_native_zero_enabled(),"birth_recorded":not _native_zero_birth.is_empty(),"birth_regions":_native_zero_birth.get("regions",[]).size(),"certificate_ready":not _native_zero_certificate.is_empty(),"certificate_map_id":str(_native_zero_certificate.map.get_id()) if not _native_zero_certificate.is_empty() else "","certificate_iteration":_native_zero_certificate.get("iteration",0),"epoch":_epoch,"index_stats":_native_zero_index_stats.duplicate(),"index_budget_us":NATIVE_ZERO_INDEX_BUDGET_US,"max_candidates":NATIVE_ZERO_MAX_CANDIDATES,"construction_observed_all_async_false":_native_zero_certificate.get("observed_all_async_false",false),"construction_observed_first_iteration":_native_zero_certificate.get("observed_all_first_iteration",0),"point0_caller_must_use_original":true,"actor_or_goal_writes":0,"token_or_physics_memo":false}
