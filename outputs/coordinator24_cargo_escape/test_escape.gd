extends SceneTree
## Exact pack only. No script replacement or fixture-owned gameplay tick.
var scene:Node3D
var p:CharacterBody3D
var w:Node
var c:Node
var t:Node3D
var errors:Array[String]=[]
var checks:=0
var expect_fixed:=false
var gpu:=false
var out:=""
var pack:=""
var sha:=""
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:errors.append(label);print("FAIL ",label)
func step(count:int=1)->void:
	for i in count:await physics_frame;await process_frame
func key(code:int,down:bool=true,echo:bool=false)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;event.echo=echo
	Input.parse_input_event(event);Input.flush_buffered_events()
func click(down:bool)->void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=Vector2(600,400);event.global_position=event.position;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event);Input.flush_buffered_events()
func controls()->Dictionary:
	return {"window_open":c.window_open,"free":p._free_mouse_look,"blocked":w.controls_blocked(),"physical_w":Input.is_physical_key_pressed(KEY_W),"forward":Input.is_action_pressed(p.ACTION_FORWARD),"mouse_mode":Input.mouse_mode,"window_focus":root.has_focus(),"transport_phase":t.phase,"e_down":t._e_down,"shots":w.shots_count}
func inventory()->Dictionary:
	var current:Dictionary=w.inventory.snapshot();var ammunition:Dictionary={}
	for id:String in current.fireStates:
		ammunition[id]=[current.fireStates[id].magazine,current.fireStates[id].reserveAmmo]
	return {"identity":w.inventory.item_identity_snapshot(),"equipped":current.equippedId,"ammo":ammunition,"cargo":c.cargo.snapshot(c.generation)}
