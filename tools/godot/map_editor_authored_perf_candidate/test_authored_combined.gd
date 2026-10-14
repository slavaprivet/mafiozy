extends SceneTree
const Factory = preload("res://authored_factory_perf.gd")
const Registry = preload("res://authored_registry_perf.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
const Bundle = preload("res://scripts/map_editor/map_bundle.gd")
const BundleStore = preload("res://scripts/map_editor/map_bundle_store.gd")
const Patch = preload("res://scripts/map_editor/map_patch.gd")
const Ground = preload("res://ground_document.gd")
const Renderer = preload("res://ground_renderer.gd")
const SurfaceMaterials = preload("res://preview_surface_materials.gd")
var failures: Array[String] = []
var checks := 0
var factory: RefCounted
var catalog: Dictionary
var topology: Dictionary
var origin := Vector3.ZERO
var shared_materials := {}
var requirements := {}
var available := {}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func begin_gate() -> Dictionary:
	return {"ok": true}

func end_gate(_document: Dictionary) -> Dictionary:
	return {"ok": true}

func lease() -> bool:
	return true

func water(_phase: String, _delta: Dictionary) -> Dictionary:
	return {"ok": true, "receipt": {"owner": "test-staged-water-adapter"}}

func navigation(_delta: Dictionary) -> Dictionary:
	return {"ok": true}

func reject_ground(_delta: Dictionary) -> Dictionary:
	return {"ok": false}

func session() -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var index := Registry.new()
	var house_id := ""
	for object: Dictionary in catalog.objects:
		if not object.has("resourceId"): continue
		var result: Dictionary = factory.spawn_key(str(object.key), {"exterior_collisions": true})
		check(result.get("ok", false), "Source asset spawned: " + str(object.key))
		if not result.get("ok", false): continue
		world.add_child(result.root)
		var row := {"kind": str(object.dataset), "model": str(object.resourceId), "label": str(object.assetId), "source": object.sourceRecord.duplicate(true)}
		check(index.register_object(str(object.key), result.root, row, [], result.pending.is_empty()).ok, "Stable native source identity registered")
		if house_id.is_empty() and str(object.assetId) == "old_town_narrow_townhouse_v1" and result.pending.is_empty(): house_id = str(object.key)
		requirements[str(object.resourceId)] = [str(object.resourceId)]
		available[str(object.resourceId)] = factory.cached_scene(str(object.resourceId)) != null
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 40, 0)
	var controller := Controller.new()
	world.add_child(controller)
	var baseline: Dictionary = index.source_document("authored-full-source-persistence")
	check(controller.setup(index, baseline, camera, begin_gate, end_gate).ok and controller.enter_editor().ok, "Paused native object controller ready")
	var ground := Ground.new()
	check(ground.setup_baseline(topology, origin).ok, "Actual full ground source ready")
	var renderer := Renderer.new()
	world.add_child(renderer)
	check(renderer.configure(ground, shared_materials, lease, water, navigation).ok, "Independent native ground renderer ready")
	return {"world": world, "registry": index, "controller": controller, "baseline": baseline, "house_id": house_id, "ground": ground, "renderer": renderer}

func ground_load(target: Dictionary, patch: Dictionary) -> Dictionary:
	var result: Dictionary = target.ground.load_patch(patch, target.renderer.apply, target.renderer.validate_navigation, target.renderer.rollback)
	if result.ok and not result.get("unchanged", false): return target.renderer.finalize()
	return result

func resigned(bundle: Dictionary) -> Dictionary:
	var result := bundle.duplicate(true)
	result.erase("payload_sha256")
	result["payload_sha256"] = Patch._canonical(result).sha256_text()
	return result

