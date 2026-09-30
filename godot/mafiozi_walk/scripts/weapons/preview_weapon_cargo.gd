extends Node
const GroundRules = preload("res://scripts/weapons/ground_weapon_rules.gd")
const GroundWater = preload("res://scripts/preview_water_surface.gd")
var _ground_capsule := CapsuleShape3D.new()
var _ground_query := PhysicsShapeQueryParameters3D.new()
var _ground_water_cells: Dictionary = {}
var _ground_water_origin := Vector3.ZERO
var _ground_water_cell_size := 4.1
var _ground_water_known := false
const WalkCargoCard = preload("res://scripts/weapons/walk_cargo_card.gd")
const TrunkWindow = preload("res://scripts/weapons/walk_trunk_window.gd")
var window_open:=false
var _window:Control
var _window_epoch:=0
var _window_selected_uid:=""
var _window_busy:=false
var _window_snapshot:Dictionary={}
var _window_revision:=-1
var _modal_keys_down:Dictionary={}
var _modal_mouse_down:Dictionary={}
var _take_key_releases:Dictionary={}
var _take_mouse_releases:Dictionary={}
var _cargo_ui_revision := -1
var _cargo_ui_names: Dictionary = {}
var _cargo_card_scope := ""
var _ui_control_refs: Array=[]
var _ui_lid_bounds: Array=[]
var _ui_layout_bound:=false
## Root integration: real camera pick, real trunk, prepared ownership transfers.
const Evidence = preload("res://scripts/transport/transport_cargo_evidence.gd")
const Store = preload("res://scripts/transport/trunk/transport_trunk_cargo_store.gd")
const Bridge = preload("res://scripts/weapons/weapon_cargo_bridge.gd")
const CargoAim = preload("res://scripts/weapons/cargo_aim_picker.gd")
var _cargo_picker: RefCounted
const Pickups = preload("res://scripts/weapons/weapon_pickup_visuals.gd")
const Catalog = preload("res://scripts/weapon_visual/weapon_visual_catalog.gd")
var weapons: Node
var transport: Node3D
var renderer: RefCounted
var evidence: RefCounted
var cargo: RefCounted
var bridge: RefCounted
var catalogue: RefCounted
var vehicle_id := ""
var generation := 0
var _ready_for_play := false
var _hint: PanelContainer
var _refresh := 0.0
var _expire := 0.0
var _ray := PhysicsRayQueryParameters3D.new()
var _shape := BoxShape3D.new()
var _shape_query := PhysicsShapeQueryParameters3D.new()
var _feedback := ""
var _feedback_time := 0.0
var _destroy_source: Callable
var _destroy_receipt := ""
var _ground_rest: Dictionary={}
var trunk_scale := Pickups.TRUNK_SCALE

func configure(weapon_host: Node, vehicle_host: Node3D) -> Dictionary:
	if _ready_for_play or not is_instance_valid(weapon_host) or not is_instance_valid(vehicle_host) or not vehicle_host.ready_for_play: return {"ok":false,"reason":"binding"}
	weapons=weapon_host; transport=vehicle_host
	vehicle_id=str(transport.body.get_meta("vehicle_id","")); generation=int(transport.body.get_meta("life_generation",0))
	catalogue=Catalog.new()
	var result: Dictionary=catalogue.open()
	if not result.ok: return result
	trunk_scale=_scale_for_actual_cargo()
	if trunk_scale<=0: return {"ok":false,"reason":"cargo_dimensions"}
	renderer=Pickups.new()
	result=renderer.configure(catalogue,weapons.scene,Callable(self,"_validate_ground"),{"trunk_scale":trunk_scale})
	if not result.ok: return result
	result=renderer.bind_trunk(vehicle_id,generation,transport.visual.root)
	if not result.ok: return result
	_cargo_picker=CargoAim.new()
	_cargo_picker.configure(renderer,transport.visual.root,{"enabled":true,"scope":"trunk","vehicle_id":vehicle_id,"generation":generation,"trunk_open":true},Callable(self,"_cargo_ray_clear"))
	evidence=Evidence.new(); result=evidence.configure(transport.visual,transport.compartments)
	if not result.ok: return result
	cargo=Store.new(); result=cargo.configure(transport.body,vehicle_id,generation,evidence,transport.compartments)
	if not result.ok: return result
	bridge=Bridge.new(); result=bridge.configure(weapons.inventory,cargo,generation,Callable(self,"_sample"),Callable(renderer,"prepare_placement"),Callable(self,"_cancel"))
	if not result.ok: return result
	_shape_query.shape=_shape; _shape_query.collision_mask=7; _shape_query.margin=.001
	_hint=WalkCargoCard.new(); weapons._layer.add_child(_hint)
	_window=TrunkWindow.new();weapons._layer.add_child(_window);_window.configure(self)
	weapons.cargo_menu_owner=self
	_load_ground_water_policy()
	_ready_for_play=true
	return {"ok":true}