func finish()->void:
	var result:Dictionary={"valid":errors.is_empty(),"checks":checks,"errors":errors,"expect_fixed":expect_fixed,"gpu":gpu,"pack_sha256":sha,"harness_sha256":FileAccess.get_sha256(get_script().resource_path),"evidence":evidence,"scope":"exact compiled pack, original3NPC/8buildings/377collision, actual F/ESC Godot input dispatch; injected key events, not manual OS-keyboard proof; no game script/camera replacement or player/transport disabling"}
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out);var file:=FileAccess.open(out.path_join("ESCAPE_RESULT.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file=null
	print("CARGO_ESCAPE_RESULT ",JSON.stringify(result))
	if is_instance_valid(scene):scene.queue_free()
	quit(0 if errors.is_empty() else 1)
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg=="--expect-fixed":expect_fixed=true
		elif arg=="--gpu":gpu=true
		elif arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
		elif arg.begins_with("--exact-pack="):pack=arg.trim_prefix("--exact-pack=")
		elif arg.begins_with("--expected-sha="):sha=arg.trim_prefix("--expected-sha=")
	if not pack.is_empty() or not sha.is_empty():check(sha.length()==64 and FileAccess.get_sha256(pack)==sha,"exact PCK pinned bytes")
	if not errors.is_empty():finish();return
	for path:String in ["res://scripts/main.gd","res://scripts/weapons/preview_weapon_cargo.gd"]:
		var script:Script=load(path)
		check(script!=null and not script.has_source_code(),"compiled PCK runtime script: "+path)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	if gpu:
		check(DisplayServer.get_name()!="headless" and not root.unfocusable,"normal focusable GPU window")
		root.grab_focus()
		for i in 120:
			await process_frame
			if root.has_focus():break
		check(root.has_focus(),"actual native focus before setup")
		if not root.has_focus():finish();return
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	for i in 180:
		await step()
		if scene.preview_ready:break
	check(scene.preview_ready,"ordinary main ready")
	if not scene.preview_ready:finish();return
	p=scene._player;w=scene.preview_weapons;t=scene.preview_transport;c=w.get_node("WeaponCargo")
	p.set_mouse_captured(true);await step(60)
	check(scene.preview_population.hit_owners.size()==3 and scene._block.counts.buildings==8 and scene.find_children("*","CollisionObject3D",true,false).size()==377 and scene.find_children("*","CollisionShape3D",true,false).size()==377,"original full test-quarter content intact")
	check(not p.get_preview_camera().top_level,"original attached camera retained")
	var access:Dictionary=t.compartments.access_profile("trunk")
	p.global_position=t.body.to_global(access.position_local_m+access.outward_local*.9);p.global_position.y=.01
	t.compartments.set_open("trunk",true);await step(100)
	check(c._window_access(),"current real hatch access")
	check(w.equip("tt_pistol").get("ok",false),"real TT selected for cargo setup")
	var tt_uid:String=w.inventory.get_item_uid("tt_pistol")
	# Populate the real trunk through the same F/G input path used in gameplay.
	key(KEY_F);key(KEY_F,false);await step(2)
	check(c.window_open and w.controls_blocked(),"setup F dispatch opens contents")
	key(KEY_G);key(KEY_G,false);await step(2)
	check(c.cargo.snapshot(c.generation).items.size()==1 and not w.inventory.get_owned_ids().has("tt_pistol"),"G dispatch stores exact TT")
	if not errors.is_empty():finish();return
	key(KEY_Q);key(KEY_Q,false);await step(2)
	check(not c.window_open and p._free_mouse_look,"Q setup close resumes ordinary controls")
	check(w.equip("nagan").get("ok",false),"armed gameplay retained during ESC scenario")
	var before:Dictionary=inventory();var shots:int=w.shots_count
	check(before.cargo.items[0].item.uid==tt_uid,"exact original TT UID in cargo before ESC")
	key(KEY_W);key(KEY_F);key(KEY_F,false);await step(2)
	check(c.window_open and c._window.visible and w.controls_blocked(),"actual F opens populated contents")
	check(Input.is_physical_key_pressed(KEY_W) and not Input.is_action_pressed(p.ACTION_FORWARD),"F modal suspends physically held W")
	evidence.before_escape=controls()
	key(KEY_ESCAPE)
	check(not c.window_open and not c._window.visible and not w.controls_blocked(),"ESCdown closes only the contents modal")
	if expect_fixed:
		check(p._free_mouse_look and Input.is_action_pressed(p.ACTION_FORWARD),"ESCdown restores gameplay and held W without click")
		if gpu:check(root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"ESCdown restores actual focused OS capture")
	else:
		check(not p._free_mouse_look and not Input.is_action_pressed(p.ACTION_FORWARD),"baseline reproduces extra-click suspension after modal ESC")
		if gpu:check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"baseline cursor remains visible")
	evidence.escape_down=controls()
	key(KEY_ESCAPE,true,true)
	check(p._free_mouse_look==expect_fixed,"same held ESC echo cannot release newly restored gameplay")
	key(KEY_ESCAPE,false)
	check(p._free_mouse_look==expect_fixed,"matching ESC release cannot fall through into another toggle")
	var position:Vector3=p.global_position;await step(3)
	var moved:float=Vector2(p.global_position.x-position.x,p.global_position.z-position.z).length()
	check(moved>.005 if expect_fixed else moved<.001,"held W physically resumes only in fixed ESC flow")
	evidence.after_escape_release=controls();evidence.movement_m=moved
	key(KEY_W,false)
	check(not Input.is_action_pressed(p.ACTION_FORWARD),"restored W stops its action on physical release")
	check(t.compartments.is_open("trunk") and t.phase=="ON_FOOT" and not t._e_down,"modal ESC/echo/release neither closes lid nor enters a seat")
	check(inventory()==before and w.shots_count==shots and not w._held and not w._pressed,"ESC flow preserves all item UIDs/ammo and causes no shot")
	if gpu:
		await RenderingServer.frame_post_draw
		var capture_path:String=out.path_join("after_modal_escape.png")
		check(root.get_texture().get_image().save_png(capture_path)==OK,"actual viewport capture after modal ESC")
		evidence.capture=capture_path
	var panel:Node=scene.find_child("PreviewUpdates",true,false)
	check(is_instance_valid(panel) and not panel.get_status().restart_required,"matching runtime notes without restart banner")
	if not expect_fixed:
		click(true);click(false)
		check(p._free_mouse_look and w.shots_count==shots,"baseline requires one neutral reacquire click")
	# The first distinct later ESC in normal gameplay retains cursor-release use.
	key(KEY_ESCAPE)
	check(not p._free_mouse_look and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not c.window_open,"second distinct ESC in gameplay still releases the cursor")
	key(KEY_ESCAPE,false)
	check(inventory()==before and w.shots_count==shots,"second gameplay ESC preserves ownership/ammo and no fire")
	evidence.final=controls();evidence.clicks_to_resume=0 if expect_fixed else 1;evidence.runtime_revision=scene.PREVIEW_RUNTIME_REVISION
	finish()