func run() -> void:
	root.size = Vector2i(1280, 720)
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	factory = Factory.new()
	check(factory.configure(catalog), "Verified source catalog configured")
	topology = JSON.parse_string(FileAccess.get_file_as_string("res://data/topology_for_placement.json"))
	var block: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/block.json"))
	topology.palette = block.surface.palette.duplicate(true)
	origin = Vector3(block.originM[0], block.originM[1], block.originM[2])
	for tile in Ground.SOURCE_TILES: shared_materials[str(tile)] = SurfaceMaterials.create_material(block.surface, tile, origin)
	for name in Ground.NAMED_LAYERS: shared_materials["layer:" + name] = StandardMaterial3D.new()
	var a := session()
	var house_id: String = a.house_id
	a.controller.selected_id = house_id
	check(a.controller.handle_action("move", {"delta": [4, 0, 7]}).ok, "Native house edited before publication")
	check(a.controller.handle_action("rotate", {"degrees": 10.0}).ok, "Native house rotation edited")
	check(a.controller.handle_action("add", {"catalog_id": house_id}).ok, "Stable authored clone added")
	var clone_id: String = a.controller.selected_id
	var painted := Vector2i(-1, -1)
	for row in range(200):
		for col in range(180):
			if a.ground.is_editable(row, col) and a.ground.cell_state(row, col).tile == 0:
				painted = Vector2i(col, row)
				break
		if painted.x >= 0: break
	a.ground.begin_stroke()
	a.ground.set_tile(painted.y, painted.x, 8)
	a.ground.set_named_layer(painted.y, painted.x, "dirt")
	check(a.renderer.commit_stroke().ok, "Actual terrain and named layer edited")
	var object_edited: Dictionary = a.controller.document.to_dictionary()
	var ground_edited: Dictionary = a.ground.export_patch()
	var created := Bundle.create(a.baseline, object_edited, requirements, "Объекты и земля", ground_edited, a.ground.validate_patch)
	check(created.ok, "Combined object+ground publication created")
	var exported := Bundle.export_json(created.bundle)
	var parsed := Bundle.import_json(exported.text)
	check(exported.ok and parsed.ok, "Combined portable JSON roundtrip")
	var path := "user://maps/tests/combined-%d.json" % Time.get_ticks_usec()
	check(BundleStore.save_bundle(created.bundle, a.baseline, requirements, available, path, a.ground.validate_patch).ok, "Actual source combined bundle saved with trusted ground validator")
	var b := session()
	var saved_read := BundleStore.load_bundle(b.baseline, requirements, available, path, b.ground.validate_patch)
	check(saved_read.ok and not saved_read.recovered and Patch._canonical(saved_read.bundle) == Patch._canonical(created.bundle), "Fresh disk load validates both original source contracts")
	var accepted := Bundle.validate(b.baseline, saved_read.bundle, requirements, available, b.ground.validate_patch)
	check(accepted.ok, "Fresh source session accepts portable envelope")
	check(b.controller.install_document(accepted.document).ok, "Fresh source reconstructs native objects and clone")
	check(ground_load(b, accepted.ground_patch).ok, "Fresh source reconstructs actual terrain patch")
	check(Patch._canonical(b.controller.document.to_dictionary()) == Patch._canonical(object_edited), "Object transforms/IDs/source metadata match publication exactly")
	check(Patch._canonical(b.ground.export_patch()) == Patch._canonical(ground_edited), "Ground cells and layers match publication exactly")
	check(b.registry.has_object(clone_id) and b.registry.ids().size() == 243, "Fresh scene contains trusted stable clone ID")
	var restored_cell: Dictionary = b.ground.cell_state(painted.y, painted.x)
	check(restored_cell.tile == 8 and restored_cell.layer == "dirt", "Exact painted source cell restored")
	var corrupted: Dictionary = parsed.bundle.duplicate(true)
	corrupted.label = "подмена"
	check(not Bundle.validate(b.baseline, corrupted, requirements, available, b.ground.validate_patch).ok, "Checksum rejects tampered portable envelope")
	corrupted = parsed.bundle.duplicate(true)
	corrupted.ground_patch.baseline_sha256 = "0".repeat(64)
	check(not Bundle.validate(b.baseline, resigned(corrupted), requirements, available, b.ground.validate_patch).ok, "Even re-signed wrong ground source hash is rejected")
	var missing := available.duplicate()
	missing.erase(str(object_edited.objects[0].model))
	check(not Bundle.validate(b.baseline, parsed.bundle, requirements, missing, b.ground.validate_patch).ok, "Missing verified native asset prevents install before either domain changes")
	corrupted = parsed.bundle.duplicate(true)
	corrupted.object_patch.added[0].source.id = "forged-authority"
	var forged := Bundle.validate(b.baseline, resigned(corrupted), requirements, available, b.ground.validate_patch)
	var before_forged: Dictionary = b.controller.document.to_dictionary()
	var host_rejection: Dictionary = b.controller.install_document(forged.document) if forged.ok else forged
	check(forged.ok and not host_rejection.ok and b.controller.document.to_dictionary() == before_forged, "Data checksum is not authority: trusted native host rejects forged clone provenance")
	# Explicitly expose the absent cross-domain transaction owner, not pretend
	# two sequential successful loaders provide atomic object+ground installation.
	var c := session()
	var before_object: Dictionary = c.controller.document.to_dictionary()
	var before_ground: Dictionary = c.ground.export_patch()
	var object_installed: Dictionary = c.controller.install_document(accepted.document)
	var failed_ground: Dictionary = c.ground.load_patch(accepted.ground_patch, reject_ground, c.renderer.validate_navigation, c.renderer.rollback)
	var partial_commit: bool = object_installed.ok and not failed_ground.ok and c.controller.document.to_dictionary() != before_object and c.ground.export_patch() == before_ground
	check(partial_commit, "KNOWN GAP reproduced: sequential object install + failed ground adapter leaves one domain committed")
	for suffix in ["", ".bak", ".tmp"]:
		var file: String = ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	print("COMBINED_PERSISTENCE_QA ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "sourceObjects": 242, "restoredObjects": 243, "groundRows": 200, "groundCols": 180, "verifiedGeometryResources": factory.loads, "bundleBytes": exported.text.to_utf8_buffer().size(), "groundPatchCells": ground_edited.tile_overrides.size(), "atomicImportReady": false, "harness": "non-atomic sequential-loader negative regression; atomic importer is tested separately", "knownGapReproduced": partial_commit, "remainingContract": "Trusted owner must prepare both domains, stage object+ground+water/nav receipts, commit both documents only after all stages validate, then finalize; any rejected stage must roll back BOTH domains including clone membership and undo/redo. MapBundle is data validation only.", "scope": "Isolated native geometry + full source ground persistence. This harness deliberately omits the candidate atomic importer; see test_atomic_import.gd. Real host integration and LIVE/GPU acceptance remain pending."}))
	for item: Dictionary in [a, b, c]: item.world.queue_free()
	quit(0 if failures.is_empty() else 1)
