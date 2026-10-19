extends RefCounted
## Local immutable-session residents. No source births, agenda, save or authority.
## Caller owns navigation pump/door revisions; this host alone moves its bodies.
const Provider = preload("res://scripts/npc_visual/npc_preview_source_provider.gd")
const Cache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const Navigation = preload("res://scripts/navigation/preview_navigation_host.gd")
## The living-city scene runs the ported city navigation stack (city engine +
## city-era host) instead of the curated preview host. Both are accepted here;
## the palazzo-only preview keeps using Navigation above.
const CityNavigation = preload("res://scripts/city/runtime/npc_city_navigation_host.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const Gait = preload("res://scripts/preview_locomotion.gd")
const Ragdoll = preload("res://scripts/npc_visual/npc_ragdoll_host_v2.gd")
const PreviewActivity = preload("res://scripts/npc_visual/npc_preview_activity.gd")
const ContactRetaliation = preload("res://scripts/npc_visual/npc_contact_retaliation.gd")
const REJECTED_PACKET := "384f1f2d2b673bde13a49cfdff2f88b4e84469801b1f572624c53259a472901d"
const FOOTPRINT := .738 # Source _npcBodyPassable radius .18 * native scale 4.1.
const HEIGHT := 1.9
const SOURCE_RENDER_YAW_SECONDS := .1 # npc_population.mjs default interpolationSeconds.
const PREVIEW_GOAL_ATTEMPTS_PER_STEP := 2
const PREVIEW_DIRECTIONS := [Vector3(1,0,0), Vector3(.7071067811865476,0,-.7071067811865476), Vector3(0,0,-1), Vector3(-.7071067811865476,0,-.7071067811865476), Vector3(-1,0,0), Vector3(-.7071067811865476,0,.7071067811865476), Vector3(0,0,1), Vector3(.7071067811865476,0,.7071067811865476)]
const MAX_RESIDENTS := 3
## The living city admits the whole pinned packet (287 rows); the curated
## palazzo preview keeps its three-resident bound above.
const MAX_CITY_RESIDENTS := 288
const PLACEMENT_CONTEXT := "a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c"
const PLACEMENT_SOURCE := "9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5"
const PLACEMENT_PHASE := "AFTER_FULL_DEFERRED_POPULATION_CALLBACK_BEFORE_ANY_SERVER_SNAPSHOT_BEFORE_NATIVE_RESOLVER"
const SUPPORT_OFFSETS := [Vector2.ZERO, Vector2(-FOOTPRINT, -FOOTPRINT), Vector2(-FOOTPRINT, FOOTPRINT), Vector2(FOOTPRINT, -FOOTPRINT), Vector2(FOOTPRINT, FOOTPRINT)]
var _scene: WeakRef
var _navigation: RefCounted
var _local_navigation_lease := {}
var _local_navigation_serial := 0
var _admit: Callable
var _support: Callable
var _records: Dictionary = {}
var _session := ""
var _manifest := PackedByteArray()
var _manifest_sha := ""
var _directory := ""
var _busy := false
var _disposed := false
var _dispose_requested := false
var _placement_receipt := {}
var _placement_current: Callable
var _walk_preview_enabled := false
var _walk_preview_clock := 0.0
var _walk_preview: Dictionary = {}
var _ragdolls: Dictionary = {}
var _box: BoxShape3D
var _ray := PhysicsRayQueryParameters3D.new()
var _dsh_report_ms := 0  # DSH_ROUND2
# DSH_RECORDLOOP: --city-yaw-skip=1 skips the per-record yaw interpolation for a
# resident that is already at its final displayed yaw and not walking. Default 0
# keeps the original per-record arithmetic. --city-rag-mode=0 restores the old
# rag.status().mode read (a Dictionary plus a binding duplicate per record) for an
# A/B of exactly that line; default 1 reads the mode field status() copies from.
var _dsh_yaw_skip := -1
var _dsh_rag_mode := -1

func _yaw_skip() -> bool:
	if _dsh_yaw_skip < 0:
		# DSH_YAWFAST: measured A/B - skipping the settled-display write tail gives
		# resid p50 -13.4% and total p50 -1208 us (-5.9%) with identical behaviour
		# (DSH_LIVES bit-identical). --city-yaw-skip=0 restores the old path.
		_dsh_yaw_skip = 1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-yaw-skip="):
				_dsh_yaw_skip = maxi(0, int(argument.trim_prefix("--city-yaw-skip=")))
	return _dsh_yaw_skip > 0

func _rag_mode_direct() -> bool:
	if _dsh_rag_mode < 0:
		_dsh_rag_mode = 1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-rag-mode="):
				_dsh_rag_mode = maxi(0, int(argument.trim_prefix("--city-rag-mode=")))
	return _dsh_rag_mode != 0
# DSH_RESID3: optional cost levers, parsed once from OS.get_cmdline_user_args().
# Every default (flag absent, or 0) reproduces the previous behaviour exactly.
var _dsh_recover_ttl := -1  # --city-recover-ttl=N ticks; 0 = retry every tick
var _dsh_recover_skips := 0  # DSH_RESID3 telemetry
var _dsh_sim_stride := -1  # --city-sim-cadence=N ticks; 0/1 = everyone full rate
var _dsh_sim_far_m := -1.0  # --city-sim-far-m=M metres
var _dsh_timing := -1  # DSH_MOTION: --city-timing=0 skips the per-record DSH_ROUND2 samples only
# DSH_SIMLOD: distance-tiered SIMULATION cadence. Every flag below defaults to the
# value that reproduces today's behaviour exactly: --city-sim-lod absent or 0
# leaves every resident on the full per-city-step path.
var _dsh_simlod := -1  # --city-sim-lod=1 enables the tiers; 0 = today
var _dsh_simlod_near_m := -1.0  # --city-sim-tier-near-m=30 (m); inside it, never deferred
var _dsh_simlod_mid_m := -1.0  # --city-sim-tier-mid-m=120 (m)
var _dsh_simlod_hyst_m := -1.0  # --city-sim-lod-hyst-m=8 (m) outward hysteresis
var _dsh_simlod_near_stride := -1  # --city-sim-near-stride (tier 0 never defers anyway)
var _dsh_simlod_mid_stride := -1  # --city-sim-mid-stride=2 city steps
var _dsh_simlod_far_stride := -1  # --city-sim-far-stride=4 city steps
var _dsh_simlod_max_delta := -1.0  # --city-sim-max-delta=0.2 (s) carried-delta ceiling
# DSH_SIMLOD: the five boundary squares, resolved once by _simlod_on() so the
# per-record tier decision is float compares plus at most one Dictionary write.
var _dsh_simlod_near_sq := -1.0  # near_m * near_m
var _dsh_simlod_mid_sq := -1.0  # mid_m * mid_m
var _dsh_simlod_out_near_sq := -1.0  # (near_m + hyst)^2
var _dsh_simlod_out_mid_sq := -1.0  # (mid_m + hyst)^2
var _dsh_simlod_in_mid_sq := -1.0  # (mid_m - hyst)^2
var _overlap := PhysicsShapeQueryParameters3D.new()
var _stats := {"admissions": 0, "rejections": 0, "admit_us_max": 0, "step_us_max": 0, "steps": 0}


# --- ported from city daily-cycle host (dsh_living_city_01) ---
const MAX_VISUAL_HEIGHT := 2.05
const CITY_PACKET_SHA := "b9c810e81b8b3da6afc048a32c4fe50745f32e4b15d0fd55ff876e69c35c54a1"
const CITY_SPAWN_ATTEMPTS := 512
var _city_spawn_context: Dictionary = {}
var _rig_tree: WeakRef
var _rig_tree_epoch := 0
var _rig_cache := {}
var _rig_cache_scans := 0
var _transport_lease := {}
var _transport_serial := 0
var _daily_activities := {}
var _daily_serial := 0
var _dsh_target_fast_cache := -1  # DSH_TARGETFAST: --city-daily-target-fast, 1 = O(1) meta index (default), 0 = original scan
var _dsh_pause_push := -1  # DSH_PAUSEPUSH: --city-pause-push, 1 = read the owner's published gate (default)
# --- end ported fields ---

func configure(scene: Node3D, navigation: RefCounted, packet: PackedByteArray, trust: Dictionary, prepared_manifest: PackedByteArray, prepared_directory: String, owners: Dictionary, source_admit: Callable, support_height: Callable) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _scene != null: return {"ok": false, "error": "lifetime"}
	if not is_instance_valid(scene) or not scene.is_inside_tree() or not scene.global_transform.is_equal_approx(Transform3D.IDENTITY) or not (navigation is Navigation or navigation is CityNavigation) or not source_admit.is_valid() or not support_height.is_valid(): return {"ok": false, "error": "host_contract"}
	if navigation._root == null or navigation._root.get_ref() != scene or navigation.state() in ["UNATTACHED", "DISPOSED", "INVALID_GEOMETRY"]: return {"ok": false, "error": "navigation_world"}
	if not trust.get("accepted") is bool or not trust.accepted or not trust.get("packet_sha256") is String or trust.packet_sha256 == REJECTED_PACKET or not trust.get("sources") is Dictionary or not trust.get("session_id") is String or not trust.get("prepared_sha256") is String: return {"ok": false, "error": "external_acceptance_required"}
	var loaded: Dictionary = Provider.load_verified(packet, trust.packet_sha256, trust.sources)
	if not loaded.ok: return loaded
	var provider: RefCounted = loaded.provider
	var receipt: Dictionary = provider.session_receipt()
	var rows: Array = provider.candidates()
	var resident_limit: int = MAX_CITY_RESIDENTS if navigation is CityNavigation else MAX_RESIDENTS
	if receipt.session_id != trust.session_id or rows.is_empty() or rows.size() > resident_limit or owners.size() != rows.size(): return {"ok": false, "error": "session_or_owner_count"}
	# The city block carries taller authored residents than the curated preview.
	var height_limit: float = MAX_VISUAL_HEIGHT if navigation is CityNavigation else HEIGHT
	var checked := {}
	for row: Dictionary in rows:
		var owner: Variant = owners.get(row.source_id)
		if not owner is Queue.Owner or owner.dead or owner.source_id != row.source_id or owner.life_generation != 1: return {"ok": false, "error": "owner_identity"}
		var raw: Dictionary = row.source_raw
		var descriptor: Dictionary = JSON.parse_string(row.descriptor_json)
		if not (descriptor.get("height") is float or descriptor.get("height") is int) or not is_finite(float(descriptor.height)) or descriptor.height < 1.65: return {"ok": false, "error": "source_height"}
		# This bounded host accepts the existing healthy ordinary initialization
		# phase only. It must not turn injured/dead/seated source actors into walkers.
		for field: String in ["speed", "_fatigue", "_fear", "hp", "max_hp", "ang"]:
			if not (raw.get(field) is float or raw.get(field) is int) or not is_finite(float(raw[field])): return {"ok": false, "error": "source_motion_fields"}
		if raw.hp <= 0 or raw.hp != raw.max_hp or raw.speed <= 0 or raw._fatigue < 0 or raw._fatigue > 1 or raw._fear < 0 or raw._fear > 1 or descriptor.height > height_limit: return {"ok": false, "error": "unsupported_source_state"}
		for field: String in ["dead", "_empireBoss", "_forcedCrawl", "_severMask", "_routineSpeedK", "carried", "evacuated"]:
			if raw.get(field): return {"ok": false, "error": "unsupported_source_state"}
		var speed := minf(minf(raw.speed * .4, 1.8 / 4.1) * (1 - raw._fatigue * .35) * (1 + raw._fear * .5), 1.8 / 4.1) * 4.1
		checked[row.source_id] = {"row": row, "owner": owner, "generation": owner.life_generation, "speed": speed, "status": "PENDING_PLACEMENT", "reason": "", "attempted": false, "body": null, "gait": null, "activity": null, "motion": null, "request": -1, "origin": Vector3.ZERO}
	var city_context: Dictionary = {}
	# Explicit new local session only. The verified city provider still owns
	# packet/schema/source hashes; this records bounded loaded-world identity.
	if trust.packet_sha256 == CITY_PACKET_SHA and provider._packet.get("schema") == "mafiozi.npc-city-session/v1" and provider._packet.get("mode") == "NEW_SESSION_BOOTSTRAP":
		var block: Variant = scene.get("_block")
		if not block is Dictionary or not block.get("surface") is Dictionary: return {"ok":false,"error":"city_spawn_surface"}
		var surface: Dictionary = block.surface
		var crop: Dictionary = provider._packet.coordinates.crop
		if surface.get("cellSize") != 4.1 or surface.get("startRow") != crop.r_min or surface.get("startCol") != crop.c_min or surface.get("rows") != crop.r_max-crop.r_min or surface.get("cols") != crop.c_max-crop.c_min: return {"ok":false,"error":"city_spawn_bounds"}
		city_context = {"block":block,"surface":surface,"crop":crop.duplicate(true),"session_id":receipt.session_id,"packet_sha256":CITY_PACKET_SHA}
	_city_spawn_context = city_context
	_scene = weakref(scene); _navigation = navigation; _admit = source_admit; _support = support_height
	_session = receipt.session_id; _records = checked; _manifest = prepared_manifest.duplicate()
	_manifest_sha = trust.prepared_sha256; _directory = prepared_directory
	_box = BoxShape3D.new(); _box.size = Vector3(FOOTPRINT * 2, HEIGHT, FOOTPRINT * 2)
	_ray.collision_mask = 1; _overlap.shape = _box; _overlap.collision_mask = 1 | 256; _overlap.margin = .001
	scene.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)
	return {"ok": true, "candidates": rows.size(), "admitted": 0, "session_id": _session}

func _living(record: Dictionary) -> bool:
	var owner: RefCounted = record.owner
	return not _disposed and not _dispose_requested and not owner.dead and owner.source_id == record.row.source_id and owner.life_generation == record.generation

func _physical_occupied(id: String) -> bool:
	return _ragdolls.has(id) and _ragdolls[id].status().mode in ["ACTIVE", "RECOVERING", "RECOVERY_HOLD"]

func _scene_alive() -> bool:
	var scene: Node3D = _scene.get_ref() if _scene != null else null
	return is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion()

