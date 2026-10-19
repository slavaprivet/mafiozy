extends SceneTree
## Actual Account/ShopVisit/DailyShop/Life handlers; after-entry fixtures only.
## This does not certify the real printshop route, door geometry, or city arrival.
const Account = preload("res://scripts/shop/npc_local_account.gd")
const Visit = preload("res://scripts/shop/npc_local_shop_visit.gd")
const DailyShop = preload("res://scripts/shop/npc_daily_shop.gd")
const Life = preload("res://scripts/npc_daily_life.gd")

class InteriorFixture:
	extends Node3D
	const SOURCE_ID := "REBUILD-VISUAL-print_shop-001"
	var ready_for_use := true
	func door_fraction(key: String) -> float: return 1.0 if key == "public" else 0.0

class PopulationFixture:
	extends RefCounted
	func door_started(_door: String, _opening: bool) -> void: pass

class WorldFixture:
	extends Node3D
	var preview_population: RefCounted
	func _current_door_occupants() -> Array: return []

class HealthFixture:
	extends RefCounted
	var _host: RefCounted
	var _token := {}
	var _binding := {}
	var _row := {}
	var _ready := true
	var paused := false
	var now := 0.0
	func _now() -> float: return now
	func should_pause_walk() -> bool: return paused
	func _current(_binding_arg: Dictionary) -> Dictionary:
		return {"row":_row} if _host.target_current(_token) else {}

class HostFixture:
	extends RefCounted
	var _records := {}
	var token := {}
	var route: RefCounted
	var health: RefCounted
	var owner: RefCounted
	var alive := true
	var bound := true
	var arrived := false
	var releases := 0
	var refuse_release := false
	var outside_x := 0.0
	func target_from_collider(body: Node) -> Dictionary: return token if body == token.body else {}
	func target_current(value: Dictionary) -> bool:
		return alive and value == token and is_instance_valid(token.get("body")) and token.body.is_inside_tree()
	func walk_pause() -> bool: return health.paused
	func daily_activity_status(_id: String) -> Dictionary:
		return {"current":alive,"owner":owner,"life_generation":token.life_generation}
	func local_navigation_adapter_status() -> Dictionary:
		return {"bound":bound,"source_id":token.source_id,"serial":5}
	func cancel_local_walk(request_owner: RefCounted, value: Dictionary, request: int) -> Dictionary:
		if request_owner != route or not target_current(value) or int(_records[token.source_id].request) != request:
			return {"ok":false,"reason":"fixture_exact_owner_required"}
		route.cancel(request)
		return {"ok":true,"cancelled_request_id":request}
	func release_local_navigation_adapter(request_owner: RefCounted, value: Dictionary) -> Dictionary:
		if refuse_release or request_owner != route or not target_current(value) or int(_records[token.source_id].request) >= 0:
			return {"ok":false,"reason":"fixture_release_unconfirmed"}
		bound=false; releases+=1
		return {"ok":true}
	func _source_admits(point: Vector3, _record: Dictionary, _purpose: String) -> bool:
		return target_current(token) and point.x >= outside_x - .2
	func _physical_clear(point: Vector3, _excluded: Array[RID]) -> bool:
		return route._capsule_clear(point) and route._native_square_clear(point,point)

