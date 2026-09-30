extends Node
## Virtual local-session equipment. Existing weapon scripts/inventory are unchanged.
## The explosion owner must synchronously consume_detonation(event) once before
## applying/queuing damage. These receipts are NOT native RPG or bullet receipts.
const WeaponUI = preload("res://scripts/weapons/walk_weapon_ui.gd")
const HOLD_SECONDS := 3.0
const REACH_M := 2.5
const MAX_CHARGES := 8
const DAMAGE := 480.0
const BLAST_RADIUS_M := 2.4
const AIM_DRIFT_M := 0.065
const ACTOR_DRIFT_M := 0.04

class ProgressCard extends Control:
	var fraction := 0.0
	var ring := true
	var heading: Label
	var detail: Label
	var counter: Label
	var panel: StyleBoxFlat
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE; custom_minimum_size=Vector2(278,78); size=custom_minimum_size
		panel=StyleBoxFlat.new(); panel.bg_color=Color("20282bea"); panel.border_color=Color("90794f")
		panel.set_border_width_all(1); panel.set_corner_radius_all(9); panel.shadow_size=6; panel.shadow_color=Color(0,0,0,.28)
		heading=Label.new(); heading.position=Vector2(73,13); heading.size=Vector2(194,23); heading.add_theme_font_size_override("font_size",16); heading.add_theme_color_override("font_color",Color("eee5cd")); heading.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(heading)
		detail=Label.new(); detail.position=Vector2(73,41); detail.size=Vector2(194,22); detail.add_theme_font_size_override("font_size",11); detail.add_theme_color_override("font_color",Color("cbb98f")); detail.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(detail)
		counter=Label.new(); counter.position=Vector2(10,26); counter.size=Vector2(53,25); counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; counter.add_theme_font_size_override("font_size",13); counter.add_theme_color_override("font_color",Color("f4ecd8")); counter.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(counter)
	func present(title: String, hint: String, value: float, countdown: String, show_ring: bool=true) -> void:
		heading.text=title; detail.text=hint; fraction=clampf(value,0,1); counter.text=countdown; ring=show_ring; queue_redraw()
	func _draw() -> void:
		draw_style_box(panel,Rect2(Vector2.ZERO,size))
		draw_arc(Vector2(36,39),24,0,TAU,48,Color("4a514c"),3,true)
		if ring and fraction>0: draw_arc(Vector2(36,39),24,-PI*.5,-PI*.5+TAU*fraction,48,Color("d8b778"),3,true)

class DeviceIcon extends Control:
	var remote := false
	func _init() -> void:
		custom_minimum_size=Vector2(140,76); mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c: Vector2=size*.5
		var r:=Rect2(c-Vector2(24,22),Vector2(48,48))
		draw_rect(Rect2(r.position+Vector2(4,4),r.size),Color(0,0,0,.25))
		draw_rect(r,Color("343d38") if not remote else Color("283037")); draw_rect(r,Color("bba783"),false,2)
		if remote:
			draw_line(c+Vector2(15,-22),c+Vector2(15,-35),Color("a6b1b2"),3,true)
			draw_circle(c+Vector2(0,9),9,Color("9a4941")); draw_rect(Rect2(c+Vector2(-16,-13),Vector2(26,12)),Color("647e72"))
		else:
			draw_line(c+Vector2(-17,-15),c+Vector2(-17,20),Color("bbaa77"),6)
			draw_line(c+Vector2(17,-15),c+Vector2(17,20),Color("bbaa77"),6)
			draw_circle(c+Vector2(0,-5),4,Color("e35d43"))

class AimMark extends Control:
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(Vector2.ZERO,2,Color("eee5cd"))
		for offset: Vector2 in [Vector2(-9,0),Vector2(9,0),Vector2(0,-9),Vector2(0,9)]:
			draw_line(offset*.75,offset,Color("bda778"),1,true)

