extends RefCounted
## BUILD storage/transaction owner for the one common hiring fixture.
## Save bytes are exactly the source {core, rows} envelope. Bodies and inventory
## stay owned by the fixture; no actor is allocated, replaced or reparented here.
const Persistence = preload("res://addons/walk_mercenary/mercenary_persistence.gd")
const WORLD_SCALE := 4.1
const SAVE_PATH := "user://gang_recruitment_save.json"
const PHYSICAL_OWNER_FLAGS := ["_mercenaryVehicleId", "_mercenaryVehicleSeat",
	"_civilianSeat", "_civilianTrip", "_civilianTripRiding", "_ambientTrafficDriver",
	"_carriedByAmbulance", "vehicleId", "vehicle_id", "_inVehicle", "_inCar"]

signal bindings_changed(core: RefCounted, host: RefCounted)
signal bindings_retiring(old_host: RefCounted)

var _world: Node
var _core: Variant = null
var _host: Variant = null
var _core_script: GDScript
var _host_script: GDScript
var _host_options: Dictionary = {}
var _path := SAVE_PATH
var _blocked := false
var _busy := false
var _configured := false
var _serial := 0
var _last_receipt: Dictionary = {}


func configure(world: Node, core: RefCounted, host: RefCounted,
		core_script: GDScript, host_script: GDScript, save_path: String = SAVE_PATH,
		host_options: Dictionary = {}) -> bool:
	if _configured or not is_instance_valid(world) or core == null or host == null \
			or core_script == null or host_script == null or save_path.is_empty():
		return false
	for method: String in ["provider_options", "original_residents", "original_resident",
			"source_body", "detached_rows", "ownership_snapshot", "restore_ownership",
			"get_residents", "get_gang", "get_inventory", "is_local", "now", "dismiss_member", "sync_inventory"]:
		if not world.has_method(method):
			return false
	for method: String in ["snapshot", "restore", "get_roster", "get_record", "get_action"]:
		if not core.has_method(method):
			return false
	for method: String in ["export_host_rows", "member_row", "reconcile_inventory", "dispose"]:
		if not host.has_method(method):
			return false
	var options: Dictionary = world.call("provider_options")
	if not is_equal_approx(float(options.get("world_scale", WORLD_SCALE)), WORLD_SCALE):
		return false
	_world = world
	_core = core
	_host = host
	_core_script = core_script
	_host_script = host_script
	_host_options = host_options.duplicate()
	_path = save_path
	_configured = true
	return true


func get_core() -> RefCounted:
	return _core


func get_host() -> RefCounted:
	return _host


func is_autosave_blocked() -> bool:
	return _blocked


func diagnostics() -> Dictionary:
	return {"configured": _configured, "busy": _busy, "autosave_blocked": _blocked,
		"path": _path, "last_receipt": _last_receipt.duplicate(true)}


func _ready_to_use() -> bool:
	return _configured and is_instance_valid(_world) and _core != null and _host != null \
		and _world.call("is_local") == true


func _result(ok: bool, reason: String, extra: Dictionary = {}) -> Dictionary:
	var receipt := {"ok": ok, "reason": reason, "preserved": not ok,
		"block_autosave": _blocked}
	if not ok:
		receipt.error = reason
	receipt.merge(extra, true)
	_last_receipt = receipt.duplicate(true)
	return receipt


func _reject_restore(reason: String) -> Dictionary:
	_blocked = true
	return _result(false, reason)


## Wire this method as ServicesHost's persist callback before configure().
## Ignore supplied snapshots: encode_current reads the current physical bodies.
func persist(_snapshot: Dictionary, _rows: Array) -> Dictionary:
	return save_now()


