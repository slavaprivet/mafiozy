extends SceneTree
## Headless UI receipt for the shop: builds the real goods window (tabs, slots,
## cards, backpack line), the real talk panel, the real shopkeeper and the worn vest
## on the real hero rig. No city, no renderer, no GPU. Run:
##   <godot> --headless --path <game> --script res://scripts/shop/tests/test_player_shop_ui.gd
const Catalog = preload("res://scripts/shop/player_shop_catalog.gd")
const Wallet = preload("res://scripts/shop/player_shop_wallet.gd")
const GoodsWindow = preload("res://scripts/shop/player_shop_panel.gd")
const TalkPanel = preload("res://scripts/shop/player_shop_dialog.gd")
const Keeper = preload("res://scripts/shop/player_shopkeeper.gd")
const ArmorVisual = preload("res://scripts/shop/player_armor_visual.gd")
const InventoryWindow = preload("res://scripts/shop/player_inventory_panel.gd")
const LABELS := {"nagan": "Наган", "tt_pistol": "ТТ", "rpg": "РПГ", "tactical_vest": "Тактический жилет"}
var checks := 0
var failures: Array[String] = []
var _purchases: Array = []
var _equips: Array = []
var _unequips := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var catalog = Catalog.new()
	check(bool(catalog.open(Catalog.DEFAULT_PATH).get("ok", false)), "catalog opens")
	catalog.attach_labels(LABELS)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(root)
	var textures := {}
	for card: Variant in catalog.items_of("weapon"):
		var id := str((card as Dictionary).get("id", ""))
		var path := "res://assets/weapon_thumbnails/" + id + ".png"
		if ResourceLoader.exists(path):
			textures[id] = load(path)
		check(textures.get(id) is Texture2D, "weapon picture loads: " + id)
	for card: Variant in catalog.items_of("ammo"):
		var id := str((card as Dictionary).get("id", ""))
		var path := "res://assets/shop_icons/" + id + ".svg"
		if ResourceLoader.exists(path):
			textures[id] = load(path)
		check(textures.get(id) is Texture2D, "ammo picture loads: " + id)
	var window = GoodsWindow.new()
	root.add_child(window)
	window.build(catalog, textures)
	window.purchase_requested.connect(func(item_id: String) -> void: _purchases.append(item_id))
	window.equip_requested.connect(func(item_id: String) -> void: _equips.append(item_id))
	window.unequip_requested.connect(func() -> void: _unequips += 1)
	check(window.get("_slots").size() == catalog.item_count(), "one slot per item: %d" % window.get("_slots").size())
	window.open_shop()
	check(window.is_open(), "window opens")
	check(window.current_tab() == "weapon", "weapons are the first tab")
	check((window.get("_tab_buttons") as Dictionary).size() == catalog.tabs().size(), "one tab per section")

	var wallet = Wallet.new()
	wallet.configure(5000)
	var empty := {"weapons": [], "armor": {}, "consumables": {}, "worn": ""}
	window.refresh(wallet, empty, "ready")
	_weapon_checks(window, catalog, wallet, empty)
	_armor_checks(window, catalog, wallet)
	_consumable_checks(window, catalog, wallet)
	_ammo_checks(window, catalog, wallet)
	window.close_shop()
	check(not window.is_open(), "window closes")

	_inventory_checks(root, catalog, textures, wallet)
	await _talk_and_keeper_checks(root, catalog)
	var vest_fit: Dictionary = await _vest_fit_checks(root)

	root.free()
	print(JSON.stringify({
		"checks": checks, "failures": failures, "passed": failures.is_empty(), "vest_fit": vest_fit
	}, "  "))
	quit(1 if not failures.is_empty() else 0)

func _weapon_checks(window, catalog, wallet, empty: Dictionary) -> void:
	for card: Variant in catalog.items_of("weapon"):
		var id := str((card as Dictionary).get("id", ""))
		window.select(id)
		check(window.selected_id() == id, "slot selects " + id)
		var price: int = catalog.price(id)
		var buy: Button = window.get("_buy")
		if price <= wallet.cash():
			check(not buy.disabled and buy.text.begins_with("Купить"),
				"affordable gun offers buying: %s / '%s' / disabled=%s" % [id, buy.text, str(buy.disabled)])
		else:
			check(buy.disabled and buy.text.begins_with("Не хватает"),
				"expensive gun needs money: %s / '%s' / disabled=%s" % [id, buy.text, str(buy.disabled)])
	window.select("nagan")
	window.refresh(wallet, {"weapons": ["nagan"], "armor": {}, "consumables": {}, "worn": ""}, "ready")
	var owned_buy: Button = window.get("_buy")
	check(owned_buy.disabled and owned_buy.text == "Уже в арсенале",
		"owned gun shows as bought: '%s' / disabled=%s" % [owned_buy.text, str(owned_buy.disabled)])
	window.select("tt_pistol")
	window.refresh(wallet, empty, "ready")
	_purchases.clear()
	(window.get("_buy") as Button).emit_signal("pressed")
	check(_purchases == ["tt_pistol"], "buy button asks for the selected gun: " + str(_purchases))

