extends "passage_floor_1m_r2.gd"
## Read-only terminal evidence, including early blast/support/deadline failure.
const STATIC_NODE_CAP := 16384
const STATIC_BODY_CAP := 512
const STATIC_SHAPE_CAP := 4096
const STATIC_POINT_CAP := 65536
const STATIC_USEC_CAP := 250000
const FIXED_SUPPORT_PATHS := ["OriginalPlaza", "StoneEntrance/OuterRamp", "StoneEntrance/Threshold", "StoneEntrance/InnerRamp"]
var static_baseline: Dictionary = {}
var foundation_baseline: Dictionary = {}
var foundation_glazing_ids: Dictionary = {}
const FOUNDATION_REVIEWED_PINS := {
  "scripts/destruction/modular30/owner/vendor/glass/walk_glass_breakage.gd": "c227899b3ab5dabc7abafeee48da6823572f2ae7f55b57f19befe044c4f28b66",
  "scripts/destruction/palazzo/building_support.gd": "762172cb490dc6f929902e4cb6d5377a9079eeb2848bc9f6f644d70bca5f8bf7",
  "scripts/destruction/palazzo/door_close43.gd": "4dfc4a0b512dd4f0e7fe47491de12fdddfffded47c074bb31259839edbdd5f96",
  "scripts/destruction/palazzo/palazzo_finished_site.gd": "49b635e6bbc81679633742a9433e59d2cc3a56db0934a8d1723f0a177902539d",
  "scripts/destruction/palazzo/palazzo_glazing.gd": "7187080b0bf558b21a50d94640397b1207d0dacc20af2f5f99a344704fe273a0",
  "scripts/destruction/palazzo/palazzo_live_site.gd": "1342115d570cc3a32f79d36880be3792f94eedcf0a8e73b07667c5d0c5976d1f",
  "scripts/destruction/palazzo/palazzo_site.gd": "ebac39944f743c532730fd2a793a98fd83cb7df4773d6d5350276292a1557a92",
  "scripts/destruction/palazzo/palazzo_structural_site.gd": "736ea7c32efc10d2ca515b1883d9c3a533c1554552bf916b8e277d891263cf30",
  "scripts/destruction/palazzo/source/fragment_body.gd": "baa5f2f9ae41b8e98ef7ac3966eac1043f3126c6547cc647ac5a9fc58ad84062",
  "scripts/destruction/palazzo/source/showcase.gd": "dd734333c59a4efc6f299e67935086fbde3d578ec5ca6860fb9d3183cda8dbcc",
  "scripts/destruction/palazzo/window_shell.gd": "851c63d996363d2f19b48f65abf35391d6491a223e58612c5fa56c05317b88f8",
  "scripts/destruction/palazzo/palazzo_access.gd": "a35adea1709f8f0d061a6cc0a3384cd848984384eb87318a410a27671a4982fd",
  "scripts/destruction/palazzo/palazzo_foundation12_site.gd": "d799c2c57ef62f5249128c13f329c66f408825db05076bb2c7de0a912b208ecb",
  "scripts/destruction/palazzo/palazzo_foundation12_site.tscn": "dbdd690e1b7b29a0866004734b060d150573012eb55b1929097ecc8de92a69ae",
  "scripts/destruction/palazzo/c4_building_blast.gd": "54a39ca265a692c77456e9f1e243924fc40bf9840509fa7dd6820a1d3adf2888",
  "scripts/destruction/palazzo/c4_equipment.gd": "11f9c4127d27a3349bc0e1242b3661fb9637e8f2bcd267217ade9db3c4e7cd29",
  "scripts/destruction/palazzo/palazzo_host.gd": "1397680ae5de0487f2faedea1e82c96181252b38d8b8035ec117c4f3e8cc4c51",
  "tests/c4_strength1920/frozen/c4_device_icon43.gd": "0f53e5e9ddc917024e29b77d850b437c9bf6905933e2bdc364d85d61416065b5",
  "tests/c4_strength1920/frozen/c4_equipment.gd": "ada0c95dcf2be2277bf09a7509c3fc48e81fdc5b4071223e901101d24dcdb3e8",
  "tests/c4_strength1920/frozen/c4_icon_cache43.gd": "47c1408055013cf3a930e04a787a831531948bc7f9de8ce98c839e8c212dd1a8",
  "tests/c4_strength1920/frozen/c4_perf_observer45.gd": "b4c6a0c7a6781757d7a9f98a67898e3db42151494302f4b7cad441ff21053e25",
  "tests/c4_strength1920/frozen/c4_placement_query45.gd": "0b34c7a7cc143be94cde9e46b54fa1c30b84bac30744061680312aaaa0fa4208",
  "tests/c4_strength1920/frozen/c4_surface_owner45.gd": "db843e8ce00a87d34455385a210657ee806f380bd59d3dbcf4a2e740eb68edd1",
  "tests/c4_strength1920/frozen/c4_visuals.gd": "ec2b4f1c5a312bf23bfa6401e84ae0c5d90cc91241592270824b5eca383a1ab3",
  "tests/c4_strength1920/frozen/test_c4.gd": "12db538fe15d4419b72a62fc3868b8840dd2621a03159305c4ed244e60831b34",
  "tests/c4_strength1920/passage_floor_1m.gd": "6464ee4e5ea791b64abaf517e23195cce7818c7a3dcd6247070f73a0b887092c",
  "tests/c4_strength1920/passage_floor_1m_r2.gd": "4aa9fa48f5673ebae0c21cc7d506fc83dfe69fe01db1995b35f22a5b2321aeb1",
  "tests/c4_strength1920/passage_floor_1m_r3.gd": "e335fc9a8582b9c96fd7344883634d4f32e484e3735733b0887db75b97b34158",
  "tests/c4_strength1920/test_c4_passage_20261003.gd": "305e5d6b0e2729f1e3fcddf95dd078e5f2fc7b223cd032e21eb1fb5b8b873a88",
  "tests/foundation12_component/test_foundation12_component.gd": "b8feedc445fe51bcef6f82de29370c97656825af681ea50a5fab2f077a756e08",
  "scripts/main.gd": "d51b213f0a8862dc20130fccda27f0d0b288165387c4bf17df5a9396cb240439"
}


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
		if not foundation_glazing_ids.has(str(body.get_instance_id())):
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
	var first: bool = static_baseline.is_empty() and is_instance_valid(site) and site.is_inside_tree()
	# The first inherited step is the25-frame cold setup, before Q/LMB/W/S.
	# Let native PhysicsServer register every shape before querying each slab.
	await super.step(count)
	if first and not finished:
		check(callbacks.is_empty() and equipment._charges.is_empty(), "F12 foundation baseline precedes real placement and explosion")
		remember_glazing_exceptions()
		static_baseline = bounded_static_snapshot("BEFORE_NATIVE_INPUT")
		evidence.static_baseline_foundation12 = static_baseline
		foundation_baseline = foundation_snapshot("BEFORE_NATIVE_INPUT", true)
		evidence.foundation12_before = foundation_baseline
		check(foundation_baseline.ok, "F12 all12 exact original-volume/mass owned foundation cells have enabled native physical shapes before input")

