extends SceneTree
const Player = preload("res://scripts/preview_player.gd")
const Dive = preload("res://scripts/preview_dive.gd")
var world: Node3D
var player: CharacterBody3D
var checks := 0
var failures: Array[String] = []
var trajectory_results: Array[Dictionary] = []
var costs: Array[int] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)
func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	world.add_child(body)
	return body
func sync() -> void:
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
func step(delta: float) -> void:
	var start := Time.get_ticks_usec()
	player._physics_process(delta)
	costs.append(Time.get_ticks_usec() - start)
func release_keys() -> void:
	for action in [player.ACTION_LEFT, player.ACTION_RIGHT, player.ACTION_FORWARD, player.ACTION_BACK, player.ACTION_JUMP, player.ACTION_RUN]:
		Input.action_release(action)
func reset_player(at: Vector3 = Vector3(0,.02,0)) -> void:
	release_keys()
	player.set_preview_pose_authority(&"on_foot", true)
	player.global_position = at # Fixture reset only, no runtime flight teleport.
	player.velocity = Vector3.ZERO
	player._camera_yaw = 0.0
	player._jump_physics_visible = true
	for i in range(10): step(1.0/60.0)
func press_direction(direction: Vector2) -> void:
	if direction.x < 0: Input.action_press(player.ACTION_LEFT)
	if direction.x > 0: Input.action_press(player.ACTION_RIGHT)
	if direction.y < 0: Input.action_press(player.ACTION_FORWARD)
	if direction.y > 0: Input.action_press(player.ACTION_BACK)
func key_space(pressed: bool, echo: bool = false) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = pressed
	key.echo = echo
	root.push_input(key)
