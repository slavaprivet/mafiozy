extends SceneTree
## Geometry/lifecycle component only. No fake positive C4 receipt, player,
## manual collider removal or claim of actual breach traversal/performance.
const AcceptedSite = preload("res://scripts/destruction/palazzo/palazzo_structural_site.gd")
const CandidateSite = preload("res://scripts/destruction/palazzo/palazzo_foundation12_site.gd")
const Access = preload("res://scripts/destruction/palazzo/palazzo_access.gd")
const REVIEWED_RUNTIME_PINS := {
	"scripts/destruction/modular30/owner/vendor/glass/walk_glass_breakage.gd": "c227899b3ab5dabc7abafeee48da6823572f2ae7f55b57f19befe044c4f28b66",
	"scripts/destruction/palazzo/building_support.gd": "762172cb490dc6f929902e4cb6d5377a9079eeb2848bc9f6f644d70bca5f8bf7",
	"scripts/destruction/palazzo/door_close43.gd": "4dfc4a0b512dd4f0e7fe47491de12fdddfffded47c074bb31259839edbdd5f96",
	"scripts/destruction/palazzo/palazzo_access.gd": "a35adea1709f8f0d061a6cc0a3384cd848984384eb87318a410a27671a4982fd",
	"scripts/destruction/palazzo/palazzo_finished_site.gd": "49b635e6bbc81679633742a9433e59d2cc3a56db0934a8d1723f0a177902539d",
	"scripts/destruction/palazzo/palazzo_foundation12_site.gd": "d799c2c57ef62f5249128c13f329c66f408825db05076bb2c7de0a912b208ecb",
	"scripts/destruction/palazzo/palazzo_foundation12_site.tscn": "dbdd690e1b7b29a0866004734b060d150573012eb55b1929097ecc8de92a69ae",
	"scripts/destruction/palazzo/palazzo_glazing.gd": "7187080b0bf558b21a50d94640397b1207d0dacc20af2f5f99a344704fe273a0",
	"scripts/destruction/palazzo/palazzo_live_site.gd": "1342115d570cc3a32f79d36880be3792f94eedcf0a8e73b07667c5d0c5976d1f",
	"scripts/destruction/palazzo/palazzo_site.gd": "ebac39944f743c532730fd2a793a98fd83cb7df4773d6d5350276292a1557a92",
	"scripts/destruction/palazzo/palazzo_structural_site.gd": "736ea7c32efc10d2ca515b1883d9c3a533c1554552bf916b8e277d891263cf30",
	"scripts/destruction/palazzo/source/fragment_body.gd": "baa5f2f9ae41b8e98ef7ac3966eac1043f3126c6547cc647ac5a9fc58ad84062",
	"scripts/destruction/palazzo/source/showcase.gd": "dd734333c59a4efc6f299e67935086fbde3d578ec5ca6860fb9d3183cda8dbcc",
	"scripts/destruction/palazzo/window_shell.gd": "851c63d996363d2f19b48f65abf35391d6491a223e58612c5fa56c05317b88f8",
}
var checks := 0
var failures: Array[String] = []
var output := ""
var manifest_path := ""
var done := false
var started := 0
var world: Node3D
var site: Node3D
var evidence: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		elif arg.begins_with("--qa-manifest="): manifest_path = arg.trim_prefix("--qa-manifest=")
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _process(_delta: float) -> bool:
	if not done and started > 0 and Time.get_ticks_usec() - started > 55000000:
		check(false, "55_second_component_deadline"); finish()
	return false

func provenance() -> bool:
	if not check(not output.is_empty() and not manifest_path.is_empty(), "explicit_output_and_full_root_manifest_required"): return false
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not check(decoded is Dictionary, "root_manifest_dictionary"): return false
	var pins: Dictionary = decoded.get("source_pins", decoded.get("expected_source_pins", {}))
	if not check(not pins.is_empty(), "complete_staged_project_pins_required"): return false
	var required_missing_or_changed: Array[String] = []
	for path: String in REVIEWED_RUNTIME_PINS:
		if pins.get(path, "") != REVIEWED_RUNTIME_PINS[path]: required_missing_or_changed.append(path)
	var fixture_resource: String = get_script().resource_path
	var fixture_path: String = fixture_resource.trim_prefix("res://")
	if not fixture_resource.begins_with("res://") or not pins.has(fixture_path): required_missing_or_changed.append("current_fixture:" + fixture_path)
	evidence.required_provenance = {"runtime_pins":REVIEWED_RUNTIME_PINS.size(), "fixture":fixture_path, "missing_or_changed":required_missing_or_changed}
	if not check(required_missing_or_changed.is_empty(), "reviewed_runtime_and_executing_fixture_pins_required"): return false
	var bad: Array[String] = []
	for path: String in pins:
		if path.is_absolute_path() or path.contains("..") or path.contains(":") or FileAccess.get_sha256("res://" + path) != pins[path]: bad.append(path)
	evidence.provenance = {"manifest":manifest_path, "sha256":FileAccess.get_sha256(manifest_path), "checked":pins.size(), "mismatches":bad}
	return check(bad.is_empty(), "staged_runtime_and_fixture_match_root_pins")

