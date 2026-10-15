extends SceneTree
var _checks:Dictionary={}
var _out:=""
var _overlay:=false
var _held:Script
func _initialize()->void:_start.call_deferred()
func _start()->void:
	await create_timer(3.0).timeout
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):_out=arg.trim_prefix("--qa-out=")
		if arg=="--guard-overlay=1":_overlay=true
	assert(not _out.is_empty())
	var here:String=get_script().resource_path.get_base_dir()
	if _overlay:
		var pins:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(here.path_join("PATCH.json")))
		var relative: String="scripts/shop/player_shop_host.gd"
		assert(FileAccess.get_sha256("res://"+relative)==pins[relative].base_sha256)
		var path:String=here.path_join("patch").path_join(relative)
		assert(FileAccess.get_sha256(path)==pins[relative].candidate_sha256)
		var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(path);script.take_over_path("res://"+relative)
		assert(script.reload()==OK and script.can_instantiate());_held=script
	var scene:Node=load("res://scenes/main_city.tscn").instantiate();root.add_child(scene);current_scene=scene
	var deadline:int=Time.get_ticks_msec()+115000
	while Time.get_ticks_msec()<deadline and not bool(scene.get("preview_ready")):await process_frame
	_checks["city_ready"]=bool(scene.get("preview_ready"))
	var shop:Node=scene.get("player_shop")
	_checks["shop_ready"]=is_instance_valid(shop) and bool(shop.get("ready_for_use"))
	if not _checks.shop_ready:_finish({"reason":"shop_missing"});return
	for tick in 12:await physics_frame
	var keepers:Array=shop.get("_keepers")
	_checks["one_actual_cashier"]=keepers.size()==1 and is_instance_valid(keepers[0]) and keepers[0].available29()
	if not _checks.one_actual_cashier:_finish({"reason":"cashier_missing"});return
	shop._open_goods();var goods:Control=shop._goods
	_checks["modal_open_with_live_cashier"]=goods.is_open()
	var before:int=shop.wallet.cash();var ammo_before:int=scene.preview_weapons.inventory.get_fire_state("nagan").reserveAmmo
	goods.select("ammo_magnum");goods.activate_selected()
	_checks["live_sale_positive"]=shop._last_result.get("ok",false) and shop.wallet.cash()==before-shop.catalog.price("ammo_magnum") and scene.preview_weapons.inventory.get_fire_state("nagan").reserveAmmo==ammo_before+shop.catalog.rounds("ammo_magnum")
	goods.select("grenade")
	var frame:int=Engine.get_physics_frames();var cash:int=shop.wallet.cash();var quantity:int=shop.backpack.count("grenade")
	var receipt_count:int=shop.state.snapshot().purchases
	# No await, no process tick, no synthetic money write between invalidation and buy.
	keepers[0].disable29()
	_checks["cashier_invalid_now"]=not keepers[0].available29()
	_checks["modal_still_open_before_poll"]=goods.is_open()
	goods.activate_selected()
	var answer:Dictionary=shop._last_result.duplicate(true)
	_checks["same_physics_frame"]=Engine.get_physics_frames()==frame
	_checks["stale_store_refused"]=not answer.get("ok",true) and answer.get("reason","")=="store_unavailable"
	_checks["no_cash_debit"]=shop.wallet.cash()==cash
	_checks["no_inventory_delivery"]=shop.backpack.count("grenade")==quantity
	_checks["no_new_purchase_receipt"]=shop.state.snapshot().purchases==receipt_count
	for tick in 2:await process_frame
	_checks["modal_closes_on_poll"]=not goods.is_open()
	var sandbox:Dictionary=_sandbox_positive()
	_checks["standalone_sandbox_transaction_preserved"]=sandbox.ok
	_finish({"answer":answer,"cash_before":cash,"cash_after":shop.wallet.cash(),"quantity_before":quantity,"quantity_after":shop.backpack.count("grenade"),"purchase_receipts_before":receipt_count,"purchase_receipts_after":shop.state.snapshot().purchases,"sandbox":sandbox})
class SandboxWorld58 extends Node3D:
	var preview_service_sites29:Node
func _sandbox_positive()->Dictionary:
	var world:=SandboxWorld58.new();root.add_child(world)
	var host:Node=load("res://scripts/shop/player_shop_host.gd").new()
	host.scene=world;host.catalog=load("res://scripts/shop/player_shop_catalog.gd").new();host.catalog.open()
	host.backpack=load("res://scripts/shop/player_shop_inventory.gd").new();host.backpack.configure(host.catalog)
	host.wallet=load("res://scripts/shop/player_shop_wallet.gd").new();host.wallet.configure(host.catalog.starting_cash())
	var state:RefCounted=load("res://scripts/shop/player_shop_state.gd").new()
	state.configure(host.catalog,host.wallet,Callable(host,"_available"),Callable(host,"_deliver"))
	var cash:int=host.wallet.cash();var answer:Dictionary=state.purchase("grenade","sandbox-guard58")
	var result:Dictionary={"ok":answer.get("ok",false) and host.wallet.cash()==cash-host.catalog.price("grenade") and host.backpack.count("grenade")==1,"answer":answer}
	host.free();world.queue_free();return result
func _finish(detail:Dictionary)->void:
	var report:Dictionary={"passed":not _checks.values().has(false),"checks":_checks,"detail":detail,"overlay":_overlay,"scope":"Actual city cashier lifecycle invalidated synchronously between live modal-open and real goods activation; isolated sandbox transaction uses real catalog/wallet/backpack ports."}
	var file=FileAccess.open(_out.path_join("GUARD58.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("GUARD58 ",JSON.stringify({"passed":report.passed,"checks":_checks,"overlay":_overlay}))
	quit(0 if report.passed else 2)
