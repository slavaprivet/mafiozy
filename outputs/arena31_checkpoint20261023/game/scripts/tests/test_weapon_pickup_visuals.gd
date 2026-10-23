extends SceneTree
const Renderer=preload("res://scripts/weapons/weapon_pickup_visuals.gd")
const Bridge=preload("res://scripts/weapons/weapon_cargo_bridge.gd")
const Inventory=preload("res://scripts/weapons/weapon_inventory.gd")
const Fire=preload("res://scripts/weapons/weapon_fire.gd")
const Store=preload("res://scripts/transport/trunk/transport_trunk_cargo_store.gd")
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Panels=preload("res://scripts/vehicle_visual/vehicle_compartments.gd")
const Evidence=preload("res://scripts/transport/transport_cargo_evidence.gd")
const Weapons=preload("res://scripts/weapon_visual/weapon_visual_catalog.gd")
class ExitHook extends Node:
	var renderer:RefCounted
	func _exit_tree():renderer.dispose()
var checks:=0
var failures:Array=[]
var world:Node3D
var visual:RefCounted
var panels:RefCounted
var evidence:RefCounted
var weapons:RefCounted
var renderer:RefCounted
var inventory:RefCounted
var cargo:RefCounted
var bridge:RefCounted
var aimed_uid:=""
var mode:=""
var prepared:=0
var validations:=0
var cold_pick_us:Array=[]
var warm_pick_us:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);print("CHECK_FAILED ",label)
func now()->float:return 12345.0
func sample()->Dictionary:
	return {"revision":1,"sample":evidence.sample(),"target_open":panels.is_open("trunk"),"interaction_allowed":true,"aimed_trunk":aimed_uid.is_empty(),"aimed_item_uid":aimed_uid}
func ground_validate(request:Dictionary)->Dictionary:
	validations+=1
	if mode=="reentry":renderer.sync_ground([],{})
	if mode=="dispose":renderer.dispose()
	if mode=="deny":return {"ok":false}
	var floors:Array=[]
	for item:Dictionary in request.items:
		var box:AABB=item.world_aabb
		var highest:float=item.position.y
		# Real physics floor query at every corner; no floor or penetration rejects.
		for x:float in [box.position.x,box.end.x]:
			for z:float in [box.position.z,box.end.z]:
				var bottom:=Vector3(x,box.position.y,z)
				var query:=PhysicsRayQueryParameters3D.create(bottom+Vector3.UP*.3,bottom-Vector3.UP*.1,1)
				var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty() or hit.normal.y<.9:return {"ok":false}
				highest=maxf(highest,hit.position.y)
		floors.append(highest)
	return {"ok":true,"floors":floors}
func prepare(request:Dictionary)->Dictionary:
	prepared+=1
	var result:Dictionary=renderer.prepare_placement(request)
	if result.ok:
		for row:Dictionary in renderer.get("_pending").rows:
			check(row.visual.is_inside_tree() and not row.visual.visible,"prepared model attached hidden before paired commit")
	if mode=="close":panels.set_open("trunk",false)
	return result
func cancel(token:Variant)->void:check(renderer.cancel_placement(token).ok,"rollback releases prepared nodes")
func activate(result:Dictionary)->void:
	check(result.get("ok",false),"real bridge transfer succeeded "+str(result.get("error",result.get("reason",""))))
	if result.get("ok",false) and result.has("placement_token"):
		check(renderer.activate_placement(result.placement_token,result).ok,"activate paired receipt without attachment")
func open_lid():
	panels.set_open("trunk",true)
	for frame in 90:panels.step(1.0/60.0)
func setup(ids:Array=["ak74"]):
	if bridge!=null:bridge.dispose()
	if renderer!=null:renderer.dispose()
	if inventory!=null:inventory.dispose()
	if cargo!=null:cargo.dispose()
	aimed_uid="";mode="";open_lid()
	inventory=Inventory.new();cargo=Store.new();bridge=Bridge.new();renderer=Renderer.new()
	check(inventory.configure(Fire.new(),{"ownedIds":ids,"now":now}).ok,"inventory configured")
	if not ids.is_empty():check(inventory.equip(ids[0]).ok,"equip")
	check(cargo.configure(visual.root,"picker-car",7,evidence,panels).ok,"real cargo configured")
	check(renderer.configure(weapons,world,ground_validate).ok,"renderer configured")
	check(renderer.bind_trunk("picker-car",7,visual.root).ok,"same actual cargo coordinate frame")
	check(bridge.configure(inventory,cargo,7,sample,prepare,cancel).ok,"bridge renderer ports")
