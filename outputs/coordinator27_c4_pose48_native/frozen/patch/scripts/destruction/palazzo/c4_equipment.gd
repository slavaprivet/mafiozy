extends Node
## Virtual local-session equipment. Existing weapon scripts/inventory are unchanged.
## The explosion owner must synchronously consume_detonation(event) once before
## applying/queuing damage. These receipts are NOT native RPG or bullet receipts.
const WeaponUI = preload("res://scripts/weapons/walk_weapon_ui.gd")
const C4Pose44 = preload("c4_pose44.gd")
const Visuals45 = preload("c4_visuals.gd") # Model/cache only; no pose instance.
const PlacementQuery45 = preload("c4_placement_query45.gd")
const SurfaceOwner45 = preload("c4_surface_owner45.gd")
const IconCache43 = preload("c4_icon_cache43.gd")
const DeviceIcon = preload("c4_device_icon43.gd")
const HOLD_SECONDS := 3.0
const REACH_M := 2.5
const MAX_CHARGES := 8
const DAMAGE := 1920.0
const BLAST_RADIUS_M := 3.2
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

class AimMark extends Control:
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(Vector2.ZERO,2,Color("eee5cd"))
		for offset: Vector2 in [Vector2(-9,0),Vector2(9,0),Vector2(0,-9),Vector2(0,9)]:
			draw_line(offset*.75,offset,Color("bda778"),1,true)

var _target_query45 := PlacementQuery45.new()
var _require_release := false
var _owner_killed := false
var _damage_revision := 0
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
var _presentation: RefCounted
var _last_placement_pose44: Dictionary={}
var _last_pose44_rejection := ""
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
	# Both actual-model PNGs must be baked/imported before promoting this overlay.
	if IconCache43.texture_for(false)==null or IconCache43.texture_for(true)==null: return {"ok":false,"reason":"c4_model_icons_not_baked"}
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
	_presentation=C4Pose44.new()
	var binding: Dictionary=_presentation.configure(actor)
	if not binding.get("ok",false):
		dispose(); return {"ok":false,"reason":"planting_pose_binding","detail":binding}
	_presentation.pose_applied.connect(_planting_pose_applied)
	_configured=true; process_priority=100; process_physics_priority=100
	return {"ok":true,"scope":"local_session_virtual_c4","hold_seconds":HOLD_SECONDS,"maximum_placed":MAX_CHARGES,"damage":DAMAGE,"radius":BLAST_RADIUS_M,"native_weapon_scripts_modified":false}

func _add_choice(title: String, detail: String, remote: bool, callback: Callable) -> Button:
	var button:=Button.new(); button.custom_minimum_size=Vector2(190,139); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal",WeaponUI.panel_style("252e35","4f595f",5)); button.add_theme_stylebox_override("hover",WeaponUI.panel_style("30393e","b09a74",5)); button.add_theme_stylebox_override("focus",WeaponUI.panel_style("30393e","b09a74",5))
	var margin: MarginContainer=WeaponUI.margins(10); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); button.add_child(margin)
	var column:=VBoxContainer.new(); column.mouse_filter=Control.MOUSE_FILTER_IGNORE; margin.add_child(column)
	var icon:=DeviceIcon.new(); icon.bind(remote); column.add_child(icon)
	column.add_child(WeaponUI.label(title,12)); var description: Label=WeaponUI.label(detail,10,"9daab1"); column.add_child(description); button.set_meta("description",description)
	button.pressed.connect(callback); _ui.grid.add_child(button)
	return button

func _current() -> bool:
	var world: Variant=_world.get_ref() if _world!=null else null
	return _configured and not _disposed and is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and get_parent()==world and world.get("preview_weapons")==_weapons and is_instance_valid(_weapons) and _weapons._owner_current() and _weapons.player==_player and _player.get_meta("actor_id",null)==_actor_id and _player.get_meta("life_generation",null)==_life and is_instance_valid(_rig) and _player.get("_pose_skeleton")==_rig

func _allowed() -> bool:
	return _current() and not _owner_killed and not _world.get_ref().get("preview_dead") and _weapons._interaction_allowed() and _player._ground_pressure_controls_allowed() and _player.is_on_floor()

