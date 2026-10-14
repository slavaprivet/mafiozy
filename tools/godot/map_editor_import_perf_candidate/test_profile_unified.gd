extends SceneTree
const AuthoredFactory = preload("res://scripts/map_editor/catalog_factory.gd")
const AuthoredRegistry = preload("res://scripts/map_editor/object_registry.gd")
const ProceduralFactory = preload("res://scripts/procedural_factory.gd")
const ProceduralRegistry = preload("res://instrumented_procedural.gd")
const Composite = preload("res://instrumented_composite.gd")
const Controller = preload("res://instrumented_controller.gd")
const Store = preload("res://scripts/map_editor/map_store.gd")
const Trusted = preload("res://scripts/map_editor/trusted_json.gd")
var checks := 0
var failures: Array[String] = []
var catalog: Dictionary
var assets: RefCounted
func extra_owners(_world: Node3D) -> Array: return []
func extra_templates(_session: Dictionary) -> Array: return []
func baseline_count() -> int: return 9636
func clone_count() -> int: return 2
func dispose_extras(_session: Dictionary) -> void: pass
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func owner(_request: Dictionary) -> Dictionary:
	# Explicit test fixture; real collider/traffic/nav authority NOT admitted.
	return {"approved": true, "commit": func(): return true, "rollback": func(): pass}
func enter() -> Dictionary: return {"ok": true}
func leave(_doc: Dictionary) -> Dictionary: return {"ok": true}
func make_session() -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var authored := AuthoredRegistry.new()
	var house := ""
	for row: Dictionary in catalog.objects:
		if not row.has("resourceId"): continue
		var built: Dictionary = assets.spawn_key(row.key, {"exterior_collisions": true})
		check(built.get("ok", false), "actual authored spawn " + str(row.key))
		if not built.get("ok", false): continue
		world.add_child(built.root)
		check(authored.register_object(row.key, built.root, {"kind": str(row.dataset), "model": str(row.resourceId), "source": row.sourceRecord.duplicate(true)}, [], built.pending.is_empty()).ok, "actual authored ID " + str(row.key))
		if house.is_empty() and row.assetId == "old_town_narrow_townhouse_v1" and built.pending.is_empty(): house = row.key
	var procedural_factory := ProceduralFactory.new()
	var admitted: bool = procedural_factory.configure("82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd")
	check(admitted, "original procedural source admission: " + str(procedural_factory.errors))
	if not admitted:
		world.free()
		return {"ok": false}
	var exploration: Dictionary = procedural_factory.build_exploration()
	var roads: Dictionary = procedural_factory.build_roads()
	check(exploration.ok and roads.ok, "actual forest/monuments/road geometry")
	if not exploration.ok or not roads.ok:
		world.free()
		return {"ok": false}
	world.add_child(exploration.root)
	world.add_child(roads.root)
	var procedural := ProceduralRegistry.new()
	check(procedural.configure(procedural_factory, owner).ok, "procedural identity registry")
	var composite := Composite.new()
	var owners: Array = [{"owner_id": "authored", "registry": authored}, {"owner_id": "procedural", "registry": procedural}]
	owners.append_array(extra_owners(world))
	check(composite.configure(owners, "unified-map-qa").ok, "one explicit composite owner")
	check(composite.ids().size() == baseline_count(), "all baseline IDs retained")
	var camera := Camera3D.new()
	world.add_child(camera)
	var controller := Controller.new()
	world.add_child(controller)
	check(controller.setup(composite, composite.source_document("unified-map-qa"), camera, enter, leave).ok, "actual single controller model")
	check(controller.enter_editor().ok, "test-only editor lease")
	return {"ok": true, "world": world, "authored": authored, "procedural": procedural, "factory": procedural_factory, "composite": composite, "controller": controller, "house": house, "owners": owners}