func _armor_checks(window, catalog, wallet) -> void:
	window.select_tab("armor")
	check(window.current_tab() == "armor", "armor tab selects")
	var vest := "tactical_vest"
	var points: int = catalog.defense(vest)
	window.select(vest)
	check((window.get("_card_stats") as Label).text.contains("поверх одежды"),
		"armor card explains the vest goes over the clothes: '%s'" % (window.get("_card_stats") as Label).text)
	check((window.get("_buy") as Button).text.begins_with("Купить"),
		"unowned vest offers buying: '%s'" % (window.get("_buy") as Button).text)
	var stored := {"weapons": [], "armor": {vest: {"qty": 1, "ap": points, "max": points, "broken": false}}, "consumables": {}, "worn": ""}
	window.refresh(wallet, stored, "ready")
	window.select("bulletproof")
	check((window.get("_buy") as Button).disabled and (window.get("_buy") as Button).text == "Уже есть бронежилет", "second vest is not offered")
	window.select(vest)
	check((window.get("_buy") as Button).text == "Надеть", "stored vest offers wearing: '%s'" % (window.get("_buy") as Button).text)
	_equips.clear()
	(window.get("_buy") as Button).emit_signal("pressed")
	check(_equips == [vest], "wear button asks the host to equip: " + str(_equips))
	var worn := {"weapons": [], "armor": {vest: {"qty": 1, "ap": 40, "max": points, "broken": false}}, "consumables": {}, "worn": vest}
	window.refresh(wallet, worn, "ready")
	window.select(vest)
	check((window.get("_backpack") as Label).text.contains(catalog.display_name(vest)),
		"backpack line names the worn vest: '%s'" % (window.get("_backpack") as Label).text)
	check((window.get("_backpack") as Label).text.contains("40/%d" % points),
		"backpack line shows the armor points: '%s'" % (window.get("_backpack") as Label).text)
	check((window.get("_buy") as Button).text == "Снять", "worn vest offers taking it off: '%s'" % (window.get("_buy") as Button).text)
	_unequips = 0
	(window.get("_buy") as Button).emit_signal("pressed")
	check(_unequips == 1, "take-off button asks the host to unequip")
	var broken := {"weapons": [], "armor": {vest: {"qty": 1, "ap": 0, "max": points, "broken": true}}, "consumables": {}, "worn": vest}
	window.refresh(wallet, broken, "ready")
	window.select(vest)
	check((window.get("_buy") as Button).text.begins_with("Купить заново"),
		"broken vest can be bought again: '%s'" % (window.get("_buy") as Button).text)

func _consumable_checks(window, catalog, wallet) -> void:
	window.select_tab("consumable")
	check(window.current_tab() == "consumable", "consumable tab selects")
	for wanted: String in ["c4", "grenade", "molotov"]:
		check(catalog.has(wanted) and catalog.kind(wanted) == "consumable", "consumable is on sale: " + wanted)
	var c4_limit: int = catalog.limit("c4")
	var full := {"weapons": [], "armor": {}, "consumables": {"c4": c4_limit}, "worn": ""}
	window.refresh(wallet, full, "ready")
	window.select("c4")
	var full_buy: Button = window.get("_buy")
	check(full_buy.disabled and full_buy.text == "Полный рюкзак",
		"full backpack stops the purchase: '%s' / disabled=%s" % [full_buy.text, str(full_buy.disabled)])
	var some := {"weapons": [], "armor": {}, "consumables": {"c4": 1}, "worn": ""}
	window.refresh(wallet, some, "ready")
	window.select("c4")
	check(not (window.get("_buy") as Button).disabled, "C4 can be bought below the limit")
	check((window.get("_backpack") as Label).text.contains("1"), "backpack line counts the C4")
	window.move_selection(1)
	check(window.selected_id() != "c4", "arrow keys move the highlight inside the tab")

