extends Node3D
## BUILD-owned, six-person hiring fixture, NOT current286 or a production world.
## Parent calls setup with the exact imported hero.glb PackedScene, then supplies
## provider_options() to ServicesHost. Core/professions/hiring/inventory arithmetic,
## scene/UI/input/movement and persistence belong to their respective owners.
## Bodies use global source metres. r/c are source grid coordinates (scale 4.1).
## No automatic motion, disk I/O, save schema, alternate actor meshes or engine runs.
## Dispose the host before clear_fixture(); only this fixture's owned subtree is freed.

const FIXTURE_RESIDENT_COUNT := 6
const MODEL_HEIGHT_METRES := 1.9
const SOURCE_MAX_SAFE_INTEGER := 9007199254740991
const SOURCE_PALETTE := ["FABRIC", "HAIR", "SKIN", "TRIM"]
const RELEASE_ERASE_KEYS := [
	"_residentIndoors", "_residentNativeVisit", "_civilianSeat", "_civilianTrip",
	"_civilianTripRiding", "_ambientTrafficDriver", "_ambientTrafficCarId",
	"_ambientTrafficPhase", "_ambientTrafficProgress", "_npcInitialPlacementPending",
	"_playerConversationOpen", "_mercenaryDemoLineup", "_mercenaryQaInvite"
]

# Providers deliberately return these live arrays, never duplicates.
var residents: Array = []
var gang: Array = []
var inventory: Array = []
var player: Node3D = null
var inventory_sync_count := 0
var last_error := ""
var local_enabled := true
var _owned_root: Node3D = null
var _original_rows: Array = []
var _by_source: Dictionary = {}
var _bodies_by_source: Dictionary = {}
var _detached_by_source: Dictionary = {} # Fixture bookkeeping, never a save/world schema.
var _model_metadata: Dictionary = {}
var _material_copies: Dictionary = {}
var _conversation_motion: Dictionary = {} # Actual body hold, not a daily AI/save schema.
var _released_conversation_rows: Array = [] # Removed member refs until paired end/resume.
var _player_position: Dictionary = {"x": 0.0, "y": 0.0, "z": 0.0}
var _world_scale := 4.1
var _configured := false


