extends SceneTree
## Headless receipt for the local player shop: catalog, wallet, backpack and the
## purchase transaction. Pure modules only (the real fire port, the real weapon
## inventory, the real catalog) — no city scene, no renderer, no player. Run:
##   <godot> --headless --path <game> --script res://scripts/shop/tests/test_player_shop.gd
const Catalog = preload("res://scripts/shop/player_shop_catalog.gd")
const Wallet = preload("res://scripts/shop/player_shop_wallet.gd")
const Purchase = preload("res://scripts/shop/player_shop_state.gd")
const Backpack = preload("res://scripts/shop/player_shop_inventory.gd")
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
const Inventory = preload("res://scripts/weapons/weapon_inventory.gd")
const BAD_CATALOG := "user://player_shop_bad_catalog.json"
var checks := 0
var failures: Array[String] = []
var _arsenal
var _backpack

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var report := {}
	report["catalog"] = _catalog_checks()
	report["wallet"] = _wallet_checks()
	report["backpack"] = _backpack_checks()
	report["purchase"] = _purchase_checks()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty(), "report": report}, "  "))
	quit(1 if not failures.is_empty() else 0)

func _catalog_checks() -> Dictionary:
	var catalog = Catalog.new()
	var opened: Dictionary = catalog.open(Catalog.DEFAULT_PATH)
	check(bool(opened.get("ok", false)), "catalog opens: " + str(opened))
	catalog.attach_labels({"nagan": "Наган"})
	check(catalog.item_count() >= 7, "catalog sells at least the seven 3D guns")
	check(catalog.starting_cash() > 0, "catalog declares starting cash")
	check(not str(catalog.seller().get("name", "")).is_empty(), "catalog declares a seller")
	check(not catalog.starter_ids().is_empty(), "catalog declares a starter weapon")
	var unknown: Array[String] = []
	var unpriced: Array[String] = []
	for value: Variant in catalog.items_of("weapon"):
		var item: Dictionary = value
		var weapon := str(item.get("id", ""))
		if not Fire.FIREARM_IDS.has(weapon):
			unknown.append(weapon)
		if int(item.get("price", 0)) <= 0:
			unpriced.append(weapon)
	check(unknown.is_empty(), "every sold id is a real firearm: " + str(unknown))
	check(unpriced.is_empty(), "every sold weapon has a price: " + str(unpriced))
	for weapon: String in Fire.FIREARM_IDS:
		check(catalog.has(weapon), "all guns are purchasable: " + weapon)
	check(catalog.items_of("ammo").size() >= 4, "ammo is on sale")
	for card: Variant in catalog.items_of("ammo"):
		var ammo_id := str((card as Dictionary).get("id", ""))
		var guns_ok := true
		for gun: String in catalog.ammo_weapons(ammo_id):
			if not Fire.FIREARM_IDS.has(gun):
				guns_ok = false
		check(catalog.rounds(ammo_id) > 0 and not catalog.caliber(ammo_id).is_empty(), "ammo declares rounds and caliber: " + ammo_id)
		check(guns_ok and not catalog.ammo_weapons(ammo_id).is_empty(), "ammo feeds real guns: " + ammo_id)
	check(catalog.items_of("armor").size() >= 4, "armor is on sale")
	check(catalog.items_of("consumable").size() >= 4, "consumables are on sale")
	for wanted: String in ["c4", "grenade", "molotov"]:
		check(catalog.has(wanted) and catalog.kind(wanted) == "consumable", "consumable on sale: " + wanted)
		check(catalog.limit(wanted) > 0, "consumable carries a limit: " + wanted)
	var vest_ok := true
	for card: Variant in catalog.items_of("armor"):
		if catalog.defense(str((card as Dictionary).get("id", ""))) <= 0:
			vest_ok = false
	check(vest_ok, "every vest declares armor points")
	check(catalog.tabs().size() == 4, "four sections are offered: " + str(catalog.tabs().size()))
	check(not catalog.stats("nagan").is_empty(), "card stats come from the real fire profile")
	check(catalog.stats("tactical_vest").contains("поверх одежды"), "armor card says it goes over the clothes")
	check(catalog.display_name("nagan") != "nagan", "card names come from the weapon host labels")
	var bad = Catalog.new()
	var file := FileAccess.open(BAD_CATALOG, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": "wrong", "weapons": []}))
	file.close()
	var rejected: Dictionary = bad.open(BAD_CATALOG)
	check(not bool(rejected.get("ok", false)) and str(rejected.get("reason", "")) == "catalog_schema", "wrong schema is refused")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BAD_CATALOG))
	return {
		"items": catalog.item_count(),
		"weapons": catalog.items_of("weapon").size(),
		"armor": catalog.items_of("armor").size(),
		"consumables": catalog.items_of("consumable").size(),
		"skipped": catalog.warnings(),
		"starter": catalog.starter_ids()
	}