func compare_static_supports(before: Dictionary, after: Dictionary) -> Dictionary:
	var comparison: Dictionary = {"ok":true, "changes":[], "scope":"F12: four required original plaza/entrance supports and every other nondestructible SITE static body remain unchanged; only the28 baseline-registered glazing bodies are exempt."}
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
	evidence.static_final_foundation12 = after
	evidence.static_baseline_foundation12 = static_baseline
	var comparison: Dictionary = compare_static_supports(static_baseline, after)
	evidence.static_support_comparison_foundation12 = comparison
	check(static_baseline.get("complete", false), "F12 complete bounded static baseline exists before native input")
	check(after.get("complete", false), "F12 complete bounded final static snapshot exists on every exit")
	check(comparison.ok, "F12 four original plaza/entrance supports and all other nondestructible site statics keep identities, transforms, masks and shape resources")
	var foundation_after: Dictionary = foundation_snapshot("FINAL_ANY_EXIT", false)
	evidence.foundation12_after = foundation_after
	evidence.foundation_contract_scope = {"receipt":"F12_OWNED_FOUNDATION_AND_STATIC4", "old_static5_receipt":false, "required_static_supports":FIXED_SUPPORT_PATHS.duplicate(), "all_other_site_statics_immutable_except_registered_panes":true, "foundation_cells":12, "QA_geometry_or_actor_mutation":false, "foundation_changed_during_cold_production_build":true, "rubble_policy":"Original production512/513, enabled .98 loose box and inherited mass; same rigid/shape IDs retained."}
	check(foundation_after.ok, "F12 all original12 owned rigid foundation pieces and enabled native shapes survive, including physical debris")
	super.finish()