var _world: WeakRef
var _weapons: Node
var _player: CharacterBody3D
var _ui: Control
var _actor_id: Variant
var _life: Variant
var _explosion: Callable
var _mode := "off" # off, place, remote
var _configured := false
var _disposed := false
var _button: Button
var _remote_button: Button
var _connections: Array[Dictionary] = []
var _layer: CanvasLayer
var _card: ProgressCard
var _aim_mark: AimMark
var _rig: Skeleton3D
var _socket := -1
var _held_root: Node3D
var _charge_tool: Node3D
var _remote_tool: Node3D
var _charges: Dictionary = {}
var _hold: Dictionary = {}
var _elapsed := 0.0
var _sequence := 0
var _dispatch: Dictionary = {}
var _dispatch_consumed := false
var _notice_until := 0
var _notice_title := ""
var _notice_detail := ""
var _notice_point := Vector3.ZERO
var _notice_complete := false
var _last_size := Vector2.ZERO
var _totals := {"placed":0,"detonated":0,"disarmed":0,"cancelled":0,"rejected":0}

func configure(world: Node3D, explosion_callback: Callable) -> Dictionary:
	if _configured or _disposed or not Thread.is_main_thread() or not is_instance_valid(world) or not world.is_inside_tree() or not explosion_callback.is_valid(): return {"ok":false,"reason":"binding"}
	var weapons: Variant=world.get("preview_weapons")
	if not weapons is Node or not weapons._owner_current() or not weapons.get("_walk_ui") is Control or not weapons.get("player") is CharacterBody3D: return {"ok":false,"reason":"native_arsenal_not_ready"}
	var ui: Control=weapons.get("_walk_ui")
	if not ui.get("grid") is GridContainer or not ui.get("choices") is Dictionary or not ui.choices.has("none"): return {"ok":false,"reason":"actual_Q_grid_required"}
	var actor: CharacterBody3D=weapons.get("player")
	var rig: Variant=actor.get("_pose_skeleton")
	if not rig is Skeleton3D or rig.find_bone("socket_weapon")<0 or not actor.has_meta("actor_id") or not actor.has_meta("life_generation"): return {"ok":false,"reason":"current_actor_socket"}
	if get_parent()!=null and get_parent()!=world: return {"ok":false,"reason":"module_parent"}
	_world=weakref(world); _weapons=weapons; _player=actor; _ui=ui; _rig=rig; _socket=rig.find_bone("socket_weapon")
	_actor_id=actor.get_meta("actor_id"); _life=actor.get_meta("life_generation"); _explosion=explosion_callback
	name="LocalC4Equipment"
	if get_parent()==null: world.add_child(self)
	_button=_add_choice("C4 · Установить","ЛКМ удерживать 3 секунды",false,Callable(self,"select_placement"))
	_remote_button=_add_choice("Пульт C4","Установленных зарядов: 0",true,Callable(self,"select_remote"))
	# Existing callbacks stay first: native equip owns all inventory/state changes.
	for key: String in ui.choices:
		var button: Button=ui.choices[key].button
		var callback: Callable=Callable(self,"_ordinary_selected").bind(key)
		button.pressed.connect(callback); _connections.append({"button":button,"callback":callback})
	_layer=CanvasLayer.new(); _layer.layer=20; add_child(_layer)
	_card=ProgressCard.new(); _card.visible=false; _layer.add_child(_card)
	_aim_mark=AimMark.new(); _aim_mark.visible=false; _layer.add_child(_aim_mark)
	_held_root=Node3D.new(); _held_root.name="C4_EquipmentSocketVisual"; _rig.add_child(_held_root)
	_charge_tool=_device(false); _remote_tool=_device(true); _held_root.add_child(_charge_tool); _held_root.add_child(_remote_tool); _held_root.visible=false
	_configured=true; process_priority=100; process_physics_priority=100
	return {"ok":true,"scope":"local_session_virtual_c4","hold_seconds":HOLD_SECONDS,"maximum_placed":MAX_CHARGES,"damage":DAMAGE,"radius":BLAST_RADIUS_M,"native_weapon_scripts_modified":false}