func encode_current() -> Dictionary:
	if not _ready_to_use():
		return _result(false, "owner_unavailable")
	var registry: Dictionary = _inspect_registry()
	if not registry.ok:
		return _result(false, registry.reason)
	var rows: Array = _host.export_host_rows()
	var snapshot: Dictionary = _core.snapshot()
	var encoded: Dictionary = Persistence.encode(snapshot, rows, float(_host.now()),
		_host_options.get("qa_enabled", false) == true)
	if not encoded.ok:
		return _result(false, str(encoded.get("error", "encode_failed")))
	return encoded


func save_now() -> Dictionary:
	if _busy:
		return _result(false, "transaction_busy")
	if _blocked:
		return _result(false, "autosave_blocked")
	var encoded: Dictionary = encode_current()
	if not encoded.ok:
		return encoded
	_busy = true
	var receipt: Dictionary = _replace_file(encoded.text.to_utf8_buffer())
	_busy = false
	return receipt


func load_now() -> Dictionary:
	if _busy:
		return _result(false, "transaction_busy")
	if not _ready_to_use():
		return _reject_restore("owner_unavailable")
	if not FileAccess.file_exists(_path):
		# Missing file is a no-op, never permission to overwrite a rejected save.
		return _result(true, "missing_save", {"missing": true, "preserved": true})
	var file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return _reject_restore("save_read_failed")
	var size := file.get_length()
	if size > Persistence.MAX_BYTES:
		file.close()
		return _reject_restore("save_size_limit")
	var bytes: PackedByteArray = file.get_buffer(size)
	var read_error := file.get_error()
	file.close()
	if bytes.size() != size or read_error != OK:
		return _reject_restore("save_read_failed")
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _reject_restore("invalid_utf8_bytes")
	# Do not normalize JSON escapes. The exact frozen helper owns parsing;
	# qualified source UTF-16 core-name behavior remains an independent QA gate.
	return restore_text(text)


func restore_text(text: Variant) -> Dictionary:
	if _busy:
		return _result(false, "transaction_busy")
	if not _ready_to_use():
		return _reject_restore("owner_unavailable")
	_busy = true
	var plan: Dictionary = Persistence.prepare_restore(text)
	if not plan.ok:
		_busy = false
		return _reject_restore(str(plan.get("error", "prepare_failed")))
	if plan.get("missing", false):
		_busy = false
		return _result(true, "missing_save", {"missing": true, "preserved": true})
	var registry: Dictionary = _inspect_registry()
	if not registry.ok:
		_busy = false
		return _reject_restore(registry.reason)
	# Source core.restore rejects active commands. Do not erase commitments by
	# sidestepping that rule through a fresh staging object.
	var current: Dictionary = _core.snapshot()
	if not current.pendingTransactions.is_empty() or not current.charges.is_empty():
		_busy = false
		return _reject_restore("commands_active")
	for record: Dictionary in _core.get_roster():
		if _core.get_action(record.id) != null:
			_busy = false
			return _reject_restore("commands_active")
	for member: Dictionary in registry.gang:
		if _has_physical_owner(member):
			_busy = false
			return _reject_restore("physical_owner_release_required")
	var stage: Dictionary = _stage(plan, registry)
	if not stage.ok:
		_busy = false
		return _reject_restore(stage.reason)
	var committed: Dictionary = _commit(stage, registry)
	if not committed.ok:
		stage.host.dispose()
		_busy = false
		_blocked = true
		return _result(false, committed.reason, {"preserved": committed.get("preserved", true)})
	_blocked = false
	# Parent rebuilds UI bindings against these new instances; old host is disposed.
	bindings_changed.emit(_core, _host)
	_busy = false
	var details := {"ids": plan.expected_ids.duplicate(),
		"disk_written": false, "body_count": stage.members.size()}
	# Surface the helper's qualified source-name migration only in this receipt.
	# It is neither a save-schema field nor permission to rewrite original bytes.
	if plan.get("compatibility") is Dictionary:
		details.compatibility = plan.compatibility.duplicate(true)
	return _result(true, "restored", details)