func _leave_busy() -> void:
	_busy = false
	if _dispose_requested: dispose()

func _source_admits(point: Vector3, record: Dictionary, purpose: String) -> bool:
	if not _living(record) or not _scene_alive() or not point.is_finite() or not _admit.is_valid(): return false
	var accepted: Variant = _admit.call(point, record.row.source_id, record.generation, FOOTPRINT, purpose)
	return accepted is bool and accepted and _living(record) and _scene_alive()

func _physical_clear(point: Vector3, excluded: Array[RID]) -> bool:
	var scene: Node3D = _scene.get_ref()
	if not is_instance_valid(scene) or not scene.is_inside_tree() or scene.is_queued_for_deletion(): return false
	var space := scene.get_world_3d().direct_space_state
	# Preserve source centre + four square corners. Do not replace by nav radius.
	_ray.exclude = excluded
	for offset: Vector2 in SUPPORT_OFFSETS:
		var probe := point + Vector3(offset.x, 0, offset.y)
		_ray.from = probe + Vector3.UP * .30; _ray.to = probe - Vector3.UP * .30
		var hit: Dictionary = space.intersect_ray(_ray)
		if hit.is_empty() or hit.normal.y < .70 or absf(hit.position.y - point.y) > .18: return false
	_overlap.exclude = excluded
	_overlap.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (HEIGHT * .5 + .025))
	return space.intersect_shape(_overlap, 1).is_empty()

## Godot's broadphase may not contain a body added earlier in this same
## physics frame. Reserve its source square footprint until the next sync.
func _owned_clear(point: Vector3, identity: String) -> bool:
	for id: String in _records:
		if id == identity: continue
		var other: Dictionary = _records[id]
		if not is_instance_valid(other.body): continue
		# DSH_RESID3: _physical_occupied() is false for every id that is not in
		# _ragdolls, so this guard yields the identical value while the ~284
		# non-ragdoll residents stop paying one GDScript call in every scan.
		var physical_lease: bool = false
		if _ragdolls.has(id): physical_lease = _physical_occupied(id)
		var physical_failed: bool = other.get("physical_failed",false)
		if other.body.collision_layer == 0 and not physical_lease and not physical_failed: continue
		# The freshly activated rigid pool may not yet be in the broadphase in
		# this same frame. Reserve its latest anchor independently of the query.
		var occupied: Vector3 = other.body.global_position
		if physical_lease or physical_failed:
			occupied = other.get("physical_anchor_world",occupied)
		if absf(point.y - occupied.y) < HEIGHT and absf(point.x - occupied.x) <= FOOTPRINT * 2.0 + .001 and absf(point.z - occupied.z) <= FOOTPRINT * 2.0 + .001:
			return false
	return true

func _route_admit(point: Vector3, identity: String, generation: int) -> bool:
	if _disposed or not _records.has(identity): return false
	var record: Dictionary = _records[identity]
	if record.generation != generation or record.get("physical_failed",false) or _physical_occupied(identity) or not is_instance_valid(record.body): return false
	# Navigation invokes this during its own pump as well as our step. Close the
	# host API against callback reentry in both cases.
	var was_busy := _busy; _busy = true
	var allowed := _source_admits(point, record, "route") and _physical_clear(point, [record.body.get_rid()])
	_busy = was_busy
	if not _busy and _dispose_requested: dispose()
	return allowed

func admit_next() -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _scene == null: return {"status": "UNAVAILABLE"}
	if not _placement_receipt.is_empty(): return {"status":"PENDING_PLACEMENT", "reason":"candidate_required"}
	var selected := ""
	for id: String in _records:
		if not _records[id].attempted: selected = id; break
	if selected.is_empty(): return {"status": "COMPLETE"}
	_busy = true
	var started := Time.get_ticks_usec()
	var record: Dictionary = _records[selected]
	record.attempted = true
	var result := _admit_record(record)
	_stats.admit_us_max = maxi(_stats.admit_us_max, Time.get_ticks_usec() - started)
	_leave_busy()
	return result

## Explicit local QA staging. Source birth coordinates remain immutable in the
## packet; this is neither the original 326-actor placement nor saved progress.
func admit_preview_stage(identity: String, r: float, c: float) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _scene == null or not _placement_receipt.is_empty(): return {"status":"UNAVAILABLE"}
	if not _records.has(identity) or not is_finite(r) or not is_finite(c) or r < 1.0 or r >= 30.0 or c < 76.0 or c >= 106.0: return {"status":"REJECTED", "reason":"preview_stage_bounds"}
	var record: Dictionary = _records[identity]
	if record.status != "PENDING_PLACEMENT" or is_instance_valid(record.body): return {"status":"REJECTED", "reason":"already_admitted"}
	_busy = true
	var started := Time.get_ticks_usec()
	var result := _admit_record(record, {}, {"r":r, "c":c})
	_stats.admit_us_max = maxi(_stats.admit_us_max, Time.get_ticks_usec() - started)
	_leave_busy()
	return result

func _reject(record: Dictionary, reason: String) -> Dictionary:
	record.reason = reason; _stats.rejections += 1
	if reason == "owner_invalid": record.status = "REMOVED"
	return {"status": record.status, "source_id": record.row.source_id, "reason": reason}

## One captured full-source placement batch. The validator must prove completed
## all-326 solving and current source/scene/life leases, not just echo labels.
## Never modifies immutable source_raw or executes diagnostic route commands.
func bind_placement_source(receipt: Dictionary, current_validator: Callable) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _scene == null or not _placement_receipt.is_empty(): return {"ok":false,"error":"lifetime"}
	if not current_validator.is_valid() or receipt.get("context_sha256") != PLACEMENT_CONTEXT or receipt.get("source_world_sha256") != PLACEMENT_SOURCE or receipt.get("session_id") != _session or receipt.get("phase") != PLACEMENT_PHASE: return {"ok":false,"error":"placement_binding"}
	var provider: Variant = receipt.get("provider")
	if not provider is Dictionary or provider.get("semantics") != "ROLE_BODY_PASS": return {"ok":false,"error":"placement_provider"}
	for field in ["id", "version", "sha256"]:
		if not provider.get(field) is String or provider[field].is_empty(): return {"ok":false,"error":"placement_provider"}
	if provider.sha256.length() != 64 or not provider.sha256.is_valid_hex_number(): return {"ok":false,"error":"placement_provider"}
	for record: Dictionary in _records.values():
		if is_instance_valid(record.body) or record.status != "PENDING_PLACEMENT": return {"ok":false,"error":"already_admitted"}
	_placement_receipt = receipt.duplicate(true)
	_placement_current = current_validator
	return {"ok":true}

func _candidate_current(candidate: Dictionary, record: Dictionary) -> bool:
	if _placement_receipt.is_empty() or not _placement_current.is_valid() or not _living(record): return false
	var scene: Node3D = _scene.get_ref()
	if not is_instance_valid(scene) or not scene.is_inside_tree() or scene.is_queued_for_deletion(): return false
	var accepted: Variant = _placement_current.call(candidate.duplicate(true), record.row.source_id, record.generation)
	return accepted is bool and accepted and _placement_current.is_valid() and _living(record) and _scene_alive()

func admit_candidate(candidate: Dictionary, generation: int) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _scene == null or _placement_receipt.is_empty(): return {"status":"UNAVAILABLE"}
	var identity: Variant = candidate.get("raw_id")
	if not identity is String or not _records.has(identity): return {"status":"REJECTED", "reason":"candidate_identity"}
	var record: Dictionary = _records[identity]
	if generation != record.generation or not _living(record): return {"status":"REJECTED", "reason":"owner_invalid"}
	if record.status != "PENDING_PLACEMENT" or is_instance_valid(record.body): return {"status":"REJECTED", "reason":"already_admitted"}
	for field in ["context_sha256", "source_world_sha256", "session_id", "phase", "provider"]:
		if candidate.get(field) != _placement_receipt.get(field): return {"status":"REJECTED", "reason":"candidate_provenance"}
	if candidate.get("kind") != "resident" or candidate.get("status") not in ["original", "relocated"] or not candidate.get("object_key") is String or candidate.object_key.is_empty() or not candidate.get("physical_admission") is bool or candidate.physical_admission: return {"status":"REJECTED", "reason":"candidate_schema"}
	for field in ["r", "c"]:
		if not (candidate.get(field) is float or candidate.get(field) is int) or not is_finite(float(candidate[field])): return {"status":"REJECTED", "reason":"candidate_position"}
	if candidate.r < 0.0 or candidate.r >= 200.0 or candidate.c < 0.0 or candidate.c >= 180.0: return {"status":"REJECTED", "reason":"candidate_position"}
	_busy = true
	var started := Time.get_ticks_usec()
	var owned := candidate.duplicate(true)
	var result := _admit_record(record, owned)
	_stats.admit_us_max = maxi(_stats.admit_us_max, Time.get_ticks_usec() - started)
	_leave_busy()
	return result

func _admit_record(record: Dictionary, candidate: Dictionary = {}, preview_stage: Dictionary = {}) -> Dictionary:
	if not _living(record): return _reject(record, "owner_invalid")
	if not candidate.is_empty() and not _candidate_current(candidate, record): return _reject(record, "placement_lease_changed")
	if not _support.is_valid(): return _reject(record, "support_provider_unavailable")
	var scene: Node3D = _scene.get_ref()
	if not is_instance_valid(scene): return _reject(record, "scene_unavailable")
	# City mode: this host is the only creator of resident bodies, and the per-record
	# reference is already the authoritative index (every other admission guard in this
	# class uses is_instance_valid(record.body)). The scene scan walked 29,571 nodes and
	# measured 14.3 ms per attempt, while the fallback placement loop can call it about
	# 146k times. The preview path keeps the scan because it shares the scene with other
	# body owners, so its exact semantics are unchanged.
	if _city_spawn_context.is_empty():
		for node: Node in scene.find_children("*", "CharacterBody3D", true, false):
			if node.get_meta("source_id", "") == record.row.source_id: return _reject(record, "duplicate_source_body")
	elif is_instance_valid(record.body):
		return _reject(record, "duplicate_source_body")
	var raw: Dictionary = record.row.source_raw
	var point := Vector3(float(raw.c) * 4.1 - 395.65, 0, float(raw.r) * 4.1 - 45.1)
	if not candidate.is_empty(): point = Vector3(float(candidate.c) * 4.1 - 395.65, 0, float(candidate.r) * 4.1 - 45.1)
	if not preview_stage.is_empty(): point = Vector3(float(preview_stage.c) * 4.1 - 395.65, 0, float(preview_stage.r) * 4.1 - 45.1)
	var height: Variant = _support.call(point, record.row.source_id, record.generation)
	if not (height is float or height is int) or not is_finite(float(height)): return _reject(record, "support_unknown")
	point.y = height
	if not _source_admits(point, record, "placement") or not _owned_clear(point, record.row.source_id) or not _physical_clear(point, []): return _reject(record, "current_placement_blocked")
	var loaded: Dictionary = Cache.load_verified(_manifest, _manifest_sha, record.row.bridge_id, record.row.descriptor_sha256, _directory)
	if not loaded.ok: return _reject(record, "visual:" + str(loaded.error))
	var cache: RefCounted = loaded.cache
	var appearance: Dictionary = cache.instantiate_actor()
	cache.dispose()
	if not appearance.ok: return _reject(record, "visual:" + str(appearance.error))
	# Callbacks and asset loading must not turn stale admission into a spawn.
	if not _living(record) or not _source_admits(point, record, "placement") or (not candidate.is_empty() and not _candidate_current(candidate, record)) or not _owned_clear(point, record.row.source_id) or not _physical_clear(point, []):
		appearance.visual.free()
		return _reject(record, "placement_changed_before_spawn")
	var body := CharacterBody3D.new()
	body.name = record.row.bridge_id
	body.collision_layer = 1; body.collision_mask = 1
	body.floor_snap_length = .25
	body.set_meta("source_id", record.row.source_id); body.set_meta("session_id", _session)
	body.set_meta("descriptor_sha256", record.row.descriptor_sha256)
	body.set_meta("placement_mode", "PREVIEW_STAGE" if not preview_stage.is_empty() else "SOURCE_CANDIDATE" if not candidate.is_empty() else "SOURCE_BIRTH")
	var capsule := CapsuleShape3D.new(); capsule.radius = .36; capsule.height = HEIGHT
	var shape := CollisionShape3D.new(); shape.shape = capsule; shape.position.y = HEIGHT * .5
	body.add_child(shape)
	var motion := Node3D.new(); motion.name = "ResidentVisualMotion"
	body.add_child(motion); motion.add_child(appearance.visual)
	# Canonical forward +Z is converted to the native body's -Z heading once.
	motion.rotation.y = PI
	scene.add_child(body); body.global_position = point
	body.rotation.y = PI / 2 - float(raw.ang) - PI
	var gait := Gait.new()
	if not gait.bind(appearance.visual, motion):
		body.free(); return _reject(record, "canonical_gait:" + str(gait.get_status().error))
	var rigs: Array[Node] = appearance.visual.find_children("*", "Skeleton3D", true, false)
	if rigs.size() != 1:
		body.free(); return _reject(record, "canonical_activity_rig")
	var activity := PreviewActivity.new()
	if not activity.bind(rigs[0] as Skeleton3D, record.row.source_id):
		body.free(); return _reject(record, "canonical_activity_bones")
	record.body = body; record.motion = motion; record.gait = gait; record.activity = activity; record.origin = point
	record["display_yaw"] = body.rotation.y
	record["turn_from"] = body.rotation.y
	record["turn_to"] = body.rotation.y
	record["turn_elapsed"] = SOURCE_RENDER_YAW_SECONDS
	record["placement_mode"] = body.get_meta("placement_mode")
	record.attempted = true
	record.status = "IDLE"; record.reason = ""; _stats.admissions += 1
	return {"status": "IDLE", "source_id": record.row.source_id, "position": point}