## Cancellation port only. Root must call after REAL committed damage/death.
## Accepted43 has no native incoming HP producer; no combat-ready claim.
func interrupt_for_damage(actor_id: Variant, life_generation: Variant, damage_amount: float, killed: bool=false) -> Dictionary:
	if not _current() or actor_id!=_actor_id or life_generation!=_life: return {"ok":false,"reason":"foreign_or_retired_actor"}
	if not is_finite(damage_amount) or damage_amount<0 or (damage_amount<=0 and not killed): return {"ok":false,"reason":"no_committed_damage"}
	_damage_revision+=1; _require_release=true
	var was_holding: bool=not _hold.is_empty()
	var point: Vector3=_hold.get("point",Vector3.ZERO)
	_cancel_hold(false)
	if was_holding:
		_totals.cancelled+=1
		_notice("Установка прервана","Получен урон · начните заново",point)
	if killed:
		_owner_killed=true; _leave_mode()
	return {"ok":true,"interrupted":was_holding,"killed":_owner_killed,"damage_revision":_damage_revision,"charge_created":false}

func _planting_pose_applied(frame: Transform3D) -> void:
	if _current() and not _hold.is_empty() and _allowed() and frame.is_finite() and is_instance_valid(_held_root):
		_held_root.global_transform=frame

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
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: _require_release=false
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
	# Historical diagnostic name, now a generic physical scenery owner query.
	return SurfaceOwner45.resolve(body,_world.get_ref(),_player)

func _target() -> Dictionary:
	if not _allowed(): return _target_query45.reject("inactive")
	var camera: Camera3D=_player.get_preview_camera()
	if not is_instance_valid(camera): return _target_query45.reject("camera_missing")
	var excluded: Array[RID]=[_player.get_rid()]
	var target: Dictionary=_target_query45.query(_player.get_world_3d().direct_space_state,camera.global_position,-camera.global_basis.z.normalized(),_player.global_position+Vector3.UP,excluded,Callable(self,"_owner_of_wall"))
	if target.is_empty(): return {}
	var body: PhysicsBody3D=target.body
	var owner: Node3D=target.owner
	if not SurfaceOwner45.contact_current(body,target.point,_world.get_ref()): return _target_query45.reject("unsupported_surface")
	target.local_point=body.to_local(target.point); target.frame=body.global_transform
	target.owner_generation=SurfaceOwner45.generation(owner,_world.get_ref())
	target.source_id=SurfaceOwner45.source_id(body,owner,_world.get_ref())
	target.body_life_generation=(body.get_meta("life_generation") if body.has_meta("life_generation") else null)
	target.shape_binding=SurfaceOwner45.capture_shape(body,int(target.get("shape_index",-1)))
	if target.shape_binding.is_empty(): return _target_query45.reject("unsupported_surface")
	return target

func _target_failure_notice() -> void:
	var reason: String=str(_target_query45.snapshot().last.reason)
	match reason:
		"too_far": _notice("Поверхность далеко","Подойдите ближе к выбранной точке",Vector3.ZERO)
		"unsupported_surface": _notice("Здесь заряд не закрепить","Наведите на землю, здание или предмет",Vector3.ZERO)
		"actor_los_blocked", "actor_los_empty", "different_surface_contact": _notice("Поверхность перекрыта","Выберите свободный участок перед собой",Vector3.ZERO)
		"camera_inside_surface", "actor_inside_surface": _notice("Точка скрыта внутри объекта","Отойдите немного и наведите на внешнюю сторону",Vector3.ZERO)
		_: _notice("Наведите на поверхность","Нужна близкая физическая поверхность",Vector3.ZERO)

func _begin_hold() -> void:
	if _require_release or not _allowed() or not _hold.is_empty(): return
	if _charges.size()>=MAX_CHARGES:
		_notice("Установлено 8 зарядов","Q → Пульт C4 для подрыва",Vector3.ZERO); return
	var target:=_target()
	if target.is_empty(): _target_failure_notice(); return
	if Vector2(_player.velocity.x,_player.velocity.z).length()>.08: return
	var admitted: Dictionary=_presentation.begin_hold()
	if not admitted.get("ok",false):
		_last_pose44_rejection=str(admitted.get("reason","pose_unavailable")); return
	_hold=target; _hold.pose_serial=admitted.request_serial; _hold.actor_position=_player.global_position; _hold.damage_revision=_damage_revision; _elapsed=0
	var shape: Shape3D=_hold.shape_binding.shape.get_ref()
	shape.changed.connect(_hold_shape_changed)
	_notice_until=0

