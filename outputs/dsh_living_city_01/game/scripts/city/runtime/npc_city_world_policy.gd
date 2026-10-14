extends RefCounted
## NEW LOCAL ERRAND CROSSING. Ordinary roam retains its old road ban.
## Exact pinned city/session inputs, current daily claim and native path bound road rights.
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const Contact = preload("../../transport/npc_contact_sweep.gd")
const CITY_PACKET_SHA := "b9c810e81b8b3da6afc048a32c4fe50745f32e4b15d0fd55ff876e69c35c54a1"
const CITY_BLOCK_SHA := "38b4b50ca06fb60172173b04c5b49ff567a84509ea01901a24306ab0d3b41dc7"
const PACKET_SHA := "e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096"
const BLOCK_SHA := "1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e"
const SESSION := "godot-preview-new-session-20260927-01"
const RADIUS := .738
const DoorOpen = preload("res://scripts/city/runtime/npc_city_door_open.gd")  # DSH_DOORFREE
const ORIGIN := Vector3(395.65, 0, 45.1)
const OFFSETS := [Vector2.ZERO, Vector2(-RADIUS, -RADIUS), Vector2(-RADIUS, RADIUS), Vector2(RADIUS, -RADIUS), Vector2(RADIUS, RADIUS)]
# DSH_NAVSTEP2: the exact same five double-precision offset pairs the proof already
# used, held once instead of rebuilt as an Array of five Arrays per sampled point.
const POINT_OFFSETS := [[0.0,0.0],[-RADIUS,-RADIUS],[-RADIUS,RADIUS],[RADIUS,-RADIUS],[RADIUS,RADIUS]]
# DSH_NAVSTEP3: shared empty placeholder for callers that pass no within-call memo, so
# the default path allocates nothing and never writes a memo it did not create.
const NO_MEMO: Array = []
var _scene: WeakRef
var _owners := {}
var _states := {}
var _version := -1
# Base terrain is not a movement grant; local authored entry owners combine it
# with their own complete source/native proof. Ordinary roam uses _ordinary.
var _land := PackedByteArray()
var _ordinary := PackedByteArray()
var _surface := {}
var _rows := 0
var _cols := 0
var _start_r := 0
var _start_c := 0
var _host: WeakRef
var _paths := {}
var _detour_suffix_reuses := 0
var _detour_suffix_points := 0
var _cookie := 0
var _contact := Contact.new()
var _box := BoxShape3D.new()
var _free_capsule_calls := 0  # DSH_DOORFREE
var _query := PhysicsShapeQueryParameters3D.new()
var _last_reason := ""
var _counts := {"source_calls":0,"native_calls":0,"floor_rays":0,"polygon_contacts":0}
var _dsh_ms := 0  # DSH_QUERY_PROBE
var _dsh_last := {}  # DSH_QUERY_PROBE
# DSH_NAVSTEP2: optional cost levers, parsed once from OS.get_cmdline_user_args().
# --city-policy-slim=0 and --city-policy-proof-ttl=0 (defaults) keep today's proof.
var _dsh_slim := -1
var _dsh_proof_ttl := -1
var _dsh_proof := {}
# DSH_NAVSTEP3: --city-navsplit=0 (default) reads no clock and touches no counter.
# --city-policy-token-memo=0 explicitly restores repeated fresh host proofs.
var _dsh_split := -1
var _dsh_split_on := false
var _dsh_split_capture := false # Diagnostic logger suppression only.
var _dsh_memo := -1
var _dsh_memo_hits := 0
var _dsh_p_ms := 0
var _dsh_p := {"calls": 0, "owner_us": 0, "road_us": 0, "daily_us": 0, "path_us": 0, "seg_us": 0, "floor_us": 0, "native_us": 0, "chain_us": 0, "tc_calls": 0, "tc_us": 0, "token_empty": 0, "prove_fail": 0, "guard_refuse": 0}

var _heights := PackedFloat64Array()
var _cells: Array = []
var _floors := {}
# The authored Palazzo dry plate overlaps existing source terrain at y=0.
# It grants no NPC land. Only an exact, current duplicate may be excluded from
# support rays, which must still find an unchanged pinned source floor below.
const DUPLICATE_SUPPORT_SIZE := Vector3(16.4, .16, 127.1)
const DUPLICATE_SUPPORT_FRAME := Transform3D(Basis.IDENTITY, Vector3(51.25, -.08, 18.45))
var _duplicate_support := {}
var _ray := PhysicsRayQueryParameters3D.new()
var _disposed := false
var _busy := false
# INITIAL_ADMISSION: global per-physics-frame budget, never one budget per actor.
const INITIAL_ADMISSION_BUDGET_US := 4000
# The measured R1 charged 4ms to every catch-up physics tick. Bound the complete
# consumer across all policies/ticks in the same process frame as well.
const INITIAL_ADMISSION_PROCESS_BUDGET_US := 2500
const INITIAL_ADMISSION_LIMIT := 512
const INITIAL_ADMISSION_NO_PROGRESS_US := 10000000
const INITIAL_ADMISSION_RESULT_RETENTION_US := 30000000
const INITIAL_ADMISSION_CHUNK_POINTS := 4
static var _initial_budget_frame := -1
static var _initial_budget_used_us := 0
static var _initial_budget_calls := 0
static var _initial_budget_max_us := 0
static var _initial_process_budget_frame := -1
static var _initial_process_budget_used_us := 0
static var _initial_process_budget_calls := 0
static var _initial_process_budget_max_us := 0
static var _initial_process_budget_skips := 0
var _initial_flag := -1
var _initial_jobs := {}
var _initial_queue: Array[int] = []
var _initial_gc: Array[int] = []
var _initial_serial := 0
var _initial_pump: Node
var _initial_pumping := false
var _initial_stats := {"created":0,"completed":0,"cancelled":0,"expired":0,"points":0,"last_frame":-1,"last_frame_us":0,"last_points":0,"atomic_step_max_us":0,"guard_max_us":0,"max_wait_us":0,"total_wait_us":0,"queue_peak":0,"completed_ok":0,"completed_refused":0,"pending_no_progress_timeouts":0,"consumed_ok":0,"consumed_refused":0,"cancelled_pending":0,"cancelled_done":0,"requester_gc_pending":0,"requester_gc_done":0,"result_gc_ok":0,"result_gc_refused":0,"disposed_jobs":0}

class InitialAdmissionPump extends Node:
	var policy: WeakRef
	func _physics_process(_delta: float) -> void:
		var current: RefCounted=policy.get_ref() if policy!=null else null
		if is_instance_valid(current): current.pump_initial_path_admissions()
		else: queue_free()

func configure(scene: Node3D, packet_rows: Array, owners: Dictionary, trust: Dictionary, access: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _scene != null: return {"ok": false, "error": "lifetime"}
	if not is_instance_valid(scene) or not scene.is_inside_tree() or not scene.global_transform.is_equal_approx(Transform3D.IDENTITY): return {"ok": false, "error": "scene"}
	if not trust.get("accepted") is bool or not trust.accepted or trust.get("packet_sha256") not in [PACKET_SHA,CITY_PACKET_SHA] or trust.get("block_sha256") not in [BLOCK_SHA,CITY_BLOCK_SHA] or trust.get("session_id") != SESSION: return {"ok": false, "error": "accepted_source_required"}
	var packet_sha: String=trust.packet_sha256
	if packet_sha==CITY_PACKET_SHA and trust.block_sha256!=CITY_BLOCK_SHA: return {"ok":false,"error":"city_packet_requires_city_block"}
	var bytes := FileAccess.get_file_as_bytes(str(trust.get("packet_path","res://assets/npc_visual/session/"+packet_sha+".json")))
	if Loader._hash(bytes) != packet_sha: return {"ok": false, "error": "packet_bytes"}
	var packet: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	if packet_rows != packet.rows or owners.size() != packet.rows.size(): return {"ok": false, "error": "exact_rows_required"}
	var source_bytes := FileAccess.get_file_as_bytes(str(scene.get("block_data_path")))
	if Loader._hash(source_bytes) != trust.block_sha256: return {"ok": false, "error": "source_block_bytes"}
	var block: Dictionary = JSON.parse_string(source_bytes.get_string_from_utf8())
	if scene.get("_block") != block or scene.get("_origin") != ORIGIN: return {"ok": false, "error": "current_block"}
	var checked := {}
	for row: Dictionary in packet_rows:
		var owner: Variant = owners.get(row.source_id)
		if not owner is Queue.Owner or owner.dead or owner.source_id != row.source_id or owner.life_generation != 1: return {"ok": false, "error": "owner_identity"}
		checked[row.source_id] = {"owner": owner, "dead_seen": false}
	var states: Variant = access.get("states")
	var version: Variant = access.get("version")
	if not version is int or version < 1 or not _valid_states(states, checked): return {"ok": false, "error": "access_snapshot"}
	var surface: Dictionary = block.surface
	if surface.cellSize!=4.1 or int(surface.rows)<1 or int(surface.cols)<1 or int(surface.rows)*int(surface.cols)>40000: return {"ok":false,"error":"bounded_source_surface"}
	_surface=surface;_rows=int(surface.rows);_cols=int(surface.cols);_start_r=int(surface.startRow);_start_c=int(surface.startCol)
	_land.resize(_rows*_cols);_ordinary.resize(_land.size());_heights.resize(_land.size());_cells.resize(_land.size())
	for i in _cells.size(): _cells[i]=[]
	for r in _rows:
		for c in _cols:
			var index:=r*_cols+c;var tile:=int(surface.grid[r][c]);var palette: Dictionary=surface.palette[str(tile)]
			var police: Variant=surface.masks.policeMask[r][c]
			var native_land: bool=bool(surface.masks.walkableMask[r][c]) or (tile==9 and (police is int or police is float) and police==1)
			var road: bool=bool(surface.masks.roadMask[r][c])
			var boundary: bool=r+_start_r>=1 and r+_start_r<int(surface.sourceMapRows)-1 and c+_start_c>=1 and c+_start_c<int(surface.sourceMapCols)-1
			_land[index]=int(boundary and (native_land or road) and tile!=16 and bool(palette.solid))
			_ordinary[index]=int(_land[index]!=0 and native_land and not road)
			_heights[index]=float(palette.heightM)
	# Retain the accepted exterior-only building envelopes, including their
	# authored public-approach gaps. Opening an interior door does not grant new
	# visitation permission. A later interior source provider needs a new scope.
	var solid_id:=0
	# DSH_CITYTOWN: a building that the scene left out must not keep its exterior
	# envelope in _cells, or its freed footprint stays blocked for every resident
	# probe. With the flag off the callable is absent and this is the same walk.
	var dsh_town_skip: Callable = Callable()
	if scene.has_method("city_town_skip"): dsh_town_skip = Callable(scene, "city_town_skip")
	for building: Dictionary in block.buildings:
		if dsh_town_skip.is_valid() and bool(dsh_town_skip.call(building)): continue
		for body: Dictionary in building.collisionBodiesM:
			var polygon := PackedVector2Array()
			var bounds := Rect2()
			for value: Array in body.polygonXZ:
				var point := Vector2(value[0], value[1]); polygon.append(point)
				bounds = Rect2(point, Vector2.ZERO) if polygon.size() == 1 else bounds.expand(point)
			var source_polygon: Array=[]
			for pair: Array in body.polygonXZ: source_polygon.append([(float(pair[0])+395.65)/4.1,(float(pair[1])+45.099999999999994)/4.1])
			var record := {"id":solid_id,"polygon": polygon,"source_polygon":source_polygon,"min_y":float(body.minY),"max_y":float(body.maxY), "bounds": bounds.grow(.00001)}
			solid_id+=1
			var first_c := maxi(0, int(floor((bounds.position.x + ORIGIN.x) / 4.1)) - _start_c)
			var last_c := mini(_cols-1, int(floor((bounds.end.x + ORIGIN.x) / 4.1)) - _start_c)
			var first_r := maxi(0, int(floor((bounds.position.y + ORIGIN.z) / 4.1))-_start_r)
			var last_r := mini(_rows-1, int(floor((bounds.end.y + ORIGIN.z) / 4.1))-_start_r)
			for r in range(first_r, last_r + 1):
				for c in range(first_c, last_c + 1): _cells[r * _cols + c].append(record)
	_scene = weakref(scene)
	if not _capture_floors(scene, surface): _scene = null; _land.clear(); _cells.clear(); _heights.clear(); _floors.clear(); return {"ok": false, "error": "source_floor_identity"}
	_capture_duplicate_support(scene)
	_owners = checked; _states = states.duplicate(); _version = version
	_ray.collision_mask = 1
	_box.size=Vector3(RADIUS*2.0,1.9,RADIUS*2.0);_query.shape=_box;_query.collision_mask=1|256;_query.margin=.001
	scene.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)
	return {"ok": true, "version": _version, "owners": _owners.size(), "source_floors": _floors.size()}