func run() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	assets = AuthoredFactory.new()
	check(assets.configure(catalog), "actual original GLBs")
	var source := make_session()
	if not source.ok:
		for error in failures: push_error(error)
		quit(1)
		return
	var templates: Array = [source.house, "explore-pine-239"]
	templates.append_array(extra_templates(source))
	for id: String in templates:
		source.controller.selected_id = id
		var moved: Dictionary = source.controller.handle_action("move", {"delta": [2, 0, 1]})
		check(moved.ok, "one UI moves owner " + id + ": " + str(moved.get("error", "")))
		check(source.controller.handle_action("undo").ok and source.controller.handle_action("redo").ok, "same history spans owner " + id)
		var added: Dictionary = source.controller.handle_action("add", {"catalog_id": id})
		check(added.ok, "actual trusted owner copy " + id + ": " + str(added.get("error", "")))
	check(source.composite.ids().size() == baseline_count()+clone_count(), "all owner copies in one identity index")
	var expected: Dictionary = source.controller.document.to_dictionary()
	var path := "user://maps/tests/unified-%d.json" % Time.get_ticks_usec()
	check(Store.save_document(source.controller.document, path).ok, "actual combined object file")
	var loaded: Dictionary = Store.load_document(path)
	check(loaded.ok, "actual saved bytes verified")
	dispose_extras(source)
	source.world.free()
	var fresh := make_session()
	if not fresh.ok:
		for error in failures: push_error(error)
		quit(1)
		return
	var started := Time.get_ticks_usec()
	var result: Dictionary = fresh.controller.install_document(loaded.document)
	var install_elapsed := Time.get_ticks_usec() - started
	var verification_started := Time.get_ticks_usec()
	check(result.ok, "fresh mixed-owner install: " + str(result.get("error", "")))
	check(fresh.composite.ids().size() == baseline_count()+clone_count(), "fresh factory reconstructs all trusted copies")
	var current: Dictionary = fresh.controller.document.to_dictionary()
	var wanted := {}
	for row: Dictionary in expected.objects: wanted[row.id] = row
	check(current.objects.size() == expected.objects.size(), "all saved record identities restored")
	for row: Dictionary in current.objects:
		check(wanted.has(row.id), "saved identity present " + str(row.id))
		if not wanted.has(row.id): continue
		var trusted: Dictionary = wanted[row.id].duplicate(true)
		var supplied: Dictionary = row.duplicate(true)
		trusted.erase("transform")
		supplied.erase("transform")
		check(Trusted.matches(trusted, supplied), "trusted opaque record restored " + str(row.id))
		var a: Transform3D = Composite.decode_transform(wanted[row.id].transform)
		var b: Transform3D = Composite.decode_transform(row.transform)
		# Editable vectors transport through JSON doubles but render/physics
		# frames are native float32: require exact bytes, not a visual epsilon.
		check(PackedFloat32Array([a.origin.x,a.origin.y,a.origin.z,a.basis.x.x,a.basis.x.y,a.basis.x.z,a.basis.y.x,a.basis.y.y,a.basis.y.z,a.basis.z.x,a.basis.z.y,a.basis.z.z]).to_byte_array() == PackedFloat32Array([b.origin.x,b.origin.y,b.origin.z,b.basis.x.x,b.basis.x.y,b.basis.x.z,b.basis.y.x,b.basis.y.y,b.basis.y.z,b.basis.z.x,b.basis.z.y,b.basis.z.z]).to_byte_array(), "exact native saved frame " + str(row.id))
	check(not fresh.composite.busy_status().busy, "no retained mixed-owner transaction")
	var verification_elapsed := Time.get_ticks_usec() - verification_started
	dispose_extras(fresh)
	fresh.world.free()
	for suffix in ["", ".bak", ".tmp"]:
		var file := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	for error in failures: push_error(error)
	print(JSON.stringify({"suite": "actual-unified-registry", "checks": checks, "failures": failures, "sourceObjects": baseline_count(), "freshObjects": baseline_count()+clone_count(), "installCpuUsec": install_elapsed, "verificationCpuUsec": verification_elapsed, "gpu": false, "productionWired": false, "ownerCallbacks": "test fixtures"}))
	print("IMPORT_PHASE_TIMINGS "+JSON.stringify(preload("res://timing.gd").entries))
	quit(0 if failures.is_empty() else 1)
