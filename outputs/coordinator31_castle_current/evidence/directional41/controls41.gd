extends SceneTree
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func button(which: int, down: bool) -> void:
	var e := InputEventMouseButton.new(); e.button_index=which;e.pressed=down;Input.parse_input_event(e)
func motion(v: Vector2) -> void:
	var e := InputEventMouseMotion.new();e.relative=v;Input.parse_input_event(e)
func run() -> void:
	var game: Node3D=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
	while game.get("preview_ready")!=true: await process_frame
	await frames(35)
	game._castle_spawn_frames=0
	var player: CharacterBody3D=game._player
	var storage: Node=game.preview_castle.armory_storage
	player.global_position=game.preview_castle.to_global(storage._rack_points[0]);player.velocity=Vector3.ZERO
	storage.interact();await frames(10)
	var sword: Node=game.preview_sword_prototype
	player.global_position=Vector3(0,0.1,990);player.velocity=Vector3.ZERO;player.set_mouse_captured(true)
	await frames(8)
	var zoom: float=player.camera_distance
	button(MOUSE_BUTTON_WHEEL_UP,true);await frames(2);button(MOUSE_BUTTON_WHEEL_UP,false)
	if player.camera_distance>=zoom:errors.append("wheel_zoom_not_forwarded")
	if absf(sword._thrust-0.2)>0.01:errors.append("wheel_thrust")
	motion(Vector2(-25,-20));await frames(1)
	button(MOUSE_BUTTON_LEFT,true);await frames(2);button(MOUSE_BUTTON_LEFT,false)
	var chosen: Vector2=sword._directional41.chosen
	if chosen.x>=0 or chosen.y<=0:errors.append("direction_not_upper_left")
	var seen := {}
	for i in 65:
		seen[sword._directional41.phase]=true
		if sword._directional41.phase!="release" and sword._swing_can_damage31():errors.append("damage_outside_release")
		if sword._directional41.active() and sword._directional41.chosen!=chosen:errors.append("direction_changed")
		await frames(1)
	if not seen.has("release") or sword._directional41.phase!="idle":errors.append("click_not_completed")
	var count: int=sword._directional41.serial
	button(MOUSE_BUTTON_LEFT,true);await frames(100)
	if sword._directional41.serial!=count+1 or sword._directional41.phase!="idle":errors.append("hold_repeats")
	button(MOUSE_BUTTON_LEFT,false);await frames(2)
	button(MOUSE_BUTTON_LEFT,true);await frames(2);button(MOUSE_BUTTON_LEFT,false)
	player.set_mouse_captured(false);await frames(2)
	if sword._directional41.phase!="idle":errors.append("capture_loss_not_cancelled")
	player.set_mouse_captured(true);await frames(2)
	button(MOUSE_BUTTON_RIGHT,true);await frames(3)
	if not sword._blocking or sword._swing_can_damage31():errors.append("guard")
	button(MOUSE_BUTTON_RIGHT,false);await frames(2)
	var wall := StaticBody3D.new();wall.collision_layer=1
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(5,3,0.3);shape.shape=box;wall.add_child(shape);game.add_child(wall)
	var forward: Vector3=-sword._camera.global_basis.z;forward.y=0;forward=forward.normalized()
	wall.global_position=player.global_position+forward*1.35+Vector3.UP*1.3
	wall.look_at(wall.global_position+forward)
	motion(Vector2(25,0));await frames(1);button(MOUSE_BUTTON_LEFT,true);await frames(2);button(MOUSE_BUTTON_LEFT,false)
	var stopped := false
	for i in 42:
		if sword._directional41.interrupted:stopped=true
		await frames(1)
	if not stopped:errors.append("real_wall_did_not_stop_attack")
	var report={"passed":errors.is_empty(),"errors":errors,"phases":seen,"chosen":str(chosen),"wheel_before":zoom,"wheel_after":player.camera_distance,"wall_stop":stopped,"scope":"Real input events and native player/weapon in latest castle, wall is a physical fixture; no damage injection"}
	FileAccess.open("D:/MafioziCombat31/directional41/CONTROLS.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if errors.is_empty() else 1)