# DSH_NAVSTEP2: --city-policy-slim=1 enables the shared-offset / deduplicated proof.
# 0 (default) keeps today's code path.
var _dsh_policy_leg_cache := -1.0  # DSH_POLICYLEG

# DSH_POLICYLEG: --city-policy-leg-m=N is the longest single route leg this policy will
# prove. 5.1 m is the source value: one 4.1 m cell plus margin, and exactly what the
# daily walk's own 5 m leg was built for. Raising it is an experiment, never a default:
# every proof below (per-cell buckets, per-tick segments) is unchanged.
func _dsh_leg_bound() -> float:  # DSH_POLICYLEG
	if _dsh_policy_leg_cache < 0.0:
		_dsh_policy_leg_cache = 5.1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-policy-leg-m="):
				_dsh_policy_leg_cache = clampf(float(argument.trim_prefix("--city-policy-leg-m=")), 1.0, 60.0)
	return _dsh_policy_leg_cache

func _slim_flag() -> int:
	if _dsh_slim < 0:
		_dsh_slim = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-policy-slim="):
				_dsh_slim = maxi(0, int(argument.trim_prefix("--city-policy-slim=")))
	return _dsh_slim

# DSH_NAVSTEP2: --city-policy-proof-ttl=N physics frames of reuse for a TRUE static
# proof. 0 (default) re-proves every call.
func _proof_ttl() -> int:
	if _dsh_proof_ttl < 0:
		_dsh_proof_ttl = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-policy-proof-ttl="):
				_dsh_proof_ttl = maxi(0, int(argument.trim_prefix("--city-policy-proof-ttl=")))
	return _dsh_proof_ttl

# DSH_NAVSTEP3: --city-navsplit=1 only observes; 0 (default) reads no clock.
func _split_flags() -> void:
	_dsh_split = 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--city-navsplit="):
			_dsh_split = maxi(0, int(argument.trim_prefix("--city-navsplit=")))
	_dsh_split_on = _dsh_split == 1

# One fresh owner/rig/capsule proof per synchronous pinned cookie/source call.
# The local Array is consumed and cleared before returning; actual floor/source/
# sweep checks stay fresh. Enabled by default; --city-policy-token-memo=0 restores repeated proofs.
func _memo_flag() -> int:
	if _dsh_memo < 0:
		_dsh_memo = 1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-policy-token-memo="):
				_dsh_memo = maxi(0, int(argument.trim_prefix("--city-policy-token-memo=")))
	return _dsh_memo

func _dsh_add(key: String, started: int) -> void:  # DSH_NAVSTEP3
	_dsh_p[key] = int(_dsh_p[key]) + Time.get_ticks_usec() - started

func _dsh_report() -> void:  # DSH_NAVSTEP3
	if _dsh_split_capture: return
	var now := Time.get_ticks_msec()
	if _dsh_p_ms == 0 or now <= _dsh_p_ms:
		_dsh_p_ms = now; _dsh_p = {"calls": 0, "owner_us": 0, "road_us": 0, "daily_us": 0, "path_us": 0, "seg_us": 0, "floor_us": 0, "native_us": 0, "chain_us": 0, "tc_calls": 0, "tc_us": 0, "token_empty": 0, "prove_fail": 0, "guard_refuse": 0}
		return
	var dt := float(now - _dsh_p_ms) / 1000.0
	var calls := maxi(1, int(_dsh_p["calls"]))
	print("DSH_NAVSTEP3POL dt=", "%.2f" % dt, " calls/s=", int(_dsh_p["calls"]),
		" us/call: owner=", int(_dsh_p["owner_us"]) / calls, " road=", int(_dsh_p["road_us"]) / calls,
		" daily=", int(_dsh_p["daily_us"]) / calls, " path=", int(_dsh_p["path_us"]) / calls,
		" seg=", int(_dsh_p["seg_us"]) / calls, " floor=", int(_dsh_p["floor_us"]) / calls,
		" native=", int(_dsh_p["native_us"]) / calls, " chain=", int(_dsh_p["chain_us"]) / calls,
		" | token_current calls/s=", int(_dsh_p["tc_calls"]), " us/call=", int(_dsh_p["tc_us"]) / maxi(1, int(_dsh_p["tc_calls"])),
		" memo_hits/s=", _dsh_memo_hits, " token_empty/s=", int(_dsh_p["token_empty"]),
		" prove_fail/s=", int(_dsh_p["prove_fail"]), " guard_refuse/s=", int(_dsh_p["guard_refuse"]),
		" | 1s=", _dsh_p)
	_dsh_p_ms = now
	_dsh_memo_hits = 0
	_dsh_p = {"calls": 0, "owner_us": 0, "road_us": 0, "daily_us": 0, "path_us": 0, "seg_us": 0, "floor_us": 0, "native_us": 0, "chain_us": 0, "tc_calls": 0, "tc_us": 0, "token_empty": 0, "prove_fail": 0, "guard_refuse": 0}

func _floor_key(size: Vector3, position: Vector3) -> String:
	return PackedVector3Array([size, position]).to_byte_array().hex_encode()

func _capture_floors(scene: Node3D, surface: Dictionary) -> bool:
	var expected := {}
	for r in _rows:
		var c := 0
		while c < _cols:
			var tile := str(int(surface.grid[r][c])); var palette: Dictionary = surface.palette[tile]
			if not palette.solid: c += 1; continue
			var first := c
			while c < _cols and str(int(surface.grid[r][c])) == tile: c += 1
			var size := Vector3((c - first) * 4.1, .16, 4.1)
			var position := Vector3((_start_c + (first + c) * .5) * 4.1 - ORIGIN.x, float(palette.heightM) - .08, (_start_r + r + .5) * 4.1 - ORIGIN.z)
			expected[_floor_key(size, position)] = true
	var seen := {}
	for node: Node in scene.get_children():
		if not node is StaticBody3D or node.get_child_count() != 1: continue
		var shape: Node = node.get_child(0)
		if not shape is CollisionShape3D or not shape.shape is BoxShape3D: continue
		var key := _floor_key(shape.shape.size, node.global_position)
		if not expected.has(key): continue
		if seen.has(key) or shape.disabled or node.collision_layer != 1 or not node.global_basis.is_equal_approx(Basis.IDENTITY) or not shape.transform.is_equal_approx(Transform3D.IDENTITY): return false
		seen[key] = true
		_floors[node.get_rid()] = {"body": weakref(node), "shape": weakref(shape), "frame": node.global_transform, "size": shape.shape.size}
	return seen.size() == expected.size()

func _duplicate_support_geometry(scene: Node3D, root: Variant, body: Variant, shape: Variant) -> bool:
	if not is_instance_valid(root) or not root is Node3D or not is_instance_valid(body) or not body is StaticBody3D or not is_instance_valid(shape) or not shape is CollisionShape3D: return false
	if root.is_queued_for_deletion() or body.is_queued_for_deletion() or shape.is_queued_for_deletion(): return false
	if root.get_parent()!=scene or root.name!=&"PalazzoGroundExtension" or root.global_transform!=Transform3D.IDENTITY or root.get_script()!=null: return false
	if root.get_meta("palazzo_ground_extension",false)!=true or root.get_meta("navigation_policy","")!="outside_unchanged_source_crop_no_npc_entry": return false
	if body.get_parent()!=root or body.name!=&"DryGround" or body.get_script()!=null or body.global_transform!=DUPLICATE_SUPPORT_FRAME or body.collision_layer!=1 or body.collision_mask!=1: return false
	if body.get_child_count()!=2 or body.get_child(0)!=shape or body.get_shape_owners().size()!=1: return false
	if shape.get_parent()!=body or shape.get_script()!=null or shape.disabled or shape.transform!=Transform3D.IDENTITY or not shape.shape is BoxShape3D: return false
	return shape.shape.get_script()==null and shape.shape.size==DUPLICATE_SUPPORT_SIZE

func _capture_duplicate_support(scene: Node3D) -> void:
	var root: Node=scene.get_node_or_null("PalazzoGroundExtension")
	var body: Node=root.get_node_or_null("DryGround") if root!=null else null
	var shape: Node=body.get_child(0) if body!=null and body.get_child_count()>0 else null
	if not _duplicate_support_geometry(scene,root,body,shape): return
	_duplicate_support={"root":weakref(root),"body":weakref(body),"shape":weakref(shape),"resource":weakref(shape.shape),"rid":body.get_rid()}

func _current_duplicate_support(scene: Node3D) -> RID:
	if _duplicate_support.is_empty(): return RID()
	var root: Variant=_duplicate_support.root.get_ref()
	var body: Variant=_duplicate_support.body.get_ref()
	var shape: Variant=_duplicate_support.shape.get_ref()
	if not _duplicate_support_geometry(scene,root,body,shape): return RID()
	if shape.shape!=_duplicate_support.resource.get_ref() or body.get_rid()!=_duplicate_support.rid: return RID()
	return _duplicate_support.rid

func _valid_states(states: Variant, owners: Dictionary) -> bool:
	if not states is Dictionary or states.size() > owners.size(): return false
	for id: Variant in states:
		if not id is String or not owners.has(id) or not states[id] is String or states[id] not in ["ordinary_outdoor", "deny", "unknown"]: return false
	return true

func _owner_allowed(id: String, generation: int) -> bool:
	if _disposed or _scene == null or not is_instance_valid(_scene.get_ref()) or generation != 1 or not _owners.has(id) or _states.get(id, "unknown") != "ordinary_outdoor": return false
	if not _scene.get_ref().global_transform.is_equal_approx(Transform3D.IDENTITY): return false
	var record: Dictionary = _owners[id]; var owner: RefCounted = record.owner
	if owner.dead or owner.source_id != id or owner.life_generation != generation: record.dead_seen = true
	return not record.dead_seen

func _index(point: Vector3) -> int:
	if not point.is_finite(): return -1
	return _world_index(float(point.x)+395.65,float(point.z)+45.099999999999994)

func _world_index(world_x: float, world_z: float) -> int:
	var c: float=world_x/4.1-float(_start_c)
	var r: float=world_z/4.1-float(_start_r)
	if r<0 or r>=_rows or c<0 or c>=_cols: return -1
	return int(floor(r))*_cols+int(floor(c))

