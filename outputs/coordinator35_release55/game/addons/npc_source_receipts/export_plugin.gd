@tool
extends EditorExportPlugin
## Add raw receipt bytes beside ordinary compiled scripts/remaps. Never replace
## compilation or weaken runtime cache admission. Updating either source needs
## a reviewed prepared manifest and an explicit pin update together.
const SOURCES := {
	"res://scripts/npc_visual/npc_visual_loader.gd": "6e8f9c0c5e55ed0b18cdd590ad4e30141108fd73b96a93a078a70b16763bac54",
	"res://scripts/npc_visual/npc_float_color_bridge.gd": "bb4932772bfaae737b1e5d4d1485711060055c7de9c685918b3bd2f35b375662",
}
const MAX_SOURCE_BYTES := 262144

func _get_name() -> String:
	return "MafioziNpcSourceReceipts"

static func validated_sources() -> Dictionary:
	var files := {}
	for path: String in SOURCES:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"ok": false, "error": "missing:" + path}
		var size := file.get_length()
		if size <= 0 or size > MAX_SOURCE_BYTES:
			return {"ok": false, "error": "size:" + path}
		var bytes := file.get_buffer(size)
		file.close()
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		if bytes.size() != size or hash.finish().hex_encode() != SOURCES[path]:
			return {"ok": false, "error": "source_sha256:" + path}
		files[path] = bytes
	return {"ok": true, "files": files}

func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	# Validate both before adding either. The same captured bytes are exported,
	# avoiding a second read between checksum validation and add_file.
	var result := validated_sources()
	if not result.ok:
		# This callback has no cancellation return. Do not claim that push_error
		# aborts the exporter: the release pipeline must reject its failed PCK gate.
		push_error("NPC source receipts rejected: " + str(result.error))
		return
	for path: String in SOURCES:
		add_file(path, result.files[path], false)
