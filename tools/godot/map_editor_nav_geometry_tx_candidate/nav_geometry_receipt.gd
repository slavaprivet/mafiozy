extends RefCounted
## Read-only, actual-collider geometry receipt for one ordinary building.
## This is deliberately not an owner lease: publication and resume remain HOLD.

const Tx = preload("res://scripts/map_editor/ordinary_building_tx.gd")
const EXPECTED_RESIDENTS := ["resident_72", "resident_169", "resident_252"]

func inspect(main: Node3D, source_id: String, action: String, value: Variant) -> Dictionary:
	if not Thread.is_main_thread() or not is_instance_valid(main) or not main.is_inside_tree() or main.is_queued_for_deletion(): return _no("STALE_MAIN_OWNER")
	if action not in ["move", "rotate", "delete", "undo", "redo", "restore"]: return _no("UNSUPPORTED_BUILDING_ACTION")
	var tx := Tx.new()
	var selected: Dictionary = tx.select(main,source_id)
	if not selected.get("ok",false): return _no("ORDINARY_BUILDING_NOT_ADMITTED:" + str(selected.get("error","unknown")))
	if action == "move" and (not value is Vector3 or not value.is_finite() or value.length_squared() < 0.00000001): return _no("INVALID_MOVE")
	if action == "rotate" and (not value is float and not value is int or not is_finite(float(value)) or absf(float(value)) < 0.000001): return _no("INVALID_ROTATION")
	if action in ["move", "rotate", "delete"] and not tx._row.visual.visible: return _no("DELETED_BUILDING_REQUIRES_RESTORE")
	var targets: Dictionary = {}
	if action in ["undo", "redo", "restore"]:
		var prepared: Dictionary = _restore_targets(main, tx._row, value)
		if not prepared.get("ok",false): return prepared
		targets = prepared.targets
	var population: RefCounted = main.get("preview_population")
	if population == null or str(main.get("population_status")) != "ready": return _no("ACTUAL_THREE_RESIDENTS_NOT_READY")
	var residents: Array = population.occupants()
	var ids: Array[String] = []
	for resident: Dictionary in residents: ids.append(str(resident.get("source_id", "")))
	ids.sort()
	var expected: Array[String] = []
	for id: String in EXPECTED_RESIDENTS: expected.append(id)
	expected.sort()
	if ids != expected: return _no("RESIDENT_ID_SET_DRIFT")
	var nav: RefCounted = population.navigation
	if nav == null or nav._disposed or not nav._geometry_valid or nav._backend == null or nav._root == null or nav._root.get_ref() != main: return _no("NAV_OWNER_NOT_ATTACHED_TO_ACTUAL_MAIN")
	var interior: Node3D = main.get("_printshop")
	if not is_instance_valid(interior) or interior.is_queued_for_deletion(): return _no("PRINTSHOP_OWNER_MISSING")
	var all: PackedVector3Array = PackedVector3Array()
	var next: PackedVector3Array = PackedVector3Array()
	var changed_before: PackedVector3Array = PackedVector3Array()
	var changed_after: PackedVector3Array = PackedVector3Array()
	var source_indices: Array[int] = []
	var siblings: Array[StaticBody3D] = []
	var delta := Transform3D.IDENTITY
	if action == "move": delta = Transform3D(Basis.IDENTITY,value)
	elif action == "rotate":
		var pivot: Vector3 = tx._row.visual.global_transform.origin
		var rotation := Basis(Vector3.UP,float(value))
		delta = Transform3D(rotation,pivot - rotation * pivot)
	for parent: Node3D in [main, interior]:
		for child: Node in parent.get_children():
			if not child is StaticBody3D: continue
			var body := child as StaticBody3D
			if body.is_queued_for_deletion() or body.get_child_count() != 1 or not body.get_child(0) is CollisionShape3D: return _no("COLLIDER_OWNER_DRIFT")
			var shape := body.get_child(0) as CollisionShape3D
			var is_selected: bool = parent == main and str(body.get_meta("source_id", "")) == source_id
			if shape.shape == null or not shape.transform.is_equal_approx(Transform3D.IDENTITY): return _no("COLLIDER_SHAPE_DRIFT")
			var local := _local_faces(nav, body, shape)
			if local.is_empty(): return _no("UNSUPPORTED_ACTUAL_COLLIDER")
			if shape.disabled:
				if not is_selected or body.collision_layer != 0 or body.collision_mask != 0: return _no("UNEXPECTED_DISABLED_COLLIDER")
			elif body.collision_layer != 1: return _no("COLLIDER_LAYER_DRIFT")
			var original := body.global_transform * local if not shape.disabled else PackedVector3Array()
			all.append_array(original)
			if is_selected:
				var index := int(body.get_meta("source_index", -1))
				if index < 0 or index in source_indices or not shape.shape is ConvexPolygonShape3D: return _no("BUILDING_SOURCE_COLLIDER_DRIFT")
				source_indices.append(index); siblings.append(body)
				changed_before.append_array(original)
				if action in ["move", "rotate"]:
					if shape.disabled: return _no("DELETED_BUILDING_REQUIRES_RESTORE")
					var proposed := (delta * body.global_transform) * local
					changed_after.append_array(proposed); next.append_array(proposed)
				elif action in ["undo", "redo", "restore"]:
					var target: Dictionary = targets.get(body.get_instance_id(),{})
					if target.is_empty(): return _no("RESTORE_MISSING_SOURCE_COLLIDER")
					if not target.disabled:
						var restored: PackedVector3Array = target.frame * local
						changed_after.append_array(restored); next.append_array(restored)
			else: next.append_array(original)
	if all != nav._static: return _no("NAV_CAPTURE_DIFFERS_FROM_CURRENT_COLLIDERS")
	source_indices.sort()
	if source_indices != tx._row.source_indices or siblings.size() != tx._row.native_sibling_bodies.size(): return _no("ORDINARY_BUILDING_SIBLING_SET_DRIFT")
	var sibling_ids: Array[int] = []
	for body: StaticBody3D in siblings: sibling_ids.append(body.get_instance_id())
	var active_records: int = nav._records.size()
	var active_jobs: int = nav._backend._jobs.size()
	return {"ok": true, "read_only": true, "owner_lease": false, "source_id": source_id,
		"action": action, "requested_value": value, "resident_ids": ids, "sibling_indices": source_indices,
		"root_instance_id": tx._row.visual.get_instance_id(), "sibling_instance_ids": sibling_ids,
		"old_faces": all.size() / 3, "new_faces": next.size() / 3,
		"building_faces_before": changed_before.size() / 3, "building_faces_after": changed_after.size() / 3,
		"old_geometry": all, "proposed_geometry": next, "active_records": active_records, "active_jobs": active_jobs,
		"blocker": "NO_ATOMIC_NAV_PUBLISH_AND_READY_RECEIPT_UNDER_EDITOR_PAUSE"}

