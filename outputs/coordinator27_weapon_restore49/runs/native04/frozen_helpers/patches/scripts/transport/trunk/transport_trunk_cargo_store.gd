extends RefCounted

const Admission = preload("res://scripts/transport/transport_cargo_admission.gd")
const FireProfiles = preload("res://scripts/weapons/weapon_fire_profiles.gd")
const CAPACITY := 100
const GAP_M := .005
const FRONTIER_PAD_M := .00001
const MAX_ITEMS := 100
const SOURCE_TRUNK_SHA256 := "91d8575b2f52ca10b43bfe73d4a004ec4ebfef7b066835c8d1ed1a46239f5fb0"
const SOURCE_WEAPON_INVENTORY_SHA256 := "1c675610bcde2c40a0ef8deb74118ea085968b4bec7538ce8784f5d9ddb405de"
const CARGO_ADMISSION_SHA256 := "ddc78bc1c7f0dc34e393c90a344dd4b27d004bf41cd85f452122483e863d48bc"
const CARGO_EVIDENCE_SHA256 := "a6e235b1b56c332f6a5a5b2283e3ad6d045876c46dc28b32fffed207db875a2e"
const COMPARTMENTS_SHA256 := "99ee5fcd0b07cb9b918f90280d30ee3f462ab54537c0073f2b079e25d14ca9df"

class CargoToken extends RefCounted:
	var serial := 0

var _root_ref: WeakRef
var _vehicle_id := ""
var _generation := 0
var _revision := 0
var _serial := 0
var _items: Array[Dictionary] = []
var _pending: Dictionary = {}
var _destroyed := false
var _destroy_event_uid := ""
var _destroy_receipt: Dictionary = {}
var _evidence_provider: RefCounted
var _compartments: RefCounted

func configure(vehicle_root: Node, vehicle_id: String, life_generation: int, evidence_provider: RefCounted, compartments: RefCounted) -> Dictionary:
	if _root_ref != null: return _error("ALREADY_CONFIGURED")
	if vehicle_root == null or not is_instance_valid(vehicle_root) or not vehicle_root.is_inside_tree() or vehicle_id.is_empty() or life_generation < 1 or evidence_provider == null or compartments == null: return _error("CONFIGURATION")
	if String(vehicle_root.get_meta("vehicle_id", "")) != vehicle_id or int(vehicle_root.get_meta("life_generation", 0)) != life_generation: return _error("IDENTITY")
	if evidence_provider.get_script() == null or String(evidence_provider.get_script().resource_path) != "res://scripts/transport/transport_cargo_evidence.gd" or compartments.get_script() == null or String(compartments.get_script().resource_path) != "res://scripts/vehicle_visual/vehicle_compartments.gd" or evidence_provider.get("_compartments") != compartments: return _error("EVIDENCE_BINDING")
	var visual: Variant = evidence_provider.get("_visual")
	if visual == null or visual.get("root") == null or not is_instance_valid(visual.root) or not (visual.root == vehicle_root or vehicle_root.is_ancestor_of(visual.root)) or compartments.get("_visual") != visual: return _error("VEHICLE_VISUAL_BINDING")
	_root_ref = weakref(vehicle_root); _vehicle_id = vehicle_id; _generation = life_generation; _revision = 1; _evidence_provider = evidence_provider; _compartments = compartments
	return {"ok": true, "revision": _revision, "capacity_units": CAPACITY}

func prepare_store(item: Dictionary, capacity_units: int, model_aabb: AABB, evidence_revision: int, expected_generation: int, expected_revision: int) -> Dictionary:
	var gate := _gate(expected_generation, expected_revision)
	if not bool(gate.ok): return gate
	if not _pending.is_empty(): return _error("PENDING")
	var normalized := _normalize_item(item, capacity_units)
	if not bool(normalized.ok): return normalized
	var cargo: Dictionary = normalized.item
	if _find_uid(String(cargo.uid)) >= 0: return _error("DUPLICATE_UID")
	if _items.size() >= MAX_ITEMS or _used_units() + capacity_units > CAPACITY: return _error("CAPACITY")
	if cargo.kind == "corpse" and not _items.is_empty(): return _error("CORPSE_EXCLUSIVE")
	if cargo.kind != "corpse" and _has_corpse(): return _error("CORPSE_EXCLUSIVE")
	if not _valid_model_aabb(model_aabb): return _error("MODEL_AABB")
	var evidence := _current_evidence(evidence_revision)
	if evidence.is_empty(): return _error("EVIDENCE")
	if not _existing_slots_fit(evidence.bounds): return _error("BOUNDS_CHANGED")
	var slot := _find_slot(model_aabb, evidence)
	if slot.is_empty(): return _error("NO_PHYSICAL_SLOT")
	var entry := {"item": cargo, "capacity_units": capacity_units, "model_aabb": model_aabb, "item_bounds_local_m": slot.item_bounds_local_m, "model_origin_local_m": slot.model_origin_local_m}
	var token := _new_token()
	_pending = {"kind": "store", "token": token, "base_revision": _revision, "evidence_revision": evidence_revision, "evidence_fingerprint": _evidence_fingerprint(evidence), "entry": entry}
	return {"ok": true, "token": token, "base_revision": _revision, "evidence_revision": evidence_revision, "entry": _copy_entry(entry)}

