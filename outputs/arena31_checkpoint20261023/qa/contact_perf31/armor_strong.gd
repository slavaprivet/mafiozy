extends SceneTree
var out:String
var checks:Dictionary={}
var rows:Array=[]
var tier:String="heavy"
var weapon:int=2
var contacts:Array=[]
var start_x:float=0.0
var start_z:float=-.75
var start_pitch:float=-.1
var amplitude:float=1.0
var flicks:bool=false
var pattern_index:int=-1
var advance:bool=false
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
  if a.begins_with("--tier="):tier=a.trim_prefix("--tier=")
  if a.begins_with("--weapon="):weapon=int(a.trim_prefix("--weapon="))
  if a.begins_with("--x="):start_x=float(a.trim_prefix("--x="))
  if a.begins_with("--z="):start_z=float(a.trim_prefix("--z="))
  if a.begins_with("--pitch="):start_pitch=float(a.trim_prefix("--pitch="))
  if a.begins_with("--amplitude="):amplitude=float(a.trim_prefix("--amplitude="))
  if a=="--flicks":flicks=true
  if a.begins_with("--pattern="):pattern_index=int(a.trim_prefix("--pattern="))
  if a=="--advance":advance=true
 run.call_deferred()
func button(value:bool):
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=value;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(value:Vector2):
 var e:=InputEventMouseMotion.new();e.relative=value;e.screen_relative=value;Input.parse_input_event(e);Input.flush_buffered_events()
func frames(count:int):
 for i in count:await process_frame
func move(value:float):
 var e:=InputEventAction.new();e.action=&"preview_move_right";e.pressed=value>0;e.strength=value;Input.parse_input_event(e);Input.flush_buffered_events()
func forward(value:bool):
 var e:=InputEventAction.new();e.action=&"preview_move_forward";e.pressed=value;e.strength=1.0 if value else 0.0;Input.parse_input_event(e);Input.flush_buffered_events()
func run():
 root.size=Vector2i(1280,720)
 change_scene_to_file("res://scenes/arena27.tscn")
 for i in 600:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
 var scene:Node=current_scene
 checks["startup"]=is_instance_valid(scene) and scene.get("lab_ready")==true
 if not checks.startup:finish();return
 var host:Node=scene.get("lab");host.lab_regrow=false
 var player:CharacterBody3D=scene.get("_player")
 scene._lab_equip(weapon)
 var equipment:Dictionary={}
 if tier!="none":
  for slot:String in ["head","torso","hands","legs","feet"]:equipment[slot]=tier+"_"+slot
 host.lab_armored=tier!="none";host.lab_armor_tier30=tier;host.set_npc_armor31(equipment)
 player.global_position=Vector3(start_x,.05,start_z);player.velocity=Vector3.ZERO
 player._camera_yaw=0.;player._camera_pitch=start_pitch;player._update_camera_rotation();player.set_mouse_captured(true)
 await frames(30)
 var helper:RefCounted=host.get("_solid_weapon29")
 var strong_start:int=host.clay_cuts
 var strong_unresolved_start:int=helper.unresolved
 button(true)
 if flicks:
  var patterns:Array=[{"aim":Vector2(-90,35),"flick":Vector2(180,0)},{"aim":Vector2(0,-80),"flick":Vector2(0,180)},{"aim":Vector2(-80,-70),"flick":Vector2(160,150)}]
  if pattern_index>=0:patterns=[patterns[pattern_index]]
  for pattern:Dictionary in patterns:
   motion(pattern.aim);await frames(60)
   if advance:forward(true)
   motion(pattern.flick)
   for tick in 36:
    await physics_frame
    contacts.append({"frame":Engine.get_physics_frames(),"input":pattern.flick,"contact":host.clay_last_contact28.duplicate(true),"cuts":host.clay_cuts,"solid_safe":helper._publish_safe,"solid":helper.last_contact.duplicate(true),"omega":host._omega})
   if advance:forward(false)
 else:
  for direction:Vector2 in [Vector2(-10,-2),Vector2(16,0),Vector2(-16,0),Vector2(0,-14),Vector2(0,17),Vector2(13,10)]:
   for tick in 24:
    motion(direction*amplitude);await physics_frame
    contacts.append({"frame":Engine.get_physics_frames(),"input":direction,"contact":host.clay_last_contact28.duplicate(true),"cuts":host.clay_cuts,"solid_safe":helper._publish_safe,"solid":helper.last_contact.duplicate(true),"omega":host._omega})
 button(false);await frames(30)
 checks["strong_actual_sever"]=host.clay_cuts>strong_start
 checks["strong_no_invalid_pose"]=helper.unresolved==strong_unresolved_start
 checks["strong_grip_attached"]=helper.max_grip_error<.005
 checks["metadata_selection_after_sever"]=helper._skin_nodes(host)==host.call("_npc_skinned_meshes")
 rows.append({"stage":"fresh_scene_strong","cuts":host.clay_cuts-strong_start,"async":host.clay_last_async28,"status":helper.status()})
 finish()
func finish():
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"rows":rows,"tier":tier,"weapon":weapon,"contacts":contacts,"events":current_scene.lab.lab_events,"audio":current_scene.lab.melee_audio_report31(),"scope":"Fresh scene, actual LMB and six directional mouse strokes14-17px. Player placement before input; no midstroke pose/contact injection."},"\t"))
 var old:Node=current_scene;current_scene=null;old.queue_free();await frames(4)
 quit(0 if passed else 1)
