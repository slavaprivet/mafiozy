extends SceneTree
## Regression guard for the project rule "one change behind a flag, default behaviour
## unchanged". Without the shop's ownedIds option the arsenal must own every gun as
## before, and the additive ammo method must never create ownership or exceed the
## state contract. Run:
##   <godot> --headless --path <game> --script res://scripts/shop/tests/test_player_shop_defaults.gd
const Fire = preload("res://scripts/weapons/weapon_fire.gd")
const Inventory = preload("res://scripts/weapons/weapon_inventory.gd")
const Catalog = preload("res://scripts/shop/player_shop_catalog.gd")
const Backpack = preload("res://scripts/shop/player_shop_inventory.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var report := {}
	report["default_ownership"] = _default_ownership()
	report["ammo_bounds"] = _ammo_bounds()
	report["backpack_defaults"] = _backpack_defaults()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty(), "report": report}, "  "))
	quit(1 if not failures.is_empty() else 0)

## No options at all: the pre-shop behaviour, every firearm owned.
func _default_ownership() -> Dictionary:
	var stock = Inventory.new()
	var configured: Dictionary = stock.configure(Fire.new())
	check(bool(configured.get("ok", false)), "default arsenal configures: " + str(configured))
	var owned: Array = stock.get_owned_ids()
	check(owned.size() == Fire.ids().size(), "default owns every firearm: %d of %d" % [owned.size(), Fire.ids().size()])
	var missing: Array[String] = []
	for id: String in Fire.FIREARM_IDS:
		if not owned.has(id):
			missing.append(id)
	check(missing.is_empty(), "default knows all guns: " + str(missing))
	check(bool(stock.equip("rpg").get("ok", false)), "default can equip a heavy gun")
	check(str(stock.get_fire_state("rpg").get("weaponId", "")) == "rpg", "equipped state names the gun")
	check(bool(stock.equip("none").get("ok", false)), "hands can be emptied without owning anything")
	return {"owned": owned.size(), "firearms": Fire.ids().size()}

## The additive method is refused for anything not owned and clamped to the contract.
func _ammo_bounds() -> Dictionary:
	var stock = Inventory.new()
	check(bool(stock.configure(Fire.new()).get("ok", false)), "ammo fixture arsenal")
	var before: int = int(stock.get_fire_state("nagan").get("reserveAmmo", 0))
	var added: Dictionary = stock.add_reserve("nagan", 12)
	check(bool(added.get("ok", false)), "owned gun accepts ammo: " + str(added))
	check(int(stock.get_fire_state("nagan").get("reserveAmmo", 0)) == before + 12, "reserve grew by the box")
	check(int(added.get("added", 0)) == 12, "the receipt names what was added")
	check(str(stock.add_reserve("none", 5).get("reason", "")) == "not_owned", "hands cannot hold ammo")
	check(str(stock.add_reserve("not_a_gun", 5).get("reason", "")) == "not_owned", "unknown gun cannot hold ammo")
	check(str(stock.add_reserve("nagan", 0).get("reason", "")) == "rounds", "zero rounds is refused")
	check(str(stock.add_reserve("nagan", 100000).get("reason", "")) == "rounds", "absurd rounds is refused")
	var owned_before: int = stock.get_owned_ids().size()
	check(bool(stock.add_reserve("nagan", 9999).get("ok", false)), "reserve can be filled up to the cap")
	check(str(stock.add_reserve("nagan", 1).get("reason", "")) == "reserve_full", "full reserve is refused")
	check(stock.get_owned_ids().size() == owned_before, "ammo never changes ownership")
	check(int(stock.get_fire_state("nagan").get("reserveAmmo", 0)) == 9999, "reserve never passes the cap")
	return {"reserve": int(stock.get_fire_state("nagan").get("reserveAmmo", 0)), "owned": owned_before}

## The backpack starts empty and a bare chest absorbs nothing.
func _backpack_defaults() -> Dictionary:
	var catalog = Catalog.new()
	check(bool(catalog.open(Catalog.DEFAULT_PATH).get("ok", false)), "backpack fixture catalog")
	var bag = Backpack.new()
	check(bool(bag.configure(catalog).get("ok", false)), "backpack binds")
	check(bag.worn_armor() == "", "nothing is worn at the start")
	check(bag.count("c4") == 0 and bag.count("grenade") == 0, "backpack starts empty")
	var bare: Dictionary = bag.absorb(50)
	check(int(bare.get("absorbed", -1)) == 0 and int(bare.get("remaining", -1)) == 50, "a bare chest absorbs nothing")
	check(not bool(bag.equip("tactical_vest").get("ok", false)), "a vest that was not bought cannot be worn")
	return {"worn": bag.worn_armor(), "absorbed": int(bare.get("absorbed", -1))}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