class RouteFixture:
	extends RefCounted
	var host: RefCounted
	var token := {}
	var interior: Node3D
	var world: Node3D
	var floor_rid: RID
	var _phase := "READY"
	var _disposed := false
	var _floors := {}
	var target := Vector3.ZERO
	var _return := Vector3.ZERO
	var _street_return := Vector3.ZERO
	var next_request := 10
	func _current() -> bool:
		var claim: Variant=host._records[token.source_id].get("local_route_owner")
		return not _disposed and host.target_current(token) and claim is WeakRef and claim.get_ref() == self
	func _source_segment(from: Vector3, to: Vector3) -> bool:
		if not _current() or from != to: return false
		for offset: Vector2 in [Vector2.ZERO,Vector2(-.738,-.738),Vector2(-.738,.738),Vector2(.738,-.738),Vector2(.738,.738)]:
			var at: Vector3=to+Vector3(offset.x,0,offset.y)
			var ray:=PhysicsRayQueryParameters3D.new()
			ray.from=at+Vector3.UP*.3; ray.to=at-Vector3.UP*.3
			ray.collision_mask=1; ray.exclude=[token.body.get_rid()]
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.rid != floor_rid or hit.normal.y < .7: return false
		return true
	func _capsule_clear(point: Vector3) -> bool:
		var collider: CollisionShape3D=token.body.get_child(0)
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=collider.shape; query.collision_mask=1|256; query.exclude=[token.body.get_rid()]
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.97)
		return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	func _native_square_clear(from: Vector3, to: Vector3) -> bool:
		if from != to: return false
		var box:=BoxShape3D.new(); box.size=Vector3(1.476,1.9,1.476)
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=box; query.collision_mask=1|256; query.exclude=[token.body.get_rid()]
		query.transform=Transform3D(Basis.IDENTITY,to+Vector3.UP*.975)
		return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	func request_route(point: Vector3, phase: String, _tolerance: float, value: Dictionary) -> Dictionary:
		if not _current() or value != token or not _capsule_clear(token.body.global_position):
			return {"accepted":false}
		next_request+=1; target=point; _phase=phase; host.arrived=false
		host._records[token.source_id].request=next_request
		return {"accepted":true,"request_id":next_request}
	func poll(request: int) -> Dictionary:
		return {"status":"ARRIVED" if host.arrived else "READY"} if request == next_request else {"status":"STALE"}
	func cancel(request: int) -> void:
		if int(host._records[token.source_id].request) == request: host._records[token.source_id].request=-1
	func dispose() -> void: _disposed=true

var checks: Array[Dictionary] = []
var expect_legacy := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--shop-canary-expect-legacy=1": expect_legacy=true
	call_deferred("_run")

func _expect(ok: bool, label: String, detail: Dictionary={}) -> void:
	checks.append({"ok":ok,"label":label,"detail":detail})
	if not ok: push_error("SHOP_COMPLETION_CANARY "+label)

func _fixture() -> Dictionary:
	var entry: PackedByteArray=FileAccess.get_file_as_bytes("res://data/LOCAL_PRINTSHOP_ENTRY.json")
	var data: Dictionary=JSON.parse_string(entry.get_string_from_utf8())
	var inside:=Vector3(float(data.public_inside_preview[0]),float(data.public_inside_preview[1]),float(data.public_inside_preview[2]))
	var outside:=Vector3(float(data.public_approach_preview[0]),float(data.public_approach_preview[1]),float(data.public_approach_preview[2]))
	var world:=WorldFixture.new(); world.preview_population=PopulationFixture.new(); root.add_child(world)
	var floor_body:=StaticBody3D.new(); floor_body.collision_layer=1
	var floor_shape:=CollisionShape3D.new(); var floor_box:=BoxShape3D.new()
	floor_box.size=Vector3(30,.2,30); floor_shape.shape=floor_box
	floor_body.add_child(floor_shape); floor_body.position=Vector3(6,inside.y-.1,6); world.add_child(floor_body)
	var body:=CharacterBody3D.new(); body.collision_layer=1; body.collision_mask=1
	var collider:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new()
	capsule.radius=.36; capsule.height=1.9; collider.shape=capsule; collider.position.y=.95
	body.add_child(collider); body.position=inside+Vector3.UP*.015; world.add_child(body)
	var interior:=InteriorFixture.new(); world.add_child(interior)
	var host:=HostFixture.new(); var health:=HealthFixture.new(); var route:=RouteFixture.new()
	var token: Dictionary={"ok":true,"source_id":"fixture_shop","session_id":"LOCAL_SHOP_REVIEW","life_generation":1,"body":body,"bridge_id":"fixture_bridge","descriptor_sha256":"fixture_descriptor"}
	var row: Dictionary={"source_id":token.source_id,"life_generation":1,"hp":60.0,"dead":false,"descriptor_sha256":token.descriptor_sha256,"source_raw":{"id":token.source_id,"_arcKey":"worker"},"bridge_row":{"id":token.bridge_id,"role":"worker","police":false,"empireBoss":false}}
	host.token=token; host.route=route; host.health=health; host.outside_x=outside.x
	host._records[token.source_id]={"body":body,"generation":1,"row":row,"request":-1,"local_route_owner":weakref(route),"walk_pause":host.walk_pause}
	health._host=host; health._token=token; health._row=row
	route.host=host; route.token=token; route.world=world; route.interior=interior; route.floor_rid=floor_body.get_rid()
	var account:=Account.new(); var admitted: Dictionary=account.configure(host,token,health)
	_expect(admitted.get("ok",false),"actual_account_configure",admitted)
	if not admitted.get("ok",false): world.queue_free(); return {}
	var life:=Life.new(); var shop:=DailyShop.new(); var visit:=Visit.new()
	host.owner=life
	shop._host=host; shop._health=health; shop._account=account; shop._scene=weakref(world); shop._owner=weakref(life)
	shop._token=token; shop._goal={"kind":"shop","goal_id":"fixture_shop:goal:1"}
	shop._route=route; shop._bound=true; shop._serial=5; shop._phase="VISIT"; shop._visit=visit
	shop._visit_started=true; shop._dsh_probe=0
	var configured: bool=visit.configure(host,interior,entry,"LOCAL_NPC_VISIT23:review",token.source_id,shop._request_visit,route.poll,shop._cancel_visit,shop._door_started,shop._occupants)
	_expect(configured and visit.bind_commerce(account,shop._goal.goal_id),"actual_visit_and_commerce_configure")
	if not configured: world.queue_free(); return {}
	# The fixture starts AFTER the real entry seam, physically grounded at pinned inside.
	visit._phase="BROWSING"; visit._since=0.0; visit._now=0.0; visit._until=3500.0
	visit._return=outside; visit._street_return=Vector3(8.5,inside.y,inside.z)
	route._return=visit._return; route._street_return=visit._street_return
	route._phase="ENTERING"
	life._host=host; life._token=token; life._health=health; life._account=account
	life._visit=shop; life._goal=shop._goal.duplicate(); life._phase="ACTIVITY"
	var f: Dictionary={"world":world,"body":body,"host":host,"health":health,"route":route,"visit":visit,"shop":shop,"life":life,"account":account,"inside":inside}
	await _ground(f,inside)
	_expect(body.is_on_floor(),"real_fixture_body_grounded")
	_tick(f,0.0)
	_expect(visit.commerce_service >= 0 and account._services.size()==1,"real_account_service_started")
	return f