func source_admit(point: Vector3, id: String, generation: int, radius: float, purpose: String, token_scope: Array=NO_MEMO) -> bool:
	if _dsh_memo<0: _memo_flag()
	if not token_scope.is_empty() and token_scope.size()==9 and (token_scope[8]!=1 or _host==null or not is_instance_valid(_host.get_ref()) or token_scope[1]!=_host.get_ref() or token_scope[1].get("_busy")!=true):
		token_scope.clear();return false # Invalid external/reused scope confers no token proof.
	var scope: Array=_take_pinned_token_scope(token_scope) if not token_scope.is_empty() else ([null] if _dsh_memo==1 and _same_call_token_contract() else NO_MEMO)
	var admitted: bool=_source_admit_scoped(point,id,generation,radius,purpose,scope)
	if not scope.is_empty(): scope.clear()
	return admitted

func _source_admit_scoped(point: Vector3, id: String, generation: int, radius: float, purpose: String, token_scope: Array) -> bool:
	# DSH_QUERY_PROBE (temporary): physics-query rate of the city admission policy.
	if _dsh_ms == 0:
		_dsh_ms = Time.get_ticks_msec(); _dsh_last = _counts.duplicate()
	elif Time.get_ticks_msec() - _dsh_ms >= 1000:
		var dsh_dt := float(Time.get_ticks_msec() - _dsh_ms) / 1000.0
		print("DSH_QPS admit/s=","%.0f" % (float(int(_counts.source_calls)-int(_dsh_last.source_calls))/dsh_dt),
			" native_seg/s=","%.0f" % (float(int(_counts.native_calls)-int(_dsh_last.native_calls))/dsh_dt),
			" floor_rays/s=","%.0f" % (float(int(_counts.floor_rays)-int(_dsh_last.floor_rays))/dsh_dt),
			" polygon/s=","%.0f" % (float(int(_counts.polygon_contacts)-int(_dsh_last.polygon_contacts))/dsh_dt),
			" total_rays=",_counts.floor_rays)
		_dsh_ms = Time.get_ticks_msec(); _dsh_last = _counts.duplicate()
	if _dsh_split < 0: _split_flags()  # DSH_NAVSTEP3
	if _dsh_memo < 0: _memo_flag()  # DSH_NAVSTEP3
	var dsh_t := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
	if _dsh_split_on: _dsh_p["calls"] = int(_dsh_p["calls"]) + 1; _dsh_report()  # DSH_NAVSTEP3
	var dsh_memo: Array=token_scope # Owned solely by the immediately enclosing wrapper.
	if not Thread.is_main_thread() or _busy or not _owner_allowed(id,generation) or not is_finite(radius) or absf(radius-RADIUS)>.000001 or purpose not in ["placement","target","route"]:
		if _dsh_split_on: _dsh_p["guard_refuse"] = int(_dsh_p["guard_refuse"]) + 1  # DSH_NAVSTEP3
		return false
	_counts.source_calls+=1
	if _dsh_split_on: _dsh_add("owner_us", dsh_t)  # DSH_NAVSTEP3
	# DSH_NAVSTEP2: --city-policy-slim=1 iterates the shared constant instead of
	# rebuilding the same five offset Arrays. Identical values, identical order.
	if _dsh_slim < 0: _dsh_slim = _slim_flag()
	var road: bool=false
	var dsh_offsets: Array = POINT_OFFSETS if _dsh_slim == 1 else [[0.0,0.0],[-RADIUS,-RADIUS],[-RADIUS,RADIUS],[RADIUS,-RADIUS],[RADIUS,RADIUS]]
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	for offset: Array in dsh_offsets:
		var index:=_world_index(float(point.x)+395.65+float(offset[0]),float(point.z)+45.099999999999994+float(offset[1]))
		if index<0:
			if _dsh_split_on: _dsh_add("road_us", dsh_t)  # DSH_NAVSTEP3
			return false
		if _ordinary[index]==0: road=true
	if _dsh_split_on: _dsh_add("road_us", dsh_t)  # DSH_NAVSTEP3
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	var token:=_daily_token(id,generation,dsh_memo)
	if _dsh_split_on: _dsh_add("daily_us", dsh_t)  # DSH_NAVSTEP3
	# The final full segment includes this exact endpoint proof. No dynamic
	# or owner result is cached beyond this synchronous admission.
	# The daily token is bound later, in daily_configure, so during fallback placement it is
	# still empty. Requiring a fully ordinary footprint in that state rejected 81% of all city
	# placement probes (roadMask covers 41.9% of the crop), before the resident had any errand
	# to be outside of. With no token there is no errand path to violate, so admit on the
	# purposeful segment test instead. Measured before: L171 road_true 3383, segment_false 62,
	# would_pass 706 -- placement never left fallback_placement. Measured after: the phase
	# advances source_birth -> fallback_placement -> navigation_ready and startup FPS rises
	# from 1-2 to 20.
	if token.is_empty():
		if _dsh_split_on: _dsh_p["token_empty"] = int(_dsh_p["token_empty"]) + 1  # DSH_NAVSTEP3
		return _source_segment(point,point,true)
	var handoff: bool=Vector2(point.x-token.body.global_position.x,point.z-token.body.global_position.z).length()<=.02
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	var dsh_path_ok: bool = not (road and not handoff) or _path_contains(id,point,dsh_memo)  # DSH_NAVSTEP3
	if _dsh_split_on: _dsh_add("path_us", dsh_t)  # DSH_NAVSTEP3
	if not dsh_path_ok: _last_reason="road_outside_current_errand_path";return false
	var from: Vector3=token.body.global_position if purpose=="route" and token.body.global_position.distance_to(point)<=.25 else point
	# DSH_NAVSTEP2: see the POLICY_TTL note in apply_nav_step.py. TTL 0 (default)
	# re-proves the whole chain exactly as before.
	var dsh_ttl := _proof_ttl()
	var dsh_pin: Variant = _dsh_proof.get(id) if dsh_ttl > 0 else null
	if dsh_ttl > 0 and dsh_pin is Dictionary and int(dsh_pin.due) > Engine.get_physics_frames() and str(dsh_pin.purpose) == purpose and dsh_pin.from == from and dsh_pin.point == point and int(dsh_pin.rid) == token.body.get_rid() and int(dsh_pin.version) == _version:
		_last_reason=""
		return _token_current(token, null, dsh_memo)
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	var dsh_seg: bool = _source_segment(from,point,true)  # DSH_NAVSTEP3
	if _dsh_split_on: _dsh_add("seg_us", dsh_t)  # DSH_NAVSTEP3
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	var dsh_floor: bool = dsh_seg and _native_floor_square(token,point)  # DSH_NAVSTEP3
	if _dsh_split_on: _dsh_add("floor_us", dsh_t)  # DSH_NAVSTEP3
	if _dsh_split_on: dsh_t = Time.get_ticks_usec()  # DSH_NAVSTEP3
	var dsh_proven: bool = dsh_floor and _native_segment(token,from,point,false,dsh_memo)  # DSH_NAVSTEP3
	if _dsh_split_on:
		_dsh_add("native_us", dsh_t)  # DSH_NAVSTEP3
		if not dsh_proven: _dsh_p["prove_fail"] = int(_dsh_p["prove_fail"]) + 1  # DSH_NAVSTEP3
	if dsh_ttl > 0:
		if dsh_proven:
			if dsh_pin is Dictionary:
				dsh_pin.due = Engine.get_physics_frames() + dsh_ttl
				dsh_pin.purpose = purpose; dsh_pin.from = from; dsh_pin.point = point; dsh_pin.rid = token.body.get_rid(); dsh_pin.version = _version
			else:
				_dsh_proof[id] = {"due": Engine.get_physics_frames() + dsh_ttl, "purpose": purpose, "from": from, "point": point, "rid": token.body.get_rid(), "version": _version}
		else:
			if dsh_pin is Dictionary: _dsh_proof.erase(id)
	return dsh_proven

# DSH_HANDOFFPROBE: temporary diagnostic (--city-handoff-probe=1). Off by default: the
# gate is one int compare after the first call and every probe read re-runs exactly the
# same tests the refusal already ran, so no decision, order or stored state changes.
var _dsh_hp := -1

func _handoff_probe_on() -> int:  # DSH_HANDOFFPROBE
	if _dsh_hp < 0:
		_dsh_hp = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-handoff-probe="):
				_dsh_hp = maxi(0, int(argument.trim_prefix("--city-handoff-probe=")))
	return _dsh_hp

func _handoff_probe(point: Vector3, id: String, index: int, height: float, admit: int, hit: int, hit_y: float, dy: float, reason: String) -> void:  # DSH_HANDOFFPROBE
	print("DSH_HANDOFF_PROBE id=", id, " point=(", "%.3f" % point.x, ",", "%.3f" % point.y, ",", "%.3f" % point.z,
		") index=", index, " height=", "%.4f" % height, " admit=", admit, " hit=", hit,
		" hit_y=", "%.4f" % hit_y, " dy=", "%.4f" % dy, " reason=", reason)

func support_height(point: Vector3, id: String, generation: int) -> float:
	if not Thread.is_main_thread() or _busy or not _owner_allowed(id, generation) or not point.is_finite(): return NAN
	var probe: bool = _handoff_probe_on() == 1  # DSH_HANDOFFPROBE
	var index := _index(point)
	if index < 0:
		if probe: _handoff_probe(point, id, index, NAN, -1, 0, NAN, NAN, "index")  # DSH_HANDOFFPROBE
		return NAN
	var reference := Vector3(point.x, _heights[index], point.z)
	if not source_admit(reference, id, generation, RADIUS, "placement"):
		if probe: _handoff_probe(point, id, index, reference.y, 0, 0, NAN, NAN, "admit")  # DSH_HANDOFFPROBE
		return NAN
	_busy = true
	_ray.from = reference + Vector3.UP * .30; _ray.to = reference - Vector3.UP * .30
	var scene: Node3D = _scene.get_ref()
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(_ray)
	var result := NAN
	if not hit.is_empty() and _floors.has(hit.rid) and hit.normal.y >= .70 and absf(hit.position.y - reference.y) < .0001:
		var floor_record: Dictionary = _floors[hit.rid]
		var body: StaticBody3D = floor_record.body.get_ref()
		var shape: CollisionShape3D = floor_record.shape.get_ref()
		if is_instance_valid(body) and is_instance_valid(shape) and body.get_parent() == scene and body.global_transform.is_equal_approx(floor_record.frame) and body.collision_layer == 1 and not shape.disabled and shape.transform.is_equal_approx(Transform3D.IDENTITY) and shape.shape is BoxShape3D and shape.shape.size.is_equal_approx(floor_record.size): result = hit.position.y
	if probe and not is_finite(result):  # DSH_HANDOFFPROBE
		var dsh_hit_y: float = float(hit.position.y) if not hit.is_empty() else NAN
		var dsh_dy: float = dsh_hit_y - reference.y if not hit.is_empty() else NAN
		var dsh_reason := "none"
		if not hit.is_empty():
			if not _floors.has(hit.rid): dsh_reason = "none"
			elif hit.normal.y < .70: dsh_reason = "normal"
			elif not absf(hit.position.y - reference.y) < .0001: dsh_reason = "floor"
			else: dsh_reason = "floor"
		_handoff_probe(point, id, index, reference.y, 1, -1 if hit.is_empty() else 1, dsh_hit_y, dsh_dy, dsh_reason)
	_busy = false
	return result

func callbacks() -> Dictionary:
	return {"source_admit": Callable(self, "source_admit"), "support_height": Callable(self, "support_height")}

