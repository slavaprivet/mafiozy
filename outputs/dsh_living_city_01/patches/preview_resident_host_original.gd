extends RefCounted
## Local immutable-session residents. No source births, agenda, save or authority.
## Caller owns navigation pump/door revisions; this host alone moves its bodies.
const Provider = preload("res://scripts/npc_visual/npc_preview_source_provider.gd")
const Cache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const Navigation = preload("res://scripts/navigation/preview_navigation_host.gd")
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
# --- end ported fields ---

func configure(scene: Node3D, navigation: RefCounted, packet: PackedByteArray, trust: Dictionary, prepared_manifest: PackedByteArray, prepared_directory: String, owners: Dictionary, source_admit: Callable, support_height: Callable) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or _scene != null: return {"ok": false, "error": "lifetime"}
	if not is_instance_valid(scene) or not scene.is_inside_tree() or not scene.global_transform.is_equal_approx(Transform3D.IDENTITY) or not navigation is Navigation or not source_admit.is_valid() or not support_height.is_valid(): return {"ok": false, "error": "host_contract"}
	if navigation._root == null or navigation._root.get_ref() != scene or navigation.state() in ["UNATTACHED", "DISPOSED", "INVALID_GEOMETRY"]: return {"ok": false, "error": "navigation_world"}
	if not trust.get("accepted") is bool or not trust.accepted or not trust.get("packet_sha256") is String or trust.packet_sha256 == REJECTED_PACKET or not trust.get("sources") is Dictionary or not trust.get("session_id") is String or not trust.get("prepared_sha256") is String: return {"ok": false, "error": "external_acceptance_required"}
	var loaded: Dictionary = Provider.load_verified(packet, trust.packet_sha256, trust.sources)
	if not loaded.ok: return loaded
	var provider: RefCounted = loaded.provider
	var receipt: Dictionary = provider.session_receipt()
	var rows: Array = provider.candidates()
	if receipt.session_id != trust.session_id or rows.is_empty() or rows.size() > MAX_RESIDENTS or owners.size() != rows.size(): return {"ok": false, "error": "session_or_owner_count"}
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
		if raw.hp <= 0 or raw.hp != raw.max_hp or raw.speed <= 0 or raw._fatigue < 0 or raw._fatigue > 1 or raw._fear < 0 or raw._fear > 1 or descriptor.height > HEIGHT: return {"ok": false, "error": "unsupported_source_state"}
		for field: String in ["dead", "_empireBoss", "_forcedCrawl", "_severMask", "_routineSpeedK", "carried", "evacuated"]:
			if raw.get(field): return {"ok": false, "error": "unsupported_source_state"}
		var speed := minf(minf(raw.speed * .4, 1.8 / 4.1) * (1 - raw._fatigue * .35) * (1 + raw._fear * .5), 1.8 / 4.1) * 4.1
		checked[row.source_id] = {"row": row, "owner": owner, "generation": owner.life_generation, "speed": speed, "status": "PENDING_PLACEMENT", "reason": "", "attempted": false, "body": null, "gait": null, "activity": null, "motion": null, "request": -1, "origin": Vector3.ZERO}
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
		var physical_lease: bool = _physical_occupied(id)
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
	for node: Node in scene.find_children("*", "CharacterBody3D", true, false):
		if node.get_meta("source_id", "") == record.row.source_id: return _reject(record, "duplicate_source_body")
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


## Let Godot resolve a small vertical floor overlap before strict path admission.
## A query previews the correction; source footprint and all obstacles still pass.
func _recover_floor_contact(record: Dictionary) -> bool:
	var body: CharacterBody3D = record.body if is_instance_valid(record.body) else null
	var id: String = record.row.source_id
	if body == null or not _living(record) or record.get("physical_failed",false) or _physical_occupied(id) or body.collision_layer != 1 or body.collision_mask != 1 or (body.is_on_floor() and record.status not in ["BLOCKED","NO_PATH"]) or body.velocity.y > 0.0: return false
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