func _inspect_registry() -> Dictionary:
	var originals: Array = _world.call("original_residents")
	var residents: Array = _world.call("get_residents")
	var gang: Array = _world.call("get_gang")
	var by_source: Dictionary = {}
	var seen_bodies: Dictionary = {}
	for value: Variant in originals:
		if not value is Dictionary or not value.get("id") is String or value.id.is_empty():
			return {"ok": false, "reason": "invalid_original_identity"}
		var source_id: String = value.id
		var body: Node3D = value.get("body") as Node3D
		if by_source.has(source_id) or not is_instance_valid(body) or not body.is_inside_tree() \
				or body.is_queued_for_deletion() or not body.global_position.is_finite() \
				or seen_bodies.has(body.get_instance_id()) \
				or not is_same(_world.call("original_resident", source_id), value) \
				or not is_same(_world.call("source_body", source_id), body) \
				or str(body.get_meta("sourceBotId", "")) != source_id:
			return {"ok": false, "reason": "original_body_identity_mismatch"}
		by_source[source_id] = value
		seen_bodies[body.get_instance_id()] = true
	var owned: Dictionary = {}
	var members: Dictionary = {}
	var detached: Dictionary = {}
	for entry: Variant in _world.call("detached_rows"):
		if not entry is Dictionary or not entry.get("original") is Dictionary or not entry.get("member") is Dictionary:
			return {"ok": false, "reason": "invalid_detached_owner"}
		var source_id := str(entry.original.get("id", ""))
		if not by_source.has(source_id) or owned.has(source_id) \
				or not is_same(entry.original, by_source[source_id]) \
				or not is_same(entry.member.get("body"), by_source[source_id].body):
			return {"ok": false, "reason": "detached_body_ownership_conflict"}
		owned[source_id] = true
		detached[source_id] = entry
	for value: Variant in residents + gang:
		if not value is Dictionary:
			return {"ok": false, "reason": "invalid_live_row"}
		var source_id := str(value.get("sourceBotId", value.get("id", "")))
		if not by_source.has(source_id) or owned.has(source_id) \
				or not is_same(value.get("body"), by_source[source_id].body):
			return {"ok": false, "reason": "live_body_ownership_conflict"}
		owned[source_id] = true
	for value: Variant in residents:
		if not is_same(value, by_source.get(str(value.id))):
			return {"ok": false, "reason": "resident_row_replaced"}
	for value: Variant in gang:
		var id := str(value.get("id", ""))
		if id != "merc_" + str(value.sourceBotId) or members.has(id) \
				or not is_same(_host.member_row(id), value) or _core.get_record(id) == null:
			return {"ok": false, "reason": "live_member_identity_mismatch"}
		members[id] = value
	if owned.size() != originals.size() or members.size() != _core.get_roster().size():
		return {"ok": false, "reason": "incomplete_live_ownership"}
	return {"ok": true, "originals": originals, "by_source": by_source,
		"residents": residents, "gang": gang, "members": members, "detached": detached}


