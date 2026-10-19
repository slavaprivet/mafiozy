extends SceneTree
var game:Node3D
var player:CharacterBody3D
var bow:Node
var sword:Node
var storage:Node
var out:=""
var rows:Array=[]
var errors:Array=[]
var proof:=false
func _initialize()->void:
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
  if a=="--shadow-proof=1":proof=true
 run.call_deferred()
func frames(n:int)->void:
 for i in n:await physics_frame
func button(b:int,down:bool)->void:
 var e:=InputEventMouseButton.new();e.button_index=b;e.pressed=down;Input.parse_input_event(e)
func motion(dx:float,dy:float)->void:
 var e:=InputEventMouseMotion.new();e.relative=Vector2(dx,dy);Input.parse_input_event(e)
func key(k:int,down:bool)->void:
 var e:=InputEventKey.new();e.keycode=k;e.physical_keycode=k;e.pressed=down;Input.parse_input_event(e)
func tap(k:int)->void:
 key(k,true);await frames(2);key(k,false);await frames(4)
func count(host:Node)->int:
 var n:=0
 for d in host._aim_dots:
  if d.is_visible_in_tree():n+=1
 return n
func capture(label:String)->void:
 await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out.path_join(label+".png"))
 var row:Dictionary={"label":label,"bow_dots":count(bow),"spear_dots":count(sword),"bow_selected":bow._selected,"sword_selected":sword._selected,"position":player.global_position,"pitch":player._camera_pitch,"visual_yaw":player._visual.rotation.y,"heading":player._heading,"TAA":root.use_taa,"npc_position":sword._npc_body.global_position if is_instance_valid(sword._npc_body) else Vector3.ZERO,"crosshair":game.preview_weapons._crosshair.is_visible_in_tree(),"storage":storage.snapshot(),"points":[]}
 for d in bow._aim_dots:
  if d.is_visible_in_tree():row.points.append({"world":d.global_position,"screen":bow._camera.unproject_position(d.global_position),"shadow":d.cast_shadow})
 rows.append(row)
 if count(bow)>0 and count(sword)>0:errors.append(label+"_two_arcs")
 if bow._selected and row.crosshair:errors.append(label+"_extra_crosshair")
 if not proof:
  for d in bow._aim_dots:
   if d.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:errors.append(label+"_shadow_enabled");break
func ensure_aim()->void:
 button(MOUSE_BUTTON_RIGHT,false);await frames(3);button(MOUSE_BUTTON_RIGHT,true);await frames(95)
func run()->void:
 root.size=Vector2i(1280,720)
 game=load("res://scenes/castle.tscn").instantiate();root.add_child(game);current_scene=game
 while game.get("preview_ready")!=true:await process_frame
 await frames(150);game._castle_spawn_frames=0;player=game._player;storage=game.preview_castle.armory_storage
 player.global_position=game.preview_castle.to_global(Vector3(0,.1,float(game.preview_castle.wall_half())+35));player.velocity=Vector3.ZERO;player._camera_yaw=0;player._camera_pitch=-.08;player._heading=0;player._visual.rotation.y=PI;player._update_camera_rotation();player.set_mouse_captured(true)
 storage.acquire_or_select("spear");storage.acquire_or_select("bow");sword=game.preview_sword_prototype;bow=game.preview_bow_prototype
 await frames(30)
 for i in 300:
  if is_instance_valid(sword._npc_body):break
  await frames(1)
 if is_instance_valid(sword._npc_body):
  sword._npc_body.global_position=player.global_position+Vector3(140,0,0)
  sword._npc_body.velocity=Vector3.ZERO
  sword._npc_engaged=false
 else:errors.append("npc_not_initialized_for_isolation")
 player.global_position=game.preview_castle.to_global(Vector3(-4,.1,float(game.preview_castle.wall_half())+8));player.velocity=Vector3.ZERO;player.set_mouse_captured(true)
 if not bow._selected:await tap(KEY_Q)
 if not bow._selected:errors.append("bow_not_selected")
 var before:float=player._camera_yaw;motion(10,0);await frames(2);var delivered:float=-wrapf(player._camera_yaw-before,-PI,PI)/player.mouse_sensitivity
 if absf(delivered-10)>.05:errors.append("input_not_1to1")
 motion(-10,0);await frames(4);await ensure_aim()
 if count(bow)<3:errors.append("bow_arc_missing")
 await capture("aim_gate")
 if proof:
  paused=true
  for i in 40:await process_frame
  await capture("frozen_on1")
  for d in bow._aim_dots:d.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for i in 40:await process_frame
  await capture("frozen_off")
  for d in bow._aim_dots:d.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
  for i in 40:await process_frame
  await capture("frozen_on2")
  paused=false
 else:
  key(KEY_S,true)
  for i in 4:
   await frames(15);await capture("back_"+str(i))
   if count(bow)<3:errors.append("back_arc_missing_"+str(i))
  key(KEY_S,false);await frames(40)
  await tap(KEY_Q);await frames(35);await capture("q_to_spear")
  if bow._selected or count(bow)>0:errors.append("bow_after_q")
  await ensure_aim();await capture("spear_reaim")
  if count(sword)<1:errors.append("spear_arc_missing")
  await tap(KEY_Q);await frames(35);await capture("q_to_bow")
  if not bow._selected:errors.append("bow_not_returned")
  await ensure_aim();await capture("bow_reaim")
  if count(bow)<3:errors.append("bow_arc_missing_after_q")
  # Tilt through native input, retain only bow arc and then return through equal input.
  motion(0,-240);await frames(60);await capture("high_aim")
  if count(bow)<3:errors.append("high_arc_missing")
  motion(0,240);await frames(60)
  # Select only bow for G/E so the melee host cannot absorb pickup input.
  await tap(KEY_G);await frames(10);await capture("dropped")
  if count(bow)>0 or bow._selected or not storage._fallen.has("bow"):errors.append("drop_failed")
  await tap(KEY_E);await frames(10)
  if not bow._selected and storage._back_bow:await tap(KEY_Q)
  await capture("picked")
  if not storage._carried.has("bow") or not bow._selected:errors.append("pickup_failed")
  await ensure_aim();await capture("picked_reaim")
  if count(bow)<3:errors.append("picked_arc_missing")
  button(MOUSE_BUTTON_RIGHT,false);await frames(4);await capture("released")
  if count(bow)>0:errors.append("release_arc_remaining")
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":errors.is_empty(),"errors":errors,"input_10px_delivered":delivered,"rows":rows,"scope":"Native 1280x720 real input; async NPC awaited then positioned away once before input to isolate rendering. No NPC health changes. Frozen shadow proof changes only cast_shadow."},"\t"));quit(0 if errors.is_empty() else 2)