## Ammo tab: boxes go to the owned guns of that caliber and never to the backpack.
func _ammo_checks(window, catalog, wallet) -> void:
	check(catalog.items_of("ammo").size() > 0, "ammo is in the catalog")
	window.select_tab("ammo")
	check(window.current_tab() == "ammo", "ammo tab selects")
	var box := "ammo_magnum"
	window.select(box)
	check((window.get("_card_picture") as TextureRect).visible and (window.get("_card_picture") as TextureRect).texture is Texture2D, "ammo card shows its picture")
	check(window.get("_slots")[box]["image"] is TextureRect, "ammo slot shows its picture")
	var no_gun := {"weapons": ["nagan"], "ammo": {box: {"owned_guns": 0, "total": 0, "full": false}}, "armor": {}, "consumables": {}, "worn": ""}
	window.refresh(wallet, no_gun, "ready")
	window.select(box)
	var buy: Button = window.get("_buy")
	check(buy.disabled and buy.text == "Нет ствола под калибр", "ammo without a gun is not sold: '%s'" % buy.text)
	var with_gun := {"weapons": ["nagan"], "ammo": {box: {"owned_guns": 1, "total": 24, "full": false}}, "armor": {}, "consumables": {}, "worn": ""}
	window.refresh(wallet, with_gun, "ready")
	window.select(box)
	buy = window.get("_buy")
	check(not buy.disabled and buy.text.begins_with("Купить"), "ammo with a gun is sold: '%s'" % buy.text)
	check((window.get("_slots")[box]["state"] as Label).text.contains("24"), "slot shows the current reserve")
	var full := {"weapons": ["nagan"], "ammo": {box: {"owned_guns": 1, "total": 9999, "full": true}}, "armor": {}, "consumables": {}, "worn": ""}
	window.refresh(wallet, full, "ready")
	window.select(box)
	buy = window.get("_buy")
	check(buy.disabled and buy.text == "Полный запас", "full reserve stops the sale: '%s'" % buy.text)

func _talk_and_keeper_checks(root: Control, catalog) -> void:
	var talk = TalkPanel.new()
	root.add_child(talk)
	talk.build()
	var chosen: Array = []
	talk.goods_requested.connect(func() -> void: chosen.append(true))
	talk.open_talk(catalog.seller(), "")
	check(talk.is_open(), "talk panel opens")
	check((talk.get("_name") as Label).text == str(catalog.seller().get("name", "")), "talk panel shows the seller")
	(talk.get("_goods") as Button).emit_signal("pressed")
	check(chosen == [true], "goods choice reaches the host")
	talk.close_talk()
	check(not talk.is_open(), "talk panel closes")
	var keeper = Keeper.new()
	root.add_child(keeper)
	var placed: Dictionary = keeper.configure(Vector3(1, 0, 2), 0.0, "REBUILD-VISUAL-gun_shop-001")
	check(bool(placed.get("ok", false)), "keeper stands up: " + str(placed))
	check(keeper.head_world().y > 1.5, "keeper head is above the ground")
	check(keeper.in_talk_range(Vector3(1, 0, 3.0), 3.5), "keeper answers from the doorstep")
	check(not keeper.in_talk_range(Vector3(40, 0, 40), 3.5), "keeper ignores the far side of the map")

## The vest is measured against the real hero model: it must sit on the torso, be a
## torso-sized share of the body and travel with the chest bone.
func _vest_fit_checks(root: Control) -> Dictionary:
	var scene: PackedScene = load("res://assets/hero.glb")
	check(scene != null, "hero model loads for the vest check")
	if scene == null:
		return {}
	var hero: Node3D = scene.instantiate()
	root.add_child(hero)
	var rigs: Array = hero.find_children("*", "Skeleton3D", true, false)
	check(not rigs.is_empty(), "hero model has a skeleton")
	if rigs.is_empty():
		return {}
	var rig: Skeleton3D = rigs[0]
	check(rig.find_bone("chest") >= 0, "hero rig has the chest bone")
	var visual = ArmorVisual.new()
	root.add_child(visual)
	var placed: Dictionary = visual.configure(hero, rig)
	check(bool(placed.get("ok", false)), "vest attaches to the chest bone: " + str(placed))
	var drawn: Dictionary = visual.set_vest("tactical_vest", "#4a4433", false)
	check(bool(drawn.get("ok", false)), "vest becomes visible: " + str(drawn))
	await process_frame
	await process_frame
	var model: AABB = _mesh_box(hero)
	var vest_mesh: MeshInstance3D = visual.get("_mesh")
	check(vest_mesh != null, "vest mesh exists")
	var vest: AABB = _mesh_box(vest_mesh) if vest_mesh != null else AABB()
	if model.size.y <= 0.1 or vest.size.y <= 0.01:
		check(false, "vest and model bounds are measurable")
		return {"model": _aabb(model), "vest": _aabb(vest)}
	var ratio: float = (vest.get_center().y - model.position.y) / model.size.y
	var height_share: float = vest.size.y / model.size.y
	check(ratio > 0.35 and ratio < 0.85, "vest centre is on the torso (%.2f of height)" % ratio)
	check(height_share > 0.15 and height_share < 0.35, "vest height is a torso share (%.2f)" % height_share)
	check(vest.size.x <= model.size.x * 0.6, "vest is not wider than the model")
	check(absf(vest.get_center().x - model.get_center().x) <= model.size.x * 0.25, "vest is centred on the body")
	check(absf(vest.get_center().z - model.get_center().z) <= model.size.z * 0.6, "vest is not floating in front of the body")
	var before: Vector3 = vest.get_center()
	rig.set_bone_pose_position(rig.find_bone("chest"), rig.get_bone_pose_position(rig.find_bone("chest")) + Vector3(0, 0.5, 0))
	await process_frame
	await process_frame
	var after: Vector3 = _mesh_box(vest_mesh).get_center()
	check(after.distance_to(before) > 0.1, "vest follows the chest bone (%.2f m)" % after.distance_to(before))
	visual.clear_vest()
	check(not vest_mesh.visible, "vest can be taken off")
	return {
		"model": _aabb(model), "vest": _aabb(vest), "centre_ratio": ratio,
		"height_share": height_share, "follow_m": after.distance_to(before), "placement": placed
	}