func _add_choice(title: String, detail: String, remote: bool, callback: Callable) -> Button:
	var button:=Button.new(); button.custom_minimum_size=Vector2(190,139); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal",WeaponUI.panel_style("252e35","4f595f",5)); button.add_theme_stylebox_override("hover",WeaponUI.panel_style("30393e","b09a74",5)); button.add_theme_stylebox_override("focus",WeaponUI.panel_style("30393e","b09a74",5))
	var margin: MarginContainer=WeaponUI.margins(10); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); button.add_child(margin)
	var column:=VBoxContainer.new(); column.mouse_filter=Control.MOUSE_FILTER_IGNORE; margin.add_child(column)
	var icon:=DeviceIcon.new(); icon.remote=remote; column.add_child(icon)
	column.add_child(WeaponUI.label(title,12)); var description: Label=WeaponUI.label(detail,10,"9daab1"); column.add_child(description); button.set_meta("description",description)
	button.pressed.connect(callback); _ui.grid.add_child(button)
	return button

func _current() -> bool:
	var world: Variant=_world.get_ref() if _world!=null else null
	return _configured and not _disposed and is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and get_parent()==world and world.get("preview_weapons")==_weapons and is_instance_valid(_weapons) and _weapons._owner_current() and _weapons.player==_player and _player.get_meta("actor_id",null)==_actor_id and _player.get_meta("life_generation",null)==_life and is_instance_valid(_rig) and _player.get("_pose_skeleton")==_rig

func _allowed() -> bool:
	return _current() and _weapons._interaction_allowed() and _player._ground_pressure_controls_allowed() and _player.is_on_floor()

func _choose(mode: String) -> Dictionary:
	if not _current() or not _weapons._interaction_allowed(): return {"ok":false,"reason":"inactive"}
	if mode=="remote" and _charges.is_empty(): return {"ok":false,"reason":"no_placed_charges"}
	# This settles pending shots and unequips both real weapon model and item.
	var result: Dictionary=_weapons.equip("none")
	if not result.get("ok",false) or _weapons.fire_state.get("weaponId")!="none": return {"ok":false,"reason":"native_unequip_failed"}
	_cancel_hold(false); _mode=mode; _weapons.cancel_inputs()
	if is_instance_valid(_player._melee_practice): _player._melee_practice.cancel("c4_equipped")
	_update_hud()
	return {"ok":true,"mode":_mode,"placed":_charges.size()}

func select_placement() -> Dictionary:
	return _choose("place")

func select_remote() -> Dictionary:
	return _choose("remote")

func _ordinary_selected(_id: String) -> void:
	_leave_mode()

func _leave_mode() -> void:
	_cancel_hold(false); _mode="off"
	if is_instance_valid(_held_root): _held_root.visible=false
	if is_instance_valid(_card): _card.visible=false
	if is_instance_valid(_aim_mark): _aim_mark.visible=false
	if is_instance_valid(_ui):
		_ui.set("_hud_signature",""); _ui.set("_previous_id",""); _ui.refresh()

func _input(event: InputEvent) -> void:
	if not _current() or _mode=="off": return
	if _weapons.fire_state.get("weaponId")!="none": _leave_mode(); return
	# Q and GUI retain native ownership; E/R and other keys are never intercepted.
	if not event is InputEventMouseButton or event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] or _weapons.controls_blocked() or not _player._free_mouse_look or _player._text_control_focused(): return
	get_viewport().set_input_as_handled() # Blocks native firearm and unarmed melee.
	if not _allowed(): _cancel_hold(true); return
	if event.button_index==MOUSE_BUTTON_RIGHT:
		if event.pressed: _cancel_hold(true)
		return
	if not event.pressed:
		_cancel_hold(true); return
	if _mode=="remote": _detonate_all()
	else: _begin_hold()