func stable_support() -> bool:
	var stable := 0
	for frame: int in 600:
		await physics_frame
		if done: return false
		var state: Dictionary = site._structure.diagnostics()
		if state.get("ok", false) and not state.get("busy", true) and state.get("state", "") == "stable": stable += 1
		else: stable = 0
		if stable >= 15: return true
	return false

func chunk_snapshot() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for body: RigidBody3D in site.foundation_chunks:
		var shapes: Array[Dictionary] = []
		for child: Node in body.get_children():
			if child is CollisionShape3D:
				shapes.append({"id":child.get_instance_id(), "shape_id":child.shape.get_instance_id(), "size":str(child.shape.size) if child.shape is BoxShape3D else "unsupported", "enabled":not child.disabled, "frame":str(child.transform)})
		rows.append({"id":body.get_instance_id(), "path":str(body.get_path()), "grid":str(body.get_meta("foundation_grid")), "source":body.get_meta("source_id"), "generation":body.get_meta("foundation_generation"), "frame":str(body.transform), "frozen":body.freeze, "layer":body.collision_layer, "mask":body.collision_mask, "detached":body.get_meta("detached", false), "shapes":shapes})
	return rows

func verify_intact(label: String, baseline: Dictionary) -> void:
	var stats: Dictionary = site.get_stats()
	check(site.get_node_or_null("OriginalFoundation") == null, label + ": no old immutable foundation remains")
	check(site.get_node_or_null("OriginalPlaza") is StaticBody3D, label + ": original world plaza remains")
	check(stats.foundation.chunks == 12 and stats.foundation.intact == 12 and stats.foundation.invalid == 0, label + ": all12 ordinary intact foundation bodies")
	check(stats.native_body_count == baseline.native_body_count + 12 and stats.native_shape_count == baseline.native_shape_count + 12, label + ": exact12 owned body/shape addition")
	check(stats.pool == baseline.pool and stats.panels == baseline.panels and stats.trees == baseline.trees and stats.benches == baseline.benches, label + ": other architecture pool and site content preserved")
	check(stats.foundation.batch_builds_this_generation == 1, label + ": one final batch build")
	check(site.support_setup.get("ok", false) and site.support_setup.get("ground_bodies", 0) == 1, label + ": support uses actual plaza only")
	var seen: Dictionary = {}
	var expected_size := Vector3(8.5 / 4.0, .22, 6.5 / 3.0)
	for body: RigidBody3D in site.foundation_chunks:
		var grid: Vector2i = body.get_meta("foundation_grid")
		check(not seen.has(grid), label + ": unique grid cell " + str(grid))
		seen[grid] = true
		var expected := Vector3(-4.25 + (grid.x + .5) * expected_size.x, .19, -3.25 + (grid.y + .5) * expected_size.z)
		check(site.owns_collider(body) and body.get_meta("source_id") == site.source_id and body.get_meta("foundation_generation") == site.rebuild_generation, label + ": source and generation ownership")
		check(body.transform.is_equal_approx(Transform3D(Basis.IDENTITY, expected)) and body.get_meta("section_size").is_equal_approx(expected_size), label + ": exact original stone volume grid")
		check(body.get_meta("pooled_fragments").is_empty() and not body.has_meta("fracture_tiles") and site.pieces.has(body) and not site.pooled_fragments.has(body), label + ": no hidden foundation pool")
		check(body.collision_layer == 1 and body.collision_mask == (1 | 512) and site.render_by_id.has(body.get_instance_id()), label + ": inherited collision and batch ownership")
		var collision: CollisionShape3D
		var shape_count := 0
		for child: Node in body.get_children():
			if child is CollisionShape3D: collision = child; shape_count += 1
		check(shape_count == 1 and collision.shape is BoxShape3D and collision.shape.size.is_equal_approx(expected_size) and not collision.disabled, label + ": one exact intact box")
		# Short native ray crosses only this slab, avoiding the building above.
		var ray := PhysicsRayQueryParameters3D.create(site.to_global(expected + Vector3.UP * .125), site.to_global(expected - Vector3.UP * .125), 1)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(hit.get("collider") == body and absf(site.to_local(hit.position).y - .30) < .0001, label + ": actual native chunk surface at original .30m")
	evidence[label] = {"stats":stats, "chunks":chunk_snapshot()}