func _hold_shape_changed() -> void:
	_require_release=true
	_cancel_hold(true)

func _cancel_hold(show_notice: bool) -> void:
	if _presentation!=null: _presentation.cancel()
	if _hold.is_empty(): return
	var shape: Variant=_hold.shape_binding.shape.get_ref()
	if is_instance_valid(shape) and shape.changed.is_connected(_hold_shape_changed): shape.changed.disconnect(_hold_shape_changed)
	if show_notice:
		_totals.cancelled+=1; _notice("Установка отменена","Удерживайте ЛКМ неподвижно",_hold.point)
	_hold={}; _elapsed=0

func _physics_process(delta: float) -> void:
	if not _configured or _disposed: return
	if not _current(): dispose(); return
	_maintain_charges()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _require_release=false
	if _mode!="off" and _weapons.fire_state.get("weaponId")!="none": _leave_mode()
	if _hold.is_empty(): return
	if not _allowed() or _hold.damage_revision!=_damage_revision or _require_release or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not is_finite(delta) or delta<=0 or delta>.25:
		_cancel_hold(true); return
	var current:=_target()
	if current.is_empty() or current.body!=_hold.body or current.owner!=_hold.owner or current.owner_generation!=_hold.owner_generation or current.body_life_generation!=_hold.body_life_generation or not SurfaceOwner45.shape_current(current.body,_hold.shape_binding) or current.local_point.distance_to(_hold.local_point)>AIM_DRIFT_M or current.normal.dot(_hold.normal)<.999 or _player.global_position.distance_to(_hold.actor_position)>ACTOR_DRIFT_M or Vector2(_player.velocity.x,_player.velocity.z).length()>.08:
		_cancel_hold(true); return
	_hold.point=current.point; _hold.normal=current.normal; _hold.frame=current.frame
	# Consume the preceding final request after the real player writer, before replacing it.
	if _hold.has("completion_frame") and Engine.get_physics_frames()>int(_hold.completion_frame):
		_place_charge(); return
	_elapsed+=delta
	var prepared: Dictionary=_presentation.prepare_hold(delta,minf(1,_elapsed/HOLD_SECONDS),_hold)
	if not prepared.get("ok",false): _reject_pose44(str(prepared.get("reason","pose_unavailable"))); return
	if _elapsed>=HOLD_SECONDS: _hold.completion_frame=Engine.get_physics_frames()

func _reject_pose44(reason: String) -> void:
	_last_pose44_rejection=reason; _require_release=true
	_cancel_hold(true)

