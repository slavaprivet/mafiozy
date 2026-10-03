extends "passage_floor_1m_r2.gd"
## Read-only terminal evidence, including early blast/support/deadline failure.
const STATIC_NODE_CAP := 16384
const STATIC_BODY_CAP := 512
const STATIC_SHAPE_CAP := 4096
const STATIC_POINT_CAP := 65536
const STATIC_USEC_CAP := 250000
const FIXED_SUPPORT_PATHS := ["OriginalFoundation", "OriginalPlaza", "StoneEntrance/OuterRamp", "StoneEntrance/Threshold", "StoneEntrance/InnerRamp"]
var static_baseline: Dictionary = {}

func static_budget_ok(report: Dictionary, begun: int) -> bool:
	if Time.get_ticks_usec() - begun > STATIC_USEC_CAP:
		report.complete = false
		report.reason = "snapshot_time_budget"
		return false
	return true

func bounded_static_snapshot(label: String) -> Dictionary:
	var begun: int = Time.get_ticks_usec()
	var report: Dictionary = {"label":label, "phase":phase, "physics_frame":Engine.get_physics_frames(), "complete":true, "reason":"", "nodes":0, "shape_count":0, "point_count":0, "bodies":[], "supports":{}, "required_supports":FIXED_SUPPORT_PATHS.duplicate(), "missing_supports":[]}
	if not is_instance_valid(site) or not site.is_inside_tree():
		report.complete = false; report.reason = "site_unavailable"
		return report
	report.site_id = site.get_instance_id()
	report.site_path = str(site.get_path())
	report.site_frame = Observe.frame(site.global_transform)
	var inverse: Transform3D = site.global_transform.affine_inverse()
	var pending: Array[Node] = [site]
	while not pending.is_empty() and report.complete:
		if not static_budget_ok(report, begun): break
		var node: Node = pending.pop_back()
		if not is_instance_valid(node):
			report.complete = false; report.reason = "node_lifetime_changed"; break
		report.nodes += 1
		var children: int = node.get_child_count()
		if int(report.nodes) + pending.size() + children > STATIC_NODE_CAP:
			report.complete = false; report.reason = "snapshot_node_budget"; break
		for index: int in children: pending.append(node.get_child(index))
		if not node is StaticBody3D: continue
		if report.bodies.size() >= STATIC_BODY_CAP:
			report.complete = false; report.reason = "snapshot_static_body_budget"; break
		var body: StaticBody3D = node as StaticBody3D
		var relative: String = str(site.get_path_to(body))
		var owners: PackedInt32Array = body.get_shape_owners()
		var row: Dictionary = {"relative_path":relative, "path":str(body.get_path()), "id":body.get_instance_id(), "class":body.get_class(), "layer":body.collision_layer, "mask":body.collision_mask, "body_frame":Observe.frame(body.global_transform), "site_local_frame":Observe.frame(inverse * body.global_transform), "shape_owner_count":owners.size(), "shape_count":0, "shapes":[]}
		report.bodies.append(row)
		if FIXED_SUPPORT_PATHS.has(relative) or relative.begins_with("StoneEntrance/"):
			report.supports[relative] = row
		if owners.size() > STATIC_SHAPE_CAP:
			report.complete = false; report.reason = "snapshot_owner_budget"; break
		for owner_id: int in owners:
			if not static_budget_ok(report, begun): break
			var owner: Object = body.shape_owner_get_owner(owner_id)
			var local: Transform3D = body.shape_owner_get_transform(owner_id)
			var count: int = body.shape_owner_get_shape_count(owner_id)
			if int(report.shape_count) + count > STATIC_SHAPE_CAP:
				report.complete = false; report.reason = "snapshot_shape_budget"; break
			for slot: int in count:
				if not static_budget_ok(report, begun): break
				var shape: Shape3D = body.shape_owner_get_shape(owner_id, slot)
				var data: Dictionary = {"valid":is_instance_valid(shape)}
				if not is_instance_valid(shape):
					report.complete = false; report.reason = "invalid_static_shape"; break
				data.resource_id = shape.get_instance_id()
				data.resource_path = shape.resource_path
				data.class_name = shape.get_class()
				if shape is BoxShape3D: data.size = Observe.vector(shape.size)
				elif shape is CapsuleShape3D: data.height = shape.height; data.radius = shape.radius
				elif shape is SphereShape3D: data.radius = shape.radius
				elif shape is ConvexPolygonShape3D:
					var points: PackedVector3Array = shape.points
					if int(report.point_count) + points.size() > STATIC_POINT_CAP:
						report.complete = false; report.reason = "snapshot_point_budget"; break
					var saved: Array = []
					for point: Vector3 in points: saved.append(Observe.vector(point))
					data.points = saved
					report.point_count += points.size()
				else:
					# Never stringify an unbounded native mesh and call it complete.
					data.unsupported = true
					report.complete = false; report.reason = "unsupported_static_shape"
				var enabled: bool = not body.is_shape_owner_disabled(owner_id)
				row.shapes.append({"owner_id":owner_id, "owner_node":str(owner.get_path()) if owner is Node else str(owner), "owner_instance_id":owner.get_instance_id() if is_instance_valid(owner) else 0, "shape_index":body.shape_owner_get_shape_index(owner_id, slot), "enabled":enabled, "local_frame":Observe.frame(local), "world_frame":Observe.frame(body.global_transform * local), "shape":data})
				row.shape_count += 1
				report.shape_count += 1
				if not report.complete: break
			if not report.complete: break
	for path: String in FIXED_SUPPORT_PATHS:
		if not report.supports.has(path): report.missing_supports.append(path)
	if not report.missing_supports.is_empty():
		report.complete = false
		if report.reason.is_empty(): report.reason = "required_support_missing"
	report.elapsed_usec = Time.get_ticks_usec() - begun
	static_budget_ok(report, begun)
	return report