func _stage(plan: Dictionary, registry: Dictionary) -> Dictionary:
	if plan.expected_ids.size() > 5:
		return {"ok": false, "reason": "squad_capacity_exceeded"}
	var options: Dictionary = _world.call("provider_options")
	options.merge(_host_options, true)
	options.world_scale = WORLD_SCALE
	options.persist = Callable(self, "persist")
	var host: Variant = _host_script.new(options)
	var core: Variant = _core_script.new(host.core_options())
	if not host.bind_core(core):
		host.dispose()
		return {"ok": false, "reason": "stage_bind_failed"}
	var restored: Dictionary = core.restore(plan.core)
	if not restored.get("ok", false):
		host.dispose()
		return {"ok": false, "reason": "core_restore_" + str(restored.get("reason", "failed"))}
	var actual_ids: Array = []
	for record: Dictionary in core.get_roster():
		actual_ids.append(record.id)
	if actual_ids != plan.expected_ids:
		host.dispose()
		return {"ok": false, "reason": "restored_ids_differ"}
	var members: Array = []
	var positions: Array[Vector3] = []
	var sources: Dictionary = {}
	for saved: Dictionary in plan.rows:
		var id: String = saved.id
		var source_id := str(saved.get("sourceBotId", ""))
		if saved.get("sourceBotId") == null and id.begins_with("merc_"):
			source_id = id.trim_prefix("merc_")
		if id != "merc_" + source_id or not registry.by_source.has(source_id) or sources.has(source_id):
			host.dispose()
			return {"ok": false, "reason": "unresolved_original_resident"}
		if registry.detached.has(source_id):
			host.dispose()
			return {"ok": false, "reason": "detached_body_owner_release_required"}
		var original: Dictionary = registry.by_source[source_id]
		if _has_physical_owner(original) or _has_physical_owner(saved):
			host.dispose()
			return {"ok": false, "reason": "physical_owner_release_required"}
		var body: Node3D = original.body
		var row: Dictionary = Persistence.normalize_host_row(saved, core.get_record(id),
			float(host.now()), options.get("qa_enabled", false) == true)
		# Full host name is required here; never reconstruct it from truncated core.
		if not row.get("name") is String or not row.get("look", {}) is Dictionary \
				or float(row.max_hp) <= 0.0:
			host.dispose()
			return {"ok": false, "reason": "invalid_host_person_fields"}
		row.sourceBotId = source_id
		row.body = body
		row.look = row.get("look", {}).duplicate(true)
		row.source_position = original.get("source_position")
		# Source envelope has no Y. Fixture ground is flat; preserve current feet Y.
		# A production terrain owner may provide ground_height(x,z) explicitly.
		var target := Vector3(float(row.c) * WORLD_SCALE, body.global_position.y,
			float(row.r) * WORLD_SCALE)
		var ground: Callable = options.get("ground_height", Callable())
		if ground.is_valid():
			var height: Variant = ground.call(target.x, target.z)
			if not (height is int or height is float) or not is_finite(float(height)):
				host.dispose()
				return {"ok": false, "reason": "invalid_restored_ground"}
			target.y = float(height)
		if not target.is_finite() or not host.bind_restored_member(row, original):
			host.dispose()
			return {"ok": false, "reason": "stage_member_bind_failed"}
		members.append(row)
		positions.append(target)
		sources[source_id] = true
	var inventory: Dictionary = _stage_inventory(core)
	if not inventory.ok:
		host.dispose()
		return inventory
	return {"ok": true, "core": core, "host": host, "members": members,
		"positions": positions, "sources": sources, "inventory": inventory.items,
		"gross_inventory": inventory.gross}


func _has_physical_owner(row: Dictionary) -> bool:
	for key: String in PHYSICAL_OWNER_FLAGS:
		var value: Variant = row.get(key)
		if value == null:
			continue
		if value is bool and not value:
			continue
		if value is String and value.is_empty():
			continue
		if (value is int or value is float) and value == 0:
			continue
		return true
	return false


func _quantity(item: Dictionary) -> Variant:
	var value: Variant = item.get("qty", item.get("count", item.get("quantity", 0)))
	return float(value) if (value is int or value is float) and is_finite(float(value)) and value >= 0 else null


func _set_quantity(item: Dictionary, value: float) -> void:
	item.qty = value
	if item.has("count"):
		item.count = value
	if item.has("quantity"):
		item.quantity = value


