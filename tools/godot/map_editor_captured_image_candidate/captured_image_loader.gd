extends RefCounted
## CPU-only approved immutable capture snapshots. No Texture/Material admission.
const ROOT := "res://captured_canvas/"
const RECEIPT_FILE_SHA := "2445be8994a25923d05c91f8523be944db7143e9d6e31585b543edcf4083f31a"
const CAPTURE_SHA := "614c65a7a209946125dbc5fcd0632bb575df66cdf080cf6d083d300b914f4a32"
const SOURCE_SHA := "4e459bda9cf6a9ab752667bc8a55fe36a6a6c4d7350a7d5ddc64e08c6a8c490c"
const CLOSURE_SHA := "0c905c26584b0916777973fb7b28e12bfe7aa1e759134e0ec1ad188501897b81"
var _generation := 0
var _approved := false
var _slots := {}
var _texture_slots := {}
var _texture_types := {}
var _cache := {}
var _counters := {"image_reads":0,"png_decodes":0,"image_cache_hits":0,"image_copies":0,"image_hashes":0}

static func sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func invalidate() -> void:
	_generation += 1
	_approved = false
	_slots.clear()
	_texture_slots.clear()
	_texture_types.clear()
	_cache.clear()
	_counters = {"image_reads":0,"png_decodes":0,"image_cache_hits":0,"image_copies":0,"image_hashes":0}

func configure() -> Dictionary:
	# Even failed reconfiguration invalidates the old approved generation.
	invalidate()
	var receipt_bytes := FileAccess.get_file_as_bytes(ROOT+"receipt.json")
	var closure_bytes := FileAccess.get_file_as_bytes(ROOT+"closure.json")
	if sha(receipt_bytes)!=RECEIPT_FILE_SHA or sha(closure_bytes)!=CLOSURE_SHA:
		return {"ok":false,"error":"Original approved capture/closure bytes changed"}
	var receipt: Variant = JSON.parse_string(receipt_bytes.get_string_from_utf8())
	var closure: Variant = JSON.parse_string(closure_bytes.get_string_from_utf8())
	if not receipt is Dictionary or not closure is Dictionary:
		return {"ok":false,"error":"Invalid approved capture metadata"}
	if receipt.get("schema")!="original-landmark-canvas-browser-capture-v1" or receipt.get("ready")!=false or receipt.get("canonicalSha256")!=CAPTURE_SHA or receipt.get("sourceManifestSha256")!=SOURCE_SHA or receipt.get("sourceClosureSha256")!=CLOSURE_SHA or receipt.get("threeRevision")!="180" or receipt.get("zeroWebGL")!=true or receipt.get("webglAttempts")!=0:
		return {"ok":false,"error":"Capture is not the approved CPU-only original generation"}
	if not receipt.get("slots") is Array or receipt.slots.size()!=43 or not closure.get("textures") is Array or closure.textures.size()!=38:
		return {"ok":false,"error":"Original43 images /38 texture descriptors required"}
	var expected := []
	for texture: Dictionary in closure.textures:
		for ordinal in texture.images.size():
			expected.append({"texture":texture,"image":texture.images[ordinal],"ordinal":ordinal,"id":str(texture.id)+"-image-"+str(ordinal)})
	if expected.size()!=43: return {"ok":false,"error":"Unexpected source image slots"}
	var names := RegEx.create_from_string("^texture-(0|[1-9][0-9]?)-image-[0-5]$")
	for i in 43:
		var slot: Dictionary = receipt.slots[i]
		var e: Dictionary = expected[i]
		var face: Variant = e.ordinal if e.texture.type=="CubeTexture" else null
		if names.search(str(slot.get("id","")))==null or _slots.has(slot.id) or slot.id!=e.id or slot.textureId!=e.texture.id or slot.ordinal!=e.ordinal or slot.cubeFaceOrdinal!=face or slot.width!=e.image.width or slot.height!=e.image.height or slot.rgbaBytes!=int(slot.width)*int(slot.height)*4 or slot.sourceRecipeSha256!=e.image.sourceRecipeSha256 or slot.sourceRecipeKey!=e.image.recipeKey or slot.sourceSampler!=e.texture.sampler:
			return {"ok":false,"error":"Original source dimensions/order/recipe/sampler mismatch"}
		_slots[slot.id] = slot.duplicate(true)
		if not _texture_slots.has(slot.textureId): _texture_slots[slot.textureId] = []
		_texture_slots[slot.textureId].append(slot.id)
		_texture_types[slot.textureId] = e.texture.type
	_approved = true
	return {"ok":true,"generation":_generation,"slots":43,"cpu_only":true,"ready":false}