func setup(source_model: PackedScene, player_at: Vector3 = Vector3.ZERO,
		resident_positions: Array = [], world_scale: float = 4.1, resident_ids: Array = []) -> bool:
	# This creates controlled fixture identities, never substitutes a reduced city cohort.
	if _owned_root != null or not is_inside_tree() or source_model == null:
		last_error = "setup requires an empty fixture in the tree and an imported PackedScene"
		return false
	if not player_at.is_finite() or not is_finite(world_scale) or world_scale <= 0.0:
		last_error = "invalid source position/scale"
		return false
	var spawn_positions: Array = resident_positions.duplicate()
	if spawn_positions.is_empty():
		# Six explicit metre offsets for deterministic proximity; not city placement.
		for offset: Vector3 in [Vector3(-2, 0, -2), Vector3(0, 0, -2),
				Vector3(2, 0, -2), Vector3(-2, 0, -4), Vector3(0, 0, -4), Vector3(2, 0, -4)]:
			spawn_positions.append(player_at + offset)
	if spawn_positions.size() != FIXTURE_RESIDENT_COUNT:
		last_error = "exactly six fixture resident positions required"
		return false
	for point in spawn_positions:
		if not point is Vector3 or not point.is_finite():
			last_error = "resident position must be a finite global Vector3"
			return false
	var spawn_ids: Array = resident_ids.duplicate()
	if spawn_ids.is_empty():
		for index in FIXTURE_RESIDENT_COUNT:
			spawn_ids.append("fixture_resident_%02d" % (index + 1))
	if spawn_ids.size() != FIXTURE_RESIDENT_COUNT:
		last_error = "exactly six fixture resident IDs required"
		return false
	var seen_ids: Dictionary = {}
	for source_id in spawn_ids:
		if not source_id is String or source_id.is_empty() or seen_ids.has(source_id):
			last_error = "resident IDs must be nonempty unique Strings"
			return false
		seen_ids[source_id] = true
	_world_scale = world_scale
	last_error = ""
	_owned_root = Node3D.new()
	_owned_root.name = "OwnedHiringFixture"
	add_child(_owned_root)
	# Avoid inheriting a scaled/rotated parent: source metres are global metres.
	_owned_root.top_level = true
	_owned_root.global_transform = Transform3D.IDENTITY
	player = Node3D.new()
	player.name = "FixturePlayer"
	player.set_meta("isHero", true) # Source visibility roots exclude the local hero.
	_owned_root.add_child(player)
	player.global_position = player_at
	if not _attach_source_model(player, source_model):
		clear_fixture()
		return false
	for index in FIXTURE_RESIDENT_COUNT:
		var body := CharacterBody3D.new()
		body.name = "FixtureResident%02d" % (index + 1)
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.30 # Same controlled capsule radius as preview_player.
		capsule.height = MODEL_HEIGHT_METRES
		var collision := CollisionShape3D.new()
		collision.name = "FixtureCapsule"
		collision.shape = capsule
		collision.position.y = MODEL_HEIGHT_METRES * 0.5
		body.add_child(collision)
		_owned_root.add_child(body)
		body.global_position = spawn_positions[index]
		if not _attach_source_model(body, source_model):
			clear_fixture()
			return false
		var source_id: String = spawn_ids[index]
		body.set_meta("sourceBotId", source_id)
		var row := {"id": source_id, "sourceBotId": source_id, "body": body,
			"name": "", "look": {}, "hp": 80.0, "max_hp": 80.0,
			"alive": true, "dead": false, "_arcKey": "worker", "_relation": 0,
			"_beach": false, "_allowBeach": false, "position": {"x": 0.0, "y": 0.0, "z": 0.0}}
		row.source_position = Callable(self, "source_position").bind(source_id)
		residents.append(row)
		_original_rows.append(row)
		_by_source[source_id] = row
		_bodies_by_source[source_id] = body
		_refresh_row_position(row)
	# Fixture stock, not an invented price, hiring cap or source economy rule.
	inventory.append({"id": "pistol", "type": "weapon", "qty": 2})
	inventory.append({"id": "rifle", "type": "weapon", "qty": 2})
	_configured = true
	return true


func provider_options() -> Dictionary:
	return {"get_residents": Callable(self, "get_residents"), "get_gang": Callable(self, "get_gang"),
		"get_inventory": Callable(self, "get_inventory"), "get_player_position": Callable(self, "get_player_position"),
		"is_local": Callable(self, "is_local"), "now": Callable(self, "now"),
		"transfer_member": Callable(self, "transfer_member"), "dismiss_member": Callable(self, "dismiss_member"),
		"sync_inventory": Callable(self, "sync_inventory"), "world_scale": _world_scale,
		"begin_npc_player_conversation": Callable(self, "begin_npc_player_conversation"),
		"end_npc_player_conversation": Callable(self, "end_npc_player_conversation"),
		"resume_npc_after_player_conversation": Callable(self, "resume_npc_after_player_conversation"),
		"performance_now_ms": Callable(self, "performance_now_ms"),
		"demo_supported": Callable(self, "demo_supported")}


func performance_now_ms() -> float:
	return float(Time.get_ticks_msec())


func demo_supported() -> bool:
	return false # This controlled fixture does not claim the source URL demo mode.


func _conversation_body(row: Dictionary) -> CharacterBody3D:
	prune_released_conversation_rows()
	var source_id := str(row.get("sourceBotId", ""))
	var original: Dictionary = _by_source.get(source_id, {})
	if not _configured or not _valid_original(original) or not is_same(row.get("body"), original.body):
		return null
	# Never accept a Dictionary copy just because it points at an existing body.
	var known := is_same(row, original) or _identity_index(gang, row) >= 0 \
		or _identity_index(_released_conversation_rows, row) >= 0
	if not known:
		return null
	return original.body as CharacterBody3D