func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := box(Vector3(0,-.5,0), Vector3(200,1,200))
	player = Player.new()
	world.add_child(player)
	player.set_physics_process(false)
	await sync()
	reset_player()
	check(player.is_on_floor() and player.get_preview_status().source_dive_ready, "actual player settled and source sampler ready")
	var capsule: CapsuleShape3D = player.get_node("PlayerCapsule").shape
	check(is_equal_approx(capsule.radius,.30) and is_equal_approx(player._jump_permission_shape.radius,.36), "physical capsule stays.30 and source permission sweep uses.36")
	for fps in [3,5,10,30,60]:
		for mode: String in ["normal","dive"]:
			reset_player()
			Input.action_press(player.ACTION_RIGHT)
			check(player._request_preview_jump(1000), "first discrete jump admitted")
			if mode == "dive": check(player._request_preview_jump(1000), "immediate upgrade admitted")
			var peak := 0.0
			var frames := 0
			while not player._jump.is_empty() and frames < 120:
				step(1.0 / fps)
				peak = maxf(peak, player.position.y)
				frames += 1
			var distance := player.position.x
			var expected := 5.25 if mode == "dive" else 2.8
			check(absf(distance - expected) < .002, "source physical distance " + mode + " fps=" + str(fps) + " actual=" + str(distance))
			check(player._jump.is_empty() and frames <= ceili((1.70 if mode == "dive" else 1.25)/minf(1.0/fps,.25)) + 2, "source elapsed/recovery parity")
			check(player.position.y < .01 and player.is_on_floor(), "real support reached before flat-floor completion")
			trajectory_results.append({"fps":fps,"mode":mode,"distance":distance,"sampled_peak":peak,"frames":frames})
	for direction: Vector2 in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)]:
		reset_player()
		press_direction(direction)
		player._request_preview_jump(1000)
		player._request_preview_jump(1000)
		for i in range(110):
			if player._jump.is_empty(): break
			step(1.0/60.0)
		var expected := direction.normalized()*5.25
		check(Vector2(player.position.x,player.position.z).distance_to(expected)<.003,"eight-direction movement has no diagonal boost")
		check(player.get_node("VisualHeading/LocomotionOffset").quaternion.is_equal_approx(Quaternion.IDENTITY),"source recovery completes full upright rotation")
	reset_player()
	Input.action_press(player.ACTION_RIGHT)
	player._request_preview_jump(1000)
	for i in range(12): step(1.0/60.0)
	var before := player.position
	var elapsed: float = player._jump.elapsed
	check(player._request_preview_jump(1200),"second press200ms upgrades existing flight")
	check(player.position==before and player._jump.elapsed==elapsed,"upgrade adds no teleport or second impulse")
	var direction_before: Vector2 = player._jump.direction
	release_keys()
	Input.action_press(player.ACTION_BACK)
	check(not player._request_preview_jump(1300) and player._jump.direction==direction_before,"third press cannot redirect or restart")
	for i in range(100):
		if player._jump.is_empty():break
		step(1.0/60.0)
	check(absf(player.position.x-5.11)<.003,"delayed upgrade preserves5.11m cinematic total")
	# Every admitted upgrade time keeps the normal curve's instantaneous y/v.
	# The numerical derivative comes from the continuation, independently of
	# CharacterBody's preceding frame-average velocity (which is not changed).
	for tick in range(51):
		var t := float(tick) / 100.0
		var y := 4.0 * 1.05 * (t/.8) * (1.0-t/.8)
		var vy := 5.25 * (1.0-2.0*t/.8)
		var initial := {"elapsed":t,"startedAt":1000.0,"mode":"normal"}
		var upgraded:Dictionary = Dive.cinematic_upgrade(initial,Vector2.RIGHT,1000+t*1000,y)
		var zero:Dictionary = Dive.cinematic_proposal(upgraded,0.0)
		var tiny:Dictionary = Dive.cinematic_proposal(upgraded,.000001)
		check(absf(zero.arc_y-y)<.000001 and absf((tiny.arc_y-zero.arc_y)/.000001-vy)<.001,"C1 upgrade height/velocity at "+str(t))
		var prior_y := y
		var peak_y := y
		for sample_i in range(1,101):
			var state:Dictionary = upgraded.duplicate()
			state.elapsed = t + (1.25-t)*sample_i/100.0
			var point:Dictionary = Dive.cinematic_proposal(state,0.0)
			peak_y=maxf(peak_y,point.arc_y)
			check(point.arc_y>=-.000001 and point.arc_y<=1.050001,"continuation stays above ground and under retained normal apex")
			if t>=.4:check(point.arc_y<=prior_y+.000001,"descending upgrade never restarts ascent")
			prior_y=point.arc_y
		check(absf(prior_y)<.000001 and peak_y>=y,"continuation reaches ground at1.25 without lost gained height")
	reset_player()
	Input.action_press(player.ACTION_RIGHT)
	player._request_preview_jump(1000)
	for i in range(30):step(1.0/60.0)
	var retained_position := player.position
	var retained_velocity := player.velocity
	check(player._request_preview_jump(1500) and player.position==retained_position and player.velocity==retained_velocity,"500ms runtime upgrade preserves body position and velocity exactly")
	step(.04)
	check(player.position.y<retained_position.y and player.position.y>.8,"late dive continues descending from gained height")
	reset_player()
	player._request_preview_jump(1000)
	player._request_preview_jump(1000)
	for i in range(66):step(1.0/60.0)
	check(not player.is_on_floor() and player._jump.contact_elapsed<0 and is_equal_approx(player._jump.progress,.72),"horizontal pose holds in physical flight at1.10s")
	while not player.is_on_floor():step(1.0/60.0)
	var contact_time:float=player._jump.contact_elapsed
	check(contact_time>=1.20 and contact_time<=1.28,"actual floor contact occurs around1.25s")
	step(.2)
	check(not player._jump.is_empty() and player._jump.progress>.72 and player._jump.progress<1.0,"recovery clock starts only after physical touchdown")
	reset_player()
	player._request_preview_jump(1000)
	check(not player._request_preview_jump(1500.01) and player._jump.mode=="normal","late second press denied")
	reset_player()
	key_space(true)
	check(player._jump.mode=="normal","real input firstSpace normal")
	key_space(true,true)
	check(player._jump.mode=="normal","keyboard repeat does not upgrade")
	key_space(true)
	check(player._jump.mode=="normal","duplicate held keydown without release cannot upgrade")
	key_space(false)
	key_space(true)
	check(player._jump.mode=="dive","real released secondSpace upgrades stationary jump toward camera")
	key_space(false)
	step(1.0/60.0)
	reset_player()
	var editor := LineEdit.new()
	world.add_child(editor)
	editor.grab_focus()
	key_space(true)
	key_space(false)
	check(player._jump.is_empty() and not player._request_preview_jump(1000),"focused text control blocks jump input and direct admission")
	editor.release_focus()
	editor.free()
	# Run actual engine physics callbacks, not only direct deterministic replays.
	reset_player()
	Input.action_press(player.ACTION_RIGHT)
	player.set_physics_process(true)
	key_space(true)
	key_space(false)
	for i in range(12):
		await physics_frame
		await process_frame
	var event_elapsed: float = player._jump.elapsed
	key_space(true)
	key_space(false)
	check(player._jump.mode=="dive" and player._jump.elapsed==event_elapsed,"actual engine second Space preserves existing elapsed")
	var pose_checks := 0
	for i in range(110):
		await physics_frame
		await process_frame
		if not player._jump_pose.is_empty():
			var state:Dictionary=player._jump_pose
			var v:Vector2=state.direction
			var expected:Dictionary=player._dive.sample(state.progress,state.diveBlend,player._visual.global_rotation.y,player._camera_yaw+PI,player._camera_pitch,atan2(v.x,v.y),&"on_foot",player._pose_epoch)
			check(absf(player._pose_motion.quaternion.dot(expected.visual_rotation))>0.999999 and player._pose_motion.position.distance_to(expected.visual_offset)<.0001,"single writer applies exact source visual transform (q and -q equivalent)")
			pose_checks+=1
		if player._jump.is_empty():break
	player.set_physics_process(false)
	check(pose_checks>40 and absf(player.position.x-(5.25-event_elapsed*.7))<.01,"actual physics callback distance matches delayed source upgrade")
	reset_player()
	var wall := box(Vector3(1,1,0),Vector3(.02,4,20))
	await sync()
	Input.action_press(player.ACTION_RIGHT)
	player._request_preview_jump(1000)
	player._request_preview_jump(1000)
	for i in range(110):
		if player._jump.is_empty():break
		step(1.0/60.0)
	check(player.position.x<=.631 and player.position.x>.5,"thin wall preserves source.36 footprint: "+str(player.position.x))
	wall.free()
	reset_player()
	var ceiling := box(Vector3(0,2.02,0),Vector3(20,.02,20))
	await sync()
	player._request_preview_jump(1000)
	step(.04)
	check(player._jump.ceilingHit and player._jump.elapsed>=.8 and player.position.y<.01,"ceiling enters and integrates falling/contact in same substep")
	check(not player._request_preview_jump(1040),"ceiling-hit jump cannot upgrade")
	reset_player()
	player._request_preview_jump(1000)
	player._request_preview_jump(1000)
	step(.04)
	check(player._jump.ceilingHit and player.is_on_floor() and player._jump.contact_elapsed>=0.0,"cinematic ceiling cancellation integrates fall and real contact in same substep")
	ceiling.free()
	reset_player()
	Input.action_press(player.ACTION_RIGHT)
	player._request_preview_jump(1000)
	player._request_preview_jump(1000)
	step(.2)
	var epoch: int = player.get_preview_status().pose_epoch
	player.set_preview_pose_authority(&"vehicle")
	var held := player.position
	step(.1)
	check(player._jump.is_empty() and player.position==held and player.get_node("VisualHeading/LocomotionOffset").quaternion==Quaternion.IDENTITY,"external authority cancels movement and residual visual tilt")
	player.set_preview_pose_authority(&"on_foot",true)
	check(player.get_preview_status().pose_epoch==epoch+2,"owner and new lifetime advance epochs")
	reset_player()
	player._request_preview_jump(1000)
	player._request_preview_jump(1000)
	var frozen: Dictionary = player._jump.duplicate()
	player._jump_physics_visible=false
	step(.25)
	check(player._jump==frozen,"hidden frame has no elapsed or movement debt")
	player._jump_physics_visible=true
	step(2.0)
	check(player._jump==frozen,"long gap has no catch-up impulse")
	player._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	step(.04)
	check(player._jump.elapsed>0.0,"visible focus loss releases controls but does not freeze source jump")
	for ledge_height:float in [.005,.018,.0199]:
		player.set_preview_pose_authority(&"on_foot",true)
		var tiny_ledge := box(Vector3(0,ledge_height*.5,0),Vector3(1.2,ledge_height,2))
		await sync()
		reset_player(Vector3(0,ledge_height+.02,0))
		Input.action_press(player.ACTION_RIGHT)
		check(player._request_preview_jump(1000) and player._request_preview_jump(1000),"cinematic starts from small physical ledge")
		for i in range(132):
			step(1.0/60.0)
		check(player._jump.is_empty() and player.is_on_floor() and absf(player.position.y)<.001,"sub2cm floor drop reaches real support and completes recovery: "+str(ledge_height))
		check(player._request_preview_jump(4000),"next jump admitted after sub2cm landing")
		tiny_ledge.free()
	player.set_preview_pose_authority(&"on_foot",true)
	floor_body.free()
	box(Vector3(0,-.5,0),Vector3(1.2,1,10))
	box(Vector3(4,-10.5,0),Vector3(12,1,10))
	await sync()
	reset_player()
	Input.action_press(player.ACTION_RIGHT)
	player._request_preview_jump(1000)
	player._request_preview_jump(1000)
	var seen_fall := false
	for i in range(110):
		if player._jump.is_empty():break
		step(1.0/60.0)
		seen_fall = seen_fall or bool(player._jump.get("falling",false))
	check(seen_fall and player.position.y<-.05,"edge starts actual falling toward lower floor")
	if player.get_preview_status().source_falling:
		var vy:float=player.velocity.y
		step(1.0/60.0)
		check(absf(player.velocity.y-(vy-18.0/60.0))<.001,"post-jump source fall preserves gravity18: "+str(vy)+" -> "+str(player.velocity.y))
	release_keys()
	for i in range(90):step(1.0/60.0)
	check(player.is_on_floor() and absf(player.position.y+10.0)<.01,"lower actual support catches fall without teleport")
	world.free()
	var main:Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await sync()
	check(main.preview_ready and main._player.get_preview_status().jump_surface_guard_bound,"actual main binds source containment guard")
	check(not main.preview_jump_surface_allowed(Vector3(100000,0,100000),.36),"out-of-crop source containment fails closed")
	var surface:Dictionary=main._block.surface
	var water_checked:=false
	for r in range(surface.grid.size()):
		for c in range(surface.grid[r].size()):
			if int(surface.grid[r][c])!=16:continue
			var p:=Vector3((surface.startCol+c+.5)*surface.cellSize-main._origin.x,-.18,(surface.startRow+r+.5)*surface.cellSize-main._origin.z)
			if not main.preview_jump_surface_allowed(p,.36):continue
			var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.1,p-Vector3.UP*1.0,1)
			var hit:Dictionary=main.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty():continue
			water_checked=true
			break
		if water_checked:break
	check(water_checked,"source water is allowed without inventing a physical water floor")
	main.free()
	costs.sort()
	print("DIVE_INTEGRATION ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"trajectories":trajectory_results,"physics_cpu_p50_us":costs[costs.size()/2],"physics_cpu_p95_us":costs[int(costs.size()*.95)],"live":false,"fps":false}))
	quit(0 if failures.is_empty() else 1)
