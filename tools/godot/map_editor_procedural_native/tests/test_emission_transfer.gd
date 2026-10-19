extends SceneTree
## Native glTF parser oracle, no GPU or res:// asset installation.
func _initialize() -> void:
	var sha := "060efe1399086eba29b8ba0871787792aa4bfd8187a54203837e5f7ddf44814b"
	var path := ProjectSettings.globalize_path("res://").path_join("../map_editor_asset_stage/" + sha + ".glb").simplify_path()
	var raw := FileAccess.get_file_as_bytes(path)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(raw)
	if hashing.finish().hex_encode() != sha:
		quit(1)
		return
	var source: Dictionary = JSON.parse_string(raw.slice(20, 20 + raw.decode_u32(12)).get_string_from_utf8())
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	if document.append_from_file(path, state) != OK:
		quit(1)
		return
	var checks := 0
	var errors := 0
	for row: Dictionary in source.materials:
		var emissive: Array = row.get("emissiveFactor", [0, 0, 0])
		if emissive == [0, 0, 0]:
			continue
		for material: StandardMaterial3D in state.get_materials():
			if material.resource_name != row.get("name", ""):
				continue
			var linear := Color(emissive[0], emissive[1], emissive[2], 1)
			var strength := float(row.get("extensions", {}).get("KHR_materials_emissive_strength", {}).get("emissiveStrength", 1.0))
			var expected := linear.linear_to_srgb()
			var ok := material.emission.is_equal_approx(expected) and is_equal_approx(material.emission_energy_multiplier, strength)
			print("GLTF_EMISSION_ORACLE ", {"material": material.resource_name, "linear": str(linear), "native": str(material.emission), "expectedSrgb": str(expected), "nativeStrength": material.emission_energy_multiplier, "expectedStrength": strength, "ok": ok})
			checks += 1
			if not ok:
				errors += 1
	print("GLTF_EMISSION_TRANSFER_QA ", {"checks": checks, "errors": errors, "scope": "native importer properties only; GPU pending"})
	quit(0 if checks > 0 and errors == 0 else 1)