func acquire_owner_lease(_proposal: Dictionary) -> Dictionary:
	# An editable transaction must receive a real RefCounted owner token. The
	# existing host cannot publish/rebake while paused or hold residents until
	# the new NavigationServer map is READY, so never mint a token here.
	return _no("NO_ATOMIC_NAV_PUBLISH_AND_READY_RECEIPT_UNDER_EDITOR_PAUSE")

## Reconstruct the current active static collider stream after a candidate
## scene mutation. This is a read, never a nav publication or lease.
func current_stream(main: Node3D, source_id: String) -> Dictionary:
	if not is_instance_valid(main) or not main.is_inside_tree(): return _no("STALE_MAIN_OWNER")
	var tx := Tx.new()
	var admission: Dictionary = tx.select(main,source_id)
	if not admission.get("ok",false): return _no("ORDINARY_BUILDING_NOT_ADMITTED:" + str(admission.get("error","unknown")))
	var population: RefCounted = main.get("preview_population")
	if population == null or population.navigation == null: return _no("NAV_OWNER_NOT_ATTACHED_TO_ACTUAL_MAIN")
	var nav: RefCounted = population.navigation
	var interior: Node3D = main.get("_printshop")
	if not is_instance_valid(interior): return _no("PRINTSHOP_OWNER_MISSING")
	var stream := PackedVector3Array()
	var source_indices: Array[int] = []
	for parent: Node3D in [main, interior]:
		for child: Node in parent.get_children():
			if not child is StaticBody3D: continue
			var body := child as StaticBody3D
			if body.is_queued_for_deletion() or body.get_child_count() != 1 or not body.get_child(0) is CollisionShape3D: return _no("COLLIDER_OWNER_DRIFT")
			var shape := body.get_child(0) as CollisionShape3D
			var selected: bool = parent == main and str(body.get_meta("source_id", "")) == source_id
			if selected:
				var index := int(body.get_meta("source_index", -1))
				if index < 0 or index in source_indices: return _no("BUILDING_SOURCE_COLLIDER_DRIFT")
				source_indices.append(index)
			if shape.disabled:
				if not selected or body.collision_layer != 0 or body.collision_mask != 0: return _no("UNEXPECTED_DISABLED_COLLIDER")
				continue
			if body.collision_layer != 1 or shape.shape == null or not shape.transform.is_equal_approx(Transform3D.IDENTITY): return _no("COLLIDER_SHAPE_DRIFT")
			var local := _local_faces(nav, body, shape)
			if local.is_empty(): return _no("UNSUPPORTED_ACTUAL_COLLIDER")
			stream.append_array(body.global_transform * local)
	source_indices.sort()
	if source_indices != tx._row.source_indices: return _no("ORDINARY_BUILDING_SIBLING_SET_DRIFT")
	return {"ok": true, "faces": stream, "source_indices": source_indices}