func commit_store(token: RefCounted, validation: RefCounted, expected_generation: int, expected_revision: int, evidence_revision: int) -> Dictionary:
	var gate := _sealed_gate("store", token, validation, expected_generation, expected_revision, evidence_revision)
	if not bool(gate.ok): return gate
	var entry: Dictionary = _pending.entry
	_items.append(_copy_entry(entry)); _pending.clear(); _revision += 1
	return {"ok": true, "revision": _revision, "entry": _copy_entry(entry), "used_units": _used_units()}

func prepare_take(uid: String, evidence_revision: int, expected_generation: int, expected_revision: int) -> Dictionary:
	var gate := _gate(expected_generation, expected_revision)
	if not bool(gate.ok): return gate
	if not _pending.is_empty(): return _error("PENDING")
	var evidence := _current_evidence(evidence_revision)
	if evidence.is_empty(): return _error("EVIDENCE")
	var index := _find_uid(uid)
	if index < 0: return _error("MISSING_UID")
	var token := _new_token(); var entry := _copy_entry(_items[index])
	_pending = {"kind": "take", "token": token, "base_revision": _revision, "evidence_revision": evidence_revision, "evidence_fingerprint": _evidence_fingerprint(evidence), "index": index, "uid": uid, "entry": entry}
	return {"ok": true, "token": token, "base_revision": _revision, "evidence_revision": evidence_revision, "entry": _copy_entry(entry)}

func commit_take(token: RefCounted, validation: RefCounted, expected_generation: int, expected_revision: int, evidence_revision: int) -> Dictionary:
	var gate := _sealed_gate("take", token, validation, expected_generation, expected_revision, evidence_revision)
	if not bool(gate.ok): return gate
	var index := int(_pending.index); var uid := String(_pending.uid)
	if index < 0 or index >= _items.size() or String(_items[index].item.uid) != uid: return _error("PENDING_STALE")
	var entry := _copy_entry(_items[index]); _items.remove_at(index); _pending.clear(); _revision += 1
	return {"ok": true, "revision": _revision, "entry": entry, "used_units": _used_units()}

func prepare_destroy(event_uid: String, expected_generation: int, expected_revision: int) -> Dictionary:
	if not _root_identity_boundary(expected_generation): return _error("LIFETIME")
	if expected_revision != _revision: return _error("REVISION")
	if _destroyed:
		if event_uid == _destroy_event_uid: return {"ok": true, "duplicate": true, "committed": true, "receipt": _destroy_receipt.duplicate(true)}
		return _error("ALREADY_DESTROYED")
	if not _identity_boundary(expected_generation): return _error("VISUAL_LIFETIME")
	if event_uid.is_empty(): return _error("EVENT_UID")
	if not _pending.is_empty():
		if _pending.kind == "destroy" and _pending.event_uid == event_uid:
			_pending.erase("validation_seal")
			return {"ok": true, "duplicate": true, "token": _pending.token, "base_revision": _revision, "items": _copy_entries(_pending.items)}
		return _error("PENDING")
	var token := _new_token(); var staged := _copy_entries(_items)
	_pending = {"kind": "destroy", "token": token, "base_revision": _revision, "event_uid": event_uid, "items": staged}
	return {"ok": true, "duplicate": false, "token": token, "base_revision": _revision, "items": _copy_entries(staged)}

func commit_destroy(token: RefCounted, validation: RefCounted, expected_generation: int, expected_revision: int) -> Dictionary:
	var gate := _sealed_gate("destroy", token, validation, expected_generation, expected_revision, -1)
	if not bool(gate.ok): return gate
	var event_uid := String(_pending.event_uid); var drops := _copy_entries(_pending.items)
	_items.clear(); _pending.clear(); _destroyed = true; _destroy_event_uid = event_uid; _revision += 1
	_destroy_receipt = {"event_uid": event_uid, "vehicle_id": _vehicle_id, "life_generation": _generation, "revision": _revision, "items": drops}
	return {"ok": true, "duplicate": false, "receipt": _destroy_receipt.duplicate(true)}

