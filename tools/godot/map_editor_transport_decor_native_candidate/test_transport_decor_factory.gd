extends SceneTree
const Factory = preload("res://transport_decor_factory.gd")
var checks := 0
var failures := 0
var allow_edit := false
var allow_commit := true
var lease := true
var rollback_count := 0
var manifest: Dictionary
var admitted_requests: Array = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func edit_adapter(request: Dictionary) -> Dictionary:
	admitted_requests.append(request)
	return {"ok": allow_edit, "commit": func(): return allow_commit, "rollback": func(): rollback_count += 1; return true}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var raw := FileAccess.get_file_as_bytes("res://source/manifest.json")
	var expected_sha := Factory._hash(raw)
	manifest = JSON.parse_string(raw.get_string_from_utf8())
	var consumer := Factory.new()
	check(not consumer.configure("res://source", "0".repeat(64)).ok, "wrong hostsha denied")
	check(consumer.configure("res://source", expected_sha, {"edit_lease": func(): return lease, "edit_adapter": edit_adapter}).ok, "trusted source manifest admission")
	var resources := consumer.shared_resources()
	check(resources.meshes.size() == 36 and resources.materials.size() == 42, "36sharedmeshes42untexturedmaterials2labelmaterialsHOLD")
	for geometry: Dictionary in manifest.geometries:
		var arrays: Array = resources.arrays[geometry.id]
		var expected: PackedByteArray = FileAccess.get_file_as_bytes("res://source/buffers/" + str(geometry.attributes.position.buffer) + ".bin")
		var floats := expected.to_float32_array()
		check(arrays[Mesh.ARRAY_VERTEX].size() == floats.size() / 3, "original vertexcount")
		for index in arrays[Mesh.ARRAY_VERTEX].size():
			var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
			check(vertex == Vector3(floats[index * 3], floats[index * 3 + 1], floats[index * 3 + 2]), "exactoriginal positionfloat32")
		if geometry.attributes.has("normal"):
			var normals := FileAccess.get_file_as_bytes("res://source/buffers/" + str(geometry.attributes.normal.buffer) + ".bin").to_float32_array()
			for index in arrays[Mesh.ARRAY_NORMAL].size():
				check(arrays[Mesh.ARRAY_NORMAL][index] == Vector3(normals[index * 3], normals[index * 3 + 1], normals[index * 3 + 2]), "normal untouched no normalization")
		if geometry.index != null:
			var source := FileAccess.get_file_as_bytes("res://source/buffers/" + str(geometry.index.buffer) + ".bin")
			var width := 2 if geometry.index.arrayType == "Uint16Array" else 4
			for index in range(0, int(geometry.index.count), 3):
				for axis in 3:
					var original_index: int = index + [0, 2, 1][axis]
					var value: int = source.decode_u16(original_index * width) if width == 2 else source.decode_u32(original_index * width)
					check(arrays[Mesh.ARRAY_INDEX][index + axis] == value, "only documentedCWwindingbridge")
	for descriptor: Dictionary in manifest.materials:
		if not resources.materials.has(descriptor.id): continue
		var material: StandardMaterial3D = resources.materials[descriptor.id]
		var expected_color := Color(descriptor.colorLinear[0], descriptor.colorLinear[1], descriptor.colorLinear[2], descriptor.opacity).linear_to_srgb()
		check(material.albedo_color.is_equal_approx(expected_color), "albedo linear→srgb importercontract")
		check(material.emission.is_equal_approx(Color(descriptor.emissiveLinear[0], descriptor.emissiveLinear[1], descriptor.emissiveLinear[2]).linear_to_srgb()), "emission linear→srgb importercontract")
		check(not material.vertex_color_is_srgb and material.vertex_color_use_as_albedo, "linear instancecolors no doubleconversion")
		check(is_equal_approx(material.roughness, descriptor.roughness) and is_equal_approx(material.metallic, descriptor.metalness), "source materialPBRfactors")
	var world := Node3D.new()
	root.add_child(world)
	var built := consumer.build_parking()
	check(built.ok and built.batches == 42 and consumer.initial_uploads == 42, "exactparkingnative42batchoneupload each")
	world.add_child(built.root)
	check(built.root.position == -Vector3(manifest.coordinateContract.originM[0], manifest.coordinateContract.originM[1], manifest.coordinateContract.originM[2]), "sourceorigin once no4.1rescale")
	var parts := 0
	for batch: Dictionary in manifest.parking.batches:
		var matrices := FileAccess.get_file_as_bytes("res://source/buffers/" + str(batch.instanceMatrices.buffer) + ".bin").to_float32_array()
		var node: MultiMeshInstance3D = built.root.get_node(str(batch.key).validate_node_name())
		check(node.multimesh.mesh == resources.meshes[batch.geometry] and node.material_override == resources.materials[batch.material], "shared exactresources reused")
		check(node.multimesh.instance_count == int(batch.count), "activecount exact")
		for index in int(batch.count):
			check(consumer.cpu_instance(batch.key, index) == Factory._transform(matrices, index * 16), "source matrixCPUshadow exact")
			check(consumer.resolve_part(batch.key, index) == batch.objectKeys[index], "exact stable sourceindex routing")
			parts += 1
	check(parts == 856, "all856 originalparkingparts")
	var bay: Dictionary = manifest.parking.sourcePlan.bays[0]
	var key := "parking-bays:" + str(bay.id)
	var before := consumer.current_state(key)
	var after: Transform3D = before.frame
	after.origin += Vector3(7, 0, -3)
	check(not consumer.transform_object(key, after).ok and consumer.current_state(key) == before, "defaultauthority locked no silentactivation")
	allow_edit = true
	lease = false
	check(not consumer.transform_object(key, after).ok, "pausedlease mandatory")
	lease = true
	check(consumer.transform_object(key, after).ok and consumer.last_changed_parts == 4, "moveexact4sourcebayparts only")
	check(consumer.current_state(key).frame == after and consumer.source_metadata("parking").sourcePlan == manifest.parking.sourcePlan, "routes/ownership originals preserved")
	check(consumer.undo().ok and consumer.current_state(key) == before, "undooriginalidentityframe")
	check(consumer.redo().ok and consumer.current_state(key).frame == after, "redoexactsourceparts")
	check(consumer.delete_object(key).ok and consumer.last_changed_parts == 4 and consumer.current_state(key).deleted, "deleteonlycorrectsourceindices")
	for ref: Dictionary in manifest.objectIndex[key]:
		check(is_zero_approx((consumer.cpu_instance(ref.batch, ref.instance) as Transform3D).basis.determinant()), "deletedparts degenerategeometry CPUshadow")
	check(consumer.undo().ok and not consumer.current_state(key).deleted, "undodelete exactrestore")
	var stable := consumer.current_state(key)
	allow_commit = false
	check(not consumer.transform_object(key, before.frame).ok and consumer.current_state(key) == stable and rollback_count == 1, "ownercommitfailure exactstate rollback")
	allow_commit = true
	check(consumer.redo().ok and consumer.current_state(key).deleted, "failededit retains originalredo branch")
	check(consumer.undo().ok, "restorebay beforecull")
	var distant: Transform3D = before.frame
	distant.origin += Vector3(20000, 0, 20000)
	check(consumer.transform_object(key, distant).ok, "far source edit admitted")
	for ref: Dictionary in manifest.objectIndex[key]:
		var node: MultiMeshInstance3D = built.root.get_node(str(ref.batch).validate_node_name())
		var part_bounds: AABB = (consumer.cpu_instance(ref.batch, ref.instance) as Transform3D) * node.multimesh.mesh.get_aabb()
		check(node.multimesh.custom_aabb.encloses(part_bounds), "CPU edited instance included in native frustum bounds")
	consumer.update_parking_culling(distant.origin)
	for ref: Dictionary in manifest.objectIndex[key]:
		check(built.root.get_node(str(ref.batch).validate_node_name()).visible, "far edited bay visible near observer")
	check(consumer.undo().ok and consumer.current_state(key) == stable, "far edit undo restores exact state")
	consumer.update_parking_culling(Vector3(-10000, 0, -10000))
	var visible := 0
	for node in built.root.get_children():
		if node.visible: visible += 1
	check(visible == 0, "exactsource parkingculling distantfocus")
	consumer.update_parking_culling(Vector3.ZERO)
	check(consumer.source_record(key).id == bay.id and admitted_requests.back().source_manifest_sha256 == expected_sha, "trustedadapterboundtosource identity SHA")
	var held := consumer.build_railway()
	check(not held.ok and held.error.begins_with("HOLD") and held.required_captures.textures.size() == 2, "railHOLD no stationlabel substitute")
	check(built.root.get_child_count() == 42, "HOLD causes no partialrailchildren")
	check(not consumer.update_railway(0.1).ok, "unadmittedtrainmotionandsignals neveractivated")
	var metadata := consumer.source_metadata("railway")
	check(metadata.trainCars.size() == 3 and metadata.sourceMotionSnapshot.cars.size() == 3 and metadata.signalLamps.size() == 24, "allactualtrain/lamps/route metadata preserved")
	# Native actual GLB importer confirms the material bridge and original3roots.
	var glb := FileAccess.get_file_as_bytes("res://source/train.glb")
	check(Factory._hash(glb) == metadata.trainAsset.sha256, "actualtrainGLBsourcebytesSHA")
	var gltf_state := GLTFState.new()
	var gltf_doc := GLTFDocument.new()
	check(gltf_doc.append_from_file("res://source/train.glb", gltf_state) == OK, "actualGLBnativeimportnotplaceholder")
	var native_scene := gltf_doc.generate_scene(gltf_state)
	check(native_scene != null, "actual native authoredtrain scene")
	for index in 3: check(native_scene.find_child("TRAIN_LOD0_CAR0%d_ROOT" % index, true, false) != null, "actualauthor3traincarroots")
	var json: Dictionary = JSON.parse_string(glb.slice(20, 20 + glb.decode_u32(12)).get_string_from_utf8())
	var imported := gltf_state.get_materials()
	for descriptor: Dictionary in json.materials:
		for material: StandardMaterial3D in imported:
			if material.resource_name != descriptor.name: continue
			var factor: Array = descriptor.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])
			check(material.albedo_color.is_equal_approx(Color(factor[0], factor[1], factor[2], factor[3]).linear_to_srgb()), "actualGodotGLTFalbedooracle")
			var emission: Array = descriptor.get("emissiveFactor", [0, 0, 0])
			check(material.emission.is_equal_approx(Color(emission[0], emission[1], emission[2]).linear_to_srgb()), "actualGodotGLTFemissionoracle")
	if native_scene != null: native_scene.free()
	consumer.dispose()
	world.free()
	print("transport_decor_factory: %d checks, %d failures; actual train import/material CPU oracle; station pixels HOLD; no GPU" % [checks, failures])
	quit(1 if failures else 0)
