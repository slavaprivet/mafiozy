extends Node
const WalkWeaponUI = preload("res://scripts/weapons/walk_weapon_ui.gd")
const SandboxArsenal29=preload("res://scripts/weapons/sandbox_arsenal29.gd")
var sandbox_reselect29:=false
var _sandbox_choice29:=""
var _sandbox_display29:=""
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
const LABELS := {"none":"Без оружия", "sword":"Тестовый меч (прототип)", "bow":"Тестовый лук (прототип)", "mace":"Булава (прототип)", "axe":"Двуручный топор (прототип)", "sledge":"Кувалда (прототип)", "spear":"Копьё (прототип)", "shield":"Щит (прототип)", "nagan":"Наган", "tt_pistol":"ТТ", "revolver":"Револьвер", "deagle":"Desert Eagle", "golden_colt":"Золотой Colt", "sawn_off":"Обрез", "shotgun":"Дробовик", "uzi":"Uzi", "golden_uzi":"Золотой Uzi", "ak74":"АК-74", "m16":"M16", "tommy_gun":"Томпсон", "sniper":"Снайперская винтовка", "rpg":"РПГ"}
## DSH_SWORD_PROTO: the prototype sword is a melee item, not a firearm. It is
## always available in the existing arsenal menu (no purchase, no ammo) and it
## only routes input to the prototype host while it is the equipped item.
const SWORD_ID := "sword"
## DSH_BOW_PROTO: the test bow, always available like the test sword.
const BOW_ID := "bow"
## DSH_MELEE_SET: every melee weapon of the set, always available and free of charge.
const MELEE_IDS := ["sword", "mace", "axe", "sledge", "spear"]
## DSH_MELEE_SET: the shield is worn, not held, so it has its own equip path.
const SHIELD_ID := "shield"
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
var cargo_menu_owner: Node
var castle_storage_owner: Node
var _ship_climb := false
var _ship_saved_fire_state: Dictionary = {}
var _ship_saved_shield := false
var _ship_climb_epoch := -1
var _catapult_stone_carry := false
var _catapult_saved_fire_state: Dictionary = {}
var _catapult_saved_shield := false
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

func configure(world: Node3D, actor: CharacterBody3D, options: Dictionary = {}) -> Dictionary:
	if ready_for_play or not is_instance_valid(world) or not is_instance_valid(actor) or not actor.is_inside_tree(): return {"ok":false,"reason":"binding"}
	scene = world; player = actor
	sandbox_reselect29=bool(options.get("sandbox_reselect29",false))
	inventory = Inventory.new()
	var inventory_options: Dictionary = {}
	# DSH_PLAYERSHOP: starter ownership is supplied only when the shop is enabled.
	if options.has("ownedIds"): inventory_options["ownedIds"] = options["ownedIds"]
	var configured: Dictionary = inventory.configure(Fire.new(), inventory_options)
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
	if _ship_climb: return false
	return _owner_current() and player._free_mouse_look and player._pose_authority == &"on_foot" and player._jump.is_empty() and not bool(scene.get("preview_dead")) and not bool(scene.get("preview_physics_fault"))

## DSH_MELEE_SET: the arsenal OWNS the cursor, so choosing a weapon has to be allowed
## while it is open even though the mouse is not captured. Requiring capture here is
## what made pressing a weapon card do nothing at all.
func _equip_allowed() -> bool:
	if _ship_climb: return false
	if not _owner_current(): return false
	if bool(scene.get("preview_dead")) or bool(scene.get("preview_physics_fault")): return false
	if player._pose_authority != &"on_foot": return false
	return player._free_mouse_look or menu_open

## The arsenal may be opened from a captured mouse OR while it is already open, but
## never while the player is dead, mid-air or not in control of his body.
func _menu_allowed() -> bool:
	if _ship_climb: return false
	if not _owner_current(): return false
	if bool(scene.get("preview_dead")) or bool(scene.get("preview_physics_fault")): return false
	return player._pose_authority == &"on_foot"