func _place_charge() -> void:
	if _hold.is_empty() or _charges.size()>=MAX_CHARGES or not _allowed() or _require_release or _hold.damage_revision!=_damage_revision or not is_instance_valid(_hold.get("body")) or not is_instance_valid(_hold.get("owner")): _cancel_hold(true); return
	var body: PhysicsBody3D=_hold.body; var owner: Node3D=_hold.owner
	if _owner_of_wall(body)!=owner: _cancel_hold(true); return
	# No direct call can bypass current geometry, original hold time or lifetime.
	var current: Dictionary=_target()
	if _elapsed<HOLD_SECONDS or Engine.get_physics_frames()<=int(_hold.get("completion_frame",Engine.get_physics_frames())) or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or current.is_empty() or current.body!=body or current.owner!=owner or current.owner_generation!=_hold.owner_generation or current.body_life_generation!=_hold.body_life_generation or not SurfaceOwner45.shape_current(body,_hold.shape_binding) or current.source_id!=_hold.source_id or current.local_point.distance_to(_hold.local_point)>AIM_DRIFT_M or current.normal.dot(_hold.normal)<.999 or _player.global_position.distance_to(_hold.actor_position)>ACTOR_DRIFT_M or Vector2(_player.velocity.x,_player.velocity.z).length()>.08: _cancel_hold(true); return
	_hold.point=current.point; _hold.normal=current.normal
	var completed: Dictionary=_presentation.consume_completion(_hold)
	if not completed.get("ok",false): _reject_pose44(str(completed.get("reason","post_writer_receipt_missing"))); return
	_last_placement_pose44=completed.duplicate(); _last_pose44_rejection=""
	_sequence+=1
	var id: String="c4:%d:%d"%[get_instance_id(),_sequence]
	var node: Node3D=_device(false); node.name="Placed_C4_%d"%_sequence
	var z: Vector3=_hold.normal
	var frame:=Transform3D(Visuals45.surface_basis(z),_hold.point+z*.045)
	body.add_child(node); node.global_transform=frame
	_charges[id]={"id":id,"item_uid":id+":virtual-item","node":weakref(node),"body":weakref(body),"owner":weakref(owner),"owner_generation":_hold.owner_generation,"source_id":_hold.source_id,"body_life_generation":_hold.body_life_generation,"local_frame":node.transform,"local_normal":body.global_basis.transposed()*z,"placed_at_msec":Time.get_ticks_msec(),"actor_id":_actor_id,"life_generation":_life}
	# Resource mutation/removal retires this attachment instead of leaving a
	# floating charge when a pane or prop shape is replaced/disabled in place.
	var shape: Shape3D=current.shape_binding.shape.get_ref()
	_charges[id].shape_binding=current.shape_binding
	_watch_charge_shape(id,shape)
	_totals.placed+=1
	var at: Vector3=node.global_position
	_cancel_hold(false); _mode="remote"
	_notice("Заряд установлен","ЛКМ — подорвать · Q — ещё C4",at,true)
	_update_hud()

func _charge_current(row: Dictionary) -> bool:
	var node: Variant=row.node.get_ref(); var body: Variant=row.body.get_ref(); var owner: Variant=row.owner.get_ref()
	if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion() or not is_instance_valid(body) or not is_instance_valid(owner) or _owner_of_wall(body)!=owner: return false
	if SurfaceOwner45.generation(owner,_world.get_ref())!=row.owner_generation or SurfaceOwner45.source_id(body,owner,_world.get_ref())!=row.source_id or (body.get_meta("life_generation") if body.has_meta("life_generation") else null)!=row.body_life_generation: return false
	if not SurfaceOwner45.shape_current(body,row.shape_binding): return false
	return node.get_parent()==body and node.transform==row.local_frame and node.global_transform.is_finite() and row.actor_id==_actor_id and row.life_generation==_life

func _maintain_charges() -> void:
	for id: String in _charges.keys():
		var row: Dictionary=_charges[id]
		if not _charge_current(row): _remove_charge(id,false)

func _watch_charge_shape(id: String, shape: Shape3D) -> void:
	# Godot signal slots compare the base callable, ignoring bind arguments.
	# One resource owns one handler; each attachment retains one reference.
	var changed: Callable=Callable(self,"_charge_shape_changed").bind(shape.get_instance_id())
	_charges[id].shape_changed=changed
	shape.changed.connect(changed,CONNECT_REFERENCE_COUNTED)

func _charge_shape_changed(shape_id: int) -> void:
	for id: String in _charges.keys():
		var shape: Variant=_charges[id].shape_binding.shape.get_ref()
		if is_instance_valid(shape) and shape.get_instance_id()==shape_id: _remove_charge(id,false)