func place(id:String,x:float=4.0,z:float=0.0,yaw:float=0.0)->Dictionary:
	check(is_equal_approx(renderer.model_aabb(id,"ground").position.y,.009),"ground model box starts at source rest clearance")
	return {"position":{"x":x,"y":0.0,"z":z},"yaw":yaw}
func ray_for(row:Dictionary)->Dictionary:
	# Aim at an actual visible source triangle centroid, from its normal side.
	for part:Dictionary in row.parts:
		if not part.visible:continue
		var vertices:PackedVector3Array=part.mesh.get_faces()
		for i in range(0,vertices.size(),3):
			var t:Transform3D=row.visual.global_transform*part.transform
			var a:Vector3=t*vertices[i];var b:Vector3=t*vertices[i+1];var c:Vector3=t*vertices[i+2]
			var n:Vector3=(b-a).cross(c-a).normalized()
			if n.length_squared()>.9:return {"origin":(a+b+c)/3.0+n*2.0,"direction":-n}
	return {}
func pick_row(row:Dictionary,scope:String="trunk")->Dictionary:
	var ray:=ray_for(row)
	return renderer.pick(ray.origin,ray.direction,5,{"enabled":true,"scope":scope,"trunk_open":true,"vehicle_id":"picker-car","generation":7})