func destroy_once(event_uid: String, expected_generation: int) -> Dictionary:
	if not _root_identity_boundary(expected_generation): return _error("LIFETIME")
	if _destroyed and event_uid == _destroy_event_uid: return {"ok": true, "duplicate": true, "receipt": _destroy_receipt.duplicate(true)}
	return _error("PREPARE_REQUIRED")

func cancel(token: RefCounted) -> Dictionary:
	if _pending.is_empty() or token == null or token != _pending.token: return _error("TOKEN")
	_pending.clear()
	return {"ok": true, "revision": _revision}

func validate_pending(token: RefCounted, kind: String, expected_generation: int, expected_revision: int, evidence_revision: int) -> Dictionary:
	# Every validation attempt revokes the prior seal before touching any
	# external boundary.  A failed revalidation must never leave an older
	# same-frame commit capability alive.
	if not _pending.is_empty(): _pending.erase("validation_seal")
	var gate := _commit_gate(kind, token, expected_generation, expected_revision, evidence_revision)
	if not bool(gate.ok): return gate
	if kind in ["store", "take"]:
		var current := _current_evidence(evidence_revision)
		if current.is_empty() or _evidence_fingerprint(current) != _pending.evidence_fingerprint: return _error("EVIDENCE_CHANGED")
	if kind == "take":
		var index := int(_pending.index); var uid := String(_pending.uid)
		if index < 0 or index >= _items.size() or String(_items[index].item.uid) != uid: return _error("PENDING_STALE")
	var seal := _new_token(); _pending["validation_seal"] = seal
	return {"ok": true, "revision": _revision, "kind": kind, "validation": seal}

func snapshot(expected_generation: int) -> Dictionary:
	if not (_root_identity_boundary(expected_generation) if _destroyed else _identity_boundary(expected_generation)): return _error("LIFETIME")
	return {"ok": true, "vehicle_id": _vehicle_id, "life_generation": _generation, "revision": _revision, "capacity_units": CAPACITY, "used_units": _used_units(), "destroyed": _destroyed, "pending": not _pending.is_empty(), "items": _copy_entries(_items)}

func summary(expected_generation: int) -> Dictionary:
	# HUD-safe scalar view.  snapshot() is reserved for event/debug boundaries
	# because it defensively copies every item and its fireState.
	if not (_root_identity_boundary(expected_generation) if _destroyed else _identity_boundary(expected_generation)): return _error("LIFETIME")
	return {"ok": true, "revision": _revision, "capacity_units": CAPACITY, "used_units": _used_units(), "count": _items.size(), "pending": not _pending.is_empty(), "destroyed": _destroyed}

func dispose() -> void:
	_root_ref = null; _vehicle_id = ""; _generation = 0; _revision = 0; _items.clear(); _pending.clear(); _destroyed = false; _destroy_event_uid = ""; _destroy_receipt.clear(); _evidence_provider = null; _compartments = null

func _gate(expected_generation: int, expected_revision: int) -> Dictionary:
	if not _boundary(expected_generation): return _error("LIFETIME")
	if _destroyed: return _error("DESTROYED")
	if expected_revision != _revision: return _error("REVISION")
	return {"ok": true}

func _commit_gate(kind: String, token: RefCounted, expected_generation: int, expected_revision: int, evidence_revision: int) -> Dictionary:
	if kind == "destroy":
		if not _identity_boundary(expected_generation): return _error("LIFETIME")
		if expected_revision != _revision or _destroyed: return _error("REVISION")
	else:
		var gate := _gate(expected_generation, expected_revision)
		if not bool(gate.ok): return gate
	if _pending.is_empty() or _pending.kind != kind or token == null or token != _pending.token or int(_pending.base_revision) != _revision: return _error("TOKEN")
	if evidence_revision >= 0 and int(_pending.evidence_revision) != evidence_revision: return _error("EVIDENCE_REVISION")
	return {"ok": true}

