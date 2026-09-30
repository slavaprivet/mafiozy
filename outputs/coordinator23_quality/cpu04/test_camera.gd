extends SceneTree
var scene:Node3D
var p:CharacterBody3D
var host:Node
var rows:Array=[]
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func sync(n:int)->void:
	for i:int in n:await physics_frame;await process_frame
func capture(label:String)->void:
	var c:Camera3D=p.get_preview_camera();var a:SpringArm3D=p._spring_arm
	rows.append({"label":label,"fov":c.fov,"camera":str(c.global_position),"player":str(p.global_position),"distance_setting":p.camera_distance,"spring_length":a.spring_length,"hit_length":a.get_hit_length(),"actual_aiming":host._aiming,"module":host.aim_camera.stats(),"arm_offset":str(a.position),"attached":c.get_parent()==a,"camera_distance_from_eye":c.global_position.distance_to(p.global_position+Vector3.UP*host._posture_view.eyeHeight)})
func mouse(down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;p._unhandled_input(e)
func run()->void:
	create_timer(15).timeout.connect(func():quit(3))
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	while not scene.preview_ready:await physics_frame
	p=scene._player;host=scene.preview_weapons;p._free_mouse_look=true
	if not host.equip("ak74").ok:failures.append("AK equip")
	await sync(60);capture("actual_start_normal")
	mouse(true);await sync(60);capture("actual_start_RMB")
	if not host._aiming or absf(p.get_preview_camera().fov-38)>.002:failures.append("RMB camera overwritten or not admitted")
	mouse(false);await sync(60);capture("released_normal")
	if absf(p.get_preview_camera().fov-45)>.002:failures.append("RMB release not restored")
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;wheel.factor=1;p._unhandled_input(wheel);await sync(5)
	var wheel_distance:float=p.camera_distance
	mouse(true);await sync(45);mouse(false);await sync(45);capture("wheel_distance_restored")
	if absf(p._spring_arm.spring_length-wheel_distance)>.002:failures.append("user wheel distance lost after RMB")
	mouse(true);await sync(20);host.set_menu(true);await sync(3);capture("menu_resets_zoom")
	if absf(p.get_preview_camera().fov-45)>.002 or host.aim_camera.scoped():failures.append("menu zoom not reset")
	host.set_menu(false);p._free_mouse_look=true;mouse(true);await sync(20);p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);await sync(3);capture("blur_resets_zoom")
	if absf(p.get_preview_camera().fov-45)>.002:failures.append("blur zoom not reset")
	p._free_mouse_look=true;mouse(true);await sync(20);p.set_preview_pose_authority(&"vehicle",true);await sync(3);capture("seat_camera_owner")
	if absf(p.get_preview_camera().fov-65)>.002:failures.append("seat ownership lens not restored")
	var result:Dictionary={"rows":rows,"failures":failures,"scope":"actual full main/player input/physics/spring camera; source project intentional, NOT export validation"}
	FileAccess.open(get_script().resource_path.get_base_dir().path_join("CAMERA_RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("ZOOM_RUNTIME ",JSON.stringify(result));scene.free();quit(0 if failures.is_empty() else 1)