func run():
	world=Node3D.new();root.add_child(world)
	var floor:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(40,1,40);collision.shape=shape;floor.add_child(collision);floor.position.y=-.5;world.add_child(floor)
	var catalog:Dictionary=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:Dictionary=Visual.instantiate_visual(catalog.entries.compact_sedan,catalog.base_path)
	check(loaded.ok,"actual sedan loaded")
	if not loaded.ok:quit(1);return
	visual=loaded.visual;world.add_child(visual.root);visual.root.set_meta("vehicle_id","picker-car");visual.root.set_meta("life_generation",7)
	panels=Panels.new();evidence=Evidence.new();weapons=Weapons.new()
	check(panels.configure(visual).ok and evidence.configure(visual,panels).ok and weapons.open().ok,"actual panels/evidence/14-model catalog")
	await physics_frame
	await physics_frame
	for id:String in Fire.ids():
		setup([id]);var uid:String=inventory.get_item_uid();var live:Dictionary=inventory.get_fire_state();live.magazine=1;live.reserveAmmo=71
		activate(bridge.store(renderer.model_aabb(id),live))
		var rows:Dictionary=renderer.get("_trunks")["picker-car"].items
		if rows.is_empty():continue
		var row:Dictionary=rows[uid]
		check(row.visual.scale.is_equal_approx(Vector3.ONE*.2),"small actual trunk model "+id)
		check(row.local_box==cargo.snapshot(7).items[0].item_bounds_local_m,"actual packed box "+id)
		var started:=Time.get_ticks_usec();var picked:=pick_row(row);cold_pick_us.append(Time.get_ticks_usec()-started)
		check(picked.get("hit",false) and picked.item_uid==uid,"actual triangle pick "+id+" "+str(picked))
		started=Time.get_ticks_usec();picked=pick_row(row);warm_pick_us.append(Time.get_ticks_usec()-started)
		check(picked.get("hit",false),"warm exact geometry pick "+id)
		var before:Dictionary=renderer.debug_snapshot();var ray:=ray_for(row)
		check(not renderer.pick(ray.origin,ray.direction,5,{"enabled":false,"scope":"trunk","trunk_open":true}).hit,"inactive no focus")
		check(not renderer.pick(ray.origin,ray.direction,5,{"enabled":true,"scope":"trunk","trunk_open":false}).hit,"closed no focus")
		check(renderer.debug_snapshot()==before,"disabled/closed zero geometry or AABB work")
		check(not renderer.pick(ray.origin,ray.direction,5,{"enabled":true,"scope":"trunk","trunk_open":true,"vehicle_id":"picker-car","generation":7,"blocker_distance":.001}).hit,"host blocker clips pick")
		check(renderer.sync_trunk("picker-car",7,cargo.snapshot(7).items).created==0 and rows[uid].visual==row.visual,"unchanged cargo retains model")
		aimed_uid=uid;activate(bridge.take(uid))
		check(renderer.debug_snapshot().total_count==0 and inventory.get_item_uid(id)==uid and inventory.get_fire_state(id).magazine==1,"take exact UID/ammo removes only presentation")
	setup(["ak74","tt_pistol"])
	activate(bridge.store(renderer.model_aabb("ak74")))
	inventory.equip("tt_pistol");activate(bridge.store(renderer.model_aabb("tt_pistol")))
	var entries:Array=cargo.snapshot(7).items
	var positions:Array=[place("ak74",4,0,.3),place("tt_pistol",6,0,-.5)]
	var saved:Dictionary=inventory.snapshot()
	var invalid:Array=positions.duplicate(true);invalid[0].position.x=100
	check(not bridge.destroy("blast",invalid).ok and cargo.snapshot(7).items==entries and inventory.snapshot()==saved,"real physics missing floor refuses both ownership commits")
	invalid=positions.duplicate(true);invalid[0].position.y=-2
	check(not bridge.destroy("blast",invalid).ok and cargo.snapshot(7).items==entries,"floor penetration refuses destruction")
	invalid=positions.duplicate(true);invalid[1]=positions[0].duplicate(true)
	check(not bridge.destroy("blast",invalid).ok,"real full-size ground bounds prevent overlap")
	mode="reentry"
	check(not bridge.destroy("blast",positions).ok and cargo.snapshot(7).items==entries,"ground callback reentry rejects before paired commit")
	mode="";var destroyed:Dictionary=bridge.destroy("blast",positions);activate(destroyed)
	check(cargo.snapshot(7).items.is_empty() and renderer.debug_snapshot().ground_count==2,"destroy whole cargo becomes two ground originals")
	var ground:Dictionary=renderer.get("_ground")
	for drop_uid:String in ground:
		var row:Dictionary=ground[drop_uid];var picked:=pick_row(row,"ground")
		check(picked.get("hit",false) and picked.drop_uid==drop_uid and picked.item_uid==inventory.get_drop_item(drop_uid).uid,"ground source drop UID plus stable item UID")
		check(row.visual.scale.is_equal_approx(Vector3.ONE*Renderer.GROUND_SCALE),"ground hero native scale")
		check(is_equal_approx(row.world_box.get_center().x,row.placement.position.x) and is_equal_approx(row.world_box.get_center().z,row.placement.position.z),"asymmetric source mesh centered over pickup coordinate")
		check(is_equal_approx(row.world_box.position.y,.009) and is_equal_approx(row.visual.position.y-row.rest_transform.origin.y,.55),"lying rest clearance and initial source fall height")
		check(row.visual.basis.is_equal_approx(Basis(Vector3.UP,row.placement.yaw)*Basis(Vector3.BACK,PI/2)*Basis.from_scale(Vector3.ONE*.368)),"source yaw plus sideways rotation")
	check(renderer.update(-1).updated==2,"negative fall delta clamps to zero")
	check(renderer.update(1).updated==2,"large fall delta clamps to .1")
	for row:Dictionary in ground.values():check(is_equal_approx(row.visual.position.y-row.rest_transform.origin.y,.55*(1-.25*.25)),"source fall quadratic at .1 seconds")
	for i in 3:renderer.update(.1)
	check(renderer.debug_snapshot().falling_count==0,"all items settle at .4 seconds")
	var settled_updates:int=renderer.debug_snapshot().fall_updates
	var no_updates:=true
	for i in 100:no_updates=no_updates and renderer.update(.016).updated==0
	check(no_updates,"settled scene performs no fall scan across 100 frames")
	check(renderer.debug_snapshot().fall_updates==settled_updates,"settled objects receive no transforms")
	var calls:=validations
	check(renderer.sync_ground(inventory.get_dropped(),inventory.item_identity_snapshot().dropped).created==0 and calls==validations,"unchanged ground no reload or physics callback")
	check(bridge.destroy("blast",positions).duplicate and renderer.debug_snapshot().ground_count==2,"destroy replay no new ground")
	var first:String=ground.keys()[0];var original_uid:String=inventory.get_drop_item(first).uid
	check(inventory.pickup(first).ok,"actual inventory ground pickup")
	check(renderer.sync_ground(inventory.get_dropped(),inventory.item_identity_snapshot().dropped).ok and renderer.debug_snapshot().ground_count==1,"source pickup retires renderer drop")
	check(inventory.item_identity_snapshot().owned.values().has(original_uid),"ground pickup preserves item UID")
	setup();mode="close";saved=inventory.snapshot()
	check(not bridge.store(renderer.model_aabb("ak74")).ok and inventory.snapshot()==saved and renderer.debug_snapshot().total_count==0 and not renderer.debug_snapshot().pending,"lid changed after hidden prepare cancels with no orphan")
	setup();activate(bridge.store(renderer.model_aabb("ak74")))
	var row:Dictionary=renderer.get("_trunks")["picker-car"].items.values()[0]
	var ray:=ray_for(row);var mesh:MeshInstance3D=row.parts[0].node.get_ref();var old_transform:=mesh.transform
	mesh.position.x+=.01
	check(not renderer.pick(ray.origin,ray.direction,5,{"enabled":true,"scope":"trunk","trunk_open":true,"vehicle_id":"picker-car","generation":7}).ok,"changed source-rest mesh rejects stale cached pick")
	mesh.transform=old_transform
	visual.root.position=Vector3(2,1,3);visual.root.rotation.y=.6
	check(pick_row(row).get("hit",false),"moving rotated car transforms item pick correctly")
	visual.root.transform=Transform3D.IDENTITY
	var empty_aabb_cells:=0;var geometry_hits:=0
	for x in 9:
		for y in 9:
			var box:AABB=row.bounds;var local:=Vector3(box.position.x+box.size.x*(x+.5)/9,box.position.y+box.size.y*(y+.5)/9,box.position.z-2)
			var origin:Vector3=row.visual.global_transform*local;var direction:Vector3=row.visual.global_basis*Vector3.BACK
			var before:int=renderer.debug_snapshot().geometry_queries
			var hit:Dictionary=renderer.pick(origin,direction,5,{"enabled":true,"scope":"trunk","trunk_open":true,"vehicle_id":"picker-car","generation":7})
			if hit.get("hit",false):geometry_hits+=1
			elif renderer.debug_snapshot().geometry_queries>before:empty_aabb_cells+=1
	check(empty_aabb_cells>0 and geometry_hits>0,"native triangle authority rejects empty space inside model AABB")
	setup()
	var item:Dictionary={"uid":inventory.get_item_uid(),"weaponId":"ak74","fireState":inventory.get_fire_state()}
	var placement:=place("ak74",4,0,.3)
	var before_inventory:Dictionary=inventory.snapshot();mode="deny"
	check(not renderer.prepare_ground_drop(item,placement).ok and inventory.snapshot()==before_inventory,"standalone ground preflight failure leaves ownership untouched")
	mode="";var preparation:Dictionary=renderer.prepare_ground_drop(item,placement)
	check(preparation.ok and renderer.get("_pending").rows[0].visual.is_inside_tree() and not renderer.get("_pending").rows[0].visual.visible,"atomic G pre-parents hidden original")
	check(renderer.cancel_placement(preparation.token).ok and renderer.debug_snapshot().ground_count==0,"cancel standalone G before inventory mutation")
	var step:=StaticBody3D.new();var step_collision:=CollisionShape3D.new();var step_shape:=BoxShape3D.new();step_shape.size=Vector3(.1,.12,4);step_collision.shape=step_shape;step.add_child(step_collision)
	# One high corner, lower pickup center: source max(dropY,four floor corners).
	var probe:Dictionary=renderer.prepare_ground_drop(item,placement);var footprint:AABB=renderer.get("_pending").rows[0].world_box;renderer.cancel_placement(probe.token)
	step.position=Vector3(footprint.end.x-.01,.06,0);world.add_child(step)
	await physics_frame
	await physics_frame
	preparation=renderer.prepare_ground_drop(item,placement)
	check(preparation.ok,"real raised corner ground preflight")
	if preparation.ok:
		var pre:Dictionary=renderer.get("_pending").rows[0]
		check(is_equal_approx(pre.world_box.position.y,.129),"highest actual physics corner sets source rest Y")
		var actual_drop:Dictionary=inventory.drop({"position":placement.position,"yaw":placement.yaw,"fireState":item.fireState})
		check(actual_drop.ok,"actual G drop commits after preparation")
		check(not renderer.activate_ground_drop(preparation.token,actual_drop.drop,"wrong_uid").ok,"wrong item UID receipt cannot expose prepared model")
		check(renderer.activate_ground_drop(preparation.token,actual_drop.drop,item.uid).ok,"atomic G activation original item identity")
		check(not renderer.activate_ground_drop(preparation.token,actual_drop.drop,item.uid).ok,"atomic G token replay rejected")
		check(inventory.get_drop_item(actual_drop.drop.uid).uid==item.uid and renderer.debug_snapshot().ground_count==1,"atomic G inventory and renderer share stable UID")
	step.free()
	setup();activate(bridge.store(renderer.model_aabb("ak74")));mode="dispose"
	check(not bridge.destroy("dispose",[place("ak74")]).ok and cargo.snapshot(7).items.size()==1 and inventory.get_dropped().is_empty(),"ground validator disposal rejects before ownership mutation")
	mode=""
	setup(Fire.ids())
	var index:=0;var prepare_costs:Array=[]
	for id:String in Fire.ids():
		inventory.equip(id)
		item={"uid":inventory.get_item_uid(),"weaponId":id,"fireState":inventory.get_fire_state()};placement=place(id,-10+index*1.5,8,.3)
		var started:=Time.get_ticks_usec();preparation=renderer.prepare_ground_drop(item,placement);prepare_costs.append(Time.get_ticks_usec()-started)
		check(preparation.ok,"all14 atomic ground models with real floor "+id)
		if preparation.ok:
			var dropped:Dictionary=inventory.drop({"position":placement.position,"yaw":placement.yaw})
			check(dropped.ok and renderer.activate_ground_drop(preparation.token,dropped.drop,item.uid).ok,"all14 ground commit "+id)
		index+=1
	var active_update_us:Array=[]
	for frame in 4:
		var started:=Time.get_ticks_usec();var updated:Dictionary=renderer.update(.1);active_update_us.append(Time.get_ticks_usec()-started)
		check(updated.updated==14,"bounded source fall touches exactly14 active items")
	var target:Dictionary=renderer.get("_ground").values()[0];var warm_ray:=ray_for(target)
	renderer.pick(warm_ray.origin,warm_ray.direction,5,{"enabled":true,"scope":"ground"})
	var hot_pick_costs:Array=[];var idle_costs:Array=[];var disabled_costs:Array=[];var sync_costs:Array=[]
	var all_drops:Array=inventory.get_dropped();var identities:Dictionary=inventory.item_identity_snapshot().dropped
	for iteration in 101:
		var started:=Time.get_ticks_usec();var hit:Dictionary=renderer.pick(warm_ray.origin,warm_ray.direction,5,{"enabled":true,"scope":"ground"});hot_pick_costs.append(Time.get_ticks_usec()-started)
		check(hit.get("hit",false) and hit.item_uid==target.uid,"loaded14 actual geometry target remains present")
		started=Time.get_ticks_usec();renderer.update(.016);idle_costs.append(Time.get_ticks_usec()-started)
		started=Time.get_ticks_usec();renderer.pick(warm_ray.origin,warm_ray.direction,5,{"enabled":false,"scope":"ground"});disabled_costs.append(Time.get_ticks_usec()-started)
		started=Time.get_ticks_usec();var synced:Dictionary=renderer.sync_ground(all_drops,identities);sync_costs.append(Time.get_ticks_usec()-started)
		check(synced.ok and synced.created==0,"loaded14 unchanged sync retains originals")
	var costs:Dictionary={}
	for pair:Array in [["loaded14_hot_pick",hot_pick_costs],["loaded14_settled_update",idle_costs],["disabled_pick",disabled_costs],["loaded14_unchanged_sync",sync_costs],["all14_atomic_prepare_with_physics",prepare_costs],["14_active_fall_update",active_update_us]]:
		var values:Array=pair[1];values.sort();costs[pair[0]]={"p50_us":values[values.size()/2],"p95_us":values[min(values.size()-1,int(values.size()*.95))],"samples":values.size()}
	print("PICKUP_LOADED14_CPU ",JSON.stringify(costs))
	setup();activate(bridge.store(renderer.model_aabb("ak74")))
	var exit_hook:=ExitHook.new();exit_hook.renderer=renderer;world.add_child(exit_hook)
	world.free()
	check(renderer.debug_snapshot().total_count==0,"actual scene.free invokes renderer disposal while parent removes children")
	cold_pick_us.sort();warm_pick_us.sort()
	print("PICKUP_COST_CPU ",JSON.stringify({"cold_all14_p50_us":cold_pick_us[cold_pick_us.size()/2],"cold_all14_max_us":cold_pick_us.back(),"warm_all14_p50_us":warm_pick_us[warm_pick_us.size()/2],"warm_all14_max_us":warm_pick_us.back(),"limits":"headless CPU only; includes test ray construction; no scene FPS/GPU claim"}))
	bridge.dispose();renderer.dispose();inventory.dispose();cargo.dispose();evidence.dispose();panels.dispose();weapons.close()
	print("PICKUP_VISUALS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