## Deterministic local preview circuit, not the source NPC agenda. Every
## goal and path is still checked by current source access and native physics.
func enable_walk_preview() -> bool:
	if not Thread.is_main_thread() or _busy or _disposed or _scene == null: return false
	_walk_preview_enabled = true
	_walk_preview_clock = 0.0
	_walk_preview.clear()
	for id: String in _records:
		var suffix := int(id.trim_prefix("resident_"))
		_walk_preview[id] = {"awaiting":false, "next_at":0.0, "requests":0, "blocked_at":-1.0, "direction_cursor":suffix % 8, "radius_m":3.25 + float(suffix % 3) * .35}
	return true

func preview_walk_step(delta: float) -> void:
	if Thread.is_main_thread() and not _busy and not _disposed: _sync_local_navigation_adapter()
	if not _walk_preview_enabled or _busy or _disposed or not is_finite(delta) or delta <= 0.0 or delta > .05 or _navigation.state() != "READY": return
	_walk_preview_clock += delta
	for id: String in _records:
		if not _local_navigation_lease.is_empty() and _local_navigation_lease.source_id==id: continue
		var record: Dictionary = _records[id]
		if record.get("physical_failed",false) or _physical_occupied(id): continue
		if not _living(record) or not is_instance_valid(record.body): continue
		var exercise: Dictionary = _walk_preview[id]
		if exercise.awaiting:
			if record.status == "ARRIVED":
				exercise.awaiting = false
				exercise.blocked_at = -1.0
				exercise.direction_cursor = (int(exercise.direction_cursor) + 1) % 8
				exercise.next_at = _walk_preview_clock + 1.5 + float(int(id.trim_prefix("resident_")) % 3) * .7
			elif record.status == "BLOCKED":
				if exercise.blocked_at < 0.0: exercise.blocked_at = _walk_preview_clock
				if _walk_preview_clock - exercise.blocked_at < 1.0: continue
				exercise.awaiting = false
				exercise.direction_cursor = (int(exercise.direction_cursor) + 1) % 8
				exercise.next_at = _walk_preview_clock
			elif record.status in ["PENDING", "READY"]:
				exercise.blocked_at = -1.0
				continue
			elif record.status in ["STALE", "NO_PATH"]:
				# Door/access changes invalidate the old receipt. After a pause the
				# demonstration may ask for a new route through current guards.
				exercise.awaiting = false
				exercise.blocked_at = -1.0
				exercise.direction_cursor = (int(exercise.direction_cursor) + 1) % 8
				exercise.next_at = _walk_preview_clock + 1.5
			else:
				# Unsupported physical bodies and destroyed owners cannot be revived.
				continue
		if record.status not in ["IDLE", "ARRIVED", "BLOCKED", "STALE", "NO_PATH"] or _walk_preview_clock < exercise.next_at: continue
		var body: CharacterBody3D = record.body
		var accepted := -1
		for attempt in PREVIEW_GOAL_ATTEMPTS_PER_STEP:
			var direction: Vector3 = PREVIEW_DIRECTIONS[(int(exercise.direction_cursor) + attempt) % PREVIEW_DIRECTIONS.size()]
			var goal: Vector3 = record.origin + direction * float(exercise.radius_m)
			if body.global_position.distance_to(goal) > 8.0: continue
			var height: Variant = _support.call(goal, id, record.generation)
			if not (height is float or height is int) or not is_finite(float(height)): continue
			goal.y = float(height)
			accepted = request_walk(id, goal)
			if accepted >= 0:
				exercise.direction_cursor = (int(exercise.direction_cursor) + attempt) % PREVIEW_DIRECTIONS.size()
				break
		if accepted >= 0:
			exercise.awaiting = true
			exercise.blocked_at = -1.0
			exercise.requests += 1
		else:
			exercise.direction_cursor = (int(exercise.direction_cursor) + PREVIEW_GOAL_ATTEMPTS_PER_STEP) % PREVIEW_DIRECTIONS.size()
			exercise.next_at = _walk_preview_clock + .25

func retry_pending(identity: String) -> bool:
	if not Thread.is_main_thread() or _busy or _disposed or not _records.has(identity) or _records[identity].status != "PENDING_PLACEMENT": return false
	_records[identity].attempted = false
	return true

func request_walk(identity: String, target: Vector3) -> int:
	if not Thread.is_main_thread() or _busy or _disposed or not _records.has(identity) or not target.is_finite(): return -1
	if _records[identity].get("physical_failed",false): return -1
	if _physical_occupied(identity): return -1
	var record: Dictionary = _records[identity]
	if not _living(record) or not is_instance_valid(record.body) or record.body.global_position.distance_to(target) > 8.0: return -1
	_busy = true
	var allowed := _source_admits(target, record, "target") and _physical_clear(target, [record.body.get_rid()])
	var id := -1
	if allowed: id = _navigation.request(record.owner, record.body, target, _route_admit)
	if id >= 0:
		if record.request >= 0: _navigation.cancel(record.request)
		record.request = id; record.status = "PENDING"
	_leave_busy()
	return id


# DSH_RESID3: per-record retry cadence for the stuck-floor recovery. 0 (default)
# keeps the original "attempt on every tick" behaviour; N retries a still-stuck
# record every N physics ticks, staggered by a stable hash of its source id so
# stuck residents do not all retry on the same tick. The due tick runs the
# identical recovery; only the retry interval changes.
func _recover_retry_ttl() -> int:
	if _dsh_recover_ttl < 0:
		_dsh_recover_ttl = 3  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-recover-ttl="):
				_dsh_recover_ttl = maxi(0, int(argument.trim_prefix("--city-recover-ttl=")))
	return _dsh_recover_ttl

## Stable per-record phase (the same 31-multiplier shape as the engine admit TTL).
func _record_phase(record: Dictionary) -> int:
	if record.has("dsh_phase"): return int(record["dsh_phase"])
	var value := 0
	var text_id: String = str(record.row.source_id)
	for index in text_id.length():
		value = (value * 31 + text_id.unicode_at(index)) & 0x7fffffff
	record["dsh_phase"] = value
	return value

# DSH_RESID3: staggered simulation cadence for far, ordinary, healthy residents.
# 0/1 keeps every resident at full rate. A skipped tick defers only the navigation
# step; its delta is carried in the record and passed on the due tick, so the
# simulated walking distance and speed are unchanged.
func _sim_stride() -> int:
	if _dsh_sim_stride < 0:
		_dsh_sim_stride = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-sim-cadence="):
				_dsh_sim_stride = maxi(0, int(argument.trim_prefix("--city-sim-cadence=")))
	return _dsh_sim_stride

func _sim_far_metres() -> float:
	if _dsh_sim_far_m < 0.0:
		_dsh_sim_far_m = 60.0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-sim-far-m="):
				_dsh_sim_far_m = maxf(0.0, float(argument.trim_prefix("--city-sim-far-m=")))
	return _dsh_sim_far_m

# DSH_SIMLOD: one flag scan for the whole tier set, cached on first use. Returns
# false (and changes nothing) unless --city-sim-lod=1.
func _simlod_on() -> bool:
	if _dsh_simlod < 0:
		_dsh_simlod = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		_dsh_simlod_near_m = 30.0
		_dsh_simlod_mid_m = 120.0
		_dsh_simlod_hyst_m = 8.0
		_dsh_simlod_near_stride = 1
		# DSH_SIMLOD2: the default operating point is the one the game A/B measured,
		# not the largest ceiling the tiers can reach. step() proposes
		# minf(speed * delta, distance_to_waypoint) and the edge loop leaves that
		# distance >= .25 m, while _admit_motion refuses the whole call above its own
		# SAMPLE_METRES = .25 m; a 1.8 m/s walker at .1996 s proposes .359 m and is
		# refused, which turns the deferred tick into a BLOCKED step (full cadence
		# again, plus the floor-recovery branch). At .0998 s the same walker proposes
		# .180 m and is admitted. Measured, same baseline flags: far 4 / .2 s ->
		# resid 32.9-44.6 ms, recover 21-22, blocked/s ~98; far 2 / .1 s -> resid
		# 11.4-12.7 ms, recover 1, blocked/s 3; LOD off -> 14.8-16.8 ms. Mid stays 2
		# (measured skip_mid 5-7 of 16 mid records, i.e. stride 2) and near stays 1.
		# Every flag below still overrides these defaults.
		_dsh_simlod_mid_stride = 2
		_dsh_simlod_far_stride = 2
		_dsh_simlod_max_delta = .1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-sim-lod="):
				_dsh_simlod = maxi(0, int(argument.trim_prefix("--city-sim-lod=")))
			elif argument.begins_with("--city-sim-tier-near-m="):
				_dsh_simlod_near_m = maxf(0.0, float(argument.trim_prefix("--city-sim-tier-near-m=")))
			elif argument.begins_with("--city-sim-tier-mid-m="):
				_dsh_simlod_mid_m = maxf(0.0, float(argument.trim_prefix("--city-sim-tier-mid-m=")))
			elif argument.begins_with("--city-sim-lod-hyst-m="):
				_dsh_simlod_hyst_m = maxf(0.0, float(argument.trim_prefix("--city-sim-lod-hyst-m=")))
			elif argument.begins_with("--city-sim-near-stride="):
				_dsh_simlod_near_stride = maxi(1, int(argument.trim_prefix("--city-sim-near-stride=")))
			elif argument.begins_with("--city-sim-mid-stride="):
				_dsh_simlod_mid_stride = maxi(1, int(argument.trim_prefix("--city-sim-mid-stride=")))
			elif argument.begins_with("--city-sim-far-stride="):
				_dsh_simlod_far_stride = maxi(1, int(argument.trim_prefix("--city-sim-far-stride=")))
			elif argument.begins_with("--city-sim-max-delta="):
				_dsh_simlod_max_delta = clampf(float(argument.trim_prefix("--city-sim-max-delta=")), .05, .5)
		var dsh_near_m := _dsh_simlod_near_m
		var dsh_mid_m := maxf(dsh_near_m, _dsh_simlod_mid_m)
		var dsh_hyst := _dsh_simlod_hyst_m
		_dsh_simlod_near_sq = dsh_near_m * dsh_near_m
		_dsh_simlod_mid_sq = dsh_mid_m * dsh_mid_m
		_dsh_simlod_out_near_sq = (dsh_near_m + dsh_hyst) * (dsh_near_m + dsh_hyst)
		_dsh_simlod_out_mid_sq = (dsh_mid_m + dsh_hyst) * (dsh_mid_m + dsh_hyst)
		_dsh_simlod_in_mid_sq = (dsh_mid_m - dsh_hyst) * (dsh_mid_m - dsh_hyst)
	return _dsh_simlod > 0

## DSH_SIMLOD: stable distance tier with hysteresis. 0 = near (never deferred),
## 1 = mid, 2 = far. The near boundary is a hard clamp, not a hysteresis edge: a
## record inside --city-sim-tier-near-m is tier 0 on the step that measures it, so
## no stale tier can outlive a camera move. Only the promotion outward needs
## --city-sim-lod-hyst-m of clearance, so a camera panning across a boundary cannot
## thrash a record between cadences on every city step. The stored tier is written
## only when it really changes: this runs for all 287 records on every city step
## and a Dictionary write hashes its key, which measured as the dominant cost.
func _simlod_tier(record: Dictionary, dist_sq: float) -> int:
	var stored := int(record.get("simlod_tier", -1))
	if dist_sq <= _dsh_simlod_near_sq:
		if stored != 0: record["simlod_tier"] = 0
		return 0
	var candidate := 1 if dist_sq <= _dsh_simlod_mid_sq else 2
	if stored < 0:
		record["simlod_tier"] = candidate
		return candidate
	var result := stored
	if candidate > stored:
		if dist_sq > (_dsh_simlod_out_near_sq if candidate == 1 else _dsh_simlod_out_mid_sq): result = candidate
	elif candidate < stored:
		if dist_sq < _dsh_simlod_in_mid_sq: result = candidate
	if result != stored: record["simlod_tier"] = result
	return result

## DSH_SIMLOD: the per-record stride of a tier, in city steps.
func _simlod_stride(tier: int) -> int:
	if tier == 1: return maxi(1, _dsh_simlod_mid_stride)
	if tier >= 2: return maxi(1, _dsh_simlod_far_stride)
	return maxi(1, _dsh_simlod_near_stride)

# DSH_MOTION: --city-timing=0 skips only the per-record diagnostic samples above.
# Every marker still prints; their timing fields read 0 while the flag is 0. Default 1.
func _timing_records() -> bool:
	if _dsh_timing < 0:
		_dsh_timing = 1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-timing="):
				_dsh_timing = maxi(0, int(argument.trim_prefix("--city-timing=")))
	return _dsh_timing != 0

# DSH_SIMLOD: the three modes in which a ragdoll host PHYSICALLY owns its
# resident body. A prewarmed pool sitting in _ragdolls with mode IDLE owns
# nothing - the walking capsule is still the body - and refusing to defer those
# made this whole path inert (v1 bug: 284 of 287 residents carry that pool).
const DSH_RAGDOLL_PHYSICAL := ["ACTIVE", "RECOVERING", "RECOVERY_HOLD"]

## DSH_RESID3: true only for a far, ordinary, healthy walking resident. Dead,
## physical, fighting, stuck and near-camera residents always keep full cadence.
func _sim_deferrable(record: Dictionary, rag_mode: String, retaliation: RefCounted, dist_sq: float) -> bool:
	if not _living(record) or record.get("physical_failed",false) or rag_mode in DSH_RAGDOLL_PHYSICAL: return false
	if retaliation != null or record.get("contact_hit_reaction") != null: return false
	if record.status in DSH_STATUS_BLOCKED_OR_NO_PATH: return false  # DSH_RESID4
	# DSH_SIMLOD: the tier was resolved for this record earlier in this same city
	# step, from the same body position and the same hoisted camera, so the near
	# test needs no second camera lookup. Tier 0 is clamped hard to the near radius,
	# so "tier > 0" is exactly "farther than the near tier": the near-camera
	# guarantee does not depend on any flag value. Reading the already-resolved flag
	# avoids a redundant _simlod_on() call for every deferrable record.
	if _dsh_simlod > 0: return int(record.get("simlod_tier", 0)) > 0
	var far := _sim_far_metres()
	if far <= 0.0: return true
	return dist_sq > far * far

