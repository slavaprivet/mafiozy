extends SceneTree
const Bridge=preload("res://scripts/weapons/weapon_cargo_bridge.gd")
const Inventory=preload("res://scripts/weapons/weapon_inventory.gd")
const Fire=preload("res://scripts/weapons/weapon_fire.gd")
const Store=preload("res://scripts/transport/trunk/transport_trunk_cargo_store.gd")
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Panels=preload("res://scripts/vehicle_visual/vehicle_compartments.gd")
const Evidence=preload("res://scripts/transport/transport_cargo_evidence.gd")
const Weapons=preload("res://scripts/weapon_visual/weapon_visual_catalog.gd")
const Sizes=preload("res://scripts/weapons/weapon_cargo_sizes.gd")
const SCALE:=Sizes.TRUNK_SCALE
class Placement extends RefCounted:
	var visual:Node3D
	var request:Dictionary
var checks:=0
var failures:Array=[]
var visual:RefCounted
var panels:RefCounted
var evidence:RefCounted
var weapons:RefCounted
var inventory:RefCounted
var cargo:RefCounted
var bridge:RefCounted
var aimed_trunk:=true
var aimed_uid:=""
var allowed:=true
var mode:=""
var cancelled:=0
var prepared:=0
var sample_count:=0
var tokens:Array=[]
var external_placements:Array=[]
var last_request:Dictionary={}
var times:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);print("CHECK_FAILED ",label)
func now()->float:
	if mode=="clock_mutates_placements" and not external_placements.is_empty():external_placements[0].position.x=999
	if mode=="clock_reentry":bridge.actions()
	return 12345.0
func sample()->Dictionary:
	sample_count+=1
	return {"revision":1,"sample":evidence.sample(),"target_open":panels.is_open("trunk"),"interaction_allowed":allowed,"aimed_trunk":aimed_trunk,"aimed_item_uid":aimed_uid}
func prepare(request:Dictionary)->Dictionary:
	prepared+=1;last_request=request.duplicate(true)
	var token:=Placement.new();token.request=request.duplicate(true);tokens.append(token)
	if request.action=="store":
		var built:Dictionary=weapons.instantiate_weapon(request.entry.item.weaponId)
		if not built.ok:return {"ok":false,"token":token}
		token.visual=built.visual
		var actual:AABB=Transform3D(Basis.from_scale(Vector3.ONE*SCALE),Vector3.ZERO)*token.visual.local_bounds()
		check(actual==request.entry.model_aabb,"preflight uses actual scaled native model bounds")
		if actual!=request.entry.model_aabb:return {"ok":false,"token":token}
		token.visual.scale=Vector3.ONE*SCALE;token.visual.position=request.entry.model_origin_local_m
	if request.action=="destroy":
		token.visual=Node3D.new()
		var placed_boxes:Array[AABB]=[]
		for index in request.entries.size():
			var built:Dictionary=weapons.instantiate_weapon(request.entries[index].item.weaponId)
			if not built.ok:return {"ok":false,"token":token}
			var ground:Node3D=built.visual;var at:Dictionary=request.placements[index].position
			ground.scale=Vector3.ONE*SCALE;ground.position=Vector3(at.x,at.y,at.z);ground.rotation.y=request.placements[index].yaw
			token.visual.add_child(ground)
			var ground_box:AABB=ground.transform*ground.local_bounds()
			if ground_box.position.y < -.000001:return {"ok":false,"token":token}
			for previous:AABB in placed_boxes:
				if ground_box.intersects(previous):return {"ok":false,"token":token}
			placed_boxes.append(ground_box)
	if mode=="closed_during_prepare":panels.set_open("trunk",false)
	if mode=="revision_during_prepare":visual.root.set_meta("life_generation",8)
	if mode=="reentry":bridge.actions()
	if mode=="dispose_bridge":bridge.dispose()
	if mode=="dispose_inventory":inventory.dispose()
	if mode=="cancel_inventory":inventory.cancel_cargo_transfer(inventory.get("_cargo_ticket"))
	if mode=="cancel_cargo":cargo.cancel(cargo.get("_pending").token)
	if mode=="failed":return {"ok":false,"token":token}
	return {"ok":true,"token":token}
func cancel(token:RefCounted)->void:
	cancelled+=1
	if is_instance_valid(token.visual):token.visual.free();token.visual=null
