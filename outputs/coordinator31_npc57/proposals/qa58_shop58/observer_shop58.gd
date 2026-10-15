extends Node
## DSH_SHOP58 observer (read-only for residents): proves the purchase chain on the
## live unified build. It buys one weapon from the catalogue, then reads back both the
## shop snapshot and the arsenal inventory the Q window renders from.
var out_dir := ""
var _scene: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var deadline := Time.get_ticks_msec() + 115000
	var pop: Variant = null
	while Time.get_ticks_msec() < deadline:
		_scene = get_tree().current_scene
		pop = _scene.get("preview_population") if _scene != null else null
		if pop != null and _scene.get("preview_ready") == true and pop.get("city_ready") == true:
			break
		await get_tree().process_frame
	if _scene == null or pop == null:
		_finish({"ok": false, "reason": "city_not_ready"})
		return
	var shop: Variant = _scene.get("player_shop")
	var weapons: Variant = _scene.get("preview_weapons")
	if shop == null or not is_instance_valid(shop) or weapons == null or not is_instance_valid(weapons):
		_finish({"ok": false, "reason": "shop_or_arsenal_missing",
			"shop_present": shop != null, "arsenal_present": weapons != null})
		return
	# Let the shop finish its own configuration ticks.
	var ready_deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < ready_deadline and not bool(shop.get("ready_for_use")):
		await get_tree().process_frame
	var inventory: Variant = weapons.get("inventory")
	if inventory == null:
		_finish({"ok": false, "reason": "arsenal_inventory_missing"})
		return
	var before_owned: Array = inventory.call("get_owned_ids")
	var before_cash: int = int(_scene.get("player_shop").call("snapshot").get("cash", -1))
	var item := "tt_pistol"
	# The catalogue object owns the price; snapshot()/stock() do not expose it flat.
	var catalog: Variant = shop.get("catalog")
	var price: int = int(catalog.call("price", item)) if catalog != null and is_instance_valid(catalog) else -1
	print("DSH_SHOP58 stage=before owned=", JSON.stringify(before_owned), " cash=", before_cash, " item=", item)
	shop.call("_on_purchase", item)
	for tick in 12:
		await get_tree().process_frame
	var after_owned: Array = inventory.call("get_owned_ids")
	var after_snapshot: Dictionary = shop.call("snapshot")
	var after_cash: int = int(after_snapshot.get("cash", -1))
	var result: Dictionary = after_snapshot.get("last_result", {})
	var gained: bool = after_owned.has(item) and not before_owned.has(item)
	var paid: int = before_cash - after_cash
	var charged: bool = paid > 0 and (price < 0 or paid == price)
	_finish({"ok": gained and charged, "item": item, "price": price,
		"owned_before": before_owned, "owned_after": after_owned,
		"arsenal_owned_after": after_owned.duplicate(), "shop_owned_after": after_snapshot.get("owned", []),
		"cash_before": before_cash, "cash_after": after_cash, "charged": charged, "gained": gained,
		"purchase_ok": bool(result.get("ok", false)),
		"same_source_as_q": "arsenal inventory get_owned_ids is the list the Q window renders",
		"level": "component_callback_not_simulated_mouse"})


func _finish(value: Dictionary) -> void:
	print("DSH_SHOP58_RESULT ", JSON.stringify(value))
	if not out_dir.is_empty():
		var file := FileAccess.open(out_dir.path_join("SHOP58.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(value, "\t"))
			file.close()
	get_tree().quit(0 if value.get("ok", false) else 1)
