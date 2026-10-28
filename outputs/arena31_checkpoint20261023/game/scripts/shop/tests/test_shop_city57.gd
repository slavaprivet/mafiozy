extends SceneTree
## Full city receipt: real compact shop, cashier, purchase ownership, armor visual,
## ammo reserve and loaded card textures. Run with the ordinary 10-resident flags
## plus --city-player-shop=1, on the private shop candidate only.
var checks := 0
var failures: Array[String] = []
var output := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="): output = arg.trim_prefix("--qa-out=")
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _run() -> void:
	var scene = load("res://scenes/main_city.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	var deadline := Time.get_ticks_msec() + 115000
	while Time.get_ticks_msec() < deadline and not bool(scene.get("preview_ready")):
		await process_frame
	var shop = scene.get("player_shop")
	_check(bool(scene.get("preview_ready")), "city ready")
	_check(is_instance_valid(shop) and bool(shop.get("ready_for_use")), "shop module ready")
	if not is_instance_valid(shop):
		_finish({"reason":"shop_missing"}); return
	for tick in 10: await physics_frame
	var sites_host = scene.get("preview_service_sites29")
	var site = null
	if is_instance_valid(sites_host):
		for value: Variant in sites_host.current_sites():
			if str(value.get("source_id")) == "VENUE29-SHOP-002": site = value; break
	_check(is_instance_valid(site), "weapon shop compact site built")
	if not is_instance_valid(site):
		_finish({"reason":"site_missing"}); return
	var door_distance := INF
	var owned_pieces := 0
	if is_instance_valid(site):
		door_distance = scene._player.global_position.distance_to(site.to_global(Vector3(0, 0, 3.5)))
		owned_pieces = site.pieces.size()
		_check(door_distance <= 20.0, "shop door near actual Palazzo hero spawn")
		_check(owned_pieces >= 40 and is_instance_valid(site._door), "destructible sections and physical door")
		_check(bool(site.get_meta("player_weapon_shop", false)), "weapon-shop signage and rack")
	var cashiers: Array = shop.get("_keepers")
	_check(cashiers.size() == 1 and is_instance_valid(cashiers[0]), "exactly one cashier")
	if cashiers.size() != 1 or not is_instance_valid(cashiers[0]):
		_finish({"reason":"cashier_missing"}); return
	var behind_counter := false
	if cashiers.size() == 1 and is_instance_valid(cashiers[0]) and is_instance_valid(site):
		behind_counter = site.to_local(cashiers[0].global_position).z < -1.7
	_check(behind_counter, "cashier behind counter")
	var pictures := 0
	for kind: String in ["weapon", "ammo"]:
		for card: Variant in shop.catalog.items_of(kind):
			var id: String = str((card as Dictionary).get("id", ""))
			var texture: Texture2D = shop.texture_for(id)
			if texture != null and texture.get_size().x > 0 and texture.get_size().y > 0: pictures += 1
	_check(pictures == shop.catalog.items_of("weapon").size() + shop.catalog.items_of("ammo").size(), "every gun and ammo picture loads")
	var cash_before: int = shop.wallet.cash()
	shop.call("_open_goods")
	var goods = shop.get("_goods")
	_check(goods.is_open(), "goods window opens with live cashier")
	if not goods.is_open():
		_finish({"reason":"cashier_unavailable"}); return
	var vest_id := "tactical_vest"
	var vest_price: int = shop.catalog.price(vest_id)
	goods.select(vest_id); goods.activate_selected()
	var bought_vest: Dictionary = shop.get("_last_result")
	_check(bool(bought_vest.get("ok", false)), "vest purchase succeeds")
	_check(shop.wallet.cash() == cash_before - vest_price, "vest charges once")
	_check(shop.backpack.worn_armor() == vest_id, "bought vest auto-equipped")
	var armor_mesh = shop.armor_visual.get("_mesh") if is_instance_valid(shop.armor_visual) else null
	_check(is_instance_valid(armor_mesh) and armor_mesh.visible, "vest visible on hero")
	var second: Dictionary = shop.state.purchase("bulletproof", "city57-vest-second")
	_check(str(second.get("reason", "")) == "already_owned" and shop.wallet.cash() == cash_before - vest_price, "second intact vest blocked without charge")
	var inventory = scene.preview_weapons.inventory
	var reserve_before: int = int((inventory.get_fire_state("nagan") as Dictionary).get("reserveAmmo", 0))
	var ammo_price: int = shop.catalog.price("ammo_magnum")
	goods.select("ammo_magnum"); goods.activate_selected()
	var bought_ammo: Dictionary = shop.get("_last_result")
	var reserve_after: int = int((inventory.get_fire_state("nagan") as Dictionary).get("reserveAmmo", 0))
	_check(bool(bought_ammo.get("ok", false)), "ammo purchase succeeds")
	_check(reserve_after == reserve_before + shop.catalog.rounds("ammo_magnum"), "ammo reaches owned gun reserve")
	_check(shop.wallet.cash() == cash_before - vest_price - ammo_price, "ammo charges exact price")
	var card_picture: TextureRect = goods.get("_card_picture")
	_check(card_picture.visible and card_picture.texture is Texture2D, "ammo picture visible in goods card")
	for id: String in ["grenade","molotov","c4"]:
		goods.select(id); goods.activate_selected()
		var purchase: Dictionary=shop.get("_last_result")
		_check(bool(purchase.get("ok",false)) and shop.backpack.count(id)==1,"consumable purchased: "+id)
	shop.close_all()
	var throwables = scene.get("player_throwables")
	_check(is_instance_valid(throwables) and bool(throwables.snapshot().get("ready",false)),"throw equipment connected")
	if not is_instance_valid(throwables):
		_finish({"reason":"throw_equipment_missing"}); return
	var selected: Dictionary=throwables.select("grenade")
	_check(bool(selected.get("ok",false)),"owned grenade selectable in Q equipment")
	var right_down:=InputEventMouseButton.new(); right_down.button_index=MOUSE_BUTTON_RIGHT; right_down.pressed=true
	var right_up:=InputEventMouseButton.new(); right_up.button_index=MOUSE_BUTTON_RIGHT; right_up.pressed=false
	throwables._input(right_down)
	_check(bool(throwables.snapshot().get("aiming",false)),"right button begins trajectory aim")
	throwables._input(right_up)
	_check(not bool(throwables.snapshot().get("aiming",true)) and shop.backpack.count("grenade")==1,"right release cancels without spending")
	var grenade_path: Dictionary=throwables._trajectory()
	_check(not grenade_path.is_empty() and grenade_path.points.size()>2,"grenade ballistic path computed")
	# Fire real consumed projectiles into opposite intact side walls. The earlier
	# trajectory assertion checks the player's camera preview independently.
	throwables._launch({"start":site.to_global(Vector3(4.8,1.55,0)),"velocity":site.global_basis*Vector3(-4,0,0)})
	var grenade_launched_at:=Time.get_ticks_msec()
	_check(shop.backpack.count("grenade")==0,"grenade consumed once on throw")
	var wait_until:=Time.get_ticks_msec()+4000
	while Time.get_ticks_msec()<wait_until and int(throwables.snapshot().get("impacts",0))<1: await physics_frame
	_check(int(throwables.snapshot().get("impacts",0))>=1,"grenade has physical impact and area blast")
	_check(int(throwables.snapshot().get("bounces",0))>=1 and Time.get_ticks_msec()-grenade_launched_at>=2200,"grenade bounces and burns its fuse before detonation")
	_check(int((throwables.snapshot().get("last_area",{}) as Dictionary).get("released",0))>0,"grenade releases physical shop sections")
	selected=throwables.select("molotov")
	_check(bool(selected.get("ok",false)),"owned Molotov selectable")
	var molotov_path: Dictionary=throwables._trajectory()
	_check(not molotov_path.is_empty(),"Molotov ballistic path computed")
	throwables._launch({"start":site.to_global(Vector3(-5.15,1.55,0)),"velocity":site.global_basis*Vector3(8,0,0)})
	_check(shop.backpack.count("molotov")==0,"Molotov consumed once on throw")
	wait_until=Time.get_ticks_msec()+4000
	while Time.get_ticks_msec()<wait_until and int(throwables.snapshot().get("impacts",0))<2: await physics_frame
	_check(int(throwables.snapshot().get("fire_fields",0))>=1,"Molotov leaves a fire area")
	_check(int(throwables.snapshot().get("molotov_shatters",0))>=1,"bottle shatters on first contact")
	var visual_budget: Dictionary=throwables.snapshot()
	_check(int(visual_budget.projectiles.get("active",-1))==0 and int(visual_budget.fire_fx.get("active",-1))==1,"projectile pool returned and one fire field active")
	_check(int(visual_budget.projectiles.get("per_throw_node_allocations",-1))==0 and int(visual_budget.fire_fx.get("per_impact_node_allocations",-1))==0,"throws and fire hits reuse visual objects")
	_check(int(visual_budget.fire_fx.get("maximum_draw_batches",0))==12 and int(visual_budget.fire_fx.get("shadowed_lights",-1))==0,"fire draw and lighting budget bounded")
	var explosion_fx: Dictionary=scene.preview_c4_blast._fx45.snapshot()
	_check(int(explosion_fx.get("per_blast_node_or_mesh_allocations",-1))==0 and int(explosion_fx.get("capacity",0))==6,"grenade reuses pooled Palazzo blast effects")
	_check(int((throwables.snapshot().get("last_area",{}) as Dictionary).get("released",0))>0,"Molotov releases physical shop sections")
	_check(shop.backpack.count("c4")==1 and bool(shop.get("_c4_bound")),"bought C4 feeds native placement equipment")
	_finish({"door_distance_m":door_distance,"owned_sections":owned_pieces,"cashiers":cashiers.size(),"cashier_behind_counter":behind_counter,"pictures":pictures,"vest_purchase":bought_vest,"second_vest":second,"ammo_purchase":bought_ammo,"reserve_before":reserve_before,"reserve_after":reserve_after,"throwables":throwables.snapshot(),"cash_after":shop.wallet.cash()})

func _finish(detail: Dictionary) -> void:
	var report := {"ok":failures.is_empty(),"checks":checks,"failures":failures,"detail":detail}
	print("SHOP_CITY57 ", JSON.stringify(report))
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("SHOP_CITY57.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