func _stage_inventory(next_core: Variant) -> Dictionary:
	var inventory: Array = _world.call("get_inventory")
	var items: Array = inventory.duplicate(true)
	for item: Variant in items:
		if not item is Dictionary or (item.get("type") == "weapon" and _quantity(item) == null):
			return {"ok": false, "reason": "invalid_inventory_row"}
	# First return receipts owned by the old core into the staged available pool.
	for record: Dictionary in _core.get_roster():
		var weapon: Variant = record.get("weapon")
		if weapon == null:
			continue
		if not _valid_issued_weapon(weapon):
			return {"ok": false, "reason": "invalid_issued_weapon_receipt"}
		var matched := false
		for item: Dictionary in items:
			if item.get("id") == weapon.id and item.get("type") == "weapon":
				_set_quantity(item, float(_quantity(item)) + 1.0)
				matched = true
				break
		if not matched:
			var returned: Dictionary = weapon.duplicate(true)
			returned.merge({"qty": 1, "count": 1, "quantity": 1}, true)
			items.append(returned)
	# Match the public host reconciler: string IDs, pool order, and reservation
	# spread over rows. Retain GROSS separately so the fresh host sees live refs
	# before its first debit. Passing NET to it would reserve the weapon twice.
	var gross: Array = items.duplicate(true)
	var reserved: Dictionary = {}
	for record: Dictionary in next_core.get_roster():
		var weapon: Variant = record.get("weapon")
		if weapon == null:
			continue
		if not _valid_issued_weapon(weapon):
			return {"ok": false, "reason": "invalid_saved_weapon_receipt"}
		var id := str(weapon.id)
		reserved[id] = float(reserved.get(id, 0.0)) + 1.0
	for item: Dictionary in items:
		if item.get("type") != "weapon":
			continue
		var id := str(item.get("id", item.get("item_id", "")))
		var remaining := float(reserved.get(id, 0.0))
		if remaining > 0.0:
			var used := minf(float(_quantity(item)), remaining)
			_set_quantity(item, float(_quantity(item)) - used)
			reserved[id] = remaining - used
	for remaining: Variant in reserved.values():
		if float(remaining) > 0.0:
			return {"ok": false, "reason": "saved_issued_weapon_unavailable"}
	return {"ok": true, "items": items, "gross": gross}


func _valid_issued_weapon(value: Variant) -> bool:
	if not value is Dictionary or value.get("type") != "weapon":
		return false
	var id: Variant = value.get("id")
	return id is String or ((id is int or id is float) and is_finite(float(id)))