## Let Godot resolve a small vertical floor overlap before strict path admission.
## A query previews the correction; source footprint and all obstacles still pass.
func _recover_floor_contact(record: Dictionary) -> bool:
	# DSH_RESID3: on a non-due tick the whole attempt is skipped; the record keeps
	# its status and the next due tick runs the identical recovery.
	var retry_ttl := _recover_retry_ttl()
	if retry_ttl > 1 and (Engine.get_physics_frames() + _record_phase(record)) % retry_ttl != 0:
		_dsh_recover_skips += 1
		return false
	var body: CharacterBody3D = record.body if is_instance_valid(record.body) else null
	var id: String = record.row.source_id
	if body == null or not _living(record) or record.get("physical_failed",false) or _physical_occupied(id) or body.collision_layer != 1 or body.collision_mask != 1 or (body.is_on_floor() and record.status not in DSH_STATUS_BLOCKED_OR_NO_PATH) or body.velocity.y > 0.0: return false  # DSH_RESID4
	var require_floor_only: bool = body.is_on_floor() and record.status == "NO_PATH"
	var before := body.global_transform
	var margin := body.safe_margin
	var snap_length := body.floor_snap_length
	var overlap_recovery := body.move_and_collide(Vector3.ZERO, true, margin, true)
	if overlap_recovery == null: return false
	var correction: Vector3 = overlap_recovery.get_travel()
	var corrected: Vector3 = before.origin + correction
	if not correction.is_finite() or correction.y < 0.0 or correction.y > .05 or Vector2(correction.x,correction.z).length() > .0001: return false
	if require_floor_only:
		# A grounded actor can enter NO_PATH while its conservative square still
		# clips the supporting floor. Retry only the exact native vertical floor
		# recovery after another actor's reservation has cleared; never admit an
		# obstacle, weaken the footprint or assign a replacement transform.
		var floor_collider: Object = overlap_recovery.get_collider()
		if correction.y <= 0.0 or not floor_collider is StaticBody3D or overlap_recovery.get_normal().dot(Vector3.UP) < .9999: return false
		var excluded: Array[RID] = [body.get_rid()]
		_overlap.exclude = excluded
		_overlap.transform = Transform3D(Basis.IDENTITY, before.origin + Vector3.UP * (HEIGHT * .5 + .025))
		var overlaps: Array[Dictionary] = body.get_world_3d().direct_space_state.intersect_shape(_overlap,2)
		if overlaps.size() != 1 or overlaps[0].collider != floor_collider: return false
	if not _source_admits(corrected, record, "route"): return false
	# The source callback may revoke or replace the physical owner synchronously.
	if not is_instance_valid(body) or body.is_queued_for_deletion() or record.body != body or body.global_transform != before: return false
	if body.collision_layer != 1 or body.collision_mask != 1 or record.get("physical_failed",false) or _physical_occupied(id): return false
	if body.velocity.y > 0.0 or body.safe_margin != margin or body.floor_snap_length != snap_length: return false
	if not _physical_clear(corrected,[body.get_rid()]) or not _owned_clear(corrected,id): return false
	body.move_and_collide(Vector3.ZERO, false, margin, true)
	var after_native: Vector3 = body.global_position
	body.apply_floor_snap()
	_stats["floor_recoveries"] = int(_stats.get("floor_recoveries",0)) + 1
	_stats["last_floor_recovery"] = {"source_id":id,"status":record.status,"floor_only_no_path":require_floor_only,"before":before.origin,"correction":correction,"after_native":after_native,"after_snap":body.global_position,"on_floor_after":body.is_on_floor(),"physics_frame":Engine.get_physics_frames()}
	return true

# DSH_RESID4: the per-record status tests built a fresh two-element Array on every
# pass (287 records per city step). The same constant Arrays compare the same
# strings and allocate nothing; the membership result is unchanged.
const DSH_STATUS_BLOCKED_OR_NO_PATH := ["BLOCKED", "NO_PATH"]
const DSH_STATUS_READY_OR_ARRIVED := ["READY", "ARRIVED"]


