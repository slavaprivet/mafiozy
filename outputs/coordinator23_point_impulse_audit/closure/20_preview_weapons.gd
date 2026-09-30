extends Node
const WalkWeaponUI = preload("res://scripts/weapons/walk_weapon_ui.gd")
var _walk_ui: Control
var cargo_reticle_requested := false
## Local new-session arsenal. Authenticated ownership and target HP stay separate.
const AimCamera = preload("res://scripts/weapons/weapon_aim_camera.gd")
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
const Inventory = preload("res://scripts/weapons/weapon_inventory.gd")
const Presentation = preload("res://scripts/weapons/player_weapon_presentation.gd")
const RpgEffects = preload("res://scripts/weapons/rpg_effects.gd")
const Projectiles = preload("res://scripts/weapons/weapon_projectiles.gd")
const SurfaceImpacts = preload("res://scripts/weapons/weapon_surface_impacts.gd")
const Posture = preload("res://scripts/weapons/weapon_posture_base.gd")
signal shot_emitted(shot: Dictionary, muzzle: Dictionary, camera_origin: Vector3, camera_direction: Vector3)
const LABELS := {"none":"Без оружия", "nagan":"Наган", "tt_pistol":"ТТ", "revolver":"Револьвер", "deagle":"Desert Eagle", "golden_colt":"Золотой Colt", "sawn_off":"Обрез", "shotgun":"Дробовик", "uzi":"Uzi", "golden_uzi":"Золотой Uzi", "ak74":"АК-74", "m16":"M16", "tommy_gun":"Томпсон", "sniper":"Снайперская винтовка", "rpg":"РПГ"}
var aim_camera: RefCounted
var inventory: RefCounted
var presentation: RefCounted
var effects: RefCounted
var rpg_effects: RefCounted
var surface_effects: RefCounted
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
var _combat_active := false
var _layer: CanvasLayer
var _hud: Label
var _crosshair: Control
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
	surface_effects=SurfaceImpacts.new()
	if not surface_effects.configure(world):
		effects.dispose(); posture.dispose(); presentation.dispose(); inventory.dispose(); return {"ok":false,"reason":"surface_effects"}
	effects.cosmetic_impact.connect(_surface_impact)
	fire_state = Fire.create_state("none")
	ready_for_play = true
	rpg_effects=RpgEffects.new()
	configured=rpg_effects.configure(self)
	if not configured.get("ok",false):
		rpg_effects.dispose(); surface_effects.dispose(); effects.dispose(); posture.dispose(); presentation.dispose(); inventory.dispose(); ready_for_play=false; return configured
	rpg_effects.cosmetic_impact.connect(_surface_impact)
	_build_ui()
	aim_camera=AimCamera.new()
	if not aim_camera.configure(self): return {"ok":false,"reason":"aim_camera"}
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
	if aim_camera!=null: aim_camera.reset()
	_combat_active=false
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
	_combat_active=false
	if not _owner_current(): return
	_settle_pending(false)
	effects.advance(delta)
	surface_effects.advance(delta)
	rpg_effects.advance(delta)
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
	if aim_camera!=null: aim_camera.advance(delta)
	var forward: Vector3 = -player.get_preview_camera().global_basis.z
	_aim={"aimYaw":atan2(forward.x,forward.z),"aimPitch":asin(clampf(forward.y,-.958,.958)),"recoil":0.0,"recoilYaw":0.0,"reloadProgress":0.0}
	if not armed(): return
	var allowed: bool = _interaction_allowed() and not menu_open
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
	# Walk updateCombat.active: merely carrying a gun does not aim the body.
	_combat_active=allowed and (_aiming or _held or not result.shots.is_empty() or float(recoil.normalized)>0 or float(pose_state.reloadRemaining)>0)
	_aim = {"aimYaw":atan2(forward.x,forward.z),"aimPitch":asin(clampf(forward.y,-.958,.958)),"recoil":recoil.weaponKick,"recoilYaw":recoil.recoilYaw,"reloadProgress":1.0-float(pose_state.reloadRemaining)/float(_profile.reloadSeconds) if float(pose_state.reloadRemaining)>0.0 else 0.0}
	_refresh_ui()