func step(delta: float) -> void:
	if Thread.is_main_thread() and not _busy and not _disposed: _sync_local_navigation_adapter()
	if not Thread.is_main_thread() or _busy or _disposed or not is_finite(delta) or delta <= 0 or delta > .05: return
	_busy = true
	var started := Time.get_ticks_usec()
	for record: Dictionary in _records.values():
		var body: CharacterBody3D = record.body if is_instance_valid(record.body) else null
		var id: String = record.row.source_id
		var retaliation: RefCounted = record.get("melee_retaliation")
		if retaliation != null and (not _living(record) or record.get("physical_failed",false) or _physical_occupied(id) or not is_instance_valid(body)):
			retaliation.cancel("host_owner_or_physical_state")
		if record.get("physical_failed",false):
			var failed_owner: RefCounted = record.owner
			if failed_owner.source_id != id or failed_owner.life_generation != record.generation:
				if is_instance_valid(body): body.queue_free()
				record.body = null; record.status = "REMOVED"
			continue
		if _ragdolls.has(id) and _ragdolls[id].status().mode in ["IDLE", "RETIRED"]:
			# A prewarmed pool cannot outlive the walking source generation while
			# waiting for a confirmed event. A retired pool is also never reused.
			if not _living(record) or _ragdolls[id].status().mode == "RETIRED":
				_ragdolls[id].dispose(); _ragdolls.erase(id)
		if _ragdolls.has(id) and _ragdolls[id].status().mode in ["RECOVERING", "RECOVERY_HOLD"]:
			# Another owner may coordinate a source-approved rise. Never let the
			# disabled walking capsule fall through to navigation or gait here.
			if record.request >= 0: _navigation.cancel(record.request); record.request = -1
			record.status = "PHYSICAL_RECOVERING" if _ragdolls[id].status().mode == "RECOVERING" else "PHYSICAL_HOLD"
			continue
		if _ragdolls.has(id) and _ragdolls[id].status().mode == "ACTIVE":
			if record.request >= 0: _navigation.cancel(record.request); record.request = -1
			var physical: Dictionary = _ragdolls[id].advance()
			if physical.get("ok",false):
				record.status = "PHYSICAL_DEAD" if physical.get("final_dead",false) else "PHYSICAL_KNOCKDOWN"
				record["physical_anchor_world"] = physical.physical.anchor_world
				continue
			_ragdolls[id].retire("physical_advance_failed")
			_ragdolls.erase(id)
			record["physical_failed"] = true
			record.status = "PHYSICAL_FAILED"
			continue
		if not _living(record):
			if record.request >= 0: _navigation.cancel(record.request)
			if is_instance_valid(body): body.queue_free()
			record.body = null; record.gait = null; record.motion = null; record.status = "REMOVED"; record.attempted = true; continue
		if not is_instance_valid(body): continue
		if not body.is_on_floor() or record.status in ["BLOCKED","NO_PATH"]:
			_recover_floor_contact(record)
			# Recovery admission invokes source code; it may retire this actor.
			if not _living(record) or not is_instance_valid(body) or body.is_queued_for_deletion() or record.body != body: continue
			if record.get("physical_failed",false) or _physical_occupied(id) or body.collision_layer != 1 or body.collision_mask != 1: continue
		var before := body.global_position
		var walk_pause: Callable = record.get("walk_pause", Callable())
		var paused: bool = walk_pause.is_valid() and walk_pause.call()
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
			var result: Dictionary = _navigation.poll(record.request)
			if result.status == "READY": result = _navigation.step(record.request, delta, record.speed, 9.8)
			record.status = result.status
			if result.status not in ["READY", "ARRIVED"]: body.velocity = Vector3.ZERO
		var displacement := body.global_position - before
		var horizontal := Vector3(displacement.x, 0, displacement.z)
		if horizontal.length_squared() > .00000001: body.basis = Basis(Vector3.UP, atan2(-horizontal.x, -horizontal.z))
		# Source renderer interpolates the shortest yaw arc while source motion
		# can change angle immediately. Keep the physical body/path untouched;
		# rotate only the canonical presentation node against body heading.
		var desired_yaw: float = body.rotation.y
		if absf(atan2(sin(desired_yaw - float(record.turn_to)), cos(desired_yaw - float(record.turn_to)))) >= .000001:
			record.turn_from = record.display_yaw
			record.turn_to = desired_yaw
			record.turn_elapsed = 0.0
		record.turn_elapsed = minf(SOURCE_RENDER_YAW_SECONDS, float(record.turn_elapsed) + delta)
		record.display_yaw = float(record.turn_from) + atan2(sin(float(record.turn_to) - float(record.turn_from)), cos(float(record.turn_to) - float(record.turn_from))) * (float(record.turn_elapsed) / SOURCE_RENDER_YAW_SECONDS)
		record.motion.rotation.y = PI + atan2(sin(float(record.display_yaw) - desired_yaw), cos(float(record.display_yaw) - desired_yaw))
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
				for bone: int in bones.size(): rig.set_bone_pose(bone,bones[bone])
				record.motion.position = pose.visual_offset
		else:
			record.gait.update_pose(delta, horizontal / delta, body.is_on_floor() or record.status in ["IDLE", "ARRIVED"])
			if _walk_preview_enabled and record.activity != null: record.activity.step(delta, horizontal.length() / delta)
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

## Map an actual physics collider to the current visual/physical resident life.
## This transient token proves identity only: it is not bullet contact, damage,
## source hit acceptance or final-death authority.
func target_from_collider(collider: Object) -> Dictionary:
	if not Thread.is_main_thread() or _busy or _disposed or not collider is CharacterBody3D or not is_instance_valid(collider): return {"ok":false}
	for id: String in _records:
		var record: Dictionary = _records[id]
		if not _living(record) or not is_instance_valid(record.body) or record.body != collider or not is_instance_valid(record.motion): continue
		var body: CharacterBody3D = record.body
		if body.get_meta("source_id", "") != id or body.get_meta("session_id", "") != _session or body.get_meta("descriptor_sha256", "") != record.row.descriptor_sha256 or body.get_child_count() < 2: return {"ok":false}
		var shape: Node = body.get_child(0)
		if not shape is CollisionShape3D or shape.disabled or not shape.shape is CapsuleShape3D or not is_equal_approx(shape.shape.radius, .36) or not is_equal_approx(shape.shape.height, HEIGHT): return {"ok":false}
		if body.collision_layer != 1 or body.collision_mask != 1 or body.get_parent() != _scene.get_ref(): return {"ok":false}
		var rigs: Array[Node] = record.motion.find_children("*", "Skeleton3D", true, false)
		if rigs.size() != 1: return {"ok":false}
		var rig: Skeleton3D = rigs[0] as Skeleton3D
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
	var rigs: Array[Node] = record.motion.find_children("*", "Skeleton3D", true, false)
	if rigs.size() != 1: return false
	var rig: Skeleton3D = rigs[0] as Skeleton3D
	var expected := {"session_id":_session, "source_id":id, "bridge_id":record.row.bridge_id, "render_id":record.row.bridge_id, "life_generation":record.generation,
		"descriptor_sha256":record.row.descriptor_sha256, "placement_mode":record.get("placement_mode", "NONE"),
		"body_instance_id":body.get_instance_id(), "body_rid":body.get_rid(), "rig_instance_id":rig.get_instance_id(), "rig_epoch":rig.get_instance_id()}
	for key: String in expected:
		if binding.get(key) != expected[key]: return false
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