func prune_released_conversation_rows() -> void:
	# Call after successful old-host end/dispose; providers also prune lazily.
	# Never end a live conversation here or modify its row/physics. A rollback
	# can return the same member to gang, where it no longer needs a release ref.
	for index in range(_released_conversation_rows.size() - 1, -1, -1):
		var row: Dictionary = _released_conversation_rows[index]
		if not row.get("_mercenaryConversation", false) or _identity_index(gang, row) >= 0:
			_released_conversation_rows.remove_at(index)


func begin_npc_player_conversation(row: Dictionary) -> bool:
	# world.html:32481; Host owns availability/proximity and member-only flags.
	var body := _conversation_body(row)
	if not is_local() or body == null or not _valid_original(row) \
			or _identity_index(residents, row) < 0 or not body.velocity.is_finite():
		return false
	if _refresh_row_position(row) == null or get_player_position() == null:
		return false
	var source_id := str(row.sourceBotId)
	if not _conversation_motion.has(source_id):
		_conversation_motion[source_id] = {"row": row, "body": body,
			"velocity": body.velocity, "physics_processing": body.is_physics_processing(),
			"ownership_changed": false}
	elif not is_same(_conversation_motion[source_id].row, row):
		return false
	if not row.get("_playerConversationResume") is Dictionary:
		var route: Variant = row.get("_route")
		row._playerConversationResume = {"tr": row.get("tr"), "tc": row.get("tc"),
			"route": route.duplicate(true) if route is Array else null,
			"routeIndex": row.get("_routeIndex", 0), "routeKind": row.get("_routeKind", ""),
			"idleUntil": row.get("idleUntil", 0)}
	row._playerConversationOpen = true
	row._playerConversationUntil = INF
	# Source _clearNpcRoute, world.html:9547; no fabricated replacement route.
	row.merge({"_npcWanderSearch": null, "_route": null, "_routeIndex": 0,
		"_routeGoalR": null, "_routeGoalC": null, "_routeBlockedAt": 0,
		"tr": row.r, "tc": row.c, "walking": false, "walkPhase": 0,
		"_talking": SOURCE_MAX_SAFE_INTEGER}, true)
	row.ang = atan2(player.global_position.z - body.global_position.z,
		player.global_position.x - body.global_position.x)
	# Source angle is measured from +X; the imported hero faces +Z in Godot.
	body.rotation.y = PI * 0.5 - float(row.ang)
	# Physical fixture seam: a QA-injected body physics callback actually pauses.
	# No move_and_slide/route solver is created here. External movement owners must
	# honor the same hold flag, as source NPC update does.
	body.velocity = Vector3.ZERO
	body.set_physics_process(false)
	return true


func end_npc_player_conversation(row: Dictionary) -> void:
	if _conversation_body(row) == null:
		return
	var speech_until := maxf(performance_now_ms() + 120.0, float(row.get("cryUntil", 0)))
	row._playerConversationOpen = false
	row._playerConversationUntil = speech_until
	if row.get("_talking") == SOURCE_MAX_SAFE_INTEGER:
		row._talking = speech_until


