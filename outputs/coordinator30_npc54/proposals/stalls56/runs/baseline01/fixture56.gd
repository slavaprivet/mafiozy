extends SceneTree
const Account=preload("res://scripts/shop/npc_local_account.gd")
const Economy=preload("res://scripts/shop/npc_economy_visit28.gd")
const Route=preload("res://scripts/hospital/npc_restaurant_visit28.gd")
const Registry=preload("res://scripts/venues/npc_venue_registry29.gd")
const Life=preload("res://scripts/npc_daily_life.gd")
const Budget=preload("res://scripts/hospital/npc_route_budget29.gd")

class HostPort extends RefCounted:
	var _records: Dictionary={}
	func target_current(token: Dictionary) -> bool:
		return is_instance_valid(token.get("body")) and _records.has(token.source_id) and int(_records[token.source_id].generation)==int(token.life_generation)
class HealthPort extends RefCounted:
	var _host: RefCounted
	var _token: Dictionary={}
	var _ready:=true
	var _binding: Dictionary={}
	var _row: Dictionary={}
	func _current(_binding_value: Dictionary) -> Dictionary:return {"row":_row}
	func _now() -> float:return 1000.0
	func should_pause_walk() -> bool:return false
class WalkPort extends RefCounted:
	func cancel() -> Dictionary:return {"ok":true}

