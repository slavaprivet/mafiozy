extends RefCounted
## Local immutable-session residents. No source births, agenda, save or authority.
## Caller owns navigation pump/door revisions; this host alone moves its bodies.
const Provider = preload("res://scripts/npc_visual/npc_preview_source_provider.gd")
const Cache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const Navigation = preload("res://scripts/navigation/preview_navigation_host.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const Gait = preload("res://scripts/preview_locomotion.gd")
const Ragdoll = preload("res://scripts/npc_visual/npc_ragdoll_host.gd")
const PreviewActivity = preload("res://scripts/npc_visual/npc_preview_activity.gd")
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
	if not _walk_preview_enabled or _busy or _disposed or not is_finite(delta) or delta <= 0.0 or delta > .05 or _navigation.state() != "READY": return
	_walk_preview_clock += delta
	for id: String in _records:
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
	if body == null or not _living(record) or record.get("physical_failed",false) or _physical_occupied(id) or body.collision_layer != 1 or body.collision_mask != 1 or (body.is_on_floor() and record.status != "BLOCKED") or body.velocity.y > 0.0: return false
	var before := body.global_transform
	var margin := body.safe_margin
	var snap_length := body.floor_snap_length
	var overlap_recovery := body.move_and_collide(Vector3.ZERO, true, margin, true)
	if overlap_recovery == null: return false
	var correction: Vector3 = overlap_recovery.get_travel()
	var corrected: Vector3 = before.origin + correction
	if not correction.is_finite() or correction.y < 0.0 or correction.y > .05 or Vector2(correction.x,correction.z).length() > .0001: return false
	if not _source_admits(corrected, record, "route"): return false
	# The source callback may revoke or replace the physical owner synchronously.
	if not is_instance_valid(body) or body.is_queued_for_deletion() or record.body != body or body.global_transform != before: return false
	if body.collision_layer != 1 or body.collision_mask != 1 or record.get("physical_failed",false) or _physical_occupied(id): return false
	if body.velocity.y > 0.0 or body.safe_margin != margin or body.floor_snap_length != snap_length: return false
	if not _physical_clear(corrected,[body.get_rid()]) or not _owned_clear(corrected,id): return false
	body.move_and_collide(Vector3.ZERO, false, margin, true)
	body.apply_floor_snap()
	return true

func step(delta: float) -> void:
	if not Thread.is_main_thread() or _busy or _disposed or not is_finite(delta) or delta <= 0 or delta > .05: return
	_busy = true
	var started := Time.get_ticks_usec()
	for record: Dictionary in _records.values():
		var body: CharacterBody3D = record.body if is_instance_valid(record.body) else null
		var id: String = record.row.source_id
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
		if not body.is_on_floor() or record.status == "BLOCKED":
			_recover_floor_contact(record)
			# Recovery admission invokes source code; it may retire this actor.
			if not _living(record) or not is_instance_valid(body) or body.is_queued_for_deletion() or record.body != body: continue
			if record.get("physical_failed",false) or _physical_occupied(id) or body.collision_layer != 1 or body.collision_mask != 1: continue
		var before := body.global_position
		var walk_pause: Callable = record.get("walk_pause", Callable())
		var paused: bool = walk_pause.is_valid() and walk_pause.call()
		if paused: body.velocity = Vector3.ZERO
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
		record.gait.update_pose(delta, horizontal / delta, body.is_on_floor() or record.status in ["IDLE", "ARRIVED"])
		if _walk_preview_enabled and record.activity != null: record.activity.step(delta, horizontal.length() / delta)
	_stats.steps += 1
	_stats.step_us_max = maxi(_stats.step_us_max, Time.get_ticks_usec() - started)
	_leave_busy()

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
	var prepared: Dictionary = host.configure(token, _scene.get_ref(), Callable(self,"physical_life_current"), confirmed_events, options)
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
	_disposed = true
	_dispose_requested = false
	for host: RefCounted in _ragdolls.values(): host.dispose()
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
