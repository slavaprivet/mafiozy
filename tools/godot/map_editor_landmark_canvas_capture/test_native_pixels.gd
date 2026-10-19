extends SceneTree
## Original browser PNG decode parity only. No texture, renderer or owner grant.
var checks := 0
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--capture-dir" or not args[1].is_absolute_path():
		push_error("Usage: -- --capture-dir <absolute-reviewed-capture-directory>")
		quit(1)
		return
	var folder: String = args[1]
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("receipt.json")))
	if not receipt is Dictionary or not receipt.get("slots") is Array:
		push_error("Actual saved capture receipt required")
		quit(1)
		return
	check(receipt.schema == "original-landmark-canvas-browser-capture-v1" and receipt.ready == false and receipt.zeroWebGL == true, "Original HOLD browser capture")
	check(receipt.canonicalSha256 == "614c65a7a209946125dbc5fcd0632bb575df66cdf080cf6d083d300b914f4a32", "Exact root-observed repeated original capture pin")
	check(receipt.slots.size() == 43, "Every original image included")
	var names := RegEx.new()
	names.compile("^texture-[0-9]+-image-[0-5]$")
	var rgba_bytes := 0
	for slot: Dictionary in receipt.slots:
		check(names.search(slot.id) != null, "Canonical original image identity")
		if names.search(slot.id) == null: continue
		var png := FileAccess.get_file_as_bytes(folder.path_join("images/" + slot.id + ".png"))
		var rgba := FileAccess.get_file_as_bytes(folder.path_join("images/" + slot.id + ".rgba"))
		check(png.size() == slot.pngBytes and rgba.size() == slot.rgbaBytes, "Exact native stored sizes " + slot.id)
		var png_hash := HashingContext.new()
		png_hash.start(HashingContext.HASH_SHA256)
		png_hash.update(png)
		check(png_hash.finish().hex_encode() == slot.pngSha256, "Original PNG byte hash " + slot.id)
		var rgba_hash := HashingContext.new()
		rgba_hash.start(HashingContext.HASH_SHA256)
		rgba_hash.update(rgba)
		check(rgba_hash.finish().hex_encode() == slot.rgbaSha256, "Original RGBA byte hash " + slot.id)
		var native := Image.new()
		var loaded: Error = native.load_png_from_buffer(png)
		check(loaded == OK, "Godot native PNG decoder " + slot.id)
		if loaded != OK: continue
		check(native.get_width() == slot.width and native.get_height() == slot.height, "Original native dimensions " + slot.id)
		native.convert(Image.FORMAT_RGBA8)
		check(native.get_data() == rgba, "Every native decoded RGBA byte equals original browser pixels " + slot.id)
		rgba_bytes += rgba.size()
	for failure in failures: push_error(failure)
	print(JSON.stringify({"suite":"original-canvas-native-PNG-RGBA-parity","checks":checks,"failures":failures,"slots":receipt.slots.size(),"rgbaBytes":rgba_bytes,"gpu":false,"productionInstalled":false,"fontBackendAccepted":false,"iblAccepted":false,"ready":false}))
	quit(0 if failures.is_empty() else 1)