func _restore_targets(main: Node3D, row: Dictionary, state: Variant) -> Dictionary:
	if not state is Dictionary or state.get("root") != row.visual or state.get("parent") != main or not state.get("frame") is Transform3D or not state.get("visible") is bool or not state.get("bodies") is Array: return _no("INVALID_RESTORE_SNAPSHOT")
	if state.bodies.size() != row.native_sibling_bodies.size(): return _no("RESTORE_SIBLING_COUNT_DRIFT")
	var target_root: Transform3D = state.frame
	if not target_root.origin.is_finite() or not target_root.basis.is_finite(): return _no("INVALID_RESTORE_FRAME")
	var root_delta: Transform3D = target_root * row.visual.global_transform.affine_inverse()
	if not root_delta.basis.is_equal_approx(root_delta.basis.orthonormalized()) or not root_delta.basis.y.is_equal_approx(Vector3.UP) or absf(root_delta.basis.determinant() - 1.0) > 0.0001: return _no("RESTORE_NON_YAW_OR_SCALE_DELTA")
	var targets: Dictionary = {}
	for item: Dictionary in state.bodies:
		if not item.get("node") is StaticBody3D: return _no("RESTORE_SOURCE_IDENTITY_DRIFT")
		var body: StaticBody3D = item.get("node")
		if not is_instance_valid(body) or body not in row.native_sibling_bodies or targets.has(body.get_instance_id()) or item.get("parent") != main or not item.get("frame") is Transform3D or not item.get("shapes") is Array or item.shapes.size() != 1: return _no("RESTORE_SOURCE_IDENTITY_DRIFT")
		var frame: Transform3D = item.frame
		if not frame.origin.is_finite() or not frame.basis.is_finite(): return _no("INVALID_RESTORE_FRAME")
		if not frame.is_equal_approx(root_delta * body.global_transform): return _no("RESTORE_VISUAL_COLLIDER_AFFINE_DRIFT")
		if body.get_child_count() != 1 or not body.get_child(0) is CollisionShape3D: return _no("RESTORE_SHAPE_OWNER_DRIFT")
		var shape: CollisionShape3D = body.get_child(0)
		var saved: Dictionary = item.shapes[0]
		if saved.get("node") != shape or saved.get("shape") != shape.shape or not saved.get("disabled") is bool: return _no("RESTORE_SHAPE_RESOURCE_DRIFT")
		var disabled: bool = saved.disabled
		if disabled:
			if bool(state.visible) or int(item.get("layer",-1)) != 0 or int(item.get("mask",-1)) != 0: return _no("RESTORE_DELETE_STATE_INCOHERENT")
		elif not bool(state.visible) or int(item.get("layer",-1)) != 1 or int(item.get("mask",-1)) != 1: return _no("RESTORE_ACTIVE_STATE_INCOHERENT")
		targets[body.get_instance_id()] = {"frame": frame, "disabled": disabled}
	return {"ok": true, "targets": targets}

func _local_faces(nav: RefCounted, body: StaticBody3D, collision: CollisionShape3D) -> PackedVector3Array:
	if collision.shape is ConvexPolygonShape3D: return nav._extrusion(collision.shape.points)
	if collision.shape is ConcavePolygonShape3D: return collision.shape.get_faces()
	if collision.shape is BoxShape3D:
		var half: Vector3 = collision.shape.size * 0.5
		return nav._extrusion(PackedVector3Array([
			Vector3(-half.x,-half.y,-half.z),Vector3(-half.x,half.y,-half.z),
			Vector3(half.x,-half.y,-half.z),Vector3(half.x,half.y,-half.z),
			Vector3(half.x,-half.y,half.z),Vector3(half.x,half.y,half.z),
			Vector3(-half.x,-half.y,half.z),Vector3(-half.x,half.y,half.z)]))
	return PackedVector3Array()

func _no(reason: String) -> Dictionary:
	return {"ok": false, "read_only": true, "owner_lease": false, "error": reason}
