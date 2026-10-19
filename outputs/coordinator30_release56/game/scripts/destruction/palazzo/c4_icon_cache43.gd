extends RefCounted
## Two baked images of C4Visuals.make_device. No runtime camera or viewport.
const PATHS := ["res://scripts/destruction/palazzo/icons/c4_package43.png", "res://scripts/destruction/palazzo/icons/c4_remote43.png"]
static var _attempted := [false, false]
static var _textures: Array[Texture2D] = [null, null]
static var _loads := 0

static func texture_for(remote: bool) -> Texture2D:
	var index: int = 1 if remote else 0
	if not _attempted[index]:
		_attempted[index] = true
		if ResourceLoader.exists(PATHS[index], "Texture2D"):
			_textures[index] = load(PATHS[index]) as Texture2D
			_loads += 1
	return _textures[index]

static func snapshot() -> Dictionary:
	return {"ready":_textures[0] != null and _textures[1] != null, "cached_textures":int(_textures[0] != null) + int(_textures[1] != null), "load_count":_loads, "maximum_cached_textures":2, "runtime_viewports":0, "source":"one-time render of C4Visuals.make_device", "assets":PATHS}