func clear_tokens()->void:
	for token:Placement in tokens:
		if is_instance_valid(token.visual):token.visual.free()
	tokens=[]
func open_lid()->void:
	panels.set_open("trunk",true)
	for frame in 90:panels.step(1.0/60.0)
func setup(ids:Array=["ak74"],max_drops:int=100)->void:
	clear_tokens()
	if bridge!=null:bridge.dispose()
	if inventory!=null:inventory.dispose()
	if cargo!=null:cargo.dispose()
	mode="";aimed_trunk=true;aimed_uid="";allowed=true;cancelled=0;prepared=0;sample_count=0
	visual.root.set_meta("life_generation",7);open_lid()
	inventory=Inventory.new();cargo=Store.new();bridge=Bridge.new()
	check(inventory.configure(Fire.new(),{"ownedIds":ids,"now":now,"maxDrops":max_drops}).ok,"actual inventory configure")
	if not ids.is_empty():check(inventory.equip(ids[0]).ok,"actual equip")
	check(cargo.configure(visual.root,"bridge-car",7,evidence,panels).ok,"actual cargo/evidence configure")
	check(bridge.configure(inventory,cargo,7,sample,prepare,cancel).ok,"actual bridge configure")
func box(id:String)->AABB:
	var built:Dictionary=weapons.instantiate_weapon(id)
	check(built.ok,"actual weapon model "+id)
	var value:AABB=Transform3D(Basis.from_scale(Vector3.ONE*SCALE),Vector3.ZERO)*built.visual.local_bounds()
	built.visual.free();return value
