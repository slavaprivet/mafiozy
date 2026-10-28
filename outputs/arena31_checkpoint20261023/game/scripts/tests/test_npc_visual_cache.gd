extends SceneTree
const Cache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
const Bridge = preload("res://scripts/npc_visual/npc_float_color_bridge.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path := "res://assets/npc_visual/catalogue_manifest.json"
	var source_bytes := FileAccess.get_file_as_bytes(path)
	var source: Dictionary = JSON.parse_string(source_bytes.get_string_from_utf8())
	var entry: Dictionary = source.entries[0]
	var directory := "res://assets/npc_visual/prepared/cache_test"
	var receipt := Cache.prepare_entry(entry, path.get_base_dir(), directory, true)
	check(receipt.ok, "actual GLB offline float bridge packing")
	if not receipt.ok:
		print(receipt)
		quit(1)
		return
	var manifest := {"schema": Cache.SCHEMA, "engine": Cache.engine_id(), "source_manifest_sha256": Loader._hash(source_bytes), "entries": [receipt]}
	var bytes := JSON.stringify(manifest).to_utf8_buffer()
	var fingerprint := Loader._hash(bytes)
	var loaded := Cache.load_verified(bytes, fingerprint, entry.bridge_id, entry.descriptor_sha256, directory)
	check(loaded.ok, "native serialized scene load")
	if not loaded.ok:
		print(loaded)
		quit(1)
		return
	var cache: RefCounted = loaded.cache
	var a: Dictionary = cache.instantiate_actor()
	var b: Dictionary = cache.instantiate_actor()
	a.visual.get_meta("npc_descriptor")["cache_test_nested"] = {"value": [1, 2]}
	a.descriptor["height"] = 99
	check(not b.visual.get_meta("npc_descriptor").has("cache_test_nested") and b.descriptor.height == entry.descriptor.height, "descriptor metadata/result private")
	var extras_a: Dictionary = a.meshes[0].get_meta("extras", {})
	var extras_b: Dictionary = b.meshes[0].get_meta("extras", {})
	extras_a["cache_test_nested"] = {"mutable": [99]}
	check(not extras_b.has("cache_test_nested"), "mesh extras metadata private")
	var original := Loader.load_file(entry, entry.bridge_id, path.get_base_dir())
	var original_plan := Bridge.prepare(original.visual, FileAccess.get_file_as_bytes(path.get_base_dir().path_join(entry.asset_file)), entry.asset_sha256)
	check(original_plan.ok and Bridge.apply(original_plan).ok, "independent source bridge baseline")
	var by_name := {}
	for mesh: MeshInstance3D in original.meshes:
		by_name[mesh.get_meta("extras", {}).npc_visual_source_mesh_key] = mesh
	for mesh: MeshInstance3D in a.meshes:
		var before: MeshInstance3D = by_name[mesh.get_meta("extras", {}).npc_visual_source_mesh_key]
		for surface in mesh.mesh.get_surface_count():
			check(mesh.mesh.surface_get_arrays(surface) == before.mesh.surface_get_arrays(surface), "native serialization preserves ALL surface arrays")
			var after_material: StandardMaterial3D = mesh.mesh.surface_get_material(surface)
			var before_material: StandardMaterial3D = before.mesh.surface_get_material(surface)
			check(after_material.vertex_color_use_as_albedo == before_material.vertex_color_use_as_albedo and not after_material.vertex_color_is_srgb and after_material.albedo_color == before_material.albedo_color and after_material.roughness == before_material.roughness, "native serialization preserves source material flags")
	original.visual.free()
	# Explicit mutable shadow ownership fixture, derived from the admitted source.
	var shadow_source: ArrayMesh = a.meshes[0].mesh.duplicate(true)
	shadow_source.shadow_mesh = b.meshes[0].mesh.duplicate(true)
	var shadow_a := Cache._localize_mesh(shadow_source)
	var shadow_b := Cache._localize_mesh(shadow_source)
	check(shadow_a.shadow_mesh != shadow_b.shadow_mesh and shadow_a.shadow_mesh != shadow_source.shadow_mesh, "private shadow meshes")
	shadow_a.shadow_mesh.clear_surfaces()
	check(shadow_b.shadow_mesh.get_surface_count() > 0 and shadow_source.shadow_mesh.get_surface_count() > 0, "shadow mutation isolation")
	var shadow_fixture: Dictionary = cache.instantiate_actor()
	shadow_fixture.meshes[0].mesh.shadow_mesh = shadow_source
	var shadow_scene := PackedScene.new()
	check(shadow_scene.pack(shadow_fixture.visual) == OK, "pack source-derived shadow ownership fixture")
	shadow_fixture.visual.free()
	var shadow_path := directory.path_join("shadow_fixture.scn")
	check(ResourceSaver.save(shadow_scene, shadow_path) == OK, "serialize native shadow fixture")
	var shadow_loaded := ResourceLoader.load(shadow_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var shadow_one := shadow_loaded.instantiate()
	var shadow_two := shadow_loaded.instantiate()
	Cache._own_resources(shadow_one)
	Cache._own_resources(shadow_two)
	var shadow_one_mesh: MeshInstance3D
	var shadow_two_mesh: MeshInstance3D
	for node in shadow_one.find_children("*", "MeshInstance3D", true, false):
		if node.mesh.shadow_mesh != null:
			shadow_one_mesh = node
	for node in shadow_two.find_children("*", "MeshInstance3D", true, false):
		if node.mesh.shadow_mesh != null:
			shadow_two_mesh = node
	check(shadow_one_mesh != null and shadow_two_mesh != null and shadow_one_mesh.mesh.shadow_mesh != shadow_two_mesh.mesh.shadow_mesh, "serialized shadow resources private")
	shadow_one_mesh.mesh.shadow_mesh.clear_surfaces()
	check(shadow_two_mesh.mesh.shadow_mesh.get_surface_count() > 0, "serialized shadow mutation isolation")
	shadow_one.free()
	shadow_two.free()
	check(a.ok and b.ok, "two actors instantiated")
	check(a.skeleton != b.skeleton, "private skeleton")
	check(a.visual.get_parent() == null and b.visual.get_parent() == null, "no world insertion")
	check(not a.shader_bound and not b.shader_bound, "shader OFF")
	for index in a.meshes.size():
		var am: MeshInstance3D = a.meshes[index]
		var bm: MeshInstance3D = b.meshes[index]
		check(am.mesh != bm.mesh, "private mesh")
		check(am.mesh.resource_local_to_scene, "mesh local-to-scene")
		if am.skin != null:
			check(am.skin != bm.skin, "private Skin")
			var old_pose := bm.skin.get_bind_pose(0)
			am.skin.set_bind_pose(0, Transform3D(Basis.IDENTITY, Vector3.ONE))
			check(bm.skin.get_bind_pose(0) == old_pose, "Skin mutation isolation")
		for surface in am.mesh.get_surface_count():
			var ma: Material = am.mesh.surface_get_material(surface)
			var mb: Material = bm.mesh.surface_get_material(surface)
			check(ma != mb and ma is StandardMaterial3D, "private shader-free material")
			var old_color: Color = mb.albedo_color
			ma.albedo_color = Color.RED
			check(mb.albedo_color == old_color, "material mutation isolation")
			var aa := am.mesh.surface_get_arrays(surface)
			var ba := bm.mesh.surface_get_arrays(surface)
			check(aa[Mesh.ARRAY_VERTEX] == ba[Mesh.ARRAY_VERTEX], "serialized vertices")
			check(aa[Mesh.ARRAY_COLOR] == ba[Mesh.ARRAY_COLOR], "serialized colors")
			check(aa[Mesh.ARRAY_CUSTOM0] == ba[Mesh.ARRAY_CUSTOM0], "serialized Float32 CUSTOM0")
	var b_pose: Vector3 = b.skeleton.get_bone_pose_position(0)
	a.skeleton.set_bone_pose_position(0, Vector3.ONE)
	check(b.skeleton.get_bone_pose_position(0) == b_pose, "pose isolation")
	a.meshes[0].mesh.clear_surfaces()
	check(b.meshes[0].mesh.get_surface_count() > 0, "geometry mutation isolation")
	a.visual.free()
	var c: Dictionary = cache.instantiate_actor()
	check(c.ok and c.meshes[0].mesh.get_surface_count() > 0 and c.skeleton.get_bone_pose_position(0) == b_pose, "cache survived actor mutation/free")
	check(not c.visual.get_meta("npc_descriptor").has("cache_test_nested") and not c.meshes[0].get_meta("extras", {}).has("cache_test_nested") and c.descriptor.height == entry.descriptor.height, "cache metadata survived mutation")
	check(not Cache.load_verified(bytes, "0".repeat(64), entry.bridge_id, entry.descriptor_sha256, directory).ok, "stale manifest hash")
	check(not Cache.load_verified(bytes, fingerprint, "stale_id", entry.descriptor_sha256, directory).ok, "stale bridge ID")
	check(not Cache.load_verified(bytes, fingerprint, entry.bridge_id, "0".repeat(64), directory).ok, "stale descriptor")
	for key in ["prepared_sha256", "engine", "bridge_version", "shader_bound", "loader_sha256", "bridge_sha256"]:
		var changed := manifest.duplicate(true)
		changed.entries[0][key] = "0".repeat(64) if key == "prepared_sha256" else (true if key == "shader_bound" else "stale")
		var changed_bytes := JSON.stringify(changed).to_utf8_buffer()
		check(not Cache.load_verified(changed_bytes, Loader._hash(changed_bytes), entry.bridge_id, entry.descriptor_sha256, directory).ok, "reject " + key)
	# Malformed JSON types must return explicit failure, never abort to empty {}.
	for section in ["manifest", "receipt", "entry", "descriptor"]:
		var fields: Array
		match section:
			"manifest": fields = ["schema", "engine", "source_manifest_sha256", "entries"]
			"receipt": fields = ["engine", "bridge_version", "loader_sha256", "bridge_sha256", "prepared_sha256", "prepared_file", "shader_bound", "float_bridge"]
			"entry": fields = ["bridge_id", "descriptor_json", "descriptor_sha256", "canonical_source_sha256", "asset_sha256", "asset_file", "material_fidelity", "appearance_application_count", "normalization_application_count", "animation_count"]
			"descriptor": fields = ["id", "sex"]
		for field in fields:
			for malformed in [{}, [], null]:
				var typed_case := manifest.duplicate(true)
				match section:
					"manifest": typed_case[field] = malformed
					"receipt": typed_case.entries[0][field] = malformed
					"entry": typed_case.entries[0].entry[field] = malformed
					"descriptor": typed_case.entries[0].entry.descriptor[field] = malformed
				var typed_bytes := JSON.stringify(typed_case).to_utf8_buffer()
				var typed_result := Cache.load_verified(typed_bytes, Loader._hash(typed_bytes), entry.bridge_id, entry.descriptor_sha256, directory)
				check(typed_result.has("ok") and typed_result.ok == false and typed_result.has("error"), "explicit typed rejection " + section + "." + field)
	var array_encoded := manifest.duplicate(true)
	array_encoded.entries[0].entry.descriptor_json = "[]"
	var array_encoded_bytes := JSON.stringify(array_encoded).to_utf8_buffer()
	var array_encoded_result := Cache.load_verified(array_encoded_bytes, Loader._hash(array_encoded_bytes), entry.bridge_id, entry.descriptor_sha256, directory)
	check(array_encoded_result.has("ok") and array_encoded_result.ok == false, "descriptor JSON array rejected explicitly")
	var corrupt := manifest.duplicate(true)
	corrupt.entries[0].prepared_sha256 = "0".repeat(64)
	corrupt.entries[0].prepared_file = "0".repeat(64) + ".scn"
	var corrupt_bytes := JSON.stringify(corrupt).to_utf8_buffer()
	check(not Cache.load_verified(corrupt_bytes, Loader._hash(corrupt_bytes), entry.bridge_id, entry.descriptor_sha256, directory).ok, "scene bytes fingerprint rejection")
	var plain := Cache.prepare_entry(entry, path.get_base_dir(), directory)
	check(plain.ok and not plain.float_bridge and not plain.shader_bound, "default no bridge no shader")
	var plain_manifest := manifest.duplicate(true)
	plain_manifest.entries = [plain]
	var plain_bytes := JSON.stringify(plain_manifest).to_utf8_buffer()
	var plain_loaded := Cache.load_verified(plain_bytes, Loader._hash(plain_bytes), entry.bridge_id, entry.descriptor_sha256, directory)
	check(plain_loaded.ok, "default prepared native load")
	var plain_actor: Dictionary = plain_loaded.cache.instantiate_actor()
	check(plain_actor.ok and not plain_actor.shader_bound and plain_actor.meshes[0].material_override == null, "default shader remains OFF")
	plain_actor.visual.free()
	plain_loaded.cache.dispose()
	var warm: Array = []
	var cold: Array = []
	var glb_cold: Array = []
	for sample in 20:
		var started := Time.get_ticks_usec()
		var actor: Dictionary = cache.instantiate_actor()
		warm.append(Time.get_ticks_usec() - started)
		actor.visual.free()
		started = Time.get_ticks_usec()
		var fresh := Cache.load_verified(bytes, fingerprint, entry.bridge_id, entry.descriptor_sha256, directory)
		cold.append(Time.get_ticks_usec() - started)
		check(fresh.ok, "cold sample load")
		fresh.cache.dispose()
		started = Time.get_ticks_usec()
		var parsed := Loader.load_file(entry, entry.bridge_id, path.get_base_dir())
		glb_cold.append(Time.get_ticks_usec() - started)
		check(parsed.ok, "source GLB cold sample")
		parsed.visual.free()
	cache.dispose()
	check(not cache.instantiate_actor().ok and b.visual != null, "dispose cache does not free actors")
	b.visual.free()
	c.visual.free()
	var report := {"checks": checks, "failures": failures, "cold_load_usec": cold, "cold_glb_loader_usec": glb_cold, "warm_instantiate_usec": warm, "loader_sha256": FileAccess.get_sha256(Cache.LOADER_PATH), "bridge_sha256": FileAccess.get_sha256(Cache.BRIDGE_PATH), "scope": "catalogue-only CPU loading; no live birth, no FPS"}
	var prepared_dir := "res://assets/npc_visual/prepared"
	var all_bytes := FileAccess.get_file_as_bytes(prepared_dir.path_join("manifest.json"))
	var prepared: Dictionary = JSON.parse_string(all_bytes.get_string_from_utf8())
	for item in prepared.entries:
		var item_cache := Cache.load_verified(all_bytes, Loader._hash(all_bytes), item.entry.bridge_id, item.entry.descriptor_sha256, prepared_dir)
		check(item_cache.ok, "catalogue prepared entry verified")
		if item_cache.ok:
			var model: Dictionary = item_cache.cache.instantiate_actor()
			check(model.ok and model.visual.get_parent() == null and not model.shader_bound, "catalogue private native actor")
			model.visual.free()
			item_cache.cache.dispose()
	report.checks = checks
	report.failures = failures
	report.prepared_catalogue_entries = prepared.entries.size()
	var report_directory := ProjectSettings.globalize_path("res://").path_join("../../outputs/astra21_npc_visual_cache").simplify_path()
	DirAccess.make_dir_recursive_absolute(report_directory)
	var out := FileAccess.open(report_directory.path_join("test_results.json"), FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures == 0 else 1)