func decorate(selected: Dictionary) -> Dictionary:
	if not _owner_current(): return selected
	var gait: RefCounted = player._locomotion
	var actual_speed:=Vector2(player.velocity.x,player.velocity.z).length()
	var distance:=Vector2(player.global_position.x-_last_foot.x,player.global_position.z-_last_foot.z).length()
	_last_foot=player.global_position
	if player.is_on_floor() and player._jump.is_empty():
		# Source hero.update rotates the complete visual pivot toward aim before
		# weapon IK. The standing posture fast path otherwise keeps travel yaw.
		# Set an absolute relative yaw: crouch/prone may assign the same value,
		# but never multiply it twice. Preserve unarmed movement and floor offset.
		if _combat_active:
			selected=selected.duplicate(); selected.visual_rotation=Quaternion(Vector3.UP,float(_aim.get("aimYaw",0))-player._visual.global_rotation.y)
		var prepared: Dictionary=posture.sample_ground(selected,{"delta":_pose_delta,"moving":actual_speed>.01,"speed":actual_speed,"distance":distance,"actor_world":player._visual.global_transform,"actor_yaw":player._visual.global_rotation.y,"standing_phase":gait._phase,"standing_gait":gait._gait,"running":Input.is_action_pressed(player.ACTION_RUN),"weapon_mounted":armed()},float(_aim.get("aimYaw",0)) if _combat_active else player._visual.global_rotation.y,player._pose_epoch)
		if prepared.get("valid",false): selected=prepared
	if not armed(): return selected
	var source_gait: Dictionary=selected.get("weapon_posture",{})
	# Source inactive hero.update receives no aimYaw/aimPitch. Reload progress
	# remains a separate presentation input even if menu/authority blocks aim.
	var presentation_aim: Dictionary=_aim if _combat_active else {"reloadProgress":_aim.get("reloadProgress",0.0)}
	return presentation.decorate(selected,presentation_aim,{"crouch":_posture_view.crouch,"prone":_posture_view.prone},float(source_gait.get("phase",gait._phase)),float(source_gait.get("gait",gait._gait)),player._pose_epoch)

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
	_shot_ray.from=request.origin; _shot_ray.to=request.origin+request.direction*float(request.range); _shot_ray.collision_mask=5 | 256; _shot_ray.exclude=[player.get_rid()]
	_shot_ray.hit_from_inside=true
	var hit:=scene.get_world_3d().direct_space_state.intersect_ray(_shot_ray)
	if hit.is_empty(): return {}
	return {"point":hit.position,"normal":hit.normal,"distance":request.origin.distance_to(hit.position),"collider":hit.collider}

func _surface_impact(receipt: Dictionary) -> void:
	if not _owner_current(): return
	var collider: Variant=receipt.get("collider")
	if not is_instance_valid(collider): return
	# Character capsules and physical limbs are contact proxies, not the skin
	# surface. Their owner handles injury presentation; never paint masonry chips
	# on these invisible hulls or attach a scorch to an animated rigid proxy.
	if collider is CharacterBody3D or collider.has_meta("ragdoll_bone"): return
	if surface_effects.hit(receipt): cosmetic_impacts+=1

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
	if fire_state.weaponId=="rpg":
		if pending.size()!=1: _settle_pending(false); return
		var prepared: Dictionary=rpg_effects.prepare_shot(pending[0],receipt,target)
		if not prepared.get("ok",false): _settle_pending(false); return
		if not _settle_pending(true): rpg_effects.cancel_shot(prepared.ticket); return
		# Both commits are synchronous; preflight already ran all external ports.
		var emitted: bool=rpg_effects.commit_shot(prepared.ticket)
		assert(emitted,"Reserved RPG launch must commit with accepted inventory")
		shots_count+=1; _refresh_ui()
		if _owner_current(): shot_emitted.emit(pending[0].duplicate(true),receipt.duplicate(true),origin,direction)
		return
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
	_walk_ui = WalkWeaponUI.new(); _layer.add_child(_walk_ui)
	var textures: Dictionary = {}
	for id: String in LABELS:
		var path := "res://assets/weapon_thumbnails/"+id+".png"
		if ResourceLoader.exists(path): textures[id]=load(path)
	_walk_ui.configure(self,textures)
	_menu=_walk_ui.menu; _crosshair=_walk_ui.crosshair; _hud=_walk_ui.title
	for id: String in _walk_ui.choices: _buttons[id]=_walk_ui.choices[id].button

func _refresh_ui() -> void:
	if is_instance_valid(_walk_ui): _walk_ui.refresh()

func set_cargo_reticle(requested: bool) -> void:
	if cargo_reticle_requested == requested: return
	cargo_reticle_requested=requested
	_refresh_ui()

func snapshot() -> Dictionary:
	return {"ready":ready_for_play,"equipped":fire_state.get("weaponId","none"),"fire_state":fire_state.duplicate(true),"menu_open":menu_open,"shots":shots_count,"inventory":inventory.snapshot() if inventory!=null else {},"muzzle":last_muzzle.duplicate(),"posture":_posture_view.duplicate(),"effects":effects.stats() if effects!=null else {},"rpg":rpg_effects.stats() if rpg_effects!=null else {},"cosmetic_impacts":cosmetic_impacts}

func _exit_tree() -> void:
	if aim_camera!=null: aim_camera.dispose()
	ready_for_play = false
	if rpg_effects != null: rpg_effects.dispose()
	if effects != null: effects.dispose()
	if surface_effects != null: surface_effects.dispose()
	if posture != null: posture.dispose()
	if presentation != null: presentation.dispose()
	if inventory != null: inventory.dispose()
