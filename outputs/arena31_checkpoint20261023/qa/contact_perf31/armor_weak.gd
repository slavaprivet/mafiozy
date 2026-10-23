extends SceneTree
var out:String
var checks:Dictionary={}
var rows:Array=[]
var tier:String="heavy"
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
  if a.begins_with("--tier="):tier=a.trim_prefix("--tier=")
 run.call_deferred()
func button(value:bool):
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=value;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(value:Vector2):
 var e:=InputEventMouseMotion.new();e.relative=value;e.screen_relative=value;Input.parse_input_event(e);Input.flush_buffered_events()
func frames(count:int):
 for i in count:await process_frame
func move(value:float):
 var e:=InputEventAction.new();e.action=&"preview_move_right";e.pressed=value>0;e.strength=value;Input.parse_input_event(e);Input.flush_buffered_events()
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
 scene._lab_equip(0)
 var equipment:Dictionary={}
 if tier!="none":
  for slot:String in ["head","torso","hands","legs","feet"]:equipment[slot]=tier+"_"+slot
 host.lab_armored=tier!="none";host.lab_armor_tier30=tier;host.set_npc_armor31(equipment)
 player.global_position=Vector3(-1.3,.05,-.75);player.velocity=Vector3.ZERO
 player._camera_yaw=0.;player._camera_pitch=-.1;player._update_camera_rotation();player.set_mouse_captured(true)
 await frames(30)
 var helper:RefCounted=host.get("_solid_weapon29")
 checks["metadata_selection_initial"]=helper._skin_nodes(host)==host.call("_npc_skinned_meshes")
 button(true);motion(Vector2(0,100));await frames(60)
 var start_contacts:int=helper.contacts
 var start_cuts:int=host.clay_cuts
 var start_wounds:int=host.clay_local_wounds28
 var slow_player_start:=player.global_position
 move(.55)
 for tick in 400:
  await process_frame
  if helper.contacts>start_contacts:break
 move(0)
 checks["slow_native_lateral_movement"]=player.global_position.distance_to(slow_player_start)>.1
 var peak_speed:=Vector3(helper.last_contact.get("motion",Vector3.ZERO)).length()
 for direction:Vector2 in [Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(1,1),Vector2(-1,-1)]:
  for tick in 80:
   motion(direction*.45);await process_frame
   peak_speed=maxf(peak_speed,Vector3(helper.last_contact.get("motion",Vector3.ZERO)).length())
 checks["slow_real_contact"]=helper.contacts>start_contacts
 checks["slow_no_sever"]=host.clay_cuts==start_cuts
 var held_cuts:int=host.clay_cuts;var before_held_contacts:int=helper.contacts
 for tick in 120:await process_frame
 checks["held120_no_sever"]=host.clay_cuts==held_cuts
 rows.append({"stage":"slow_and_hold","player_displacement":player.global_position-slow_player_start,"input_deadzone":InputMap.action_get_deadzone(&"preview_move_right"),"contacts":helper.contacts-start_contacts,"wounds":host.clay_local_wounds28-start_wounds,"cuts":host.clay_cuts-start_cuts,"peak_contact_speed":peak_speed,"held_contacts":helper.contacts-before_held_contacts,"status":helper.status()})
 button(false)
 finish()
func finish():
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"rows":rows,"tier":tier,"armor":current_scene.lab._armor_contact31.last,"scope":"Actual mouse and native movement input: aim beside target, analog D .55 above configured deadzone brings blade SIDE into skin (not axial bore), slow0.45px draw-frame motions,120heldnoinputframes. Setup player placement before each stage; no midstroke pose/contact injection."},"\t"))
 var old:Node=current_scene;current_scene=null;old.queue_free();await frames(4)
 quit(0 if passed else 1)
