extends SceneTree
const Simple = preload("res://scripts/hospital/npc_simple_hospital.gd")
const Budget = preload("res://scripts/hospital/npc_route_budget29.gd")
const Economy = preload("res://scripts/shop/npc_economy_visit28.gd")
class PolicyLife extends RefCounted:
	func _hospital51_below_threshold(_row:Dictionary)->bool:return false
	func dsh_energy_on()->bool:return false
class PolicyAccount extends RefCounted:
	var releases:=0
	func snapshot()->Dictionary:return {"conserved":true,"account":{"cash":80}}
	func release_economy28(_owner:RefCounted)->void:releases+=1
class PolicyEconomy extends Economy:
	func current()->bool:return true
class OutcomeBridge extends RefCounted:
	var outcome:=""
	var reason:=""
	func step(_delta:float)->String:return outcome
	func last_reason()->String:return reason
	func needs_exit()->bool:return false
	func cancel()->void:pass
class TestWorld extends Node3D:
	var _origin := Vector3(50,0,50)
	var _block: Dictionary = {"surface":{"cellSize":100.0,"startCol":0,"startRow":0,"grid":[[0]],"palette":{"0":{"kind":"ground","solid":true,"heightM":0.0},"1":{"kind":"water","solid":false,"heightM":-1.0}}}}
var world: Node3D
var actor: CharacterBody3D
var output := ""
var checks: Array[Dictionary] = []
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=")
	_run.call_deferred()
func check(label:String,ok:bool,extra:Dictionary={}) -> void:
	extra.merge({"label":label,"passed":ok});checks.append(extra)
func box(at:Vector3,size:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var resource:=BoxShape3D.new()
	resource.size=size;shape.shape=resource;body.add_child(shape);world.add_child(body);body.position=at;return body
func finish(drive:RefCounted,seconds:float)->String:
	var deadline:int=Time.get_ticks_msec()+int(seconds*1000.0);var result:=""
	while Time.get_ticks_msec()<deadline and drive.active():
		await physics_frame;result=drive.step(1.0/60.0)
		if result in ["arrived","blocked"]:break
	return result
func _run()->void:
	world=TestWorld.new();root.add_child(world);current_scene=world
	box(Vector3(0,-.1,0),Vector3(60,.2,60))
	actor=CharacterBody3D.new();actor.collision_layer=1;actor.collision_mask=1
	var shape:=CollisionShape3D.new();var cap:=CapsuleShape3D.new();cap.radius=.36;cap.height=1.9
	var initial_radius:float=cap.radius;var initial_height:float=cap.height
	shape.shape=cap;shape.position.y=.95;actor.add_child(shape);world.add_child(actor);actor.position=Vector3(-10,.003,0)
	await physics_frame;await physics_frame
	var wall:StaticBody3D=box(Vector3(0,2.0,0),Vector3(1,4,65))
	await physics_frame;await physics_frame
	var drive:RefCounted=Simple.new();var goal:=Vector3(8,.003,0)
	check("begin_real_unreachable_service",drive.begin(goal,actor,RID(),"service_guard30","service_approach"))
	var result:String=await finish(drive,20.0)
	var state:Dictionary=drive.service_watch_state30()
	check("unreachable_service_stops_bounded_work",result=="blocked" and drive.last_reason() in ["service_planning_work_limit30","service_local_wait_limit30"],{"result":result,"watch":state,"reason":drive.last_reason()})
	check("blocked_is_not_arrived",drive.distance_m()>10.0 and drive.phase()=="blocked" and drive.moved_m()<.01)
	check("blocked_releases_planner_memory",Budget.diagnostics().jobs==0 and Budget.diagnostics().nodes==0 and Budget.diagnostics().heap_items==0 and drive._route._nodes.is_empty() and drive._route._open.is_empty())
	# Feed this actual physical blocked outcome through the unchanged economy branch.
	# Life/account/outer-route bridge are test doubles; the guard result is native.
	var policy_life:=PolicyLife.new();var account:=PolicyAccount.new();var economy:=PolicyEconomy.new();var bridge:=OutcomeBridge.new()
	bridge.outcome=result;bridge.reason=drive.last_reason();economy._life=weakref(policy_life);economy._account=account;economy._route=bridge
	economy._kind="shop";economy._phase="INBOUND";economy._pending={"kind":"shop","price":17,"restore_energy":true};economy._planned_amount=17
	var pending:Dictionary=economy._pending.duplicate(true);economy.step(1.0/60.0,10000.0,{"hp":100.0})
	check("native_blocked_preserves_purchase_and_real_retry_branch",economy._pending==pending and economy._phase=="IDLE" and economy._retry_at==18000.0 and account.releases==1 and not economy._completion.completed and not economy._completion.committed)
	check("saved_purchase_available_after_cooldown",economy.desired_kind(17999.0)=="" and economy.desired_kind(18000.0)=="shop" and economy.required_cash()==17 and account.snapshot().account.cash==80)
	wall.queue_free();await physics_frame;await physics_frame
	check("retry_keeps_exact_target",drive.begin(goal,actor,RID(),"service_guard30","service_approach") and drive.target()==goal)
	result=await finish(drive,15.0)
	check("same_body_walks_after_obstacle_removed",result=="arrived" and drive.distance_m()<Simple.ARRIVE_M,{"result":result,"position":actor.global_position,"watch":drive.service_watch_state30()})
	var next:Vector3=actor.global_position+Vector3(3,0,0)
	drive.begin(next,actor,RID(),"service_guard30","service_approach")
	for tick in 20:await physics_frame;drive.step(1.0/60.0)
	var before:Dictionary=drive.service_watch_state30();var held:bool=drive.attention_pause29()
	for tick in 180:await physics_frame;drive.attention_hold29(1.0/60.0)
	check("service_attention_does_not_charge_work_or_motion",held and before==drive.service_watch_state30())
	var position:Vector3=actor.global_position;drive.attention_resume29()
	await physics_frame;drive.step(1.0/60.0)
	check("service_ready_resume_moves_first_frame",Simple._flat(position,actor.global_position)>.005)
	result=await finish(drive,8.0);check("service_resume_arrives",result=="arrived")
	for cycle in 24:
		drive.begin(actor.global_position+Vector3(3,0,0),actor,RID(),"service_guard30","service_approach")
		await physics_frame;drive.step(1.0/60.0);drive.cancel();drive.cancel()
		check("cancel_soak_"+str(cycle),Budget.diagnostics().jobs==0 and Budget.diagnostics().nodes==0 and Budget.diagnostics().heap_items==0 and drive._route._nodes.is_empty())
	check("capsule_and_collision_unchanged",cap.radius==initial_radius and cap.height==initial_height and actor.collision_layer==1 and actor.collision_mask==1)
	var passed:bool=checks.all(func(row:Dictionary)->bool:return row.passed)
	var report:Dictionary={"passed":passed,"checks":checks,"native_physics":true,"fixture_bodies":1,"body_relocated_after_begin":false,"synthetic_planner_counters":false,"economy_branch_is_real":true,"economy_life_account_and_outcome_bridge_are_test_doubles":true,"performance_accepted":false}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SERVICE_GUARD30 ",JSON.stringify(report));quit(0 if passed else 1)
