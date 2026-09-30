extends Node
## Local new-session arsenal. Authenticated ownership and target HP stay separate.
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
const Inventory = preload("res://scripts/weapons/weapon_inventory.gd")
const Presentation = preload("res://scripts/weapons/player_weapon_presentation.gd")
const Projectiles = preload("res://scripts/weapons/weapon_projectiles.gd")
const Posture = preload("res://scripts/weapons/weapon_posture_base.gd")
signal shot_emitted(shot: Dictionary, muzzle: Dictionary, camera_origin: Vector3, camera_direction: Vector3)
const LABELS := {"none":"Без оружия", "nagan":"Наган", "tt_pistol":"ТТ", "revolver":"Револьвер", "deagle":"Desert Eagle", "golden_colt":"Золотой Colt", "sawn_off":"Обрез", "shotgun":"Дробовик", "uzi":"Uzi", "golden_uzi":"Золотой Uzi", "ak74":"АК-74", "m16":"M16", "tommy_gun":"Томпсон", "sniper":"Снайперская винтовка", "rpg":"РПГ"}
var inventory: RefCounted
var presentation: RefCounted
var effects: RefCounted
var posture: RefCounted
var player: CharacterBody3D
var scene: Node3D
var fire_state: Dictionary = {}
var menu_open := false
var ready_for_play := false
var _held := false
var _pressed := false
var _reload := false
var _aiming := false
var _pending_shots: Array = []
var _pending_epoch := -1
var _pending_plan: Dictionary = {}
var _profile: Dictionary = {}
var _aim: Dictionary = {}
var _layer: CanvasLayer
var _hud: Label
var _crosshair: Label
var _menu: PanelContainer
var _buttons: Dictionary = {}
var _hud_value := ""
var shots_count := 0
var last_muzzle: Dictionary = {}
var _last_pose_epoch := -1
var _posture_query := PhysicsShapeQueryParameters3D.new()
var _posture_shape := CapsuleShape3D.new()
var _posture_view: Dictionary = {}
var _pose_delta := 0.0
var _last_foot := Vector3.ZERO
var _shot_ray := PhysicsRayQueryParameters3D.new()
var cosmetic_impacts := 0

func configure(world: Node3D, actor: CharacterBody3D) -> Dictionary:
	if ready_for_play or not is_instance_valid(world) or not is_instance_valid(actor) or not actor.is_inside_tree(): return {"ok":false,"reason":"binding"}
	scene = world; player = actor
	inventory = Inventory.new()
	var configured: Dictionary = inventory.configure(Fire.new())
	if not configured.get("ok", false): return configured
	presentation = Presentation.new()
	configured = presentation.configure(player)
	if not configured.get("ok", false): inventory.dispose(); return configured
	posture=Posture.new()
	if not posture.configure_player(player): presentation.dispose(); inventory.dispose(); return {"ok":false,"reason":"posture_binding"}
	posture.seed_gait(player._locomotion._phase,player._locomotion._gait)
	_posture_query.shape=_posture_shape; _posture_query.collision_mask=player.collision_mask; _posture_query.exclude=[player.get_rid()]; _posture_query.margin=.001
	_posture_view=posture.posture_state(); _last_foot=player.global_position
	effects=Projectiles.new()
	configured=effects.configure(world,Callable(self,"_projectile_ray"),{"ground_height":Callable(self,"_ground_height")})
	if not configured.get("ok",false): posture.dispose(); presentation.dispose(); inventory.dispose(); return configured
	effects.cosmetic_impact.connect(func(_receipt: Dictionary): cosmetic_impacts+=1)
	fire_state = Fire.create_state("none")
	ready_for_play = true
	_build_ui()
	_refresh_ui()
	return {"ok":true,"scope":"local_new_session", "authenticated_ownership":false}

func _owner_current() -> bool:
	return ready_for_play and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion() and is_instance_valid(scene) and scene.is_inside_tree() and not scene.is_queued_for_deletion()

