extends SceneTree

var checks:=0
var failures:Array[String]=[]

func check(value: bool,label: String)->void:
	checks+=1
	if not value: failures.append(label); push_error("RESOURCE_MODAL58 "+label)

func _initialize()->void: call_deferred("run")

func key_event(code: Key)->InputEventKey:
	var event:=InputEventKey.new(); event.pressed=true; event.physical_keycode=code; return event

func run()->void:
	var packed:PackedScene=load("res://scenes/castle.tscn")
	var scene:=packed.instantiate(); root.add_child(scene); current_scene=scene
	var deadline:=Time.get_ticks_msec()+240000
	while Time.get_ticks_msec()<deadline and scene.get("preview_ready")!=true: await process_frame
	var inventory:CanvasLayer=scene.get("preview_resource_inventory") as CanvasLayer
	var weapons:Node=scene.get("preview_weapons")
	var player:CharacterBody3D=scene.get("_player") as CharacterBody3D
	check(is_instance_valid(inventory) and is_instance_valid(weapons) and is_instance_valid(player),"live owners installed")
	# The castle continues installing horse/ship hosts for a few frames after preview_ready.
	# Measure locomotion only after their one-time spawn corrections have completed.
	for frame in 120: await physics_frame
	weapons.equip("sword")
	check(inventory.open_window(),"inventory opens")
	check(inventory.is_open() and not bool(player.get("_free_mouse_look")),"inventory owns visible cursor")
	check(weapons.controls_blocked(),"central controls blocked")
	var before:=Vector2(player.global_position.x,player.global_position.z)
	Input.action_press("preview_move_forward")
	for frame in 12: await physics_frame
	Input.action_release("preview_move_forward")
	var after:=Vector2(player.global_position.x,player.global_position.z)
	check(before.distance_to(after)<0.02,"W cannot move player while inventory is open")
	var attack:=InputEventMouseButton.new(); attack.button_index=MOUSE_BUTTON_LEFT; attack.pressed=true
	check(weapons.input_event(attack) and not bool(weapons.get("_held")),"attack is consumed without swing")
	var card:Button=inventory.get("_item_buttons").get("wood")
	card.pressed.emit()
	check(str(inventory.get("_detail_title").text).contains("Брёвна"),"mouse card selection shows details")
	for pickup in 4: inventory.add_resource("wood",1)
	check((inventory.get("_toast_panels") as Array).size()==4,"each pickup keeps its own compact notification")
	var right_click:=InputEventMouseButton.new(); right_click.button_index=MOUSE_BUTTON_RIGHT; right_click.pressed=true
	card.call("_gui_input",right_click)
	await process_frame
	var discard_popup:=inventory.get("_discard_popup") as PopupPanel
	var discard_slider:=inventory.get("_discard_slider") as HSlider
	check(discard_popup.visible and discard_slider.max_value==4.0,"RMB opens small discard menu beside resource")
	discard_slider.value=3
	(inventory.get("_discard_button") as Button).pressed.emit()
	check(inventory.count("wood")==1,"LMB discard action drops selected slider amount")
	await process_frame
	card=inventory.get("_item_buttons").get("wood")
	card.call("_gui_input",right_click)
	await process_frame
	check(discard_popup.visible,"discard popup can reopen for remaining resource")
	inventory.call("_input",key_event(KEY_Q))
	await process_frame
	check(not discard_popup.visible and not inventory.is_open() and bool(weapons.get("menu_open")),"Q switches directly from active discard popup to weapon inventory")
	weapons.set_menu(false)
	check(inventory.open_window(),"resource inventory reopens after weapon inventory")
	var close:Button=inventory.get("_window").find_child("CloseButton",true,false) as Button
	close.pressed.emit()
	check(not inventory.is_open() and bool(player.get("_free_mouse_look")) and not weapons.controls_blocked(),"cross closes and restores controls")
	before=Vector2(player.global_position.x,player.global_position.z)
	Input.action_press("preview_move_forward")
	for frame in 12: await physics_frame
	Input.action_release("preview_move_forward")
	after=Vector2(player.global_position.x,player.global_position.z)
	check(before.distance_to(after)>0.03,"movement returns immediately")
	check(inventory.open_window(),"inventory reopens")
	check(inventory.window_input(key_event(KEY_ESCAPE)) and not inventory.is_open(),"Escape closes instantly")
	check(inventory.open_window(),"inventory opens for B close")
	check(inventory.window_input(key_event(KEY_B)) and not inventory.is_open(),"B closes instantly")
	print("RESOURCE_MODAL58_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