func _sealed_gate(kind: String, token: RefCounted, validation: RefCounted, expected_generation: int, expected_revision: int, evidence_revision: int) -> Dictionary:
	# Local-only paired-commit gate: validate_pending already sampled every
	# mutable external boundary. Root performs no callback between validation
	# and the inventory/trunk commits.
	if _destroyed or expected_generation != _generation or expected_revision != _revision: return _error("REVISION_OR_LIFETIME")
	if _pending.is_empty() or _pending.kind != kind or token == null or token != _pending.token or validation == null or validation != _pending.get("validation_seal") or int(_pending.base_revision) != _revision: return _error("VALIDATION")
	if evidence_revision >= 0 and int(_pending.evidence_revision) != evidence_revision: return _error("EVIDENCE_REVISION")
	if kind == "take":
		var index := int(_pending.index)
		if index < 0 or index >= _items.size() or String(_items[index].item.uid) != String(_pending.uid): return _error("PENDING_STALE")
	return {"ok": true}

func _boundary(expected_generation: int) -> bool:
	if not _identity_boundary(expected_generation): return false
	var root := _root_ref.get_ref() as Node
	return not bool(root.get_meta("transport_destroying", false)) and not bool(root.get_meta("transport_wrecked", false))

func _identity_boundary(expected_generation: int) -> bool:
	if not _root_identity_boundary(expected_generation): return false
	var root := _root_ref.get_ref() as Node
	if _evidence_provider == null or _compartments == null or _evidence_provider.get("_compartments") != _compartments: return false
	var visual: Variant = _evidence_provider.get("_visual")
	return visual != null and visual.get("root") != null and is_instance_valid(visual.root) and (visual.root == root or root.is_ancestor_of(visual.root)) and _compartments.get("_visual") == visual

func _root_identity_boundary(expected_generation: int) -> bool:
	if _root_ref == null or expected_generation != _generation: return false
	var root := _root_ref.get_ref() as Node
	return root != null and is_instance_valid(root) and root.is_inside_tree() and String(root.get_meta("vehicle_id", "")) == _vehicle_id and int(root.get_meta("life_generation", 0)) == _generation

func _normalize_item(value: Dictionary, units: int) -> Dictionary:
	var uid_value: Variant = value.get("uid", value.get("itemUID"))
	if typeof(uid_value) != TYPE_STRING or String(uid_value).is_empty() or String(uid_value).length() > 128: return _error("UID")
	if value.has("uid") and value.has("itemUID") and String(value.uid) != String(value.itemUID): return _error("UID_ALIAS")
	var kind := String(value.get("kind", "weapon"))
	if kind not in ["weapon", "corpse"]: return _error("KIND")
	if kind == "corpse":
		if units != CAPACITY: return _error("CORPSE_UNITS")
		return {"ok": true, "item": {"uid": String(uid_value), "itemUID": String(uid_value), "kind": kind}}
	if units < 1 or units > CAPACITY: return _error("CAPACITY_UNITS")
	var weapon_id_value: Variant = value.get("weaponId")
	if typeof(weapon_id_value) != TYPE_STRING or String(weapon_id_value).is_empty(): return _error("WEAPON_ID")
	var fire_value: Variant = value.get("fireState")
	if not fire_value is Dictionary or not _valid_fire_state(fire_value, String(weapon_id_value)): return _error("FIRE_STATE")
	var plain := _plain_copy(fire_value, [], 0, [0])
	if not bool(plain.ok): return _error("FIRE_STATE_PLAIN_DATA")
	if var_to_bytes(plain.value).size() > 65536: return _error("FIRE_STATE_SIZE")
	return {"ok": true, "item": {"uid": String(uid_value), "itemUID": String(uid_value), "kind": kind, "weaponId": String(weapon_id_value), "fireState": plain.value}}

func _valid_fire_state(state: Dictionary, weapon_id: String) -> bool:
	if String(state.get("weaponId", "")) != weapon_id: return false
	var profile: Dictionary = FireProfiles.PROFILES.get(weapon_id, {})
	if profile.is_empty(): return false
	if not _safe_nonnegative_integer(state.get("magazine"), int(profile.magazineSize)): return false
	if not _safe_nonnegative_integer(state.get("reserveAmmo"), 9999): return false
	if not _safe_nonnegative_integer(state.get("sequence"), 9007199254740991): return false
	for key in ["cooldown", "reloadRemaining", "recoil"]:
		var value: Variant = state.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) < 0.0: return false
	return typeof(state.get("triggerHeld")) == TYPE_BOOL

func _safe_nonnegative_integer(value: Variant, maximum: int) -> bool:
	if typeof(value) == TYPE_INT: return int(value) >= 0 and int(value) <= maximum
	if typeof(value) != TYPE_FLOAT: return false
	var number := float(value)
	return is_finite(number) and number >= 0.0 and number <= float(maximum) and number == floor(number)