func _wallet_checks() -> Dictionary:
	var wallet = Wallet.new()
	check(bool(wallet.configure(1000).get("ok", false)), "wallet accepts starting cash")
	check(wallet.cash() == 1000, "wallet keeps starting cash")
	check(not bool(wallet.spend(1200).get("ok", false)), "wallet refuses overspend")
	check(wallet.cash() == 1000, "refused overspend keeps cash")
	check(bool(wallet.spend(400).get("ok", false)) and wallet.cash() == 600, "wallet debits the exact price")
	check(bool(wallet.grant(400).get("ok", false)) and wallet.cash() == 1000, "wallet can return a refund")
	check(not bool(wallet.spend(0).get("ok", false)), "wallet refuses a zero price")
	check(not bool(Wallet.new().configure(-1).get("ok", false)), "wallet refuses negative cash")
	return wallet.snapshot()

func _backpack_checks() -> Dictionary:
	var catalog = Catalog.new()
	check(bool(catalog.open(Catalog.DEFAULT_PATH).get("ok", false)), "backpack fixture catalog")
	var bag = Backpack.new()
	check(bool(bag.configure(catalog).get("ok", false)), "backpack binds to the catalog")
	check(bag.count("c4") == 0, "backpack starts empty")
	check(bool(bag.add("grenade", 2).get("ok", false)) and bag.count("grenade") == 2, "grenades are counted")
	check(bool(bag.take("grenade", 1).get("ok", false)) and bag.count("grenade") == 1, "grenades are spent")
	check(not bool(bag.take("grenade", 5).get("ok", false)), "backpack refuses to spend more than it holds")
	var grenade_limit: int = catalog.limit("grenade")
	bag.add("grenade", grenade_limit - 1)
	check(bag.count("grenade") == grenade_limit, "backpack reaches the carry limit")
	check(str(bag.add("grenade", 1).get("reason", "")) == "limit_reached", "backpack refuses above the limit")
	var vest := str((catalog.items_of("armor")[0] as Dictionary).get("id", ""))
	var points: int = catalog.defense(vest)
	check(bool(bag.grant_armor(vest).get("ok", false)), "vest is granted")
	check(not bool(bag.grant_armor(vest).get("ok", false)), "the same vest is not granted twice")
	var second_vest := str((catalog.items_of("armor")[1] as Dictionary).get("id", ""))
	check(str(bag.grant_armor(second_vest).get("reason", "")) == "already_owned", "a second intact vest cannot be owned")
	check(bool(bag.equip(vest).get("ok", false)) and bag.worn_armor() == vest, "vest is worn")
	var hit: Dictionary = bag.absorb(points)
	check(int(hit.get("absorbed", 0)) == points and int(hit.get("armor_left", -1)) == 0, "vest takes the hit and breaks")
	check(bool(hit.get("broken", false)), "broken vest is marked broken")
	check(int(bag.absorb(12).get("absorbed", -1)) == 0, "a broken vest absorbs nothing")
	check(bool(bag.grant_armor(vest).get("ok", false)), "a broken vest can be bought again")
	check(int(bag.armor_state(vest).get("ap", 0)) == points, "re-bought vest restores its points")
	var worn_hit: Dictionary = bag.absorb(5)
	check(int(worn_hit.get("absorbed", 0)) == 5 and int(worn_hit.get("remaining", -1)) == 0, "worn vest meets damage first")
	check(int(bag.armor_state(vest).get("ap", 0)) == points - 5, "vest loses exactly what it took")
	return bag.snapshot()

