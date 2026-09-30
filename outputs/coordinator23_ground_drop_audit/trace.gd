extends SceneTree
const Fire=preload("res://scripts/weapons/weapon_fire.gd")
var checks:=0
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);print("CHECK_FAILED ",label)
func press_g(cargo:Node):
	var event:=InputEventKey.new();event.physical_keycode=KEY_G;event.keycode=KEY_G;event.pressed=true
	cargo._input(event)
func aim_item(cargo:Node,camera:Camera3D,uid:String)->bool:
	var row:Dictionary=cargo.renderer.get("_trunks")[cargo.vehicle_id].items[uid]
	var access: Dictionary=cargo.transport.compartments.access_profile("trunk")
	camera.global_position=cargo.transport.body.to_global(access.position_local_m+access.outward_local*1.5)+Vector3.UP*.7
	for part:Dictionary in row.parts:
		if not part.visible:continue
		var faces:PackedVector3Array=part.mesh.get_faces()
		for face in range(0,faces.size(),3):
			var point:Vector3=row.visual.global_transform*part.transform*((faces[face]+faces[face+1]+faces[face+2])/3.0)
			camera.look_at(point,Vector3.UP)
			if cargo.aim_context().item_uid==uid:return true
	return false
func run():
	var scene:Node3D=load("res://scenes/main.tscn").instantiate();scene.preview_residents_enabled=false;scene.preview_weapons_enabled=true
	root.add_child(scene)
	while not scene.preview_ready:await physics_frame
	var player:CharacterBody3D=scene._player;var transport:Node3D=scene.preview_transport;var weapons:Node=scene.preview_weapons;var cargo:Node=weapons.get_node_or_null("WeaponCargo")
	check(cargo!=null,"actual main cargo host")
	if cargo==null:scene.free();quit(1);return
	player.set_mouse_captured(true)
	for i in 60:await physics_frame
	var profile:Dictionary=transport.compartments.access_profile("trunk")
	var stand:Vector3=transport.body.to_global(profile.position_local_m+profile.outward_local*.9);stand.y=.01;player.global_position=stand
	for i in 5:await physics_frame
	var bounds:Dictionary=transport.compartments.cargo_bounds();var camera:Camera3D=player.get_preview_camera()
	camera.top_level=true;camera.global_position=stand+Vector3.UP*2;camera.look_at(transport.visual.root.to_global((bounds.min+bounds.max)*.5),Vector3.UP)
	check(weapons.equip("ak74").ok,"equipped before G guards")
	var before:Dictionary=weapons.inventory.snapshot();var velocity:Vector3=transport.body.linear_velocity
	check(cargo.aim_context().near_trunk and cargo.aim_context().aimed_trunk,"geometrically aimed actual hatchback")
	press_g(cargo)
	check(weapons.inventory.snapshot()==before and cargo.cargo.summary(cargo.generation).count==0,"closed stationary G never drops or stores")
	transport.body.linear_velocity=Vector3(.7,0,0)
	check(transport._nearest_panel().is_empty() and cargo.aim_context().near_trunk and not cargo.aim_context().cargo_allowed,"moving trunk remains geometric context despite admission gate")
	press_g(cargo)
	check(weapons.inventory.snapshot()==before,"moving closed G keeps exact owned state and no drop")
	transport.body.linear_velocity=velocity
	transport.compartments.set_open("trunk",true)
	for i in 100:await physics_frame
	camera.global_position=player.global_position+Vector3.UP*2;camera.look_at(transport.visual.root.to_global((bounds.min+bounds.max)*.5),Vector3.UP)
	before=weapons.inventory.snapshot()
	transport.body.linear_velocity=Vector3(.7,0,0)
	check(cargo.aim_context().near_trunk and cargo.aim_context().open,"moving open trunk keeps G context")
	press_g(cargo)
	check(weapons.inventory.snapshot()==before and cargo.cargo.summary(cargo.generation).count==0,"moving open G neither stores nor falls through to ground")
	check(not cargo.drop_held().ok and not cargo.store_held().ok,"direct actions also respect near-trunk semantics and speed admission")
	transport.body.linear_velocity=Vector3.ZERO
	check(transport.body.get_meta("profile_id")=="city_hatchback","actual main uses hatchback rather than sedan fixture")
	check(cargo.trunk_scale>0 and cargo.trunk_scale<.2,"one adaptive common scale fits shallower hatchback")
	var inventory_uids:Dictionary={}
	for id:String in Fire.ids():
		check(weapons.equip(id).ok,"equip actual arsenal "+id)
		weapons.fire_state.magazine=1;weapons.fire_state.reserveAmmo=71
		inventory_uids[id]=weapons.inventory.get_item_uid(id)
		var answer:Dictionary=cargo.store_held()
		check(answer.get("ok",false),"actual hatchback all14 store "+id+" "+str(answer.get("reason","")))
	var state:Dictionary=cargo.cargo.snapshot(cargo.generation)
	check(state.items.size()==14 and state.used_units==100 and weapons.inventory.get_owned_ids().is_empty(),"actual main all14 consume exactly100")
	for a in state.items.size():
		var box:AABB=state.items[a].item_bounds_local_m
		check(is_equal_approx(box.position.y,bounds.min.y),"actual hatchback every item floor-supported")
		for b in range(a+1,state.items.size()):check(not box.intersects(state.items[b].item_bounds_local_m),"actual hatchback all14 nonoverlap")
	cargo._refresh=0;cargo._process(0)
	check(cargo._hint.capacity.text.contains("Занято 100 / 100") and cargo._hint.capacity.text.contains("Свободно 0"),"open HUD shows exact full and free amount")
	for id:String in ["nagan","tt_pistol"]:
		if id=="tt_pistol":
			weapons.fire_state.magazine=1;weapons.fire_state.reserveAmmo=59;weapons.fire_state.cooldown=0
			weapons._held=true;weapons._pressed=true;weapons.advance(1.0/60.0)
			check(not weapons._pending_plan.is_empty(),"actual fire advancement queued a shot before trunk take")
		var aimed:=aim_item(cargo,camera,inventory_uids[id]);check(aimed,"real triangle aim before take "+id)
		if aimed and id=="nagan":
			transport._selected_panel=transport._nearest_panel()
			cargo._refresh=0;cargo._process(0)
			check(not transport._panel.visible and card_action(cargo._hint,"E","Взять"),"aimed item shows pickup E without conflicting close-trunk E")
			var queries:int=cargo.renderer.debug_snapshot().geometry_queries
			for tick in 120:transport._update_hint()
			check(cargo.renderer.debug_snapshot().geometry_queries==queries and not transport._panel.visible,"transport hint ticks reuse focus cache without new item geometry queries")
			camera.look_at(camera.global_position+Vector3.RIGHT*10,Vector3.UP);cargo._refresh=0;cargo._process(0)
			check(not transport._panel.visible and card_action(cargo._hint,"E","Закрыть багажник") and transport._cargo_item_hint_focus,"aim-off sample shows close-trunk on unified cargo card")
			aim_item(cargo,camera,inventory_uids[id]);cargo._refresh=0;cargo._process(0)
			weapons.set_menu(true);cargo._refresh=.1;queries=cargo.renderer.debug_snapshot().geometry_queries;cargo._process(0)
			check(not transport._cargo_item_hint_focus and not cargo._hint._active and cargo.renderer.debug_snapshot().geometry_queries==queries,"menu clears item focus immediately without a fresh geometry sample")
			weapons.set_menu(false);aim_item(cargo,camera,inventory_uids[id]);cargo._refresh=0;cargo._process(0)
			player._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT);cargo._refresh=.1;cargo._process(0)
			check(not transport._cargo_item_hint_focus and not cargo._hint._active,"actual application focus loss immediately clears item focus")
			player.set_mouse_captured(true);aim_item(cargo,camera,inventory_uids[id]);cargo._refresh=0;cargo._process(0)
			transport.compartments.set_open("trunk",false);cargo._refresh=.1;cargo._process(0)
			check(not transport._cargo_item_hint_focus and transport._panel.visible and transport._hint.text.contains("Открыть багажник"),"closing target clears focus and restores normal vehicle hint")
			transport.compartments.set_open("trunk",true);aim_item(cargo,camera,inventory_uids[id]);cargo._refresh=0;cargo._process(0)
		if aimed:
			check(cargo.take_item(inventory_uids[id]).get("ok",false),"real E collection "+id)
			check(weapons.fire_state.weaponId==id and weapons.inventory.snapshot().equippedId==id and weapons.presentation.get("_weapon").id==id,"trunk E immediately equips exact selected item "+id)
			check(weapons.inventory.get_item_uid(id)==inventory_uids[id] and weapons.fire_state.magazine==1 and weapons.fire_state.reserveAmmo==71,"trunk E equipped UID and ammunition retained "+id)
	check(weapons.inventory.get_owned_ids().has("nagan") and weapons.inventory.get_item_uid("nagan")==inventory_uids.nagan and weapons.inventory.get_fire_state("nagan").magazine==1 and weapons.inventory.get_fire_state("nagan").reserveAmmo==59,"new trunk weapon preserves previous held UID and uncommitted-shot fallback ammunition")
	check(weapons._pending_plan.is_empty() and not weapons._held and weapons.fire_state.weaponId=="tt_pistol","old pending fire cannot restore old weapon after taking new one")
	cargo._refresh=0;cargo._process(0)
	check(cargo._hint.capacity.text.contains("Свободно 6"),"open HUD updates capacity freed by real pickups")
	transport.compartments.set_open("trunk",false);cargo._process(0)
	check(not cargo._hint._active,"closed HUD immediately hides free amount")
	var before_failed_take:Dictionary=weapons.inventory.snapshot();var before_cargo:Dictionary=cargo.cargo.snapshot(cargo.generation)
	check(not cargo.take_item(inventory_uids.revolver).ok,"closed trunk refuses take after presentation preflight")
	check(weapons.inventory.snapshot()==before_failed_take and cargo.cargo.snapshot(cargo.generation)==before_cargo,"failed trunk take preserves both ownership stores")
	check(weapons.presentation.get("_weapon").get("id","")=="tt_pistol" and weapons.fire_state.weaponId=="tt_pistol","failed take restores previously held original model")
	player.global_position=Vector3(31,.01,-18)
	for i in 8:await physics_frame
	check(weapons.equip("nagan").ok,"first ground weapon equip")
	var first:Dictionary=cargo.drop_held();check(first.get("ok",false),"first actual ground drop")
	check(weapons.equip("tt_pistol").ok,"second ground weapon equip")
	var second:Dictionary=cargo.drop_held();check(second.get("ok",false),"successive same-frame ground drop finds another free placement")
	print("DROP_TRACE_FIRST ",first," SECOND ",second," player ",player.global_position," yaw ",player._visual.global_rotation.y)
	print("DROP_TRACE_REST ",cargo._ground_rest)
	if not second.get("ok",false):
		var origin:Vector3=player.global_position
		var yaw:float=player._visual.global_rotation.y
		for proposed:Vector3 in cargo.GroundRules.drop_points(origin,yaw):
			var floor:Dictionary=cargo._ground_floor(proposed)
			if floor.is_empty():print("DROP_TRACE nofloor ",proposed);continue
			var point:Vector3=floor.position
			var clear:bool=cargo.GroundRules.path_clear(origin,point,func(sample:Vector3):return cargo._ground_reachable(sample,.45))
			var item:Dictionary={"uid":weapons.inventory.get_item_uid("tt_pistol"),"weaponId":"tt_pistol","fireState":weapons.fire_state.duplicate(true)}
			var placement:Dictionary={"position":{"x":point.x,"y":point.y,"z":point.z},"yaw":yaw}
			var row:Dictionary=cargo.renderer._ground_row(item,placement)
			var overlap:bool=false
			for old:Dictionary in cargo._ground_rest.values():
				if row.world_box.grow(.005).intersects(old.world_aabb):overlap=true
			cargo._shape.size=row.world_box.size;cargo._shape_query.transform=Transform3D(Basis.IDENTITY,row.world_box.get_center());cargo._shape_query.exclude=[]
			var collisions:Array=scene.get_world_3d().direct_space_state.intersect_shape(cargo._shape_query,8)
			print("DROP_TRACE candidate ",proposed," floor ",point," water ",cargo._ground_has_water(point)," path ",clear," box ",row.world_box," overlaps ",overlap," collisions ",collisions)
			cargo.renderer._free_rows([row])
	if first.get("ok",false) and second.get("ok",false):
		var uid1:String=weapons.inventory.get_drop_item(first.drop.uid).uid;var uid2:String=weapons.inventory.get_drop_item(second.drop.uid).uid
		var row1:Dictionary=cargo.renderer.get("_ground")[first.drop.uid];var row2:Dictionary=cargo.renderer.get("_ground")[second.drop.uid]
		var box1:AABB=cargo._ground_rest[uid1].world_aabb;var box2:AABB=cargo._ground_rest[uid2].world_aabb
		check(cargo.renderer.debug_snapshot().falling_count==2,"both models still falling when reservations are checked")
		check(row1.visual.position.y>row1.rest_transform.origin.y+.5 and box1==row1.world_box,"reservation uses canonical settled bounds instead of animated pose")
		check(not box1.grow(.005).intersects(box2) and first.drop.position!=second.drop.position,"successive settled ground items do not overlap")
		var same:Dictionary={"item_uid":uid1,"weapon_id":first.drop.weaponId,"position":first.drop.position,"yaw":first.drop.yaw,"world_aabb":box1}
		check(cargo._validate_ground({"items":[same]}).ok,"actual same source item excluded during revalidation")
		same=same.duplicate(true);same.item_uid="new-unowned-candidate"
		check(not cargo._validate_ground({"items":[same]}).ok,"different item cannot bypass existing reservation at same pose")
		check(cargo.renderer.sync_ground(weapons.inventory.get_dropped(),weapons.inventory.item_identity_snapshot().dropped).ok,"existing ground sync preserves same-item semantics")
		for i in 40:await physics_frame
		check(cargo.renderer.debug_snapshot().falling_count==0 and cargo._ground_rest[uid1].world_aabb==box1,"settlement never moves canonical reservation")
		check(weapons.inventory.expire_drops(1e15).expired.size()==2,"actual inventory expiry removes source drops")
		cargo.renderer.sync_ground(weapons.inventory.get_dropped(),weapons.inventory.item_identity_snapshot().dropped)
		check(cargo._ground_reservations().boxes.is_empty() and cargo._ground_rest.is_empty(),"expired ownership retires reservations")
	print("CARGO_REGRESSION_SCALE ",cargo.trunk_scale)
	scene.free();await process_frame;await process_frame
	print("CARGO_REGRESSIONS ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),"scope":"actual main hatchback, originalall14, physics/input/HUD; headless CPU only"}))
	quit(0 if failures.is_empty() else 1)

func card_action(card: PanelContainer,key: String,label: String) -> bool:
	for row: Dictionary in card.action_rows:
		if row.row.visible and row.key.text==key and row.label.text.contains(label): return true
	return false