func provenance() -> bool:
	if not super.provenance(): return false
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var pins: Dictionary = raw.get("source_pins", raw.get("expected_source_pins", {}))
	var missing: Array[String] = []
	for path: String in FOUNDATION_REVIEWED_PINS:
		if pins.get(path, "") != FOUNDATION_REVIEWED_PINS[path]: missing.append(path)
	var executing: String = get_script().resource_path.trim_prefix("res://")
	if not pins.has(executing): missing.append("executing_fixture:" + executing)
	evidence.foundation_provenance = {"required_pins":FOUNDATION_REVIEWED_PINS.size(), "executing_fixture":executing, "missing_or_changed":missing}
	return check(missing.is_empty(), "F12 exact reviewed foundation/runtime/QA and executing fixture pins required")

func remember_glazing_exceptions() -> void:
	# Only this generation's registered native panes may change as a normal
	# result of C4. A name/prefix alone never exempts another static body.
	var glazing: Variant = site.get("_glazing")
	if not is_instance_valid(glazing): return
	var panes: Variant = glazing.get("_panes")
	if not panes is Dictionary: return
	for entry: Dictionary in panes.values():
		var body: Variant = entry.get("body")
		if body is StaticBody3D and is_instance_valid(body) and body.get_parent() == glazing and body.get_meta("source_id", "") == site.source_id:
			foundation_glazing_ids[str(body.get_instance_id())] = str(site.get_path_to(body))
	evidence.foundation_glazing_exception_ids = foundation_glazing_ids.duplicate()
	check(foundation_glazing_ids.size() == 28, "F12 only28 original registered destructible panes exempt from immutable site-static comparison")

func foundation_assert(report: Dictionary, ok: bool, issue: String) -> void:
	if not ok: report.errors.append(issue)

func foundation_physical_probe(body: RigidBody3D, collision: CollisionShape3D) -> Dictionary:
	# Query only. This tiny sphere lies inside the chunk's current solid box.
	# Record all returned IDs and fail on saturation; never erase/exclude peers
	# merely to force the intended body to become a positive result.
	var shape := SphereShape3D.new()
	shape.radius = .002
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, collision.global_position)
	query.collision_mask = 1 | 512
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits: Array[Dictionary] = game.get_world_3d().direct_space_state.intersect_shape(query, 32)
	var ids: Array[int] = []
	var own := false
	for hit: Dictionary in hits:
		var collider: Variant = hit.get("collider")
		if is_instance_valid(collider): ids.append(collider.get_instance_id())
		if collider == body: own = true
	return {"ok":own and hits.size() < 32, "own_body_hit":own, "saturated":hits.size() >= 32, "ids":ids, "world_point":Observe.vector(collision.global_position), "mask":query.collision_mask}