func _commit(stage: Dictionary, registry: Dictionary) -> Dictionary:
	# No await or external presentation callback until the complete binding swap.
	# Owner rejects concurrent input using _busy; rollback retains original rows.
	var ownership: Dictionary = _world.call("ownership_snapshot")
	var old_gang: Array = registry.gang.duplicate()
	var old_gang_values: Array = registry.gang.duplicate(true)
	var inventory: Array = _world.call("get_inventory")
	var old_inventory: Array = inventory.duplicate()
	var old_inventory_values: Array = inventory.duplicate(true)
	var old_originals: Array = []
	var old_transforms: Array[Transform3D] = []
	var old_velocities: Array[Vector3] = []
	for original: Dictionary in registry.originals:
		old_originals.append(original.duplicate(true))
		var body: Node3D = original.body
		old_transforms.append(body.global_transform)
		old_velocities.append(body.velocity if body is CharacterBody3D else Vector3.ZERO)
	var failure := ""
	for old_member: Dictionary in old_gang:
		if not stage.sources.has(str(old_member.sourceBotId)):
			if _world.call("dismiss_member", old_member, registry.by_source[str(old_member.sourceBotId)]) != true:
				failure = "resident_release_rejected"
				break
	if failure.is_empty():
		# Daily dismissal may move a dead/hospital member into the detached owner.
		# Keep the resulting daily residents; rebuilding from all originals revives
		# those detached actors. Previously selected gang rows stay gang-owned.
		var remaining_residents: Array = []
		for resident: Dictionary in registry.residents:
			if not stage.sources.has(str(resident.id)):
				remaining_residents.append(resident)
		registry.residents.clear()
		registry.residents.append_array(remaining_residents)
		registry.gang.clear()
		registry.gang.append_array(stage.members)
		for index: int in range(stage.members.size()):
			var member: Dictionary = stage.members[index]
			var body: Node3D = member.body
			body.global_position = stage.positions[index]
			if body is CharacterBody3D:
				body.velocity = Vector3.ZERO
			member.position = {"x": body.global_position.x, "y": body.global_position.y, "z": body.global_position.z}
			if not body.global_position.is_equal_approx(stage.positions[index]):
				failure = "body_placement_rejected"
				break
	if failure.is_empty():
		# Preserve the live array and existing Dictionary refs, including the refs
		# remembered by inventory UI. Only a returned missing item is appended.
		for index: int in range(stage.gross_inventory.size()):
			if index < inventory.size():
				inventory[index].clear()
				inventory[index].merge(stage.gross_inventory[index], true)
			else:
				inventory.append(stage.gross_inventory[index].duplicate(true))
		stage.host.reconcile_inventory(inventory)
		if inventory != stage.inventory:
			failure = "inventory_reconciliation_mismatch"
	if not failure.is_empty():
		for index: int in range(registry.originals.size()):
			var original: Dictionary = registry.originals[index]
			original.clear()
			original.merge(old_originals[index], true)
			var body: Node3D = original.body
			body.global_transform = old_transforms[index]
			if body is CharacterBody3D:
				body.velocity = old_velocities[index]
		for index: int in range(old_gang.size()):
			old_gang[index].clear()
			old_gang[index].merge(old_gang_values[index], true)
		for index: int in range(old_inventory.size()):
			old_inventory[index].clear()
			old_inventory[index].merge(old_inventory_values[index], true)
		inventory.clear()
		inventory.append_array(old_inventory)
		var rolled_back: bool = _world.call("restore_ownership", ownership) == true
		return {"ok": false, "reason": failure if rolled_back else "ownership_rollback_failed",
			"preserved": rolled_back}
	var old_host: Variant = _host
	# Synchronous presentation teardown only: close/end and invalidate old UI
	# callbacks while its host, core and providers still exist. No await/rebind
	# here; all transaction rejection/rollback paths have already returned.
	bindings_retiring.emit(old_host)
	_core = stage.core
	_host = stage.host
	old_host.dispose()
	_world.call("sync_inventory", inventory)
	return {"ok": true}


func _replace_file(bytes: PackedByteArray) -> Dictionary:
	var destination := ProjectSettings.globalize_path(_path)
	_serial += 1
	var suffix := ".owner-%d-%d" % [OS.get_process_id(), _serial]
	var temporary := destination + suffix + ".tmp"
	var backup := destination + suffix + ".bak"
	if FileAccess.file_exists(temporary) or FileAccess.file_exists(backup):
		return _result(false, "save_sidecar_collision")
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _result(false, "save_temp_open_failed")
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_bytes(temporary) != bytes:
		DirAccess.remove_absolute(temporary)
		return _result(false, "save_temp_verify_failed")
	var existed := FileAccess.file_exists(destination)
	if existed and DirAccess.rename_absolute(destination, backup) != OK:
		DirAccess.remove_absolute(temporary)
		return _result(false, "save_backup_failed")
	if DirAccess.rename_absolute(temporary, destination) != OK:
		var rolled_back := not existed or DirAccess.rename_absolute(backup, destination) == OK
		DirAccess.remove_absolute(temporary)
		if not rolled_back:
			_blocked = true
		return _result(false, "save_replace_failed", {"preserved": rolled_back, "backup": backup if not rolled_back else ""})
	if existed:
		DirAccess.remove_absolute(backup)
	return _result(true, "saved", {"bytes": bytes.size(), "path": _path})


func dispose() -> void:
	# Parent owns live host/UI disposal. This only releases storage-owner bindings.
	_configured = false
	_core = null
	_host = null
	_world = null
	_host_options.clear()
