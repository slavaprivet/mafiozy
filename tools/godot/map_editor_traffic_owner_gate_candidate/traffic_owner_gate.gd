extends RefCounted
## Read-only receipt from the actual preview transport/traffic owner. No edit token.

var _main: Node3D
var _transport: Node3D
var _runtime: Node3D
var _body: RigidBody3D
var _player: CharacterBody3D
var _receipt: Dictionary = {}
var _snapshot: Array = []
var _serial := 0

func inspect(main: Node3D, source_id: String) -> Dictionary:
	_receipt.clear()
	_snapshot.clear()
	if not is_instance_valid(main) or not main.is_inside_tree() or main.is_queued_for_deletion(): return _refuse("main_not_live")
	if main.get_script() == null or main.get_script().resource_path != "res://scripts/main.gd": return _refuse("not_actual_preview_main")
	var block: Variant = main.get("_block")
	if not block is Dictionary: return _refuse("missing_source_block")
	var found := false
	for row: Dictionary in block.get("buildings", []):
		if str(row.get("id", "")) == source_id: found = true
	if not found: return _refuse("source_building_not_in_live_crop")
	_transport = main.get("preview_transport") as Node3D
	if not is_instance_valid(_transport) or _transport.is_queued_for_deletion() or _transport.get_parent() != main: return _refuse("preview_transport_owner_missing")
	_runtime = _transport.get("runtime") as Node3D
	_body = _transport.get("body") as RigidBody3D
	_player = _transport.get("player") as CharacterBody3D
	if not is_instance_valid(_runtime) or not is_instance_valid(_body) or not is_instance_valid(_player) or _runtime.is_queued_for_deletion() or _body.is_queued_for_deletion() or _player.is_queued_for_deletion(): return _refuse("transport_participant_missing")
	if _runtime.get_parent() != _transport or _body.get_parent() != _transport: return _refuse("transport_parent_drift")
	if not bool(_transport.get("ready_for_play")) or str(_transport.get("phase")) != "ON_FOOT": return _refuse("transport_not_quiescent")
	var catalog: RefCounted = _runtime.get("catalog") as RefCounted
	if not is_instance_valid(catalog) or not catalog.has_method("parking_bay"): return _refuse("parking_catalog_missing")
	var parking_id: String = str(_transport.get_script().get_script_constant_map().get("PARKING_ID", ""))
	if parking_id.is_empty(): return _refuse("parking_id_missing")
	var bay: Variant = catalog.parking_bay(parking_id)
	if not bay is Dictionary or bay.is_empty(): return _refuse("parking_bay_missing")
	if not _body.has_meta("vehicle_id") or int(_body.get_meta("life_generation", 0)) <= 0: return _refuse("vehicle_identity_missing")
	_main = main
	_snapshot = _capture(bay)
	_serial += 1
	_receipt = {"owner_instance_id": main.get_instance_id(), "transport_instance_id": _transport.get_instance_id(),
		"runtime_instance_id": _runtime.get_instance_id(), "body_instance_id": _body.get_instance_id(),
		"source_id": source_id, "parking_id": parking_id, "vehicle_id": str(_body.get_meta("vehicle_id")),
		"life_generation": int(_body.get_meta("life_generation")), "serial": _serial,
		"read_only": true, "geometry_transaction": false}
	return {"ok": true, "receipt": _receipt.duplicate(true), "editable": false}

func verify(receipt: Dictionary) -> bool:
	if _receipt.is_empty() or receipt != _receipt: return false
	if not is_instance_valid(_main) or not is_instance_valid(_transport) or not is_instance_valid(_runtime) or not is_instance_valid(_body) or not is_instance_valid(_player): return false
	if _main.is_queued_for_deletion() or _transport.is_queued_for_deletion() or _runtime.is_queued_for_deletion() or _body.is_queued_for_deletion() or _player.is_queued_for_deletion(): return false
	if _transport.get_parent() != _main or _runtime.get_parent() != _transport or _body.get_parent() != _transport: return false
	var catalog: RefCounted = _runtime.get("catalog") as RefCounted
	if not is_instance_valid(catalog): return false
	var bay: Variant = catalog.parking_bay(str(_receipt.parking_id))
	return bay is Dictionary and _capture(bay) == _snapshot

func prepare_geometry_edit(receipt: Dictionary, request: Dictionary) -> Dictionary:
	if not verify(receipt): return _refuse("traffic_owner_receipt_drift")
	if str(request.get("source_id", "")) != str(_receipt.source_id) or str(request.get("action", "")) not in ["move", "rotate", "delete", "undo", "redo"]: return _refuse("traffic_request_mismatch")
	# The real runtime has parking/seat/access APIs, but no reversible geometry
	# prepare/commit/rollback or road/support publication. Never mint a token.
	return _refuse("traffic_geometry_transaction_owner_missing")

func _capture(bay: Dictionary) -> Array:
	var shapes: Array = []
	for child: Node in _body.get_children():
		if child is CollisionShape3D: shapes.append([child.get_instance_id(), child.shape.get_instance_id() if is_instance_valid(child.shape) else 0, child.disabled])
	return [_main.get_instance_id(), _transport.get_instance_id(), _runtime.get_instance_id(), _body.get_instance_id(),
		var_to_bytes(_main.get("_block")), var_to_bytes(_transport.get("_session")), _transport.get("_clock"), _transport.get("_sequence"),
		_transport.get("phase"), _transport.get("_parked_brake"), _transport.get("_pending_exit"),
		var_to_bytes(_runtime.get("_runtime_leases")), var_to_bytes(_runtime.get("_native_vehicle_bodies")), var_to_bytes(bay),
		_body.get_meta("vehicle_id"), _body.get_meta("life_generation"), _body.global_transform,
		_body.linear_velocity, _body.angular_velocity, _body.collision_layer, _body.collision_mask,
		_body.freeze, _body.get_rid(), shapes, _player.get_instance_id(), _player.collision_layer,
		_player.collision_mask, _transport.get("_seat_collision_owned")]

func _refuse(reason: String) -> Dictionary:
	return {"ok": false, "error": reason, "owner": "actual_preview_transport", "token": null}
