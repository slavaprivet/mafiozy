extends Node
## Root integration: real camera pick, real trunk, prepared ownership transfers.
const Evidence = preload("res://scripts/transport/transport_cargo_evidence.gd")
const Store = preload("res://scripts/transport/trunk/transport_trunk_cargo_store.gd")
const Bridge = preload("res://scripts/weapons/weapon_cargo_bridge.gd")
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
var _hint: Label
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
	evidence=Evidence.new(); result=evidence.configure(transport.visual,transport.compartments)
	if not result.ok: return result
	cargo=Store.new(); result=cargo.configure(transport.body,vehicle_id,generation,evidence,transport.compartments)
	if not result.ok: return result
	bridge=Bridge.new(); result=bridge.configure(weapons.inventory,cargo,generation,Callable(self,"_sample"),Callable(renderer,"prepare_placement"),Callable(self,"_cancel"))
	if not result.ok: return result
	_shape_query.shape=_shape; _shape_query.collision_mask=7; _shape_query.margin=.001
	_hint=Label.new(); _hint.position=Vector2(22,154); _hint.add_theme_font_size_override("font_size",19); _hint.mouse_filter=Control.MOUSE_FILTER_IGNORE; weapons._layer.add_child(_hint)
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
			var hit: Dictionary=renderer.pick(origin,direction,12.0,{"enabled":true,"scope":"trunk","vehicle_id":vehicle_id,"generation":generation,"trunk_open":true})
			if hit.get("hit",false): result.item_uid=hit.item_uid
		return result
	var ground_hit: Dictionary=renderer.pick(origin,direction,12.0,{"enabled":true,"scope":"ground"})
	if ground_hit.get("hit",false):
		var point: Vector3=ground_hit.point
		var offset: Vector3=point-weapons.player.global_position
		if Vector2(offset.x,offset.z).length()<=1.65 and absf(offset.y)<=.65:
			var obstruction:=_ray_hit(origin,point)
			var approach:=_ray_hit(weapons.player.global_position+Vector3.UP*.2,point+Vector3.UP*.1)
			if (obstruction.is_empty() or obstruction.position.distance_to(point)<.03) and approach.is_empty(): result.drop_uid=ground_hit.drop_uid
	return result

func _sample() -> Dictionary:
	var context:=aim_context()
	return {"revision":1,"sample":evidence.sample(),"target_open":bool(context.open),"interaction_allowed":_allowed() and bool(context.cargo_allowed),"aimed_trunk":bool(context.aimed_trunk),"aimed_item_uid":str(context.item_uid)}

func _input(event: InputEvent) -> void:
	if not _allowed() or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if key not in [KEY_G,KEY_E]: return
	var context:=aim_context()
	if key==KEY_G and context.near_trunk:
		# Closed cargo never falls through to a ground drop.
		if context.cargo_allowed and context.open and context.aimed_trunk: store_held()
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
	weapons.cancel_inputs()
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
		weapons._profile=load("res://scripts/weapons/weapon_fire.gd").profile(str(weapons.fire_state.weaponId))
		weapons.cancel_inputs(); weapons.presentation.equip(str(weapons.fire_state.weaponId)); weapons._refresh_ui()
	else:
		_feedback="Недостаточно места" if str(result.get("reason","")) in ["CAPACITY","NO_PHYSICAL_SLOT"] else "Не удалось переместить оружие"
		_feedback_time=1.6
	_refresh=0
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
	var placement:=_placement(id,weapons.player.global_position,weapons.player._camera_yaw,[])
	if not placement.ok: return placement
	var item: Dictionary={"uid":weapons.inventory.get_item_uid(id),"weaponId":id,"fireState":weapons.fire_state.duplicate(true)}
	var prepared: Dictionary=renderer.prepare_ground_drop(item,{"position":placement.position,"yaw":placement.yaw})
	if not prepared.get("ok",false): return prepared
	var result: Dictionary=weapons.inventory.drop({"position":placement.position,"yaw":placement.yaw,"fireState":weapons.fire_state})
	if result.get("ok",false):
		var visible: Dictionary=renderer.activate_ground_drop(prepared.token,result.drop,item.uid)
		assert(visible.get("ok",false),"Prepared ground drop must activate after inventory commit")
		weapons.fire_state=result.fireState; weapons.cancel_inputs(); weapons.presentation.equip("none"); weapons._refresh_ui()
	else: renderer.cancel_placement(prepared.token)
	_refresh=0
	return result

func pickup_ground(uid: String) -> Dictionary:
	if not _allowed() or aim_context().drop_uid!=uid: return {"ok":false,"reason":"aim"}
	var result: Dictionary=weapons.inventory.pickup(uid,weapons.fire_state)
	if result.get("ok",false):
		weapons.fire_state=result.fireState
		renderer.sync_ground(weapons.inventory.get_dropped(),weapons.inventory.item_identity_snapshot().dropped)
		weapons._refresh_ui()
	_refresh=0
	return result

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
	if renderer.has_method("update"): renderer.update(delta)
	# Cheap lifetime/control checks clear the cache immediately, including menu,
	# released mouse and application focus loss. Aim changes use the .15s sample.
	if not _allowed() or not transport.compartments.is_open("trunk"):
		transport.set_cargo_item_hint_focus(false)
		_hint.text=""
	_feedback_time=maxf(0,_feedback_time-delta)
	_refresh-=delta; _expire-=delta
	if _expire<=0:
		_expire=1.0
		var expired: Dictionary=weapons.inventory.expire_drops()
		if not expired.get("expired",[]).is_empty(): renderer.sync_ground(weapons.inventory.get_dropped(),weapons.inventory.item_identity_snapshot().dropped)
	if _refresh>0: return
	_refresh=.15
	_hint.text=""
	if not _allowed(): return
	var context:=aim_context()
	transport.set_cargo_item_hint_focus(context.cargo_allowed and context.open and not str(context.item_uid).is_empty())
	if context.near_trunk and context.open:
		var state: Dictionary=bridge.actions()
		var lines: PackedStringArray=[]
		for action: Dictionary in state.get("actions",[]): lines.append(action.key+" — "+action.label)
		var used:=int(state.get("used_units",0))
		lines.append("Занято %d / 100 · Свободно %d" % [used,100-used])
		if int(state.get("selected_cost",0))>0: lines.append("Оружие займёт %d" % int(state.selected_cost))
		_hint.text="\n".join(lines)
	elif not str(context.drop_uid).is_empty(): _hint.text="E — Взять"
	if _feedback_time>0 and context.open: _hint.text+="\n"+_feedback

func _exit_tree() -> void:
	_ready_for_play=false
	if is_instance_valid(transport): transport.set_cargo_item_hint_focus(false)
	if bridge!=null: bridge.dispose()
	if cargo!=null: cargo.dispose()
	if evidence!=null: evidence.dispose()
	if renderer!=null: renderer.dispose()
	if catalogue!=null: catalogue.close()