func _ground(f: Dictionary, target: Vector3) -> void:
	# Only the isolated fixture mover writes this test body.
	var body: CharacterBody3D=f.body
	body.position=Vector3(target.x,float(f.inside.y)+.015,target.z)
	for _i in range(3):
		await physics_frame
		body.velocity=Vector3(0,-1,0); body.move_and_slide()

func _tick(f: Dictionary, now: float) -> void:
	f.health.now=now; f.shop._frame=-1; f.shop._step_impl(1.0/60.0)

func _paid(f: Dictionary) -> bool:
	return f.account._account.receipts.size()==1 and f.account._account.spent==3 and f.account.conserved()

func _cleanup(f: Dictionary) -> void:
	f.visit.commerce=null; f.visit._request=Callable(); f.visit._poll=Callable(); f.visit._cancel=Callable()
	f.visit._door_started=Callable(); f.visit._occupants=Callable()
	f.account.dispose(); f.life._visit=null; f.shop._visit=null; f.shop._route=null
	f.route.host=null; f.host.route=null; f.host.owner=null; f.host.health=null; f.host._records.clear()
	f.world.queue_free(); await process_frame

func _run() -> void:
	var normal: Dictionary=await _fixture()
	if normal.is_empty(): _finish(); return
	_tick(normal,3100.0)
	_expect(_paid(normal) and normal.visit.commerce_result.status=="COMPLETE","ordinary_checkout_commits_one_local_receipt")
	await _cleanup(normal)

	var delayed: Dictionary=await _fixture()
	if delayed.is_empty(): _finish(); return
	delayed.life._finish_activity(true,{"status":"COMPLETE","released":false})
	_expect(delayed.life._completed.shop==0 and delayed.life._visit==delayed.shop,"life_refuses_complete_before_release")
	_tick(delayed,4000.0)
	_expect(not _paid(delayed) if expect_legacy else _paid(delayed),"delayed_tick_legacy_cancels_or_candidate_commits",delayed.visit.commerce_result)
	if not expect_legacy:
		_tick(delayed,4000.0)
		_expect(_paid(delayed),"duplicate_poll_never_debits_twice")
		await _ground(delayed,delayed.visit._return)
		delayed.host.arrived=true; _tick(delayed,4200.0)
		await _ground(delayed,delayed.visit._street_return)
		delayed.host.refuse_release=true
		delayed.host.arrived=true; _tick(delayed,4400.0)
		_expect(not delayed.shop._released and delayed.shop._phase=="HOLD","unconfirmed_adapter_release_keeps_owner")
		delayed.life._finish_activity(true,delayed.shop.snapshot())
		_expect(delayed.life._completed.shop==0,"unconfirmed_release_never_counts_shop")
		delayed.host.refuse_release=false; _tick(delayed,4500.0)
		var state: Dictionary=delayed.shop.snapshot()
		_expect(state.status=="COMPLETE" and state.released and delayed.host.releases==1,"exit_street_return_exact_release_before_complete",state)
		delayed.life._now=4500.0; delayed.life._finish_activity(true,state)
		_expect(delayed.life._completed.shop==1 and delayed.life._phase=="IDLE" and delayed.life._goal.is_empty() and delayed.life._next_decision==5500.0,"released_shop_schedules_next_valid_decision")
	await _cleanup(delayed)

	var paused: Dictionary=await _fixture()
	if paused.is_empty(): _finish(); return
	paused.health.paused=true; _tick(paused,5000.0)
	_expect(not _paid(paused) and paused.visit._phase=="BROWSING","pause_defers_browse_and_account")
	paused.health.paused=false; _tick(paused,8100.0)
	_expect(_paid(paused),"resumed_checkout_commits_once")
	await _cleanup(paused)

	var ended: Dictionary=await _fixture()
	if ended.is_empty(): _finish(); return
	ended.host.alive=false; _tick(ended,4000.0)
	_expect(not _paid(ended) and ended.shop._phase!="COMPLETE","ended_life_never_buys_or_completes")
	await _cleanup(ended)

	var replaced: Dictionary=await _fixture()
	if replaced.is_empty(): _finish(); return
	var replacement:=RefCounted.new()
	replaced.host._records[replaced.host.token.source_id].local_route_owner=weakref(replacement)
	_tick(replaced,4000.0)
	_expect(not _paid(replaced) and not replaced.shop._released and replaced.host.releases==0,"replacement_route_owner_never_authorizes_checkout_or_release")
	await _cleanup(replaced)

	var blocked: Dictionary=await _fixture()
	if blocked.is_empty(): _finish(); return
	var obstacle:=StaticBody3D.new(); obstacle.collision_layer=256
	var obstacle_shape:=CollisionShape3D.new(); var obstacle_box:=BoxShape3D.new()
	obstacle_box.size=Vector3(.2,.5,.2); obstacle_shape.shape=obstacle_box; obstacle.add_child(obstacle_shape)
	obstacle.position=blocked.body.position+Vector3.UP*.8; blocked.world.add_child(obstacle)
	await physics_frame
	_tick(blocked,4000.0)
	_expect(not _paid(blocked),"new_physical_obstacle_prevents_receipt")
	await _cleanup(blocked)

	var forged: Dictionary=await _fixture()
	if forged.is_empty(): _finish(); return
	_tick(forged,3100.0); _tick(forged,4000.0)
	forged.host.arrived=true
	await physics_frame
	_tick(forged,4200.0)
	# The inner visit is HOLD; DailyShop retains VISIT while its unsafe unwind
	# waits. Assert ownership and non-completion, not the outer phase spelling.
	_expect(_paid(forged) and not forged.shop._released and forged.shop._phase!="COMPLETE" and forged.visit._phase=="HOLD" and forged.shop._same_lease() and forged.host.releases==0,"forged_exit_arrived_cannot_complete_without_physical_return",{"shop":forged.shop.snapshot(),"visit_phase":forged.visit._phase,"paid":_paid(forged),"body":forged.body.position})
	forged.life._finish_activity(true,forged.shop.snapshot())
	_expect(forged.life._completed.shop==0 and forged.life._visit==forged.shop,"unsafe_forged_return_retains_life_owner_without_completion")
	await _cleanup(forged)
	_finish()

func _finish() -> void:
	var failed:=0
	for check: Dictionary in checks:
		if not check.ok: failed+=1
	if checks.size()<18: failed+=1; push_error("SHOP_COMPLETION_CANARY insufficient checks")
	var report: Dictionary={"checks":checks,"failed":failed,"expected_legacy":expect_legacy,"scope":"actual_commerce_controllers_after_entry_fixture; not city physical acceptance"}
	print("SHOP_COMPLETION_CANARY "+JSON.stringify(report))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shop-review-result="):
			var file:=FileAccess.open(arg.trim_prefix("--shop-review-result="),FileAccess.WRITE)
			if file==null: failed+=1; push_error("SHOP_COMPLETION_CANARY result write failed")
			else: file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
	await create_timer(2.0).timeout
	quit(1 if failed>0 else 0)
