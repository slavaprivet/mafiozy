extends SceneTree
var _out := ""
var _failures: Array[String] = []
func _initialize() -> void: _start.call_deferred()
func _start() -> void:
	var marker := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): _out = arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-ready="): marker = arg.trim_prefix("--qa-ready=")
	var deadline: int = Time.get_ticks_msec()+30000
	while not marker.is_empty() and not FileAccess.file_exists(marker):
		if Time.get_ticks_msec() >= deadline: quit(2); return
		await create_timer(.05).timeout
	var scene: Node3D = load("res://scenes/main_city.tscn").instantiate();root.add_child(scene);current_scene=scene
	deadline=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		var population: RefCounted=scene.get("preview_population")
		if scene.get("preview_ready")==true and population!=null and population.get("city_ready")==true:break
		await process_frame
	var host: Node
	for child: Node in scene.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("npc_venue_staff_host29.gd"):host=child;break
	if not is_instance_valid(host):_finish({"ok":false,"reason":"missing_staff"});return
	for layer: Node in scene.find_children("*","CanvasLayer",true,false): layer.visible=false
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=48
	var actors: Array=[];var selected: Dictionary={}
	for venue: String in host._rows:
		var row: Dictionary=host._rows[venue];var actor: Node3D=row.actor
		actors.append({"role":actor.role29,"snapshot":actor.snapshot29(),"style":actor.get_meta("medic_style30",{}),"stats":_stats(actor),"meshes":_meshes(actor),"bones":_bones(actor._skeleton)})
		if actor.role29=="medic" and selected.is_empty():selected=row
	if selected.is_empty():_finish({"ok":false,"reason":"missing_medic"});return
	var actor: Node3D=selected.actor;var point: Vector3=actor.global_position
	var outward: Vector3=-actor.global_basis.z;var side: Vector3=actor.global_basis.x
	var images: Array=[]
	for view: String in ["front","side","case"]:
		var target: Vector3=point+Vector3.UP*1.0
		var offset: Vector3=outward*2.6+Vector3.UP*1.45
		if view=="side":offset=side*2.4+outward*.6+Vector3.UP*1.35
		if view=="case":target=point+outward*.75+Vector3.UP*1.04;offset=outward*1.7+side*.55+Vector3.UP*1.65
		camera.global_position=point+offset;camera.look_at(target)
		for frame: int in 12:await physics_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var filename: String="medic_"+view+".png"
			if root.get_texture().get_image().save_png(_out.path_join(filename))==OK:images.append(filename)
	var counter: Node3D=selected.counter.get_ref()
	_finish({"ok":host._rows.size()==12 and _failures.is_empty(),"staff_count":host._rows.size(),"actors":actors,"counter_stats":_stats(counter),"counter_meshes":_meshes(counter),"images":images,"failures":_failures,"real_city":true,"performance_accepted":false})
func _stats(node: Node) -> Dictionary:
	var value: Dictionary={"nodes":1,"meshes":0,"vertices":0,"triangles":0,"colliders":0,"bones":0,"visible_meshes":0,"visible_vertices":0,"visible_triangles":0}
	if node is MeshInstance3D and node.mesh!=null:
		value.meshes=1
		if node.visible:value.visible_meshes=1
		for surface: int in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			value.vertices+=arrays[Mesh.ARRAY_VERTEX].size()
			value.triangles+=(arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size()/3)
		if node.visible:value.visible_vertices=value.vertices;value.visible_triangles=value.triangles
	if node is CollisionShape3D:value.colliders=1
	if node is Skeleton3D:value.bones=node.get_bone_count()
	for child: Node in node.get_children():
		var part: Dictionary=_stats(child)
		for key: String in value:value[key]+=part[key]
	return value
func _meshes(node: Node) -> Array:
	var result: Array=[]
	if node is MeshInstance3D and node.mesh!=null:
		var materials: Array=[]
		for surface: int in node.mesh.get_surface_count():
			var mat: Material=node.get_active_material(surface)
			materials.append({"type":mat.get_class() if mat!=null else "null","name":mat.resource_name if mat!=null else "","shader":mat.shader.code if mat is ShaderMaterial else ""})
		var diagnostic: Dictionary={}
		if str(node.name)=="player_male_DEMO_core_FABRIC":
			var stored: Array=node.mesh.get("_surfaces");var first: Dictionary=stored[0];var count: int=first.vertex_count;var format: int=first.format
			var histogram: Dictionary={}
			for color: Color in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:histogram[str(color)]=int(histogram.get(str(color),0))+1
			diagnostic={"colors":histogram,"format":format,"stride":RenderingServer.mesh_surface_get_format_attribute_stride(format,count),"offset":RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_COLOR),"first_bytes":first.attribute_data.slice(0,48).hex_encode()}
		result.append({"name":str(node.name),"path":str(node.get_path()),"aabb":str(node.get_aabb()),"transform":str(node.global_transform),"materials":materials,"diagnostic":diagnostic})
	for child: Node in node.get_children():result.append_array(_meshes(child))
	return result
func _bones(rig: Skeleton3D) -> Dictionary:
	var result: Dictionary={"rig_transform":str(rig.global_transform)}
	for index: int in rig.get_bone_count():result[str(rig.get_bone_name(index))]={"local":str(rig.get_bone_pose(index)),"global":str(rig.get_bone_global_pose(index))}
	return result
func _finish(result: Dictionary) -> void:
	var file:=FileAccess.open(_out.path_join("MEDIC30.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("MEDIC30 ",result.get("ok",false));quit(0 if result.get("ok",false) else 1)