func step(delta: float) -> void:
	# DSH_ROUND2: per-resident cost ranking, once per wall second.
	var dsh_now := Time.get_ticks_msec()
	if dsh_now - _dsh_report_ms >= 1000:
		_dsh_report_ms = dsh_now
		var dsh_rows: Array = []
		var dsh_sum := 0
		var dsh_n := 0
		var dsh_calls := 0
		for dsh_record: Dictionary in _records.values():
			var dsh_nav := int(dsh_record.get("dsh_nav_us", 0))
			var dsh_rec := int(dsh_record.get("dsh_rec_us", 0))
			var dsh_call := int(dsh_record.get("dsh_nav_calls", 0))
			if dsh_nav + dsh_rec > 0:
				dsh_rows.append({"id": str(dsh_record.row.source_id), "nav": dsh_nav, "rec": dsh_rec, "calls": dsh_call, "status": str(dsh_record.status)})
				dsh_sum += dsh_nav + dsh_rec
				dsh_calls += dsh_call
				dsh_n += 1
			dsh_record["dsh_nav_us"] = 0
			dsh_record["dsh_rec_us"] = 0
			dsh_record["dsh_nav_calls"] = 0
		dsh_rows.sort_custom(func(a, b): return (int(a.nav) + int(a.rec)) > (int(b.nav) + int(b.rec)))
		var dsh_line := "DSH_ONE n=" + str(dsh_n) + " sum_us=" + str(dsh_sum) + " calls=" + str(dsh_calls) + " avg_us=" + ("%.0f" % (float(dsh_sum) / maxf(1.0, float(dsh_n))))
		for dsh_i in mini(5, dsh_rows.size()):
			dsh_line += " | " + str(dsh_rows[dsh_i].id) + " " + str(dsh_rows[dsh_i].status) + " nav=" + str(dsh_rows[dsh_i].nav) + " rec=" + str(dsh_rows[dsh_i].rec) + " calls=" + str(dsh_rows[dsh_i].calls)
		print(dsh_line)
	if Thread.is_main_thread() and not _busy and not _disposed: _sync_local_navigation_adapter()
	if not Thread.is_main_thread() or _busy or _disposed or not is_finite(delta) or delta <= 0 or delta > .05: return
	_busy = true
	var started := Time.get_ticks_usec()
	# DSH_TELEMETRY (temporary): where the resid bucket actually goes.
	var dsh_records := 0
	var dsh_posed := 0
	var dsh_lod_skip := 0
	# DSH_SIMLOD: per-city-step tier telemetry and the resolved carried-delta
	# ceiling. `dsh_simlod` is false (and the ceiling .05) unless --city-sim-lod=1.
	var dsh_simlod := _simlod_on()
	# DSH_SIMLODFIX: the flag default is -1.0 (unset). Using it directly made the
	# ceiling negative, so sim_cap clamped every stride to 1 and the LOD was inert
	# (measured: tiers near=3/mid=16/far=265 but skip_far=0, sim_ms=0). Fall back to
	# the documented .2 s whenever the flag was not given.
	# DSH_SIMLOD2: the unset fallback tracks the same measured ceiling as the default
	# above, so one path cannot read .2 s while the other reads .1 s. A flag value > 0
	# still wins on both paths.
	var dsh_sim_ceiling := ((_dsh_simlod_max_delta if _dsh_simlod_max_delta > 0.0 else .1) if dsh_simlod else .05)
	var dsh_tier_near := 0
	var dsh_tier_mid := 0
	var dsh_tier_far := 0
	var dsh_skip_near := 0
	var dsh_skip_mid := 0
	var dsh_skip_far := 0
	var dsh_sim_delta_ms := 0
	var dsh_pose_us := 0
	var dsh_walk := 0  # DSH_QUERY_PROBE
	var dsh_recover := 0  # DSH_QUERY_PROBE
	var dsh_cadence_skip := 0  # DSH_RESID3
	var dsh_timing := _timing_records()  # DSH_MOTION
	# DSH_RECORDLOOP: the animation LOD resolved the viewport camera inside every
	# record and twice per record - up to 574 camera lookups per city step (per
	# second: ~11k) for one value that cannot change inside this loop.
	var dsh_camera := _anim_lod_camera()
	var dsh_camera_pos := dsh_camera.global_position if dsh_camera != null else Vector3.ZERO
	var dsh_lod_limit := ANIM_LOD_RADIUS_M * ANIM_LOD_RADIUS_M
	var dsh_yaw_skip := _yaw_skip()  # DSH_RECORDLOOP
	var dsh_rag_mode_direct := _rag_mode_direct()  # DSH_RECORDLOOP
	# DSH_PAUSEPUSH: one frame stamp, one clock and one flag per step for the pause
	# read below; all three are loop-invariant inside this call.
	var dsh_pause_push := _pause_push()
	var dsh_pause_frame := Engine.get_physics_frames()
	var dsh_pause_now_us := Time.get_ticks_usec()
	var dsh_pause_fast := 0  # DSH_PAUSEPUSH telemetry
	var dsh_pause_slow := 0  # DSH_PAUSEPUSH telemetry
	# DSH_RESID4: the absent-key default for walk_pause was a freshly built Callable
	# on every record; one empty Callable serves every miss.
	var dsh_no_callable := Callable()
	for record: Dictionary in _records.values():
		dsh_records += 1
		# DSH_RESID4: one read of record.body serves the validity test and the value;
		# the conditional form read the same key twice on every record.
		var body: CharacterBody3D = record.body
		if not is_instance_valid(body): body = null
		var id: String = record.row.source_id
		# One ragdoll status per record per frame. It allocates a Dictionary and
		# duplicates its binding on every call; this loop previously called it six
		# times per record across all 287 residents, and it is now called zero times:
		# DSH_RECORDLOOP reads the mode field that the status() dictionary copies
		# (base _result() always writes it, and the only subclass never overrides it).
		var rag: RefCounted = _ragdolls.get(id)
		var rag_mode: String = str(rag.mode) if rag != null and dsh_rag_mode_direct else (str(rag.status().mode) if rag != null else "")
		var retaliation: RefCounted = record.get("melee_retaliation")
		if retaliation != null and (not _living(record) or record.get("physical_failed",false) or rag_mode in ["ACTIVE","RECOVERING","RECOVERY_HOLD"] or not is_instance_valid(body)):
			retaliation.cancel("host_owner_or_physical_state")
		if record.get("physical_failed",false):
			var failed_owner: RefCounted = record.owner
			if failed_owner.source_id != id or failed_owner.life_generation != record.generation:
				if is_instance_valid(body): body.queue_free()
				record.body = null; record.status = "REMOVED"
			continue
		# DSH_RESID4: the previous form ran three independent membership tests on
		# rag_mode, each allocating a two/three element Array, and every prewarmed
		# resident (284 of 287 records per step, measured) reaches here with mode IDLE
		# on every pass. Dispatching on the same mode strings, in the same order, runs
		# the identical bodies with the identical disposal and `continue`s.
		if rag != null:
			if rag_mode == "IDLE" or rag_mode == "RETIRED":
				# A prewarmed pool cannot outlive the walking source generation while
				# waiting for a confirmed event. A retired pool is also never reused.
				if not _living(record) or rag_mode == "RETIRED":
					rag.dispose(); _ragdolls.erase(id); rag = null; rag_mode = ""
			elif rag_mode == "RECOVERING" or rag_mode == "RECOVERY_HOLD":
				# Another owner may coordinate a source-approved rise. Never let the
				# disabled walking capsule fall through to navigation or gait here.
				if record.request >= 0: _navigation.cancel(record.request); record.request = -1
				record.status = "PHYSICAL_RECOVERING" if rag_mode == "RECOVERING" else "PHYSICAL_HOLD"
				continue
			elif rag_mode == "ACTIVE":
				if record.request >= 0: _navigation.cancel(record.request); record.request = -1
				var physical: Dictionary = rag.advance()
				if physical.get("ok",false):
					record.status = "PHYSICAL_DEAD" if physical.get("final_dead",false) else "PHYSICAL_KNOCKDOWN"
					record["physical_anchor_world"] = physical.physical.anchor_world
					continue
				rag.retire("physical_advance_failed")
				_ragdolls.erase(id)
				record["physical_failed"] = true
				record.status = "PHYSICAL_FAILED"
				continue
		# DSH_RESID4: the same five checks _living(record) makes, without a GDScript
		# call per record and without a second nested row lookup: `id` above is exactly
		# record.row.source_id, and record.row is never reassigned after admission.
		# _living() itself is unchanged for every other caller.
		var record_owner: RefCounted = record.owner
		if _disposed or _dispose_requested or record_owner.dead or record_owner.source_id != id or record_owner.life_generation != record.generation:
			if record.request >= 0: _navigation.cancel(record.request)
			if is_instance_valid(body): body.queue_free()
			record.body = null; record.gait = null; record.motion = null; record.status = "REMOVED"; record.attempted = true; continue
		if not is_instance_valid(body): continue
		if not body.is_on_floor() or record.status in DSH_STATUS_BLOCKED_OR_NO_PATH:  # DSH_RESID4
			dsh_recover += 1  # DSH_QUERY_PROBE: intersect_shape per call inside
			var dsh_r0 := Time.get_ticks_usec() if dsh_timing else 0  # DSH_ROUND2
			_recover_floor_contact(record)
			if dsh_timing: record["dsh_rec_us"] = int(record.get("dsh_rec_us", 0)) + (Time.get_ticks_usec() - dsh_r0)  # DSH_ROUND2
			# Recovery admission invokes source code; it may retire this actor.
			if not _living(record) or not is_instance_valid(body) or body.is_queued_for_deletion() or record.body != body: continue
			if record.get("physical_failed",false) or rag_mode in ["ACTIVE","RECOVERING","RECOVERY_HOLD"] or body.collision_layer != 1 or body.collision_mask != 1: continue
		# DSH_RECORDLOOP: exactly today's _anim_lod_ok(record) answer, computed once
		# from the hoisted camera (a null camera meant 0.0 <= limit, i.e. near).
		# DSH_RESID4: one global transform read now serves the LOD predicate and the
		# displacement baseline; both read the same unchanged value in the same two
		# consecutive statements.
		var before := body.global_position
		# DSH_SIMLOD: the same distance the animation LOD already computes, read once
		# and reused for the simulation tier. A null camera means 0.0 = near, which is
		# exactly what _anim_lod_ok() has always answered for a null camera.
		var dsh_dist_sq: float = 0.0 if dsh_camera == null else (dsh_camera_pos - before).length_squared()
		var dsh_lod_ok: bool = dsh_camera == null or dsh_dist_sq <= dsh_lod_limit
		var dsh_tier := _simlod_tier(record, dsh_dist_sq) if dsh_simlod else -1  # DSH_SIMLOD
		if dsh_tier == 0: dsh_tier_near += 1  # DSH_SIMLOD
		elif dsh_tier == 1: dsh_tier_mid += 1
		elif dsh_tier == 2: dsh_tier_far += 1
		# DSH_PAUSEPUSH: the health owner published the identical predicate during
		# this city step's health loop (population.step runs hit_owners before
		# residents.step, in the same physics frame), so read its two operands.
		# A stale stamp, or --city-pause-push=0, falls back to the unchanged Callable.
		var paused: bool
		if dsh_pause_push and int(record.get("pause_stamp", -1)) == dsh_pause_frame:
			dsh_pause_fast += 1
			paused = bool(record.get("pause_block", false))
			if not paused:
				var pause_deadline := float(record.get("pause_deadline_ms", 0.0))
				if pause_deadline > 0.0:
					# The identical expression should_pause_walk() uses for `now`.
					var pause_now_ms := float(dsh_pause_now_us - int(record.get("pause_epoch_us", dsh_pause_now_us))) / 1000.0 + 1.0
					paused = pause_now_ms < pause_deadline
		else:
			dsh_pause_slow += 1
			var walk_pause: Callable = record.get("walk_pause", dsh_no_callable)  # DSH_RESID4
			paused = walk_pause.is_valid() and walk_pause.call()
		var hit_paused: bool = paused
		if retaliation != null:
			# Existing stagger/health owner pause always wins over attack pose.
			if paused: retaliation.hold_for_hit(delta)
			else: retaliation.step(delta)
			if retaliation.engaged():
				paused = true
				var facing: Vector3 = retaliation.target_position() - body.global_position
				if facing.is_finite() and Vector2(facing.x,facing.z).length_squared() > .0001:
					body.rotation.y = atan2(-facing.x,-facing.z)
		if paused: body.velocity = Vector3.ZERO
		if retaliation != null and retaliation.engaged() and not hit_paused:
			var defensive_velocity: Vector3 = retaliation.defensive_velocity(delta)
			if defensive_velocity.length_squared() > .000001:
				# Same native body owner; navigation remains paused. No second process,
				# collision exclusions, root teleport, or active-window translation.
				body.velocity = defensive_velocity + Vector3.DOWN*9.8*delta
				body.move_and_slide()
				retaliation.record_defensive_motion(before,body.global_position)
				body.velocity = Vector3.ZERO
		if record.request >= 0 and not paused:
			# Exact healthy civilian branch of source _npcEffectiveSpeed, fixed at
			# immutable session receipt time. No fatigue/health simulation claimed.
			# step() polls internally and returns that poll's status when it is not READY,
			# so polling here first was a second identical query per walking resident.
			# DSH_RESID3: a far, ordinary, healthy resident may be scheduled on a
			# staggered stride. A skipped tick keeps the request, the body, the pose and
			# every other per-tick update intact; its delta is carried into the due tick,
			# which is the only tick that asks the host to move the body again.
			var sim_stride := _sim_stride()
			var sim_lod := dsh_simlod  # DSH_SIMLOD
			if sim_lod: sim_stride = _simlod_stride(dsh_tier)  # DSH_SIMLOD
			var sim_delta := delta
			var sim_due := true
			if sim_stride > 1:
				# DSH_SIMLOD: .05 s is the legal ceiling today; --city-sim-lod=1 raises
				# it to --city-sim-max-delta for this per-record carried path only. The
				# STRIDE is capped, not the delta, so the walked distance stays exact:
				# delta * stride never exceeds the ceiling. At delta .0499 and a .2 s
				# ceiling the stride caps at 4, i.e. one due tick every 4 city steps
				# (5 Hz, 28 cm per due tick for a 1.4 m/s walker).
				# This class and npc_city_navigation_host both refused delta > .05, so the
				# stride used to be capped to one legal step; that cap is what made
				# --city-sim-cadence dead, and it is the ceiling above that lifts it.
				var sim_ceiling := dsh_sim_ceiling if sim_lod else .05
				var sim_cap := int(floor(sim_ceiling / delta + .000001))
				if sim_cap < 1: sim_cap = 1
				if sim_stride > sim_cap: sim_stride = sim_cap
				if sim_stride > 1 and _sim_deferrable(record, rag_mode, retaliation, dsh_dist_sq):
					# DSH_SIMLOD: the due test counts THIS record's own deferrable city
					# steps, not the physics frame. A physics-frame modulo can starve every
					# record whose phase is not in the subgroup generated by the global
					# city stride (a far stride of 3 or 6 under --city-sim-stride=3 would
					# never come due at all); the per-record tick always does.
					var sim_due_now := false
					if sim_lod:
						var sim_tick := int(record.get("simlod_tick", 0)) + 1
						record["simlod_tick"] = sim_tick
						sim_due_now = (sim_tick + _record_phase(record)) % sim_stride == 0
					else:
						sim_due_now = (Engine.get_physics_frames() + _record_phase(record)) % sim_stride == 0
					if sim_due_now:
						sim_delta = minf(sim_ceiling, delta + float(record.get("sim_carry", 0.0)))
						record["sim_carry"] = 0.0
						if sim_lod: dsh_sim_delta_ms = maxi(dsh_sim_delta_ms, int(sim_delta * 1000.0))  # DSH_SIMLOD
					else:
						record["sim_carry"] = float(record.get("sim_carry", 0.0)) + delta
						sim_due = false
						dsh_cadence_skip += 1
						if dsh_tier == 1: dsh_skip_mid += 1  # DSH_SIMLOD
						elif dsh_tier == 2: dsh_skip_far += 1
				elif record.has("sim_carry"):
					# Full rate again: never apply a stale carry later.
					record["sim_carry"] = 0.0
			elif record.has("sim_carry"):  # DSH_SIMLOD: tier 0 is always full rate
				record["sim_carry"] = 0.0
			dsh_walk += 1  # DSH_QUERY_PROBE
			var dsh_n0 := Time.get_ticks_usec() if dsh_timing else 0  # DSH_ROUND2
			if sim_due:
				var result: Dictionary = _navigation.step(record.request, sim_delta, record.speed, 9.8)
				if dsh_timing: record["dsh_nav_us"] = int(record.get("dsh_nav_us", 0)) + (Time.get_ticks_usec() - dsh_n0)  # DSH_ROUND2
				record["dsh_nav_calls"] = int(record.get("dsh_nav_calls", 0)) + 1  # DSH_ROUND2
				record.status = result.status
				if result.status not in DSH_STATUS_READY_OR_ARRIVED: body.velocity = Vector3.ZERO  # DSH_RESID4
		var displacement := body.global_position - before
		var horizontal := Vector3(displacement.x, 0, displacement.z)
		if horizontal.length_squared() > .00000001: body.basis = Basis(Vector3.UP, atan2(-horizontal.x, -horizontal.z))
		# Source renderer interpolates the shortest yaw arc while source motion
		# can change angle immediately. Keep the physical body/path untouched;
		# rotate only the canonical presentation node against body heading.
		var desired_yaw: float = body.rotation.y
		# DSH_RECORDLOOP: with --city-yaw-skip=1 a resident whose turn has already
		# finished (turn_elapsed == 0.1) and whose body heading already equals
		# turn_to has turn_from == turn_to, so display_yaw and motion.rotation.y are
		# already exactly what this block would rewrite.
		# DSH_RESID4: that settled test and the turn test below are the same arc of the
		# same two values, and turn_to/turn_elapsed/turn_from/display_yaw were each
		# fetched from the record two or three times per pass. Compute the arc once,
		# read every stored value once, and write back exactly what the previous form
		# wrote (turn_from keeps the stored Variant, turn_to keeps desired_yaw) with
		# the same arithmetic in the same order. Which records enter this block, and
		# the --city-yaw-skip decision, are unchanged.
		var dsh_turn_to := float(record.turn_to)
		var dsh_turn_elapsed := float(record.turn_elapsed)
		var dsh_turn_from := float(record.turn_from)
		var dsh_display := float(record.display_yaw)
		var dsh_turn_shift := atan2(sin(desired_yaw - dsh_turn_to), cos(desired_yaw - dsh_turn_to))
		if not (dsh_yaw_skip and dsh_turn_elapsed >= SOURCE_RENDER_YAW_SECONDS and absf(dsh_turn_shift) < .000001):
			if absf(dsh_turn_shift) >= .000001:
				record.turn_from = record.display_yaw
				record.turn_to = desired_yaw
				dsh_turn_from = dsh_display
				dsh_turn_to = desired_yaw
				dsh_turn_elapsed = 0.0
			dsh_turn_elapsed = minf(SOURCE_RENDER_YAW_SECONDS, dsh_turn_elapsed + delta)
			record.turn_elapsed = dsh_turn_elapsed
		# DSH_PAUSEPUSH (opt-in): the settled test at :954 already proves
		# turn_elapsed == SOURCE_RENDER_YAW_SECONDS (factor 1.0) and turn_to ==
		# desired_yaw; adding "display_yaw already equals desired_yaw" proves the
		# three statements below write exactly the values they would recompute, so
		# --city-yaw-skip=1 may skip them. With the default flag value (0) the
		# condition is constantly true and the writes run exactly as today.
		if not (dsh_yaw_skip and dsh_turn_elapsed >= SOURCE_RENDER_YAW_SECONDS and absf(dsh_turn_shift) < .000001 and absf(dsh_display - desired_yaw) < .000001):
			dsh_display = dsh_turn_from + atan2(sin(dsh_turn_to - dsh_turn_from), cos(dsh_turn_to - dsh_turn_from)) * (dsh_turn_elapsed / SOURCE_RENDER_YAW_SECONDS)
			record.display_yaw = dsh_display
			record.motion.rotation.y = PI + atan2(sin(dsh_display - desired_yaw), cos(dsh_display - desired_yaw))
		var hit_pose: RefCounted = record.get("contact_hit_reaction")
		var hit_pose_active: bool = hit_pose != null and hit_pose.hit_pose_active()
		if (retaliation != null and retaliation.engaged()) or hit_pose_active:
			# Sample ordinary pose, compose attack, then commit once. Activity is
			# suppressed here to prevent a second skeleton authority in this frame.
			var pose: Dictionary = record.gait.sample(delta, horizontal / delta, body.is_on_floor() or record.status in ["IDLE", "ARRIVED"])
			if retaliation != null: pose = retaliation.compose_pose(pose)
			if hit_pose_active: pose = hit_pose.compose_hit_pose(pose)
			if pose.get("valid",false):
				var rig: Skeleton3D = record.gait._skeleton
				var bones: Array[Transform3D] = pose.poses
				if dsh_lod_ok:
					_set_resident_shadows(record, true)
					for bone: int in bones.size(): rig.set_bone_pose(bone,bones[bone])
				record.motion.position = pose.visual_offset
		else:
			if dsh_lod_ok:
				# DSH_RESID4: the callee's own first line is this exact guard. Evaluating
				# it here keeps the identical transition (and the identical
				# record["shadow_on"] write) while skipping the call for the 281 of 287
				# residents that are far - and already off - on every step.
				if not bool(record.get("shadow_on", true)): _set_resident_shadows(record, true)
				var dsh_t0 := Time.get_ticks_usec() if dsh_timing else 0
				record.gait.update_pose(delta, horizontal / delta, body.is_on_floor() or record.status in ["IDLE", "ARRIVED"])
				if dsh_timing: dsh_pose_us += Time.get_ticks_usec() - dsh_t0
				dsh_posed += 1
			else:
				dsh_lod_skip += 1
				if bool(record.get("shadow_on", true)): _set_resident_shadows(record, false)  # DSH_RESID4
			if _walk_preview_enabled and record.activity != null: record.activity.step(delta, horizontal.length() / delta)
	var dsh_frame := Engine.get_physics_frames()
	if dsh_frame % 60 == 0:
		var dsh_recover_skip := _dsh_recover_skips
		_dsh_recover_skips = 0
		print("DSH_RESID f=",dsh_frame," records=",dsh_records," posed=",dsh_posed," lod_skip=",dsh_lod_skip," walk=",dsh_walk," recover=",dsh_recover," pause_fast=",dsh_pause_fast," pause_slow=",dsh_pause_slow," cadence_skip=",dsh_cadence_skip," recover_skip=",dsh_recover_skip," pose_us=",dsh_pose_us," loop_us=",Time.get_ticks_usec()-started," fps=",Engine.get_frames_per_second()," simlod=",dsh_simlod," near=",dsh_tier_near," mid=",dsh_tier_mid," far=",dsh_tier_far," skip_near=",dsh_skip_near," skip_mid=",dsh_skip_mid," skip_far=",dsh_skip_far," sim_ms=",dsh_sim_delta_ms)
	_stats.steps += 1
	_stats.step_us_max = maxi(_stats.step_us_max, Time.get_ticks_usec() - started)
	_leave_busy()

## Explicit integration seam. Parent supplies the real local HP event owner
## and both-life authority callback; attaching alone never starts an attack.
func attach_contact_retaliation(token: Dictionary, authority_current: Callable, confirmed_event: Callable) -> RefCounted:
	if not target_current(token) or not authority_current.is_valid() or not confirmed_event.is_valid(): return null
	var record: Dictionary = _records[token.source_id]
	if record.get("melee_retaliation") != null: return null
	var controller := ContactRetaliation.new()
	if not controller.configure(token, record.gait._rest_poses, authority_current, confirmed_event): return null
	record["melee_retaliation"] = controller
	return controller

## Read only after step and player pose commit. No contact or damage is implied.
func contact_retaliation_capabilities() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not Thread.is_main_thread() or _busy or _disposed or _dispose_requested: return result
	for record: Dictionary in _records.values():
		var controller: RefCounted = record.get("melee_retaliation")
		if controller == null: continue
		if not _living(record) or record.get("physical_failed",false) or _physical_occupied(record.row.source_id):
			controller.cancel("late_host_state_change"); continue
		var active: Dictionary = controller.capability()
		if active.is_empty(): continue
		active["controller"] = controller
		result.append(active)
	return result