func _plain_copy(value: Variant, ancestors: Array, depth: int, budget: Array) -> Dictionary:
	budget[0] = int(budget[0]) + 1
	if depth > 16 or int(budget[0]) > 512: return {"ok": false}
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return {"ok": true, "value": value}
		TYPE_FLOAT:
			return {"ok": is_finite(float(value)), "value": value}
		TYPE_ARRAY:
			for ancestor in ancestors:
				if is_same(ancestor, value): return {"ok": false}
			var next_ancestors := ancestors.duplicate(); next_ancestors.append(value)
			var output: Array = []
			for child in value:
				var copied := _plain_copy(child, next_ancestors, depth + 1, budget)
				if not bool(copied.ok): return {"ok": false}
				output.append(copied.value)
			return {"ok": true, "value": output}
		TYPE_DICTIONARY:
			for ancestor in ancestors:
				if is_same(ancestor, value): return {"ok": false}
			var next_ancestors := ancestors.duplicate(); next_ancestors.append(value)
			var output: Dictionary = {}
			for key in value:
				if typeof(key) != TYPE_STRING: return {"ok": false}
				var copied := _plain_copy(value[key], next_ancestors, depth + 1, budget)
				if not bool(copied.ok): return {"ok": false}
				output[key] = copied.value
			return {"ok": true, "value": output}
	return {"ok": false}

func _valid_model_aabb(value: AABB) -> bool:
	return value.position.is_finite() and value.size.is_finite() and value.size.x > 0.0 and value.size.y > 0.0 and value.size.z > 0.0

func _valid_evidence(value: Dictionary, revision: int) -> bool:
	if revision < 1 or value.get("available", false) != true or value.get("has_floor", false) != true: return false
	if typeof(value.get("amount")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.amount)): return false
	if value.get("target_open_authenticated", false) != true or value.get("lid_visible", false) != true or float(value.amount) < .85: return false
	return value.get("bounds") is AABB and _valid_model_aabb(value.bounds) and value.get("lid_bounds") is AABB and value.get("mode", "") in ["trunk", "hatch", "tailgate"] and typeof(value.get("lid_visible")) == TYPE_BOOL

func _current_evidence(revision: int) -> Dictionary:
	if revision < 1 or _evidence_provider == null or _compartments == null or _evidence_provider.get("_compartments") != _compartments: return {}
	if not bool(_compartments.call("is_open", "trunk")): return {}
	var sampled: Variant = _evidence_provider.call("sample")
	if not sampled is Dictionary: return {}
	var value: Dictionary = sampled.duplicate(true); value["target_open_authenticated"] = true; value["detached"] = false
	return value if _valid_evidence(value, revision) else {}

func _evidence_fingerprint(value: Dictionary) -> Array:
	if value.is_empty(): return []
	return [value.get("bounds"), value.get("lid_bounds"), value.get("amount"), value.get("mode"), value.get("lid_visible"), value.get("has_floor"), value.get("available"), value.get("visual_sha256"), value.get("target_open_authenticated")]

func _find_slot(model_aabb: AABB, evidence: Dictionary) -> Dictionary:
	var bounds: AABB = evidence.bounds; var points: Array[Vector3] = [bounds.position]
	for existing in _items:
		var box: AABB = existing.item_bounds_local_m
		# Vector3 is float32 in this build.  The outward pad prevents `end + .005`
		# rounding a few ULPs below the required 5 mm separation.  Collision tests
		# keep the exact GAP_M threshold, so this only makes placement conservative.
		points.append(Vector3(box.end.x + GAP_M + FRONTIER_PAD_M, box.position.y, box.position.z))
		points.append(Vector3(box.position.x, box.end.y + GAP_M + FRONTIER_PAD_M, box.position.z))
		points.append(Vector3(box.position.x, box.position.y, box.end.z + GAP_M + FRONTIER_PAD_M))
	points.sort_custom(func(a: Vector3, b: Vector3): return a.y < b.y or (is_equal_approx(a.y,b.y) and (a.z < b.z or (is_equal_approx(a.z,b.z) and a.x < b.x))))
	for point in points:
		var candidate := AABB(point, model_aabb.size)
		if not _contains(bounds, candidate) or _overlaps_existing(candidate): continue
		var center := candidate.get_center(); var half := candidate.size * .5
		if not Admission.accepts(bounds, center, half, float(evidence.amount), false, bool(evidence.has_floor), String(evidence.mode), bool(evidence.lid_visible), evidence.lid_bounds, bool(evidence.available)): continue
		return {"item_bounds_local_m": candidate, "model_origin_local_m": point - model_aabb.position}
	return {}