func _remove_charge(id: String, detonated: bool) -> void:
	if not _charges.has(id): return
	var row: Dictionary=_charges[id]; var node: Variant=row.node.get_ref()
	var shape: Variant=row.shape_binding.shape.get_ref()
	if is_instance_valid(shape) and shape.changed.is_connected(row.shape_changed): shape.changed.disconnect(row.shape_changed)
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
		var node: Node3D=row.node.get_ref(); var body: PhysicsBody3D=row.body.get_ref()
		_dispatch={"scope":"new_local_session_c4","authority":"local_c4_equipment","server_authority":false,"equipment_owner":self,"equipment_instance_id":get_instance_id(),"event_id":row.id+":detonate","placement_id":row.id,"item_uid":row.item_uid,"actor_id":_actor_id,"life_generation":_life,"world_instance_id":_world.get_ref().get_instance_id(),"collider":body,"source_id":row.source_id,"generation":row.owner_generation,"position":node.global_position,"normal":SurfaceOwner45.world_normal(body,row.local_normal),"damage":DAMAGE,"power":DAMAGE,"radius":BLAST_RADIUS_M,"weapon_id":"c4","explosive":true,"placed_at_msec":row.placed_at_msec}
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
	var node: Node3D=row.node.get_ref(); var body: PhysicsBody3D=row.body.get_ref()
	if event.get("equipment_owner")!=self or event.get("equipment_instance_id")!=get_instance_id() or event.get("event_id")!=id+":detonate" or event.get("item_uid")!=row.item_uid or event.get("actor_id")!=_actor_id or event.get("life_generation")!=_life or event.get("world_instance_id")!=_world.get_ref().get_instance_id() or event.get("position")!=node.global_position or event.get("collider")!=body or event.get("source_id")!=row.source_id or event.get("generation")!=row.owner_generation or event.get("normal")!=SurfaceOwner45.world_normal(body,row.local_normal) or event.get("damage")!=DAMAGE or event.get("power")!=DAMAGE or event.get("radius")!=BLAST_RADIUS_M or event.get("weapon_id")!="c4" or event.get("explosive")!=true or event.get("authority")!="local_c4_equipment" or event.get("scope")!="new_local_session_c4" or event.get("server_authority")!=false or event.get("placed_at_msec")!=row.placed_at_msec: return {"ok":false,"reason":"changed_c4_dispatch"}
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
		_ui.ammo.text="ЛКМ 3 с у поверхности · Q — арсенал" if _mode=="place" else "ЛКМ — подорвать · Зарядов: %d"%count
		_ui.ammo.add_theme_color_override("font_color",Color("cbb98f"))
		_ui.photo.texture=IconCache43.texture_for(_mode=="remote")

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
		var pose: Dictionary=_presentation.held_frame() if not _hold.is_empty() else {}
		if pose.get("ok",false): _held_root.global_transform=pose.frame
		else:
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
	return Visuals45.make_device(remote)

func snapshot() -> Dictionary:
	var placed: Array=[]
	for row: Dictionary in _charges.values():
		var node: Variant=row.node.get_ref()
		placed.append({"id":row.id,"source_id":row.source_id,"valid":_charge_current(row),"world_position":node.global_position if is_instance_valid(node) else null})
	return {"ready":_current(),"mode":_mode,"holding":not _hold.is_empty(),"elapsed_seconds":_elapsed,"placed":placed,"totals":_totals.duplicate(),"maximum_placed":MAX_CHARGES,"hold_seconds":HOLD_SECONDS,"damage":DAMAGE,"radius":BLAST_RADIUS_M,"actor_id":_actor_id,"life_generation":_life,"damage_revision":_damage_revision,"requires_release":_require_release,"owner_killed":_owner_killed,"target_query":_target_query45.snapshot(),"icons":IconCache43.snapshot(),"placement_scope":"near_aimed_physical_scenery","hand_contact_animation":"private_native_bone_pose48_not_gpu_accepted","presentation":_presentation.snapshot() if _presentation!=null else {},"last_placement_pose44":_last_placement_pose44.duplicate(),"last_pose44_rejection":_last_pose44_rejection}

func dispose() -> void:
	if _disposed: return
	_leave_mode()
	if _presentation!=null: _presentation.dispose(); _presentation=null
	_disposed=true; set_process(false); set_physics_process(false); set_process_input(false)
	for id: String in _charges.keys(): _remove_charge(id,false)
	for item: Dictionary in _connections:
		if is_instance_valid(item.button) and item.button.pressed.is_connected(item.callback): item.button.pressed.disconnect(item.callback)
	_connections.clear(); _dispatch={}; _explosion=Callable()
	for node: Variant in [_button,_remote_button,_held_root,_layer]:
		if is_instance_valid(node): node.queue_free()
	if is_inside_tree(): queue_free()

func _exit_tree() -> void:
	dispose()