func update_access(version: int, states: Dictionary) -> bool:
	if not Thread.is_main_thread() or _busy or _disposed or _scene == null or version <= _version or not _valid_states(states, _owners): return false
	_states = states.duplicate(); _version = version
	return true

func access_version() -> int: return _version

func bind_host(host: RefCounted) -> bool:
	if _host!=null or _scene==null or not is_instance_valid(host) or host.get("_admit").get_object()!=self: return false
	for method: String in ["_local_walker_current","daily_activity_status","physical_life_current"]:
		if not host.has_method(method): return false
	_host=weakref(host)
	_install_initial_admission_pump()
	return true

func _daily_token(id: String, generation: int, memo: Array=NO_MEMO) -> Dictionary:
	if _host==null or not is_instance_valid(_host.get_ref()): return {}
	var host: RefCounted=_host.get_ref()
	var claims: Variant=host.get("_daily_activities")
	if not claims is Dictionary or not claims.has(id): return {}
	var token: Dictionary=claims[id].binding
	if token.life_generation!=generation or not _token_current(token,null,memo): return {}
	return token

func _token_current(token: Dictionary, activity_owner: RefCounted=null, memo: Array=NO_MEMO) -> bool:
	# Only the exact synchronous caller mints and clears a scope; no memo fields.
	var dsh_t0 := Time.get_ticks_usec() if _dsh_split_on else 0
	var dsh_current := false
	var id: String=str(token.get("source_id",""))
	var generation: int=int(token.get("life_generation",-1))
	if not Thread.is_main_thread() or _disposed or _host==null or not is_instance_valid(_host.get_ref()) or not _owner_allowed(id,generation): dsh_current=false
	else:
		var host: RefCounted=_host.get_ref()
		var have_memo: bool=_dsh_memo==1 and (memo.size()==1 and memo[0]==null or memo.size()==9 and (memo[8]==0 or memo[8]==2))
		var claims: Variant=host.get("_daily_activities") if have_memo else null
		if have_memo and memo.size()==9 and is_same(token,memo[0]) and memo[1]==host and memo[3]==id and memo[4]==generation and memo[7]==_version and host.get("_disposed")==false and host.get("_dispose_requested")==false and is_instance_valid(token.get("body")) and token.body.get_rid()==memo[5] and claims is Dictionary and claims.has(id):
			var claim: Dictionary=claims[id]
			if is_same(claim.binding,token) and claim.serial==memo[6] and claim.owner is WeakRef and claim.owner.get_ref()==memo[2] and is_instance_valid(memo[2]):
				_dsh_memo_hits+=1
				return activity_owner==null or memo[2]==activity_owner
		# A fresh original body/rig/capsule predicate is always the first proof.
		if not host._local_walker_current(token): dsh_current=false
		else:
			var direct: Dictionary=claims[id] if have_memo and claims is Dictionary and claims.has(id) else {}
			# local_walker_current implies transport_life_current for this exact
			# full binding. These dictionary reads cannot change the world.
			if not direct.is_empty() and direct.get("binding")==token and direct.get("owner") is WeakRef:
				var owner: RefCounted=direct.owner.get_ref()
				dsh_current=is_instance_valid(owner) and (activity_owner==null or owner==activity_owner)
				if dsh_current:
					var phase: int=int(memo[8]) if memo.size()==9 else 0
					memo.resize(9)
					memo[0]=direct.binding;memo[1]=host;memo[2]=owner;memo[3]=id;memo[4]=generation;memo[5]=token.body.get_rid();memo[6]=direct.serial;memo[7]=_version;memo[8]=phase
			else:
				# Unequal claims and custom graphs retain the original heavy proof.
				var lease: Dictionary=host.daily_activity_status(token.source_id)
				dsh_current=lease.get("current",false) and lease.get("life_generation")==token.life_generation and is_instance_valid(lease.get("owner")) and (activity_owner==null or lease.owner==activity_owner)
	if _dsh_split_on:
		_dsh_p["tc_calls"]=int(_dsh_p["tc_calls"])+1
		_dsh_add("tc_us",dsh_t0)
	return dsh_current


func authorize_errand_path(activity_owner: RefCounted, token: Dictionary, map: RID, iteration: int, path: PackedVector3Array, previous_cookie: int = -1, reused_suffix_from: int = -1, old_suffix_from: int = -1) -> Dictionary:
	if _busy or not _token_current(token,activity_owner) or not map.is_valid() or path.is_empty() or path.size()>512: return {"ok":false,"reason":"current_bounded_errand_required"}
	var host: RefCounted=_host.get_ref();var navigation: RefCounted=_ordinary_navigation(host)
	var backend: Variant=navigation.get("_backend") if navigation!=null else null
	if backend==null or backend.map_rid()!=map or NavigationServer3D.map_get_iteration_id(map)!=iteration: return {"ok":false,"reason":"current_native_map_required"}
	if path[0].distance_to(token.body.global_position)>.35: return {"ok":false,"reason":"path_must_start_at_actual_body"}
	# A detour replaces only the travelled prefix of this exact, still current
	# policy route. The byte-exact suffix was already projected onto this same
	# native map and policy version. Rebuild all buckets for the NEW route, but
	# avoid repeating hundreds of static closest-point queries for that suffix.
	var reuse_suffix := previous_cookie >= 0
	if reuse_suffix:
		var id: String = str(token.get("source_id", ""))
		if not current_errand_cookie(id, int(token.get("life_generation", -1)), previous_cookie): return {"ok":false,"reason":"detour_previous_path_not_current"}
		var old: Dictionary = _paths[id]
		var vertices: PackedVector3Array = old.vertices
		if old.owner.get_ref() != activity_owner or old.token != token or old.map != map or old.iteration != iteration or reused_suffix_from < 1 or reused_suffix_from > path.size() or old_suffix_from < 1 or old_suffix_from > vertices.size() or path.size() - reused_suffix_from != vertices.size() - old_suffix_from:
			return {"ok":false,"reason":"detour_suffix_identity"}
		for offset in path.size() - reused_suffix_from:
			if path[reused_suffix_from + offset] != vertices[old_suffix_from + offset]: return {"ok":false,"reason":"detour_suffix_changed"}
	var buckets: Dictionary={};var distance:=0.0
	for index in path.size():
		var point: Vector3=path[index]
		if not point.is_finite(): return {"ok":false,"reason":"path_point_off_native_map","point_index":index,"point":point,"nonfinite":true}
		if not reuse_suffix or index < reused_suffix_from:
			var closest:=NavigationServer3D.map_get_closest_point(map,point)
			var off_map:=closest.distance_to(point)
			if off_map>.12:
				# The physical floor and voxel surface can differ at kerbs. Admit
				# only the actual initial body through its bounded physical connector.
				# Every subsequent proposal must still lie on the current native map.
				var actual_start:=index==0 and point.distance_to(token.body.global_position)<=.000001
				if not actual_start or off_map>2.0:
					return {"ok":false,"reason":"path_point_off_native_map","point_index":index,"point":point,"closest":closest,"distance_m":off_map,"is_actual_start":actual_start,"connector_reason":"actual_start_or_gap_bound"}
				if not native_clear_segment(token,point,closest):
					return {"ok":false,"reason":"path_point_off_native_map","point_index":index,"point":point,"closest":closest,"distance_m":off_map,"is_actual_start":actual_start,"connector_reason":_last_reason}
		if index==0: continue
		var a: Vector3=path[index-1]
		if a.distance_to(point)>_dsh_leg_bound(): return {"ok":false,"reason":"path_leg_exceeds_bound"}  # DSH_POLICYLEG
		distance+=a.distance_to(point)
		if distance>2000.0: return {"ok":false,"reason":"path_distance_bound"}
		var minv:=Vector2(a.x,a.z).min(Vector2(point.x,point.z))-Vector2.ONE*.36
		var maxv:=Vector2(a.x,a.z).max(Vector2(point.x,point.z))+Vector2.ONE*.36
		for z in range(floori(minv.y/4.1),floori(maxv.y/4.1)+1):
			for x in range(floori(minv.x/4.1),floori(maxv.x/4.1)+1):
				var key:=Vector2i(x,z)
				if not buckets.has(key): buckets[key]=[]
				buckets[key].append([Vector2(a.x,a.z),Vector2(point.x,point.z)])
	if not _token_current(token,activity_owner) or NavigationServer3D.map_get_iteration_id(map)!=iteration: return {"ok":false,"reason":"owner_or_map_changed"}
	_cookie+=1
	_paths[token.source_id]={"owner":weakref(activity_owner),"token":token.duplicate(),"cookie":_cookie,"map":map,"iteration":iteration,"buckets":buckets,"vertices":path.duplicate(),"version":_version,"navigation":weakref(navigation),"backend":weakref(backend)}
	if reuse_suffix:
		_detour_suffix_reuses += 1
		_detour_suffix_points += path.size() - reused_suffix_from
	return {"ok":true,"cookie":_cookie,"points":path.size(),"source_authority":false}

## The persistent mover may reuse only this exact current policy proposal.
## This identity check does not prove physics; the backend validates its prefix.
func current_errand_cookie(id: String, life_generation: int, cookie: int, token_scope: Array=NO_MEMO) -> bool:
	var cookie_scope: Array=token_scope if _dsh_memo==1 and token_scope.size()==1 and token_scope[0]==null else NO_MEMO
	if not token_scope.is_empty() and cookie_scope.is_empty(): token_scope.clear()
	if not _paths.has(id): return false
	var path: Dictionary = _paths[id]
	var owner: RefCounted = path.owner.get_ref()
	if not is_instance_valid(owner) or int(path.token.get("life_generation", -1)) != life_generation or int(path.cookie) != cookie or path.version != _version or not _token_current(path.token,owner,cookie_scope): return false
	var host: RefCounted = _host.get_ref()
	var navigation: RefCounted = _ordinary_navigation(host)
	if navigation == null or not is_instance_valid(path.backend.get_ref()) or path.navigation.get_ref() != navigation or path.backend.get_ref() != navigation.get("_backend") or not path.map.is_valid(): return false
	var current: bool=path.backend.get_ref().map_rid()==path.map and NavigationServer3D.map_get_iteration_id(path.map)==path.iteration
	if current and cookie_scope.size()==9: cookie_scope[8]=1 # immediately following source call consumes the cookie proof.
	return current

func current_errand_route(activity_owner: RefCounted, token: Dictionary, map: RID, iteration: int, cookie: int, route: PackedVector3Array) -> bool:
	var id: String = str(token.get("source_id", ""))
	if not current_errand_cookie(id, int(token.get("life_generation", -1)), cookie): return false
	var path: Dictionary = _paths[id]
	if path.owner.get_ref() != activity_owner or path.token != token or path.map != map or path.iteration != iteration: return false
	var vertices: PackedVector3Array = path.vertices
	if route.size() != vertices.size() or route.is_empty() or route[0].distance_to(vertices[0]) > .35: return false
	for index in range(1, route.size()):
		if route[index] != vertices[index]: return false
	return true

func revoke_errand_path(activity_owner: RefCounted, token: Dictionary, cookie: int) -> bool:
	var id: String=str(token.get("source_id",""))
	if not _paths.has(id): return false
	var path: Dictionary=_paths[id]
	# A stale life may revoke only its exact old read-only path, never a newer one.
	if path.owner.get_ref()!=activity_owner or path.token!=token or path.cookie!=cookie: return false
	_paths.erase(id);return true