func _owner_of_wall(body: Variant) -> Node3D:
	if not body is RigidBody3D or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or not body.freeze or body.get_meta("detached",false) or body.get_meta("fracture_active",false) or (body.collision_layer&1)==0: return null
	var owner: Node=body.get_parent()
	while owner!=null and owner!=_world.get_ref():
		if owner is Node3D and owner.has_method("owns_collider") and owner.get("wall_panels") is Array and owner.get("wall_panels").has(body) and owner.owns_collider(body) and owner.get("site_ready")==true and not owner.get("rebuilding") and not owner.get("collapsing"): return owner
		owner=owner.get_parent()
	return null

func _target() -> Dictionary:
	if not _allowed(): return {}
	var camera: Camera3D=_player.get_preview_camera()
	if not is_instance_valid(camera): return {}
	var from: Vector3=camera.global_position; var direction: Vector3=-camera.global_basis.z.normalized()
	var query:=PhysicsRayQueryParameters3D.create(from,from+direction*30.0,1|512,[_player.get_rid()])
	query.hit_from_inside=true
	var hit: Dictionary=_player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.get("position") is Vector3 or not hit.get("normal") is Vector3: return {}
	var body: Variant=hit.get("collider"); var owner: Node3D=_owner_of_wall(body)
	if owner==null: return {}
	var point: Vector3=hit.position; var normal: Vector3=hit.normal
	if not point.is_finite() or not normal.is_finite() or normal.length_squared()<.9 or absf(normal.normalized().y)>.25: return {}
	var reach: Vector3=_player.global_position+Vector3.UP*1.25
	if reach.distance_to(point)>REACH_M: return {}
	var near_query:=PhysicsRayQueryParameters3D.create(reach,point+normal.normalized()*.005,1|512,[_player.get_rid()]); near_query.hit_from_inside=true
	var obstruction: Dictionary=_player.get_world_3d().direct_space_state.intersect_ray(near_query)
	if not obstruction.is_empty() and obstruction.get("collider")!=body: return {}
	return {"body":body,"owner":owner,"point":point,"normal":normal.normalized(),"local_point":body.to_local(point),"frame":body.global_transform,"owner_generation":owner.get("rebuild_generation"),"source_id":str(owner.get("source_id"))}

func _begin_hold() -> void:
	if _charges.size()>=MAX_CHARGES:
		_notice("Установлено 8 зарядов","Q → Пульт C4 для подрыва",Vector3.ZERO); return
	var target:=_target()
	if target.is_empty(): _notice("Нужна стена поближе","Подойдите на 2,5 м и наведите",Vector3.ZERO); return
	if Vector2(_player.velocity.x,_player.velocity.z).length()>.08: return
	_hold=target; _hold.actor_position=_player.global_position; _elapsed=0
	_notice_until=0

func _cancel_hold(show_notice: bool) -> void:
	if _hold.is_empty(): return
	if show_notice:
		_totals.cancelled+=1; _notice("Установка отменена","Удерживайте ЛКМ неподвижно",_hold.point)
	_hold={}; _elapsed=0

func _physics_process(delta: float) -> void:
	if not _configured or _disposed: return
	if not _current(): dispose(); return
	_maintain_charges()
	if _mode!="off" and _weapons.fire_state.get("weaponId")!="none": _leave_mode()
	if _hold.is_empty(): return
	if not _allowed() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not is_finite(delta) or delta<=0 or delta>.25:
		_cancel_hold(true); return
	var current:=_target()
	if current.is_empty() or current.body!=_hold.body or current.owner!=_hold.owner or current.owner_generation!=_hold.owner_generation or current.frame!=_hold.frame or current.point.distance_to(_hold.point)>AIM_DRIFT_M or current.normal.dot(_hold.normal)<.999 or _player.global_position.distance_to(_hold.actor_position)>ACTOR_DRIFT_M or Vector2(_player.velocity.x,_player.velocity.z).length()>.08:
		_cancel_hold(true); return
	_elapsed+=delta
	if _elapsed>=HOLD_SECONDS: _place_charge()