## The inventory window shows the same cards as the Q arsenal, with the real state.
func _inventory_checks(root: Control, catalog, textures: Dictionary, wallet) -> void:
	var vest := "tactical_vest"
	var points: int = catalog.defense(vest)
	var bag = InventoryWindow.new()
	root.add_child(bag)
	bag.build(catalog, textures)
	bag.equip_requested.connect(func(item_id: String) -> void: _equips.append(item_id))
	bag.unequip_requested.connect(func() -> void: _unequips += 1)
	check((bag.get("_cards") as Dictionary).size() == catalog.item_count(), "inventory has a card per item")
	bag.open_inventory()
	check(bag.is_open(), "inventory opens")
	var stored := {"weapons": ["nagan"], "reserves": {"nagan": 24}, "ammo": {"ammo_magnum": {"owned_guns": 1, "total": 24, "full": false}}, "armor": {vest: {"qty": 1, "ap": points - 12, "max": points, "broken": false}}, "consumables": {"c4": 2}, "worn": ""}
	bag.refresh(stored, "ready")
	check((bag.get("_summary") as Label).text.contains(catalog.display_name("nagan")) or (bag.get("_summary") as Label).text.contains("оружие: 1"),
		"inventory summary counts the guns: '%s'" % (bag.get("_summary") as Label).text)
	var vest_detail: Label = bag.get("_cards")[vest]["detail"]
	check(vest_detail.text.contains("в запасе"), "inventory shows the stored vest: '%s'" % vest_detail.text)
	var wear_button: Button = bag.get("_cards")[vest]["action"]
	check(wear_button.visible and wear_button.text == "Надеть", "inventory offers wearing the vest: '%s'" % wear_button.text)
	_equips.clear()
	wear_button.emit_signal("pressed")
	check(_equips == [vest], "inventory wear reaches the host: " + str(_equips))
	var worn := {"weapons": ["nagan"], "reserves": {"nagan": 24}, "ammo": {"ammo_magnum": {"owned_guns": 1, "total": 24, "full": false}}, "armor": {vest: {"qty": 1, "ap": points - 12, "max": points, "broken": false}}, "consumables": {"c4": 2}, "worn": vest}
	bag.refresh(worn, "ready")
	var remove_button: Button = bag.get("_cards")[vest]["action"]
	check(remove_button.visible and remove_button.text == "Снять", "inventory offers taking the vest off: '%s'" % remove_button.text)
	_unequips = 0
	remove_button.emit_signal("pressed")
	check(_unequips == 1, "inventory take-off reaches the host")
	check((bag.get("_cards")["nagan"]["detail"] as Label).text.contains("Q"), "inventory points at Q for guns")
	check((bag.get("_cards")["nagan"]["detail"] as Label).text.contains("патроны"), "inventory shows the gun ammo: '%s'" % (bag.get("_cards")["nagan"]["detail"] as Label).text)
	check((bag.get("_cards") as Dictionary).has("ammo_magnum"), "inventory has ammo cards")
	check((bag.get("_cards")["c4"]["detail"] as Label).text.contains("2"), "inventory counts the C4")
	check(not (bag.get("_cards")["grenade"]["action"] as Button).visible, "inventory shows no action for consumables")
	bag.close_inventory()
	check(not bag.is_open(), "inventory closes")

func _mesh_box(node: Node) -> AABB:
	var instances: Array = []
	if node is MeshInstance3D:
		instances.append(node)
	instances.append_array(node.find_children("*", "MeshInstance3D", true, false))
	var box := AABB()
	var first := true
	for child: Node in instances:
		var mesh_instance: MeshInstance3D = child
		if mesh_instance.mesh == null:
			continue
		var world: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		box = world if first else box.merge(world)
		first = false
	return box

func _aabb(box: AABB) -> Dictionary:
	return {"min": [box.position.x, box.position.y, box.position.z], "size": [box.size.x, box.size.y, box.size.z]}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