func _purchase_checks() -> Dictionary:
	var catalog = Catalog.new()
	check(bool(catalog.open(Catalog.DEFAULT_PATH).get("ok", false)), "purchase fixture catalog")
	var wallet = Wallet.new()
	wallet.configure(catalog.starting_cash())
	_arsenal = Inventory.new()
	var configured: Dictionary = _arsenal.configure(Fire.new(), {"ownedIds": catalog.starter_ids()})
	check(bool(configured.get("ok", false)), "arsenal accepts the starter set: " + str(configured))
	_backpack = Backpack.new()
	check(bool(_backpack.configure(catalog).get("ok", false)), "backpack binds")
	var module = Purchase.new()
	var wired: Dictionary = module.configure(catalog, wallet, Callable(self, "_available"), Callable(self, "_deliver"))
	check(bool(wired.get("ok", false)), "purchase module binds: " + str(wired))
	var start: int = wallet.cash()
	var c4_price_for_fill := 0

	# ── weapon ──────────────────────────────────────────────────────────────
	var cheap_price: int = catalog.price("tt_pistol")
	var cheap: Dictionary = module.purchase("tt_pistol", "receipt-cheap")
	check(bool(cheap.get("ok", false)), "cheap gun buys: " + str(cheap))
	check(wallet.cash() == start - cheap_price, "exact gun price is deducted")
	check(_arsenal.get_owned_ids().has("tt_pistol"), "bought gun reaches the arsenal")
	var repeated: Dictionary = module.purchase("tt_pistol", "receipt-cheap")
	check(bool(repeated.get("ok", false)) and bool(repeated.get("replayed", false)), "same receipt id replays instead of charging")
	check(wallet.cash() == start - cheap_price, "replayed receipt does not charge twice")
	var again: Dictionary = module.purchase("tt_pistol", "receipt-other")
	check(str(again.get("reason", "")) == "already_owned", "owned gun is refused")
	var poor: Dictionary = module.purchase("rpg", "receipt-rpg")
	check(str(poor.get("reason", "")) == "cash_insufficient", "expensive gun needs money: " + str(poor))
	check(wallet.cash() == start - cheap_price, "refused gun purchases do not charge")

	# ── armor ───────────────────────────────────────────────────────────────
	var vest := "tactical_vest"
	var vest_price: int = catalog.price(vest)
	var vest_points: int = catalog.defense(vest)
	var worn: Dictionary = module.purchase(vest, "receipt-vest")
	check(bool(worn.get("ok", false)), "vest buys: " + str(worn))
	check(wallet.cash() == start - cheap_price - vest_price, "vest price is deducted")
	check(_backpack.worn_armor() == vest, "bought vest is worn over the clothes")
	check(int(_backpack.worn_state().get("ap", 0)) == vest_points, "worn vest starts at full armor")
	var vest_again: Dictionary = module.purchase(vest, "receipt-vest-2")
	check(str(vest_again.get("reason", "")) == "already_owned", "the same vest is not sold twice")
	var other_vest: Dictionary = module.purchase("bulletproof", "receipt-vest-other")
	check(str(other_vest.get("reason", "")) == "already_owned", "another intact vest is not sold")
	check(wallet.cash() == start - cheap_price - vest_price, "refused vest purchase does not charge")

	# ── consumables ─────────────────────────────────────────────────────────
	var c4_price: int = catalog.price("c4")
	var c4_limit: int = catalog.limit("c4")
	c4_price_for_fill = 0
	var c4: Dictionary = module.purchase("c4", "receipt-c4")
	check(bool(c4.get("ok", false)) and _backpack.count("c4") == 1, "C4 buys into the backpack")
	check(wallet.cash() == start - cheap_price - vest_price - c4_price, "C4 price is deducted")
	for index in range(1, c4_limit):
		module.purchase("c4", "receipt-c4-%d" % index)
	check(_backpack.count("c4") == c4_limit, "C4 fills up to its limit")
	var over: Dictionary = module.purchase("c4", "receipt-c4-over")
	check(str(over.get("reason", "")) == "limit_reached", "C4 above the limit is refused: " + str(over))
	for wanted: String in ["grenade", "molotov"]:
		var bought: Dictionary = module.purchase(wanted, "receipt-" + wanted)
		check(bool(bought.get("ok", false)) and _backpack.count(wanted) == 1, wanted + " buys into the backpack")
	var missing: Dictionary = module.purchase("not_a_gun", "receipt-missing")
	check(str(missing.get("reason", "")) == "unknown_item", "unknown item is refused")

	# ── ammo ────────────────────────────────────────────────────────────────
	var box := "ammo_magnum"
	var before_ammo: int = int((_arsenal.get_fire_state("nagan") as Dictionary).get("reserveAmmo", 0))
	var cash_before_ammo: int = wallet.cash()
	var ammo_buy: Dictionary = module.purchase(box, "receipt-magnum")
	check(bool(ammo_buy.get("ok", false)), "ammo buys: " + str(ammo_buy))
	var after_ammo: int = int((_arsenal.get_fire_state("nagan") as Dictionary).get("reserveAmmo", 0))
	check(after_ammo == before_ammo + int(catalog.rounds(box)), "rounds land in the owned gun (%d -> %d)" % [before_ammo, after_ammo])
	check(wallet.cash() == cash_before_ammo - catalog.price(box), "ammo price is deducted once")
	# tt_pistol was bought earlier, so 9 mm is legitimate: use a caliber with no gun.
	var no_gun: Dictionary = module.purchase("ammo_rocket", "receipt-rocket")
	check(str(no_gun.get("reason", "")) == "no_weapon_for_caliber", "ammo without a matching gun is refused: " + str(no_gun))
	check(wallet.cash() == cash_before_ammo - catalog.price(box), "refused ammo does not charge")
	wallet.grant(1000000)
	for index in range(1, 600):
		if int((_arsenal.get_fire_state("nagan") as Dictionary).get("reserveAmmo", 0)) >= 9999:
			break
		if not bool(module.purchase(box, "receipt-fill-%d" % index).get("ok", false)):
			break
	check(int((_arsenal.get_fire_state("nagan") as Dictionary).get("reserveAmmo", 0)) >= 9999, "reserve reaches the cap")
	var full_box: Dictionary = module.purchase(box, "receipt-full")
	check(str(full_box.get("reason", "")) == "reserve_full", "full reserve is refused: " + str(full_box))

	# ── a refused delivery must return the money ────────────────────────────
	var refund_wallet = Wallet.new()
	refund_wallet.configure(1000)
	var refund_module = Purchase.new()
	refund_module.configure(catalog, refund_wallet, Callable(self, "_available_always"), Callable(self, "_deliver_refused"))
	var failed: Dictionary = refund_module.purchase("grenade", "receipt-refund")
	check(not bool(failed.get("ok", false)), "refused delivery fails the purchase")
	check(str(failed.get("reason", "")).begins_with("delivery_refused"), "refusal names the delivery: " + str(failed))
	check(refund_wallet.cash() == 1000, "refused delivery returns the exact price")
	return {
		"cash": wallet.cash(),
		"start_cash": start,
		"owned": _arsenal.get_owned_ids(),
		"backpack": _backpack.snapshot(),
		"module": module.snapshot(),
		"refund_cash": refund_wallet.cash()
	}

