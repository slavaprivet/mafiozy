extends SceneTree
## Proposed bounded actual-host regression; output-only until ROOT applies it.
## No OS-input/render/FPS acceptance. Supply --report=<absolute path> optionally.
var checks := 0
var failures: Array[String] = []
var finished := false
var scene: Node3D
var player: CharacterBody3D
var host: Node

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value and failures.size() < 30: failures.append(label)
func forward(yaw: float, pitch: float = 0.0) -> Vector3:
	return Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))
func sample_case(actor_yaw: float, aim_yaw: float, pitch: float, moving: bool, label: String) -> void:
	# Fixture varies the actor/travel frame separately from the camera, just as
	# the source actor + visualPivot contract. Production host derives _aim.
	player._visual.rotation.y = actor_yaw
	player._heading = actor_yaw - deg_to_rad(player.visual_yaw_degrees)
	player.velocity = forward(actor_yaw)*2.0 if moving else Vector3.ZERO
	var cam: Camera3D = player.get_preview_camera()
	cam.top_level = true
	cam.global_position = player.global_position + Vector3.UP*2.0
	cam.look_at(cam.global_position + forward(aim_yaw,pitch),Vector3.UP)
	host.advance(0.0)
	var base: Dictionary = player._locomotion.sample(1.0/60.0,player.velocity,true)
	var before_offset: Vector3 = base.visual_offset
	var before_rotation: Quaternion = base.get("visual_rotation",Quaternion.IDENTITY)
	var before_actor: Transform3D = player._visual.transform
	var before_body: Transform3D = player.global_transform
	var selected: Dictionary = host.decorate(base)
	selected = host.finish_pose(selected)
	check(selected.get("valid",false),label+": valid selection")
	var display_basis: Basis = player._visual.global_basis * Basis(selected.get("visual_rotation",Quaternion.IDENTITY))
	check((display_basis*Vector3.BACK).normalized().distance_to(forward(aim_yaw)) < 0.0001,label+": complete body source aim yaw")
	check(base.visual_offset == before_offset and base.get("visual_rotation",Quaternion.IDENTITY) == before_rotation,label+": input base not mutated")
	if host._posture_view.value == 0.0:
		check(selected.visual_offset == before_offset,label+": standing floor offset retained")
	check(player._visual.transform == before_actor and player.global_transform == before_body,label+": actor and physical root untouched")
	check(player._apply_selected_pose(selected,player._pose_epoch),label+": sole writer accepts")
	var muzzle: Dictionary = host.presentation.current_muzzle()
	check(muzzle.get("ok",false),label+": current muzzle")
	if muzzle.get("ok",false):
		check(muzzle.weapon_id == host.fire_state.weaponId and muzzle.pose_revision == player._pose_revision,label+": exact gun/latest pose")
		check(muzzle.direction.distance_to(forward(aim_yaw,pitch)) < 0.002,label+": actual gun points along camera aim")
	check(host.presentation._visual.scale.is_equal_approx(Vector3.ONE),label+": original inherited gun scale")

func run() -> void:
	create_timer(20.0).timeout.connect(func():
		if not finished: check(false,"bounded timeout"); finish())
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled = false
	scene.preview_weapons_enabled = true
	root.add_child(scene)
	for i: int in 240:
		if scene.preview_ready: break
		await physics_frame
	check(scene.preview_ready,"actual main ready")
	if not scene.preview_ready: finish(); return
	player = scene._player; host = scene.preview_weapons
	check(is_instance_valid(host),"actual weapon host installed")
	if not is_instance_valid(host): finish(); return
	for i: int in 20: await physics_frame
	check(player.is_on_floor(),"real floor before bounded supplied-pose cases")
	if not player.is_on_floor(): finish(); return
	player.set_physics_process(false)
	player._free_mouse_look = true
	for id: String in ["nagan","ak74","sniper"]:
		check(host.equip(id).get("ok",false),"equip "+id)
		for actor_yaw: float in [0.0,PI/2.0,-PI/2.0,PI]:
			for yaw_delta: float in [0.0,PI/2.0,PI]:
				for moving: bool in [false,true]:
					sample_case(actor_yaw,actor_yaw+yaw_delta,0.0,moving,id+":standing:"+str(actor_yaw)+":"+str(yaw_delta)+":"+str(moving))
	# Exercise controller transition values including return to the exact fast
	# path; actual capsule/ceiling admission remains covered by posture tests.
	for target: String in ["crouch","prone","stand"]:
		check(host.posture.request_posture(target),"request "+target)
		for i: int in 21:
			host.posture.step_posture(0.05)
			host._posture_view = host.posture.posture_state()
			sample_case(-0.67,0.6,0.18,false,"transition:"+target+":"+str(i))
	check(host._posture_view.value == 0.0,"standing fast path reached after prone")
	check(host.equip("none").get("ok",false),"unarmed restored")
	var base: Dictionary = player._locomotion.sample(0.0,Vector3.ZERO,true)
	var expected: Quaternion = base.get("visual_rotation",Quaternion.IDENTITY)
	var selected: Dictionary = host.decorate(base)
	check(selected.get("visual_rotation",Quaternion.IDENTITY) == expected,"unarmed native heading preserved")
	finish()

func finish() -> void:
	if finished: return
	finished = true
	var report := {"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"Actual host pose/yaw integration, bounded supplied locomotion frames; no GPU, FPS, OS-focus or collision-transition acceptance"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STANDING_AIM_YAW ",JSON.stringify(report))
	if is_instance_valid(scene): scene.free()
	quit(0 if failures.is_empty() else 1)
