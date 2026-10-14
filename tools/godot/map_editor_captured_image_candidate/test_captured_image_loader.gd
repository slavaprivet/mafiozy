extends SceneTree
const Loader = preload("res://captured_image_loader.gd")
var checks := 0
var failures := []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func write_fixture(path: String,data: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(data)
	file.close()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var loader := Loader.new()
	check(not loader.load_image("texture-0-image-0").ok,"unconfigured CPU source refused")
	check(loader.configure().ok,"exact approved capture/closure admission")
	check(loader.stats().cache_size==0 and loader.stats().counters.image_reads==0,"source images remain lazy at configure")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Loader.ROOT+"receipt.json"))
	var count_bytes := 0
	for slot: Dictionary in source.slots:
		var result: Dictionary = loader.load_image(slot.id)
		check(result.ok,"actual source image loads: "+str(slot.id))
		if not result.ok: continue
		check(result.image.get_width()==slot.width and result.image.get_height()==slot.height,"actual dimensions preserved")
		check(result.image.get_format()==Image.FORMAT_RGBA8 and not result.image.has_mipmaps(),"sRGB base bytes only, no new mips")
		check(Loader.sha(result.image.get_data())==slot.rgbaSha256,"every actual native RGBA bytehash")
		check(result.descriptor==slot,"source sampler/recipe/face/font metadata exact")
		check(not result.ready and not result.font_backend_accepted and not result.sampler_accepted and not result.ibl_accepted and not result.owner_accepted,"no visual/font/gameplay acceptance")
		count_bytes += result.image.get_data().size()
	check(count_bytes==55033856 and loader.ids().size()==43,"all43 actual original image pixels")
	check(loader.stats().counters.png_decodes==43 and loader.stats().counters.image_reads==86 and loader.stats().counters.image_hashes==86,"each original PNG/RGBA verified once per generation")
	var first: Dictionary = loader.load_image("texture-0-image-0")
	var second: Dictionary = loader.load_image("texture-0-image-0")
	check(first.image!=second.image,"independent mutable Image resources")
	first.image.fill(Color.MAGENTA)
	first.descriptor.sourceSampler.repeat[0] = 999
	var returned_bytes: PackedByteArray = second.image.get_data()
	returned_bytes[0] ^= 255
	var third: Dictionary = loader.load_image("texture-0-image-0")
	check(Loader.sha(second.image.get_data())==source.slots[0].rgbaSha256 and Loader.sha(third.image.get_data())==source.slots[0].rgbaSha256,"Image/data copies cannot mutate approved cache or another caller")
	check(third.descriptor.sourceSampler.repeat[0]==18,"mutable caller metadata cannot alter approved sampler")
	var cube: Dictionary = loader.load_texture_images("texture-1")
	check(cube.ok and cube.images.size()==6 and cube.source_type=="CubeTexture","all six original cube slots, no GPU cube resource")
	for i in 6:
		check(cube.descriptors[i].cubeFaceOrdinal==i and cube.descriptors[i].ordinal==i,"original cube face order retained")
		check(Loader.sha(cube.images[i].get_data())==cube.descriptors[i].rgbaSha256,"original cube face exact byte payload")
	check(not cube.ready and not cube.has("texture") and not cube.has("material"),"no Texture/Material/IBL promotion")
	check(not loader.load_image("../../receipt.json").ok and not loader.load_image("texture-99-image-0").ok and not loader.load_texture_images("../texture-1").ok,"unknown/path IDs refused")
	var generation: int = loader.stats().generation
	var image_reads: int = loader.stats().counters.image_reads
	var png_path := Loader.ROOT+"images/texture-0-image-0.png"
	var original_png := FileAccess.get_file_as_bytes(png_path)
	var tampered_png := original_png.duplicate()
	tampered_png[0] ^= 1
	write_fixture(png_path,tampered_png)
	check(loader.load_image("texture-0-image-0").ok and loader.stats().counters.image_reads==image_reads,"warm call returns prior immutable validated snapshot, no live disk reread")
	check(loader.configure().ok and loader.stats().generation>generation and loader.stats().cache_size==0,"explicit generation reset invalidates cache")
	check(not loader.load_image("texture-0-image-0").ok and loader.stats().cache_size==0,"tampered PNG refused on new generation before cache")
	write_fixture(png_path,original_png)
	check(loader.load_image("texture-0-image-0").ok,"restored approved source accepted with SHA repeated")
	var rgba_path := Loader.ROOT+"images/texture-0-image-0.rgba"
	var original_rgba := FileAccess.get_file_as_bytes(rgba_path)
	var tampered_rgba := original_rgba.duplicate()
	tampered_rgba[0] ^= 1
	write_fixture(rgba_path,tampered_rgba)
	check(loader.configure().ok and not loader.load_image("texture-0-image-0").ok,"tampered RGBA refused before decode/cache")
	write_fixture(rgba_path,original_rgba)
	var receipt_path := Loader.ROOT+"receipt.json"
	var original_receipt := FileAccess.get_file_as_bytes(receipt_path)
	var bad_receipt := original_receipt.duplicate()
	bad_receipt[0] ^= 1
	write_fixture(receipt_path,bad_receipt)
	check(not loader.configure().ok and not loader.stats().approved and loader.ids().is_empty() and not loader.load_image("texture-0-image-0").ok,"failed metadata generation invalidates old authority and snapshots")
	write_fixture(receipt_path,original_receipt)
	check(loader.configure().ok,"approved capture generation restored after refusal")
	loader.invalidate()
	check(not loader.load_texture_images("texture-1").ok and loader.stats().cache_size==0,"explicit owner invalidation blocks stale generation")
	print(JSON.stringify({"suite":"actual43-captured-image-CPU-loader","checks":checks,"failures":failures,"sourceRGBABytes":count_bytes,"gpu":false,"fontBackendAccepted":false,"samplerAccepted":false,"iblAccepted":false,"productionInstalled":false,"ready":false}))
	quit(0 if failures.is_empty() else 1)
