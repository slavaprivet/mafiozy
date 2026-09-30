extends SceneTree
## External harness for unpacked stage OR --main-pack with this absolute script.
## Actual equip/input/presentation/muzzle/ammo/native ray; no synthetic shots.
## Test-only: stationary three residents, QA aim camera, deterministic survival RNG.
var scene: Node3D
var player: CharacterBody3D
var weapons: Node
var owner: RefCounted
var observer: Camera3D
var target_fallen:=false
var tracking:=false
var scripted_controls:=false
var done:=false
var checks:=0
var failures: Array[String]=[]
var phases: Array[Dictionary]=[]
var impacts: Array[Dictionary]=[]
var shots: Array[Dictionary]=[]
var images: Array[String]=[]
var out:=""
var draws:=0

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func mouse(pressed: bool) -> InputEventMouseButton:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; return event
func controls() -> void:
	if scripted_controls and is_instance_valid(player) and not player._free_mouse_look: player._free_mouse_look=true
func _process(_dt: float) -> bool:
	controls()
	if tracking: aim()
	return false
func sync(count:=1) -> void:
	for i in count:
		if done: return
		await physics_frame; await process_frame
func target_point() -> Vector3:
	if target_fallen:
		var physical: RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
		return physical._body._bodies.chest.global_position
	return owner._token.body.global_position+Vector3.UP*1.1
func aim() -> void:
	if not is_instance_valid(player) or owner==null: return
	var camera: Camera3D=player.get_preview_camera()
	camera.top_level=true
	camera.global_position=player.global_position+Vector3.UP*2.2
	camera.look_at(target_point(),Vector3.UP)
func own_collider(collider: Variant) -> bool:
	if collider==owner._token.body: return true
	if not collider is RigidBody3D: return false
	var physical: RefCounted=scene.preview_population.residents._ragdolls[owner._token.source_id]
	return collider in physical.owned_bodies()
func real_sight() -> Dictionary:
	var camera: Camera3D=player.get_preview_camera()
	var camera_hit: Dictionary=weapons._projectile_ray({"origin":camera.global_position,"direction":-camera.global_basis.z,"range":100.0})
	var muzzle: Dictionary=weapons.presentation.current_muzzle()
	if not camera_hit.has("point") or not muzzle.get("ok",false): return {"ok":false,"reason":"camera_or_muzzle","camera_hit":str(camera_hit),"muzzle":str(muzzle)}
	var direction: Vector3=(camera_hit.point-muzzle.origin).normalized()
	var ray: Dictionary=weapons._projectile_ray({"origin":muzzle.origin,"direction":direction,"range":muzzle.origin.distance_to(camera_hit.point)+.03})
	return {"ok":own_collider(camera_hit.get("collider")) and own_collider(ray.get("collider")) and ray.get("normal",Vector3.ZERO).length_squared()>.5,"camera_hit":str(camera_hit),"muzzle_hit":str(ray),"muzzle":str(muzzle)}
func phase(label: String) -> void:
	var row: Dictionary=owner.snapshot() if owner!=null else {}
	var state:={"label":label,"at_ms":Time.get_ticks_msec(),"actor":str(owner._token.source_id) if owner!=null else "","hp":row.get("row",{}).get("hp"),"dead":row.get("row",{}).get("dead",false),"medical":row.get("row",{}).get("_medicalDowned",false),"physical":row.get("physical",{}),"ammo":weapons.fire_state.magazine if is_instance_valid(weapons) else -1,"shots":shots.size()}
	phases.append(state); print("PHASE ",JSON.stringify(state))
	if not out.is_empty(): FileAccess.open(out.path_join("PHASE.json"),FileAccess.WRITE).store_string(JSON.stringify(state))
func capture(label: String) -> void:
	if done or DisplayServer.get_name()=="headless" or out.is_empty(): return
	observer.global_position=target_point()+Vector3(4.2,2.0,4.2)
	observer.look_at(target_point(),Vector3.UP); observer.make_current()
	var before:=draws
	await sync(3)
	check(draws>before,"rendered:"+label)
	if draws>before:
		var result: int=root.get_texture().get_image().save_png(out.path_join(label+".png"))
		check(result==OK,"capture:"+label)
		if result==OK: images.append(label+".png")
