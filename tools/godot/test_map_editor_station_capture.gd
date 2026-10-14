extends SceneTree
const Factory = preload("res://transport_decor_factory.gd")
var failures := 0
var checks := 0
var consumer: RefCounted
var capture_receipt: Dictionary
var train_asset: Dictionary
var captures: Array = []
func lease() -> bool: return true
func owner_adapter(_request: Dictionary) -> Dictionary:
	return {"ok": true, "commit": func(): return true, "rollback": func(): return true}
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func capture_gate(request: Dictionary) -> Dictionary:
	check(request.source_manifest_sha256 == capture_receipt.source_manifest_sha256, "capture manifest binding")
	return {"ok": true, "source_manifest_sha256": request.source_manifest_sha256, "captures": captures}
func actual_train_factory(request: Dictionary) -> Dictionary:
	check(request.asset.sha256 == train_asset.sha256, "trusted source GLB identity")
	var roots: Array[Node3D] = []
	for index in 3:
		var car := Node3D.new()
		car.name = "Exact_Source_Train_Car_" + str(index)
		for batch: Dictionary in request.batches:
			if batch.dynamicTrainCar != index: continue
			var mesh := MeshInstance3D.new()
			mesh.mesh = request.meshes[batch.geometry]
			mesh.material_override = request.materials[batch.material]
			mesh.transform = Factory._transform(PackedFloat32Array(batch.carLocalMatrix))
			mesh.set_meta("source_train_batch", batch.key)
			car.add_child(mesh)
		roots.append(car)
	return {"ok": true, "source_manifest_sha256": request.source_manifest_sha256, "asset_sha256": request.asset.sha256, "car_roots": roots}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	capture_receipt = JSON.parse_string(FileAccess.get_file_as_string("res://captures/receipt.json"))
	check(capture_receipt.gpuFeatureStatus["2d_canvas"] == "disabled_software" and not capture_receipt.userProfileUsed and capture_receipt.gameTabsOpened == 0, "isolated source canvas CPU capture")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://source/manifest.json"))
	train_asset = manifest.railway.trainAsset
	check(Factory._hash(FileAccess.get_file_as_bytes("res://source/train.glb")) == train_asset.sha256, "actual GLB source bytes admission")
	for row: Dictionary in capture_receipt.captures:
		check(row.font == "600 66px Arial" and row.platformFonts.size() == 1 and row.platformFonts[0].postScriptName == "Arial-BoldMT", "actual native Windows Arial Bold no fallback")
		var bytes := FileAccess.get_file_as_bytes("res://captures/" + str(row.rgba_file))
		check(Factory._hash(bytes) == row.rgba_sha256 and bytes.size() == 1024 * 192 * 4, "original captured RGBA hash")
		var image := Image.create_from_data(1024, 192, false, Image.FORMAT_RGBA8, bytes)
		check(image.get_data() == bytes, "native Image receives exact sRGB RGBA no color conversion")
		# Three source UVs remain untouched (plane top has v=1). Godot texture
		# row zero is v=0, so flip rows once to reproduce Three flipY=true.
		image.flip_y()
		var flipped := image.get_data()
		for y in 192:
			check(flipped.slice(y * 4096, (y + 1) * 4096) == bytes.slice((191 - y) * 4096, (192 - y) * 4096), "exact native flipY row bridge")
		var texture := ImageTexture.create_from_image(image)
		check(texture.get_width() == 1024 and texture.get_height() == 192, "exact native texture dimensions")
		var received: Image = texture.get_image()
		check(received != null and received.get_data() == flipped, "native texture upload/readback preserves exact RGBA")
		captures.append({"texture_id": row.texture_id, "texture": texture, "recipe": row.recipe, "capture_sha256": Factory._hash(flipped), "live_capture_verified": true})
	consumer = Factory.new()
	check(consumer.configure("res://source", capture_receipt.source_manifest_sha256, {"station_capture_gate": capture_gate, "train_factory": actual_train_factory, "edit_lease": lease, "edit_adapter": owner_adapter}).ok, "source consumer admission")
	var built: Dictionary = consumer.build_railway()
	check(built.ok, "combined native railway exact captured label/train build")
	if built.ok:
		root.add_child(built.root)
		check(built.train_cars == 3 and built.root.get_child_count() == 43, "40 static batches plus three actual detailed car roots")
		var actual_meshes := 0
		for car in consumer._train_roots:
			actual_meshes += car.get_child_count()
		check(actual_meshes == 27, "all27 original merged detailed train mesh batches")
		for batch: Dictionary in manifest.railway.batches:
			if batch.has("dynamicTrainCar"): continue
			var node: Node3D = built.root.get_node(str(batch.key).validate_node_name())
			check(node.transform == Factory._transform(PackedFloat32Array(batch.sourceWorldMatrix)), "exact original railway parent transform")
			if batch.kind == "source-instanced":
				check(node.multimesh.instance_count == int(batch.count), "rail active instance count not backing capacity")
		for descriptor: Dictionary in manifest.materials:
			if descriptor.textureBindings.is_empty(): continue
			var material: StandardMaterial3D = consumer._materials[descriptor.id]
			check(material.albedo_texture != null and material.get_meta("source_material") == descriptor, "actual captured source texture admitted no font replacement")
		var alignment := ""
		for record: Dictionary in manifest.semanticObjects:
			if str(record.key).begins_with("railway-alignment:"): alignment = record.key
		check(not alignment.is_empty(), "original alignment identity")
		var before: Dictionary = consumer.current_state(alignment)
		var pose: Transform3D = before.frame
		pose.origin += Vector3(15, 0, -9)
		var train_before: Array[Transform3D] = []
		for car in consumer._train_roots: train_before.append(car.transform)
		check(consumer.transform_object(alignment, pose).ok, "paused source alignment edit admitted by fixture owner")
		for index in 3:
			check(consumer._train_roots[index].position.is_equal_approx(train_before[index].origin + Vector3(15, 0, -9)), "alignment move includes exact actual car roots")
		check(consumer.delete_object(alignment).ok, "alignment delete admitted")
		for car in consumer._train_roots: check(not car.visible, "alignment deletion hides actual cars")
		check(consumer.undo().ok and consumer.undo().ok, "delete/move undo exact")
		for index in 3: check(consumer._train_roots[index].transform.is_equal_approx(train_before[index]) and consumer._train_roots[index].visible, "exact source car restore")
	check(not consumer.update_railway(0.1).ok, "CPU fixture does not activate motion or signal authority")
	consumer.dispose()
	print("station_capture_native: %d checks, %d failures; original CPU canvas pixels/native upload/combined railway; GPU/live parity pending" % [checks, failures])
	quit(1 if failures else 0)