func _interaction_allowed() -> bool:
	return _owner_current() and player._free_mouse_look and player._pose_authority == &"on_foot" and player._jump.is_empty() and not bool(scene.get("preview_dead")) and not bool(scene.get("preview_physics_fault"))

func armed() -> bool:
	return ready_for_play and fire_state.get("weaponId", "none") != "none"

func controls_blocked() -> bool:
	return menu_open

func equip(id: String) -> Dictionary:
	if not _interaction_allowed(): return {"ok":false,"reason":"inactive"}
	if id != "none" and not inventory.get_owned_ids().has(id): return {"ok":false,"reason":"not_owned"}
	cancel_inputs()
	# Prepare the real model before changing item ownership/equipment state.
	var prepared: Dictionary = presentation.equip(id)
	if not prepared.get("ok", false): return prepared
	var result: Dictionary = inventory.equip(id, fire_state)
	if not result.get("ok", false):
		presentation.equip(str(fire_state.weaponId)); return result
	fire_state = result.fireState
	_profile = Fire.profile(id)
	cancel_inputs()
	if is_instance_valid(player._melee_practice): player._melee_practice.cancel("weapon_equipped")
	set_menu(false)
	_refresh_ui()
	return result

func set_menu(open: bool) -> void:
	if open and not _interaction_allowed(): return
	var was_open := menu_open
	menu_open = open
	cancel_inputs()
	if is_instance_valid(_menu): _menu.visible = open
	if _owner_current():
		# A direct equip/cargo transfer does not own pointer capture. Only an
		# actual menu transition changes it; blur remains owned by the player.
		if open or was_open:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open or not player._free_mouse_look else Input.MOUSE_MODE_CAPTURED
		for action: StringName in [player.ACTION_LEFT,player.ACTION_RIGHT,player.ACTION_FORWARD,player.ACTION_BACK,player.ACTION_RUN,player.ACTION_JUMP]:
			if InputMap.has_action(action): Input.action_release(action)
	_refresh_ui()

func cancel_inputs() -> void:
	_settle_pending(false)
	_held = false; _pressed = false; _reload = false; _aiming = false
	_pending_shots.clear()
	if not fire_state.is_empty(): fire_state.triggerHeld = false

func _settle_pending(accepted: bool) -> bool:
	if _pending_plan.is_empty(): return false
	var plan := _pending_plan
	_pending_plan = {}; _pending_shots = []
	if inventory == null or not ready_for_play: return false
	if fire_state.get("weaponId") != plan.weapon_id or inventory.get_item_uid(plan.weapon_id) != plan.uid: return false
	var next_state: Dictionary = plan.proposed if accepted else plan.fallback
	var committed: Dictionary = inventory.update_fire_state(next_state)
	if not committed.get("ok",false): return false
	fire_state = next_state
	return true

func _inventory_state(state: Dictionary) -> Dictionary:
	# Source Fire can return an overdue (negative) cooldown from its reload early
	# return. The next source step starts with max(0,cooldown), so zero preserves
	# all timing/shot behavior while meeting Inventory's persistent-state contract.
	# Ammunition, sequence and all other fields retain their exact source values.
	if float(state.get("cooldown",0)) < 0.0:
		state=state.duplicate()
		state.cooldown=0.0
	return state

func release_controls() -> void:
	cancel_inputs()
	set_menu(false)

func input_event(event: InputEvent) -> bool:
	if not _owner_current() or not player._free_mouse_look: return false
	if event is InputEventKey:
		if event.pressed and not event.echo:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if code == KEY_Q and _interaction_allowed(): set_menu(not menu_open); return true
			if code == KEY_ESCAPE and menu_open:
				set_menu(false); player.set_mouse_captured(false); return true
			if menu_open: return true
			if code in [KEY_C,KEY_Z] and _interaction_allowed():
				var requested: String="crouch" if code==KEY_C else "prone"
				posture.request_posture("stand" if posture.posture_state().target==requested else requested,Callable(self,"_can_occupy_posture"))
				return true
			if code == KEY_R and armed() and _interaction_allowed(): _reload = true; return true
		return menu_open
	if event is InputEventMouseButton and not menu_open and armed() and _interaction_allowed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _held: _pressed = true
			_held = event.pressed
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_aiming = event.pressed; return true
	return menu_open and event is InputEventMouseMotion