func _combat_allowed() -> bool:
	if _ship_climb: return false
	if not _owner_current(): return false
	if bool(scene.get("preview_dead")) or bool(scene.get("preview_physics_fault")): return false
	if player._pose_authority != &"on_foot": return false
	# DSH_MELEE_SET: the ARSENAL owns the cursor while it is open, so "the mouse is
	# captured" cannot be a condition for it - the arsenal is exactly what released it.
	# Requiring capture here made combat "not allowed", and advance() then closed the
	# arsenal on the very next physics frame, which is why its cards could not be
	# clicked.
	return player._free_mouse_look or menu_open

func armed() -> bool:
	return ready_for_play and fire_state.get("weaponId", "none") != "none"

func cargo_menu_active() -> bool:
	return is_instance_valid(cargo_menu_owner) and cargo_menu_owner.window_open

func controls_blocked() -> bool:
	return menu_open or cargo_menu_active() or (is_instance_valid(castle_storage_owner) and castle_storage_owner.window_open)

## Holding the one catapult stone borrows both hands. The castle inventory keeps
## ownership and slot positions; only the active models and attacks are suspended.
func begin_catapult_stone_carry() -> bool:
	if _catapult_stone_carry or _ship_climb: return false
	if not _owner_current() or player._pose_authority != &"on_foot": return false
	if is_instance_valid(castle_storage_owner) and castle_storage_owner.window_open:
		castle_storage_owner.close_window()
	set_menu(false)
	cancel_inputs()
	_catapult_saved_fire_state = fire_state.duplicate(true)
	var sword_host: Node = scene.get("preview_sword_prototype")
	_catapult_saved_shield = is_instance_valid(sword_host) and bool(sword_host.shield_status().get("worn", false))
	if _catapult_saved_shield: sword_host.set_shield_worn(false)
	_sword_prototype_selected(false)
	_bow_prototype_selected(false)
	if is_instance_valid(castle_storage_owner) and castle_storage_owner.has_back_bow():
		castle_storage_owner._set_bow_back(true)
	presentation.equip("none")
	fire_state = Fire.create_state("none")
	_catapult_stone_carry = true
	_refresh_ui()
	return true

func end_catapult_stone_carry() -> void:
	if not _catapult_stone_carry: return
	_catapult_stone_carry = false
	var id: String = str(_catapult_saved_fire_state.get("weaponId", "none"))
	if is_instance_valid(castle_storage_owner) and id in castle_storage_owner.MEDIEVAL \
			and not castle_storage_owner._carried.has(id): id = "none"
	fire_state = _catapult_saved_fire_state.duplicate(true) if id != "none" else Fire.create_state("none")
	if id in MELEE_IDS:
		presentation.equip("none")
		_sword_prototype_weapon(id)
		_sword_prototype_selected(true)
	elif id == BOW_ID:
		presentation.equip("none")
		_bow_prototype_selected(true)
		if is_instance_valid(castle_storage_owner): castle_storage_owner._set_bow_back(false)
	else:
		presentation.equip(id)
	if _catapult_saved_shield and is_instance_valid(castle_storage_owner) \
			and castle_storage_owner.hand_has_shield():
		var sword_host: Node = scene.get("preview_sword_prototype")
		if is_instance_valid(sword_host):
			if id == "none" and sword_host.has_method("set_shield_only31"):
				sword_host.set_shield_only31(true)
			sword_host.set_shield_worn(true)
			_sword_prototype_selected(true)
	_catapult_saved_fire_state.clear()
	_catapult_saved_shield = false
	cancel_inputs()
	_refresh_ui()