func fire_once(label: String) -> void:
	for i in 180:
		if done: return
		if float(weapons.fire_state.cooldown)<=0 and float(weapons.fire_state.reloadRemaining)<=0: break
		await sync()
	var sight:=real_sight()
	check(sight.ok,label+":camera_and_actual_muzzle_reach_actor:"+str(sight))
	if not sight.ok: return
	var ammo: int=weapons.fire_state.magazine
	var emitted: int=weapons.shots_count
	var before_impacts:=impacts.size()
	player._unhandled_input(mouse(true)); await sync(2)
	player._unhandled_input(mouse(false)); await sync(24)
	check(weapons.shots_count==emitted+1,label+":one_actual_input_shot")
	check(weapons.fire_state.magazine==ammo-1,label+":one_inventory_round_spent")
	check(impacts.size()>before_impacts,label+":actual_native_impact")
	phase(label)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): out=arg.trim_prefix("--qa-out=")
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	create_timer(45.0).timeout.connect(func():
		if not done: check(false,"bounded_timeout"); finish())
	RenderingServer.frame_post_draw.connect(func(): draws+=1)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
		DisplayServer.window_set_title("Мафиози — проверка попаданий NPC")
	scene=load("res://scenes/main.tscn").instantiate()
	scene.preview_resident_walk_enabled=false
	root.add_child(scene); await sync(4)
	check(scene.preview_ready and scene.preview_population.combat_status=="new_local_session","actual_main_bound_HP")
	if not scene.preview_ready or scene.preview_population.hit_owners.size()!=3: finish(); return
	player=scene._player; weapons=scene.preview_weapons
	for action: StringName in [player.ACTION_LEFT,player.ACTION_RIGHT,player.ACTION_FORWARD,player.ACTION_BACK,player.ACTION_RUN,player.ACTION_JUMP]:
		Input.action_release(action); InputMap.action_erase_events(action)
	player._unhandled_input(mouse(true)); player._unhandled_input(mouse(false))
	scripted_controls=true; controls()
	check(weapons.equip("revolver").get("ok",false),"actual_revolver_equip")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	observer=Camera3D.new(); scene.add_child(observer); observer.fov=65
	weapons.shot_emitted.connect(func(shot: Dictionary,muzzle: Dictionary,_origin: Vector3,_direction: Vector3):
		check(muzzle.get("ok",false) and muzzle.pose_revision==player._pose_revision,"actual_shot_fresh_presented_muzzle")
		shots.append({"shot_id":shot.shotId,"muzzle":str(muzzle),"ammo_after_commit":weapons.fire_state.magazine}))
	weapons.effects.cosmetic_impact.connect(func(impact: Dictionary):
		impacts.append({"shot_id":impact.shotId,"point":str(impact.point),"collider":str(impact.collider.get_path()) if impact.collider is Node else str(impact.collider)})
		print("NATIVE_IMPACT ",JSON.stringify(impacts[-1])))
	var found:=false
	for candidate: RefCounted in scene.preview_population.hit_owners:
		owner=candidate; tracking=true; target_fallen=false; aim(); await sync(8)
		var sight:=real_sight()
		print("NATIVE_AIM ",candidate._token.source_id," ",sight)
		if sight.ok: found=true; break
	check(found,"one_actor_reachable_from_real_player_muzzle")
	if not found: finish(); return
	phase("before_hit"); await capture("01_before_hit")
	# Seed only source survival choice, never a hit, HP value or death decision.
	var sample:=RandomNumberGenerator.new()
	for seed_value in 100:
		sample.seed=seed_value; sample.randf()
		if sample.randf()<.72: owner._rng.seed=seed_value; break
	await fire_once("first_input_hit")
	var snapshot: Dictionary=owner.snapshot()
	check(snapshot.row.hp==1 and snapshot.row.get("_medicalDowned",false) and not snapshot.row.get("dead",false),"input_hit_genuine_medical_survival")
	check(snapshot.physical.get("ok",false),"input_hit_actual_physical_fall")
	if not snapshot.physical.get("ok",false): finish(); return
	check(not scene.preview_population.residents._ragdolls[owner._token.source_id]._eyes.closed,"medical survivor eyes remain open")
	target_fallen=true; await sync(60); await capture("02_medical_fall")
	await fire_once("second_input_hit")
	snapshot=owner.snapshot()
	check(owner.blood!=null and owner.blood._last_revision==owner.last_result.revision,"real input blood tracks accepted damage revision")
	check(snapshot.row.hp==0 and snapshot.row.get("dead",false) and snapshot.row.get("_deathFromDowned",false),"input_fallen_hit_final_death")
	check(scene.preview_population.residents._ragdolls[owner._token.source_id].status().final_dead,"same_physical_body_final_death")
	check(scene.preview_population.residents._ragdolls[owner._token.source_id]._eyes.closed,"final death closes original eyes")
	await capture("03_final_death"); finish()
func finish() -> void:
	if done: return
	done=true; tracking=false; scripted_controls=false
	if is_instance_valid(player): player._unhandled_input(mouse(false))
	var report:={"checks":checks,"errors":failures,"scope":"actual equip/input/presentation/muzzle/ammo/native ray/HP/physical lifecycle; stationary NPCs, QA camera, deterministic source survival seed","rendered":DisplayServer.get_name()!="headless","draws":draws,"phases":phases,"shots":shots,"impacts":impacts,"images":images,"test_sha256":FileAccess.get_sha256(get_script().resource_path)}
	if not out.is_empty(): FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	if is_instance_valid(scene): scene.queue_free()
	quit(0 if failures.is_empty() else 1)