func stats() -> Dictionary:
	return {"generation":_generation,"approved":_approved,"cache_size":_cache.size(),"counters":_counters.duplicate(true),"cpu_only":true,"ready":false}

func ids() -> Array:
	return _slots.keys() if _approved else []

func load_image(id: String) -> Dictionary:
	if not _approved or not _slots.has(id): return {"ok":false,"error":"Unknown/unapproved original image ID"}
	var slot: Dictionary = _slots[id]
	if not _cache.has(id):
		# Fixed admitted IDs only: no caller path or caller metadata is accepted.
		var png := FileAccess.get_file_as_bytes(ROOT+"images/"+id+".png")
		var rgba := FileAccess.get_file_as_bytes(ROOT+"images/"+id+".rgba")
		_counters.image_reads += 2
		if png.size()!=int(slot.pngBytes) or rgba.size()!=int(slot.rgbaBytes):
			return {"ok":false,"error":"Original PNG/RGBA sizes changed"}
		_counters.image_hashes += 2
		if sha(png)!=slot.pngSha256 or sha(rgba)!=slot.rgbaSha256:
			return {"ok":false,"error":"Original PNG/RGBA SHA changed"}
		var decoded := Image.new()
		_counters.png_decodes += 1
		if decoded.load_png_from_buffer(png)!=OK or decoded.get_width()!=int(slot.width) or decoded.get_height()!=int(slot.height):
			return {"ok":false,"error":"Original native PNG decode/dimensions failed"}
		decoded.convert(Image.FORMAT_RGBA8)
		if decoded.has_mipmaps() or decoded.get_data()!=rgba:
			return {"ok":false,"error":"Native decoded pixels differ from original browser sRGB bytes"}
		# Internal immutable snapshot; Image resources are never returned/cached.
		_cache[id] = rgba.duplicate()
	else:
		_counters.image_cache_hits += 1
	_counters.image_copies += 1
	var image := Image.create_from_data(int(slot.width),int(slot.height),false,Image.FORMAT_RGBA8,_cache[id].duplicate())
	return {"ok":true,"image":image,"descriptor":slot.duplicate(true),"generation":_generation,"cpu_only":true,"stored_color_space":"srgb","ready":false,"font_backend_accepted":false,"sampler_accepted":false,"ibl_accepted":false,"owner_accepted":false}

func load_texture_images(texture_id: String) -> Dictionary:
	if not _approved or not _texture_slots.has(texture_id): return {"ok":false,"error":"Unknown/unapproved original texture ID"}
	var images := []
	var descriptors := []
	for id: String in _texture_slots[texture_id]:
		var loaded: Dictionary = load_image(id)
		if not loaded.ok: return loaded
		images.append(loaded.image)
		descriptors.append(loaded.descriptor)
	return {"ok":true,"texture_id":texture_id,"source_type":_texture_types[texture_id],"images":images,"descriptors":descriptors,"sampler":descriptors[0].sourceSampler.duplicate(true),"generation":_generation,"cpu_only":true,"ready":false,"font_backend_accepted":false,"sampler_accepted":false,"ibl_accepted":false,"owner_accepted":false}