func equip(id: String) -> Dictionary:
	if _catapult_stone_carry: return {"ok":false,"reason":"hands_occupied_by_stone"}
	if not _equip_allowed(): return {"ok":false,"reason":"inactive"}
	if is_instance_valid(castle_storage_owner) and id in castle_storage_owner.MEDIEVAL \
			and not castle_storage_owner._busy:
		return castle_storage_owner.acquire_or_select(id)
	if is_instance_valid(castle_storage_owner) and id in castle_storage_owner.MEDIEVAL \
			and not castle_storage_owner.allows_equip(id):
		return {"ok":false,"reason":"castle_weapon_not_carried"}
	# DSH_MELEE_SET / DSH_SWORD_PROTO: the whole melee set is always available and
	# never consumes inventory ownership or ammunition. It disables the firearm
	# presentation, and only one weapon host is ever selected at a time.
	if id == SHIELD_ID: return _equip_shield()
	if id in MELEE_IDS: return _equip_melee(id)
	if id == BOW_ID: return _equip_bow_prototype()
	_sword_prototype_selected(false)
	_bow_prototype_selected(false)
	if id != "none" and not inventory.get_owned_ids().has(id): return {"ok":false,"reason":"not_owned"}
	cancel_inputs()
	# Prepare the real model before changing item ownership/equipment state.
	var prepared: Dictionary = presentation.equip(id)
	if not prepared.get("ok", false): return prepared
	# Medieval prototypes live outside firearm inventory. Passing their temporary
	# fire_state to that inventory rejects stowing them (including chest deposits).
	var inventory_state: Dictionary = inventory.get_fire_state() if str(fire_state.get("weaponId", "none")) in MELEE_IDS or str(fire_state.get("weaponId", "none")) == BOW_ID else fire_state
	var result: Dictionary = inventory.equip(id, inventory_state)
	if not result.get("ok", false):
		presentation.equip(str(fire_state.weaponId)); return result
	fire_state = result.fireState
	_sandbox_choice29=id
	if sandbox_reselect29 and id=="none":
		var prototype:Node=scene.get("preview_sword_prototype")
		if is_instance_valid(prototype):prototype.set_shield_worn(false)
	_profile = Fire.profile(id)
	if id == "none" and is_instance_valid(castle_storage_owner):
		castle_storage_owner.selected_none()
	if id == "none" and is_instance_valid(castle_storage_owner) \
			and castle_storage_owner.hand_has_shield():
		var shield_host: Node = scene.get("preview_sword_prototype") if is_instance_valid(scene) else null
		if is_instance_valid(shield_host) and shield_host.has_method("set_shield_only31"):
			shield_host.set_shield_only31(true)
			_sword_prototype_selected(true)
	cancel_inputs()
	if is_instance_valid(player._melee_practice): player._melee_practice.cancel("weapon_equipped")
	set_menu(false)
	_refresh_ui()
	return result

## DSH_MELEE_SET: hands the chosen melee weapon to the prototype host and takes the
## firearm presentation away. No inventory ownership and no ammo are involved.
## Castle loading may defer these hosts. Prepare before changing equipment.
func _ensure_medieval_host(property: String, installer: String) -> bool:
	if not is_instance_valid(scene): return false
	if is_instance_valid(scene.get(property)): return true
	if not scene.has_method(installer): return false
	scene.call(installer)
	return is_instance_valid(scene.get(property))

func _equip_melee(id: String) -> Dictionary:
	if not _ensure_medieval_host("preview_sword_prototype", "_install_sword_prototype"):
		return {"ok":false,"reason":"no_prototype"}
	var prototype: Node = scene.get("preview_sword_prototype")
	var models:Dictionary=prototype.get("_weapon_models")
	var candidate:Node=models.get(id)
	var attachment:Node=prototype.get("_embedded29").dropped_attachment31(candidate)
	if is_instance_valid(attachment) and not bool(attachment.call("can_regrab",prototype)):
		return {"ok":false,"reason":"embedded_weapon_out_of_reach"}
	if str(prototype.get("_weapon_id"))!=id and preload("res://scripts/combat/embedded_drop31.gd").candidate(prototype):
		if not bool(prototype.call("drop_sword_to_ground")):return {"ok":false,"reason":"embedded_release_refused"}
	if sandbox_reselect29 and id in ["axe","sledge","spear"]:
		prototype.set_shield_worn(false)
	if id in ["axe", "sledge", "spear"] and is_instance_valid(prototype) \
			and bool(prototype.shield_status().get("worn", false)):
		return {"ok":false,"reason":"shield_occupies_right_hand"}
	# Selection can be refused (lost hands, shield, invalid id). Do not publish a
	# different HUD/fire-state weapon while the physical host retains its old one.
	if not bool(prototype.set_weapon(id)):
		return {"ok":false,"reason":"melee_selection_refused"}
	if sandbox_reselect29 and not SandboxArsenal29.reclaim_melee(prototype):
		return {"ok":false,"reason":"sandbox_ground_item_missing"}
	cancel_inputs()
	presentation.equip("none")
	fire_state = Fire.create_state("none")
	fire_state.weaponId = id
	fire_state.magazine = 0
	fire_state.reserveAmmo = 0
	_profile = {}
	_sword_prototype_selected(true)
	if is_instance_valid(prototype) and prototype.has_method("set_shield_only31"):
		prototype.set_shield_only31(false)
	_bow_prototype_selected(false)
	_sandbox_choice29=id
	if is_instance_valid(player._melee_practice): player._melee_practice.cancel("melee_equipped")
	set_menu(false)
	_refresh_ui()
	return {"ok":true,"weaponId":id,"melee":true,"ammo_free":true}

