extends SceneTree
class Probe:
	extends Node
	var player:Node
	var bow:Node
	var phase:=""
	var rows:Array=[]
	var physics_yaw:=0.0
	var prior_yaw:=0.0
	var physics_count:=0
	func _physics_process(_dt:float)->void:
		if player==null:return
		physics_yaw=player._visual.global_rotation.y
		physics_count+=1
	func _process(dt:float)->void:
		if player==null or phase.is_empty():return
		var yaw:float=player._visual.global_rotation.y
		var hand:Vector3=bow._bow.global_position
		rows.append({"phase":phase,"dt":dt,"yaw":yaw,"physics_yaw":physics_yaw,"frame_correction_degrees":rad_to_deg(absf(wrapf(yaw-physics_yaw,-PI,PI))),"render_step_degrees":rad_to_deg(absf(wrapf(yaw-prior_yaw,-PI,PI))),"camera_error_degrees":rad_to_deg(absf(wrapf(yaw-player._camera_yaw-PI,-PI,PI))),"position":[player.position.x,player.position.y,player.position.z],"hand":[hand.x,hand.y,hand.z],"physics_count":physics_count})
		prior_yaw=yaw
var game:Node
var player:Node
var bow:Node
var probe:Probe
var out:=""
func _initialize()->void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
	run.call_deferred()
func frames(n:int)->void:
	for i in n:await physics_frame
func key(down:bool)->void:
	var e:=InputEventKey.new();e.keycode=KEY_S;e.physical_keycode=KEY_S;e.pressed=down;Input.parse_input_event(e)
func button(down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;Input.parse_input_event(e)
func shot(name_:String)->void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+name_+".png")
func phase(name_:String)->void:
	probe.phase=name_
	for i in 4:
		await frames(30)
		await shot(name_+str(i))
	probe.phase=""
func run()->void:
	root.size=Vector2i(1280,720)
	game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true:await process_frame
	await frames(100);game._castle_spawn_frames=0;player=game._player;bow=game.preview_bow_prototype
	game.preview_castle.armory_storage.acquire_or_select("bow");bow=game.preview_bow_prototype
	player.global_position=Vector3(0,0.1,990);player.velocity=Vector3.ZERO;player._camera_yaw=0;player._camera_pitch=-0.24;player._update_camera_rotation();player.set_mouse_captured(true)
	await frames(90)
	probe=Probe.new();probe.process_priority=300;probe.process_physics_priority=300;probe.player=player;probe.bow=bow;root.add_child(probe)
	key(true);await phase("back_held")
	button(true);await phase("back_aimed")
	button(false);await phase("back_released")
	key(false);await frames(30)
	FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":probe.rows,"root_size":str(root.size),"bow":bow.snapshot()},"\t"))
	quit()

