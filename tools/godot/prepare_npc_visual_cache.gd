extends SceneTree
const Cache = preload("res://scripts/npc_visual/npc_visual_cache.gd")
const Loader = preload("res://scripts/npc_visual/npc_visual_loader.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Usage: -- manifest_path trusted_manifest_sha output_directory [float32]")
		quit(2)
		return
	var bytes := FileAccess.get_file_as_bytes(args[0])
	if Loader._hash(bytes) != args[1] or not Loader._valid_hash(args[1]):
		push_error("Untrusted input manifest")
		quit(2)
		return
	var source: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not source is Dictionary or source.get("schema") != Loader.SCHEMA or not source.get("entries") is Array:
		quit(2)
		return
	var manifest := {"schema": Cache.SCHEMA, "engine": Cache.engine_id(), "source_manifest_sha256": args[1], "entries": []}
	for entry in source.entries:
		if not entry is Dictionary or not entry.get("bridge_id") is String or not entry.get("descriptor_sha256") is String:
			quit(2)
			return
		var selected := Loader.select_entry(bytes, args[1], entry.bridge_id, entry.descriptor_sha256)
		if not selected.ok:
			push_error(str(selected))
			quit(2)
			return
		var receipt := Cache.prepare_entry(selected.entry, args[0].get_base_dir(), args[2], args.size() > 3 and args[3] == "float32")
		if not receipt.ok:
			push_error(str(receipt))
			quit(2)
			return
		receipt.erase("ok")
		manifest.entries.append(receipt)
	var file := FileAccess.open(args[2].path_join("manifest.json.tmp"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	# Preserve admitted descriptor numbers exactly; descriptor_json/hash are source
	# receipts and must never be rewritten to fit rounded manifest JSON.
	file.store_string(JSON.stringify(manifest, "\t", true, true) + "\n")
	file.close()
	if DirAccess.rename_absolute(args[2].path_join("manifest.json.tmp"), args[2].path_join("manifest.json")) != OK:
		quit(2)
		return
	print("PREPARED ", manifest.entries.size(), " assets manifest SHA ", FileAccess.get_sha256(args[2].path_join("manifest.json")))
	quit(0)