## Wears or stows the shield. It goes in the hand that is not carrying the weapon.
func _equip_shield() -> Dictionary:
	if not _ensure_medieval_host("preview_sword_prototype", "_install_sword_prototype"):
		return {"ok":false,"reason":"no_prototype"}
	cancel_inputs()
	var prototype: Node = scene.get("preview_sword_prototype") if is_instance_valid(scene) else null
	if sandbox_reselect29:
		return _equip_sandbox_shield29(prototype)
	if is_instance_valid(prototype) and prototype.has_method("set_shield_worn"):
		var already_worn: bool = bool(prototype.shield_status().get("worn", false))
		var worn: bool = true if is_instance_valid(castle_storage_owner) else not already_worn
		if worn and already_worn: return {"ok":true,"weaponId":SHIELD_ID,"shield":true}
		var shield_only: bool = str(fire_state.get("weaponId", "none")) == "none"
		if worn and shield_only and prototype.has_method("set_shield_only31"):
			prototype.set_shield_only31(true)
		if worn and not bool(prototype.can_wear_shield31()):
			if shield_only and prototype.has_method("set_shield_only31"): prototype.set_shield_only31(false)
			return {"ok":false,"reason":"shield_needs_free_right_hand"}
		if not bool(prototype.set_shield_worn(worn)):
			if shield_only and prototype.has_method("set_shield_only31"): prototype.set_shield_only31(false)
			return {"ok":false,"reason":"shield_equip_failed"}
		if worn:
			_sword_prototype_selected(true)
		set_menu(false)
		_refresh_ui()
		return {"ok":true,"weaponId":SHIELD_ID,"shield":worn}
	return {"ok":false,"reason":"no_prototype"}

func _equip_sandbox_shield29(prototype:Node)->Dictionary:
	if bool(prototype.get("_shield_broken")) or bool(prototype.call("_hand_lost31",&"right")):
		return {"ok":false,"reason":"shield_unavailable"}
	if not SandboxArsenal29.reclaim_shield(prototype):
		return {"ok":false,"reason":"sandbox_shield_missing"}
	var current:=str(fire_state.get("weaponId","none"))
	# Bow/two-handed steel needs both hands. Selecting shield stows that weapon;
	# a one-handed weapon may retain its existing paired shield configuration.
	if current not in ["sword","mace"]:
		if preload("res://scripts/combat/embedded_drop31.gd").candidate(prototype):
			if not prototype.drop_sword_to_ground():return {"ok":false,"reason":"embedded_release_failed"}
		_bow_prototype_selected(false)
		_sword_prototype_selected(false)
		prototype.set_shield_only31(true)
		fire_state=Fire.create_state("none")
		_profile={}
	if not bool(prototype.set_shield_worn(true)):
		return {"ok":false,"reason":"shield_equip_failed"}
	_sword_prototype_selected(true)
	_sandbox_choice29="shield"
	set_menu(false)
	_refresh_ui()
	return {"ok":true,"weaponId":"shield","shield":true}

func arsenal_display_id29()->String:
	var id:=str(fire_state.get("weaponId","none"))
	if not sandbox_reselect29:return id
	var melee:Node=scene.get("preview_sword_prototype")
	if _sandbox_choice29=="shield" and is_instance_valid(melee) and bool(melee.get("_shield_worn")):return "shield"
	if id in MELEE_IDS and (bool(melee.get("_sword_grounded")) or bool(melee.get("_unarmed"))):return "none"
	if id=="bow":
		var bow:Node=scene.get("preview_bow_prototype")
		if is_instance_valid(bow) and bool(bow.get("_grounded")):return "none"
	return id