func resume_npc_after_player_conversation(row: Dictionary, still_resident: bool) -> void:
	var body := _conversation_body(row)
	if body == null:
		return
	var saved: Variant = row.get("_playerConversationResume")
	row._playerConversationResume = null
	row._playerConversationOpen = false
	row._playerConversationUntil = 0
	if row.get("_talking") == SOURCE_MAX_SAFE_INTEGER:
		row._talking = 0
	var source_id := str(row.sourceBotId)
	var hold: Dictionary = _conversation_motion.get(source_id, {})
	var paired := is_same(hold.get("row"), row) and is_same(hold.get("body"), body)
	var actual_resident := still_resident and _valid_original(row) and _identity_index(residents, row) >= 0
	if actual_resident and saved is Dictionary:
		var route: Variant = saved.get("route")
		if route is Array and not route.is_empty():
			row._route = route
			row._routeIndex = mini(int(saved.get("routeIndex", 0)), route.size() - 1)
			row._routeKind = saved.get("routeKind", "")
			var next: Dictionary = route[row._routeIndex]
			row.tr = next.r
			row.tc = next.c
		elif _conversation_finite_number(saved.get("tr")) and _conversation_finite_number(saved.get("tc")):
			row.tr = float(saved.tr)
			row.tc = float(saved.tc)
		row.idleUntil = minf(float(saved.get("idleUntil", 0)), performance_now_ms() + 250.0)
	if paired:
		_conversation_motion.erase(source_id)
		# A hire/death/hospital transition must not revive stale civilian velocity
		# or its physics callback. The new owner supplies its own motion thereafter.
		if actual_resident and not hold.ownership_changed and float(row.get("hp", 0)) > 0 \
				and not row.get("dead", false) and not row.get("_mercenaryHospital", false):
			body.velocity = hold.velocity
			body.set_physics_process(bool(hold.physics_processing))
	var released_index := _identity_index(_released_conversation_rows, row)
	if released_index >= 0:
		_released_conversation_rows.remove_at(released_index)


func _conversation_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func get_residents() -> Array:
	prune_released_conversation_rows()
	return residents


func get_gang() -> Array:
	prune_released_conversation_rows()
	return gang


func get_inventory() -> Array:
	return inventory


func is_local() -> bool:
	return _configured and local_enabled and is_inside_tree()


func now() -> float:
	# Core/save deadlines follow source Date.now()/1000, including after reload.
	return Time.get_unix_time_from_system()


func get_player_position() -> Variant:
	if not _configured or not is_instance_valid(player) or not player.is_inside_tree():
		return null
	var point := player.global_position
	if not point.is_finite():
		return null
	_player_position.x = point.x
	_player_position.y = point.y
	_player_position.z = point.z
	return _player_position


func _identity_index(rows: Array, row: Dictionary) -> int:
	for index in rows.size():
		if is_same(rows[index], row):
			return index
	return -1


func _valid_original(original: Dictionary) -> bool:
	var source_id := str(original.get("id", ""))
	if not _by_source.has(source_id) or not is_same(_by_source[source_id], original):
		return false
	var body: CharacterBody3D = original.get("body") as CharacterBody3D
	return is_instance_valid(body) and body.is_inside_tree() and not body.is_queued_for_deletion() \
		and is_same(body, _bodies_by_source.get(source_id)) \
		and str(original.get("sourceBotId", "")) == source_id \
		and str(body.get_meta("sourceBotId", "")) == source_id and body.global_position.is_finite()


func transfer_member(original: Dictionary, row: Dictionary) -> bool:
	if not is_local() or not _valid_original(original) or is_same(original, row):
		return false
	var index := _identity_index(residents, original)
	if index < 0 or _identity_index(gang, row) >= 0 or str(row.get("id", "")) == "":
		return false
	if str(row.get("sourceBotId", "")) != str(original.id) or not is_same(row.get("body"), original.body):
		return false
	for member in gang:
		if member is Dictionary and (is_same(member.get("body"), original.body) \
				or str(member.get("sourceBotId", "")) == str(original.id) or member.get("id") == row.id):
			return false
	# Do not reparent, move, replace or restyle the actual person.
	row.source_position = original.source_position
	_refresh_row_position(row)
	residents.remove_at(index)
	gang.append(row)
	if _conversation_motion.has(str(original.id)):
		_conversation_motion[str(original.id)].ownership_changed = true
	return true