func _place_charge() -> void:
	if _hold.is_empty() or _charges.size()>=MAX_CHARGES or not _allowed(): _cancel_hold(true); return
	var body: RigidBody3D=_hold.body; var owner: Node3D=_hold.owner
	if _owner_of_wall(body)!=owner: _cancel_hold(true); return
	_sequence+=1
	var id: String="c4:%d:%d"%[get_instance_id(),_sequence]
	var node: Node3D=_device(false); node.name="Placed_C4_%d"%_sequence
	var z: Vector3=_hold.normal; var x: Vector3=Vector3.UP.cross(z).normalized(); var y: Vector3=z.cross(x).normalized()
	var frame:=Transform3D(Basis(x,y,z),_hold.point+z*.045)
	body.add_child(node); node.global_transform=frame
	_charges[id]={"id":id,"item_uid":id+":virtual-item","node":weakref(node),"body":weakref(body),"owner":weakref(owner),"owner_generation":_hold.owner_generation,"source_id":_hold.source_id,"local_frame":node.transform,"local_normal":body.global_basis.transposed()*z,"placed_at_msec":Time.get_ticks_msec(),"actor_id":_actor_id,"life_generation":_life}
	_totals.placed+=1
	var at: Vector3=node.global_position
	_hold={}; _elapsed=0; _mode="remote"
	_notice("Заряд установлен","ЛКМ — подорвать · Q — ещё C4",at,true)
	_update_hud()

func _charge_current(row: Dictionary) -> bool:
	var node: Variant=row.node.get_ref(); var body: Variant=row.body.get_ref(); var owner: Variant=row.owner.get_ref()
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion() and is_instance_valid(body) and _owner_of_wall(body)==owner and is_instance_valid(owner) and owner.get("rebuild_generation")==row.owner_generation and owner.get("source_id")==row.source_id and node.get_parent()==body and node.transform==row.local_frame and node.global_transform.is_finite() and row.actor_id==_actor_id and row.life_generation==_life

func _maintain_charges() -> void:
	for id: String in _charges.keys():
		var row: Dictionary=_charges[id]
		if not _charge_current(row): _remove_charge(id,false)

func _remove_charge(id: String, detonated: bool) -> void:
	if not _charges.has(id): return
	var row: Dictionary=_charges[id]; var node: Variant=row.node.get_ref()
	if is_instance_valid(node): node.visible=false; node.queue_free()
	_charges.erase(id)
	if detonated: _totals.detonated+=1
	else: _totals.disarmed+=1

func _detonate_all() -> void:
	if not _allowed() or _mode!="remote" or not _dispatch.is_empty(): return
	_maintain_charges()
	var count:=0
	for id: String in _charges.keys():
		if not _charges.has(id): continue
		var row: Dictionary=_charges[id]
		if not _charge_current(row): _remove_charge(id,false); continue
		var node: Node3D=row.node.get_ref(); var body: RigidBody3D=row.body.get_ref()
		_dispatch={"scope":"new_local_session_c4","authority":"local_c4_equipment","server_authority":false,"equipment_owner":self,"equipment_instance_id":get_instance_id(),"event_id":row.id+":detonate","placement_id":row.id,"item_uid":row.item_uid,"actor_id":_actor_id,"life_generation":_life,"world_instance_id":_world.get_ref().get_instance_id(),"collider":body,"source_id":row.source_id,"generation":row.owner_generation,"position":node.global_position,"normal":(body.global_basis*row.local_normal).normalized(),"damage":DAMAGE,"power":DAMAGE,"radius":BLAST_RADIUS_M,"weapon_id":"c4","explosive":true,"placed_at_msec":row.placed_at_msec}
		_dispatch_consumed=false
		_explosion.call(_dispatch)
		if _dispatch_consumed: count+=1
		else: _totals.rejected+=1
		_dispatch={}; _dispatch_consumed=false
		if not _current(): return
	_notice("Подрыв: %d"%count,"Q → C4, чтобы установить ещё",Vector3.ZERO)
	_update_hud()