func stow_castle_shield() -> bool:
	if not is_instance_valid(scene): return false
	var prototype: Node = scene.get("preview_sword_prototype")
	if not is_instance_valid(prototype) or not bool(prototype.shield_status().get("worn", false)):
		return false
	if not bool(prototype.set_shield_worn(false)): return false
	if str(fire_state.get("weaponId", "none")) == "none":
		if prototype.has_method("set_shield_only31"): prototype.set_shield_only31(false)
		_sword_prototype_selected(false)
	return true

## Tells the host which weapon of the set to present.
func _sword_prototype_weapon(id: String) -> void:
	if not is_instance_valid(scene): return
	var prototype: Node = scene.get("preview_sword_prototype")
	if is_instance_valid(prototype) and prototype.has_method("set_weapon"):
		prototype.set_weapon(id)

## DSH_SWORD_PROTO: kept for the existing callers; it is now one weapon of the set.
func _equip_sword_prototype() -> Dictionary:
	return _equip_melee(SWORD_ID)

func _sword_prototype_selected(selected: bool) -> void:
	if not is_instance_valid(scene): return
	var prototype: Node = scene.get("preview_sword_prototype")
	if is_instance_valid(prototype) and prototype.has_method("set_selected"):
		prototype.set_selected(selected)

func sword_selected() -> bool:
	# DSH_MELEE_SET: any melee weapon of the set is handled by the same host.
	return ready_for_play and fire_state.get("weaponId","none") in MELEE_IDS

## DSH_BOW_PROTO: hands the scene over to the bow host, exactly as the sword does.
## No inventory ownership, no ammunition, no firearm presentation.
func _equip_bow_prototype() -> Dictionary:
	if not _ensure_medieval_host("preview_sword_prototype", "_install_sword_prototype") or not _ensure_medieval_host("preview_bow_prototype", "_install_bow_prototype"):
		return {"ok":false,"reason":"no_prototype"}
	var melee_host:Node=scene.get("preview_sword_prototype")
	if preload("res://scripts/combat/embedded_drop31.gd").candidate(melee_host):
		if not melee_host.drop_sword_to_ground():return {"ok":false,"reason":"embedded_release_failed"}
	if sandbox_reselect29:
		if not SandboxArsenal29.reclaim_bow(scene.get("preview_bow_prototype")):
			return {"ok":false,"reason":"sandbox_bow_missing"}
		scene.get("preview_sword_prototype").set_shield_worn(false)
	cancel_inputs()
	presentation.equip("none")
	fire_state = Fire.create_state("none")
	fire_state.weaponId = BOW_ID
	fire_state.magazine = 0
	fire_state.reserveAmmo = 0
	_profile = {}
	_sword_prototype_selected(false)
	_bow_prototype_selected(true)
	_sandbox_choice29="bow"
	if is_instance_valid(player._melee_practice): player._melee_practice.cancel("bow_equipped")
	set_menu(false)
	_refresh_ui()
	return {"ok":true,"weaponId":BOW_ID,"bow":true,"ammo_free":true}

func _bow_prototype_selected(selected: bool) -> void:
	if not is_instance_valid(scene): return
	var prototype: Node = scene.get("preview_bow_prototype")
	if is_instance_valid(prototype) and prototype.has_method("set_selected"):
		prototype.set_selected(selected)

func bow_selected() -> bool:
	return ready_for_play and fire_state.get("weaponId","none") == BOW_ID

## DSH_MELEE_SET: the menu transition is guarded against re-entrancy.
## Releasing the pointer calls the host's release_controls(), which itself calls
## set_menu(false) - so without this guard the nested call closed the arsenal that the
## outer call was in the middle of opening, and the cards were never clickable.
var _menu_transition := false

func set_menu(open: bool) -> void:
	if _menu_transition: return
	if open and not _menu_allowed(): return
	if open and cargo_menu_active(): cargo_menu_owner.close_window(false)
	var was_open := menu_open
	_menu_transition = true
	# The arsenal OWNS the cursor while it is open: freeing it through the player's own
	# API is what makes the cards clickable, and it is done inside the guard so the
	# nested close it triggers cannot undo this transition.
	menu_open = open
	cancel_inputs()
	if is_instance_valid(_menu): _menu.visible = open
	_refresh_ui()
	if _owner_current() and (open or was_open):
		player.set_mouse_captured(not open)
	_menu_transition = false