func dismiss_member(member: Dictionary, original: Dictionary) -> bool:
	prune_released_conversation_rows()
	if not is_local() or not _valid_original(original):
		return false
	var index := _identity_index(gang, member)
	if index < 0 or _identity_index(residents, original) >= 0:
		return false
	if not is_same(member.get("body"), original.body) or str(member.get("sourceBotId", "")) != str(original.id):
		return false
	if member.get("_mercenaryConversation", false) and _identity_index(_released_conversation_rows, member) < 0:
		_released_conversation_rows.append(member)
	# Source _dismissGangMember succeeds before releaseAsResident decides whether
	# this person can rejoin daily life. Returning false here would also block the
	# host's issued-weapon refund and core.dismiss for dead/hospital members.
	var member_hp := float(member.get("hp", 0.0))
	if not is_finite(member_hp) or member_hp <= 0.0 or member.get("dead", false) or member.get("_mercenaryHospital", false):
		gang.remove_at(index)
		_detached_by_source[str(original.id)] = {"original": original, "member": member,
			"reason": "dismissed_not_returned_to_daily_owner"}
		# Preserve actual body, death/hospital state and original reference. No HP,
		# transform, visuals, daily flags, body removal or resurrection is performed.
		return true
	# Civilian visit/idle source fields use performance.now(), not epoch deadlines.
	var stamp := float(Time.get_ticks_msec())
	var personal_weapon := str(original.get("_mercenaryOwnWeapon", "pistol"))
	if personal_weapon.is_empty():
		personal_weapon = "pistol"
	var max_hp := float(original.get("max_hp", member.get("max_hp", 80.0)))
	if not is_finite(max_hp) or max_hp <= 0.0:
		max_hp = float(member.get("max_hp", 80.0))
		if not is_finite(max_hp) or max_hp <= 0.0:
			max_hp = 80.0
	var look: Dictionary = original.get("look", {})
	var member_look: Dictionary = member.get("look", {})
	look.merge(member_look, true)
	original.look = look
	var member_name := str(member.get("name", ""))
	if not member_name.is_empty():
		original.name = member_name
	_refresh_row_position(original)
	var plan: Dictionary = original.get("_civilianPlan", {})
	original.merge({"tr": original.r, "tc": original.c, "ang": original.body.rotation.y,
		"walkPhase": 0, "walking": false, "idleUntil": stamp + 350.0,
		"hp": maxf(1.0, minf(member_hp, max_hp)), "max_hp": maxf(1.0, max_hp),
		"alive": true, "dead": false, "_hostile": false, "_fighting": false,
		"_fightingMelee": false, "snitching": false, "panicUntil": 0, "_relation": 0,
		"_beach": false, "weapon": personal_weapon, "_fightWeapon": "", "_formerMercenary": true,
		"_formerMercenaryWeapon": personal_weapon,
		"_civilianPlan": {"phase": "seek_shop", "cycle": int(plan.get("cycle", 0)) + 1, "retryAt": stamp + 800.0},
		"_buildingVisitCooldownUntil": stamp + 800.0, "_talking": 0}, true)
	var speed := float(original.get("speed", 0.0))
	if not is_finite(speed) or speed <= 0.0:
		original.speed = 1.2
	if str(original.get("_arcKey", "")).is_empty() or original._arcKey == "bandit":
		original._arcKey = "worker"
	for key in RELEASE_ERASE_KEYS:
		original.erase(key)
	# No invented _arc/emotions/navigation schema: those require the real daily owner.
	gang.remove_at(index)
	residents.append(original)
	return true


func sync_inventory(items: Array) -> void:
	# ServicesHost has already performed source inventory arithmetic in this array.
	if is_same(items, inventory):
		inventory_sync_count += 1
	else:
		last_error = "sync_inventory requires the live fixture inventory array"


func _refresh_row_position(row: Dictionary) -> Variant:
	var body: Node3D = row.get("body") as Node3D
	if not is_instance_valid(body) or not body.is_inside_tree():
		return null
	var point := body.global_position
	if not point.is_finite():
		return null
	var coordinates: Dictionary = row.get("position", {})
	coordinates.x = point.x
	coordinates.y = point.y
	coordinates.z = point.z
	row.position = coordinates
	row.r = point.z / _world_scale
	row.c = point.x / _world_scale
	return coordinates