## Same policy the game host enforces. Plain comparisons instead of `match`: a
## non-literal pattern would bind a variable instead of comparing kinds.
func _available(item_id: String) -> Dictionary:
	var catalog = _catalog()
	var item_kind: String = catalog.kind(item_id)
	if item_kind == "weapon":
		if _arsenal.get_owned_ids().has(item_id):
			return {"ok": false, "reason": "already_owned"}
		return {"ok": true}
	if item_kind == "armor":
		for owned_id: String in _backpack.armor_ids():
			var row: Dictionary = _backpack.armor_state(owned_id)
			if int(row.get("qty", 0)) > 0 and not bool(row.get("broken", false)):
				return {"ok": false, "reason": "already_owned"}
		return {"ok": true}
	if item_kind == "ammo":
		var ammo_guns: Array = catalog.ammo_weapons(item_id)
		var ammo_owned := 0
		var ammo_full := 0
		for gun: String in ammo_guns:
			if not _arsenal.get_owned_ids().has(gun):
				continue
			ammo_owned += 1
			var gun_state: Variant = _arsenal.get_fire_state(gun)
			if gun_state is Dictionary and int((gun_state as Dictionary).get("reserveAmmo", 0)) >= 9999:
				ammo_full += 1
		if ammo_owned <= 0:
			return {"ok": false, "reason": "no_weapon_for_caliber"}
		if ammo_full == ammo_owned:
			return {"ok": false, "reason": "reserve_full"}
		return {"ok": true}
	if item_kind == "consumable":
		if _backpack.count(item_id) >= int(catalog.limit(item_id)):
			return {"ok": false, "reason": "limit_reached"}
		return {"ok": true}
	return {"ok": false, "reason": "unknown_kind"}