func _scale_for_actual_cargo() -> float:
	# One floor row is a sufficient, insertion-order-independent packing bound.
	# The actual preview hatchback is shallower than the sedan fixture.
	var bounds: Dictionary=transport.compartments.cargo_bounds()
	if bounds.is_empty(): return 0
	var size: Vector3=bounds.max-bounds.min
	var widths:=0.0; var height:=0.0; var depth:=0.0; var count:=0
	for id: String in Catalog.IDS:
		if id=="none": continue
		var box: Dictionary=catalogue.get_entry(id).profile.bounds_native
		widths+=float(box.max[0])-float(box.min[0]); height=maxf(height,float(box.max[1])-float(box.min[1])); depth=maxf(depth,float(box.max[2])-float(box.min[2])); count+=1
	if not size.is_finite() or widths<=0 or height<=0 or depth<=0: return 0
	var limit:=minf((size.x-(count-1)*(Store.GAP_M+Store.FRONTIER_PAD_M))/widths,minf(size.y/height,size.z/depth))
	return minf(Pickups.TRUNK_SCALE,.99*limit)

func _cancel(token: RefCounted) -> void: renderer.cancel_placement(token)
func _allowed() -> bool:
	return _ready_for_play and is_instance_valid(transport) and is_instance_valid(transport.body) and transport.ready_for_play and weapons._interaction_allowed() and not weapons.menu_open and transport.phase=="ON_FOOT"

func _ray_hit(from: Vector3,to: Vector3,exclude_car: bool=false) -> Dictionary:
	_ray.from=from; _ray.to=to; _ray.collision_mask=7
	var exclusions: Array[RID]=[weapons.player.get_rid()]
	if exclude_car: exclusions.append(transport.body.get_rid())
	_ray.exclude=exclusions
	return weapons.scene.get_world_3d().direct_space_state.intersect_ray(_ray)

func _cargo_ray_clear(origin: Vector3, point: Vector3) -> bool:
	var obstacle:=_ray_hit(origin,point,true)
	return obstacle.is_empty() or obstacle.position.distance_to(point)<.03

func _near_trunk_geometry() -> bool:
	# Proximity determines G's meaning even while speed/upright admission denies
	# a transfer. A moving/closed nearby trunk must never turn G into ground-drop.
	var profile: Dictionary=transport.compartments.access_profile("trunk")
	if profile.is_empty(): return false
	var local: Vector3=transport.body.to_local(weapons.player.global_position)
	var offset: Vector3=local-profile.position_local_m
	return offset.dot(profile.outward_local)>=.10 and absf(local.x)<=float(profile.get("width",1.91))*.5+.3 and absf(local.y)<=1.8 and Vector2(offset.x,offset.z).length()<=float(profile.range_m)

func aim_context() -> Dictionary:
	var result: Dictionary={"near_trunk":false,"cargo_allowed":false,"aimed_trunk":false,"item_uid":"","drop_uid":"","open":false}
	if not _allowed(): return result
	var camera: Camera3D=weapons.player.get_preview_camera()
	var origin:=camera.global_position; var direction: Vector3=-camera.global_basis.z
	var panel: Dictionary=transport._nearest_panel()
	result.near_trunk=_near_trunk_geometry()
	result.cargo_allowed=panel.get("kind")=="trunk"
	result.open=transport.compartments.is_open("trunk")
	if result.near_trunk:
		var bounds: Dictionary=transport.compartments.cargo_bounds()
		if bounds.is_empty(): return result
		var inverse: Transform3D=transport.visual.root.global_transform.affine_inverse()
		var box:=AABB(bounds.min,bounds.max-bounds.min).grow(.08)
		var entry: Variant=box.intersects_ray(inverse*origin,inverse.basis*direction)
		if entry is Vector3:
			var point: Vector3=transport.visual.root.global_transform*entry
			var obstruction:=_ray_hit(origin,point,true)
			result.aimed_trunk=obstruction.is_empty() or obstruction.position.distance_to(point)<.03
		if result.cargo_allowed and result.open and result.aimed_trunk:
			var hit: Dictionary=_cargo_picker.pick(camera)
			if hit.get("hit",false): result.item_uid=hit.item_uid; result.point=hit.point; result.weapon_id=hit.weaponId
		if result.cargo_allowed and result.open: return result
	var nearby:=_nearest_ground_context()
	if not nearby.is_empty(): result.merge(nearby,true)
	return result

func _sample() -> Dictionary:
	var context:=aim_context()
	var sample:Dictionary={"revision":1,"sample":evidence.sample(),"target_open":bool(context.open),"interaction_allowed":_allowed() and bool(context.cargo_allowed),"aimed_trunk":bool(context.aimed_trunk),"aimed_item_uid":str(context.item_uid)}
	if _window_access():
		sample.selection_mode="trunk_window" if window_open else ("aim" if not str(context.item_uid).is_empty() else "near_open_trunk")
		sample.window_open=window_open;sample.window_epoch=_window_epoch;sample.selected_item_uid=_window_selected_uid
	elif window_open:
		sample.interaction_allowed=false
	return sample

