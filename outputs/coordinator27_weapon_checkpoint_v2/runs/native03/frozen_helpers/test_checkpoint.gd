extends SceneTree
const Checkpoint=preload("checkpoint.gd")
var scene: Node3D
var p: CharacterBody3D
var w: Node
var c: Node
var t: Node3D
var out:=""
var checks:=0
var errors:Array[String]=[]
var phases:Array[Dictionary]=[]
var done:=false
var durations:Array[int]=[]
func _initialize()->void: run.call_deferred()
func check(value:bool,label:String)->bool:
	checks+=1
	if not value: errors.append(label);print("FAIL ",label)
	return value
func tick(n:int=1)->void:
	for i:int in n: await physics_frame;await process_frame
func key(code:int)->void:
	for down:bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func invariant()->String:
	var npcs:Array=[]
	for owner:RefCounted in scene.preview_population.hit_owners:
		npcs.append({"id":owner._token.source_id,"life":owner._token.life_generation,"body":owner._token.body.get_instance_id(),"rig":owner._token.rig.get_instance_id(),"row":owner.snapshot().row})
	return Checkpoint.canonical({"inventory":w.inventory.snapshot(),"identities":w.inventory.item_identity_snapshot(),"cargo":c.cargo.snapshot(c.generation),"fire":w.fire_state,"player_position":p.position,"player_actor":p.get_meta("actor_id"),"player_life":p.get_meta("life_generation"),"player_epoch":p._pose_epoch,"npcs":npcs,"scene_dead":scene.preview_dead,"source_session":t.runtime.host.diagnostics().session})
func sample(label:String)->Dictionary:
	var before:=invariant()
	var started:=Time.get_ticks_usec()
	var capture:=Checkpoint.capture(scene)
	durations.append(Time.get_ticks_usec()-started)
	check(invariant()==before,label+": read-only capture preserves all live identities/state/HP/pose")
	if not check(capture.ok,label+": capture "+str(capture.get("reason",""))):return {}
	var encoded:=Checkpoint.encode(capture.document)
	if not check(encoded.ok,label+": encode"):return {}
	var decoded:=Checkpoint.decode(encoded.text)
	if not check(decoded.ok,label+": decode "+str(decoded.get("reason",""))):return {}
	check(Checkpoint.canonical(capture.document)==Checkpoint.canonical(decoded.document),label+": canonical complete roundtrip")
	var plan:=Checkpoint.plan(decoded.document,capture.document)
	check(plan.ok and plan.restore_authorized==false and plan.effects_applied==0 and plan.server_grants==0,label+": plan only; no adoption/grant")
	check(Checkpoint.canonical(plan)==Checkpoint.canonical(Checkpoint.plan(decoded.document,capture.document)),label+": plan idempotent")
	check(invariant()==before,label+": codec and plan have no live effects")
	FileAccess.open(out.path_join(label+".json"),FileAccess.WRITE).store_string(encoded.text)
	phases.append({"label":label,"sha256":encoded.sha256,"items":plan.items,"ammo_total":plan.ammo_total,"locations":plan.locations,"capture_us":durations[-1]})
	return capture.document
func reject(changed:Dictionary,current:Dictionary,reason:String)->void:
	var actual:=Checkpoint.plan(changed,current)
	check(not actual.ok and actual.reason==reason,"negative "+reason+": "+str(actual))
