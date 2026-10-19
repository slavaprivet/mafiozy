extends RefCounted
const Factory = preload("res://transport_decor_factory.gd")
const TextureAdapter = preload("res://station_bundle/station_texture_adapter.gd")
const SHA := "69ecbd14108fd151b504a41dc3d00ab5dbeca98b8c5ccd6251553fb60189546b"
const RECEIPT_SHA := "8324eabf33a71a9133137491a3bab766e04d3bb10cc4fee7ca58e9602a994fcf"
var factory: RefCounted
var adapter := TextureAdapter.new()
var receipt := {}
var raw_by_id := {}
var prepared := []
var visual_approved := false
var native_car_nodes := 0
var verified_native_glb := false
func configure() -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes("res://station_bundle/captures/receipt.json")
	if TextureAdapter.sha(bytes)!=RECEIPT_SHA: return {"ok":false,"error":"Host-approved original capture receipt changed"}
	receipt = JSON.parse_string(bytes.get_string_from_utf8())
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://source/manifest.json"))
	var approved := {}
	for capture: Dictionary in receipt.captures:
		approved[capture.texture_id] = capture.rgba_sha256
		raw_by_id[capture.texture_id] = FileAccess.get_file_as_bytes("res://station_bundle/captures/"+str(capture.rgba_file))
	var admission: Dictionary = adapter.configure(SHA,manifest.textures,approved)
	if not admission.ok: return admission
	factory = Factory.new()
	return factory.configure("res://source",SHA,{"station_capture_gate":Callable(self,"capture_gate"),"train_factory":Callable(self,"train_factory")})
func capture_gate(request: Dictionary) -> Dictionary:
	var response: Dictionary = adapter.consumer_gate(request,receipt,raw_by_id,Callable(self,"visual_owner"))
	if response.ok: prepared = response.prepared
	return response
func visual_owner(_sha: String,_prepared: Array) -> bool:
	# Native test fixture only; default false. Not a gameplay/GPU approval.
	return visual_approved
func train_factory(request: Dictionary) -> Dictionary:
	if request.source_manifest_sha256!=SHA or Factory._hash(FileAccess.get_file_as_bytes("res://source/train.glb"))!=request.asset.sha256: return {"ok":false}
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	if gltf.append_from_file("res://source/train.glb",state)!=OK: return {"ok":false}
	var authored: Node3D = gltf.generate_scene(state)
	verified_native_glb = authored!=null
	if authored==null: return {"ok":false}
	for index in 3:
		if authored.find_child("TRAIN_LOD0_CAR0%d_ROOT" % index,true,false)==null: verified_native_glb = false
	authored.free()
	if not verified_native_glb: return {"ok":false}
	# Source consumer has installed captured exact textures. Bind the admitted
	# trilinear/clamp sampler using owned clones, never mutate original material.
	for descriptor: Dictionary in factory._manifest.materials:
		if descriptor.textureBindings.is_empty(): continue
		var capture: Dictionary = {}
		for candidate: Dictionary in prepared:
			if candidate.capture_record.texture_id==descriptor.textureBindings.map: capture = candidate
		var material: Dictionary = adapter.material_with_sampler(factory._materials[descriptor.id],capture)
		if not material.ok: return material
		factory._materials[descriptor.id] = material.material
	var cars: Array[Node3D] = []
	for index in 3:
		var car := Node3D.new()
		car.name = "Original_TRAIN_LOD0_CAR0%d_ROOT" % index
		for row: Dictionary in request.batches:
			if row.dynamicTrainCar!=index: continue
			var node := MeshInstance3D.new()
			node.mesh = request.meshes[row.geometry]
			node.material_override = request.materials[row.material]
			node.transform = Factory._transform(PackedFloat32Array(row.carLocalMatrix))
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if row.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.set_meta("source_train_batch",row.key)
			car.add_child(node)
			native_car_nodes += 1
		cars.append(car)
	return {"ok":true,"source_manifest_sha256":SHA,"asset_sha256":request.asset.sha256,"car_roots":cars}
func dispose() -> void:
	if is_instance_valid(factory):
		factory._hooks.clear()
		factory.dispose()
	adapter = null
	factory = null