func snapshot() -> Dictionary:
	var rows: Array = []
	if not Thread.is_main_thread(): return {"status": "INVALID_THREAD"}
	var walk_requests := 0
	for id: String in _records:
		var record: Dictionary = _records[id]
		var body: CharacterBody3D = record.body if is_instance_valid(record.body) else null
		rows.append({"source_id": id, "bridge_id": record.row.bridge_id, "descriptor_sha256": record.row.descriptor_sha256, "status": record.status, "reason": record.reason, "position": body.global_position if is_instance_valid(body) else null, "physical_anchor_world": record.get("physical_anchor_world"), "life_generation": record.generation, "speed_mps": record.speed, "placement_mode": record.get("placement_mode", "NONE")})
		if _walk_preview.has(id): walk_requests += int(_walk_preview[id].requests)
	return {"session_id": _session, "disposed": _disposed, "rows": rows, "stats": _stats.duplicate(), "walk_preview": {"enabled":_walk_preview_enabled, "requests":walk_requests}}

func occupants() -> Array[Dictionary]:
	var positions: Array[Dictionary] = []
	if not Thread.is_main_thread() or _disposed: return positions
	for record: Dictionary in _records.values():
		if is_instance_valid(record.body) and record.body.collision_layer != 0: positions.append({"position": record.body.global_position, "radius": .36, "height": HEIGHT, "source_id": record.row.source_id, "life_generation": record.generation})
	return positions

# DSH_TARGETFAST: --city-daily-target-fast=0 restores the original identity scan
# (`for id: String in _records:` = 284 dictionary lookups + a _living() call each),
# i.e. an exact A/B of the identity resolution alone. Resolved once, so the hot
# path pays one int compare per check. 1 = accepted default.
# DSH_PAUSEPUSH: --city-pause-push=0 makes this host call record.walk_pause for
# every record exactly as before, so the change can be A/B'd with one flag
# instead of a revert. 1 (default) reads the operands the health owner published
# in this same city step.
func _pause_push() -> bool:  # DSH_PAUSEPUSH
	if _dsh_pause_push < 0:
		_dsh_pause_push = 1
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-pause-push="):
				_dsh_pause_push = 0 if int(argument.trim_prefix("--city-pause-push=")) == 0 else 1
	return _dsh_pause_push != 0

func _dsh_target_fast() -> int:  # DSH_TARGETFAST
	if _dsh_target_fast_cache < 0:
		_dsh_target_fast_cache = 1  # DSH_ACCEPTED: принятое значение по умолчанию, флаг переопределяет
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--city-daily-target-fast="):
				_dsh_target_fast_cache = 0 if int(argument.trim_prefix("--city-daily-target-fast=")) == 0 else 1
	return _dsh_target_fast_cache

## Map an actual physics collider to the current visual/physical resident life.
## This transient token proves identity only: it is not bullet contact, damage,
## source hit acceptance or final-death authority.
func target_from_collider(collider: Object) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or not collider is CharacterBody3D or not is_instance_valid(collider): return {"ok":false}
	# DSH_TARGETFAST: _admit_record() writes this exact source_id into the body
	# (:358) BEFORE record.body is set (:379), inside the host's _busy section, so the
	# record owning this collider is one Dictionary lookup away; bodies are unique, so
	# this is the record the scan below would have found. Every check that follows is
	# the original one, re-checked on the selected record; when the O(1) lookup cannot
	# prove the identity (missing/foreign meta) the original scan runs verbatim.
	var id := ""
	if _dsh_target_fast() != 0:
		id = str(collider.get_meta("source_id", ""))
		if not id.is_empty():
			if not _records.has(id): id = ""
			else:
				var dsh_candidate: Dictionary = _records[id]
				if dsh_candidate.get("body") != collider: id = ""
	if id.is_empty():
		for scan_id: String in _records:
			var scan_record: Dictionary = _records[scan_id]
			if not _living(scan_record) or not is_instance_valid(scan_record.body) or scan_record.body != collider or not is_instance_valid(scan_record.motion): continue
			id = scan_id
			break
	if id.is_empty(): return {"ok":false}
	var record: Dictionary = _records[id]
	if not _living(record) or not is_instance_valid(record.body) or record.body != collider or not is_instance_valid(record.motion): return {"ok":false}
	var body: CharacterBody3D = record.body
	if body.get_meta("source_id", "") != id or body.get_meta("session_id", "") != _session or body.get_meta("descriptor_sha256", "") != record.row.descriptor_sha256 or body.get_child_count() < 2: return {"ok":false}
	var shape: Node = body.get_child(0)
	if not shape is CollisionShape3D or shape.disabled or not shape.shape is CapsuleShape3D or not is_equal_approx(shape.shape.radius, .36) or not is_equal_approx(shape.shape.height, HEIGHT): return {"ok":false}
	if body.collision_layer != 1 or body.collision_mask != 1 or body.get_parent() != _scene.get_ref(): return {"ok":false}
	# DSH_RIGCACHE: cached rig lookup, same single-rig requirement.
	var rig: Skeleton3D = _current_record_rig(record)
	if rig == null: return {"ok":false}
	return {"ok":true, "source_authority":false, "session_id":_session,
		"source_id":id, "bridge_id":record.row.bridge_id, "render_id":record.row.bridge_id,
		"life_generation":record.generation,
		"descriptor_sha256":record.row.descriptor_sha256,
		"placement_mode":record.get("placement_mode", "NONE"),
		"body":body, "body_instance_id":body.get_instance_id(),
		"body_rid":body.get_rid(), "rig":rig,
		"rig_instance_id":rig.get_instance_id(), "rig_epoch":rig.get_instance_id()}
	return {"ok":false}

func target_current(token: Dictionary) -> bool:
	if not Thread.is_main_thread() or _busy or _disposed or token.get("ok") != true or token.get("source_authority") != false: return false
	var body: Variant = token.get("body")
	if not body is CharacterBody3D or not is_instance_valid(body): return false
	var fresh: Dictionary = target_from_collider(body)
	if not fresh.get("ok", false): return false
	for key: String in ["session_id", "source_id", "bridge_id", "render_id", "life_generation", "descriptor_sha256", "placement_mode", "body_instance_id", "body_rid", "rig", "rig_instance_id", "rig_epoch"]:
		if token.get(key) != fresh.get(key): return false
	return true

## The articulated body keeps the same source life and rig after the walking
## capsule is disabled, and a confirmed final death makes owner.dead true.
## This callback deliberately does not re-use target_current(): that checks a
## live walking collider. It still rejects a replaced actor, rig or generation.
## It grants no damage, death, vehicle-contact or recovery authority.
func physical_life_current(binding: Dictionary) -> bool:
	if not Thread.is_main_thread() or _disposed or _dispose_requested or not _scene_alive() or not binding.get("source_id") is String: return false
	var id: String = binding.source_id
	if not _records.has(id): return false
	var record: Dictionary = _records[id]
	var owner: RefCounted = record.owner
	if owner.source_id != id or owner.life_generation != record.generation or not is_instance_valid(record.body) or not is_instance_valid(record.motion): return false
	var body: CharacterBody3D = record.body
	if body.is_queued_for_deletion() or body.get_parent() != _scene.get_ref() or body.get_meta("source_id", "") != id or body.get_meta("session_id", "") != _session or body.get_meta("descriptor_sha256", "") != record.row.descriptor_sha256: return false
	# DSH_RIGCACHE: same single-rig requirement, but through the cached lookup
	# instead of a scene-tree walk on every owner on every physics tick.
	var rig: Skeleton3D = _current_record_rig(record)
	if rig == null: return false
	# DSH_HFASTPATH: the same eleven comparisons in the same order, without building
	# and iterating an 11-entry Dictionary on every owner on every tick.
	if binding.get("session_id") != _session: return false
	if binding.get("source_id") != id: return false
	if binding.get("bridge_id") != record.row.bridge_id: return false
	if binding.get("render_id") != record.row.bridge_id: return false
	if binding.get("life_generation") != record.generation: return false
	if binding.get("descriptor_sha256") != record.row.descriptor_sha256: return false
	if binding.get("placement_mode") != record.get("placement_mode", "NONE"): return false
	if binding.get("body_instance_id") != body.get_instance_id(): return false
	if binding.get("body_rid") != body.get_rid(): return false
	if binding.get("rig_instance_id") != rig.get_instance_id(): return false
	if binding.get("rig_epoch") != rig.get_instance_id(): return false
	return true

## Prewarm while this source life is still an ordinary walker. The caller's
## event provider must later supply the completed source death or verified car
## contact; this method itself cannot decide damage or falling.
func prepare_physical(token: Dictionary, confirmed_events: Callable, options: Dictionary = {}) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or not confirmed_events.is_valid() or not target_current(token): return {"ok":false,"error":"current_walker_required"}
	var id: String = token.source_id
	if _ragdolls.has(id) or not _scene_alive(): return {"ok":false,"error":"already_prepared_or_scene"}
	_busy = true
	var host: RefCounted = Ragdoll.new()
	var physical_options: Dictionary = options.duplicate(true)
	var contact_player: CharacterBody3D = _scene.get_ref().get("_player") as CharacterBody3D
	if is_instance_valid(contact_player) and contact_player.has_method("final_dead_block_contract_receipt"):
		var negotiated: Dictionary = contact_player.final_dead_block_contract_receipt()
		if negotiated.get("active") == false and negotiated.get("contract") == Ragdoll.blocking_contract() and negotiated.get("actor_instance_id") == contact_player.get_instance_id() and negotiated.get("actor_rid") == contact_player.get_rid() and contact_player.collision_layer == 2 and contact_player.collision_mask == 1:
			physical_options["final_dead_blocking_bit"] = 1024
			physical_options["blocking_player"] = contact_player
	var prepared: Dictionary = host.configure(token, _scene.get_ref(), Callable(self,"physical_life_current"), confirmed_events, physical_options)
	if prepared.get("ok",false) and physical_life_current(token): _ragdolls[id] = host
	else:
		host.dispose()
		if prepared.get("ok",false): prepared = {"ok":false,"error":"life_changed_during_prepare"}
	_leave_busy()
	return prepared

## Must be called after external event admission and before the next walking
## step. The pre-hit token can remain valid when a final death set owner.dead;
## its physical-life binding still has to match the original body and rig.
func activate_physical(token: Dictionary, event_id: String) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or not physical_life_current(token) or not _ragdolls.has(token.source_id): return {"ok":false,"error":"physical_life_not_prepared"}
	var id: String = token.source_id
	var host: RefCounted = _ragdolls[id]
	if host.status().mode != "IDLE": return {"ok":false,"error":"not_idle"}
	_busy = true
	var result: Dictionary = host.activate(event_id)
	if result.get("ok",false):
		var record: Dictionary = _records[id]
		if record.request >= 0: _navigation.cancel(record.request); record.request = -1
		record.status = "PHYSICAL_DEAD" if result.get("final_dead",false) else "PHYSICAL_KNOCKDOWN"
		if _walk_preview.has(id): _walk_preview[id].awaiting = false
	_leave_busy()
	return result

func confirm_physical_death(token: Dictionary, event_id: String) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or not physical_life_current(token) or not _ragdolls.has(token.source_id): return {"ok":false,"error":"physical_life_missing"}
	_busy = true
	var result: Dictionary = _ragdolls[token.source_id].confirm_final_death(event_id)
	if result.get("ok",false): _records[token.source_id].status = "PHYSICAL_DEAD"
	_leave_busy()
	return result

func dispose() -> void:
	if not Thread.is_main_thread() or _disposed: return
	if _busy:
		_dispose_requested = true
		return
	if not _local_navigation_lease.is_empty():
		_busy=true;_release_local_navigation_adapter("host_dispose",false);_busy=false
	_disposed = true
	_dispose_requested = false
	for host: RefCounted in _ragdolls.values(): host.dispose()
	for record: Dictionary in _records.values():
		if record.get("melee_retaliation") != null: record.melee_retaliation.dispose()
	_ragdolls.clear()
	for record: Dictionary in _records.values():
		if record.request >= 0: _navigation.cancel(record.request)
		if record.activity != null: record.activity.dispose()
		if is_instance_valid(record.body): record.body.queue_free()
	_records.clear(); _manifest.clear(); _admit = Callable(); _support = Callable(); _placement_current = Callable(); _placement_receipt.clear(); _navigation = null; _box = null; _overlap = null; _ray = null
	_walk_preview.clear(); _walk_preview_enabled = false
	var scene: Node3D = _scene.get_ref() if _scene != null else null
	if is_instance_valid(scene) and scene.tree_exiting.is_connected(dispose): scene.tree_exiting.disconnect(dispose)


## ARTIST-REVIEW PROPOSAL: explicit read-only capability registration.
## Does not admit force, death, recovery or changes to collision ownership.
func public_final_dead_contact_capabilities() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not Thread.is_main_thread() or _busy or _disposed or _dispose_requested or not _scene_alive(): return result
	for host: RefCounted in _ragdolls.values():
		var state: Dictionary = host.status()
		if state.get("mode") not in ["IDLE", "ACTIVE"] or not state.get("binding") is Dictionary: continue
		var binding: Dictionary = state.binding.duplicate(true)
		if not physical_life_current(binding): continue
		result.append({"ragdoll_host":host, "binding":binding, "current_life":Callable(self,"public_final_dead_contact_current").bind(host)})
	return result


## Same-generation host replacement also retires the old capability.
func public_final_dead_contact_current(binding: Dictionary, expected_host: RefCounted) -> bool:
	if not Thread.is_main_thread() or _busy or _disposed or _dispose_requested or not _scene_alive(): return false
	if not is_instance_valid(expected_host) or _ragdolls.get(binding.get("source_id")) != expected_host: return false
	if not physical_life_current(binding): return false
	var state: Dictionary = expected_host.status()
	return state.get("mode") == "ACTIVE" and state.get("final_dead") == true and not str(state.get("death_key", "")).is_empty()