class Scene extends Node3D:
	var _origin:=Vector3(64,0,64)
	var _block: Dictionary={}
	var host=HostPort.new()
	var checks: Dictionary={}
	var details: Dictionary={}
	var lives: Array=[]
	var registry: RefCounted
	var fixed:=false
	var out:=""
	func _ready() -> void:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
			if arg=="--expect-fixed=1":fixed=true
		var grid: Array=[]
		for r: int in 128:
			var row: Array=[];row.resize(128);row.fill(0);grid.append(row)
		_block={"surface":{"cellSize":1.0,"startCol":0,"startRow":0,"grid":grid,"palette":{"0":{"kind":"grass","solid":true,"heightM":0.0},"1":{"kind":"water","solid":false,"heightM":-1.0}}}}
		var floor_body:=StaticBody3D.new();floor_body.collision_layer=1;floor_body.collision_mask=1
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(128,1,128);shape.shape=box;floor_body.add_child(shape);add_child(floor_body);floor_body.position.y=-.5
		_run.call_deferred()
	func _make(index: int) -> RefCounted:
		var id:="fixture_"+str(index)
		var body:=CharacterBody3D.new();body.collision_layer=1;body.collision_mask=1
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.7;shape.shape=capsule;shape.position.y=.85;body.add_child(shape);add_child(body);body.position=Vector3(-40+(index%25)*2,.003,-40+floori(float(index)/25)*2)
		var token: Dictionary={"source_id":id,"body":body,"bridge_id":id,"descriptor_sha256":"controlled_fixture","life_generation":1,"session_id":"stalls56_fixture"}
		host._records[id]={"generation":1,"row":{"source_id":id,"descriptor_sha256":"controlled_fixture","source_raw":{"id":id,"_arcKey":"worker"},"bridge_row":{"id":id,"role":"worker"}}}
		var health:=HealthPort.new();health._host=host;health._token=token;health._row={"source_id":id,"life_generation":1,"hp":60.0,"max_hp":60.0}
		var account=Account.new()
		assert(account.configure(host,token,health).ok)
		var life=Life.new();life._host=host;life._health=health;life._token=token;life._account=account;life._walk=WalkPort.new();life._now=1000.0;life._phase="IDLE"
		var economy=Economy.new();assert(economy.configure(life,account,self,RID()).ok);life._economy28=economy
		lives.append(life)
		return life
	func _full_venue() -> void:
		registry=Registry.for_scene(self);registry._next_refresh=2147483647;registry._next_reap=2147483647
		var owner:=Node3D.new();var clone:=Node3D.new();add_child(owner);add_child(clone)
		registry._entries["shop"]={"kind":"shop","owner":weakref(owner),"clone":weakref(clone),"normal":Vector3.FORWARD,"door":Vector3(40,0,40),"outside":Vector3(40,0,38)}
		registry.ledger.register("shop","shop",4)
		for i: int in 4:
			var row: Dictionary=registry.ledger.request("fixture_capacity_holder_"+str(i),"shop",[{"venue":"shop","cost":1.0}],1000)
			assert(row.state=="reserved")
			registry.ledger.touch("fixture_capacity_holder_"+str(i),1000)
	func _run() -> void:
		await get_tree().physics_frame
		await get_tree().physics_frame
		_full_venue()
		var admitted:=0;var rejected:=0;var protected:=0;var retained:=0
		for i: int in 287:
			var life: RefCounted=_make(i)
			var visit: RefCounted=life._economy28
			visit._choose_purchase("shop",true)
			# Controlled route-port setup. The ledger/account/visit implementations are
			# production; this fixture does NOT claim city geometry entry or payment.
			var route=Route.new();route._body=life._token.body;route._scene=self;route._id=life._token.source_id;route._kind="shop";route._key=Registry.life_key(route._id,route._body);route._registry=registry;route._phase="WAITING"
			var row: Dictionary=registry.request(route._id,route._body,route,"shop",1000)
			assert(row.state=="waiting")
			visit._route=route;visit._phase="WAITING";visit._kind="shop"
			var before: Dictionary=life._account.snapshot().account
			var reservation: Dictionary=life._account.begin_economy28(visit,"shop",1000)
			if reservation.ok: admitted+=1;visit._serial=reservation.serial
			elif reservation.get("reason")=="physical_route_required":rejected+=1
			var settled: Dictionary=life._account.settle_economy28(visit,"shop",visit.required_cash(),1000)
			if not settled.ok and life._account.snapshot().account==before:protected+=1
			if registry.owns(route._key,route):retained+=1
		checks.full_287_admission=admitted==287 if fixed else rejected==287
		checks.no_waiting_payment=protected==287
		checks.real_queue_retained=retained==287 and registry.ledger.snapshot().waiting==287
		var first: RefCounted=lives[0]._economy28._route
		registry.ledger.release("fixture_capacity_holder_0",1000,"fixture_free_slot")
		var promoted: Dictionary=registry.ledger.poll(first._key,1000)
		checks.fifo_promotion=promoted.state=="reserved" and registry.ledger.requests[lives[1]._economy28._route._key].state=="waiting"
		for life: RefCounted in lives:
			life._economy28.cancel("fixture_owner_cancel")
		checks.all_claims_cancelled=registry.ledger.requests.size()==3 and registry._actors.is_empty()
		registry.ledger.request("fixture_capacity_holder_0","shop",[{"venue":"shop","cost":1.0}],1000);registry.ledger.touch("fixture_capacity_holder_0",1000)
		var optional: RefCounted=lives[0];var econ: RefCounted=optional._economy28
		econ._choose_purchase("shop",false)
		var saved: Dictionary=econ._pending.duplicate(true);var cash: int=optional._account._account.cash
		var began: bool=econ.begin("shop",1000)
		checks.optional_real_route_result=not began and econ._reason==("optional_capacity_deferred" if fixed else "physical_route_required")
		checks.optional_goal_money_preserved=econ._pending==saved and optional._account._account.cash==cash and registry._actors.is_empty()
		optional._now=1001
		var intercept: bool=optional._economy28_try_begin(optional._health._row)
		checks.cooldown_allows_normal_decision=not intercept if fixed else intercept
		checks.cooldown_does_not_cancel_activity=not optional.dsh_economy_priority_pending() if fixed else optional.dsh_economy_priority_pending()
		# Existing urgent food flag remains stronger than discretionary cooldown.
		econ.request_food()
		checks.hunger_keeps_priority=optional.dsh_economy_priority_pending()
		if fixed:checks.hunger_not_optional=not econ.optional_retry56(optional._now)
		checks.pending_purchase_retained=econ._pending.price==saved.price and econ._pending.restore_energy
		checks.no_route_jobs_after_cancel=Budget.diagnostics().jobs==0
		details={"admitted":admitted,"baseline_rejected":rejected,"protected_wallets":protected,"waiting_claims":retained,"optional_reason":econ._reason,"optional_retry_ms":econ._retry_at-1000,"full_city_entry_test":false,"performance_accepted":false}
		var passed:=true
		for value: bool in checks.values():passed=passed and value
		for life: RefCounted in lives:life._economy28.cancel("fixture_end");life._account.dispose()
		var file:=FileAccess.open(out+"/RESULT.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"fixed":fixed,"checks":checks,"details":details},"\t"));file.close()
		print("STALLS56 ",JSON.stringify({"passed":passed,"checks":checks.size(),"details":details}))
		get_tree().quit(0 if passed else 1)

func _initialize() -> void:
	var scene:=Scene.new();root.add_child.call_deferred(scene);set_deferred("current_scene",scene)
