extends SceneTree
# Diagnostic allocation checkpoints only. Does NOT measure performance or alter source files.
const IDS := ["nagan","tt_pistol","revolver","deagle","golden_colt","sawn_off","shotgun","uzi","golden_uzi","ak74","m16","tommy_gun","sniper","rpg"]
var scene:Node3D
var player:CharacterBody3D
var weapons:Node
var cargo:Node
var report:Dictionary={"checkpoints":[],"errors":[],"headless_only":true,"scope":"Diagnostic main-load/resource census; release stages are attribution experiments, not gameplay/perf."}
var output:=""
func _initialize()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--memory-out="):output=arg.trim_prefix("--memory-out=")
	run.call_deferred()
func has_property(obj:Object,key:String)->bool:
	for row:Dictionary in obj.get_property_list():
		if row.name==key:return true
	return false
func census()->Dictionary:
	var classes:Dictionary={};var meshes:Dictionary={};var materials:Dictionary={};var groups:Dictionary={};var vertices:=0;var indices:=0;var visible_meshes:=0
	var all:Array[Node]=scene.find_children("*","Node",true,false)
	for node:Node in all:
		var cls:=node.get_class();classes[cls]=classes.get(cls,0)+1
		if not node is MeshInstance3D:continue
		if node.is_visible_in_tree():visible_meshes+=1
		var branch:Node=node
		while branch.get_parent()!=scene and branch.get_parent()!=null:branch=branch.get_parent()
		groups[str(branch.name)]=groups.get(str(branch.name),0)+1
		if node.mesh==null:continue
		if not meshes.has(node.mesh.get_instance_id()):
			meshes[node.mesh.get_instance_id()]=true
			for i:int in node.mesh.get_surface_count():
				if node.mesh.has_method("surface_get_array_len"):vertices+=node.mesh.surface_get_array_len(i);indices+=node.mesh.surface_get_array_index_len(i)
		for i:int in node.mesh.get_surface_count():
			var material:Material=node.get_active_material(i)
			if material!=null:materials[material.get_instance_id()]=true
	var caches:Dictionary={}
	if cargo!=null:
		caches.pickup_renderer=cargo.renderer.debug_snapshot()
		if has_property(cargo,"_cargo_picker") and cargo.get("_cargo_picker")!=null:caches.car_triangle_meshes=cargo.get("_cargo_picker")._parts.size()
	return {"nodes":all.size(),"node_classes":classes,"mesh_instances_by_main_branch":groups,"visible_mesh_instances":visible_meshes,"unique_mesh_resources":meshes.size(),"unique_active_materials":materials.size(),"unique_mesh_vertices":vertices,"unique_mesh_indices":indices,"caches":caches,"note":"Vertex/index counts from metadata only: no get_faces/surface_get_arrays allocation or mesh readback. Not byte-accurate resource sizing."}
func checkpoint(name:String,scan:bool=false)->void:
	var row:Dictionary={"name":name,"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"static_peak_bytes":Performance.get_monitor(Performance.MEMORY_STATIC_MAX),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"orphan_nodes":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}
	if scan:row.census=census()
	report.checkpoints.append(row)
func sync(frames:int)->void:
	for i:int in frames:await physics_frame;await process_frame
func run()->void:
	if DisplayServer.get_name()!="headless" or output.is_empty():push_error("Memory probe requires --headless and --memory-out=ABS");quit(2);return
	checkpoint("engine_before_main_load")
	var packed:PackedScene=load("res://scenes/main.tscn")
	checkpoint("main_resource_loaded_scripts_compiled_or_loaded")
	scene=packed.instantiate();checkpoint("main_instantiated_before_ready")
	root.add_child(scene)
	for i:int in 300:
		if scene.preview_ready:break
		await sync(1)
	if not scene.preview_ready:report.errors.append("main not ready");finish();return
	player=scene._player;weapons=scene.preview_weapons;cargo=weapons.get_node("WeaponCargo")
	player._free_mouse_look=true
	checkpoint("main_ready",true)
	await sync(6);checkpoint("main_ready_after6frames",true)
	var transport:Node3D=scene.preview_transport
	var access:Dictionary=transport.compartments.access_profile("trunk")
	player.global_position=transport.body.to_global(access.position_local_m+access.outward_local*.7);player.global_position.y=.01
	player._camera_yaw=transport.body.global_rotation.y;player._camera_pitch=-.55;player._update_camera_rotation();transport.compartments.set_open("trunk",true)
	await sync(90)
	for id:String in IDS:
		var eq:Dictionary=weapons.equip(id);var stored:Dictionary=cargo.store_held()
		if not eq.get("ok",false) or not stored.get("ok",false):report.errors.append("cargo store failed "+id)
		await sync(1)
	await sync(3);checkpoint("full14_cargo_warm",true)
	# Stop gameplay only AFTER all loaded checkpoints. No measurements claim this is normal load.
	scene.process_mode=Node.PROCESS_MODE_DISABLED
	if has_property(cargo,"_cargo_picker") and cargo.get("_cargo_picker")!=null:
		cargo.get("_cargo_picker")._parts.clear()
		checkpoint("diagnostic_release_only_car_triangle_cache",true)
	if has_property(weapons,"surface_effects") and weapons.get("surface_effects")!=null:
		weapons.get("surface_effects").dispose();await sync(2);checkpoint("diagnostic_release_surface_pool_after_car_cache",true)
	if has_property(weapons,"rpg_effects") and weapons.get("rpg_effects")!=null:
		weapons.get("rpg_effects").dispose();await sync(2);checkpoint("diagnostic_release_rpg_pool_after_surface",true)
	cargo=null;weapons=null;player=null;scene.free();scene=null;packed=null
	await sync(2);checkpoint("scene_disposed_cached_scripts_resources_may_remain")
	finish()
func finish()->void:
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("MEMORY_ACCOUNT ",report.errors);quit(0 if report.errors.is_empty() else 1)