func _input(event: InputEvent) -> void:
	# A successful take may close the modal on key-down; its matching release
	# still belongs to that activation, never to a seat/jump/fire action.
	if event is InputEventKey:
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if _take_key_releases.has(code):
			if not event.pressed:_take_key_releases.erase(code)
			get_viewport().set_input_as_handled();return
		if code in [KEY_E,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
			if window_open and event.pressed:_modal_keys_down[code]=true
			elif not event.pressed:_modal_keys_down.erase(code)
	elif event is InputEventMouseButton:
		if _take_mouse_releases.has(event.button_index):
			if not event.pressed:_take_mouse_releases.erase(event.button_index)
			get_viewport().set_input_as_handled();return
		if event.button_index==MOUSE_BUTTON_LEFT:
			if window_open and event.pressed:_modal_mouse_down[event.button_index]=true
			elif not event.pressed:_modal_mouse_down.erase(event.button_index)
	if window_open:return # Weapon host owns modal keys before transport/player shortcuts.
	if not _allowed() or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if key not in [KEY_G,KEY_E,KEY_F]: return
	var context:=aim_context()
	if key==KEY_F and context.near_trunk and context.open:
		open_window();get_viewport().set_input_as_handled();return
	if key==KEY_G and context.near_trunk:
		# Closed cargo never falls through to a ground drop.
		if _window_access(): store_held()
		get_viewport().set_input_as_handled(); return
	if key==KEY_E and not str(context.item_uid).is_empty():
		take_item(context.item_uid); get_viewport().set_input_as_handled(); return
	if key==KEY_E and not str(context.drop_uid).is_empty():
		pickup_ground(context.drop_uid); get_viewport().set_input_as_handled(); return
	if key==KEY_G and weapons.armed():
		drop_held(); get_viewport().set_input_as_handled()

func store_held() -> Dictionary:
	if not _allowed() or not weapons.armed(): return {"ok":false,"reason":"inactive"}
	weapons.cancel_inputs()
	var result: Dictionary=bridge.store(renderer.model_aabb(str(weapons.fire_state.weaponId)),weapons.fire_state)
	return _apply_transfer(result)

func take_item(uid: String) -> Dictionary:
	if not _allowed(): return {"ok":false,"reason":"inactive"}
	# Settle any uncommitted shot against the OLD held UID before presentation
	# or ownership changes. A later cancellation must not restore an old weapon.
	# Keep the displayed aim ray stable through the paired ownership checks.
	# The successful transfer resets the view only after committing this UID.
	weapons.cancel_inputs(false)
	var selected: Dictionary={}
	var snapshot: Dictionary=cargo.snapshot(generation)
	if not snapshot.get("ok",false): return snapshot
	for entry: Dictionary in snapshot.items:
		if entry.item.uid==uid: selected=entry.item; break
	if selected.is_empty(): return {"ok":false,"reason":"missing_item"}
	var previous_id: String=weapons.fire_state.weaponId
	# Latest user choice: E from the trunk immediately puts this exact item in
	# hand. Load/attach that presentation BEFORE either ownership owner commits.
	var prepared: Dictionary=weapons.presentation.equip(selected.weaponId)
	if not prepared.get("ok",false): return prepared
	var result: Dictionary=bridge.take(uid,weapons.fire_state)
	if not result.get("ok",false):
		weapons.presentation.equip(previous_id)
		return _apply_transfer(result)
	return _apply_transfer(result,selected.weaponId)

func _apply_transfer(result: Dictionary,equip_taken: String="") -> Dictionary:
	if result.get("ok",false):
		var visible: Dictionary=renderer.activate_placement(result.placement_token,result)
		assert(visible.get("ok",false),"Prepared visual activation must succeed immediately after paired commits")
		if not equip_taken.is_empty():
			# Concrete Inventory.equip has no clock/external callbacks. Its exact
			# UID was just imported; old held ammunition was preserved by the take.
			var equipped: Dictionary=weapons.inventory.equip(equip_taken,result.inventory.fireState)
			assert(equipped.get("ok",false),"Just-imported exact trunk item must equip")
			result.inventory.merge(equipped,true)
		weapons.fire_state=result.inventory.fireState
		if is_instance_valid(weapons._walk_ui): weapons._walk_ui.invalidate_inventory()
		weapons._profile=load("res://scripts/weapons/weapon_fire.gd").profile(str(weapons.fire_state.weaponId))
		weapons.cancel_inputs(); weapons.presentation.equip(str(weapons.fire_state.weaponId)); weapons._refresh_ui()
	else:
		_feedback="Недостаточно места" if str(result.get("reason","")) in ["CAPACITY","NO_PHYSICAL_SLOT"] else "Не удалось переместить оружие"
		_feedback_time=1.6
	_refresh=0
	if window_open: _refresh_window(true)
	return result

func _ground_reservations(same_items: Array=[]) -> Dictionary:
	# Canonical settled geometry, never a falling node's current world AABB.
	# Every cached row is matched against authoritative inventory identity/pose.
	var identities: Dictionary=weapons.inventory.item_identity_snapshot().dropped
	var boxes: Array[AABB]=[]; var live: Dictionary={}
	for drop: Dictionary in weapons.inventory.get_dropped():
		var uid: String=str(identities.get(drop.uid,""))
		if uid.is_empty(): return {"ok":false}
		live[uid]=true
		var same:=false
		for item: Dictionary in same_items:
			if item.get("item_uid")==uid and item.get("weapon_id")==drop.weaponId and item.get("position")==drop.position and item.get("yaw")==drop.yaw: same=true; break
		if same: continue
		var rest: Dictionary=_ground_rest.get(uid,{})
		if rest.is_empty() or rest.weapon_id!=drop.weaponId or rest.position!=drop.position or rest.yaw!=drop.yaw: return {"ok":false}
		boxes.append(rest.world_aabb)
	# Cancelled preflight/expired drop entries have no ownership authority.
	for uid: String in _ground_rest.keys():
		if not live.has(uid): _ground_rest.erase(uid)
	return {"ok":true,"boxes":boxes}

func _validate_ground(request: Dictionary) -> Dictionary:
	if not is_instance_valid(weapons) or not weapons._owner_current() or not request.get("items") is Array: return {"ok":false}
	var existing:=_ground_reservations(request.items)
	if not existing.ok: return {"ok":false}
	var boxes: Array[AABB]=existing.boxes
	var floors: Array[float]=[]
	var accepted: Dictionary={}
	for item: Dictionary in request.items:
		if not item.get("world_aabb") is AABB: return {"ok":false}
		var box: AABB=item.world_aabb
		if not box.position.is_finite() or not box.size.is_finite() or box.size.x<=0 or box.size.y<=0 or box.size.z<=0: return {"ok":false}
		var floor_height: float=float(item.position.y)
		for x: float in [box.position.x,box.end.x]:
			for z: float in [box.position.z,box.end.z]:
				var floor:=_ray_hit(Vector3(x,box.position.y+.3,z),Vector3(x,box.position.y-.3,z))
				if floor.is_empty() or floor.normal.y<.8: return {"ok":false}
				floor_height=maxf(floor_height,float(floor.position.y))
		box.position.y+=floor_height+.009-box.position.y
		for prior: AABB in boxes:
			if box.grow(.005).intersects(prior): return {"ok":false}
		var center:=box.get_center()
		_shape.size=box.size; _shape_query.transform=Transform3D(Basis.IDENTITY,center); _shape_query.exclude=[]
		if not weapons.scene.get_world_3d().direct_space_state.intersect_shape(_shape_query,1).is_empty(): return {"ok":false}
		boxes.append(box)
		floors.append(floor_height)
		if item.get("item_uid") is String and item.item_uid!="placement":
			accepted[item.item_uid]={"weapon_id":item.weapon_id,"position":item.position.duplicate(true),"yaw":item.yaw,"world_aabb":box}
	for uid: String in accepted: _ground_rest[uid]=accepted[uid]
	return {"ok":true,"floors":floors}

func _placement(id: String,center: Vector3,yaw: float,reserved: Array[AABB]) -> Dictionary:
	var local: AABB=renderer.model_aabb(id,"ground")
	var existing:=_ground_reservations()
	if not existing.ok: return {"ok":false,"reason":"ground_reservations"}
	var occupied: Array[AABB]=reserved.duplicate()
	occupied.append_array(existing.boxes)
	for ring: float in [1.15,1.75,2.4,3.1]:
		for angle: float in [0.0,.8,-.8,1.6,-1.6,2.4,-2.4,PI]:
			var horizontal:=Vector3(-sin(yaw+angle),0,-cos(yaw+angle))*ring
			var sample:=center+horizontal
			var floor:=_ray_hit(sample+Vector3.UP*1.5,sample-Vector3.UP*2.0)
			if floor.is_empty() or floor.normal.y<.8: continue
			var point: Vector3=floor.position
			var box: AABB=Transform3D(Basis(Vector3.UP,yaw),point)*local
			var blocked:=false
			for prior: AABB in occupied:
				if box.grow(.005).intersects(prior): blocked=true; break
			if blocked: continue
			var row: Dictionary={"item_uid":"placement","weapon_id":id,"position":{"x":point.x,"y":point.y,"z":point.z},"yaw":yaw,"world_aabb":box}
			var admitted:=_validate_ground({"items":[row]})
			if admitted.ok:
				box.position.y=float(admitted.floors[0])+.009
				return {"ok":true,"position":row.position,"yaw":yaw,"world_aabb":box}
	return {"ok":false,"reason":"ground_space"}

func drop_held() -> Dictionary:
	if not _allowed() or not weapons.armed(): return {"ok":false,"reason":"inactive"}
	if _near_trunk_geometry(): return {"ok":false,"reason":"near_trunk"}
	weapons.cancel_inputs()
	var id: String=weapons.fire_state.weaponId
	var placement:=_ground_drop_placement(id)
	if not placement.ok: return placement
	var item: Dictionary={"uid":weapons.inventory.get_item_uid(id),"weaponId":id,"fireState":weapons.fire_state.duplicate(true)}
	var prepared: Dictionary=placement.prepared
	if not prepared.get("ok",false): return prepared
	if not _allowed() or str(weapons.fire_state.weaponId)!=id or weapons.inventory.get_item_uid(id)!=item.uid:
		renderer.cancel_placement(prepared.token)
		return {"ok":false,"reason":"selection_changed"}
	var result: Dictionary=weapons.inventory.drop({"position":placement.position,"yaw":placement.yaw,"fireState":weapons.fire_state})
	if result.get("ok",false):
		var visible: Dictionary=renderer.activate_ground_drop(prepared.token,result.drop,item.uid)
		assert(visible.get("ok",false),"Prepared ground drop must activate after inventory commit")
		weapons.fire_state=result.fireState; weapons.cancel_inputs(); weapons.presentation.equip("none"); weapons._refresh_ui()
	else: renderer.cancel_placement(prepared.token)
	_refresh=0
	return result

func pickup_ground(uid: String) -> Dictionary:
	# Real Walk host E picks up AND equips; Inventory.pickup alone only collects.
	if not _allowed() or str(aim_context().drop_uid)!=uid: return {"ok":false,"reason":"reach"}
	weapons.cancel_inputs()
	var selected: Variant=weapons.inventory.get_drop_item(uid)
	if not selected is Dictionary: _sync_ground_after_mutation(); return {"ok":false,"reason":"missing_drop"}
	var previous: String=str(weapons.fire_state.weaponId)
	var identity: String=str(selected.uid)
	var target: String=str(selected.weaponId)
	# Resource loading/mesh setup may fail. Prepare before ownership changes.
	var prepared: Dictionary=weapons.presentation.equip(target)
	if not prepared.get("ok",false): return prepared
	var fresh: Variant=weapons.inventory.get_drop_item(uid)
	if not _allowed() or not fresh is Dictionary or fresh.uid!=identity or fresh.weaponId!=target or str(aim_context().drop_uid)!=uid:
		weapons.presentation.equip(previous)
		return {"ok":false,"reason":"selection_changed"}
	var current: Dictionary=weapons._inventory_state(weapons.fire_state)
	var result: Dictionary=weapons.inventory.pickup(uid,current)
	if not result.get("ok",false):
		weapons.presentation.equip(previous)
		_sync_ground_after_mutation() # expiry failure also removes its old mesh
		return result
	# No await/callback/resource loading between concrete inventory commits.
	var equipped: Dictionary=weapons.inventory.equip(target,result.fireState)
	assert(equipped.get("ok",false),"Just-collected original item must equip")
	assert(weapons.inventory.get_item_uid(target)==identity,"Ground pickup must retain item identity")
	result.merge(equipped,true)
	weapons.fire_state=result.fireState
	weapons._profile=load("res://scripts/weapons/weapon_fire.gd").profile(target)
	_sync_ground_after_mutation()
	return result

func _sync_ground_after_mutation() -> void:
	var synced: Dictionary=renderer.sync_ground(weapons.inventory.get_dropped(),weapons.inventory.item_identity_snapshot().dropped)
	assert(synced.get("ok",false),"Existing ground rows must reconcile after pickup/expiry")
	if is_instance_valid(weapons._walk_ui): weapons._walk_ui.invalidate_inventory()
	weapons._refresh_ui()
	_refresh=0

func bind_destruction_source(source: Callable) -> bool:
	# Only the vehicle damage owner can supply destruction events; no UI key
	# or observed cosmetic explosion fabricates this authority.
	if _destroy_source.is_valid() or not source.is_valid() or source.get_argument_count()!=1: return false
	_destroy_source=source
	return true

func consume_vehicle_destruction(event_uid: String) -> Dictionary:
	if not _ready_for_play or not _destroy_source.is_valid() or event_uid.is_empty(): return {"ok":false,"reason":"source_unavailable"}
	var event: Variant=_destroy_source.call(event_uid)
	if not event is Dictionary or event.get("event_id")!=event_uid or event.get("vehicle_id")!=vehicle_id or event.get("life_generation")!=generation or event.get("body_instance_id")!=transport.body.get_instance_id() or event.get("destroyed")!=true: return {"ok":false,"reason":"source_identity"}
	if event_uid==_destroy_receipt: return {"ok":true,"duplicate":true}
	var snapshot: Dictionary=cargo.snapshot(generation)
	if not snapshot.get("ok",false): return snapshot
	var placements: Array=[]; var reserved: Array[AABB]=[]
	for entry: Dictionary in snapshot.items:
		var placement:=_placement(entry.item.weaponId,transport.body.global_position,transport.body.global_rotation.y,reserved)
		if not placement.ok: return placement
		reserved.append(placement.world_aabb)
		placements.append({"position":placement.position,"yaw":placement.yaw})
	var result: Dictionary=bridge.destroy(event_uid,placements)
	if not result.get("ok",false): return result
	if result.get("placement_token")!=null:
		var visible: Dictionary=renderer.activate_placement(result.placement_token,result)
		assert(visible.get("ok",false),"Prepared destruction batch activates exactly once")
	_destroy_receipt=event_uid
	_refresh=0
	return result

func _process(delta: float) -> void:
	if not _ready_for_play: return
	if not _allowed():_take_key_releases.clear();_take_mouse_releases.clear()
	if window_open and (not _allowed() or not transport.compartments.is_open("trunk")):_invalidate_window_controls()
	if renderer.has_method("update"): renderer.update(delta)
	# Invalidation is immediate; geometry/authority sampling remains bounded.
	# Do not erase a ground pickup hint each frame merely because trunk is closed.
	if not _allowed() or (_cargo_card_scope=="trunk" and not transport.compartments.is_open("trunk")):
		_clear_cargo_ui()
	_feedback_time=maxf(0,_feedback_time-delta)
	_refresh-=delta; _expire-=delta
	if _expire<=0:
		_expire=1.0
		var expired: Dictionary=weapons.inventory.expire_drops()
		if not expired.get("expired",[]).is_empty(): renderer.sync_ground(weapons.inventory.get_dropped(),weapons.inventory.item_identity_snapshot().dropped)
	if _refresh>0: return
	_refresh=.15
	if not _allowed(): return
	if window_open:
		if not _window_access():_invalidate_window_controls()
		else:_refresh_window()
		return
	var context:=aim_context()
	if renderer.has_method("set_hover"):renderer.set_hover(context)
	var camera: Camera3D=weapons.player.get_preview_camera()
	weapons.set_cargo_reticle(bool(context.near_trunk and context.open) or not str(context.drop_uid).is_empty())
	if context.near_trunk and context.open:
		var state: Dictionary=bridge.actions()
		if not state.get("ok",false): _clear_cargo_ui(); return
		var summary: Dictionary=cargo.summary(generation)
		if summary.get("ok",false) and int(summary.revision)!=_cargo_ui_revision:
			var contents: Dictionary=cargo.snapshot(generation)
			if contents.get("ok",false):
				_cargo_ui_names.clear()
				for entry: Dictionary in contents.items: _cargo_ui_names[str(entry.item.uid)]=str(entry.item.weaponId)
				_cargo_ui_revision=int(contents.revision)
		var aimed_uid:String=str(context.item_uid)
		var actions:Array=[{"key":"E","label":"Взять" if not aimed_uid.is_empty() else "Закрыть крышку"},{"key":"F","label":"Содержимое"}]
		transport.set_cargo_item_hint_focus(bool(context.cargo_allowed))
		var detail:String="G — положить оружие" if weapons.armed() else ""
		if _feedback_time>0: detail+=("\n" if not detail.is_empty() else "")+_feedback
		var bounds: Dictionary=transport.compartments.cargo_bounds()
		if bounds.is_empty(): _clear_cargo_ui(); return
		var anchor: Vector3=transport.visual.root.to_global((bounds.min+bounds.max)*.5)+Vector3.UP*.65
		_cargo_card_scope="trunk"
		var targets: Array=[{"node":weakref(transport.visual.root),"bounds":AABB(bounds.min,bounds.max-bounds.min)}]
		var item_bounds: Dictionary=renderer.ui_bounds("trunk",str(context.item_uid),vehicle_id,generation)
		if not item_bounds.is_empty(): targets.append(item_bounds)
		_bind_ui_layout()
		targets.append_array(_ui_lid_bounds)
		_hint.set_layout_context(camera,"trunk:"+vehicle_id,targets,weapons.player,_ui_control_refs)
		var title:String=weapons.LABELS.get(_cargo_ui_names.get(aimed_uid,""),"Багажник") if not aimed_uid.is_empty() else "Багажник"
		_hint.present_trunk(camera,anchor,title,actions,detail)
	elif not str(context.drop_uid).is_empty():
		transport.set_cargo_item_hint_focus(false)
		# Pick metadata is already present in renderer.pick; no new ray/mesh query.
		var point: Variant=context.get("point")
		var id: String=str(context.get("weapon_id",""))
		if not point is Vector3:
			for drop: Dictionary in weapons.inventory.get_dropped():
				if str(drop.uid)==str(context.drop_uid):
					point=Vector3(drop.position.x,drop.position.y,drop.position.z); id=str(drop.weaponId); break
		if not point is Vector3: _clear_cargo_ui(); return
		_cargo_card_scope="ground"
		var target_bounds: Dictionary=renderer.ui_bounds("ground",str(context.drop_uid))
		if target_bounds.is_empty(): _clear_cargo_ui(); return
		_bind_ui_layout()
		_hint.set_layout_context(camera,"ground:"+str(context.drop_uid),[target_bounds],weapons.player,_ui_control_refs)
		_hint.present_ground(weapons.LABELS.get(id,"Оружие"),int(context.get("magazine",0)),int(context.get("reserveAmmo",0)))
	else:
		_clear_cargo_ui()

func _clear_cargo_ui() -> void:
	if renderer!=null and renderer.has_method("clear_hover"):renderer.clear_hover()
	_cargo_card_scope=""
	transport.set_cargo_item_hint_focus(false)
	weapons.set_cargo_reticle(false)
	_hint.clear()

func _exit_tree() -> void:
	close_window(false)
	if is_instance_valid(weapons) and weapons.cargo_menu_owner==self:weapons.cargo_menu_owner=null
	if is_instance_valid(_window):_window.queue_free()
	_ready_for_play=false
	if is_instance_valid(transport): transport.set_cargo_item_hint_focus(false)
	if bridge!=null: bridge.dispose()
	if cargo!=null: cargo.dispose()
	if evidence!=null: evidence.dispose()
	if renderer!=null: renderer.dispose()
	if catalogue!=null: catalogue.close()

func _load_ground_water_policy() -> void:
	# Exact currently-loaded source water crop. This is local geometry admission,
	# not an invented authoritative water/save API. Missing evidence denies G.
	_ground_query.shape=_ground_capsule; _ground_query.collision_mask=7; _ground_query.margin=.001
	_ground_query.exclude=[weapons.player.get_rid()]
	var path: Variant=weapons.scene.get("water_data_path")
	if not path is String or not FileAccess.file_exists(path): return
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not GroundWater.validate(data).is_empty(): return
	_ground_water_origin=Vector3(data.originM[0],data.originM[1],data.originM[2])
	_ground_water_cell_size=float(data.metresPerCell)
	for cell: Dictionary in data.native.cells: _ground_water_cells[Vector2i(int(cell.c),int(cell.r))]=true
	_ground_water_known=true

func _ground_has_water(point: Vector3) -> bool:
	if not _ground_water_known: return true
	var original:=point+_ground_water_origin
	return _ground_water_cells.has(Vector2i(int(floor(original.x/_ground_water_cell_size)),int(floor(original.z/_ground_water_cell_size))))

func _ground_floor(point: Vector3) -> Dictionary:
	return _ray_hit(point+Vector3.UP*.70,point-Vector3.UP*.70)

func _ground_reachable(point: Vector3, maximum_step: float) -> bool:
	var floor:=_ground_floor(point)
	if floor.is_empty() or floor.normal.y<.8 or absf(floor.position.y-point.y)>=maximum_step: return false
	# Source samples pedestrianAllowed along every .12m of the short path.
	# Native scene uses actual blocking collision and current player footprint.
	var collider: CollisionShape3D=weapons.player.get_node("PlayerCapsule")
	var actual: CapsuleShape3D=collider.shape
	_ground_capsule.radius=actual.radius; _ground_capsule.height=maxf(actual.height-.012,actual.radius*2)
	_ground_query.transform=Transform3D(Basis.IDENTITY,Vector3(point.x,floor.position.y+_ground_capsule.height*.5+.012,point.z))
	return weapons.scene.get_world_3d().direct_space_state.intersect_shape(_ground_query,1).is_empty()

func _nearest_ground_context() -> Dictionary:
	if not _allowed(): return {}
	var expired: Dictionary=weapons.inventory.expire_drops()
	if not expired.get("expired",[]).is_empty(): _sync_ground_after_mutation()
	var origin: Vector3=weapons.player.global_position
	var candidate: Dictionary=GroundRules.nearest(weapons.inventory.get_dropped(),origin,func(point: Vector3): return _ground_reachable(point,.65))
	if candidate.is_empty(): return {}
	var item: Variant=weapons.inventory.get_drop_item(candidate.drop.uid)
	if not item is Dictionary: return {}
	var visual: Dictionary=renderer.ground_receipt(str(candidate.drop.uid),str(item.uid))
	if not visual.get("ok",false): return {}
	# Whole-footpath sampling prevents through-wall/floor collection without
	# requiring a six-pixel gun to be precisely under the camera crosshair.
	return {"drop_uid":str(candidate.drop.uid),"point":visual.point,"weapon_id":str(item.weaponId),"magazine":int(item.fireState.magazine),"reserveAmmo":int(item.fireState.reserveAmmo)}

func _ground_drop_placement(id: String) -> Dictionary:
	if not _ground_water_known: return {"ok":false,"reason":"water_contract"}
	var origin: Vector3=weapons.player.global_position
	var yaw: float=weapons.player._visual.global_rotation.y
	# Source order .8/.55/.3/0 in actual hero +Z direction. No long-ring search
	# beyond a wall. Destruction scatter retains its separate original method.
	for proposed: Vector3 in GroundRules.drop_points(origin,yaw):
		var floor:=_ground_floor(proposed)
		if floor.is_empty() or floor.normal.y<.8: continue
		var point: Vector3=floor.position
		if _ground_has_water(point) or not GroundRules.path_clear(origin,point,func(sample: Vector3): return _ground_reachable(sample,.45)): continue
		var item: Dictionary={"uid":weapons.inventory.get_item_uid(id),"weaponId":id,"fireState":weapons.fire_state.duplicate(true)}
		# Source model-centred exact vertices, all footprint floor samples and
		# collision/no-overlap checks already live in the existing renderer.
		var prepared: Dictionary=renderer.prepare_ground_drop(item,{"position":{"x":point.x,"y":point.y,"z":point.z},"yaw":yaw})
		if not prepared.get("ok",false): continue
		return {"ok":true,"position":{"x":point.x,"y":point.y,"z":point.z},"yaw":yaw,"prepared":prepared}
	return {"ok":false,"reason":"ground_space"}

func _bind_ui_layout() -> void:
	if _ui_layout_bound: return
	_ui_layout_bound=true
	# Once after scene construction: actual main HUD rectangles, not hardcoded size.
	for child: Node in weapons.scene.get_children():
		if not child is CanvasLayer: continue
		for control: Node in child.get_children():
			if control is Control: _ui_control_refs.append(weakref(control))
	_ui_control_refs.append(weakref(weapons._walk_ui.launcher))
	var panels: Dictionary=transport.compartments.get("_panels")
	var lid: Node3D=panels.get("trunk",{}).get("lid")
	if not is_instance_valid(lid): return
	var meshes: Array=lid.find_children("*","MeshInstance3D",true,false)
	if lid is MeshInstance3D: meshes.append(lid)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh!=null: _ui_lid_bounds.append({"node":weakref(mesh),"bounds":mesh.get_aabb()})

## Explicit modal selection retains actual access/lid/body/ownership admission.
func _window_access()->bool:
	if not _allowed() or not _near_trunk_geometry() or transport._nearest_panel().get("kind")!="trunk" or not transport.compartments.is_open("trunk"):return false
	var sample:Dictionary=evidence.sample()
	if not sample.get("available",false) or not sample.get("has_floor",false) or float(sample.get("amount",0))<.85:return false
	var profile:Dictionary=transport.compartments.access_profile("trunk")
	var point:Vector3=transport.body.to_global(profile.position_local_m+profile.outward_local*.12)
	var ray:Dictionary=_ray_hit(weapons.player.global_position+Vector3.UP*.9,point,true)
	return ray.is_empty() or ray.position.distance_to(point)<.03

func _release_window_actions()->void:
	for action:StringName in [weapons.player.ACTION_LEFT,weapons.player.ACTION_RIGHT,weapons.player.ACTION_FORWARD,weapons.player.ACTION_BACK,weapons.player.ACTION_RUN,weapons.player.ACTION_JUMP]:
		if InputMap.has_action(action):Input.action_release(action)

func open_window()->bool:
	if window_open:return true
	if not _window_access():return false
	var state:Dictionary=cargo.snapshot(generation)
	if not state.get("ok",false) or state.destroyed or state.pending:return false
	weapons.cancel_inputs();weapons.set_menu(false);_release_window_actions()
	_window_epoch+=1;window_open=true;_window_selected_uid="";_window_revision=-1;_window.visible=true
	_clear_cargo_ui();transport.set_cargo_item_hint_focus(true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_refresh_window(true);return true

func close_window(capture:bool=true)->void:
	if not window_open:return
	window_open=false;_window_epoch+=1;_window_selected_uid="";_window_snapshot.clear();_window_revision=-1
	_modal_keys_down.clear();_modal_mouse_down.clear()
	if is_instance_valid(_window):_window.clear_hover();_window.visible=false
	if is_instance_valid(transport):transport.set_cargo_item_hint_focus(false)
	if is_instance_valid(weapons):
		weapons.cancel_inputs();_release_window_actions()
		if capture and weapons._interaction_allowed():_resume_window_controls()
	_refresh=0

func _invalidate_window_controls()->void:
	close_window(false)
	if is_instance_valid(weapons) and is_instance_valid(weapons.player):weapons.player.set_mouse_captured(false)

func _resume_window_controls()->void:
	# Normal focused gameplay resumes immediately. Synthetic offscreen QA must
	# not steal the desktop cursor; losing focus also suspends logical controls.
	if DisplayServer.get_name()=="headless" or (get_window().has_focus() and not get_window().unfocusable):
		weapons.player.set_mouse_captured(true)
		_restore_window_movement()
	else:weapons.player.set_mouse_captured(false)

func _restore_window_movement()->void:
	# Modal keys release actions without releasing physical keys. Resume only
	# the movement still physically held when this valid, focused modal closes.
	# E, jump and mouse activation stay quarantined; never replay them as actions.
	if not _allowed():return
	for action:StringName in [weapons.player.ACTION_LEFT,weapons.player.ACTION_RIGHT,weapons.player.ACTION_FORWARD,weapons.player.ACTION_BACK,weapons.player.ACTION_RUN]:
		for mapped:InputEvent in InputMap.action_get_events(action):
			if not mapped is InputEventKey:continue
			var held:bool=Input.is_physical_key_pressed(mapped.physical_keycode) if mapped.physical_keycode!=0 else Input.is_key_pressed(mapped.keycode)
			if held:Input.action_press(action);break

func window_input(event:InputEvent)->bool:
	if not window_open:return false
	if event is InputEventKey:
		_release_window_actions()
		if event.pressed and not event.echo:
			var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
			if code==KEY_Q:close_window()
			elif code==KEY_E:
				var uid:String=_window.hovered_item_uid()
				if not uid.is_empty():window_take(uid)
			elif code==KEY_ESCAPE:close_window(false);weapons.player.set_mouse_captured(false)
			elif code==KEY_G:window_store()
		return true
	return event is InputEventMouseButton or event is InputEventMouseMotion

func window_store()->Dictionary:
	if _window_busy or not window_open or not _window_access():return {"ok":false,"reason":"window_access"}
	_window_busy=true
	var result:Dictionary=store_held()
	_window_busy=false;_refresh_window(true);return result

func window_take(uid:String)->Dictionary:
	if _window_busy or not window_open or not _window_access():return {"ok":false,"reason":"window_access"}
	_window_busy=true;_window_selected_uid=uid
	var result:Dictionary=take_item(uid)
	_window_selected_uid="";_window_busy=false
	if result.get("ok",false):
		# Claim the GUI activation before hiding controls. Button activation can
		# occur on either edge; currently held activation edges are quarantined.
		get_viewport().set_input_as_handled()
		_take_key_releases=_modal_keys_down.duplicate();_take_mouse_releases=_modal_mouse_down.duplicate()
		_modal_keys_down.clear();_modal_mouse_down.clear()
		weapons.cancel_inputs();close_window()
	else:
		_feedback="Оружие уже недоступно" if result.get("reason")=="missing_item" else "Не удалось взять оружие"
		_feedback_time=1.6;_refresh_window(true)
	return result

func window_close_lid()->void:
	if not window_open or not _window_access():return
	close_window();transport.compartments.set_open("trunk",false)

func _refresh_window(force:bool=false)->void:
	if not window_open:return
	var summary:Dictionary=cargo.summary(generation)
	if not summary.get("ok",false) or summary.destroyed:_invalidate_window_controls();return
	if force or _window_revision!=int(summary.revision):
		_window_snapshot=cargo.snapshot(generation)
		if not _window_snapshot.get("ok",false):_invalidate_window_controls();return
		_window_revision=int(summary.revision)
	_window.present(_window_snapshot,weapons.fire_state,_feedback if _feedback_time>0 else "")