func foundation_snapshot(label: String, initial: bool) -> Dictionary:
	var report: Dictionary = {"label":label, "scope":"F12 exact-volume owned foundation;4 required immutable supports plus every other nondestructible site static", "physics_frame":Engine.get_physics_frames(), "errors":[], "rows":[], "by_id":{}, "authored_volume_m3":0.0, "actual_box_volume_m3":0.0, "initial_mass_kg":218.79, "actual_mass_kg":0.0, "detached":0, "native_probes":0, "ok":false, "inherited_release_policy":{"intact_mass_per_chunk_kg":18.2325, "detached_mass_per_chunk_kg":0.709041666666667, "detached_box_axis_scale":0.98, "detached_box_volume_scale":0.941192, "dynamic_mass_conserved":false, "loose_collision_matches_full_authored_volume":false}}
	if not is_instance_valid(site) or not site.is_inside_tree():
		report.errors.append("site_unavailable"); return report
	foundation_assert(report, site.get_node_or_null("OriginalFoundation") == null, "old_static_foundation_must_be_absent_from_cold_build")
	var chunks: Variant = site.get("foundation_chunks")
	if not chunks is Array or chunks.size() != 12:
		report.errors.append("exact12_foundation_array_required"); return report
	var stats: Dictionary = site.get_stats()
	report.stats = stats.get("foundation", {})
	report.site_id = site.get_instance_id()
	report.generation = site.rebuild_generation
	foundation_assert(report, not site.rebuilding and not site.collapsing, "same_live_building_generation")
	foundation_assert(report, stats.native_body_count == 669 and stats.native_shape_count == 2081 and stats.pool == 560 and stats.panels == 28, "original657bodies2069shapes_plus12_owned_no_pool_change")
	foundation_assert(report, report.stats.get("source_static_removed_during_cold_build", false) and report.stats.get("source_error", "missing").is_empty() and report.stats.get("hidden_foundation_pool", -1) == 0, "cold_original_volume_replacement_no_hidden_pool")
	foundation_assert(report, site.support_setup.get("ok", false) and site.support_setup.get("ground_bodies", 0) == 1, "actual_plaza_is_single_ground_support")
	var seen_grid: Dictionary = {}
	var expected_size := Vector3(8.5 / 4.0, .22, 6.5 / 3.0)
	var expected_volume: float = expected_size.x * expected_size.y * expected_size.z
	for value: Variant in chunks:
		if not value is RigidBody3D or not is_instance_valid(value):
			report.errors.append("missing_native_rigid_chunk"); continue
		var body: RigidBody3D = value
		var id: String = str(body.get_instance_id())
		var grid: Variant = body.get_meta("foundation_grid", null)
		if not grid is Vector2i or grid.x < 0 or grid.x >= 4 or grid.y < 0 or grid.y >= 3:
			report.errors.append(id + ":invalid_grid"); continue
		foundation_assert(report, not seen_grid.has(grid) and not report.by_id.has(id), id + ":duplicate_grid_or_identity")
		seen_grid[grid] = true
		var at := Vector3(-4.25 + (grid.x + .5) * expected_size.x, .19, -3.25 + (grid.y + .5) * expected_size.z)
		var detached: bool = body.get_meta("detached", false)
		var row: Dictionary = {"id":body.get_instance_id(), "path":str(body.get_path()), "grid":[grid.x, grid.y], "source_id":body.get_meta("source_id", ""), "generation":body.get_meta("foundation_generation", -1), "frame":Observe.frame(body.global_transform), "site_frame":Observe.frame(site.global_transform.affine_inverse() * body.global_transform), "detached":detached, "frozen":body.freeze, "parked":body.get_meta("parked", false), "layer":body.collision_layer, "mask":body.collision_mask, "mass":body.mass, "shape_count":0, "shapes":[]}
		report.rows.append(row); report.by_id[id] = row
		foundation_assert(report, body.is_inside_tree() and not body.is_queued_for_deletion() and site.owns_collider(body) and body.get_parent() == site.building and row.source_id == site.source_id and row.generation == site.rebuild_generation, id + ":current_physical_owner_and_generation")
		foundation_assert(report, body.get_meta("section_size", Vector3.ZERO).is_equal_approx(expected_size) and body.get_meta("foundation_chunk", false) and body.get_meta("pooled_fragments", []).is_empty() and not body.has_meta("fracture_tiles") and site.pieces.has(body) and not site.pooled_fragments.has(body) and site.render_by_id.has(body.get_instance_id()), id + ":original_authored_volume_and_visible_owned_lifecycle")
		var expected_mass: float = clampf(expected_volume * .7, .12, 3.0) if detached else maxf(2.0, expected_volume * 18.0)
		foundation_assert(report, is_equal_approx(body.mass, expected_mass), id + ":inherited_intact_or_rubble_mass")
		foundation_assert(report, body.collision_layer == (512 if detached else 1) and body.collision_mask == 513, id + ":ordinary_intact_or_rubble_layers")
		if detached: report.detached += 1
		else:
			foundation_assert(report, body.freeze and body.transform.is_equal_approx(Transform3D(Basis.IDENTITY, at)), id + ":intact_cell_exact_original_pose")
		if initial: foundation_assert(report, not detached, id + ":all12_intact_before_native_input")
		else:
			var old: Dictionary = foundation_baseline.get("by_id", {}).get(id, {})
			foundation_assert(report, not old.is_empty() and old.get("grid", []) == row.grid and old.get("generation", -1) == row.generation and old.get("source_id", "") == row.source_id, id + ":same_original12_identity_not_replacement")
		var collision: CollisionShape3D
		if body.get_child_count() > 64:
			report.errors.append(id + ":child_evidence_budget"); continue
		for child: Node in body.get_children():
			if child is CollisionShape3D: collision = child; row.shape_count += 1
		if row.shape_count != 1 or not is_instance_valid(collision) or not collision.shape is BoxShape3D:
			report.errors.append(id + ":one_actual_box_shape_required"); continue
		var shape_size: Vector3 = expected_size * (.98 if detached else 1.0)
		var owners: PackedInt32Array = body.get_shape_owners()
		var owner_ok: bool = owners.size() == 1
		if owner_ok:
			owner_ok = body.shape_owner_get_shape_count(owners[0]) == 1 and not body.is_shape_owner_disabled(owners[0]) and body.shape_owner_get_owner(owners[0]) == collision
			if owner_ok: owner_ok = body.shape_owner_get_shape(owners[0], 0) == collision.shape and body.shape_owner_get_transform(owners[0]).is_equal_approx(Transform3D.IDENTITY)
		foundation_assert(report, owner_ok and not collision.disabled and collision.transform.is_equal_approx(Transform3D.IDENTITY) and collision.shape.size.is_equal_approx(shape_size), id + ":enabled_native_owner_box_retains_full_or_inherited98percent_shape")
		row.shape_id = collision.shape.get_instance_id(); row.collision_id = collision.get_instance_id()
		row.shapes.append({"id":row.collision_id, "resource_id":row.shape_id, "enabled":not collision.disabled, "size":Observe.vector(collision.shape.size), "local_frame":Observe.frame(collision.transform), "world_frame":Observe.frame(collision.global_transform)})
		row.actual_box_volume_m3 = collision.shape.size.x * collision.shape.size.y * collision.shape.size.z
		report.actual_box_volume_m3 += row.actual_box_volume_m3
		if not initial:
			var old: Dictionary = foundation_baseline.get("by_id", {}).get(id, {})
			foundation_assert(report, old.get("shape_id", 0) == row.shape_id and old.get("collision_id", 0) == row.collision_id, id + ":same_shape_resource_and_collision_node")
		row.native_probe = foundation_physical_probe(body, collision)
		foundation_assert(report, row.native_probe.ok, id + ":native_physics_query_resolves_the_real_chunk")
		if row.native_probe.ok: report.native_probes += 1
		if initial:
			var ray := PhysicsRayQueryParameters3D.create(site.to_global(at + Vector3.UP * .125), site.to_global(at - Vector3.UP * .125), 1)
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
			var top_ok: bool = hit.get("collider") == body and absf(site.to_local(hit.get("position", Vector3.ZERO)).y - .30) < .0001
			row.native_original_top_y = site.to_local(hit.get("position", Vector3.ZERO)).y
			foundation_assert(report, top_ok, id + ":native_original30cm_top_surface")
		report.authored_volume_m3 += expected_volume
		report.actual_mass_kg += body.mass
	foundation_assert(report, seen_grid.size() == 12 and report.by_id.size() == 12 and report.native_probes == 12 and absf(report.authored_volume_m3 - 12.155) < .0001, "all12_grid_cells_exact12_155m3_and_native_physical_shapes")
	if initial: foundation_assert(report, absf(report.actual_mass_kg - 218.79) < .001, "all12_initial_mass218_79kg")
	else:
		foundation_assert(report, foundation_baseline.get("ok", false) and report.site_id == foundation_baseline.get("site_id", 0) and report.generation == foundation_baseline.get("generation", -1), "same_validated_foundation_site_and_generation")
		report.direct_foundation_ids = []
		var state: Dictionary = blast.snapshot() if is_instance_valid(blast) else {}
		if state.get("events", []).size() == 1:
			var event: Dictionary = state.events[0]
			for row: Dictionary in report.rows:
				if event.released.has(row.id): report.direct_foundation_ids.append(row.id)
				if row.grid == [0, 2]: foundation_assert(report, event.released.has(row.id) and row.detached, "actual_native_C4_released_original_front_lane_foundation_chunk")
	report.ok = report.errors.is_empty()
	return report