func invalid_plain_paths(value:Variant,path:String="root")->Array:
	var found:Array=[]
	if Checkpoint.finite_plain(value):return found
	if value is Dictionary:
		if value.has("@f64"):found.append(path+": reserved "+str(value))
		for k:Variant in value:found.append_array(invalid_plain_paths(value[k],path+"."+str(k)))
	elif value is Array:
		for i:int in value.size():found.append_array(invalid_plain_paths(value[i],path+"["+str(i)+"]"))
	else:found.append(path+": type="+str(typeof(value))+" value="+str(value))
	return found
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
	if out.is_empty():quit(2);return
	create_timer(65).timeout.connect(func():
		if not done:check(false,"bounded65s deadline");finish())
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i:int in 180:
		await tick()
		if scene.preview_ready:break
	if not check(scene.preview_ready,"actual48 scene ready"):finish();return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo")
	p.set_mouse_captured(true);await tick(30)
	check(scene.preview_population.hit_owners.size()==3,"all original three NPC present")
	check(w.equip("tt_pistol").get("ok",false),"actual native TT equip")
	await tick(2)
	var original_uid:String=w.inventory.get_item_uid("tt_pistol")
	var initial:=sample("initial")
	if initial.is_empty():finish();return
	var value:=initial.duplicate(true);value.schema="future/v999";reject(value,initial,"SCHEMA")
	value=initial.duplicate(true);value.actor.erase("actor_id");reject(value,initial,"MISSING_OWNER")
	value=initial.duplicate(true);value.session.session_id+="-foreign";reject(value,initial,"CROSS_SESSION")
	value=initial.duplicate(true);value.vehicles[0].life_generation+=1;reject(value,initial,"STALE_GENERATION")
	value=initial.duplicate(true);value.actor.life_generation+=1;reject(value,initial,"STALE_ACTOR_GENERATION")
	value=initial.duplicate(true);value.vehicles[0].revision+=1;reject(value,initial,"STALE_REVISION")
	value=initial.duplicate(true);value.pending_transactions=[{"request_id":"unresolved"}];reject(value,initial,"BUSY_RECONCILE")
	value=initial.duplicate(true);value.vehicles[0].pending=true;reject(value,initial,"BUSY_RECONCILE")
	value=initial.duplicate(true);value.authority="server_acknowledged";reject(value,initial,"AUTHORITY_RECONCILIATION_REQUIRED")
	value=initial.duplicate(true);value.inventory.identities.owned.erase("tt_pistol");reject(value,initial,"MISSING_IDENTITY")
	value=initial.duplicate(true);value.inventory.identities.owned.nagan=value.inventory.identities.owned.tt_pistol;reject(value,initial,"DUPLICATE_UID")
	value=initial.duplicate(true);value.inventory.fireStates.nagan.magazine=INF;reject(value,initial,"PLAIN_FINITE_LIMIT")
	value=initial.duplicate(true);value.inventory.fireStates.nagan.magazine=0.5;reject(value,initial,"OWNED_STATE")
	value=initial.duplicate(true);value.inventory.host_fire_state=[];reject(value,initial,"INVENTORY_SHAPE")
	value=initial.duplicate(true);value.vehicles=[];reject(value,initial,"MISSING_CARGO_OWNER")
	value=initial.duplicate(true);value.vehicles[0].destroyed=true;reject(value,initial,"DESTROY_RECONCILIATION_REQUIRED")
	var encoded:=Checkpoint.encode(initial)
	check(not Checkpoint.decode(encoded.text.substr(0,encoded.text.length()-1)).ok,"truncated document rejected")
	check(not Checkpoint.decode('{"schema":"duplicate",'+encoded.text.substr(1)).ok,"duplicate JSON key rejected")
	var fraction:float=0.1
	check(PackedFloat64Array([Checkpoint.unwire(Checkpoint.wire(fraction))]).to_byte_array()==PackedFloat64Array([fraction]).to_byte_array(),"fractional binary64 wire preserves exact bits")
	check(Checkpoint.unwire({"@f64":"zzzzzzzzzzzzzzzz"})==null,"invalid float tag fails closed")
	check(Checkpoint.unwire({"@f64":"000000000000f87f"})==null,"NaN float tag fails closed")
	value=initial.duplicate(true)
	value.inventory.fireStates.nagan.magazine=float(value.inventory.fireStates.nagan.magazine)
	check(Checkpoint.encode(value).ok,"source integer-valued float ammo accepted")
	# Reserved wire tags cannot appear as plaintext user fields at any depth.
	value=initial.duplicate(true);value.inventory.fireStates.nagan.extra={"@f64":"9a9999999999b93f"}
	check(not Checkpoint.encode(value).ok,"reserved wire dictionary collision rejected before encoding")
	value=initial.duplicate(true);value.inventory.fireStates.nagan.extra=[{"nested":{"@f64":"9a9999999999b93f"}}]
	check(not Checkpoint.encode(value).ok,"reserved wire tag rejected in nested array/dictionary")
	value=initial.duplicate(true);value.inventory.fireStates.nagan.extra=0.1
	var extra_encoded:=Checkpoint.encode(value)
	if not extra_encoded.ok:print("EXTRA_INVALID ",invalid_plain_paths(value))
	var extra_decoded:=Checkpoint.decode(extra_encoded.text) if extra_encoded.ok else {"ok":false}
	check(extra_encoded.ok and extra_decoded.ok and extra_decoded.document.inventory.fireStates.nagan.extra is float,"legitimate fractional extension retains its type: encode="+str(extra_encoded.get("reason","ok"))+" decode="+str(extra_decoded.get("reason","ok")))
	value=initial.duplicate(true);value.inventory.fireStates.nagan.extra=9007199254740993
	check(not Checkpoint.encode(value).ok,"unsafe integer extension rejected without conversion loss")
	value=initial.duplicate(true);value.inventory.fireStates.nagan.extra=-9007199254740993
	check(not Checkpoint.encode(value).ok,"negative unsafe integer extension rejected")
	# Real reservation cancelled only by the issued token; no raw owner mutation.
	var pending:Dictionary=w.inventory.begin_cargo_export(w.fire_state)
	check(pending.get("ok",false),"real inventory reservation issued")
	var held:=invariant();var denied:=Checkpoint.capture(scene)
	check(not denied.ok and denied.reason=="BUSY_RECONCILE" and invariant()==held,"live pending transfer blocks capture without cancellation")
	check(w.inventory.cancel_cargo_transfer(pending.token).get("ok",false),"owner cancels exact reservation")
	check(Checkpoint.capture(scene).ok,"settled owner captures again")
	var dropped:Dictionary=c.drop_held()
	if not check(dropped.get("ok",false),"actual near-player native ground drop "+str(dropped.get("reason",""))):finish();return
	var ground:=sample("ground")
	if ground.is_empty():finish();return
	check(ground.inventory.identities.dropped[dropped.drop.uid]==original_uid,"same TT UID owned to ground")
	value=ground.duplicate(true);value.inventory.dropped[0].expiresAt=value.capture.mono_ms;reject(value,ground,"EXPIRED_OR_INVALID_CLOCK")
	await tick(15)
	var picked:Dictionary=c.pickup_ground(dropped.drop.uid)
	if not check(picked.get("ok",false),"actual native ground pickup and equip "+str(picked.get("reason",""))):finish();return
	check(w.inventory.get_item_uid("tt_pistol")==original_uid,"pickup preserves exact UID")
	var returned:=sample("picked_up")
	if returned.is_empty():finish();return
	# One explicit setup placement at real rear access. No car/NPC/shape edits.
	var access:Dictionary=t.compartments.access_profile("trunk")
	var setup:Vector3=t.body.to_global(access.position_local_m+access.outward_local*.9)
	var ray:=PhysicsRayQueryParameters3D.create(setup+Vector3.UP*2,setup-Vector3.UP*3,1,[p.get_rid(),t.body.get_rid()])
	var hit:Dictionary=p.get_world_3d().direct_space_state.intersect_ray(ray)
	if not check(not hit.is_empty(),"current rear floor for explicit setup placement"):finish();return
	setup.y=hit.position.y+.02;p.global_position=setup
	t.compartments.set_open("trunk",true);await tick(100)
	if not check(c._window_access(),"actual rear geometry/door access"):finish();return
	key(KEY_F);await tick(2)
	if not check(c.window_open,"F input opens real trunk window"):finish();return
	key(KEY_G);await tick(2)
	if not check(c.cargo.snapshot(c.generation).items.size()==1,"G input stores held TT via paired native owners"):finish();return
	var cargo:=sample("cargo")
	if cargo.is_empty():finish();return
	check(cargo.vehicles[0].items[0].item.uid==original_uid,"same original UID in cargo")
	check(Checkpoint.validate(cargo).ammo_total==Checkpoint.validate(initial).ammo_total,"complete item/ammo conservation across domains")
	value=cargo.duplicate(true);value.inventory.identities.owned.nagan=original_uid;reject(value,cargo,"DUPLICATE_UID")
	value=cargo.duplicate(true);value.vehicles[0].items[0].item.itemUID="conflicting-alias";reject(value,cargo,"CARGO_ITEM")
	value=cargo.duplicate(true);value.vehicles[0].used_units+=1;reject(value,cargo,"CAPACITY")
	value=cargo.duplicate(true);value.vehicles[0].items[0].model_aabb.size.x=-1;reject(value,cargo,"CARGO_GEOMETRY")
	var taken:Dictionary=c.window_take(original_uid)
	if not check(taken.get("ok",false),"native trunk window takes exact item"):finish();return
	var final_doc:=sample("taken")
	check(not final_doc.is_empty() and w.inventory.get_item_uid("tt_pistol")==original_uid,"same original UID restored by native transfer, not codec")
	check(Checkpoint.validate(final_doc).ammo_total==Checkpoint.validate(initial).ammo_total,"ammo conserved after complete drop/pickup/store/take sequence")
	finish()
func finish()->void:
	if done:return
	done=true
	var result:Dictionary={"passed":errors.is_empty(),"checks":checks,"errors":errors,"phases":phases,"capture_us":durations,"production_accepted":false,"restore_implemented":false,"server_grants":0,"scope":"Actual unchanged48 main/3NPC/player/vehicle and native transfer APIs plus F/G engine input; one explicit rear player setup placement. Capture/codec/plan read-only. Private output files only. No server/auth/storage access. Headless2CPU functional; no graphics/perf acceptance."}
	FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CHECKPOINT_RESULT ",JSON.stringify({"passed":result.passed,"checks":checks,"errors":errors,"phases":phases.size()}))
	if is_instance_valid(scene):scene.queue_free()
	await process_frame;await process_frame
	quit(0 if errors.is_empty() else 1)
