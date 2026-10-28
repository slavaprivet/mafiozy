extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=true; return event
func mouse(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; return event
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.preview_residents_enabled=false; scene.preview_weapons_enabled=true
	root.add_child(scene)
	while not scene.preview_ready: await physics_frame
	var p: CharacterBody3D = scene._player
	var weapons: Node = scene.preview_weapons
	check(is_instance_valid(weapons),"actual main weapon installed")
	if not is_instance_valid(weapons): print("WEAPON_SCENE ",JSON.stringify({"checks":checks,"failures":failures})); quit(1); return
	check(not weapons.equip("ak74").ok,"inactive cannot equip")
	p._unhandled_input(mouse(true)); p._unhandled_input(mouse(false))
	check(weapons.shots_count==0,"capture click does not shoot")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	check(weapons.equip("nagan").ok,"direct Nagan equip")
	var nagan_uid: String=weapons.inventory.get_item_uid("nagan")
	var nagan_state: Dictionary=weapons.fire_state.duplicate(true)
	check(weapons.equip("tt_pistol").ok,"direct TT switch")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and p._free_mouse_look,"direct equip preserves caller pointer mode")
	check(weapons.inventory.get_item_uid("nagan")==nagan_uid and weapons.inventory.get_fire_state("nagan")==nagan_state,"direct switch retains UID and ammo")
	p._unhandled_input(key(KEY_Q))
	p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not weapons.menu_open and not p._free_mouse_look and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"blur closes arsenal and releases control")
	check(not weapons.equip("tt_pistol").ok,"blurred equip remains blocked")
	p._unhandled_input(mouse(true)); p._unhandled_input(mouse(false))
	check(weapons.shots_count==0,"armed reacquire click does not shoot")
	p._unhandled_input(key(KEY_Q))
	check(weapons.menu_open,"Q opens actual arsenal")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"arsenal cursor free")
	check(not p._request_preview_jump(Time.get_ticks_msec()),"menu blocks jump")
	check(weapons.equip("ak74").ok,"AK equip through inventory and actual model")
	check(not weapons.menu_open,"selection closes arsenal")
	# Headless DisplayServer always reports VISIBLE; native capture is LIVE-only.
	if DisplayServer.get_name()!="headless": check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"real menu selection captures pointer")
	for i in 5: await physics_frame
	check(weapons.last_muzzle.get("ok",false),"actual current muzzle")
	check(weapons.last_muzzle.get("pose_revision")==p._pose_revision,"muzzle matches latest writer")
	var ammo: int = int(weapons.fire_state.magazine)
	p._unhandled_input(mouse(true))
	for i in 24: await physics_frame
	p._unhandled_input(mouse(false))
	check(weapons.shots_count>1,"held AK automatic fire")
	check(int(weapons.fire_state.magazine)==ammo-weapons.shots_count,"every emitted shot consumes exactly one round")
	check(scene.preview_melee._source.snapshot().attackSeq==0,"gun input never triggers melee")
	p._unhandled_input(key(KEY_R)); await physics_frame; await physics_frame
	check(float(weapons.fire_state.reloadRemaining)>0,"R starts original reload")
	var total: int = int(weapons.fire_state.magazine+weapons.fire_state.reserveAmmo)
	for i in 220: await physics_frame
	check(float(weapons.fire_state.reloadRemaining)==0,"reload completes")
	check(int(weapons.fire_state.magazine+weapons.fire_state.reserveAmmo)==total,"reload conserves finite ammo")
	p._unhandled_input(key(KEY_ESCAPE))
	check(not p._free_mouse_look,"Escape still releases controls")
	var shots: int = weapons.shots_count
	p._unhandled_input(mouse(true)); p._unhandled_input(mouse(false))
	for i in 12: await physics_frame
	check(weapons.shots_count==shots,"reacquire click cannot fire")
	p.set_preview_pose_authority(&"vehicle",true)
	check(not weapons.presentation.current_muzzle().ok,"vehicle removes onfoot muzzle")
	p.set_preview_pose_authority(&"on_foot",true)
	check(weapons.equip("tt_pistol").ok,"new onfoot lifetime can equip")
	for i in 5: await physics_frame
	p._unhandled_input(mouse(true))
	for i in 70: await physics_frame
	p._unhandled_input(mouse(false))
	check(weapons.shots_count==shots+1,"semi automatic fires once per hold")
	check(weapons.equip("none").ok,"unequip through inventory")
	check(not weapons.presentation.current_muzzle().ok,"unarmed cannot retain muzzle")
	scene.free()
	await process_frame
	print("WEAPON_SCENE ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
