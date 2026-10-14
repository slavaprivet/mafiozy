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
# --city-policy-token-memo=0 (default) re-asks the host on every _token_current call.
var _dsh_split := -1
var _dsh_split_on := false
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
	for building: Dictionary in block.buildings:
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

# DSH_NAVSTEP3: --city-policy-token-memo=1 lets one source_admit() frame reuse the
# _token_current() answer it already computed. The memo is the Array that frame owns, so
# no other entry point can ever see it; 0 (default) re-asks the host every time.
func _memo_flag() -> int:
	if _dsh_memo < 0:
		_dsh_memo = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-policy-token-memo="):
				_dsh_memo = maxi(0, int(argument.trim_prefix("--city-policy-token-memo=")))
	return _dsh_memo

func _dsh_add(key: String, started: int) -> void:  # DSH_NAVSTEP3
	_dsh_p[key] = int(_dsh_p[key]) + Time.get_ticks_usec() - started

func _dsh_report() -> void:  # DSH_NAVSTEP3
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

func source_admit(point: Vector3, id: String, generation: int, radius: float, purpose: String) -> bool:
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
	var dsh_memo: Array = [] if _dsh_memo == 1 else NO_MEMO  # DSH_NAVSTEP3: frame-owned memo
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
	var token:=_daily_token(id,generation)
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
	var dsh_path_ok: bool = not (road and not handoff) or _path_contains(id,point)  # DSH_NAVSTEP3
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

func support_height(point: Vector3, id: String, generation: int) -> float:
	if not Thread.is_main_thread() or _busy or not _owner_allowed(id, generation) or not point.is_finite(): return NAN
	var index := _index(point)
	if index < 0: return NAN
	var reference := Vector3(point.x, _heights[index], point.z)
	if not source_admit(reference, id, generation, RADIUS, "placement"): return NAN
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
	return true

func _daily_token(id: String, generation: int) -> Dictionary:
	if _host==null or not is_instance_valid(_host.get_ref()): return {}
	var host: RefCounted=_host.get_ref()
	var claims: Variant=host.get("_daily_activities")
	if not claims is Dictionary or not claims.has(id): return {}
	var token: Dictionary=claims[id].binding
	if token.life_generation!=generation or not _token_current(token): return {}
	return token

func _token_current(token: Dictionary, activity_owner: RefCounted=null, memo: Array=NO_MEMO) -> bool:
	# DSH_NAVSTEP3: --city-policy-token-memo=1 reuses the answer this same source_admit()
	# frame already computed for this exact (source_id, life_generation). The memo Array
	# belongs to that frame, so it cannot outlive the call or be seen by another entry
	# point; a call that carries an activity_owner is never memoised.
	if _dsh_memo == 1 and not memo.is_empty():
		if int(memo[0]) == 1 and str(memo[1]) == str(token.get("source_id","")) and int(memo[2]) == int(token.get("life_generation",-1)):
			if _dsh_split_on: _dsh_memo_hits += 1
			return bool(memo[3])
	var dsh_t0 := Time.get_ticks_usec() if _dsh_split_on else 0  # DSH_NAVSTEP3
	var dsh_current := false
	if not Thread.is_main_thread() or _disposed or _host==null or not is_instance_valid(_host.get_ref()) or not _owner_allowed(str(token.get("source_id","")),int(token.get("life_generation",-1))): dsh_current = false
	else:
		var host: RefCounted=_host.get_ref()
		# The host may be busy while invoking its current local movement adapter.
		# This identity/death/capsule gate deliberately does not use target_current.
		if not host._local_walker_current(token): dsh_current = false
		else:
			var lease: Dictionary=host.daily_activity_status(token.source_id)
			dsh_current = lease.get("current",false) and lease.get("life_generation")==token.life_generation and is_instance_valid(lease.get("owner")) and (activity_owner==null or lease.owner==activity_owner)
	if _dsh_split_on:
		_dsh_p["tc_calls"] = int(_dsh_p["tc_calls"]) + 1
		_dsh_add("tc_us", dsh_t0)
	if _dsh_memo == 1 and not memo.is_empty() and activity_owner == null:
		memo.clear()
		memo.append(1); memo.append(str(token.get("source_id",""))); memo.append(int(token.get("life_generation",-1))); memo.append(dsh_current)
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
func current_errand_cookie(id: String, life_generation: int, cookie: int) -> bool:
	if not _paths.has(id): return false
	var path: Dictionary = _paths[id]
	var owner: RefCounted = path.owner.get_ref()
	if not is_instance_valid(owner) or int(path.token.get("life_generation", -1)) != life_generation or int(path.cookie) != cookie or path.version != _version or not _token_current(path.token, owner): return false
	var host: RefCounted = _host.get_ref()
	var navigation: RefCounted = _ordinary_navigation(host)
	if navigation == null or not is_instance_valid(path.backend.get_ref()) or path.navigation.get_ref() != navigation or path.backend.get_ref() != navigation.get("_backend") or not path.map.is_valid(): return false
	return path.backend.get_ref().map_rid() == path.map and NavigationServer3D.map_get_iteration_id(path.map) == path.iteration

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

func _path_contains(id: String, point: Vector3) -> bool:
	if not _paths.has(id): return false
	var path: Dictionary=_paths[id]
	if not is_instance_valid(path.owner.get_ref()) or not _token_current(path.token,path.owner.get_ref()) or path.version!=_version or not path.map.is_valid(): return false
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

func _native_floor_square(token: Dictionary, point: Vector3) -> bool:
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
	var scene: Node3D = _scene.get_ref() if _scene != null else null
	if is_instance_valid(scene) and scene.tree_exiting.is_connected(dispose): scene.tree_exiting.disconnect(dispose)
	_paths.clear();_host=null;_owners.clear(); _states.clear(); _floors.clear(); _cells.clear(); _land.clear(); _heights.clear(); _ray = null