func _contains(outer: AABB, inner: AABB) -> bool:
	return inner.position.x >= outer.position.x - .0000001 and inner.position.y >= outer.position.y - .0000001 and inner.position.z >= outer.position.z - .0000001 and inner.end.x <= outer.end.x + .0000001 and inner.end.y <= outer.end.y + .0000001 and inner.end.z <= outer.end.z + .0000001

func _overlaps_existing(candidate: AABB) -> bool:
	for entry in _items:
		var box: AABB = entry.item_bounds_local_m
		if candidate.position.x < box.end.x + GAP_M and candidate.end.x + GAP_M > box.position.x and candidate.position.y < box.end.y + GAP_M and candidate.end.y + GAP_M > box.position.y and candidate.position.z < box.end.z + GAP_M and candidate.end.z + GAP_M > box.position.z: return true
	return false

func _existing_slots_fit(bounds: AABB) -> bool:
	for entry in _items:
		if not _contains(bounds, entry.item_bounds_local_m): return false
	return true

func _used_units() -> int:
	var total := 0
	for entry in _items: total += int(entry.capacity_units)
	return total

func _has_corpse() -> bool:
	for entry in _items:
		if entry.item.kind == "corpse": return true
	return false

func _find_uid(uid: String) -> int:
	for index in _items.size():
		if String(_items[index].item.uid) == uid: return index
	return -1

func _new_token() -> CargoToken:
	_serial += 1; var token := CargoToken.new(); token.serial = _serial; return token

func _copy_entry(value: Dictionary) -> Dictionary:
	return value.duplicate(true)

func _copy_entries(values: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for value in values: out.append(_copy_entry(value))
	return out

func _error(code: String) -> Dictionary:
	return {"ok": false, "error": code, "revision": _revision}


## PRIVATE restore49: validate against fresh native identity and actual geometry.
func prepare_local_restore(service:RefCounted,cap:RefCounted,value:Dictionary,serial:int)->Dictionary:
	if not service.allows(cap,self,"cargo") or not _items.is_empty() or not _pending.is_empty() or _revision!=1 or _destroyed:return _error("RESTORE_BOUNDARY")
	if value.vehicle_id!=_vehicle_id or value.life_generation!=_generation or not _identity_boundary(_generation):return _error("RESTORE_IDENTITY")
	var raw:Dictionary=_compartments.cargo_bounds()
	if raw.is_empty():return _error("RESTORE_BOUNDS")
	var bounds:=AABB(raw.min,raw.max-raw.min)
	var rows:Array[Dictionary]=[]
	for old:Dictionary in value.items:
		var entry:Dictionary=old.duplicate(true)
		var model:Dictionary=entry.model_aabb
		var box:Dictionary=entry.item_bounds_local_m
		entry.model_aabb=AABB(Vector3(model.position.x,model.position.y,model.position.z),Vector3(model.size.x,model.size.y,model.size.z))
		entry.item_bounds_local_m=AABB(Vector3(box.position.x,box.position.y,box.position.z),Vector3(box.size.x,box.size.y,box.size.z))
		var pos:Dictionary=entry.model_origin_local_m
		entry.model_origin_local_m=Vector3(pos.x,pos.y,pos.z)
		if not _normalize_item(entry.item,int(entry.capacity_units)).ok or not _contains(bounds,entry.item_bounds_local_m):return _error("RESTORE_ENTRY")
		if entry.model_aabb.size!=entry.item_bounds_local_m.size or entry.model_origin_local_m+entry.model_aabb.position!=entry.item_bounds_local_m.position:return _error("RESTORE_MODEL_TRANSFORM")
		for other:Dictionary in rows:
			if entry.item_bounds_local_m.grow(GAP_M*.5).intersects(other.item_bounds_local_m.grow(GAP_M*.5)):return _error("RESTORE_OVERLAP")
		rows.append(entry)
	return {"ok":true,"owner":self,"cap":cap,"items":rows,"revision":int(value.revision),"serial":serial}

func commit_local_restore(service:RefCounted,cap:RefCounted,prepared:Dictionary)->void:
	assert(service.allows(cap,self,"cargo") and prepared.owner==self and prepared.cap==cap)
	_items=prepared.items;_revision=prepared.revision;_serial=prepared.serial