## Synchronous single-use capability: only the EXACT dictionary currently being
## delivered to the configured callback may be consumed. A copied/fake/replayed
## receipt cannot consume a new item. Capture then remove before root mutation.
func consume_detonation(event: Dictionary) -> Dictionary:
	if not _allowed() or _mode!="remote" or _dispatch.is_empty() or not is_same(event,_dispatch) or _dispatch_consumed: return {"ok":false,"reason":"not_current_equipment_dispatch"}
	var id: String=str(event.get("placement_id",""))
	if not _charges.has(id): return {"ok":false,"reason":"unknown_or_consumed_charge"}
	var row: Dictionary=_charges[id]
	if not _charge_current(row): return {"ok":false,"reason":"charge_owner_ended"}
	var node: Node3D=row.node.get_ref(); var body: RigidBody3D=row.body.get_ref()
	if event.get("equipment_owner")!=self or event.get("equipment_instance_id")!=get_instance_id() or event.get("event_id")!=id+":detonate" or event.get("item_uid")!=row.item_uid or event.get("actor_id")!=_actor_id or event.get("life_generation")!=_life or event.get("world_instance_id")!=_world.get_ref().get_instance_id() or event.get("position")!=node.global_position or event.get("collider")!=body or event.get("source_id")!=row.source_id or event.get("generation")!=row.owner_generation or event.get("normal")!=(body.global_basis*row.local_normal).normalized() or event.get("damage")!=DAMAGE or event.get("power")!=DAMAGE or event.get("radius")!=BLAST_RADIUS_M or event.get("weapon_id")!="c4" or event.get("explosive")!=true or event.get("authority")!="local_c4_equipment" or event.get("scope")!="new_local_session_c4" or event.get("server_authority")!=false or event.get("placed_at_msec")!=row.placed_at_msec: return {"ok":false,"reason":"changed_c4_dispatch"}
	var receipt: Dictionary=event.duplicate(); receipt.erase("equipment_owner"); receipt.admitted=true; receipt.consumed=true
	_dispatch_consumed=true; _remove_charge(id,true)
	return {"ok":true,"receipt":receipt}

func _notice(title: String, detail: String, at: Vector3, complete: bool=false) -> void:
	_notice_title=title; _notice_detail=detail; _notice_point=at; _notice_complete=complete; _notice_until=Time.get_ticks_msec()+2200

func _update_hud() -> void:
	if not _current(): return
	var count: int=_charges.size()
	_remote_button.disabled=count==0
	_remote_button.get_meta("description").text="Зарядов: %d · ЛКМ — подрыв"%count
	_button.get_meta("description").text="ЛКМ 3 с · %d / %d установлено"%[count,MAX_CHARGES]
	if _mode!="off" and _weapons.fire_state.get("weaponId")=="none":
		_ui.title.text="C4 · Установка" if _mode=="place" else "Пульт C4"
		_ui.ammo.text="ЛКМ 3 с у стены · Q — арсенал" if _mode=="place" else "ЛКМ — подорвать · Зарядов: %d"%count
		_ui.ammo.add_theme_color_override("font_color",Color("cbb98f"))
		_ui.photo.texture=null

