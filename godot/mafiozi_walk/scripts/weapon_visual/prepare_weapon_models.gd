extends SceneTree
## Offline only. Builds native resources; never a game autoload.
const Visual = preload("res://scripts/weapon_visual/weapon_visual.gd")
var source_dir := ""
var output_dir := ""
var failures: Array[String] = []

static func matrix(value: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(value[0],value[1],value[2]),Vector3(value[4],value[5],value[6]),Vector3(value[8],value[9],value[10])),Vector3(value[12],value[13],value[14]))

static func vector(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source_dir = arg.trim_prefix("--source=")
		if arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	if source_dir.is_empty() or output_dir.is_empty(): quit(2); return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_dir.path_join("manifest.json")))
	if source.get("schema") != "mafiozi.weapon-source/v1": quit(2); return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var entries: Array = []
	var start := Time.get_ticks_usec()
	for entry: Dictionary in source.entries:
		var bytes := FileAccess.get_file_as_bytes(source_dir.path_join(entry.buffer_file))
		if bytes.size() != int(entry.buffer_bytes) or FileAccess.get_sha256(source_dir.path_join(entry.buffer_file)) != entry.buffer_sha256:
			failures.append(entry.id + ": buffer hash"); continue
		var node := Node3D.new()
		node.name = "Weapon_" + entry.id
		node.set_script(Visual)
		var profile := {"id": entry.id, "label": entry.label, "family": entry.family, "two_handed": entry.two_handed,
			"source_metadata": entry.source_metadata, "primary_hand_grip": entry.primary_hand_grip,
			"reload_hand_target": entry.reload_hand_target, "source_forward": "+Z", "units": entry.units, "bounds_source": entry.bounds}
		node.set_meta("weapon_profile", profile)
		var native_low := Vector3(INF, INF, INF)
		var native_high := Vector3(-INF, -INF, -INF)
		var materials: Array[StandardMaterial3D] = []
		for row: Dictionary in entry.materials:
			var material := StandardMaterial3D.new()
			material.resource_name = "SourceMaterial_%d" % materials.size()
			material.albedo_color = Color(row.color_linear[0], row.color_linear[1], row.color_linear[2], row.opacity).linear_to_srgb()
			material.metallic = row.metallic
			material.roughness = row.roughness
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if row.transparent else BaseMaterial3D.TRANSPARENCY_DISABLED
			material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS if row.transparent and row.depth_write else BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
			material.cull_mode = BaseMaterial3D.CULL_BACK
			material.set_meta("weapon_source_material", row)
			materials.append(material)
		for batch: Dictionary in entry.batches:
			var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = bytes.slice(int(batch.positions.offset),int(batch.positions.offset+batch.positions.bytes)).to_vector3_array()
			arrays[Mesh.ARRAY_NORMAL] = bytes.slice(int(batch.normals.offset),int(batch.normals.offset+batch.normals.bytes)).to_vector3_array()
			arrays[Mesh.ARRAY_TEX_UV] = bytes.slice(int(batch.uvs.offset),int(batch.uvs.offset+batch.uvs.bytes)).to_vector2_array()
			arrays[Mesh.ARRAY_INDEX] = bytes.slice(int(batch.indices.offset),int(batch.indices.offset+batch.indices.bytes)).to_int32_array()
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, materials[int(batch.material)])
			var instance := MeshInstance3D.new()
			instance.name = batch.key; instance.mesh = mesh; instance.transform = matrix(batch.local_matrix)
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var transformed := instance.transform * point
				native_low = native_low.min(transformed); native_high = native_high.max(transformed)
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			node.add_child(instance); instance.owner = node
			if batch.slot != null:
				instance.set_meta("weapon_animation_slot", batch.slot)
				instance.set_meta("weapon_rest", instance.transform)
		profile["bounds_native"] = null if entry.batches.is_empty() else {"min":[native_low.x,native_low.y,native_low.z],"max":[native_high.x,native_high.y,native_high.z]}
		node.set_meta("weapon_profile", profile)
		var anchors := {"GripOrigin":entry.source_metadata.gripOrigin,"PrimaryHandGrip":entry.primary_hand_grip,
			"Muzzle":entry.source_metadata.muzzle,"EjectionPort":entry.source_metadata.ejectionPort,"SupportGrip":entry.source_metadata.supportGrip}
		for name: String in anchors:
			if anchors[name] == null: continue
			var anchor := Marker3D.new(); anchor.name = name; anchor.position = vector(anchors[name]); anchor.set_meta("weapon_anchor",true)
			node.add_child(anchor); anchor.owner = node
		var packed := PackedScene.new()
		if packed.pack(node) != OK: failures.append(entry.id+": pack")
		var target := output_dir.path_join(entry.id + ".scn")
		# Meshes/materials are already built-in resources. Keep the behavior script
		# as a normal res:// external dependency; bundling GDScript into .scn is invalid.
		if ResourceSaver.save(packed, target) != OK: failures.append(entry.id+": save")
		node.free()
		entries.append({"id":entry.id,"file":entry.id+".scn","sha256":FileAccess.get_sha256(target),"bytes":FileAccess.get_file_as_bytes(target).size(),
			"source_meshes":entry.source_meshes,"draw_surfaces":entry.native_draw_surfaces,"triangles":entry.triangles,"profile":profile})
	var manifest := {"schema":"mafiozi.weapon-native/v1","engine":Engine.get_version_info().string,"source_inputs":source.source_inputs,
		"source_hash_normalization":source.source_hash_normalization,"source_manifest_sha256":FileAccess.get_sha256(source_dir.path_join("manifest.json")),
		"entries":entries,"limits":source.limits}
	FileAccess.open(output_dir.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t",true,true))
	print("WEAPON_NATIVE_PREPARE ",JSON.stringify({"passed":failures.is_empty(),"entries":entries.size(),"elapsed_ms":(Time.get_ticks_usec()-start)/1000.0,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