func _available_always(_item_id: String) -> Dictionary:
	return {"ok": true}

## Same two-step admission the game host uses for guns.
func _deliver(item_id: String, uid: String) -> Dictionary:
	var catalog = _catalog()
	var item_kind: String = catalog.kind(item_id)
	if item_kind == "armor":
		var granted: Dictionary = _backpack.grant_armor(item_id)
		if not granted.get("ok", false):
			return granted
		_backpack.equip(item_id)
		return granted
	if item_kind == "ammo":
		var loaded := 0
		var blocked := 0
		for gun: String in catalog.ammo_weapons(item_id):
			if not _arsenal.get_owned_ids().has(gun):
				continue
			var taken: Dictionary = _arsenal.add_reserve(gun, int(catalog.rounds(item_id)))
			if bool(taken.get("ok", false)):
				loaded += 1
			else:
				blocked += 1
		if loaded <= 0:
			return {"ok": false, "reason": "reserve_full" if blocked > 0 else "no_weapon_for_caliber"}
		return {"ok": true, "guns": loaded}
	if item_kind == "consumable":
		return _backpack.add(item_id, 1)
	var begun: Dictionary = _arsenal.begin_cargo_import({"uid": uid, "weaponId": item_id, "fireState": Fire.create_state(item_id)})
	if not begun.get("ok", false):
		return {"ok": false, "reason": str(begun.get("reason", "begin"))}
	var committed: Dictionary = _arsenal.commit_cargo_import(begun.get("token"))
	if not committed.get("ok", false):
		_arsenal.cancel_cargo_transfer(begun.get("token"))
		return {"ok": false, "reason": str(committed.get("reason", "commit"))}
	return {"ok": true, "owned": _arsenal.get_owned_ids()}

func _deliver_refused(_item_id: String, _uid: String) -> Dictionary:
	return {"ok": false, "reason": "test_refusal"}

var _catalog_cache

func _catalog() -> RefCounted:
	if _catalog_cache == null:
		_catalog_cache = Catalog.new()
		_catalog_cache.open(Catalog.DEFAULT_PATH)
	return _catalog_cache

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