func _path_contains(id: String, point: Vector3, memo: Array=NO_MEMO) -> bool:
	if not _paths.has(id): return false
	var path: Dictionary=_paths[id]
	var path_token: Dictionary=memo[0] if memo.size()==9 and memo[0] is Dictionary and path.token==memo[0] else path.token
	if not is_instance_valid(path.owner.get_ref()) or not _token_current(path_token,path.owner.get_ref(),memo) or path.version!=_version or not path.map.is_valid(): return false
	if not is_instance_valid(path.navigation.get_ref()) or _ordinary_navigation(_host.get_ref())!=path.navigation.get_ref() or path.navigation.get_ref().get("_backend")!=path.backend.get_ref(): return false
	if not is_instance_valid(path.backend.get_ref()) or path.backend.get_ref().map_rid()!=path.map or NavigationServer3D.map_get_iteration_id(path.map)!=path.iteration: return false
	var p:=Vector2(point.x,point.z)
	for edge: Array in path.buckets.get(Vector2i(floori(point.x/4.1),floori(point.z/4.1)),[]):
		if Geometry2D.get_closest_point_to_segment(p,edge[0],edge[1]).distance_to(p)<=.35: return true
	return false

static func _ordinary_navigation(host: RefCounted) -> RefCounted:
	if not is_instance_valid(host): return null
	var current: RefCounted=host.get("_navigation")
	var lease: Variant=host.get("_local_navigation_lease")
	if not lease is Dictionary or lease.is_empty(): return current
	var reference: Variant=lease.get("adapter")
	if not reference is WeakRef or not is_instance_valid(reference.get_ref()) or current!=reference.get_ref(): return null
	# Only unwrap the exact host-issued lease. A field named base_nav is not
	# authority. Another actor's current entry forwards the original jobs;
	# a disposed/replaced/dead entry cannot confer a usable native map.
	if current.get("host")!=host or current.get("base_nav")!=lease.get("base") or current.get("token")!=lease.get("token") or current.get("_disposed")!=false: return null
	if not host.has_method("_local_walker_current") or not lease.get("token") is Dictionary or not host._local_walker_current(lease.token): return null
	return lease.base as RefCounted

func admit_daily_handoff(token: Dictionary, point: Vector3) -> bool:
	if _busy or not _token_current(token) or point.distance_to(token.body.global_position)>.02: return false
	return _source_segment(point,point,true) and _native_floor_square(token,point) and _native_segment(token,point,point,false)

func purposeful_entry_land_allowed(token: Dictionary, point: Vector3) -> bool:
	# Source terrain/restriction only. The entry owner separately proves its
	# pinned corridor, contact-specific floor, complete solids and live bodies.
	return _token_current(token) and point.is_finite() and is_finite(_terrain_height(float(point.x)+395.65,float(point.z)+45.099999999999994))

func native_clear_segment(token: Dictionary, from: Vector3, to: Vector3) -> bool:
	if _busy or not _token_current(token) or not from.is_finite() or not to.is_finite() or from.distance_to(to)>5.1: _last_reason="segment_identity_or_bound";return false
	if not _source_segment(from,to,true): return false
	return _native_floor_square(token,from) and _native_floor_square(token,to) and _native_segment(token,from,to,false)

func current_vehicle_clear_segment(token: Dictionary, from: Vector3, to: Vector3) -> bool:
	# This is only the dynamic-body conjunct for an authored entry's separate
	# pinned source/static/floor proof. It is not a substitute for that proof.
	if _busy or not _token_current(token) or not from.is_finite() or not to.is_finite() or from.distance_to(to)>5.1: return false
	return _native_segment(token,from,to,true)

func _native_segment(token: Dictionary, from: Vector3, to: Vector3, dynamic_only: bool, memo: Array=NO_MEMO) -> bool:
	_counts.native_calls+=1
	var scene: Node3D=_scene.get_ref();var space:=scene.get_world_3d().direct_space_state
	var exclusions: Array[RID]=[token.body.get_rid()]
	var square_from:=from; var square_to:=to
	if not dynamic_only:
		# A full footprint can straddle the authored 4cm road kerb while the
		# actual capsule stands on the lower road. Ground is support, not an
		# obstacle penetrating the wider clearance box. Source floor rays and
		# the native capsule still validate the real movement at its own height.
		if _dsh_slim < 0: _dsh_slim = _slim_flag()
		# DSH_NAVSTEP2: --city-policy-slim=1 computes the footprint height once when
		# from == to: _terrain_height is pure, so both copies took the same value and
		# the identical max() is applied to both. Same bound, same refusal.
		var dsh_same_footprint: bool = _dsh_slim == 1 and from == to
		for offset: Vector2 in OFFSETS:
			var a:=_terrain_height(float(from.x)+395.65+offset.x,float(from.z)+45.099999999999994+offset.y)
			if not is_finite(a): _last_reason="square_support_unknown";return false
			if dsh_same_footprint:
				square_from.y=maxf(square_from.y,a); square_to.y=maxf(square_to.y,a)
				continue
			var b:=_terrain_height(float(to.x)+395.65+offset.x,float(to.z)+45.099999999999994+offset.y)
			if not is_finite(b): _last_reason="square_support_unknown";return false
			square_from.y=maxf(square_from.y,a); square_to.y=maxf(square_to.y,b)
	# DSH_DOORFREE: with --city-door-free-entry=1 the movement proof uses the real
	# actor capsule instead of the .738 m clearance square. The .738 m footprint
	# above (support/land) and the source square in _source_segment (walls and
	# occupants) are deliberately unchanged.
	if DoorOpen.free_entry():
		if _free_capsule_calls == 0:
			print("DSH_DOORFREE world_policy capsule_proof radius=", _capsule_radius(token), " height=", _capsule_height(token), " half_width=", DoorOpen.half_width_m())
		_free_capsule_calls += 1
		if dynamic_only:
			var capsule_broad:=BoxShape3D.new()
			capsule_broad.size=(to-from).abs()+Vector3(_capsule_radius(token)*2.0,_capsule_height(token),_capsule_radius(token)*2.0)+Vector3.ONE*.01
			var broad_query:=PhysicsShapeQueryParameters3D.new()
			broad_query.shape=capsule_broad;broad_query.collision_mask=1|256;broad_query.margin=.001
			broad_query.transform=Transform3D(Basis.IDENTITY,(from+to)*.5+Vector3.UP*.975)
			var broad_hits: Array=space.intersect_shape(broad_query,128)
			if broad_hits.size()>=128: _last_reason="dynamic_broadphase_overflow";return false
			for hit: Dictionary in broad_hits:
				if hit.collider is StaticBody3D: exclusions.append(hit.rid)
		var capsule_result: Dictionary=DoorOpen.capsule_query(space,square_from,square_to,_capsule_radius(token),_capsule_height(token),1|256,exclusions)
		if not bool(capsule_result.get("ok",false)):
			_last_reason="current_capsule:"+str(capsule_result.get("reason",""));return false
		_last_reason="";return _token_current(token, null, memo)
	_query.exclude=exclusions;_query.shape=_box;_query.motion=Vector3.ZERO
	if dynamic_only:
		# Enumerate local statics in the swept AABB, then sweep the real square
		# against every other body. Bound overflow is a refusal, never truncation.
		var broad:=BoxShape3D.new();broad.size=(to-from).abs()+_box.size+Vector3.ONE*.01
		_query.shape=broad;_query.transform=Transform3D(Basis.IDENTITY,(from+to)*.5+Vector3.UP*.975)
		var hits: Array=space.intersect_shape(_query,128)
		if hits.size()>=128: _last_reason="dynamic_broadphase_overflow";return false
		for hit: Dictionary in hits:
			if hit.collider is StaticBody3D: exclusions.append(hit.rid)
		_query.exclude=exclusions;_query.shape=_box
	# With zero motion, both endpoint overlaps are identical and there is
	# no swept volume beyond that exact same full box. Keep fresh final identity.
	var endpoints: Array=[square_from] if from==to else [square_from,square_to]
	for point: Vector3 in endpoints:
		_query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.975);_query.motion=Vector3.ZERO
		if not space.intersect_shape(_query,1).is_empty(): _last_reason="current_square_overlap";return false
	if from==to: _last_reason="";return _token_current(token, null, memo)
	_query.transform=Transform3D(Basis.IDENTITY,square_from+Vector3.UP*.975);_query.motion=square_to-square_from
	var cast: PackedFloat32Array=space.cast_motion(_query)
	if cast.size()!=2 or cast[0]<.999999: _last_reason="current_square_sweep";return false
	_last_reason="";return _token_current(token, null, memo)

## DSH_DOORFREE: the actor's real capsule, read from the live body so the free
## entry proof can never be wider than the shape the engine actually moves.
func _capsule_radius(token: Dictionary) -> float:
	var body: Variant=token.get("body")
	if body is Node and (body as Node).get_child_count()>0:
		var shape: Variant=(body as Node).get_child(0).shape
		if shape is CapsuleShape3D: return maxf(0.01,(shape as CapsuleShape3D).radius)
	return 0.3

func _capsule_height(token: Dictionary) -> float:
	var body: Variant=token.get("body")
	if body is Node and (body as Node).get_child_count()>0:
		var shape: Variant=(body as Node).get_child(0).shape
		if shape is CapsuleShape3D: return maxf(0.10,(shape as CapsuleShape3D).height)
	return 1.9

func _native_floor_square(token: Dictionary, point: Vector3, static_excludes: Array[RID]=[]) -> bool:
	var body_rid: RID=token.body.get_rid()
	var scene: Node3D=_scene.get_ref();var space:=scene.get_world_3d().direct_space_state
	var duplicate_rid:=_current_duplicate_support(scene)
	for offset: Vector2 in OFFSETS:
		var at:=point+Vector3(offset.x,0,offset.y)
		var y:=_terrain_height(float(at.x)+395.65,float(at.z)+45.099999999999994)
		if not is_finite(y): return false
		# Select original support through the audited coplanar duplicate only at
		# its exact source height. Other floors, steps, ramps and all obstacles
		# retain their original queries; this exclusion never reaches movement.
		_ray.exclude=[body_rid,duplicate_rid] if duplicate_rid.is_valid() and y==0.0 else [body_rid]
		# Only explicit STATIC corridor callers supply authenticated dynamic RIDs.
		# All current movement callers retain the original exclusions above.
		if not static_excludes.is_empty():
			var floor_excludes: Array[RID]=_ray.exclude
			for rid: RID in static_excludes:
				if not rid in floor_excludes:floor_excludes.append(rid)
			_ray.exclude=floor_excludes
		_ray.from=Vector3(at.x,y+.3,at.z);_ray.to=Vector3(at.x,y-.3,at.z)
		var hit: Dictionary=space.intersect_ray(_ray);_counts.floor_rays+=1
		if hit.is_empty() or not _floors.has(hit.rid) or hit.normal.y<.7 or absf(hit.position.y-y)>.0001: _last_reason="current_source_floor_missing";return false
		var pin: Dictionary=_floors[hit.rid];var body: Variant=pin.body.get_ref();var shape: Variant=pin.shape.get_ref()
		if not is_instance_valid(body) or not is_instance_valid(shape) or body.get_parent()!=scene or body.global_transform!=pin.frame or body.collision_layer!=1 or shape.disabled or shape.transform!=Transform3D.IDENTITY or not shape.shape is BoxShape3D or shape.shape.size!=pin.size: _last_reason="source_floor_changed";return false
	return true

func _terrain_height(world_x: float, world_z: float) -> float:
	var index:=_world_index(world_x,world_z)
	if index<0 or _land[index]==0 or _restricted(world_z/4.1,world_x/4.1,int(_surface.grid[index/_cols][index%_cols])): return NAN
	return _heights[index]

