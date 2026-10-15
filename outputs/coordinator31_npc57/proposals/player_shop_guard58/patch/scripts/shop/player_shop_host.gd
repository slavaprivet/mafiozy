extends Node
## Local player shop host of the preview city.
## Flow: the shopkeeper stands at the entrance of every gun_shop building, the
## "Поговорить" prompt follows his head, E opens the talk panel, "Товар" opens the
## goods window (tabs: оружие / броня / расход), the card button runs exactly one
## transaction. P opens the same window anywhere (sandbox shortcut for checks).
## Money stays in the wallet, guns in the weapon inventory, armor and consumables
## in the backpack; the worn vest is drawn over the clothes by the armor visual.
const Catalog = preload("res://scripts/shop/player_shop_catalog.gd")
const Wallet = preload("res://scripts/shop/player_shop_wallet.gd")
const Purchase = preload("res://scripts/shop/player_shop_state.gd")
const Backpack = preload("res://scripts/shop/player_shop_inventory.gd")
const ArmorVisual = preload("res://scripts/shop/player_armor_visual.gd")
const ShopTheme = preload("res://scripts/shop/player_shop_theme.gd")
const Dialog = preload("res://scripts/shop/player_shop_dialog.gd")
const GoodsWindow = preload("res://scripts/shop/player_shop_panel.gd")
const InventoryWindow = preload("res://scripts/shop/player_inventory_panel.gd")
const Keeper = preload("res://scripts/shop/player_shopkeeper.gd")
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
const TELEMETRY := "DSH_SHOP"
const ASSET_KIND := "gun_shop"
const WEAPON_SHOP_SITE_ID := "VENUE29-SHOP-002"
const C4_ITEM := "c4"
const TALK_RANGE_M := 3.5
const PROMPT_MAX_M := 14.0
const KEEPER_OUTSET_M := 1.7
const MAX_KEEPERS := 4
const UI_LAYER := 16
const ARMOR_META := "player_armor_absorb"
var catalog: RefCounted
var wallet: RefCounted
var state: RefCounted
var backpack: RefCounted
var armor_visual
var scene: Node3D
var player: CharacterBody3D
var weapons: Node
var ready_for_use := false
var error_text := ""
var _goods
var _talk
var _bag
var _layer: CanvasLayer
var _prompt: PanelContainer
var _prompt_text: Label
var _keepers: Array = []
var _nearest
var _nearest_distance := INF
var _keeper_retry_at_ms := 0
var _mouse_released := false
var _ground_settled := false
var _c4_bound := false
var _armor_drawn := false
var _opens := 0
var _talks := 0
var _purchases := 0
var _refusals := 0
var _last_receipt: Dictionary = {}
var _last_result: Dictionary = {}
var _sold_line := ""

func configure(owner_scene: Node3D, actor: CharacterBody3D, weapon_host: Node, options: Dictionary = {}) -> Dictionary:
	if ready_for_use:
		return {"ok": false, "reason": "already_configured"}
	if not is_instance_valid(owner_scene) or not is_instance_valid(actor) or not actor.is_inside_tree():
		return _fail("binding")
	if not is_instance_valid(weapon_host) or weapon_host.get("inventory") == null:
		return _fail("arsenal_missing")
	scene = owner_scene
	player = actor
	weapons = weapon_host
	catalog = Catalog.new()
	var opened: Dictionary = catalog.open(str(options.get("catalog_path", Catalog.DEFAULT_PATH)))
	if not opened.get("ok", false):
		return _fail("catalog:" + str(opened.get("reason", "")))
	catalog.attach_labels(_labels_from_weapons())
	var starting_cash: Variant = options.get("cash", catalog.starting_cash())
	if not (starting_cash is int or starting_cash is float) or float(starting_cash) < 0.0:
		starting_cash = catalog.starting_cash()
	wallet = Wallet.new()
	var funded: Dictionary = wallet.configure(starting_cash)
	if not funded.get("ok", false):
		return _fail("wallet:" + str(funded.get("reason", "")))
	backpack = Backpack.new()
	var packed: Dictionary = backpack.configure(catalog)
	if not packed.get("ok", false):
		return _fail("backpack:" + str(packed.get("reason", "")))
	state = Purchase.new()
	var wired: Dictionary = state.configure(catalog, wallet, Callable(self, "_available"), Callable(self, "_deliver"))
	if not wired.get("ok", false):
		return _fail("state:" + str(wired.get("reason", "")))
	_build_ui()
	_build_armor_visual()
	_bind_damage_provider()
	_spawn_keepers()
	ready_for_use = true
	print(TELEMETRY, " ready=true items=", catalog.item_count(),
		" weapons=", catalog.items_of(Catalog.KIND_WEAPON).size(),
		" ammo=", catalog.items_of(Catalog.KIND_AMMO).size(),
		" armor=", catalog.items_of(Catalog.KIND_ARMOR).size(),
		" consumables=", catalog.items_of(Catalog.KIND_CONSUMABLE).size(),
		" cash=", wallet.cash(), " keepers=", _keepers.size(),
		" inventory=window keys=E/P/I",
		" skipped=", catalog.warnings(), " catalog=", catalog.path())
	return {
		"ok": true, "scope": "local_preview_shop", "items": catalog.item_count(),
		"ammo": catalog.items_of(Catalog.KIND_AMMO).size(),
		"armor": catalog.items_of(Catalog.KIND_ARMOR).size(),
		"consumables": catalog.items_of(Catalog.KIND_CONSUMABLE).size(),
		"cash": wallet.cash(), "keepers": _keepers.size(), "inventory": is_instance_valid(_bag)
	}

