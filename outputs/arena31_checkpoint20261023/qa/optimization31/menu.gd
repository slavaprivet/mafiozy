extends SceneTree
var out: String
var checks:Dictionary={}
var rows:Array=[]
var scene:Node
var arsenal:Node
var host:Node
var bow:Node
var visual:=false
const IDS:=["sword","mace","axe","sledge","spear","bow","shield"]
func _initialize():run.call_deferred()
func ticks(n:int):
	for i in n:await physics_frame
func key(code:int):
	for down in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
		Input.parse_input_event(e);Input.flush_buffered_events()
		await ticks(1)
func state(id:String)->Dictionary:
	var node:Node3D=host.get("_sword")
	var actual:=str(arsenal.fire_state.get("weaponId","none"))
	var held:=false
	if id=="bow":
		node=bow.get("_bow");held=bool(bow.get("_selected")) and not bool(bow.get("_grounded"))
	elif id=="shield":
		node=host.get("_shield");held=bool(host.shield_status().worn)
		var dropped:Node=host.get("_shield_drop_body31")
		if not is_instance_valid(node) and is_instance_valid(dropped):
			for child:Node in dropped.get_children():
				if child is Node3D and not child is CollisionShape3D:node=child;break
		if held:actual="shield"
	else:
		held=bool(host.get("_selected")) and not bool(host.get("_sword_grounded")) and not bool(host.get("_unarmed")) and str(host.get("_weapon_id"))==id
	var visible_melee:Array=[]
	for weapon_id:String in host.get("_weapon_models"):
		var cached:Node3D=host.get("_weapon_models")[weapon_id]
		if is_instance_valid(cached) and cached.is_visible_in_tree() and not host.get("_ground_swords").has(cached):visible_melee.append(weapon_id)
	var ground_owned:=is_instance_valid(node) and node.get_parent() is RigidBody3D
	return {"id":actual,"held":held,"visible":is_instance_valid(node) and node.is_visible_in_tree(),"node":node.get_instance_id() if is_instance_valid(node) else -1,"parent":str(node.get_parent().name) if is_instance_valid(node) else "","menu_open":arsenal.menu_open,"shield_worn":host.shield_status().worn,"fire_id":arsenal.fire_state.get("weaponId","none"),"display_id":arsenal.arsenal_display_id29(),"ground_models":host.get("_ground_swords").size(),"bow_ground":bow.get("_ground_items").size(),"ground_owned":ground_owned,"visible_melee":visible_melee}
func choose(id:String,label:String)->Dictionary:
	if not arsenal.menu_open:await key(KEY_Q)
	await ticks(3)
	checks[label+"_q_open"]=arsenal.menu_open
	var button:Button=arsenal.get("_buttons")[id]
	var scroll:ScrollContainer=arsenal.get("_walk_ui").scroll
	scroll.ensure_control_visible(button)
	await ticks(2)
	var point:=button.get_global_rect().get_center()
	var movement:=InputEventMouseMotion.new();movement.position=point;movement.global_position=point
	root.push_input(movement,true)
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		root.push_input(e,true);await ticks(1)
	await ticks(12)
	var result:=state(id)
	checks[label+"_selected"]=result.id==id and result.held and result.visible and not result.menu_open
	checks[label+"_hud_matches_model"]=result.display_id==id
	checks[label+"_no_stale_held"]=result.visible_melee.size()<=1 and not result.ground_owned
	rows.append({"label":label,"point":point,"state":result})
	return result
func shot(name:String):
	if not visual:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+name+".png")
func run():
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		if arg=="--visual":visual=true
	root.size=Vector2i(1280,900)
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	scene=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
	while not scene.get("lab_ready"):await physics_frame
	arsenal=scene.get("preview_weapons");host=scene.get("preview_sword_prototype");bow=scene.get("preview_bow_prototype")
	await ticks(20)
	for id:String in IDS:
		var original:Dictionary=await choose(id,id+"_initial")
		await shot(id+"_initial")
		await key(KEY_G);await ticks(10)
		var dropped:=state(id)
		checks[id+"_g_drops"]=not dropped.held
		checks[id+"_drop_hud_clear"]=dropped.display_id=="none"
		checks[id+"_drop_has_physical_owner"]=dropped.ground_owned
		rows.append({"label":id+"_dropped","state":dropped})
		await shot(id+"_dropped")
		var returned:Dictionary=await choose(id,id+"_reselect")
		checks[id+"_same_model"]=int(original.node)>0 and returned.node==original.node
		checks[id+"_return_removes_drop_ledger"]=not returned.ground_owned and returned.ground_models==0 and returned.bow_ground==0
		await shot(id+"_returned")
		await key(KEY_G);await ticks(10);await key(KEY_E);await ticks(12)
		var picked:=state(id)
		checks[id+"_native_e_same_model"]=picked.held and picked.visible and picked.node==original.node and not picked.ground_owned
		rows.append({"label":id+"_E_pickup","state":picked})
	if OS.get_cmdline_user_args().has("--pairs"):
		for first:String in IDS:
			for second:String in IDS:
				await choose(first,"from_"+first+"_to_"+second)
				await choose(second,"pair_"+first+"_to_"+second)
	var failures:Array=[]
	for k:String in checks:
		if not checks[k]:failures.append(k)
	FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,"scope":"Real InputEvent Q opens actual GUI, mouse clicks visible arsenal cards, G drops. No direct equip or weapon writes in fixture. ScrollContainer ensures card visible before click; selected model identity/visibility/owner recorded."},"  "))
	scene.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
