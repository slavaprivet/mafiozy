extends SceneTree

var scene:Node
var camera:Camera3D
var props:Node3D
var output:="D:/MafioziCombat31/tree_inventory_visual_20261128"

func _initialize()->void: call_deferred("run")

func shot(name:String, settle_frames: int = 30)->bool:
	for i in settle_frames: await process_frame
	await RenderingServer.frame_post_draw
	var path:=output.path_join("tree57_"+name+".png")
	var error:=root.get_texture().get_image().save_png(path)
	print("TREE57_VISUAL ",JSON.stringify({"name":name,"path":path,"error":error}))
	return error==OK

func run()->void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var packed:PackedScene=load("res://scenes/castle.tscn")
	scene=packed.instantiate(); root.add_child(scene); current_scene=scene
	var deadline:=Time.get_ticks_msec()+240000
	while Time.get_ticks_msec()<deadline and scene.get("preview_ready")!=true: await process_frame
	props=scene.get("preview_battlefield_props") as Node3D
	if not is_instance_valid(props): print("TREE57_VISUAL_FAIL props"); quit(1); return
	var groups:Dictionary=props.get("_groups"); var id:=""
	for key:Variant in groups.keys():
		if str(key).begins_with("tree_"): id=str(key); break
	if id.is_empty(): print("TREE57_VISUAL_FAIL tree"); quit(1); return
	var tree:Dictionary=groups[id]; var center:=Vector3(tree.center)
	DisplayServer.window_set_size(Vector2i(1280,720))
	camera=Camera3D.new(); camera.fov=58; camera.far=400; scene.add_child(camera); camera.current=true
	camera.global_position=props.to_global(center+Vector3(7.5,3.1,9.0)); camera.look_at(props.to_global(center+Vector3.UP*3.2),Vector3.UP)
	var passed:=await shot("intact_close")
	props.apply_melee_hit(id,props.to_global(center+Vector3.UP*1.2),"sword",11.0)
	passed=(await shot("damaged_hp")) and passed
	props.apply_melee_hit(id,props.to_global(center+Vector3.UP*1.2),"axe",999.0)
	await create_timer(0.72).timeout
	passed=(await shot("falling")) and passed
	await create_timer(1.1).timeout
	passed=(await shot("logs")) and passed
	var inventory:CanvasLayer=scene.get("preview_resource_inventory") as CanvasLayer
	if is_instance_valid(inventory):
		var logs:Array=props.get("_tree_logs")
		if not logs.is_empty():
			var log:RigidBody3D=(logs[0] as WeakRef).get_ref() as RigidBody3D
			if is_instance_valid(log): props.pickup_tree_log(log.global_position)
		passed=(await shot("pickup_toast", 2)) and passed
		inventory.open_window()
		passed=(await shot("inventory_b")) and passed
	print("TREE57_VISUAL_RESULT ",passed)
	quit(0 if passed else 1)