func run() -> void:
	started = Time.get_ticks_usec()
	if not provenance(): finish(); return
	world = Node3D.new(); root.add_child(world)
	# Independent sequential baseline, disposed before candidate creation.
	site = AcceptedSite.new(); site.source_id = "foundation_component_baseline"
	world.add_child(site); Access.install(site)
	if not check(site.site_ready, "accepted baseline ready"): finish(); return
	if not check(await stable_support(), "accepted support stable"): finish(); return
	var baseline: Dictionary = site.get_stats()
	evidence.baseline = baseline
	site.free(); await physics_frame; await process_frame
	if done: return
	site = CandidateSite.new(); site.source_id = "foundation_component_candidate"
	world.add_child(site); Access.install(site)
	if not check(site.site_ready, "candidate ready"): finish(); return
	if not check(await stable_support(), "candidate support stable without immutable foundation"): finish(); return
	verify_intact("initial", baseline)
	var plaza: StaticBody3D = site.get_node("OriginalPlaza") as StaticBody3D
	var plaza_id: int = plaza.get_instance_id()
	var plaza_frame: Transform3D = plaza.global_transform
	var old_generation: int = site.rebuild_generation
	var old_ids: Array[int] = []
	for body: RigidBody3D in site.foundation_chunks: old_ids.append(body.get_instance_id())
	# The public local full-collapse command is a lifecycle component check,
	# not an authenticated C4 receipt or a player passage claim.
	var command: Dictionary = site.request_full_collapse("foundation_component_all")
	if not check(command.get("ok", false), "public full collapse accepted"): finish(); return
	var complete := false
	for frame: int in 360:
		await physics_frame
		if done: return
		if site.event_status("foundation_component_all").get("completed", false): complete = true; break
	check(complete, "inherited full collapse completed")
	check(site.get_stats().foundation.detached == 12, "all foundation chunks participate in ordinary destruction")
	for body: RigidBody3D in site.foundation_chunks:
		check(body.get_meta("detached", false) and body.collision_layer == 512 and body.collision_mask == (1 | 512), "ordinary rubble collision policy after collapse")
	evidence.collapsed = {"stats":site.get_stats(), "chunks":chunk_snapshot()}
	if not check(site.request_reset().get("ok", false), "inherited public reset queued"): finish(); return
	for frame: int in 120:
		await physics_frame
		if done: return
		if not site.rebuilding: break
	if not check(not site.rebuilding and site.rebuild_generation == old_generation + 1, "native reset completed in new generation"): finish(); return
	if not check(await stable_support(), "reset support stable"): finish(); return
	verify_intact("reset", baseline)
	check(plaza.get_instance_id() == plaza_id and plaza.global_transform == plaza_frame, "world ground survives destruction and reset unchanged")
	for body: RigidBody3D in site.foundation_chunks: check(not old_ids.has(body.get_instance_id()), "no stale foundation body reused across reset")
	finish()

func finish() -> void:
	if done: return
	done = true
	if is_instance_valid(site): evidence.terminal_site = site.get_stats()
	evidence.scope = {"component_only":true, "authenticated_C4":"NOT_RUN", "actual_main_player_W_S":"NOT_RUN", "loaded_scene_performance":"NOT_RUN", "immutable_original_ramps":"preserved; separate building-wide destruction scope", "collider_mutation_for_passage":false}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL", "checks":checks, "failures":failures, "evidence":evidence, "elapsed_usec":Time.get_ticks_usec()-started}, "\t"))
			file.close()
		else: failures.append("output_write_failed")
	quit(0 if failures.is_empty() else 2)