func _input(event: InputEvent) -> void:
	# The visible arsenal owns keys before vehicle/building unhandled shortcuts.
	# GUI mouse clicks still reach the actual weapon buttons.
	if menu_open and event is InputEventKey and input_event(event):
		get_viewport().set_input_as_handled()

func advance(delta: float) -> void:
	if not _owner_current(): return
	_settle_pending(false)
	effects.advance(delta)
	_pose_delta=delta
	if _last_pose_epoch != player._pose_epoch:
		_last_pose_epoch = player._pose_epoch
		cancel_inputs()
		if armed() and player._pose_authority == &"on_foot": presentation.equip(str(fire_state.weaponId))
	if not _interaction_allowed():
		cancel_inputs()
		if menu_open: set_menu(false)
	if not is_finite(delta) or delta < 0.0 or delta > 5.0: cancel_inputs(); return
	if player._pose_authority==&"on_foot" and player._jump.is_empty():
		_posture_view=posture.step_posture(delta,Callable(self,"_can_occupy_posture"),Input.is_action_pressed(player.ACTION_RUN))
		var capsule: CollisionShape3D=player.get_node("PlayerCapsule")
		capsule.shape.height=float(_posture_view.height); capsule.position.y=float(_posture_view.height)*.5
	var forward: Vector3 = -player.get_preview_camera().global_basis.z
	_aim={"aimYaw":atan2(forward.x,forward.z),"aimPitch":asin(clampf(forward.y,-.958,.958)),"recoil":0.0,"recoilYaw":0.0,"reloadProgress":0.0}
	if not armed(): return
	var allowed: bool = _interaction_allowed() and not menu_open and fire_state.weaponId!="rpg"
	var moving: bool = Vector2(player.velocity.x,player.velocity.z).length_squared() > .01
	var stance: String="prone" if float(_posture_view.value)>=1.95 else "crouch" if float(_posture_view.value)>=.95 else "stand"
	var input := {"triggerHeld":allowed and _held,"triggerPressed":allowed and _pressed,"reload":allowed and _reload,"aiming":_aiming,"posture":stance,"moving":moving,"running":moving and Input.is_action_pressed(player.ACTION_RUN)}
	var result := Fire.step(fire_state,input,delta)
	_pressed = false; _reload = false
	if result.has("error"): cancel_inputs(); return
	result.state=_inventory_state(result.state)
	_pending_shots = result.shots
	_pending_epoch = player._pose_epoch
	if _pending_shots.is_empty():
		var updated: Dictionary=inventory.update_fire_state(result.state)
		if not updated.get("ok",false): cancel_inputs(); return
		fire_state = result.state
	else:
		input.triggerHeld=false; input.triggerPressed=false
		var fallback := Fire.step(fire_state,input,delta)
		_pending_plan={"weapon_id":fire_state.weaponId,"uid":inventory.get_item_uid(fire_state.weaponId),"proposed":result.state,"fallback":_inventory_state(fallback.state)}
	var pose_state: Dictionary=result.state
	var recoil := Fire.sample_recoil(pose_state)
	_aim = {"aimYaw":atan2(forward.x,forward.z),"aimPitch":asin(clampf(forward.y,-.958,.958)),"recoil":recoil.weaponKick,"recoilYaw":recoil.recoilYaw,"reloadProgress":1.0-float(pose_state.reloadRemaining)/float(_profile.reloadSeconds) if float(pose_state.reloadRemaining)>0.0 else 0.0}
	_refresh_ui()