func _source_segment(from: Vector3, to: Vector3, purposeful: bool) -> bool:
	if not from.is_finite() or not to.is_finite() or from.distance_to(to)>5.1: return false
	var steps:=0 if from==to else maxi(1,ceili(Vector2(to.x-from.x,to.z-from.z).length()/.574))
	if _dsh_slim < 0: _dsh_slim = _slim_flag()
	for step in range(steps+1):
		var amount:=0.0 if steps==0 else float(step)/steps
		var px: float=lerpf(float(from.x),float(to.x),amount)+395.65
		var pz: float=lerpf(float(from.z),float(to.z),amount)+45.099999999999994
		var py: float=lerpf(float(from.y),float(to.y),amount)
		var dsh_offsets: Array = POINT_OFFSETS if _dsh_slim == 1 else [[0.0,0.0],[-RADIUS,-RADIUS],[-RADIUS,RADIUS],[RADIUS,-RADIUS],[RADIUS,RADIUS]]
		for offset: Array in dsh_offsets:
			var x: float=px+float(offset[0]);var z: float=pz+float(offset[1]);var index:=_world_index(x,z)
			if index<0 or (not purposeful and _ordinary[index]==0): _last_reason="ordinary_terrain";return false
			# DSH_NAVSTEP2: --city-policy-slim=1 evaluates the index it already has
			# instead of asking _terrain_height() to recompute _world_index(x,z) for
			# this exact x,z. Same _land / _restricted / _heights test, same NAN
			# result, same reason string.
			var height: float = (_heights[index] if _land[index]!=0 and not _restricted(z/4.1,x/4.1,int(_surface.grid[index/_cols][index%_cols])) else NAN) if _dsh_slim == 1 else _terrain_height(x,z)
			if not is_finite(height) or absf(py-height)>.30: _last_reason="source_terrain_or_restriction";return false
	if not _contact.begin_segment([float(from.x)+395.65,float(from.z)+45.099999999999994],[float(to.x)+395.65,float(to.z)+45.099999999999994],RADIUS,1.9): return false
	var minv:=Vector2(from.x,from.z).min(Vector2(to.x,to.z))-Vector2.ONE*RADIUS
	var maxv:=Vector2(from.x,from.z).max(Vector2(to.x,to.z))+Vector2.ONE*RADIUS
	var seen: Dictionary={}
	for r in range(maxi(0,floori((minv.y+45.099999999999994)/4.1)-_start_r),mini(_rows-1,floori((maxv.y+45.099999999999994)/4.1)-_start_r)+1):
		for c in range(maxi(0,floori((minv.x+395.65)/4.1)-_start_c),mini(_cols-1,floori((maxv.x+395.65)/4.1)-_start_c)+1):
			for solid: Dictionary in _cells[r*_cols+c]:
				var key: int=solid.id
				if seen.has(key): continue
				seen[key]=true
				_counts.polygon_contacts+=1
				if _contact.blocks_polygon(solid.source_polygon,_terrain_height,solid.min_y,solid.max_y): _last_reason="continuous_source_square";return false
	return true

static func _restricted(r: float, c: float, tile: int) -> bool:
	# Exact source NPC restrictions from world.html. Arena/lair use floored
	# cells; prison uses continuous coordinates and its original .35 margin.
	var ri:=floorf(r);var ci:=floorf(c)
	if ri>=31 and ri<=41 and ci>=61 and ci<=71: return true
	if (ri-120.0)*(ri-120.0)+(ci-40.0)*(ci-40.0)<=400.0: return true
	var m:=.35
	if (r>=91-m and r<=103+m and c>=85-m and c<=94+m) or (r>=61-m and r<=91+m and c>=80.5-m and c<=98.5+m): return true
	if absf(r-69.55)<=1.62+m and c>=75.85-m and c<80.5+m: return true
	if absf(c-89.5)<=.93+m and r>=56-m and r<61+m: return true
	if tile==14:
		if ri+.5>=156 and ri+.5<=170 and (_segment_distance(ri+.5,ci+.5,156.8,63.0,163.8,66.8)<=1.7 or _segment_distance(ri+.5,ci+.5,162.2,67.2,168.5,72.2)<=2.25): return true
	return false

static func _segment_distance(r: float,c: float,ar: float,ac: float,br: float,bc: float) -> float:
	var vr:=br-ar;var vc:=bc-ac
	var k:=clampf(((r-ar)*vr+(c-ac)*vc)/maxf(.000000001,vr*vr+vc*vc),0.0,1.0)
	return sqrt((r-ar-vr*k)*(r-ar-vr*k)+(c-ac-vc*k)*(c-ac-vc*k))

func diagnostics() -> Dictionary:
	return {"scope":"NEW_LOCAL_ERRAND_CROSSING","reason":_last_reason,"counts":_counts.duplicate(),"paths":_paths.size(),"rows":_rows,"cols":_cols,"owners":_owners.size(),"detour_suffix_reuses":_detour_suffix_reuses,"detour_suffix_points":_detour_suffix_points,"source_authority":false}

func dispose() -> void:
	_duplicate_support.clear()
	if not Thread.is_main_thread() or _busy or _disposed: return
	_disposed = true
	_initial_stats.disposed_jobs+=_initial_jobs.size()
	_initial_jobs.clear(); _initial_queue.clear(); _initial_gc.clear()
	if is_instance_valid(_initial_pump):
		_initial_pump.set_physics_process(false); _initial_pump.queue_free()
	_initial_pump=null
	var scene: Node3D = _scene.get_ref() if _scene != null else null
	if is_instance_valid(scene) and scene.tree_exiting.is_connected(dispose): scene.tree_exiting.disconnect(dispose)
	_paths.clear();_host=null;_owners.clear(); _states.clear(); _floors.clear(); _cells.clear(); _land.clear(); _heights.clear(); _ray = null

## Proves one exact authorized static corridor edge. Every actual movement still
## calls source_admit and the original swept capsule; this proof never moves.
func static_errand_corridor(id: String, generation: int, cookie: int, edge: int, from: Vector3, to: Vector3, spacing: float) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or edge<1 or not is_finite(spacing) or spacing<.25 or spacing>1.0 or not current_errand_cookie(id,generation,cookie): return {"ok":false,"reason":"current_corridor_identity"}
	var path: Dictionary=_paths[id]
	var vertices: PackedVector3Array=path.vertices
	if edge>=vertices.size() or to!=vertices[edge] or (from!=vertices[edge-1] and not (edge==1 and from.distance_to(vertices[0])<=.35 and from.distance_to(path.token.body.global_position)<=.02)): return {"ok":false,"reason":"exact_corridor_edge"}
	var token: Dictionary=path.token
	if not _source_segment(from,to,true): return {"ok":false,"reason":"static_source_corridor:"+_last_reason}
	var result:=_static_corridor_clear(token,from,to,spacing)
	if not result.get("ok",false): return result
	var static_excludes: Array[RID]=result.exclude
	# Retain the old preflight's interior source-floor grid, once per unique point.
	var count:=maxi(1,ceili(from.distance_to(to)/spacing))
	for sample in range(count+1):
		var point:=from.lerp(to,float(sample)/count)
		if not _native_floor_square(token,point,static_excludes): return {"ok":false,"reason":"static_corridor_floor:"+_last_reason}
	if not current_errand_cookie(id,generation,cookie) or _paths[id]!=path: return {"ok":false,"reason":"corridor_changed_during_proof"}
	result.merge({"source_id":id,"life_generation":generation,"map":path.map,"iteration":path.iteration,"cookie":cookie,"floor_samples":count+1},true)
	return result

func _static_corridor_clear(token: Dictionary, from: Vector3, to: Vector3, spacing: float) -> Dictionary:
	var scene: Node3D=_scene.get_ref()
	var host: RefCounted=_host.get_ref()
	var space:=scene.get_world_3d().direct_space_state
	var excludes: Array[RID]=[token.body.get_rid()]
	# Include every old interior terrain-adjusted square, including a higher
	# interior kerb. This conservative vertical envelope also contains all
	# original point-relative boxes; endpoint-only height adjustment would not.
	var lift:=0.0
	var count:=maxi(1,ceili(from.distance_to(to)/spacing))
	for sample in range(count+1):
		var point:=from.lerp(to,float(sample)/count)
		for offset: Vector2 in OFFSETS:
			var y:=_terrain_height(point.x+395.65+offset.x,point.z+45.099999999999994+offset.y)
			if not is_finite(y) or absf(y-point.y)>.18:return {"ok":false,"reason":"static_corridor_point_floor_height"}
			lift=maxf(lift,y-point.y)
	var envelope:=BoxShape3D.new();envelope.size=_box.size+Vector3.UP*lift
	var centre:=Vector3.UP*(.975+lift*.5)
	var broad:=BoxShape3D.new();broad.size=(to-from).abs()+envelope.size+Vector3.ONE*.01
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=broad;query.collision_mask=1|256;query.margin=.001;query.exclude=excludes
	query.transform=Transform3D(Basis.IDENTITY,(from+to)*.5+centre)
	var hits:=space.intersect_shape(query,128)
	if hits.size()>=128: return {"ok":false,"reason":"corridor_broadphase_overflow"}
	# Mask1 includes NPCs. Ignore only currently authenticated ordinary bodies
	# and this scene's exact player in STATIC planning; unknown bodies refuse.
	for hit: Dictionary in hits:
		var collider: Object=hit.get("collider")
		if collider is StaticBody3D:continue
		if collider is CharacterBody3D:
			var managed: Dictionary=host.target_from_collider(collider)
			var player: Variant=scene.get("_player")
			if managed.get("ok",false) and host.physical_life_current(managed) or collider==player and is_instance_valid(player) and player.get_parent()==scene:
				if not hit.rid in excludes:excludes.append(hit.rid)
				continue
		return {"ok":false,"reason":"unowned_corridor_body"}
	query.exclude=excludes;query.shape=envelope
	for point: Vector3 in [from,to]:
		query.transform=Transform3D(Basis.IDENTITY,point+centre);query.motion=Vector3.ZERO
		if not space.intersect_shape(query,1).is_empty():return {"ok":false,"reason":"static_corridor_square_overlap"}
	query.transform=Transform3D(Basis.IDENTITY,from+centre);query.motion=to-from
	var cast:=space.cast_motion(query)
	if cast.size()!=2 or cast[0]<.999999:return {"ok":false,"reason":"static_corridor_square_sweep"}
	return {"ok":_token_current(token),"exclude":excludes}

## One graph check per direct-source or exact pinned callback scope.
func _same_call_token_contract() -> bool:
	if not Thread.is_main_thread() or _host==null or not is_instance_valid(_host.get_ref()) or not is_instance_valid(_contact): return false
	var host: RefCounted=_host.get_ref()
	var admission: Variant=host.get("_admit")
	if not admission is Callable or not admission.is_valid() or admission.get_object()!=self or admission.get_method()!=&"source_admit" or admission.get_bound_arguments_count()!=0 or admission.get_unbound_arguments_count()!=0: return false
	var host_script: Variant=host.get_script()
	var this_script: Variant=get_script()
	var footprint: Variant=_contact.get("_footprint")
	var navigation: Variant=host.get("_navigation")
	var local_lease: Variant=host.get("_local_navigation_lease")
	if not local_lease is Dictionary or not local_lease.is_empty() or not is_instance_valid(navigation) or not navigation.get_script() is Script or navigation.get_script().resource_path!="res://scripts/city/runtime/npc_city_navigation_host.gd": return false
	var backend: Variant=navigation.get("_backend")
	return this_script is Script and this_script.resource_path=="res://scripts/city/runtime/npc_city_world_policy.gd" and host_script is Script and host_script.resource_path=="res://scripts/npc_visual/preview_resident_host.gd" and is_instance_valid(backend) and backend.get_script() is Script and backend.get_script().resource_path=="res://scripts/city/runtime/npc_city_engine_navigation.gd" and backend.get("_state")=="READY" and _contact.get_script()==Contact and is_instance_valid(footprint) and footprint.get_script() is Script and footprint.get_script().resource_path=="res://scripts/navigation/npc_swept_footprint.gd"