func source_position(source_id: String) -> Variant:
	if not _configured or not _by_source.has(source_id):
		return null
	if not _valid_original(_by_source[source_id]):
		return null
	return _refresh_row_position(_by_source[source_id])


func actor_rows() -> Array:
	# Fresh array of ORIGINAL live row references, not Dictionary.duplicate snapshots.
	var rows: Array = []
	if not _configured:
		return rows
	for row in residents + gang:
		if row is Dictionary and _refresh_row_position(row) != null:
			rows.append(row)
	return rows


func original_residents() -> Array:
	# Borrowed read-only registry view for the persistence validator, including hires.
	# The six entries remain the actual original rows; caller must not mutate this array.
	return _original_rows


func original_resident(id: String) -> Dictionary:
	var row: Dictionary = _by_source.get(id, {})
	return row if _configured and _valid_original(row) else {}


func source_body(id: String) -> Node3D:
	# Lookup is by stable sourceBotId, regardless of current resident/gang ownership.
	if original_resident(id).is_empty():
		return null
	return _bodies_by_source.get(id) as Node3D


func detached_rows() -> Array:
	# Diagnostic ownership records holding original/member refs for death/hospital
	# owners. These persons are absent from residents/gang, but their bodies remain.
	return _detached_by_source.values()


func ownership_snapshot() -> Dictionary:
	# In-memory transaction token only. Shallow copies preserve actual row/body refs;
	# caller owns restoring row fields/inventory, while this restores membership.
	var motion: Dictionary = {}
	for source_id in _conversation_motion:
		# Isolate mutable ownership_changed without copying actual row/body refs.
		motion[source_id] = _conversation_motion[source_id].duplicate()
	return {"owner": self, "originals": _original_rows.duplicate(),
		"bodies": _bodies_by_source.duplicate(), "residents": residents.duplicate(),
		"gang": gang.duplicate(), "detached": _detached_by_source.duplicate(),
		"released_conversation_rows": _released_conversation_rows.duplicate(),
		"conversation_motion": motion}


func restore_ownership(snapshot: Dictionary) -> bool:
	# Validate the entire six-body closure before touching any live container.
	if not is_local() or not is_same(snapshot.get("owner"), self):
		return false
	for key in ["originals", "residents", "gang", "released_conversation_rows"]:
		if not snapshot.get(key) is Array:
			return false
	if not snapshot.get("bodies") is Dictionary or not snapshot.get("detached") is Dictionary \
			or not snapshot.get("conversation_motion") is Dictionary:
		return false
	if _original_rows.size() != FIXTURE_RESIDENT_COUNT or snapshot.originals.size() != FIXTURE_RESIDENT_COUNT \
			or snapshot.bodies.size() != FIXTURE_RESIDENT_COUNT:
		return false
	for index in FIXTURE_RESIDENT_COUNT:
		var original: Dictionary = _original_rows[index]
		if not is_same(snapshot.originals[index], original) or not _valid_original(original) \
				or not is_same(snapshot.bodies.get(str(original.id)), original.body):
			return false
	var seen: Dictionary = {}
	for row in snapshot.residents:
		if not row is Dictionary or not _valid_original(row) or seen.has(str(row.id)):
			return false
		seen[str(row.id)] = true
	for row in snapshot.gang:
		if not _snapshot_member_valid(row, seen):
			return false
		seen[str(row.sourceBotId)] = true
	for source_id in snapshot.detached:
		var record: Variant = snapshot.detached[source_id]
		if not source_id is String or not record is Dictionary \
				or not is_same(record.get("original"), _by_source.get(source_id)) \
				or not _snapshot_member_valid(record.get("member"), seen):
			return false
		if str(record.member.sourceBotId) != source_id:
			return false
		seen[source_id] = true
	if seen.size() != FIXTURE_RESIDENT_COUNT:
		return false
	var released: Array = []
	for row in snapshot.released_conversation_rows:
		if not _snapshot_member_valid(row, {}) or _identity_index(released, row) >= 0:
			return false
		released.append(row)
	var motion: Dictionary = {}
	for source_id in snapshot.conversation_motion:
		var hold: Variant = snapshot.conversation_motion[source_id]
		if not source_id is String or not hold is Dictionary:
			return false
		var original: Dictionary = _by_source.get(source_id, {})
		if not _valid_original(original) or not is_same(hold.get("row"), original) \
				or not is_same(hold.get("body"), original.body) \
				or not hold.get("velocity") is Vector3 \
				or not hold.get("physics_processing") is bool \
				or not hold.get("ownership_changed") is bool:
			return false
		if not hold.velocity.is_finite():
			return false
		motion[source_id] = hold.duplicate()
	residents.assign(snapshot.residents)
	gang.assign(snapshot.gang)
	_detached_by_source.clear()
	_detached_by_source.merge(snapshot.detached)
	_released_conversation_rows.assign(released)
	_conversation_motion.clear()
	_conversation_motion.merge(motion)
	return true