func decorate(selected: Dictionary) -> Dictionary:
	if not _owner_current(): return selected
	var gait: RefCounted = player._locomotion
	var actual_speed:=Vector2(player.velocity.x,player.velocity.z).length()
	var distance:=Vector2(player.global_position.x-_last_foot.x,player.global_position.z-_last_foot.z).length()
	_last_foot=player.global_position
	if player.is_on_floor() and player._jump.is_empty():
		var prepared: Dictionary=posture.sample_ground(selected,{"delta":_pose_delta,"moving":actual_speed>.01,"speed":actual_speed,"distance":distance,"actor_world":player._visual.global_transform,"actor_yaw":player._visual.global_rotation.y,"standing_phase":gait._phase,"standing_gait":gait._gait,"running":Input.is_action_pressed(player.ACTION_RUN)},float(_aim.get("aimYaw",0)),player._pose_epoch)
		if prepared.get("valid",false): selected=prepared
	if not armed(): return selected
	var source_gait: Dictionary=selected.get("weapon_posture",{})
	return presentation.decorate(selected,_aim,{"crouch":_posture_view.crouch,"prone":_posture_view.prone},float(source_gait.get("phase",gait._phase)),float(source_gait.get("gait",gait._gait)),player._pose_epoch)

func finish_pose(selected: Dictionary) -> Dictionary:
	return posture.finish_ground(selected) if _owner_current() else selected

func movement_speed(standing_speed: float) -> float:
	if _posture_view.is_empty(): return standing_speed
	return lerpf(lerpf(standing_speed,1.55,float(_posture_view.crouch)),.8,float(_posture_view.prone))

func _can_occupy_posture(height: float,_target: String) -> bool:
	if not _owner_current() or not is_finite(height) or height<.62 or height>1.9: return false
	_posture_shape.radius=.30; _posture_shape.height=height-.012
	_posture_query.transform=Transform3D(Basis.IDENTITY,player.global_position+Vector3.UP*(height*.5+.007))
	return player.get_world_3d().direct_space_state.intersect_shape(_posture_query,1).is_empty()

func _projectile_ray(request: Dictionary) -> Dictionary:
	if not _owner_current(): return {"invalid":true}
	_shot_ray.from=request.origin; _shot_ray.to=request.origin+request.direction*float(request.range); _shot_ray.collision_mask=5; _shot_ray.exclude=[player.get_rid()]
	_shot_ray.hit_from_inside=true
	var hit:=scene.get_world_3d().direct_space_state.intersect_ray(_shot_ray)
	if hit.is_empty(): return {}
	return {"point":hit.position,"normal":hit.normal,"distance":request.origin.distance_to(hit.position),"collider":hit.collider}

func _ground_height(x: float,z: float,y: float) -> float:
	if not _owner_current(): return NAN
	_shot_ray.from=Vector3(x,y+.3,z); _shot_ray.to=Vector3(x,y-8,z); _shot_ray.collision_mask=1; _shot_ray.exclude=[player.get_rid()]
	var hit:=scene.get_world_3d().direct_space_state.intersect_ray(_shot_ray)
	return float(hit.position.y) if not hit.is_empty() else NAN

func after_pose_applied(selected: Dictionary) -> void:
	if not _owner_current() or not armed(): _settle_pending(false); return
	var receipt: Dictionary = presentation.after_pose_applied(selected)
	last_muzzle = receipt.duplicate(true)
	if not receipt.get("ok", false) or _pending_epoch != player._pose_epoch or not _interaction_allowed():
		_settle_pending(false); return
	if _pending_plan.is_empty(): return
	var camera: Camera3D = player.get_preview_camera()
	var origin:=camera.global_position
	var direction: Vector3=-camera.global_basis.z
	var target:=origin+direction*100.0
	var hit:=_projectile_ray({"origin":origin,"direction":direction,"range":100.0})
	if hit.has("point"): target=hit.point
	var pending := _pending_shots
	# Validate every shot before committing ammo. Pool admission below is synchronous
	# and callback-free; notifications describe the already accepted whole batch.
	for shot: Dictionary in pending:
		if not effects.can_shoot(shot,receipt,target): _settle_pending(false); return
	if not _settle_pending(true): return
	for shot: Dictionary in pending:
		var emitted: bool=effects.shoot(shot,receipt,target)
		assert(emitted,"Preflighted projectile batch must admit without callbacks")
		shots_count += 1
	_refresh_ui()
	for shot: Dictionary in pending:
		if not _owner_current(): break
		shot_emitted.emit(shot.duplicate(true),receipt.duplicate(true),origin,direction)