func _process(_delta: float) -> void:
	if not _current(): return
	_update_hud()
	var size: Vector2=get_viewport().get_visible_rect().size
	if size!=_last_size:
		_last_size=size
		var base: Button=_ui.choices.none.button
		_button.custom_minimum_size=base.custom_minimum_size; _remote_button.custom_minimum_size=base.custom_minimum_size
	var show: bool=_mode!="off" and _allowed() and _weapons.fire_state.get("weaponId")=="none"
	_aim_mark.visible=show and _mode=="place"; _aim_mark.position=size*.5
	_held_root.visible=show; _charge_tool.visible=_mode=="place"; _remote_tool.visible=_mode=="remote"
	if show:
		var socket: Transform3D=_rig.global_transform*_rig.get_bone_global_pose(_socket)
		_held_root.global_transform=Transform3D(socket.basis.orthonormalized(),socket.origin)
	_card.visible=false
	if not show: return
	var anchor: Vector3=Vector3.ZERO
	if not _hold.is_empty():
		anchor=_hold.point
		var remaining: String=("%.1f с"%maxf(0,HOLD_SECONDS-_elapsed)).replace(".",",")
		_card.present("Установка C4","Держите ЛКМ · не двигайтесь",_elapsed/HOLD_SECONDS,remaining)
	elif Time.get_ticks_msec()<_notice_until:
		anchor=_notice_point; _card.present(_notice_title,_notice_detail,1.0,"0,0 с" if _notice_complete else "C4",_notice_complete)
	else: return
	var position: Vector2=Vector2(size.x*.5-_card.size.x*.5,size.y*.62)
	if anchor!=Vector3.ZERO:
		var camera: Camera3D=_player.get_preview_camera()
		if camera.is_position_behind(anchor): return
		position=camera.unproject_position(anchor+Vector3.UP*.15)+Vector2(32,-88)
	_card.position=Vector2(clampf(position.x,12,maxf(12,size.x-_card.size.x-12)),clampf(position.y,12,maxf(12,size.y-_card.size.y-12)))
	_card.visible=true

func _device(remote: bool) -> Node3D:
	var root:=Node3D.new()
	var body:=StandardMaterial3D.new(); body.albedo_color=Color("303a35") if not remote else Color("263039"); body.roughness=.55
	var trim:=StandardMaterial3D.new(); trim.albedo_color=Color("b9aa7b"); trim.roughness=.6
	var led:=StandardMaterial3D.new(); led.albedo_color=Color("ef5b43"); led.emission_enabled=true; led.emission=Color("dd4428"); led.emission_energy_multiplier=1.1
	_box(root,Vector3(.12,.19,.07) if remote else Vector3(.23,.17,.08),Vector3.ZERO,body)
	if remote:
		_box(root,Vector3(.018,.12,.018),Vector3(.04,.145,0),body)
		_box(root,Vector3(.075,.038,.006),Vector3(0,.035,.039),trim)
		_box(root,Vector3(.035,.035,.008),Vector3(0,-.035,.041),led)
	else:
		for x: float in [-.075,.075]: _box(root,Vector3(.023,.176,.084),Vector3(x,0,0),trim)
		_box(root,Vector3(.018,.018,.006),Vector3(0,.025,.044),led)
	root.set_meta("virtual_equipment_visual",true)
	return root

func _box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material) -> void:
	var mesh:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=dimensions; mesh.mesh=box; mesh.position=at; mesh.material_override=material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(mesh)

func snapshot() -> Dictionary:
	var placed: Array=[]
	for row: Dictionary in _charges.values():
		var node: Variant=row.node.get_ref()
		placed.append({"id":row.id,"source_id":row.source_id,"valid":_charge_current(row),"world_position":node.global_position if is_instance_valid(node) else null})
	return {"ready":_current(),"mode":_mode,"holding":not _hold.is_empty(),"elapsed_seconds":_elapsed,"placed":placed,"totals":_totals.duplicate(),"maximum_placed":MAX_CHARGES,"hold_seconds":HOLD_SECONDS,"damage":DAMAGE,"radius":BLAST_RADIUS_M,"actor_id":_actor_id,"life_generation":_life}

func dispose() -> void:
	if _disposed: return
	_leave_mode(); _disposed=true; set_process(false); set_physics_process(false); set_process_input(false)
	for id: String in _charges.keys(): _remove_charge(id,false)
	for item: Dictionary in _connections:
		if is_instance_valid(item.button) and item.button.pressed.is_connected(item.callback): item.button.pressed.disconnect(item.callback)
	_connections.clear(); _dispatch={}; _explosion=Callable()
	for node: Variant in [_button,_remote_button,_held_root,_layer]:
		if is_instance_valid(node): node.queue_free()
	if is_inside_tree(): queue_free()

func _exit_tree() -> void:
	dispose()