func _new_pinned_token_scope(host: RefCounted) -> Array:
	if _dsh_memo<0: _memo_flag()
	if _dsh_memo!=1 or _host==null or _host.get_ref()!=host or not _same_call_token_contract(): return NO_MEMO
	return [null]

func _take_pinned_token_scope(scope: Array) -> Array:
	if _dsh_memo==1 and scope.size()==9 and scope[8]==1 and _host!=null and scope[1]==_host.get_ref() and scope[1].get("_busy")==true:
		scope[8]=2 # A retained Array cannot seed a second source entry.
		return scope
	return [null] if _dsh_memo==1 and _same_call_token_contract() else NO_MEMO


# Cooperative INITIAL admission changes scheduling only. Public synchronous
# authorize_errand_path (including suffix reuse) remains byte-exact above.
func initial_path_admission_enabled() -> bool:
	if _initial_flag<0:
		_initial_flag=1 # Native241 + matched default286 original frame budgets PASS.
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-initial-admission-budget="): _initial_flag=1 if argument.trim_prefix("--city-initial-admission-budget=")=="1" else 0
	return _initial_flag==1

func _install_initial_admission_pump() -> void:
	if not initial_path_admission_enabled() or _disposed or is_instance_valid(_initial_pump) or _scene==null: return
	var scene: Node3D=_scene.get_ref()
	if not is_instance_valid(scene) or not scene.is_inside_tree(): return
	var pump:=InitialAdmissionPump.new()
	pump.name="CityInitialAdmissionPump"; pump.policy=weakref(self)
	pump.process_physics_priority=1
	pump.set_process(false); scene.add_child(pump); pump.set_physics_process(true)
	_initial_pump=pump

func begin_initial_path_admission(activity_owner: RefCounted, token: Dictionary, map: RID, iteration: int, path: PackedVector3Array, requester: RefCounted, query_epoch: int) -> int:
	if not initial_path_admission_enabled() or _busy or _initial_pumping or not _token_current(token,activity_owner) or not map.is_valid() or path.is_empty() or path.size()>512 or _initial_jobs.size()>=INITIAL_ADMISSION_LIMIT: return -1
	if not is_instance_valid(requester) or requester.get_script()!=load("res://scripts/npc_daily_walk.gd") or requester.get("_policy")!=self or requester.get("_token")!=token or requester.get("_owner")==null or requester.get("_owner").get_ref()!=activity_owner or int(requester.get("_initial_admission_ticket"))>=0 or not requester._initial_admission_intent_current(query_epoch,map,iteration,path): return -1
	var intent_points: PackedVector3Array=requester.get("_points")
	for index in intent_points.size():
		if path[index+1]!=intent_points[index]: return -1
	for existing: int in _initial_jobs:
		if _initial_jobs[existing].token.source_id==token.source_id: return -1
	var host: RefCounted=_host.get_ref(); var navigation: RefCounted=_ordinary_navigation(host)
	var backend: Variant=navigation.get("_backend") if navigation!=null else null
	if backend==null or backend.map_rid()!=map or NavigationServer3D.map_get_iteration_id(map)!=iteration: return -1
	if not path[0].is_finite() or path[0].distance_to(token.body.global_position)>.35: return -1
	var claim: Dictionary=host.daily_activity_status(token.source_id)
	_initial_serial+=1
	var ticket:=_initial_serial
	_initial_jobs[ticket]={"ticket":ticket,"owner":weakref(activity_owner),"token":token.duplicate(),"requester":weakref(requester),"epoch":query_epoch,"map":map,"iteration":iteration,"version":_version,"navigation":weakref(navigation),"backend":weakref(backend),"claim_serial":claim.get("serial",-1),"path":path.duplicate(),"index":1,"verified":0,"buckets":{},"distance":0.0,"started_us":Time.get_ticks_usec(),"last_progress_us":Time.get_ticks_usec(),"progress_pause_us":0,"paused_us_total":0,"paused":false,"pause_started_us":0,"done":false,"result":{}}
	_initial_queue.append(ticket); _initial_gc.append(ticket)
	_initial_stats.created+=1
	_initial_stats.queue_peak=maxi(_initial_stats.queue_peak,_initial_queue.size())
	return ticket

func _initial_job_current(job: Dictionary) -> String:
	var owner: RefCounted=job.owner.get_ref(); var requester: RefCounted=job.requester.get_ref()
	if _busy or _disposed or not Thread.is_main_thread() or _version!=job.version or not is_instance_valid(owner) or not is_instance_valid(requester) or not _token_current(job.token,owner): return "owner_or_map_changed"
	if not requester._initial_admission_current(job.ticket,job.epoch,job.map,job.iteration,job.path): return "initial_path_intent_changed"
	var host: RefCounted=_host.get_ref(); var navigation: RefCounted=_ordinary_navigation(host)
	var backend: RefCounted=job.backend.get_ref()
	if not is_instance_valid(navigation) or not is_instance_valid(backend) or navigation!=job.navigation.get_ref() or navigation.get("_backend")!=backend or backend.map_rid()!=job.map or not job.map.is_valid() or NavigationServer3D.map_get_iteration_id(job.map)!=job.iteration: return "current_native_map_required"
	var claim: Dictionary=host.daily_activity_status(job.token.source_id)
	if claim.get("serial",-1)!=job.claim_serial or not claim.get("current",false) or claim.get("owner")!=owner or claim.get("life_generation",-1)!=int(job.token.life_generation): return "initial_path_claim_changed"
	if job.path[0].distance_to(job.token.body.global_position)>.35: return "path_must_start_at_actual_body"
	return ""

func _initial_finish(job: Dictionary, result: Dictionary) -> void:
	if not _initial_job_live(job) or job.done: return
	job.done=true; job.result=result.duplicate(); job.finished_us=Time.get_ticks_usec()
	_initial_stats.completed+=1
	if result.get("ok",false): _initial_stats.completed_ok+=1
	else:
		_initial_stats.completed_refused+=1
		if result.get("reason")=="initial_path_no_progress_timeout": _initial_stats.pending_no_progress_timeouts+=1
	var waited: int=job.finished_us-job.started_us
	_initial_stats.max_wait_us=maxi(_initial_stats.max_wait_us,waited); _initial_stats.total_wait_us+=waited

func _initial_projection(job: Dictionary, index: int) -> Dictionary:
	var point: Vector3=job.path[index]
	if not point.is_finite(): return {"ok":false,"reason":"path_point_off_native_map","point_index":index,"point":point,"nonfinite":true}
	# Only a freshly certified native region returning this EXACT point can
	# replace the global map loop. All nonzero/uncertain answers use original.
	# Point0 always performs its original global query and fresh connector.
	if index>0:
		var backend: RefCounted=job.backend.get_ref()
		if is_instance_valid(backend) and backend.native_published_point_zero(job.map,int(job.iteration),point):
			return {"ok":true}
	var closest:=NavigationServer3D.map_get_closest_point(job.map,point)
	var off_map:=closest.distance_to(point)
	if off_map>.12:
		var actual_start: bool=index==0 and point.distance_to(job.token.body.global_position)<=.000001
		if not actual_start or off_map>2.0:
			return {"ok":false,"reason":"path_point_off_native_map","point_index":index,"point":point,"closest":closest,"distance_m":off_map,"is_actual_start":actual_start,"connector_reason":"actual_start_or_gap_bound"}
		if not native_clear_segment(job.token,point,closest):
			return {"ok":false,"reason":"path_point_off_native_map","point_index":index,"point":point,"closest":closest,"distance_m":off_map,"is_actual_start":actual_start,"connector_reason":_last_reason}
	return {"ok":true}

func _initial_advance(job: Dictionary, deadline: int) -> int:
	var guard_started:=Time.get_ticks_usec()
	var reason:=_initial_job_current(job)
	_initial_stats.guard_max_us=maxi(_initial_stats.guard_max_us,Time.get_ticks_usec()-guard_started)
	if not reason.is_empty(): _initial_finish(job,{"ok":false,"reason":reason}); return 0
	var pause_reason:=_initial_observe_pause(job)
	if not _initial_job_live(job): return 0 # Original pause callback may cancel synchronously.
	if not pause_reason.is_empty(): _initial_finish(job,{"ok":false,"reason":pause_reason}); return 0
	if job.paused: return 0 # Only the same canonical Walk may explicitly resume.
	if not job.paused and _initial_pending_idle_us(job,Time.get_ticks_usec())>INITIAL_ADMISSION_NO_PROGRESS_US:
		_initial_finish(job,{"ok":false,"reason":"initial_path_no_progress_timeout"}); return 0
	var path: PackedVector3Array=job.path; var work:=0
	while int(job.index)<path.size() and work<INITIAL_ADMISSION_CHUNK_POINTS and Time.get_ticks_usec()<deadline:
		var atomic_started:=Time.get_ticks_usec()
		var index: int=job.index; var point: Vector3=path[index]
		var projected:=_initial_projection(job,index)
		if not projected.get("ok",false): _initial_finish(job,projected); return work
		var a: Vector3=path[index-1]
		if a.distance_to(point)>_dsh_leg_bound(): _initial_finish(job,{"ok":false,"reason":"path_leg_exceeds_bound"}); return work
		job.distance+=a.distance_to(point)
		if float(job.distance)>2000.0: _initial_finish(job,{"ok":false,"reason":"path_distance_bound"}); return work
		var minv:=Vector2(a.x,a.z).min(Vector2(point.x,point.z))-Vector2.ONE*.36
		var maxv:=Vector2(a.x,a.z).max(Vector2(point.x,point.z))+Vector2.ONE*.36
		for z in range(floori(minv.y/4.1),floori(maxv.y/4.1)+1):
			for x in range(floori(minv.x/4.1),floori(maxv.x/4.1)+1):
				var key:=Vector2i(x,z)
				if not job.buckets.has(key): job.buckets[key]=[]
				job.buckets[key].append([Vector2(a.x,a.z),Vector2(point.x,point.z)])
		job.index+=1; job.verified+=1; work+=1
		job.last_progress_us=Time.get_ticks_usec(); job.progress_pause_us=int(job.paused_us_total)
		_initial_stats.atomic_step_max_us=maxi(_initial_stats.atomic_step_max_us,Time.get_ticks_usec()-atomic_started)
	# Point zero's physical connector is never a stale cross-frame receipt.
	# Project it last and perform the fresh owner/map/claim guard before minting.
	if int(job.index)==path.size() and Time.get_ticks_usec()<deadline:
		var atomic_started:=Time.get_ticks_usec()
		reason=_initial_job_current(job)
		if not reason.is_empty(): _initial_finish(job,{"ok":false,"reason":reason}); return work
		var projected:=_initial_projection(job,0)
		if not projected.get("ok",false): _initial_finish(job,projected); return work
		reason=_initial_job_current(job)
		if not reason.is_empty(): _initial_finish(job,{"ok":false,"reason":reason}); return work
		_cookie+=1
		var token: Dictionary=job.token
		_paths[token.source_id]={"owner":job.owner,"token":token.duplicate(),"cookie":_cookie,"map":job.map,"iteration":job.iteration,"buckets":job.buckets,"vertices":path.duplicate(),"version":_version,"navigation":job.navigation,"backend":job.backend}
		job.verified+=1; work+=1
		_initial_finish(job,{"ok":true,"cookie":_cookie,"points":path.size(),"source_authority":false})
		_initial_stats.atomic_step_max_us=maxi(_initial_stats.atomic_step_max_us,Time.get_ticks_usec()-atomic_started)
	return work