func cancel_inputs(reset_camera: bool = true) -> void:
	if reset_camera and aim_camera!=null: aim_camera.reset()
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
	if cargo_menu_active(): cargo_menu_owner.close_window(false)
	cancel_inputs()
	# DSH_MELEE_SET: when the ARSENAL is the one freeing the pointer, this must not
	# close it again. Esc still closes it, because that release is not a transition.
	if not _menu_transition: set_menu(false)

func input_event(event: InputEvent) -> bool:
	if _catapult_stone_carry: return false
	if is_instance_valid(castle_storage_owner) and castle_storage_owner.window_open:
		return castle_storage_owner.window_input(event)
	if cargo_menu_active(): return cargo_menu_owner.window_input(event)
	if not _owner_current(): return false
	# DSH_MELEE_SET: THE CURSOR MAY LEGITIMATELY BE FREE - at the very start of a session,
	# after Esc, after Alt-tab - and the arsenal's own keys must still work. Requiring a
	# captured mouse here meant Q and the weapon keys were dead exactly when a player was
	# most likely to press them, and no weapon could be taken at all.
	if not player._free_mouse_look:
		if not (event is InputEventKey) or not event.pressed or event.echo: return false
		var loose_code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if loose_code == KEY_Q and _menu_allowed():
			player.set_mouse_captured(true)
			set_menu(not menu_open)
			return true
		var loose_hot: String = ""
		match loose_code:
			KEY_1: loose_hot = "sword"
			KEY_2: loose_hot = "mace"
			KEY_3: loose_hot = "axe"
			KEY_4: loose_hot = "sledge"
			KEY_5: loose_hot = "spear"
			KEY_6: loose_hot = "shield"
		if loose_hot != "":
			if menu_open: set_menu(false)
			player.set_mouse_captured(true)
			equip(loose_hot)
			return true
		return false
	if event is InputEventKey:
		if event.pressed and not event.echo:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if code == KEY_Q and _interaction_allowed(): set_menu(not menu_open); return true
			# DSH_MELEE_SET: a DIRECT path to the set. It works whether the arsenal window is
			# open or not, and closes it behind itself: a hotkey is a complete command, not a
			# selection that still needs a second click.
			var hot: String = ""
			match code:
				KEY_1: hot = "sword"
				KEY_2: hot = "mace"
				KEY_3: hot = "axe"
				KEY_4: hot = "sledge"
				KEY_5: hot = "spear"
				KEY_6: hot = "shield"
			if hot != "":
				if menu_open: set_menu(false)
				equip(hot)
				return true
			if code == KEY_ESCAPE and menu_open:
				set_menu(false); player.set_mouse_captured(false); return true
			if menu_open: return true
			if code in [KEY_C,KEY_CTRL,KEY_Z] and _request_posture(code): return true
			if code == KEY_R and armed() and _combat_allowed(): _reload = true; return true
		return menu_open
	if event is InputEventMouseButton and not menu_open and armed() and _combat_allowed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _held: _pressed = true
			_held = event.pressed
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_aiming = event.pressed; return true
	return menu_open and event is InputEventMouseMotion

func sandbox_drop_input29(event:InputEvent)->bool:
	if _catapult_stone_carry:return false
	if sandbox_reselect29 and not controls_blocked() and _interaction_allowed() and event is InputEventKey and event.pressed and not event.echo:
		var sandbox_code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if sandbox_code==KEY_G and _sandbox_choice29=="shield":
			var shield_host:Node=scene.get("preview_sword_prototype")
			shield_host.drop_shield_to_ground31()
			_refresh_ui()
			return true
	return false