func run():
	var catalog:Dictionary=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:Dictionary=Visual.instantiate_visual(catalog.entries.compact_sedan,catalog.base_path)
	check(loaded.ok,"actual compact sedan GLB")
	if not loaded.ok:quit(1);return
	visual=loaded.visual;root.add_child(visual.root);visual.root.set_meta("vehicle_id","bridge-car");visual.root.set_meta("life_generation",7)
	panels=Panels.new();evidence=Evidence.new();weapons=Weapons.new()
	check(panels.configure(visual).ok,"actual lid rig")
	check(evidence.configure(visual,panels).ok,"actual cargo floor and lid vertices")
	check(weapons.open().ok,"actual14 native weapon catalogue")
	var meta:=Bridge.capacity_metadata()
	check(meta.capacity_units==100 and meta.costs.size()==14 and meta.user_fixed_costs.is_empty() and meta.other_costs_source=="exact_model_volume_largest_remainders","latest user all14 total100, AK15 was an example")
	for id:String in Fire.ids():
		setup([id])
		var held:Dictionary=inventory.get_fire_state();held.magazine=1;held.reserveAmmo=73;held.sequence=19
		var uid:String=inventory.get_item_uid();var bounds:=box(id)
		check(bridge.actions().actions==[{"key":"G","label":"Погрузить","action":"store"}],"exact open G label "+id)
		var started:=Time.get_ticks_usec();var stored:Dictionary=bridge.store(bounds,held);times.append(Time.get_ticks_usec()-started)
		check(stored.ok,"all14 actual models store "+id+" "+str(stored))
		if not stored.ok:continue
		check(inventory.get_owned_ids().is_empty() and cargo.snapshot(7).used_units==Bridge.COSTS[id],"store changes both owners once "+id)
		var entry:Dictionary=cargo.snapshot(7).items[0]
		check(entry.item.uid==uid and entry.item.fireState.magazine==1 and entry.item.fireState.reserveAmmo==73 and entry.item.fireState.sequence==19,"stable UID and ammunition "+id)
		aimed_trunk=false;aimed_uid=uid
		check(bridge.actions().actions==[{"key":"E","label":"Взять","action":"take","uid":uid}],"exact aimed E label "+id)
		var taken:Dictionary=bridge.take(uid)
		check(taken.ok and inventory.snapshot().equippedId=="none" and inventory.get_item_uid(id)==uid and inventory.get_fire_state(id).magazine==1 and cargo.snapshot(7).items.is_empty(),"take preserves UID/ammo without equipping "+id)
		check(not bridge.take(uid).ok,"missing sameUID cannot duplicate "+id)
	setup()
	var ak_box:=box("ak74")
	panels.set_open("trunk",false)
	check(bridge.actions().actions.is_empty() and not bridge.store(ak_box).ok,"closed target hides G even before lid finishes closing")
	open_lid();allowed=false
	check(bridge.actions().actions.is_empty() and not bridge.store(ak_box).ok,"host range/motion gate required")
	allowed=true;aimed_trunk=false
	check(not bridge.store(ak_box).ok,"not aimed trunk rejects press")
	for failure:String in ["failed","closed_during_prepare","revision_during_prepare","reentry","dispose_bridge","cancel_inventory","cancel_cargo"]:
		setup();mode=failure
		var before:Dictionary=inventory.snapshot();var answer:Dictionary=bridge.store(ak_box)
		check(not answer.ok,"store preflight failure "+failure)
		visual.root.set_meta("life_generation",7)
		check(inventory.snapshot()==before and cargo.snapshot(7).items.is_empty(),"failure preserves original ownership "+failure)
		check(not inventory.cargo_transfer_pending() and not cargo.snapshot(7).pending and cancelled==1,"both reservations and renderer cancelled "+failure)
	setup();mode="dispose_inventory"
	check(not bridge.store(ak_box).ok and cargo.snapshot(7).items.is_empty(),"disposed inventory cannot leave cargo duplicate")
	setup();check(bridge.store(ak_box).ok,"take-failure seed")
	var uid:String=cargo.snapshot(7).items[0].item.uid;aimed_trunk=false;aimed_uid=uid;mode="failed"
	check(not bridge.take(uid).ok and cargo.snapshot(7).items.size()==1 and inventory.get_owned_ids().is_empty(),"failed take leaves exact cargo item")
	mode="";panels.set_open("trunk",false)
	check(bridge.actions().actions.is_empty() and not bridge.take(uid).ok,"closed target hides E and rejects exactitem press")
	setup(["ak74","tt_pistol"]);check(bridge.store(ak_box).ok,"equipped selection seed")
	uid=cargo.snapshot(7).items[0].item.uid;aimed_trunk=false;aimed_uid=uid
	check(inventory.equip("tt_pistol").ok,"hold different weapon before taking")
	var pistol_state:Dictionary=inventory.get_fire_state();pistol_state.magazine=2
	check(bridge.take(uid,pistol_state).ok and inventory.snapshot().equippedId=="tt_pistol" and inventory.get_fire_state().magazine==2,"E pickup keeps currently held weapon and live ammo")
	setup(["ak74","tt_pistol"])
	check(bridge.store(ak_box).ok,"destroy seed ak")
	check(inventory.equip("tt_pistol").ok,"destroy seed pistol equip")
	var pistol_store:Dictionary=bridge.store(box("tt_pistol"))
	check(pistol_store.ok,"destroy seed pistol "+str(pistol_store))
	if not pistol_store.ok:
		var old:AABB=cargo.snapshot(7).items[0].item_bounds_local_m;var next_box:=box("tt_pistol");var sampled:Dictionary=evidence.sample()
		for axis in 3:
			var point:=old.position;point[axis]=old.end[axis]+Store.GAP_M
			var candidate:=AABB(point,next_box.size)
			print("PACK_DIAG ",JSON.stringify({"old":str(old),"next":str(candidate),"volume":str(sampled.bounds),"axis":axis,"gap":float(point[axis])-old.end[axis],"overlaps":cargo._overlaps_existing(candidate),"contains":cargo._contains(sampled.bounds,candidate)}))
	var entries:Array=cargo.snapshot(7).items
	var positions:Array=[{"position":{"x":1,"y":-ak_box.position.y,"z":2},"yaw":0.0},{"position":{"x":1.5,"y":-box("tt_pistol").position.y,"z":2},"yaw":.1}]
	if entries.size()==2:
		var overlapping:Array=positions.duplicate(true);overlapping[1].position.x=1
		check(not bridge.destroy("blast1",overlapping).ok and cargo.snapshot(7).items==entries and inventory.get_dropped().is_empty(),"actual model ground overlap fails preflight without ownership loss")
		mode="failed"
		check(not bridge.destroy("blast1",positions).ok and cargo.snapshot(7).items==entries and inventory.get_dropped().is_empty(),"failed ground renderer preserves entire cargo")
		mode="clock_mutates_placements";external_placements=positions
		var destroyed:Dictionary=bridge.destroy("blast1",positions)
		check(destroyed.ok and cargo.snapshot(7).items.is_empty() and inventory.get_dropped().size()==2,"destroy reserves whole ground batch then clears cargo")
		check(inventory.get_dropped()[0].position.x==1 and last_request.placements[0].position.x==1 and positions[0].position.x==999,"clock cannot replace renderer/reserved placements")
		for index in 2:check(inventory.get_drop_item(inventory.get_dropped()[index].uid).uid==entries[index].item.uid,"destroy preserves each distinct item UID")
		var before_count:=prepared
		check(bridge.destroy("blast1",positions).get("duplicate")==true and inventory.get_dropped().size()==2 and prepared==before_count,"destroy replay emits no extra renderer or drops")
		check(not bridge.destroy("other-blast",positions).ok,"different destruction event cannot replay")
	setup(["ak74"],0);check(bridge.store(ak_box).ok,"limit seed")
	check(not bridge.destroy("full",[positions[1]]).ok and cargo.snapshot(7).items.size()==1 and not cargo.snapshot(7).pending,"ground capacity failure retains cargo and cancels destroy")
	setup();check(bridge.store(ak_box).ok,"clock reentry seed");mode="clock_reentry"
	check(not bridge.destroy("clock",[positions[1]]).ok and cargo.snapshot(7).items.size()==1 and inventory.get_dropped().is_empty() and not inventory.cargo_transfer_pending() and not cargo.snapshot(7).pending,"clock reentry cancels both sides before ground renderer")
	setup([]);check(bridge.destroy("empty",[]).ok and bridge.destroy("empty",[]).duplicate,"empty cargo destruction once")
	# Every original model at common scale: floor-supported, no hidden stack.
	var original:Array=Fire.ids();var reversed:Array=original.duplicate();reversed.reverse()
	var large_first:Array=original.duplicate();large_first.sort_custom(func(a:String,b:String):return Sizes.MEASUREMENTS[a].volume_native>Sizes.MEASUREMENTS[b].volume_native)
	for order:Array in [original,reversed,large_first]:
		setup(order)
		for id:String in order:
			check(inventory.equip(id).ok,"all14 next owned item "+id)
			var full:Dictionary=bridge.store(box(id))
			check(full.ok,"all14 physical packing "+id+" "+str(full.get("reason","")))
		var full:Dictionary=cargo.snapshot(7);var floor_box:AABB=evidence.sample().bounds
		check(full.used_units==100 and full.items.size()==14 and inventory.get_owned_ids().is_empty(),"all14 consume exactly100 in each tested order")
		for a in full.items.size():
			var actual:AABB=full.items[a].item_bounds_local_m
			check(is_equal_approx(actual.position.y,floor_box.position.y),"all14 actual model rests on floor; no floating layer")
			check(cargo._contains(floor_box,actual),"all14 exact geometry bounds inside actual sedan")
			for b in range(a+1,full.items.size()):check(not actual.intersects(full.items[b].item_bounds_local_m),"all14 actual models pairwise nonoverlap")
	bridge.dispose();inventory.dispose();inventory=Inventory.new();bridge=Bridge.new()
	check(inventory.configure(Fire.new(),{"ownedIds":["ak74"]}).ok and inventory.equip("ak74").ok,"overflow source")
	check(bridge.configure(inventory,cargo,7,sample,prepare,cancel).ok,"overflow bridge")
	check(not bridge.store(ak_box).ok and inventory.get_owned_ids()==["ak74"] and cargo.snapshot(7).used_units==100,"overflow retains source item")
	var action_us:Array=[]
	for frame in 144:
		var started:=Time.get_ticks_usec();var hints:Dictionary=bridge.actions();var elapsed:=Time.get_ticks_usec()-started
		check(hints.ok and hints.used_units==100,"loaded100 UI state current")
		if frame>=16:action_us.append(elapsed)
	action_us.sort()
	clear_tokens();bridge.dispose();inventory.dispose();cargo.dispose();evidence.dispose();panels.dispose();visual.dispose();weapons.close()
	times.sort()
	print("WEAPON_CARGO_BRIDGE ",JSON.stringify({"checks":checks,"failures":failures,"store_actual_models_p50_us":times[times.size()/2],"store_actual_models_max_us":times.back(),"actions_loaded100_p50_us":action_us[action_us.size()/2],"actions_loaded100_p95_us":action_us[int(action_us.size()*.95)],"scope":"actual Fire/Inventory/Cargo/Evidence/Panels/compact sedan GLB and14weapon models; warmedresource newmodelnode preflight; fixture aim/ground positions; no main/UI/GPU/FPS"}))
	quit(0 if failures.is_empty() else 1)
