extends RefCounted
## Bounded lazy cache: immutable meshes/materials are shared, instance nodes private.
const IDS := ["none", "nagan", "tt_pistol", "revolver", "deagle", "golden_colt", "sawn_off", "shotgun", "uzi", "golden_uzi", "ak74", "m16", "tommy_gun", "sniper", "rpg"]
var _entries: Dictionary = {}
var _scenes: Dictionary = {}
var _directory := ""

func open(path: String = "res://assets/weapon_visual/manifest.json", trusted_sha256: String = "") -> Dictionary:
	if not _entries.is_empty():
		return {"ok": false, "error": "already_open"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2097152:
		return {"ok": false, "error": "manifest"}
	if not trusted_sha256.is_empty() and FileAccess.get_sha256(path) != trusted_sha256:
		return {"ok": false, "error": "manifest_hash"}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("schema") != "mafiozi.weapon-native/v1" or not data.get("entries") is Array or data.entries.size() != IDS.size():
		return {"ok": false, "error": "schema"}
	var candidate: Dictionary = {}
	for i: int in IDS.size():
		var entry: Variant = data.entries[i]
		if not entry is Dictionary or entry.get("id") != IDS[i] or entry.get("file") != IDS[i] + ".scn" or not entry.get("sha256") is String or entry.sha256.length() != 64:
			return {"ok": false, "error": "entry"}
		if not (entry.get("bytes") is float or entry.get("bytes") is int) or entry.bytes < 20 or entry.bytes > 16777216 or not entry.get("profile") is Dictionary or entry.profile.get("id") != IDS[i]:
			return {"ok": false, "error": "entry_size_or_profile"}
		candidate[IDS[i]] = entry.duplicate(true)
	_entries = candidate
	_directory = path.get_base_dir()
	return {"ok": true, "count": IDS.size()}

func instantiate_weapon(id: String) -> Dictionary:
	if not _entries.has(id):
		return {"ok": false, "error": "unknown_weapon"}
	if not _scenes.has(id):
		var entry: Dictionary = _entries[id]
		var path := _directory.path_join(entry.file)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() != int(entry.bytes) or file.get_length() > 16777216 or FileAccess.get_sha256(path) != entry.sha256:
			return {"ok": false, "error": "asset_hash_or_size"}
		var scene := ResourceLoader.load(path, "PackedScene") as PackedScene
		if scene == null:
			return {"ok": false, "error": "scene"}
		_scenes[id] = scene
	var visual: Node3D = _scenes[id].instantiate()
	if visual == null or not visual.has_method("shot_transform") or visual.get_meta("weapon_profile", {}).get("id") != id:
		if visual != null: visual.free()
		return {"ok": false, "error": "visual_contract"}
	return {"ok": true, "visual": visual}

func retained_count() -> int:
	return _scenes.size()

func get_entry(id: String) -> Dictionary:
	# Contains source-rest bounds/profile without forcing a resource load.
	return _entries.get(id, {}).duplicate(true)

func close() -> void:
	_scenes.clear()
	_entries.clear()
	_directory = ""