func _input(event: InputEvent) -> void:
	if _catapult_stone_carry: return
	if sandbox_drop_input29(event):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(castle_storage_owner) and event is InputEventKey \
			and event.pressed and not event.echo and not castle_storage_owner.window_open:
		var castle_code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if castle_code == KEY_Q and castle_storage_owner.has_back_bow() and castle_storage_owner.toggle_bow_selection():
			get_viewport().set_input_as_handled()
			return
		if castle_code == KEY_G and bool(castle_storage_owner.drop_held(Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)).get("ok", false)):
			get_viewport().set_input_as_handled()
			return
	# The visible arsenal owns keys before vehicle/building unhandled shortcuts.
	# GUI mouse clicks still reach the actual weapon buttons.
	if event is InputEventKey and event.pressed and not event.echo:
		var stance_code: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if stance_code in [KEY_C,KEY_CTRL,KEY_Z] and _request_posture(stance_code):
			get_viewport().set_input_as_handled()
			return
	if controls_blocked() and event is InputEventKey:
		# Let the focused GUI receive navigation/activation before unhandled gameplay.
		# Unused keys still reach input_event(), which consumes them while a modal is open.
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code in [KEY_TAB,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_HOME,KEY_END,KEY_PAGEUP,KEY_PAGEDOWN]:return
		if input_event(event):get_viewport().set_input_as_handled()

func _request_posture(code: int) -> bool:
	if not _owner_current() or not player._free_mouse_look or player._pose_authority!=&"on_foot" or not player._jump.is_empty(): return false
	if player.get("_mount_mode") == true: return false
	if bool(scene.get("preview_dead")) or controls_blocked() or player._text_control_focused(): return false
	var requested: String="prone" if code==KEY_Z else "crouch"
	var target: String="stand" if posture.posture_state().target==requested else requested
	posture.request_posture(target,Callable(self,"_can_occupy_posture"))
	return true

func advance(delta: float) -> void:
	_combat_active=false
	if not _owner_current(): return
	if sandbox_reselect29:
		var displayed:=arsenal_display_id29()
		if displayed!=_sandbox_display29:
			_sandbox_display29=displayed
			_refresh_ui()
	_settle_pending(false)
	effects.advance(delta)
	surface_effects.advance(delta)
	rpg_effects.advance(delta)
	_pose_delta=delta
	if _last_pose_epoch != player._pose_epoch:
		_last_pose_epoch = player._pose_epoch
		cancel_inputs()
		if armed() and player._pose_authority == &"on_foot": presentation.equip(str(fire_state.weaponId))
	if not _combat_allowed():
		cancel_inputs()
		if menu_open: set_menu(false)
		if cargo_menu_active():
			cargo_menu_owner.close_window(false)
			player.set_mouse_captured(false)
	if not is_finite(delta) or delta < 0.0 or delta > 5.0: cancel_inputs(); return
	if player._pose_authority==&"on_foot" and player._jump.is_empty() and not player.get("_mount_mode"):
		_posture_view=posture.step_posture(delta,Callable(self,"_can_occupy_posture"),Input.is_action_pressed(player.ACTION_RUN))
		var capsule: CollisionShape3D=player.get_node("PlayerCapsule")
		capsule.shape.height=float(_posture_view.height); capsule.position.y=float(_posture_view.height)*.5
		player.set_posture_eye_height(float(_posture_view.eyeHeight))
	if aim_camera!=null: aim_camera.advance(delta)
	var forward: Vector3 = -player.get_preview_camera().global_basis.z
	_aim={"aimYaw":atan2(forward.x,forward.z),"aimPitch":asin(clampf(forward.y,-.958,.958)),"recoil":0.0,"recoilYaw":0.0,"reloadProgress":0.0}
	if not armed(): return
	# DSH_SWORD_PROTO: the melee sword has no firearm state machine, ammo or
	# shots. Its own host owns the swing, so no Fire.step runs for it.
	# DSH_BOW_PROTO: the bow is its own host too - it owns the draw, the string, the
	# flight and the arrows, so the firearm pipeline must not touch it. The host still
	# consumes the left button, which is fine: the bow polls the real button state.
	if sword_selected() or bow_selected(): return
	var allowed: bool = _combat_allowed() and not controls_blocked()
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
	if player.is_on_floor() and player._jump.is_empty() and player._jump_pose.is_empty():
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
	var jumping: bool=not player._jump_pose.is_empty()
	if jumping:
		presentation_aim=presentation_aim.duplicate()
		presentation_aim["airborne"]=true
		presentation_aim["airBlend"]=1.0
	return presentation.decorate(selected,presentation_aim,{"crouch":0.0 if jumping else _posture_view.crouch,"prone":0.0 if jumping else _posture_view.prone},float(source_gait.get("phase",gait._phase)),float(source_gait.get("gait",gait._gait)),player._pose_epoch)