func step(count: int = 1) -> void:
	# The inherited run has completed cold setup and site/host readiness before
	# its first step. Capture before W, GUI input, hold, detonation or any await.
	if static_baseline.is_empty() and is_instance_valid(site) and site.is_inside_tree():
		static_baseline = bounded_static_snapshot("BEFORE_NATIVE_INPUT")
		evidence.static_baseline_r3 = static_baseline
	await super.step(count)

func compare_static_supports(before: Dictionary, after: Dictionary) -> Dictionary:
	var comparison: Dictionary = {"ok":true, "changes":[], "scope":"Only original foundation/plaza/StoneEntrance static supports; destructible glazing and rigid rubble are not required to remain unchanged."}
	if not before.get("complete", false) or not after.get("complete", false):
		comparison.ok = false
		comparison.changes.append({"reason":"incomplete_snapshot", "before":before.get("reason", "baseline_missing"), "after":after.get("reason", "final_missing")})
	var baseline_rows: Dictionary = before.get("supports", {})
	var final_rows: Dictionary = after.get("supports", {})
	for path: String in baseline_rows:
		if not final_rows.has(path):
			comparison.ok = false; comparison.changes.append({"path":path, "reason":"support_removed"}); continue
		var original: Dictionary = baseline_rows[path]
		var actual: Dictionary = final_rows[path]
		for field: String in original:
			if original[field] != actual.get(field):
				comparison.ok = false
				comparison.changes.append({"path":path, "field":field, "before":original[field], "after":actual.get(field)})
	for path: String in final_rows:
		if not baseline_rows.has(path):
			comparison.ok = false; comparison.changes.append({"path":path, "reason":"support_added"})
	return comparison

func finish() -> void:
	if finished: return
	# No await: even support failure or the 55 s watchdog records current static
	# blockers before inherited finish releases inputs and closes the report.
	var after: Dictionary = bounded_static_snapshot("FINAL_ANY_EXIT")
	evidence.static_final_r3 = after
	evidence.static_baseline_r3 = static_baseline
	var comparison: Dictionary = compare_static_supports(static_baseline, after)
	evidence.static_support_comparison_r3 = comparison
	check(static_baseline.get("complete", false), "R3 complete bounded static baseline exists before native input")
	check(after.get("complete", false), "R3 complete bounded final static snapshot exists on every exit")
	check(comparison.ok, "R3 original foundation/plaza/ramp identities, transforms, masks and shape resources remain unchanged")
	super.finish()