func _snapshot_member_valid(row: Variant, seen: Dictionary) -> bool:
	if not row is Dictionary:
		return false
	var source_id := str(row.get("sourceBotId", ""))
	var original: Dictionary = _by_source.get(source_id, {})
	return not seen.has(source_id) and _valid_original(original) \
		and not str(row.get("id", "")).is_empty() and not is_same(row, original) \
		and is_same(row.get("body"), original.body)


func get_actor(id: String) -> Node3D:
	if not _configured:
		return null
	for row in gang + residents:
		if row is Dictionary and (str(row.get("id", "")) == id or str(row.get("sourceBotId", "")) == id):
			var body: Node3D = row.get("body") as Node3D
			if is_instance_valid(body) and body.is_inside_tree() and not body.is_queued_for_deletion() \
					and is_same(body, _bodies_by_source.get(str(row.get("sourceBotId", "")))):
				return body
	for source_id in _detached_by_source:
		var detached: Dictionary = _detached_by_source[source_id]
		if str(source_id) == id or str(detached.member.get("id", "")) == id:
			return source_body(str(source_id))
	return null


func getActor(id: String) -> Node3D:
	return get_actor(id)


func identity_snapshots() -> Array:
	# Diagnostics only; this is NOT a save/export schema and has no restore operation.
	var result: Array = []
	for original in _original_rows:
		var body: Node3D = _bodies_by_source.get(str(original.id)) as Node3D
		if not is_instance_valid(body):
			continue
		var member_id := ""
		for member in gang:
			if is_same(member.body, body):
				member_id = str(member.id)
		result.append({"sourceBotId": original.id, "body_instance_id": body.get_instance_id(),
			"global_transform": body.global_transform, "global_position": body.global_position,
			"member_id": member_id, "original_in_residents": _identity_index(residents, original) >= 0,
			"detached_from_daily_and_gang": _detached_by_source.has(str(original.id)),
			"original_row_retained": is_same(_by_source.get(str(original.id)), original)})
	return result


func model_metadata(id: String) -> Dictionary:
	var body := player if id == "player" else get_actor(id)
	return _model_metadata.get(body.get_instance_id(), {}) if is_instance_valid(body) else {}


func head_world_position(id: String) -> Variant:
	var data := model_metadata(id)
	if data.is_empty():
		return null
	var skeleton: Skeleton3D = data.get("skeleton") as Skeleton3D
	var bone := int(data.get("head_bone", -1))
	if is_instance_valid(skeleton) and bone >= 0:
		return skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	var body := player if id == "player" else get_actor(id)
	return body.global_transform * data.head_anchor_local if is_instance_valid(body) else null


