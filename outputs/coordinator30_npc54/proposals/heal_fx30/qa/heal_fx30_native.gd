extends SceneTree
const Fx30 = preload("res://scripts/npc_visual/npc_heal_fx30.gd")
var output := ""
var failures: Array[String] = []
var checks: Array[String] = []
var evidence: Dictionary = {}

class PoolHealth30 extends RefCounted:
	var _ready := true
	var _token: Dictionary = {}
	var _row: Dictionary = {}
	var _binding: Dictionary = {}
	var _adapter: RefCounted
	func _current(_binding30: Dictionary) -> Dictionary: return {}

func check(value: bool, label: String) -> void:
	checks.append(label)
	if not value: failures.append(label)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var marker := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): output=arg.trim_prefix("--qa-out=")
		if arg.begins_with("--qa-ready="): marker=arg.trim_prefix("--qa-ready=")
	var deadline: int=Time.get_ticks_msec()+30000
	while not marker.is_empty() and not FileAccess.file_exists(marker):
		if Time.get_ticks_msec()>deadline: quit(2); return
		await create_timer(.05).timeout
	create_timer(245.0).timeout.connect(func(): check(false,"bounded native QA deadline");finish())
	var scene: Node3D=load("res://scenes/main_city.tscn").instantiate();root.add_child(scene);current_scene=scene
	deadline=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		var pop: RefCounted=scene.get("preview_population")
		if pop!=null and pop.get("city_ready")==true:break
		await process_frame
	var pop: RefCounted=scene.get("preview_population")
	if pop==null or pop.get("city_ready")!=true:check(false,"actual city ready");finish();return
	var life: RefCounted=pop.daily._lives.get("resident_1")
	if life==null:check(false,"actual resident life");finish();return
	var health: RefCounted=life._health
	var body: CharacterBody3D=life._token.body
	check(scene.get_node_or_null(Fx30.POOL_NAME30)==null,"bootstrap/full-life initialization creates no effect pool")
	check(not Fx30.confirmed30(health,"invented_receipt"),"invented healing event rejected")
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=54
	for layer: Node in scene.find_children("*","CanvasLayer",true,false):layer.visible=false
	var previous_hp: float=float(health._row.hp)
	var observed_drop := previous_hp<float(health._row.max_hp)
	var waited_without_fx := false
	deadline=Time.get_ticks_msec()+150000
	var healed := false
	while Time.get_ticks_msec()<deadline:
		await physics_frame;await process_frame
		var inward:=Vector3.FORWARD
		if life._dsh_simple!=null and life._dsh_simple._inward.length_squared()>.5:inward=life._dsh_simple._inward
		var right: Vector3=Vector3.UP.cross(inward)
		camera.global_position=body.global_position-inward*2.7+right*.7+Vector3.UP*1.65
		camera.look_at(body.global_position+Vector3.UP*1.1)
		var hp: float=float(health._row.hp)
		if hp<previous_hp:observed_drop=true
		var pool: Node=scene.get_node_or_null(Fx30.POOL_NAME30)
		if hp>previous_hp:
			healed=true
			check(pool!=null,"actual hospital positive HP delta creates pool")
			if pool==null:break
			evidence.heal={"before":previous_hp,"after":hp,"phase":life._hospital_stage,"receipt":health.last_result,"pool":pool.snapshot30(),"body_position":body.global_position}
			check(pool.snapshot30().events==1 and pool.snapshot30().active==4,"one real heal emits exactly four crosses")
			check(not Fx30.confirmed30(health,str(health.last_result.event_id)),"replaying same authoritative receipt emits nothing")
			await create_timer(.42).timeout
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output.path_join("heal_actual_hospital.png"))==OK,"real hospital render saved")
			await create_timer(1.65).timeout
			evidence.after_expiry=pool.snapshot30()
			check(pool.snapshot30().active==0 and not pool.is_processing() and pool.snapshot30().allocated==4,"four crosses expire and pool sleeps without growing")
			break
		if life._hospital_stage=="TREATING":
			waited_without_fx=true
			check(pool==null,"treatment waiting does not emit")
		previous_hp=hp
	check(healed,"actual physical hospital heal completed")
	check(observed_drop,"injured resident before hospital has no regeneration effect")
	check(waited_without_fx,"observed real treatment waiting phase")
	_pool_contracts(scene)
	finish()

func _pool_contracts(scene: Node3D) -> void:
	# Isolated emitter mechanics: these synthetic rows do not authorize HP/effects
	# through confirmed30 and never alter the real resident or its receipts.
	var pool:=Fx30.new();pool.name="IsolatedPoolRegression30";scene.add_child(pool)
	var body:=CharacterBody3D.new();scene.add_child(body)
	var health:=PoolHealth30.new();health._token={"body":body,"life_generation":7};health._row={"life_generation":7,"hp":50,"dead":false}
	check(not Fx30.confirmed30(health,"synthetic_positive_delta"),"unbound synthetic HP increase cannot authorize FX")
	for index: int in 8:pool._emit30(health,body,50,7)
	check(pool.snapshot30().allocated==12 and pool.snapshot30().active==12 and pool.snapshot30().peak==12,"burst flood remains bounded at twelve reusable slots")
	pool._process(2.0)
	check(pool.snapshot30().active==0 and pool.snapshot30().released==12 and not pool.is_processing(),"flood expires fully and sleeps")
	pool._emit30(health,body,50,7);health._row.hp=49;pool._process(.01)
	check(pool.snapshot30().active==0,"actual HP drop cancels existing crosses")
	health._row.hp=50;pool._emit30(health,body,50,7);health._row.dead=true;pool._process(.01)
	check(pool.snapshot30().active==0,"death cancels existing crosses")
	health._row.dead=false;pool._emit30(health,body,50,7);health._token.life_generation=8;pool._process(.01)
	check(pool.snapshot30().active==0,"new life generation cannot retain old crosses")
	health._token.life_generation=7;pool._emit30(health,body,50,7);health._ready=false;pool._process(.01)
	check(pool.snapshot30().active==0,"health disposal cancels existing crosses")
	health._ready=true;pool._emit30(health,body,50,7);body.free();pool._process(.01)
	check(pool.snapshot30().active==0,"freed body releases weak slots safely")
	evidence.pool_contracts=pool.snapshot30()
	check(pool.snapshot30().allocated==12,"repeated events reuse the same bounded pool")
	pool.free()

func finish() -> void:
	var result: Dictionary={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"evidence":evidence,"performance_accepted":false,"real_hospital_required":true}
	var file:=FileAccess.open(output.path_join("HEAL_FX30.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("HEAL_FX30 ",result.status," checks=",checks.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