func _fail(reason: String) -> Dictionary:
	error_text = reason
	ready_for_use = false
	print(TELEMETRY, " ready=false reason=", reason)
	return {"ok": false, "reason": reason}

## Display names stay owned by preview_weapons.LABELS; the catalog only borrows them.
func _labels_from_weapons() -> Dictionary:
	var value: Variant = weapons.get("LABELS")
	if value is Dictionary and not (value as Dictionary).is_empty():
		return value
	var script: Script = weapons.get_script()
	if script != null:
		var constants: Dictionary = script.get_script_constant_map()
		if constants.get("LABELS") is Dictionary:
			return constants["LABELS"]
	return {}

func texture_for(id: String) -> Texture2D:
	var path := "res://assets/shop_icons/" + id + ".svg" if id.begins_with("ammo_") else "res://assets/weapon_thumbnails/" + id + ".png"
	return load(path) if ResourceLoader.exists(path) else null

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "PlayerShopUi"
	_layer.layer = UI_LAYER
	add_child(_layer)
	_prompt = PanelContainer.new()
	_prompt.name = "ShopTalkPrompt"
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prompt_style := ShopTheme.slot_style(ShopTheme.PANEL_BG, ShopTheme.PANEL_BORDER, 1, 6)
	prompt_style.content_margin_left = 8
	prompt_style.content_margin_right = 9
	prompt_style.content_margin_top = 4
	prompt_style.content_margin_bottom = 4
	_prompt.add_theme_stylebox_override("panel", prompt_style)
	_layer.add_child(_prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(row)
	row.add_child(ShopTheme.keycap("E"))
	_prompt_text = ShopTheme.label("", 13, ShopTheme.TEXT)
	row.add_child(_prompt_text)
	_talk = Dialog.new()
	_layer.add_child(_talk)
	_talk.build()
	_talk.goods_requested.connect(_open_goods)
	_goods = GoodsWindow.new()
	_layer.add_child(_goods)
	var textures := {}
	for kind: String in [Catalog.KIND_WEAPON, Catalog.KIND_AMMO]:
		for card: Variant in catalog.items_of(kind):
			var id := str((card as Dictionary).get("id", ""))
			var texture := texture_for(id)
			if texture != null:
				textures[id] = texture
	_goods.build(catalog, textures)
	_goods.close_requested.connect(close_all)
	_bag = InventoryWindow.new()
	_layer.add_child(_bag)
	_bag.build(catalog, textures)
	_bag.close_requested.connect(close_all)
	_bag.equip_requested.connect(_on_equip)
	_bag.unequip_requested.connect(_on_unequip)
	_goods.purchase_requested.connect(_on_purchase)
	_goods.equip_requested.connect(_on_equip)
	_goods.unequip_requested.connect(_on_unequip)

func _build_armor_visual() -> void:
	armor_visual = ArmorVisual.new()
	armor_visual.name = "WornArmorVisual"
	add_child(armor_visual)
	var rig: Skeleton3D = player.get("_pose_skeleton")
	var placed: Dictionary = armor_visual.configure(player, rig)
	if not placed.get("ok", false):
		print(TELEMETRY, " armor_visual=false reason=", placed.get("reason", ""))
		armor_visual.queue_free()
		armor_visual = null
		return
	print(TELEMETRY, " armor_visual=true bone=", placed.get("bone", ""),
		" bone_index=", placed.get("bone_index", -1),
		" size_m=", placed.get("size_m", []),
		" model_height_m=", placed.get("model_height_m", 0.0))

## The vest is the first owner of incoming damage. The health owner asks through
## this player meta, so no other file has to know about the shop.
func _bind_damage_provider() -> void:
	if not is_instance_valid(player):
		return
	player.set_meta(ARMOR_META, Callable(self, "_absorb_damage"))

func _absorb_damage(amount: int) -> Dictionary:
	if backpack == null:
		return {"absorbed": 0, "remaining": maxi(amount, 0)}
	var result: Dictionary = backpack.absorb(amount)
	var absorbed := int(result.get("absorbed", 0))
	if absorbed > 0:
		_sync_armor_visual()
		print(TELEMETRY, " event=armor_absorb amount=", amount, " absorbed=", absorbed,
			" armor_left=", int(result.get("armor_left", 0)), " broken=", bool(result.get("broken", false)),
			" worn=", str(result.get("worn", "")))
	return result

## C4 charges come from the backpack once the equipment owner exists. Without the
## provider the equipment keeps its own virtual charges (unchanged behaviour).
func _bind_c4_provider() -> void:
	if _c4_bound or not is_instance_valid(scene):
		return
	var equipment: Variant = scene.get("preview_c4")
	if equipment == null or not (equipment is Node) or not (equipment as Node).has_method("set_charge_provider"):
		return
	(equipment as Node).call("set_charge_provider", Callable(self, "_c4_charge"))
	_c4_bound = true
	print(TELEMETRY, " c4_provider=backpack")

## One provider call with an explicit mode: peek for the HUD, take for a real
## placement. Peeking must never consume a charge.
func _c4_charge(consume: bool) -> Dictionary:
	if backpack == null:
		return {"ok": false, "reason": "no_backpack", "count": 0}
	if not consume:
		return {"ok": true, "count": backpack.count(C4_ITEM)}
	var taken: Dictionary = backpack.take(C4_ITEM, 1)
	if not taken.get("ok", false):
		return {"ok": false, "reason": str(taken.get("reason", "no_charges")), "count": backpack.count(C4_ITEM)}
	return {"ok": true, "count": int(taken.get("count", 0))}

## The combined city borrows the compact site's cashier behind its counter.
## The original door-anchor keepers remain for the isolated module sandbox.
func _spawn_keepers() -> void:
	# In the combined city, the compact shop is a destructible Palazzo-style site.
	# Its venue employee already stands behind the counter and is the sole cashier.
	var sites: Variant = scene.get("preview_service_sites29")
	if sites is Node and is_instance_valid(sites):
		var staff_host: Variant = scene.get("preview_venue_staff29")
		if staff_host is Node and is_instance_valid(staff_host):
			var staff_rows: Variant = staff_host.get("_rows")
			if staff_rows is Dictionary:
				for row_value: Variant in (staff_rows as Dictionary).values():
					if not row_value is Dictionary:
						continue
					var row: Dictionary = row_value
					var site_ref: Variant = row.get("clone")
					var site: Variant = site_ref.get_ref() if site_ref is WeakRef else null
					var cashier: Variant = row.get("actor")
					if not is_instance_valid(site) or str(site.get("source_id")) != WEAPON_SHOP_SITE_ID:
						continue
					if cashier is CharacterBody3D and is_instance_valid(cashier):
						_keepers.append(cashier)
						print(TELEMETRY, " keeper=", WEAPON_SHOP_SITE_ID, " model=venue_staff29 behind_counter=true")
						break
		return
	var block: Variant = scene.get("_block")
	if not block is Dictionary:
		return
	var origin := _v3((block as Dictionary).get("originM", [0.0, 0.0, 0.0]))
	var cell := float((block as Dictionary).get("metresPerCell", 0.0))
	var rows: Variant = (block as Dictionary).get("buildings", [])
	if cell <= 0.0 or not rows is Array:
		return
	for value: Variant in rows:
		if _keepers.size() >= MAX_KEEPERS:
			break
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		if str(record.get("assetId", "")) != ASSET_KIND:
			continue
		var source_id := str(record.get("id", ""))
		var anchor := _keeper_anchor(record, origin, cell)
		if anchor.is_empty():
			print(TELEMETRY, " keeper_skipped=", source_id, " reason=no_entry_anchor")
			continue
		var keeper = Keeper.new()
		keeper.name = "Shopkeeper" + str(_keepers.size() + 1)
		add_child(keeper)
		var placed: Dictionary = keeper.configure(anchor["at"], anchor["yaw"], source_id)
		if not placed.get("ok", false):
			keeper.queue_free()
			print(TELEMETRY, " keeper_skipped=", source_id, " reason=", placed.get("reason", ""))
			continue
		keeper.set_player(player)
		_keepers.append(keeper)
		print(TELEMETRY, " keeper=", source_id, " model=", placed.get("model", ""),
			" at=", placed.get("at", []), " meshes=", placed.get("meshes", 0),
			" source_height_m=", placed.get("source_height_m", 0.0))

func _keeper_anchor(record: Dictionary, origin: Vector3, cell: float) -> Dictionary:
	var entry: Variant = record.get("entry", {})
	if not entry is Dictionary or (entry as Dictionary).is_empty():
		return {}
	var anchor_rc: Variant = (entry as Dictionary).get("anchorRC", {})
	if not anchor_rc is Dictionary or (anchor_rc as Dictionary).is_empty():
		return {}
	var base := _world_from_rc(anchor_rc, origin, cell, 0.0)
	var outside := Vector2.ZERO
	var probe_rc: Variant = (entry as Dictionary).get("roadProbeRC", {})
	if probe_rc is Dictionary and not (probe_rc as Dictionary).is_empty():
		var probe := _world_from_rc(probe_rc, origin, cell, 0.0)
		outside = Vector2(probe.x - base.x, probe.z - base.z).normalized()
	# Stand the seller in front of the door, never inside the doorway.
	var at := Vector3(base.x + outside.x * KEEPER_OUTSET_M, base.y, base.z + outside.y * KEEPER_OUTSET_M)
	var yaw := atan2(outside.x, outside.y) if outside != Vector2.ZERO else 0.0
	return {"at": at, "yaw": yaw}

## Same cell contract as the rest of the city: r grows with +z, c grows with +x,
## and originM shifts the cell grid into world metres.
func _world_from_rc(rc: Dictionary, origin: Vector3, cell: float, ground_y: float) -> Vector3:
	return Vector3(float(rc.get("c", 0.0)) * cell - origin.x, ground_y, float(rc.get("r", 0.0)) * cell - origin.z)

func _v3(value: Variant) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func _process(_delta: float) -> void:
	if not ready_for_use:
		return
	if is_instance_valid(scene.get("preview_service_sites29")) and (_keepers.is_empty() or not is_instance_valid(_keepers[0])) and Time.get_ticks_msec() >= _keeper_retry_at_ms:
		_keeper_retry_at_ms = Time.get_ticks_msec() + 1000
		_keepers.clear()
		_spawn_keepers()
	if _physical_store_mode() and (_talk.is_open() or _goods.is_open()) and not _physical_cashier_available():
		close_all()
	if not _ground_settled:
		_settle_ground()
	if not _c4_bound:
		_bind_c4_provider()
	_update_nearest()
	_update_prompt()
	if _mouse_released and not modal_open():
		_restore_mouse()

## Physics may not own the freshly built collisions during _ready, so the ground
## height is sampled on the first frame instead of at bind time.
func _settle_ground() -> void:
	_ground_settled = true
	for keeper: Variant in _keepers:
		var node = keeper
		if node is CharacterBody3D: continue # Already on the owned compact shop floor.
		var at: Vector3 = node.global_position
		var ground := _ground_y(at)
		if is_finite(ground) and absf(ground - at.y) <= 2.0:
			node.global_position = Vector3(at.x, ground, at.z)

func _ground_y(at: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.from = at + Vector3.UP * 3.0
	query.to = at - Vector3.UP * 12.0
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else NAN

func _update_nearest() -> void:
	_nearest = null
	_nearest_distance = INF
	if not talk_allowed():
		return
	for keeper: Variant in _keepers:
		var node = keeper
		if not is_instance_valid(node): continue
		if not node.in_talk_range(player.global_position, TALK_RANGE_M):
			continue
		var distance: float = node.horizontal_distance(player.global_position)
		if distance < _nearest_distance:
			_nearest = node
			_nearest_distance = distance

func _update_prompt() -> void:
	if _prompt == null:
		return
	var camera: Camera3D = player.get_preview_camera() if is_instance_valid(player) else null
	var show := is_instance_valid(_nearest) and not modal_open() and camera != null
	if show:
		var head: Vector3 = _nearest.head_world()
		if camera.is_position_behind(head) or camera.global_position.distance_to(head) > PROMPT_MAX_M:
			show = false
		else:
			_prompt.visible = true
			_prompt.reset_size()
			var screen: Vector2 = camera.unproject_position(head)
			var view: Vector2 = get_viewport().get_visible_rect().size
			var size: Vector2 = _prompt.size
			_prompt.position = Vector2(
				clampf(screen.x - size.x * 0.5, 12.0, maxf(12.0, view.x - size.x - 12.0)),
				clampf(screen.y - size.y - 6.0, 12.0, maxf(12.0, view.y - size.y - 12.0)))
	if not show:
		_prompt.visible = false
	if _prompt.visible and is_instance_valid(_nearest):
		var prompt_line := str(catalog.seller().get("prompt", "Поговорить"))
		if _prompt_text.text != prompt_line:
			_prompt_text.text = prompt_line

func talk_allowed() -> bool:
	if not ready_for_use or not is_instance_valid(player) or not is_instance_valid(scene):
		return false
	if not player.is_inside_tree() or player.is_queued_for_deletion():
		return false
	if not player._free_mouse_look:
		return false
	if player._pose_authority != &"on_foot" or not player._jump.is_empty():
		return false
	if bool(scene.get("preview_dead")) or bool(scene.get("preview_physics_fault")):
		return false
	if is_instance_valid(weapons):
		if bool(weapons.get("menu_open")):
			return false
		if weapons.has_method("cargo_menu_active") and bool(weapons.call("cargo_menu_active")):
			return false
	return true

func _physical_store_mode() -> bool:
	return is_instance_valid(scene) and is_instance_valid(scene.get("preview_service_sites29"))

func _physical_cashier_available() -> bool:
	return not _keepers.is_empty() and is_instance_valid(_keepers[0]) and bool(_keepers[0].available29())

func modal_open() -> bool:
	return (_goods != null and _goods.is_open()) or (_talk != null and _talk.is_open()) or (_bag != null and _bag.is_open())

func _input(event: InputEvent) -> void:
	if not ready_for_use or not event is InputEventKey:
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo:
		return
	var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if _goods.is_open():
		# Plain comparisons: a bare identifier in a `match` pattern can bind a
		# variable instead of comparing it, and a silent match would be a real bug.
		if code == KEY_ESCAPE:
			close_all()
		elif code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_goods.activate_selected()
		elif code == KEY_LEFT:
			_goods.move_selection(-1)
		elif code == KEY_RIGHT:
			_goods.move_selection(1)
		elif code == KEY_UP:
			_goods.move_selection_row(-1)
		elif code == KEY_DOWN:
			_goods.move_selection_row(1)
		elif code == KEY_TAB:
			_cycle_tab()
		_consume()
		return
	if _talk.is_open():
		if code == KEY_ESCAPE:
			_talk.close_talk()
		elif code in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_open_goods()
		_consume()
		return
	if not talk_allowed():
		return
	if code == KEY_E and is_instance_valid(_nearest):
		_open_dialog()
		_consume()
		return
	if code == KEY_P and not _physical_store_mode():
		_open_goods()
		_consume()
		return
	if code == KEY_I:
		_open_inventory()
		_consume()

func _cycle_tab() -> void:
	var tabs: Array = catalog.tabs()
	if tabs.size() < 2:
		return
	var kinds: Array = []
	for tab: Variant in tabs:
		kinds.append(str((tab as Dictionary).get("kind", "")))
	var index: int = kinds.find(_goods.current_tab())
	index = (index + 1) % kinds.size()
	_goods.select_tab(str(kinds[index]))

func _consume() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()

func _open_dialog() -> void:
	if not is_instance_valid(_nearest) or not talk_allowed():
		return
	_release_mouse()
	_talk.open_talk(catalog.seller(), _sold_line)
	_talks += 1
	print(TELEMETRY, " event=talk keeper=", _nearest.source_id, " dist_m=", "%.2f" % _nearest_distance,
		" cash=", wallet.cash(), " frame=", Engine.get_physics_frames())

func _open_goods() -> void:
	if _physical_store_mode() and not _physical_cashier_available():
		close_all()
		return
	if _talk.is_open():
		_talk.close_talk()
	_release_mouse()
	_goods.open_shop()
	_opens += 1
	_refresh_window("Выбери товар: описание, характеристики Рё цена справа. Enter — купить, Tab — раздел, Esc — закрыть.", ShopTheme.DIM)
	print(TELEMETRY, " event=open cash=", wallet.cash(), " items=", catalog.item_count(),
		" opener=", "keeper" if is_instance_valid(_nearest) else "hotkey", " frame=", Engine.get_physics_frames())

## Inventory (I): the same cards as the Q arsenal, but with the real backpack.
func _open_inventory() -> void:
	if _talk.is_open():
		_talk.close_talk()
	if _goods.is_open():
		_goods.close_shop()
	_release_mouse()
	_bag.open_inventory()
	_bag.refresh(stock(), "Клавиша Q — взять оружие в руки. Esc — закрыть.", ShopTheme.DIM)
	print(TELEMETRY, " event=inventory cash=", wallet.cash(), " frame=", Engine.get_physics_frames())

func close_all() -> void:
	if _goods.is_open():
		_goods.close_shop()
	if _talk.is_open():
		_talk.close_talk()
	if _bag != null and _bag.is_open():
		_bag.close_inventory()
	_restore_mouse()
	print(TELEMETRY, " event=close cash=", wallet.cash(), " purchases=", _purchases)

func _release_mouse() -> void:
	if not is_instance_valid(player) or _mouse_released:
		return
	_mouse_released = true
	player.set_mouse_captured(false)

func _restore_mouse() -> void:
	if not _mouse_released:
		return
	_mouse_released = false
	if is_instance_valid(player) and player.is_inside_tree():
		player.set_mouse_captured(true)

## ── purchase policy and delivery ─────────────────────────────────────────
func stock() -> Dictionary:
	var bag: Dictionary = backpack.backpack() if backpack != null else {}
	var ammo := {}
	var reserves := {}
	if catalog != null:
		for card: Variant in catalog.items_of(Catalog.KIND_AMMO):
			var ammo_id := str((card as Dictionary).get("id", ""))
			var state: Dictionary = _ammo_state(ammo_id)
			ammo[ammo_id] = state
			for gun: String in state.get("reserves", {}):
				reserves[gun] = int((state.get("reserves", {}) as Dictionary).get(gun, 0))
	return {
		"weapons": _owned_ids(),
		"ammo": ammo,
		"reserves": reserves,
		"armor": bag.get("armor", {}),
		"consumables": bag.get("consumables", {}),
		"worn": str(bag.get("worn", ""))
	}

## Plain comparisons instead of `match`: a non-literal pattern in GDScript binds a
## variable rather than comparing it, which would silently match every kind.
func _available(item_id: String) -> Dictionary:
	# Revalidate on the transaction stack; modal closure runs later in _process.
	if _physical_store_mode() and not _physical_cashier_available():
		return {"ok": false, "reason": "store_unavailable"}
	var item_kind: Variant = catalog.kind(item_id)
	if item_kind == Catalog.KIND_WEAPON:
		if _owned_ids().has(item_id):
			return {"ok": false, "reason": "already_owned"}
		return {"ok": true}
	if item_kind == Catalog.KIND_ARMOR:
		for owned_id: String in backpack.armor_ids():
			var row: Dictionary = backpack.armor_state(owned_id)
			if int(row.get("qty", 0)) > 0 and not bool(row.get("broken", false)):
				return {"ok": false, "reason": "already_owned", "owned_id": owned_id}
		return {"ok": true}
	if item_kind == Catalog.KIND_AMMO:
		var ammo: Dictionary = _ammo_state(item_id)
		if int(ammo.get("owned_guns", 0)) <= 0:
			return {"ok": false, "reason": "no_weapon_for_caliber"}
		if bool(ammo.get("full", false)):
			return {"ok": false, "reason": "reserve_full"}
		return {"ok": true}
	if item_kind == Catalog.KIND_CONSUMABLE:
		if backpack.count(item_id) >= catalog.limit(item_id):
			return {"ok": false, "reason": "limit_reached"}
		return {"ok": true}
	return {"ok": false, "reason": "unknown_kind"}

func _deliver(item_id: String, uid: String) -> Dictionary:
	var item_kind: Variant = catalog.kind(item_id)
	if item_kind == Catalog.KIND_WEAPON:
		return _grant_weapon(item_id, uid)
	if item_kind == Catalog.KIND_ARMOR:
		var granted: Dictionary = backpack.grant_armor(item_id)
		if not granted.get("ok", false):
			return granted
		backpack.equip(item_id)
		_sync_armor_visual()
		return granted
	if item_kind == Catalog.KIND_AMMO:
		return _add_ammo(item_id)
	if item_kind == Catalog.KIND_CONSUMABLE:
		return backpack.add(item_id, 1)
	return {"ok": false, "reason": "unknown_kind"}

func _on_purchase(item_id: String) -> void:
	if not ready_for_use or not catalog.has(item_id):
		return
	var item_name: Variant = catalog.display_name(item_id)
	var kind: Variant = catalog.kind(item_id)
	var price: Variant = catalog.price(item_id)
	var result: Dictionary = state.purchase(item_id, "")
	_last_result = result.duplicate(true)
	var text := ""
	var color := ShopTheme.GOOD
	if result.get("ok", false):
		_purchases += 1
		_last_receipt = (result.get("receipt", {}) as Dictionary).duplicate(true)
		_sold_line = str(catalog.seller().get("sold", ""))
		var price_paid: int = int(_last_receipt.get("price", price))
		text = _purchase_line(kind, item_id, item_name, price_paid)
		_sync_armor_visual()
		print(TELEMETRY, " event=purchase item=", item_id, " kind=", kind, " price=", price_paid,
			" cash=", wallet.cash(), " replay=", bool(result.get("replayed", false)),
			" backpack=", JSON.stringify(backpack.snapshot()), " frame=", Engine.get_physics_frames())
	else:
		_refusals += 1
		color = ShopTheme.BAD
		var reason := str(result.get("reason", "unknown"))
		match reason:
			"already_owned":
				text = "%s уже есть" % item_name
			"no_weapon_for_caliber":
				text = "Нет ствола под %s — сначала купи оружие" % item_name
			"reserve_full":
				text = "Запас %s уже полный" % item_name
			"limit_reached":
				text = "Больше %d шт. %s не унести" % [catalog.limit(item_id), item_name]
			"cash_insufficient":
				text = "Не хватает денег: цена %s $, у тебя %s $" % [_thousands(price), _thousands(int(result.get("cash", wallet.cash())))]
			"store_unavailable":
				text = "Магазин временно закрыт"
			"unknown_item":
				text = "Такого товара нет в лавке"
			_:
				text = "Покупка не прошла: " + reason
		print(TELEMETRY, " event=refused item=", item_id, " kind=", kind, " reason=", reason,
			" cash=", wallet.cash(), " frame=", Engine.get_physics_frames())
	_refresh_window(text, color)

## Ammo never enters the backpack: it lands in the owned guns of that caliber,
## which is exactly what the 3D shop's Патроны tab did with the shared reserve.
func _add_ammo(item_id: String) -> Dictionary:
	if not is_instance_valid(weapons):
		return {"ok": false, "reason": "arsenal_missing"}
	var inventory: Variant = weapons.get("inventory")
	if inventory == null:
		return {"ok": false, "reason": "arsenal_missing"}
	var rounds: int = catalog.rounds(item_id)
	var owned: Array = _owned_ids()
	var loaded: Array = []
	var added := 0
	var blocked := 0
	for gun: String in catalog.ammo_weapons(item_id):
		if not owned.has(gun):
			continue
		var taken: Dictionary = inventory.add_reserve(gun, rounds)
		if bool(taken.get("ok", false)):
			added += int(taken.get("added", 0))
			loaded.append(gun)
		else:
			blocked += 1
	if loaded.is_empty():
		return {"ok": false, "reason": "reserve_full" if blocked > 0 else "no_weapon_for_caliber"}
	_sync_equipped_reserve()
	return {"ok": true, "added": added, "guns": loaded}

## The equipped gun's live state belongs to the weapon host, which overwrites the
## inventory copy every frame; the new reserve must be written there as well.
func _sync_equipped_reserve() -> void:
	if not is_instance_valid(weapons):
		return
	var state: Variant = weapons.get("fire_state")
	if not state is Dictionary:
		return
	var equipped := str((state as Dictionary).get("weaponId", "none"))
	if equipped == "none":
		return
	var inventory: Variant = weapons.get("inventory")
	if inventory == null:
		return
	var stored: Variant = inventory.get_fire_state(equipped)
	if stored is Dictionary:
		(state as Dictionary)["reserveAmmo"] = int((stored as Dictionary).get("reserveAmmo", 0))
		weapons.set("fire_state", state)

## What the player already carries for this box: which owned guns it feeds and how
## much reserve they hold. Read-only; the guns remain the owners of their ammo.
func _ammo_state(item_id: String) -> Dictionary:
	var guns: Array = catalog.ammo_weapons(item_id)
	var owned: Array = _owned_ids()
	var inventory: Variant = weapons.get("inventory") if is_instance_valid(weapons) else null
	var reserves: Dictionary = {}
	var total := 0
	var matching := 0
	var full := 0
	for gun: String in guns:
		if not owned.has(gun):
			continue
		matching += 1
		var reserve := 0
		if inventory != null:
			var state: Variant = inventory.get_fire_state(gun)
			if state is Dictionary:
				reserve = int((state as Dictionary).get("reserveAmmo", 0))
		reserves[gun] = reserve
		total += reserve
		if reserve >= 9999:
			full += 1
	return {
		"guns": guns, "owned_guns": matching, "reserves": reserves,
		"total": total, "full": matching > 0 and full == matching
	}

func _purchase_line(kind: String, item_id: String, item_name: String, price_paid: int) -> String:
	if kind == Catalog.KIND_ARMOR:
		var row: Dictionary = backpack.worn_state()
		return "%s надет · броня %d/%d · −%s $ · осталось %s $" % [
			item_name, int(row.get("ap", 0)), int(row.get("max", 0)),
			_thousands(price_paid), _thousands(wallet.cash())]
	if kind == Catalog.KIND_AMMO:
		var ammo: Dictionary = _ammo_state(item_id)
		return "%s в стволах · всего %d патронов · −%s $ · осталось %s $" % [
			item_name, int(ammo.get("total", 0)), _thousands(price_paid), _thousands(wallet.cash())]
	if kind == Catalog.KIND_CONSUMABLE:
		return "%s +1 · в рюкзаке %d/%d · −%s $ · осталось %s $" % [
			item_name, backpack.count(item_id), catalog.limit(item_id),
			_thousands(price_paid), _thousands(wallet.cash())]
	return "%s куплен · −%s $ · осталось %s $" % [item_name, _thousands(price_paid), _thousands(wallet.cash())]

func _on_equip(item_id: String) -> void:
	if backpack == null:
		return
	var result: Dictionary = backpack.equip(item_id)
	_sync_armor_visual()
	var text := "Надет: %s" % catalog.display_name(item_id) if result.get("ok", false) else "Не удалось надеть: " + str(result.get("reason", ""))
	print(TELEMETRY, " event=armor_equip item=", item_id, " ok=", bool(result.get("ok", false)), " ", JSON.stringify(backpack.worn_state()))
	_refresh_window(text, ShopTheme.GOOD if result.get("ok", false) else ShopTheme.BAD)

func _on_unequip() -> void:
	if backpack == null:
		return
	backpack.unequip()
	_sync_armor_visual()
	print(TELEMETRY, " event=armor_unequip")
	_refresh_window("Броня снята", ShopTheme.DIM)

func _sync_armor_visual() -> void:
	if not is_instance_valid(armor_visual) or not armor_visual.ready_for_use or backpack == null:
		return
	var worn: Variant = backpack.worn_armor()
	if worn.is_empty():
		armor_visual.clear_vest()
		_armor_drawn = false
		return
	var row: Dictionary = backpack.worn_state()
	var drawn: Dictionary = armor_visual.set_vest(worn, catalog.armor_color(worn), bool(row.get("broken", false)))
	_armor_drawn = bool(drawn.get("ok", false))

func _refresh_window(text: String, color: String) -> void:
	if _goods == null:
		return
	_goods.refresh(wallet, stock(), text, color)
	if _bag != null and _bag.is_open():
		_bag.refresh(stock(), text, color)

func _grant_weapon(item_id: String, uid: String) -> Dictionary:
	if not is_instance_valid(weapons):
		return {"ok": false, "reason": "arsenal_missing"}
	var inventory: Variant = weapons.get("inventory")
	if inventory == null:
		return {"ok": false, "reason": "arsenal_missing"}
	var fire_state: Dictionary = Fire.create_state(item_id)
	if fire_state.is_empty() or str(fire_state.get("weaponId", "")) != item_id:
		return {"ok": false, "reason": "fire_state"}
	var begun: Dictionary = inventory.begin_cargo_import({"uid": uid, "weaponId": item_id, "fireState": fire_state})
	if not begun.get("ok", false):
		return {"ok": false, "reason": str(begun.get("reason", "begin"))}
	var committed: Dictionary = inventory.commit_cargo_import(begun.get("token"))
	if not committed.get("ok", false):
		inventory.cancel_cargo_transfer(begun.get("token"))
		return {"ok": false, "reason": str(committed.get("reason", "commit"))}
	if weapons.has_method("invalidate_pose"):
		weapons.call("invalidate_pose")
	if weapons.has_method("_refresh_ui"):
		weapons.call("_refresh_ui")
	return {"ok": true, "owned": inventory.get_owned_ids()}

func _owned_ids() -> Array:
	if not is_instance_valid(weapons):
		return []
	var inventory: Variant = weapons.get("inventory")
	if inventory == null:
		return []
	return inventory.get_owned_ids()

func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = " " + grouped
	return ("-" if value < 0 else "") + grouped

func snapshot() -> Dictionary:
	var keepers: Array = []
	for keeper: Variant in _keepers:
		if is_instance_valid(keeper): keepers.append((keeper as Node).snapshot())
	return {
		"ready": ready_for_use,
		"error": error_text,
		"scope": "local_preview_shop",
		"cash": wallet.cash() if wallet != null else -1,
		"items": catalog.item_count() if catalog != null else 0,
		"starter": catalog.starter_ids() if catalog != null else [],
		"keepers": keepers,
		"nearest": _nearest.source_id if is_instance_valid(_nearest) else "",
		"nearest_m": _nearest_distance if is_finite(_nearest_distance) else -1.0,
		"modal": modal_open(),
		"opens": _opens,
		"talks": _talks,
		"purchases": _purchases,
		"refusals": _refusals,
		"owned": _owned_ids(),
		"backpack": backpack.snapshot() if backpack != null else {},
		"armor_visual": armor_visual.snapshot() if is_instance_valid(armor_visual) else {},
		"armor_drawn": _armor_drawn,
		"c4_provider": _c4_bound,
		"last_receipt": _last_receipt.duplicate(true),
		"last_result": _last_result.duplicate(true),
		"wallet": wallet.snapshot() if wallet != null else {},
		"catalog": catalog.snapshot() if catalog != null else {}
	}

func _exit_tree() -> void:
	ready_for_use = false
	_mouse_released = false
	if is_instance_valid(player) and player.has_meta(ARMOR_META):
		player.remove_meta(ARMOR_META)
	for keeper: Variant in _keepers:
		if is_instance_valid(keeper) and (keeper as Node).get_parent() == self:
			(keeper as Node).queue_free()
	_keepers.clear()