## Explicit opt-in handoff for one configured local navigation proxy. This
## suspends only that actor's circular goal producer; step() remains sole mover.
func bind_local_navigation_adapter(adapter: RefCounted, token: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _dispose_requested or not _scene_alive() or not _local_navigation_lease.is_empty(): return {"ok":false,"reason":"host_lifetime_or_bound"}
	if not is_instance_valid(adapter) or not target_current(token) or not _local_walker_current(token): return {"ok":false,"reason":"current_walker_required"}
	for method: String in ["request","poll","step","cancel","state","dispose","_current"]:
		if not adapter.has_method(method): return {"ok":false,"reason":"adapter_interface"}
	var properties := {}
	for property: Dictionary in adapter.get_property_list(): properties[str(property.name)]=true
	for property: String in ["host","base_nav","token","body","_disposed","_phase"]:
		if not properties.has(property): return {"ok":false,"reason":"adapter_binding_interface"}
	var id: String=token.source_id
	var record: Dictionary=_records[id]
	var claim: Variant=record.get("local_route_owner")
	if not claim is WeakRef or claim.get_ref()!=adapter or adapter.get("host")!=self or adapter.get("base_nav")!=_navigation or adapter.get("body")!=token.body or adapter.get("token")!=token or adapter.get("_disposed")!=false or adapter.get("_phase")!="READY": return {"ok":false,"reason":"adapter_binding_mismatch"}
	var base := _navigation
	_busy=true
	var current: Variant=adapter.call("_current")
	if not current is bool or not current or _dispose_requested or _navigation!=base or not _local_walker_current(token) or record.get("local_route_owner")!=claim or claim.get_ref()!=adapter:
		_leave_busy();return {"ok":false,"reason":"binding_changed"}
	# Cancel only the selected actor's old ordinary route. Other actors retain
	# their exact requests and their goal producer remains enabled.
	if record.request>=0: base.cancel(record.request)
	record.request=-1;record.status="IDLE";record.body.velocity=Vector3.ZERO
	_local_navigation_serial+=1
	_local_navigation_lease={"adapter":weakref(adapter),"token":token.duplicate(),"base":base,"source_id":id,"serial":_local_navigation_serial}
	_navigation=adapter
	_leave_busy()
	return {"ok":not _disposed,"source_id":id,"serial":_local_navigation_serial,"automatic_preview_suspended":true,"source_authority":false}

func _local_walker_current(token: Dictionary) -> bool:
	if not physical_life_current(token): return false
	var id: String=token.source_id
	var record: Dictionary=_records[id]
	var body: CharacterBody3D=record.body
	if not body.is_inside_tree() or body.is_queued_for_deletion(): return false
	if not _living(record) or _physical_occupied(id) or record.get("physical_failed",false) or body.collision_layer!=1 or body.collision_mask!=1 or body.get_child_count()<2:return false
	var shape: Node=body.get_child(0)
	return shape is CollisionShape3D and not shape.disabled and shape.shape is CapsuleShape3D and is_equal_approx(shape.shape.radius,.36) and is_equal_approx(shape.shape.height,HEIGHT)

## Cancel one still-owned approach/visit request before releasing its adapter.
## Navigation CANCELLED alone does not clear this host's request/status. The
## exact host slot must be normalized or the circular producer waits forever.
func cancel_local_walk(adapter: RefCounted, token: Dictionary, request_id: int) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _dispose_requested or request_id<0:return {"ok":false,"reason":"host_lifetime_or_request"}
	if not _local_request_owned(adapter,token,request_id):return {"ok":false,"reason":"request_owner_mismatch"}
	_busy=true
	adapter.cancel(request_id)
	var result: Variant=adapter.poll(request_id)
	if not result is Dictionary or result.get("status")!="CANCELLED" or not _local_request_owned(adapter,token,request_id):
		_leave_busy();return {"ok":false,"reason":"cancellation_unconfirmed_or_owner_changed"}
	var record: Dictionary=_records[token.source_id]
	record.request=-1;record.status="IDLE";record.reason=""
	if _walk_preview.has(token.source_id):
		_walk_preview[token.source_id].awaiting=false;_walk_preview[token.source_id].blocked_at=-1.0
	_leave_busy()
	return {"ok":true,"source_id":token.source_id,"cancelled_request_id":request_id,"source_authority":false}

func _local_request_owned(adapter: RefCounted, token: Dictionary, request_id: int) -> bool:
	if _disposed or _dispose_requested or _local_navigation_lease.is_empty() or _navigation!=adapter or not is_instance_valid(adapter):return false
	if _local_navigation_lease.adapter.get_ref()!=adapter or _local_navigation_lease.token!=token or not _local_walker_current(token):return false
	var record: Dictionary=_records[token.source_id]
	var claim: Variant=record.get("local_route_owner")
	return claim is WeakRef and claim.get_ref()==adapter and record.request==request_id

## The original adapter+token pair is required even if that life has since gone
## stale. A late pair cannot release a newer lease or cancel a newer route.
func release_local_navigation_adapter(adapter: RefCounted, token: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _local_navigation_lease.is_empty():return {"ok":false,"reason":"no_releasable_lease"}
	if _local_navigation_lease.adapter.get_ref()!=adapter or _local_navigation_lease.token!=token:return {"ok":false,"reason":"lease_mismatch"}
	_busy=true
	var released := _release_local_navigation_adapter("explicit_release",true)
	_leave_busy()
	return released

func _release_local_navigation_adapter(reason: String, resume_preview: bool) -> Dictionary:
	var lease := _local_navigation_lease
	if lease.is_empty():return {"ok":false,"reason":"not_bound"}
	var adapter: RefCounted=lease.adapter.get_ref()
	var base: RefCounted=lease.base
	var still_selected := _navigation==adapter or _navigation==base
	var claim: Variant=_records.get(lease.source_id,{}).get("local_route_owner")
	var claim_owned: bool=claim is WeakRef and claim.get_ref()==adapter
	# An independently disposed exact adapter removes its own weak claim and
	# restores base navigation before this sync. Same-life, absent-claim cleanup
	# must still normalize READY/-1. A live replacement claim never qualifies.
	var own_dispose_completed: bool=is_instance_valid(adapter) and adapter.get("_disposed")==true and claim==null and _navigation==base and physical_life_current(lease.token)
	_local_navigation_lease={}
	# Restore only our proxy; an unrelated newer navigation owner is untouched.
	if _navigation==adapter:_navigation=base
	if is_instance_valid(adapter):adapter.dispose()
	if resume_preview and still_selected and (claim_owned or own_dispose_completed) and _local_walker_current(lease.token):
		var record: Dictionary=_records[lease.source_id]
		# A fresh ordinary request superseding a local visit survives adapter
		# disposal. Its velocity/status/request are not cleared here.
		if record.request<0 and record.status in ["IDLE","PENDING","READY","ARRIVED","BLOCKED","STALE","CANCELLED","NO_PATH"]:record.status="IDLE"
		# The preview circuit starts at the real current position. This changes
		# no immutable source row or actor transform and is never a teleport.
		record.origin=record.body.global_position
		if _walk_preview.has(lease.source_id):
			var exercise: Dictionary=_walk_preview[lease.source_id]
			exercise.awaiting=record.request>=0 and record.status in ["PENDING","READY"]
			exercise.blocked_at=-1.0;exercise.next_at=_walk_preview_clock+1.5
	return {"ok":true,"source_id":lease.source_id,"serial":lease.serial,"reason":reason,"source_authority":false}

func _sync_local_navigation_adapter() -> void:
	if not Thread.is_main_thread() or _busy or _disposed:return
	if _local_navigation_lease.is_empty():return
	var lease := _local_navigation_lease
	var adapter: RefCounted=lease.adapter.get_ref()
	var claim: Variant=_records.get(lease.source_id,{}).get("local_route_owner")
	if not is_instance_valid(adapter) or adapter.get("_disposed")!=false or adapter.get("_phase")=="SUPERSEDED" or _navigation!=adapter or not claim is WeakRef or claim.get_ref()!=adapter or not _local_walker_current(lease.token):
		_busy=true;_release_local_navigation_adapter("adapter_or_life_ended",true);_leave_busy()

func local_navigation_adapter_status() -> Dictionary:
	if _local_navigation_lease.is_empty():return {"bound":false}
	return {"bound":true,"source_id":_local_navigation_lease.source_id,"serial":_local_navigation_lease.serial,"automatic_preview_suspended":true,"source_authority":false}


## Animation LOD (user-approved 2026-10-04): poses are rebuilt only for residents near
## the camera. Binding, physics and navigation still run for every resident, so the
## simulation is unchanged; only the visual pose refresh is coarser far away.
const ANIM_LOD_RADIUS_M := 30.0

## Shadow LOD. Measured: shadows on = draw_calls ~4550 / prims ~2.34M / fps 1.0;
## shadows off = ~3130 / ~1.55M / fps 2.0. cast_shadow is never set for resident
## visuals, so all 287 are drawn into the shadow map as well as the main pass.
## Keep shadows for near residents, drop them past ANIM_LOD_RADIUS_M: lod_skip was
## 281 of 287, so nearly the whole -32%/-34% is available without changing what is
## visible up close. Edge-triggered via record["shadow_on"].
func _set_resident_shadows(record: Dictionary, enabled: bool) -> void:
	if bool(record.get("shadow_on", true)) == enabled: return
	record["shadow_on"] = enabled
	var body: Node = record.body
	if not is_instance_valid(body): return
	var setting: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node: Node in body.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = setting

## DSH_RESID3: single camera-distance source for the animation LOD and for the
## staggered simulation cadence (no second camera lookup). 0.0 means "near",
## which preserves the previous _anim_lod_ok() result when the scene or camera
## is unavailable.
func _camera_distance_squared(record: Dictionary) -> float:
	var camera: Camera3D = _anim_lod_camera()
	if camera == null: return 0.0
	var body: CharacterBody3D = record.body
	var at: Vector3 = body.global_position if is_instance_valid(body) else (record.motion.global_position if is_instance_valid(record.motion) else camera.global_position)
	return camera.global_position.distance_squared_to(at)

func _anim_lod_ok(record: Dictionary) -> bool:
	return _camera_distance_squared(record) <= ANIM_LOD_RADIUS_M * ANIM_LOD_RADIUS_M

## DSH_RECORDLOOP: the viewport camera, resolved once at the top of step(). The
## per-record path called scene.get_viewport().get_camera_3d() on every record;
## that lookup is loop-invariant. Null reproduces every previous answer, and the
## reference is held only for the duration of one step() call.
func _anim_lod_camera() -> Camera3D:
	var scene: Node3D = _scene.get_ref() if _scene != null else null
	if not is_instance_valid(scene) or not scene.is_inside_tree(): return null
	var camera: Camera3D = scene.get_viewport().get_camera_3d()
	if not is_instance_valid(camera): return null
	return camera

# --- ported methods from city daily-cycle host (dsh_living_city_01) ---
func admit_city_spawn(identity: String, r: float, c: float) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _dispose_requested or not _scene_alive() or not _placement_receipt.is_empty(): return {"status":"UNAVAILABLE"}
	if not _records.has(identity): return {"status":"REJECTED","reason":"city_source_identity"}
	var record: Dictionary = _records[identity]
	var proposal := {"r":r,"c":c,"mode":"LOCAL_CITY_NEW_SESSION_PLACEMENT"}
	if not _city_spawn_current(record,proposal): return {"status":"REJECTED","reason":"current_new_city_unadmitted_row_required"}
	var attempts: int = int(record.get("city_spawn_attempts",0))
	if attempts >= CITY_SPAWN_ATTEMPTS: return {"status":"REJECTED","reason":"bounded_city_spawn_attempts"}
	record["city_spawn_attempts"] = attempts+1
	_busy = true
	var started := Time.get_ticks_usec()
	var result := _admit_record(record,{},proposal)
	_stats.admit_us_max = maxi(_stats.admit_us_max,Time.get_ticks_usec()-started)
	_leave_busy()
	return result

func _city_spawn_current(record: Dictionary, proposal: Dictionary) -> bool:
	if _city_spawn_context.is_empty() or not _scene_alive() or _city_spawn_context.session_id != _session or _city_spawn_context.packet_sha256 != CITY_PACKET_SHA or not _placement_receipt.is_empty(): return false
	if not _living(record) or record.status != "PENDING_PLACEMENT" or record.get("ever_admitted",false) or is_instance_valid(record.body) or record.generation != 1: return false
	var id: String = record.row.source_id
	if not _records.has(id) or not is_same(_records[id],record) or record.row.source_raw.get("id") != id: return false
	if proposal.get("mode") != "LOCAL_CITY_NEW_SESSION_PLACEMENT" or not is_finite(float(proposal.get("r",NAN))) or not is_finite(float(proposal.get("c",NAN))): return false
	var scene: Node3D = _scene.get_ref()
	var current: Variant = scene.get("_block")
	if not current is Dictionary or not is_same(current,_city_spawn_context.block) or not is_same(current.get("surface"),_city_spawn_context.surface): return false
	var crop: Dictionary = _city_spawn_context.crop
	var surface: Dictionary = current.surface
	if surface.get("cellSize") != 4.1 or surface.get("startRow") != crop.r_min or surface.get("startCol") != crop.c_min or surface.get("rows") != crop.r_max-crop.r_min or surface.get("cols") != crop.c_max-crop.c_min: return false
	return proposal.r >= crop.r_min and proposal.r < crop.r_max and proposal.c >= crop.c_min and proposal.c < crop.c_max

func _duplicate_source_body(scene: Node3D, identity: String) -> bool:
	var started:=Time.get_ticks_usec()
	var duplicate:=false
	for node: Node in scene.find_children("*", "CharacterBody3D", true, false):
		if node.get_meta("source_id", "")==identity:
			duplicate=true; break
	var elapsed:=Time.get_ticks_usec()-started
	_stats["duplicate_scan_calls"]=int(_stats.get("duplicate_scan_calls",0))+1
	_stats["duplicate_scan_us_total"]=int(_stats.get("duplicate_scan_us_total",0))+elapsed
	_stats["duplicate_scan_us_max"]=maxi(int(_stats.get("duplicate_scan_us_max",0)),elapsed)
	return duplicate

func _on_rig_tree_changed() -> void:
	_rig_tree_epoch += 1
	_rig_cache.clear()

func _disconnect_rig_tree() -> void:
	var tree: SceneTree = _rig_tree.get_ref() if _rig_tree != null else null
	if is_instance_valid(tree) and tree.tree_changed.is_connected(_on_rig_tree_changed): tree.tree_changed.disconnect(_on_rig_tree_changed)
	_rig_tree = null
	_on_rig_tree_changed()

func _current_record_rig(record: Dictionary) -> Skeleton3D:
	var motion: Node = record.get("motion")
	if not is_instance_valid(motion): return null
	var tree: SceneTree = motion.get_tree() if motion.is_inside_tree() else null
	# Detached nodes keep the original uncached find_children semantics.
	if tree == null:
		var detached: Array[Node] = motion.find_children("*", "Skeleton3D", true, false)
		_rig_cache_scans += 1
		return detached[0] as Skeleton3D if detached.size() == 1 else null
	if _rig_tree == null or _rig_tree.get_ref() != tree:
		_disconnect_rig_tree()
		_rig_tree = weakref(tree)
		tree.tree_changed.connect(_on_rig_tree_changed)
	var key: int = motion.get_instance_id()
	if _rig_cache.has(key):
		var cached: Dictionary = _rig_cache[key]
		if cached.epoch == _rig_tree_epoch and cached.motion.get_ref() == motion:
			return cached.rig.get_ref() as Skeleton3D if cached.rig != null else null
	var found: Array[Node] = motion.find_children("*", "Skeleton3D", true, false)
	_rig_cache_scans += 1
	var rig: Skeleton3D = found[0] as Skeleton3D if found.size() == 1 else null
	_rig_cache[key] = {"epoch":_rig_tree_epoch, "motion":weakref(motion), "rig":weakref(rig) if rig != null else null}
	return rig

func acquire_transport_body(adapter: RefCounted, binding: Dictionary, activity_owner: RefCounted = null) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _dispose_requested or not _transport_lease.is_empty(): return {"ok":false,"reason":"transport_busy"}
	if not is_instance_valid(adapter) or not target_current(binding) or not _local_walker_current(binding): return {"ok":false,"reason":"current_walker_required"}
	var id: String = binding.source_id
	if _daily_activities.has(id) and (_daily_activities[id].owner.get_ref()!=activity_owner or _daily_activities[id].binding!=binding): return {"ok":false,"reason":"daily_activity_owner_mismatch"}
	if not _local_navigation_lease.is_empty() and _local_navigation_lease.source_id == id: return {"ok":false,"reason":"release_local_navigation_first"}
	var record: Dictionary = _records[id]
	if record.get("local_route_owner") != null: return {"ok":false,"reason":"local_owner_present"}
	_busy = true
	if record.request >= 0: _navigation.cancel(record.request)
	if not physical_life_current(binding) or not _living(record) or _physical_occupied(id):
		_leave_busy(); return {"ok":false,"reason":"life_changed"}
	record.request = -1; record.status = "TRANSPORT"; record.reason = ""
	record.body.velocity = Vector3.ZERO
	_transport_serial += 1
	_transport_lease = {"adapter":weakref(adapter),"binding":binding.duplicate(),"serial":_transport_serial,"source_id":id,"seated":false}
	_leave_busy()
	return {"ok":true,"serial":_transport_serial,"source_id":id}

func transport_body_current(adapter: RefCounted, binding: Dictionary, serial: int) -> bool:
	if not Thread.is_main_thread() or _disposed or _dispose_requested or _transport_lease.is_empty(): return false
	if _transport_lease.adapter.get_ref() != adapter or _transport_lease.binding != binding or _transport_lease.serial != serial: return false
	if not physical_life_current(binding): return false
	var record: Dictionary = _records[binding.source_id]
	if not _living(record) or _physical_occupied(binding.source_id) or record.get("physical_failed",false) or record.request >= 0 or record.get("local_route_owner") != null: return false
	var body: CharacterBody3D = record.body
	if body.get_child_count() < 2: return false
	var shape: Node = body.get_child(0)
	var expected_filter := 0 if _transport_lease.seated else 1
	return body.collision_layer == expected_filter and body.collision_mask == expected_filter and shape is CollisionShape3D and not shape.disabled and shape.shape is CapsuleShape3D and is_equal_approx(shape.shape.radius,.36) and is_equal_approx(shape.shape.height,HEIGHT)

func transport_life_current(binding: Dictionary) -> bool:
	if not physical_life_current(binding): return false
	var record: Dictionary = _records[binding.source_id]
	return _living(record) and not _physical_occupied(binding.source_id) and not record.get("physical_failed",false)

func transport_pose_binding(adapter: RefCounted, binding: Dictionary, serial: int) -> Dictionary:
	if _busy or not transport_body_current(adapter,binding,serial): return {}
	var record: Dictionary = _records[binding.source_id]
	return {"rig":binding.rig,"motion":record.motion,"rest":record.gait._rest_poses.duplicate(),"scale":binding.rig.global_basis.get_scale().y}

func walking_pose_binding(binding: Dictionary) -> Dictionary:
	if _busy or not target_current(binding) or not _local_walker_current(binding): return {}
	var record: Dictionary=_records[binding.source_id]
	return {"rig":binding.rig,"motion":record.motion,"rest":record.gait._rest_poses.duplicate(),"scale":binding.rig.global_basis.get_scale().y}

func set_transport_seated(adapter: RefCounted, binding: Dictionary, serial: int, seated: bool) -> bool:
	if _busy or not transport_body_current(adapter,binding,serial): return false
	# The exact lease holder calls this only after BOARDED / before native exit.
	_transport_lease.seated = seated
	binding.body.collision_layer = 0 if seated else 1
	binding.body.collision_mask = 0 if seated else 1
	return true

func release_transport_body(adapter: RefCounted, binding: Dictionary, serial: int) -> Dictionary:
	if not Thread.is_main_thread() or _busy or not transport_body_current(adapter,binding,serial): return {"ok":false,"reason":"transport_owner_changed"}
	if _transport_lease.seated: return {"ok":false,"reason":"physical_exit_required"}
	var record: Dictionary = _records[binding.source_id]
	var body: CharacterBody3D = record.body
	var before := body.global_transform
	var floor_contact := KinematicCollision3D.new()
	if not body.test_move(before,Vector3.DOWN*.01,floor_contact,.001,true) or floor_contact.get_normal().dot(Vector3.UP)<.7: return {"ok":false,"reason":"physical_ground_required"}
	_busy = true
	var admitted := _source_admits(before.origin,record,"route") and _physical_clear(before.origin,[body.get_rid()]) and _owned_clear(before.origin,binding.source_id)
	if not admitted or not transport_body_current(adapter,binding,serial) or body.global_transform != before:
		_leave_busy(); return {"ok":false,"reason":"walking_admission_required"}
	_transport_lease = {}
	body.velocity = Vector3.ZERO
	var forward := (-body.global_basis.z).slide(Vector3.UP)
	if forward.length_squared() > .000001: body.global_basis = Basis(Vector3.UP,atan2(-forward.x,-forward.z))
	record.gait.reset_pose(); record.motion.rotation.y = PI
	record.status = "IDLE"; record.reason = ""; record.origin = body.global_position
	record.display_yaw = body.rotation.y; record.turn_from = body.rotation.y; record.turn_to = body.rotation.y; record.turn_elapsed = SOURCE_RENDER_YAW_SECONDS
	if _walk_preview.has(binding.source_id):
		_walk_preview[binding.source_id].awaiting=false; _walk_preview[binding.source_id].blocked_at=-1.0; _walk_preview[binding.source_id].next_at=_walk_preview_clock+1.5
	_leave_busy()
	return {"ok":true,"walking_resumed":true}

## Retire a stale lease without changing a replacement body, its filters, gait,
## request or physical-death owner. Ordinary lifecycle processing remains live.

func retire_transport_body(adapter: RefCounted, binding: Dictionary, serial: int) -> bool:
	if not Thread.is_main_thread() or _busy or _transport_lease.is_empty(): return false
	if _transport_lease.adapter.get_ref()!=adapter or _transport_lease.binding!=binding or _transport_lease.serial!=serial: return false
	if transport_body_current(adapter,binding,serial): return false
	_transport_lease={}
	return true

## Daily activity owns only the ordinary goal producer. Walking/body/gait still
## run in step(); transport may temporarily acquire their separate exact lease.

func reserve_daily_activity(owner: RefCounted, binding: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or not is_instance_valid(owner) or not target_current(binding) or not _local_walker_current(binding): return {"ok":false,"reason":"current_walker_required"}
	var id: String=binding.source_id
	if _transport_holds(id) or (not _local_navigation_lease.is_empty() and _local_navigation_lease.source_id==id): return {"ok":false,"reason":"movement_owner_present"}
	if _daily_activities.has(id):
		if _daily_activities[id].owner.get_ref()!=owner or _daily_activities[id].binding!=binding: return {"ok":false,"reason":"daily_owner_present"}
		return {"ok":true,"serial":_daily_activities[id].serial,"source_id":id}
	_daily_serial+=1
	_daily_activities[id]={"owner":weakref(owner),"binding":binding.duplicate(),"serial":_daily_serial}
	return {"ok":true,"serial":_daily_serial,"source_id":id}

func release_daily_activity(owner: RefCounted, binding: Dictionary) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed: return {"ok":false,"reason":"host_lifetime"}
	var id: String=binding.get("source_id","")
	if not _daily_activities.has(id) or _daily_activities[id].owner.get_ref()!=owner or _daily_activities[id].binding!=binding: return {"ok":false,"reason":"daily_owner_mismatch"}
	if _transport_holds(id): return {"ok":false,"reason":"physical_transport_release_first"}
	_daily_activities.erase(id)
	_resume_daily_preview(binding)
	return {"ok":true,"source_id":id}

func daily_activity_status(id: String) -> Dictionary:
	if not _daily_activities.has(id): return {"bound":false}
	var lease: Dictionary=_daily_activities[id]
	return {"bound":true,"source_id":id,"serial":lease.serial,"life_generation":lease.binding.life_generation,"owner":lease.owner.get_ref(),"current":is_instance_valid(lease.owner.get_ref()) and transport_life_current(lease.binding)}

func _daily_owned(owner: RefCounted, binding: Dictionary) -> bool:
	var id: String=binding.get("source_id","")
	return _daily_activities.has(id) and _daily_activities[id].owner.get_ref()==owner and _daily_activities[id].binding==binding and not _transport_holds(id) and _local_walker_current(binding) and (_local_navigation_lease.is_empty() or _local_navigation_lease.source_id!=id)

func request_daily_walk(owner: RefCounted, binding: Dictionary, target: Vector3) -> int:
	if not Thread.is_main_thread() or _busy or _disposed or not _daily_owned(owner,binding): return -1
	var serial: int=_daily_activities[binding.source_id].serial
	var request_id: int=request_walk(binding.source_id,target)
	if request_id<0: return -1
	if not _daily_owned(owner,binding) or _daily_activities[binding.source_id].serial!=serial: return -1
	_daily_activities[binding.source_id]["request"]=request_id
	return request_id

func cancel_daily_walk(owner: RefCounted, binding: Dictionary, exact_request_id: int) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or exact_request_id<0 or not _daily_owned(owner,binding): return {"ok":false,"reason":"daily_owner_mismatch"}
	var id: String=binding.source_id
	var serial: int=_daily_activities[id].serial
	if _daily_activities[id].get("request",-1)!=exact_request_id or _records[id].request!=exact_request_id: return {"ok":false,"reason":"request_owner_mismatch"}
	_busy=true
	_navigation.cancel(exact_request_id)
	var result: Dictionary=_navigation.poll(exact_request_id)
	if result.get("status")!="CANCELLED" or not _daily_owned(owner,binding) or _daily_activities[id].serial!=serial or _daily_activities[id].get("request",-1)!=exact_request_id or _records[id].request!=exact_request_id:
		_leave_busy();return {"ok":false,"reason":"cancellation_unconfirmed_or_owner_changed"}
	_records[id].request=-1;_records[id].status="IDLE";_records[id].reason="";_daily_activities[id]["request"]=-1
	if _walk_preview.has(id): _walk_preview[id].awaiting=false;_walk_preview[id].blocked_at=-1.0
	_leave_busy();return {"ok":true,"cancelled_request_id":exact_request_id,"source_id":id}

func _resume_daily_preview(binding: Dictionary) -> void:
	if not _local_walker_current(binding): return
	var id: String=binding.source_id
	if not _local_navigation_lease.is_empty() and _local_navigation_lease.source_id==id: return
	var record: Dictionary=_records[id]
	# Never cancel or normalize a newer request during late producer disposal.
	if record.request<0: record.status="IDLE"
	record.origin=record.body.global_position
	if _walk_preview.has(id):
		_walk_preview[id].awaiting=record.request>=0 and record.status in ["PENDING","READY"]
		_walk_preview[id].blocked_at=-1.0;_walk_preview[id].next_at=_walk_preview_clock+1.5

func _sync_daily_activities() -> void:
	for id: String in _daily_activities.keys():
		var lease: Dictionary=_daily_activities[id]
		if is_instance_valid(lease.owner.get_ref()) and transport_life_current(lease.binding): continue
		if _transport_holds(id): continue
		_daily_activities.erase(id);_resume_daily_preview(lease.binding)

func _transport_holds(id: String) -> bool:
	return not _transport_lease.is_empty() and _transport_lease.source_id==id

func _sync_transport_body() -> void:
	if _transport_lease.is_empty(): return
	var adapter: RefCounted = _transport_lease.adapter.get_ref()
	if is_instance_valid(adapter) and transport_body_current(adapter,_transport_lease.binding,_transport_lease.serial): return
	# A live same-life body with a missing adapter stays held until its owner can
	# recover it. Replaced/dead/ragdoll lives are handled by the existing host.
	if physical_life_current(_transport_lease.binding):
		var record: Dictionary = _records[_transport_lease.source_id]
		if _living(record) and not _physical_occupied(_transport_lease.source_id) and not record.get("physical_failed",false): return
	_transport_lease={}

# --- end ported methods ---