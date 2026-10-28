extends SceneTree
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func entry_for(descriptor: Dictionary) -> Dictionary:
	var encoded := JSON.stringify(descriptor)
	return {"bridge_id": descriptor.id, "descriptor": descriptor, "descriptor_json": encoded, "descriptor_sha256": Loader._hash(encoded.to_utf8_buffer()), "canonical_source_sha256": Loader.FEMALE_SHA if descriptor.sex == "female" else Loader.MALE_SHA, "appearance_application_count": 1, "normalization_application_count": 1, "animation_count": 0, "material_fidelity": "HOLD", "asset_sha256": "a".repeat(64), "asset_file": "a".repeat(64) + ".glb"}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var descriptor := {"id": "npc_existing_id", "sex": "female", "height": 1.75, "hairstyle": "bob"}
	var entry := entry_for(descriptor)
	check(Loader.validate_entry(entry, descriptor.id).ok, "valid exact descriptor")
	var manifest_bytes := JSON.stringify({"schema": Loader.SCHEMA, "entries": [entry]}).to_utf8_buffer()
	var manifest_sha := Loader._hash(manifest_bytes)
	check(Loader.select_entry(manifest_bytes, manifest_sha, descriptor.id, entry.descriptor_sha256).ok, "trusted manifest selection")
	check(not Loader.select_entry(manifest_bytes, "0".repeat(64), descriptor.id, entry.descriptor_sha256).ok, "manifest changed")
	check(not Loader.select_entry(manifest_bytes, manifest_sha, descriptor.id, "0".repeat(64)).ok, "stale appearance rejected")
	check(not Loader.select_entry(manifest_bytes, manifest_sha, "new_invented_id", entry.descriptor_sha256).ok, "no fabricated identity")
	var duplicate_bytes := JSON.stringify({"schema": Loader.SCHEMA, "entries": [entry, entry]}).to_utf8_buffer()
	check(not Loader.select_entry(duplicate_bytes, Loader._hash(duplicate_bytes), descriptor.id, entry.descriptor_sha256).ok, "duplicate manifest identity")
	check(Loader._hash(PackedByteArray()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "empty SHA256 without engine update error")
	var synthetic := entry.duplicate(true)
	synthetic.kind = "synthetic_fixture"
	var synthetic_bytes := JSON.stringify({"schema": Loader.SCHEMA, "entries": [synthetic]}).to_utf8_buffer()
	check(not Loader.select_entry(synthetic_bytes, Loader._hash(synthetic_bytes), descriptor.id, entry.descriptor_sha256).ok, "synthetic cannot enter production selection")
	for key in ["bridge_id", "descriptor", "descriptor_json", "descriptor_sha256", "canonical_source_sha256", "appearance_application_count", "normalization_application_count", "animation_count", "material_fidelity", "asset_sha256", "asset_file"]:
		var missing := entry.duplicate(true)
		missing.erase(key)
		check(not Loader.validate_entry(missing, descriptor.id).ok, "missing %s" % key)
	for pair in [["bridge_id", "existing_id"], ["descriptor_json", "{}"], ["descriptor_sha256", "b".repeat(64)], ["canonical_source_sha256", Loader.MALE_SHA], ["appearance_application_count", 2], ["normalization_application_count", 2], ["animation_count", 1], ["material_fidelity", "PASS"], ["asset_file", "../escape.glb"], ["asset_sha256", "A".repeat(64)]]:
		var changed := entry.duplicate(true)
		changed[pair[0]] = pair[1]
		check(not Loader.validate_entry(changed, descriptor.id).ok, "reject changed %s" % pair[0])
	check(not Loader.validate_entry(entry, "existing_id").ok, "never strip bridge prefix")
	for height in [1.0, 3.0, NAN, INF]:
		var bad_entry := entry.duplicate(true)
		bad_entry.descriptor.height = height
		check(not Loader.validate_entry(bad_entry, descriptor.id).ok, "height bound")
	check(not Loader.load_bytes(entry, descriptor.id, PackedByteArray()).ok, "empty bytes")
	check(not Loader.load_file(entry, descriptor.id, "res://missing_npc_assets").ok, "missing asset")
	var bytes := PackedByteArray()
	bytes.resize(20)
	var bad_header := entry.duplicate(true)
	bad_header.asset_sha256 = Loader._hash(bytes)
	bad_header.asset_file = bad_header.asset_sha256 + ".glb"
	check(Loader.load_bytes(bad_header, descriptor.id, bytes).get("error") == "glb_header", "validated bytes invalid GLB header")
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
		check(manifest is Dictionary and manifest.get("schema") == Loader.SCHEMA, "actual manifest schema")
		if manifest is Dictionary and manifest.get("entries") is Array:
			for row in manifest.entries:
				var result := Loader.load_file(row, row.bridge_id, arguments[0].get_base_dir())
				check(result.ok, "actual import %s: %s" % [row.bridge_id, result.get("error", "")])
				if result.ok:
					print("NPC_IMPORT ", row.bridge_id, " usec=", result.creation_usec, " phases=", result.creation_phases_usec, " bytes=", result.asset_bytes, " meshes=", result.meshes.size(), " attachments=", result.attachments.size())
					check(result.skeleton.get_bone_count() == 28, "actual canonical28")
					check(result.visual.get_parent() == null, "no scene insertion/authority")
					result.visual.free()
	print("NPC_VISUAL_LOADER checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