func _initial_erase(ticket: int, revoke: bool) -> void:
	if not _initial_jobs.has(ticket): return
	var job: Dictionary=_initial_jobs[ticket]
	if revoke and job.done and job.result.get("ok",false):
		var owner: RefCounted=job.owner.get_ref()
		if is_instance_valid(owner): revoke_errand_path(owner,job.token,int(job.result.cookie))
	_initial_jobs.erase(ticket); _initial_queue.erase(ticket); _initial_gc.erase(ticket)

func cancel_initial_path_admission(requester: RefCounted, ticket: int) -> bool:
	if not Thread.is_main_thread() or not _initial_jobs.has(ticket) or _initial_jobs[ticket].requester.get_ref()!=requester: return false
	var job: Dictionary=_initial_jobs[ticket]
	if job.done: _initial_stats.cancelled_done+=1
	else: _initial_stats.cancelled_pending+=1
	_initial_erase(ticket,true); _initial_stats.cancelled+=1
	return true

func poll_initial_path_admission(requester: RefCounted, ticket: int) -> Dictionary:
	if not Thread.is_main_thread() or not _initial_jobs.has(ticket) or _initial_jobs[ticket].requester.get_ref()!=requester: return {"done":true,"ok":false,"reason":"initial_path_admission_missing"}
	var job: Dictionary=_initial_jobs[ticket]
	var reason:=_initial_job_current(job) # Fresh even for PENDING/paused/terminal results.
	if not job.done and not reason.is_empty(): _initial_finish(job,{"ok":false,"reason":reason})
	if not job.done and not job.paused and _initial_pending_idle_us(job,Time.get_ticks_usec())>INITIAL_ADMISSION_NO_PROGRESS_US:
		_initial_finish(job,{"ok":false,"reason":"initial_path_no_progress_timeout"})
	if not job.done: return {"done":false,"ok":false,"status":"SUSPENDED" if job.paused else "PENDING"}
	if Time.get_ticks_usec()-int(job.finished_us)>INITIAL_ADMISSION_RESULT_RETENTION_US:
		_initial_result_gc(job)
		return {"done":true,"ok":false,"reason":"initial_path_result_expired"}
	var result: Dictionary=job.result.duplicate(); result.done=true
	if result.get("ok",false):
		if not reason.is_empty() or not current_errand_cookie(job.token.source_id,int(job.token.life_generation),int(result.cookie)):
			_initial_stats.consumed_refused+=1
			_initial_erase(ticket,true)
			return {"done":true,"ok":false,"reason":reason if not reason.is_empty() else "owner_or_map_changed"}
		_initial_stats.consumed_ok+=1
	else: _initial_stats.consumed_refused+=1
	_initial_erase(ticket,false)
	return result

func pump_initial_path_admissions() -> void:
	if not initial_path_admission_enabled() or _disposed or _busy or _initial_pumping or not Thread.is_main_thread(): return
	var frame:=Engine.get_physics_frames()
	if _initial_budget_frame!=frame: _initial_budget_frame=frame; _initial_budget_used_us=0; _initial_budget_calls=0
	var process_frame:=Engine.get_process_frames()
	if _initial_process_budget_frame!=process_frame:
		_initial_process_budget_frame=process_frame; _initial_process_budget_used_us=0; _initial_process_budget_calls=0
	if _initial_process_budget_used_us>=INITIAL_ADMISSION_PROCESS_BUDGET_US:
		_initial_process_budget_skips+=1; return
	if _initial_budget_used_us>=INITIAL_ADMISSION_BUDGET_US: return
	var started:=Time.get_ticks_usec()
	var remaining:=mini(INITIAL_ADMISSION_BUDGET_US-_initial_budget_used_us,INITIAL_ADMISSION_PROCESS_BUDGET_US-_initial_process_budget_used_us)
	var deadline:=started+remaining
	_initial_pumping=true
	var points:=0
	# GC consumes the same budget. A pending stall becomes a retained failure;
	# it cannot discard a successful partial proof just because enqueue is old.
	for unused in mini(8,_initial_gc.size()):
		if Time.get_ticks_usec()>=deadline: break
		var ticket: int=_initial_gc.pop_front()
		if not _initial_jobs.has(ticket): continue
		var job: Dictionary=_initial_jobs[ticket]
		var now:=Time.get_ticks_usec()
		if not is_instance_valid(job.requester.get_ref()) or not is_instance_valid(job.owner.get_ref()):
			if job.done: _initial_stats.requester_gc_done+=1
			else: _initial_stats.requester_gc_pending+=1
			_initial_erase(ticket,true)
		elif job.done and now-int(job.finished_us)>INITIAL_ADMISSION_RESULT_RETENTION_US:
			_initial_result_gc(job)
		else:
			if not job.done and not job.paused and _initial_pending_idle_us(job,now)>INITIAL_ADMISSION_NO_PROGRESS_US:
				var reason:=_initial_job_current(job)
				if reason.is_empty(): reason=_initial_observe_pause(job)
				if not _initial_job_live(job): continue
				if not reason.is_empty(): _initial_finish(job,{"ok":false,"reason":reason})
				elif not job.paused: _initial_finish(job,{"ok":false,"reason":"initial_path_no_progress_timeout"})
				if job.done: _initial_queue.erase(ticket)
			_initial_gc.append(ticket)
	var suspended_seen: Dictionary={}
	while not _initial_queue.is_empty() and Time.get_ticks_usec()<deadline:
		var ticket: int=_initial_queue.pop_front()
		if not _initial_jobs.has(ticket): continue
		var job: Dictionary=_initial_jobs[ticket]
		if job.done: continue
		if suspended_seen.has(ticket):
			_initial_queue.push_front(ticket); break # No paused hot-loop or auto-resume.
		points+=_initial_advance(job,deadline)
		if _initial_job_live(job) and not job.done:
			if job.paused: suspended_seen[ticket]=true
			_initial_queue.append(ticket)
	var spent:=Time.get_ticks_usec()-started
	_initial_budget_used_us+=spent; _initial_budget_calls+=1
	_initial_process_budget_used_us+=spent; _initial_process_budget_calls+=1
	_initial_process_budget_max_us=maxi(_initial_process_budget_max_us,_initial_process_budget_used_us)
	_initial_budget_max_us=maxi(_initial_budget_max_us,_initial_budget_used_us)
	_initial_stats.last_frame=frame; _initial_stats.last_frame_us=spent; _initial_stats.last_points=points; _initial_stats.points+=points
	_initial_pumping=false

func snapshot_initial_path_admissions() -> Dictionary:
	var result: Dictionary=_initial_stats.duplicate()
	result.queued=_initial_queue.size(); result.jobs=_initial_jobs.size()
	result.global_frame=_initial_budget_frame; result.global_frame_us=_initial_budget_used_us; result.global_frame_calls=_initial_budget_calls; result.max_frame_us=_initial_budget_max_us
	result.no_progress_timeout_us=INITIAL_ADMISSION_NO_PROGRESS_US; result.result_retention_us=INITIAL_ADMISSION_RESULT_RETENTION_US
	result.global_process_frame=_initial_process_budget_frame; result.global_process_frame_us=_initial_process_budget_used_us; result.global_process_frame_calls=_initial_process_budget_calls
	result.max_process_frame_us=_initial_process_budget_max_us; result.process_budget_us=INITIAL_ADMISSION_PROCESS_BUDGET_US; result.process_budget_skips=_initial_process_budget_skips
	result.pending=0; result.done=0; result.suspended=0; result.entries=[]
	var now:=Time.get_ticks_usec()
	for ticket: int in _initial_jobs:
		var job: Dictionary=_initial_jobs[ticket]
		if job.done: result.done+=1
		else: result.pending+=1
		if job.paused: result.suspended+=1
		result.entries.append({"ticket":ticket,"index":job.verified,"point_count":job.path.size(),"done":job.done,"source_id":job.token.source_id,"paused":job.paused,"enqueue_age_us":now-int(job.started_us),"no_progress_us":_initial_pending_idle_us(job,now),"result_age_us":now-int(job.get("finished_us",now))})
	result.retired=int(result.consumed_ok)+int(result.consumed_refused)+int(result.cancelled_pending)+int(result.cancelled_done)+int(result.requester_gc_pending)+int(result.requester_gc_done)+int(result.result_gc_ok)+int(result.result_gc_refused)+int(result.disposed_jobs)
	result.conservation_ok=int(result.created)==int(result.jobs)+int(result.retired)
	return result


func _initial_job_live(job: Dictionary) -> bool:
	return _initial_jobs.has(int(job.ticket)) and is_same(_initial_jobs[int(job.ticket)],job)

func _initial_paused_us(job: Dictionary, now: int) -> int:
	return int(job.paused_us_total)+(maxi(0,now-int(job.pause_started_us)) if job.paused else 0)

func _initial_pending_idle_us(job: Dictionary, now: int) -> int:
	return maxi(0,now-int(job.last_progress_us)-(_initial_paused_us(job,now)-int(job.progress_pause_us)))

func _initial_set_paused(job: Dictionary, paused: bool) -> void:
	if bool(job.paused)==paused: return
	var now:=Time.get_ticks_usec()
	if paused: job.pause_started_us=now
	else: job.paused_us_total=int(job.paused_us_total)+maxi(0,now-int(job.pause_started_us)); job.pause_started_us=0
	job.paused=paused

func _initial_observe_pause(job: Dictionary) -> String:
	var host: RefCounted=_host.get_ref() if _host!=null else null
	if not is_instance_valid(host): return "owner_or_map_changed"
	var records: Variant=host.get("_records")
	if not records is Dictionary: return "owner_or_map_changed"
	var record: Dictionary=records.get(job.token.source_id,{})
	var pause: Callable=record.get("walk_pause",Callable())
	if not pause.is_valid(): return ""
	var paused:=bool(pause.call())
	if not _initial_job_live(job): return "initial_path_cancelled"
	var reason:=_initial_job_current(job) # A custom original pause may mutate/cancel.
	if not reason.is_empty(): return reason
	if paused: _initial_set_paused(job,true)
	return "" # False does NOT resume a latched job. Same Walk must do that.

func set_initial_path_admission_paused(requester: RefCounted, ticket: int, paused: bool) -> bool:
	if not Thread.is_main_thread() or _disposed or _busy or not _initial_jobs.has(ticket): return false
	var job: Dictionary=_initial_jobs[ticket]
	if job.requester.get_ref()!=requester or not is_instance_valid(requester) or requester.get_script()!=load("res://scripts/npc_daily_walk.gd"): return false
	var reason:=_initial_job_current(job)
	if not reason.is_empty():
		if not job.done: _initial_finish(job,{"ok":false,"reason":reason})
		return false
	_initial_set_paused(job,paused)
	return true

func _initial_result_gc(job: Dictionary) -> void:
	if not _initial_job_live(job) or not job.done: return
	if job.result.get("ok",false): _initial_stats.result_gc_ok+=1
	else: _initial_stats.result_gc_refused+=1
	_initial_stats.expired+=1 # Compatibility: now ONLY reclaimed terminal results.
	_initial_erase(int(job.ticket),true)
