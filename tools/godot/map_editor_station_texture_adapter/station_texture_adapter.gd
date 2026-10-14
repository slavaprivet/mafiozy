extends RefCounted
## Source-bound station textures only. Never loads files/scripts or changes a scene.
## Base pixels are exact; CPU linear-light mip candidate needs owner GPU parity review.
const ALGORITHM := "native-float32-linear-srgb-mip-v1"
const MAX_CACHE := 8
var _source_sha := ""
var _sources: Dictionary = {}
var _source_keys: Dictionary = {}
var _approved_pixels: Dictionary = {}
var _cache: Dictionary = {}
var _materials: Dictionary = {}
var _decode := PackedFloat32Array()
var cold_builds := 0
var cache_hits := 0
var invalidations := 0

static func _fail(message: String) -> Dictionary: return {"ok": false, "error": message}
static func sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
static func _valid_sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if character not in "0123456789abcdef": return false
	return true
static func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var items := PackedStringArray()
		for key in keys: items.append(JSON.stringify(str(key)) + ":" + _canonical(value[key]))
		return "{" + ",".join(items) + "}"
	if value is Array:
		var items := PackedStringArray()
		for item in value: items.append(_canonical(item))
		return "[" + ",".join(items) + "]"
	return JSON.stringify(value)
static func _pair(value: Variant, x: float, y: float) -> bool:
	return value is Array and value.size() == 2 and typeof(value[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(value[1]) in [TYPE_INT, TYPE_FLOAT] and value[0] == x and value[1] == y
static func _source_supported(source: Dictionary) -> bool:
	return source.get("colorSpace") == "srgb" and source.get("flipY") == true and source.get("generateMipmaps") == true and source.get("premultiplyAlpha") == false and source.get("minFilter") == 1008 and source.get("magFilter") == 1006 and source.get("wrapS") == 1001 and source.get("wrapT") == 1001 and source.get("anisotropy") == 1 and _pair(source.get("repeat"), 1, 1) and _pair(source.get("offset"), 0, 0) and _pair(source.get("center"), 0, 0) and source.get("rotation") == 0 and source.get("image", {}).get("width") == 1024 and source.get("image", {}).get("height") == 192

func configure(expected_source_sha: String, textures: Array, trusted_pixel_hashes: Dictionary) -> Dictionary:
	if not _valid_sha(expected_source_sha) or textures.size() != 2 or trusted_pixel_hashes.size() != 2: return _fail("Trusted exact two-label source/capture admission required")
	var next := {}
	for source in textures:
		if not source is Dictionary or not source.get("id") is String or next.has(source.id) or not _source_supported(source) or not _valid_sha(trusted_pixel_hashes.get(source.id)): return _fail("Unsupported original sampler or missing approved pixel SHA")
		next[source.id] = source.duplicate(true)
	_source_sha = expected_source_sha
	_sources = next
	_approved_pixels = trusted_pixel_hashes.duplicate()
	_source_keys.clear()
	for id in next: _source_keys[id] = sha(_canonical(next[id]).to_utf8_buffer())
	_cache.clear()
	_materials.clear()
	_decode.resize(256)
	for index in 256:
		var value := float(index) / 255.0
		_decode[index] = value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
	return {"ok": true}

static func level_layout(width: int, height: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var offset := 0
	while true:
		var count := width * height * 4
		result.append({"width": width, "height": height, "offset": offset, "bytes": count})
		offset += count
		if width == 1 and height == 1: break
		width = maxi(1, width >> 1)
		height = maxi(1, height >> 1)
	return result

static func _encode(value: float) -> int:
	value = clampf(value, 0.0, 1.0)
	var encoded := value * 12.92 if value <= 0.0031308 else 1.055 * pow(value, 1.0 / 2.4) - 0.055
	return clampi(roundi(encoded * 255.0), 0, 255)

func _cpu_chain(base: PackedByteArray, width: int, height: int) -> PackedByteArray:
	# Decode only a temporary filtering workspace, never rewrite base sRGB pixels.
	# Generate mipmaps in linear light; filtering sRGB bytes would darken text edges.
	var floats := PackedFloat32Array()
	floats.resize(base.size())
	for index in range(0, base.size(), 4):
		for channel in 3: floats[index + channel] = _decode[base[index + channel]]
		floats[index + 3] = float(base[index + 3]) / 255.0
	var workspace := Image.create_from_data(width, height, false, Image.FORMAT_RGBAF, floats.to_byte_array())
	if workspace.generate_mipmaps(false) != OK: return PackedByteArray()
	var generated := workspace.get_data().to_float32_array()
	var result := base.duplicate()
	result.resize(generated.size())
	for index in range(base.size(), generated.size(), 4):
		for channel in 3: result[index + channel] = _encode(generated[index + channel])
		result[index + 3] = clampi(roundi(generated[index + 3] * 255.0), 0, 255)
	return result

func _invalidate(key: String) -> void:
	if _cache.erase(key): invalidations += 1
	_materials.clear()

func prepare_capture(row: Dictionary, raw_srgb_rgba: PackedByteArray) -> Dictionary:
	if _source_sha.is_empty() or not _sources.has(row.get("texture_id")): return _fail("Unknown source label")
	var source: Dictionary = _sources[row.texture_id]
	if row.get("sourceTexture") != source or row.get("recipe") != source.image.recipe or row.get("width") != 1024 or row.get("height") != 192 or row.get("font") != "600 66px Arial" or row.get("repeatMatch") != true: return _fail("Capture recipe/source/size proof differs")
	var fonts: Variant = row.get("platformFonts")
	if not fonts is Array or fonts.size() != 1 or fonts[0].get("familyName") != "Arial" or fonts[0].get("postScriptName") != "Arial-BoldMT" or fonts[0].get("isCustomFont") != false: return _fail("Original Arial Bold capture proof required")
	if raw_srgb_rgba.size() != 1024 * 192 * 4 or row.get("rgba_sha256") != _approved_pixels[row.texture_id] or sha(raw_srgb_rgba) != row.rgba_sha256: return _fail("Approved source RGBA hash mismatch")
	var key: String = _source_sha + ":" + row.rgba_sha256 + ":" + _source_keys[row.texture_id] + ":" + ALGORITHM
	if _cache.has(key):
		cache_hits += 1
		return _result(row, _cache[key], key)
	# Content-hashed cache hits already passed this alpha validation once.
	for index in range(3, raw_srgb_rgba.size(), 4):
		if raw_srgb_rgba[index] != 255: return _fail("Source opaque station canvas alpha altered")
	var image := Image.create_from_data(1024, 192, false, Image.FORMAT_RGBA8, raw_srgb_rgba)
	image.flip_y() # One row flip only, source PlaneGeometry UVs stay unchanged.
	var base := image.get_data()
	var bytes := _cpu_chain(base, 1024, 192)
	var levels := level_layout(1024, 192)
	var expected_size: int = levels.back().offset + levels.back().bytes
	if bytes.size() != expected_size: return _fail("Native complete mip chain generation failed")
	var mip_image := Image.create_from_data(1024, 192, true, Image.FORMAT_RGBA8, bytes)
	var texture := ImageTexture.create_from_image(mip_image)
	texture.set_meta("source_srgb_sha256", row.rgba_sha256)
	texture.set_meta("source_manifest_sha256", _source_sha)
	texture.set_meta("mip_algorithm", ALGORITHM)
	texture.set_meta("gpu_parity", "HOLD-original-driver-mipmap/sampler-review")
	if _cache.size() >= MAX_CACHE: _cache.erase(_cache.keys()[0])
	var entry := {"texture": texture, "levels": levels, "native_sha256": sha(bytes), "base_sha256": sha(base), "bytes": bytes.size()}
	_cache[key] = entry
	texture.changed.connect(_invalidate.bind(key))
	cold_builds += 1
	return _result(row, entry, key)

func _result(row: Dictionary, entry: Dictionary, key: String) -> Dictionary:
	return {"ok": true, "cache_key": key, "texture": entry.texture, "levels": entry.levels.duplicate(true), "bytes": entry.bytes, "source_srgb_sha256": row.rgba_sha256, "native_sha256": entry.native_sha256, "flipped_base_sha256": entry.base_sha256, "capture_record": {"texture_id": row.texture_id, "texture": entry.texture, "recipe": row.recipe.duplicate(true), "capture_sha256": entry.native_sha256, "live_capture_verified": true}, "filtering": {"min": "linear-mipmap-linear", "mag": "linear", "wrap": "clamp-to-edge", "anisotropy": 1}, "status": "CPU-candidate-original-GPU-mipmap-parity-HOLD"}

func material_with_sampler(original: StandardMaterial3D, prepared: Dictionary) -> Dictionary:
	if original == null or not prepared.get("ok", false) or not _cache.has(prepared.get("cache_key")) or prepared.get("texture") != _cache[prepared.cache_key].texture: return _fail("Owned prepared texture required")
	var key: String = str(original.get_instance_id()) + ":" + prepared.cache_key
	if _materials.has(key): return {"ok": true, "material": _materials[key]}
	var material: StandardMaterial3D = original.duplicate()
	material.albedo_texture = prepared.texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.texture_repeat = false
	# Albedo/emission values and all source PBR flags remain unchanged.
	if _materials.size() >= 16: _materials.erase(_materials.keys()[0])
	_materials[key] = material
	var invalidate := _invalidate_material.bind(key)
	if not original.changed.is_connected(invalidate): original.changed.connect(invalidate)
	return {"ok": true, "material": material}

func _invalidate_material(key: String) -> void:
	_materials.erase(key)

func consumer_gate(request: Dictionary, receipt: Dictionary, raw_by_id: Dictionary, visual_owner_admission: Callable = Callable()) -> Dictionary:
	if request.get("source_manifest_sha256") != _source_sha or receipt.get("source_manifest_sha256") != _source_sha or not receipt.get("captures") is Array: return _fail("Capture receipt source identity mismatch")
	var prepared: Array[Dictionary] = []
	var seen := {}
	for row in receipt.captures:
		if not row is Dictionary or seen.has(row.get("texture_id")) or not raw_by_id.get(row.get("texture_id")) is PackedByteArray: return _fail("Missing or duplicate source capture")
		var candidate := prepare_capture(row, raw_by_id[row.texture_id])
		if not candidate.ok: return candidate
		prepared.append(candidate)
		seen[row.texture_id] = true
	if seen.size() != _sources.size(): return _fail("Missing original station label")
	# Never silently declare CPU mipmap filtering byte-equal to original GPU.
	if not visual_owner_admission.is_valid() or visual_owner_admission.call(_source_sha, prepared) != true: return _fail("HOLD: original driver mipmap/sampler parity needs trusted visual owner approval")
	return {"ok": true, "source_manifest_sha256": _source_sha, "captures": prepared.map(func(item): return item.capture_record), "prepared": prepared}