func finish_pose(selected: Dictionary) -> Dictionary:
	return posture.finish_ground(selected) if _owner_current() else selected

func movement_speed(standing_speed: float) -> float:
	if _posture_view.is_empty(): return standing_speed
	return lerpf(lerpf(standing_speed,1.55,float(_posture_view.crouch)),.8,float(_posture_view.prone))

func _can_occupy_posture(height: float,_target: String) -> bool:
	if not _owner_current() or not is_finite(height) or height<.62 or height>1.9: return false
	_posture_shape.radius=.30; _posture_shape.height=height-.012
	# DSH_CASTLE: the clearance probe used to start 7 mm above the boots, which is a
	# contact, not a clearance: on the castle's own ground the probe touched the paving
	# and every crouch was refused. Five centimetres is still a real clearance test.
	_posture_query.transform=Transform3D(Basis.IDENTITY,player.global_position+Vector3.UP*(height*.5+.05))
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
	if not receipt.get("ok", false) or _pending_epoch != player._pose_epoch or not _combat_allowed():
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

func begin_ship_climb() -> bool:
	if not _owner_current() or bool(scene.get("preview_dead")) or bool(scene.get("preview_physics_fault")): return false
	if _ship_climb or _catapult_stone_carry: return false
	if not _owner_current() or player._pose_authority != &"on_foot": return false
	if is_instance_valid(castle_storage_owner) and castle_storage_owner.window_open:
		castle_storage_owner.close_window()
	set_menu(false)
	cancel_inputs()
	_ship_climb_epoch = player._pose_epoch
	_ship_saved_fire_state = fire_state.duplicate(true)
	var sword_host: Node = scene.get("preview_sword_prototype")
	_ship_saved_shield = is_instance_valid(sword_host) and bool(sword_host.shield_status().get("worn", false))
	if _ship_saved_shield: sword_host.set_shield_worn(false)
	_sword_prototype_selected(false)
	_bow_prototype_selected(false)
	if is_instance_valid(castle_storage_owner) and castle_storage_owner.has_back_bow():
		castle_storage_owner._set_bow_back(true)
	presentation.equip("none")
	fire_state = Fire.create_state("none")
	_ship_climb = true
	_refresh_ui()
	return true

func end_ship_climb(restore: bool = true) -> void:
	if not _ship_climb: return
	_ship_climb = false
	if not restore or not _owner_current() or bool(scene.get("preview_dead")) or bool(scene.get("preview_physics_fault")) or player._pose_epoch != _ship_climb_epoch or str(fire_state.get("weaponId", "none")) != "none":
		_ship_saved_fire_state.clear()
		_ship_saved_shield = false
		return
	var id: String = str(_ship_saved_fire_state.get("weaponId", "none"))
	if is_instance_valid(castle_storage_owner) and id in castle_storage_owner.MEDIEVAL \
			and not castle_storage_owner._carried.has(id): id = "none"
	fire_state = _ship_saved_fire_state.duplicate(true) if id != "none" else Fire.create_state("none")
	if id in MELEE_IDS:
		presentation.equip("none")
		_sword_prototype_weapon(id)
		_sword_prototype_selected(true)
	elif id == BOW_ID:
		presentation.equip("none")
		_bow_prototype_selected(true)
		if is_instance_valid(castle_storage_owner): castle_storage_owner._set_bow_back(false)
	else:
		presentation.equip(id)
	if _ship_saved_shield and is_instance_valid(castle_storage_owner) \
			and castle_storage_owner.hand_has_shield():
		var sword_host: Node = scene.get("preview_sword_prototype")
		if is_instance_valid(sword_host):
			if id == "none" and sword_host.has_method("set_shield_only31"):
				sword_host.set_shield_only31(true)
			sword_host.set_shield_worn(true)
			_sword_prototype_selected(true)
	_ship_saved_fire_state.clear()
	_ship_saved_shield = false
	cancel_inputs()
	_refresh_ui()