func _attach_source_model(body: Node3D, source_model: PackedScene) -> bool:
	var instance: Node = source_model.instantiate()
	var hero := instance as Node3D
	if hero == null:
		instance.free()
		last_error = "source asset has no Node3D root; no substitute actor generated"
		return false
	var normalized := Node3D.new()
	normalized.name = "UniformModelScale"
	body.add_child(normalized)
	normalized.add_child(hero)
	var meshes: Array[Node] = hero.find_children("*", "MeshInstance3D", true, false)
	if hero is MeshInstance3D:
		meshes.push_front(hero)
	var bounds := AABB()
	var have_bounds := false
	var mesh_count := 0
	var colored_surfaces := 0
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var to_model := normalized.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = to_model * mesh_instance.get_aabb()
		if not mesh_bounds.position.is_finite() or not mesh_bounds.size.is_finite():
			last_error = "source mesh AABB is nonfinite"
			return false
		bounds = bounds.merge(mesh_bounds) if have_bounds else mesh_bounds
		have_bounds = true
		mesh_count += 1
		for surface in mesh_instance.mesh.get_surface_count():
			var original := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if original == null or original.resource_name not in SOURCE_PALETTE:
				continue
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if colors.is_empty() or colors.size() != vertices.size():
				last_error = "canonical palette surface lacks matching COLOR_0"
				return false
			var material_id := original.get_instance_id()
			var restored := _material_copies.get(material_id) as BaseMaterial3D
			if restored == null:
				restored = original.duplicate() as BaseMaterial3D
				restored.vertex_color_use_as_albedo = true
				restored.vertex_color_is_srgb = false
				_material_copies[material_id] = restored
			mesh_instance.set_surface_override_material(surface, restored)
			colored_surfaces += 1
	if not have_bounds or bounds.size.y <= 0.001:
		last_error = "source model has no finite nonzero mesh height"
		return false
	var factor := MODEL_HEIGHT_METRES / bounds.size.y
	normalized.scale = Vector3.ONE * factor
	var center := bounds.get_center()
	normalized.position = Vector3(-center.x, -bounds.position.y, -center.z) * factor
	for node in hero.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).stop() # No independent model animation owns movement here.
	var head_skeleton: Skeleton3D = null
	var head_bone := -1
	for node in hero.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		for bone in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(bone).to_lower()
			if bone_name == "head" or bone_name.ends_with(":head") or bone_name.ends_with("_head"):
				head_skeleton = skeleton
				head_bone = bone
				break
		if head_bone >= 0:
			break
	_model_metadata[body.get_instance_id()] = {"model": hero, "normalized": normalized,
		"source_bounds": bounds, "source_height": bounds.size.y, "uniform_scale": factor,
		"mesh_count": mesh_count, "vertex_color_surfaces": colored_surfaces,
		"skeleton": head_skeleton, "head_bone": head_bone,
		"head_anchor_local": Vector3(0, MODEL_HEIGHT_METRES, 0),
		"head_anchor_kind": "source_bone" if head_bone >= 0 else "normalized_AABB_top"}
	return true


func clear_fixture() -> void:
	_clear_registry()
	if is_instance_valid(_owned_root):
		if _owned_root.get_parent() == self:
			remove_child(_owned_root)
		_owned_root.queue_free()
	_owned_root = null


func _clear_registry() -> void:
	_configured = false
	# Clear exposed containers in place, so held provider references become empty.
	residents.clear()
	gang.clear()
	inventory.clear()
	_original_rows.clear()
	_by_source.clear()
	_bodies_by_source.clear()
	_detached_by_source.clear()
	_model_metadata.clear()
	_material_copies.clear()
	_conversation_motion.clear()
	_released_conversation_rows.clear()
	player = null
	inventory_sync_count = 0


func _exit_tree() -> void:
	# Tree exit already owns child removal; do not remove_child inside that traversal.
	_clear_registry()
	if is_instance_valid(_owned_root):
		_owned_root.queue_free()
	_owned_root = null