func invalidate_pose() -> void:
	_settle_pending(false); last_muzzle.clear()
	if presentation != null: presentation.invalidate_pose()

func _build_ui() -> void:
	_layer = CanvasLayer.new(); _layer.layer = 12; add_child(_layer)
	_hud = Label.new(); _hud.position = Vector2(22,72); _hud.add_theme_font_size_override("font_size",18); _hud.mouse_filter=Control.MOUSE_FILTER_IGNORE; _layer.add_child(_hud)
	_crosshair = Label.new(); _crosshair.text="·"; _crosshair.add_theme_font_size_override("font_size",34); _crosshair.mouse_filter=Control.MOUSE_FILTER_IGNORE; _layer.add_child(_crosshair)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER); _crosshair.position=Vector2(-5,-23)
	_menu = PanelContainer.new(); _layer.add_child(_menu); _menu.visible=false
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER); _menu.position=Vector2(-285,-235); _menu.custom_minimum_size=Vector2(570,400)
	var margin := MarginContainer.new(); for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	_menu.add_child(margin)
	var column := VBoxContainer.new(); margin.add_child(column)
	var title := Label.new(); title.text="Оружие · Q — закрыть"; title.add_theme_font_size_override("font_size",22); column.add_child(title)
	var grid := GridContainer.new(); grid.columns=3; column.add_child(grid)
	var ids: Array = ["none"]; ids.append_array(Fire.ids())
	for id: String in ids:
		var button := Button.new(); button.text=LABELS[id]; button.custom_minimum_size=Vector2(170,48); button.focus_mode=Control.FOCUS_NONE
		button.pressed.connect(func(): equip(id)); grid.add_child(button); _buttons[id]=button

func _refresh_ui() -> void:
	if not is_instance_valid(_hud): return
	var id: String = fire_state.get("weaponId","none")
	var value: String = LABELS.get(id,id) + " · Q — оружие"
	if id != "none": value += "\n%d / %d · R — перезарядить" % [int(fire_state.magazine),int(fire_state.reserveAmmo)]
	if float(fire_state.get("reloadRemaining",0)) > 0.0: value += "\nПерезарядка…"
	if id=="rpg": value += "\nВыстрел РПГ ещё переносится"
	if value != _hud_value: _hud.text=value; _hud_value=value
	_crosshair.visible=armed() and not menu_open and player._free_mouse_look
	if menu_open:
		var owned: Array = inventory.get_owned_ids()
		for key: String in _buttons: _buttons[key].disabled=key!="none" and not owned.has(key)

func snapshot() -> Dictionary:
	return {"ready":ready_for_play,"equipped":fire_state.get("weaponId","none"),"fire_state":fire_state.duplicate(true),"menu_open":menu_open,"shots":shots_count,"inventory":inventory.snapshot() if inventory!=null else {},"muzzle":last_muzzle.duplicate(),"posture":_posture_view.duplicate(),"effects":effects.stats() if effects!=null else {},"cosmetic_impacts":cosmetic_impacts}

func _exit_tree() -> void:
	ready_for_play = false
	if effects != null: effects.dispose()
	if posture != null: posture.dispose()
	if presentation != null: presentation.dispose()
	if inventory != null: inventory.dispose()
