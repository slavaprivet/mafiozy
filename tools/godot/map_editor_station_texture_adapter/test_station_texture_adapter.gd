extends SceneTree
const Adapter = preload("res://station_texture_adapter.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://captures/receipt.json"))
	var adapter := Adapter.new()
	var approved := {}
	for row: Dictionary in receipt.captures: approved[row.texture_id] = row.rgba_sha256
	check(adapter.configure(receipt.source_manifest_sha256, manifest.textures, approved).ok, "exact source sampler/pixel admission")
	var raw_by_id := {}
	var timings: Array[int] = []
	var prepared_all: Array[Dictionary] = []
	for row: Dictionary in receipt.captures:
		var raw := FileAccess.get_file_as_bytes("res://captures/" + str(row.rgba_file))
		raw_by_id[row.texture_id] = raw
		var initial := Time.get_ticks_usec()
		var prepared := adapter.prepare_capture(row, raw)
		check(prepared.ok, "native CPU linear-light complete mip candidate")
		if not prepared.ok:
			quit(1)
			return
		prepared_all.append(prepared)
		print("cold %s: %d us, %d bytes" % [row.texture_id, Time.get_ticks_usec() - initial, prepared.bytes])
		var image: Image = prepared.texture.get_image()
		check(image.get_width() == 1024 and image.get_height() == 192 and image.get_format() == Image.FORMAT_RGBA8, "source resolution/format unchanged")
		check(image.has_mipmaps() and image.get_mipmap_count() == 10 and prepared.levels.size() == 11, "complete source mipmap hierarchy to1x1")
		var bytes := image.get_data()
		check(Adapter.sha(bytes) == prepared.native_sha256 and bytes.size() == prepared.bytes, "whole native upload/readback byte hash")
		var expected_sizes := [Vector2i(1024, 192), Vector2i(512, 96), Vector2i(256, 48), Vector2i(128, 24), Vector2i(64, 12), Vector2i(32, 6), Vector2i(16, 3), Vector2i(8, 1), Vector2i(4, 1), Vector2i(2, 1), Vector2i(1, 1)]
		for level in prepared.levels.size():
			var entry: Dictionary = prepared.levels[level]
			check(Vector2i(entry.width, entry.height) == expected_sizes[level], "independent sourceNPOTmipdimensions")
			check(image.get_mipmap_offset(level) == entry.offset, "native mip layout offset")
			check(entry.bytes == entry.width * entry.height * 4, "each mip dimension and byte count")
			check(bytes.slice(entry.offset, entry.offset + entry.bytes).size() == entry.bytes, "every mip byte span present")
		for index in range(3, bytes.size(), 4): check(bytes[index] == 255, "all sourceopaque mipalpha retained")
		for y in 192:
			check(bytes.slice(y * 4096, (y + 1) * 4096) == raw.slice((191 - y) * 4096, (192 - y) * 4096), "one exact flip and no base gamma rewrite")
		var raw_before := raw.duplicate()
		for repetition in 30:
			initial = Time.get_ticks_usec()
			var repeat := adapter.prepare_capture(row, raw)
			timings.append(Time.get_ticks_usec() - initial)
			check(repeat.ok and repeat.texture == prepared.texture and repeat.capture_record.capture_sha256 == prepared.native_sha256, "content SHA cache preserves shared texture identity")
		check(raw == raw_before, "caller RGBA bytes immutable")
		var base := StandardMaterial3D.new()
		base.roughness = 0.8
		base.albedo_color = Color(0.3, 0.2, 0.7)
		var material := adapter.material_with_sampler(base, prepared)
		check(material.ok and material.material != base and material.material.albedo_texture == prepared.texture, "separate owner material resource binds shared texture")
		check(material.material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and not material.material.texture_repeat, "source trilinear-min linear-mag clamp sampler")
		check(base.albedo_texture == null and material.material.albedo_color == base.albedo_color and material.material.roughness == base.roughness, "source material untouched no gamma rerun")
		check(adapter.material_with_sampler(base, prepared).material == material.material, "material identity cached")
		base.roughness = 0.4
		base.emit_changed()
		var refresh := adapter.material_with_sampler(base, prepared)
		check(refresh.material != material.material and refresh.material.roughness == base.roughness, "source material mutation cannot reuse stale clone")
		var corrupt := raw.duplicate()
		corrupt[0] ^= 1
		check(not adapter.prepare_capture(row, corrupt).ok, "corrupt pixels rejected before cache")
		var forged_pixels := row.duplicate(true)
		forged_pixels.rgba_sha256 = Adapter.sha(corrupt)
		check(not adapter.prepare_capture(forged_pixels, corrupt).ok, "forged new pixel hash cannot replace approved source capture")
		var forged := row.duplicate(true)
		forged.sourceTexture.minFilter = 1006
		check(not adapter.prepare_capture(forged, raw).ok, "cannot silently remove source mip filtering")
	check(adapter.cold_builds == 2 and adapter.cache_hits == 60, "exact two cold textures shared60times")
	# Independent analytical oracle: equal black/white linear-light average
	# encodes to188, never naive sRGB byte average128. Source base stays exact.
	var checker := PackedByteArray([0, 0, 0, 255, 255, 255, 255, 255, 0, 0, 0, 255, 255, 255, 255, 255])
	var chain := adapter._cpu_chain(checker, 2, 2)
	check(chain.slice(0, 16) == checker and chain.slice(16) == PackedByteArray([188, 188, 188, 255]), "mips filter in linear light without base double conversion")
	var gate := adapter.consumer_gate({"source_manifest_sha256": receipt.source_manifest_sha256}, receipt, raw_by_id)
	check(not gate.ok and gate.error.begins_with("HOLD"), "no default self approval of original GPU mip parity")
	gate = adapter.consumer_gate({"source_manifest_sha256": receipt.source_manifest_sha256}, receipt, raw_by_id, func(_sha, _items): return true)
	check(gate.ok and gate.captures.size() == 2 and gate.captures[0].texture == prepared_all[0].texture, "trusted fixture admission compatible frozen consumer format")
	var source_before: Array = manifest.textures.duplicate(true)
	var unsupported: Array = manifest.textures.duplicate(true)
	unsupported[0].image.width = 512
	check(not Adapter.new().configure(receipt.source_manifest_sha256, unsupported, approved).ok and manifest.textures == source_before, "no reduced source resolution accepted")
	var old: ImageTexture = prepared_all[0].texture
	var changed_image := old.get_image()
	changed_image.set_pixel(0, 0, Color.RED)
	old.update(changed_image)
	var rebuilt := adapter.prepare_capture(receipt.captures[0], raw_by_id[receipt.captures[0].texture_id])
	check(rebuilt.ok and rebuilt.texture != old and adapter.invalidations == 1, "externally mutated resource invalidates shared cache")
	timings.sort()
	print("station_texture_adapter: %d checks, %d failures; warm p50/p95 %d/%d us; original GPU mip/sampler parity HOLD, no GPU" % [checks, failures, timings[timings.size() / 2], timings[int(timings.size() * .95)]])
	quit(1 if failures else 0)
