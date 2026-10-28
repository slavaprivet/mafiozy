extends SceneTree
## Private candidate only. Exercise real key routing, capsule, camera and mounted
## weapon through stance changes, a normal jump and a cinematic dive.
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for tick in count: await physics_frame

func _weapon_visible(host: Node) -> bool:
	var visual: Node3D=host.presentation._visual
	return is_instance_valid(visual) and visual.is_visible_in_tree() and host.snapshot().equipped=="nagan"

func _shoot(host: Node) -> bool:
	var before: int=host.shots_count
	var down:=InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
	var up:=InputEventMouseButton.new(); up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false
	host.input_event(down)
	await _frames(2)
	host.input_event(up)
	return host.shots_count>before

func _run() -> void:
	var scene=load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene); current_scene=scene
	var deadline:=Time.get_ticks_msec()+115000
	while Time.get_ticks_msec()<deadline and not bool(scene.get("preview_ready")): await process_frame
	var player=scene.get("_player")
	var host=scene.get("preview_weapons")
	_check(bool(scene.get("preview_ready")) and is_instance_valid(player) and is_instance_valid(host),"city, player and arsenal ready")
	if not is_instance_valid(player) or not is_instance_valid(host): _finish(); return
	await _frames(10)
	player.set_mouse_captured(true)
	var equipped: Dictionary=host.equip("nagan")
	await _frames(2)
	_check(bool(equipped.get("ok",false)) and _weapon_visible(host),"Nagan visible when standing")
	var pelvis_index: int=player._pose_skeleton.find_bone("pelvis")
	_check(pelvis_index>=0,"hero pelvis available for stance presentation")
	var standing_pelvis: Transform3D=player._pose_skeleton.get_bone_pose(pelvis_index) if pelvis_index>=0 else Transform3D.IDENTITY
	_key(KEY_C)
	await _frames(36)
	var crouch: Dictionary=host.snapshot().posture
	var capsule: CollisionShape3D=player.get_node("PlayerCapsule")
	_check(crouch.target=="crouch" and float(crouch.value)>.98 and absf(capsule.shape.height-1.69)<.03,"C crouches physical capsule")
	_check(pelvis_index>=0 and not player._pose_skeleton.get_bone_pose(pelvis_index).is_equal_approx(standing_pelvis),"crouch changes displayed body pose")
	_check(player._yaw_pivot.position.y<player.model_target_height*.79-.18,"crouch lowers camera")
	_check(_weapon_visible(host),"Nagan visible while crouching")
	var fired: bool=await _shoot(host)
	_check(fired,"Nagan fires while crouching")
	_key(KEY_Z)
	await _frames(38)
	var prone: Dictionary=host.snapshot().posture
	_check(prone.target=="prone" and float(prone.value)>1.98 and absf(capsule.shape.height-.62)<.03,"Z enters prone with low capsule")
	_check(pelvis_index>=0 and not player._pose_skeleton.get_bone_pose(pelvis_index).is_equal_approx(standing_pelvis),"prone changes displayed body pose")
	_check(player._yaw_pivot.position.y<.5,"prone lowers camera")
	_check(_weapon_visible(host),"Nagan visible while prone")
	fired=await _shoot(host)
	_check(fired,"Nagan fires while prone")
	_key(KEY_Z)
	await _frames(75)
	_check(host.snapshot().posture.target=="stand" and absf(capsule.shape.height-1.9)<.03,"second Z stands up")
	_key(KEY_CTRL)
	await _frames(36)
	_check(host.snapshot().posture.target=="crouch" and absf(capsule.shape.height-1.69)<.03,"Ctrl also crouches")
	_key(KEY_CTRL)
	await _frames(36)
	_check(host.snapshot().posture.target=="stand" and absf(capsule.shape.height-1.9)<.03,"second Ctrl stands up")
	var now:=float(Time.get_ticks_msec())
	var jumped: bool=player._request_preview_jump(now)
	await _frames(2)
	_check(jumped and not player._jump_pose.is_empty(),"ordinary jump starts")
	_check(_weapon_visible(host),"Nagan visible during ordinary jump")
	fired=await _shoot(host)
	_check(fired,"Nagan fires during ordinary jump")
	var upgraded: bool=player._request_preview_jump(now+120.0)
	await _frames(2)
	_check(upgraded and str(player._jump_pose.get("mode",""))=="dive","Max Payne dive starts")
	_check(_weapon_visible(host),"Nagan visible during Max Payne dive")
	await _frames(28)
	fired=await _shoot(host)
	_check(fired,"Nagan fires during Max Payne dive")
	_finish()

func _finish() -> void:
	var report: Dictionary={"ok":failures.is_empty(),"checks":checks,"failures":failures}
	print("PLAYER_POSE57 ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
