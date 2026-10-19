extends SceneTree
const Factory = preload("res://profile_authored_factory.gd")
const Registry = preload("res://profile_authored_registry.gd")
var failures := []
var checks := 0
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message)
static func sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
func census(host: Node3D) -> Dictionary:
	var meshes := {}
	var materials := {}
	var textures := {}
	var shapes := {}
	var shape_payloads := {}
	var normals := 0
	var visible := 0
	var surfaces := 0
	var shadow_surfaces := 0
	var bodies := 0
	var packed_material_flags := {}
	var nodes := [host]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		if node is MeshInstance3D and node.mesh!=null:
			normals += 1
			if not node.is_visible_in_tree(): continue
			visible += 1
			meshes[node.mesh.get_instance_id()] = node.mesh
			surfaces += node.mesh.get_surface_count()
			if node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: shadow_surfaces += node.mesh.get_surface_count()
			for index in node.mesh.get_surface_count():
				var material: Material = node.get_active_material(index)
				if material==null: continue
				materials[material.get_instance_id()] = material
				if material.resource_local_to_scene: packed_material_flags[material.get_instance_id()] = true
				if material is StandardMaterial3D:
					for property in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","emission_texture"]:
						var texture: Variant = material.get(property)
						if texture is Texture2D: textures[texture.get_instance_id()] = true
		if node is StaticBody3D: bodies += 1
		if node is CollisionShape3D and node.shape!=null:
			shapes[node.shape.get_instance_id()] = true
			check(node.shape is ConvexPolygonShape3D,"original convex collider, no substitute")
			var shape: ConvexPolygonShape3D = node.shape
			var key := sha(shape.points.to_byte_array()+PackedFloat64Array([shape.margin]).to_byte_array())
			shape_payloads[key] = int(shape_payloads.get(key,0))+1
	return {"allMeshNodes":normals,"visibleMeshNodes":visible,"surfaces":surfaces,"shadowSurfaces":shadow_surfaces,"uniqueMeshResources":meshes.size(),"uniqueMaterialResources":materials.size(),"uniqueTextureResources":textures.size(),"sceneLocalMaterials":packed_material_flags.size(),"bodies":bodies,"uniqueShapeResources":shapes.size(),"uniqueExactShapePayloads":shape_payloads.size(),"exactDuplicateShapeInstances":shapes.size()-shape_payloads.size()}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var factory := Factory.new()
	var begin := Time.get_ticks_usec()
	check(factory.configure(catalog),"source admission")
	var configure_usec := Time.get_ticks_usec()-begin
	var rows := []
	var expected_census := {}
	var expected_bounds := {}
	var expected_frames := {}
	for round in 6:
		factory.reset_profile()
		var host := Node3D.new()
		root.add_child(host)
		var registry := Registry.new()
		var pending := {}
		var count := 0
		var roots := []
		var wall_start := Time.get_ticks_usec()
		for object: Dictionary in catalog.objects:
			if not object.has("resourceId"): continue
			var built: Dictionary = factory.spawn_key(object.key,{"exterior_collisions":true})
			check(built.ok,"actual original source spawn")
			host.add_child(built.root)
			roots.append(built.root)
			count += 1
			for reason: String in built.pending: pending[reason]=int(pending.get(reason,0))+1
			check(registry.register_object(object.key,built.root,{"kind":object.dataset,"model":object.resourceId,"source":object.sourceRecord.duplicate(true)},[],built.pending.is_empty()).ok,"source index")
			if round==0:
				expected_bounds[object.key] = registry.world_bounds(object.key)
				expected_frames[object.key] = built.root.transform
			else:
				check(registry.world_bounds(object.key)==expected_bounds[object.key],"exact source native bounds retained")
				check(built.root.transform==expected_frames[object.key],"exact source native frames retained")
		var total := Time.get_ticks_usec()-wall_start
		var resources := census(host)
		if round==0: expected_census = resources.duplicate(true)
		else: check(resources==expected_census,"census unchanged warm scene")
		check(count==242,"all242 objects")
		check(factory.loads==factory.packed_cache.size(),"each placed verified GLB loaded once")
		check(resources.visibleMeshNodes==6772 and resources.surfaces==7065,"original visible meshes/surfaces preserved")
		check(resources.bodies==355,"all355 admitted original convex bodies")
		rows.append({"round":round,"cold":round==0,"totalSpawnAndRegisterUsec":total,"factory":factory.counters.duplicate(true),"registry":registry.counters.duplicate(true),"census":resources,"protectedPending":pending,"packedLoads":factory.loads})
		host.free()
	print("AUTHORED_AUDIT "+JSON.stringify({"checks":checks,"failures":failures,"configureUsec":configure_usec,"rows":rows,"scope":"source original assets, actual native headless; inclusive profile timings, no GPU/drawcall/FPS acceptance"}))
	quit(0 if failures.is_empty() else 1)
