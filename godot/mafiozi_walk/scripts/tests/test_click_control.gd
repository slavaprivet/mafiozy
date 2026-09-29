extends SceneTree
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label:String)->void:
	checks+=1
	if not ok: failures.append(label)
func key(code:Key)->InputEventKey:
	var e:=InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=true; return e
func _initialize()->void: run.call_deferred()
func run()->void:
	var scene: Node3D=load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled=false
	root.add_child(scene)
	while not scene.preview_ready: await physics_frame
	var p: CharacterBody3D=scene._player
	var yaw:float=p._camera_yaw
	var mouse:=InputEventMouseMotion.new(); mouse.relative=Vector2(80,30)
	check(not p._free_mouse_look,"startup inactive")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"startup cursor free")
	p._unhandled_input(mouse)
	check(p._camera_yaw==yaw,"hover does not rotate")
	p._unhandled_input(key(KEY_TAB))
	check(not p._free_mouse_look,"Tab does not acquire control")
	Input.action_press("preview_move_forward")
	for i in 10: await physics_frame
	check(Vector2(p.velocity.x,p.velocity.z).length()<.001,"inactive keyboard does not walk")
	p._unhandled_input(key(KEY_SPACE))
	check(p._jump.is_empty(),"inactive jump blocked")
	scene.preview_transport._unhandled_input(key(KEY_E))
	check(not scene.preview_transport._e_down,"inactive E does not enter")
	Input.action_release("preview_move_forward")
	var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
	p._unhandled_input(click)
	check(p._free_mouse_look,"first click acquires")
	check(not scene.preview_melee._left_held and scene.preview_melee._state.is_empty(),"first click does not fire or charge")
	click.pressed=false; p._unhandled_input(click)
	check(scene.preview_melee._source.snapshot().attackSeq==0,"capture click release does not attack")
	click.pressed=true
	p._unhandled_input(mouse)
	check(p._camera_yaw!=yaw,"active mouse rotates")
	Input.action_press("preview_move_forward")
	for i in 10: await physics_frame
	check(Vector2(p.velocity.x,p.velocity.z).length()>.1,"active keyboard walks")
	p._unhandled_input(key(KEY_ESCAPE))
	check(not p._free_mouse_look and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Escape releases control")
	check(not Input.is_action_pressed("preview_move_forward"),"Escape clears held move action")
	yaw=p._camera_yaw; p._unhandled_input(mouse)
	check(p._camera_yaw==yaw,"released hover stays inert")
	p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not p._free_mouse_look,"focus return requires click")
	p._unhandled_input(click)
	check(p._free_mouse_look,"second click reacquires")
	p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not p._free_mouse_look,"blur releases")
	scene.free()
	print("CLICK_CONTROL ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
