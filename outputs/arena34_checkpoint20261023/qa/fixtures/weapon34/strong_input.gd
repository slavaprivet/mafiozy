extends SceneTree
var out:String
var rows:Array=[]
var scenarios:Array=[]
var checks:Dictionary={}
var host:Node
var solid:RefCounted
func _initialize():
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 run.call_deferred()
func frames(n:int):
 for i in n:await process_frame
func button(v:bool):
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=v;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(v:Vector2):
 var e:=InputEventMouseMotion.new();e.relative=v;e.screen_relative=v;Input.parse_input_event(e);Input.flush_buffered_events()
func start(z:float):
 button(false)
 if is_instance_valid(current_scene):
  var old:=current_scene;current_scene=null;host=null;solid=null;old.queue_free();await frames(5)
 var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
 while not scene.get("lab_ready"):await physics_frame
 host=scene.get("lab");host.lab_regrow=false;scene.call("_lab_equip",0);solid=host.get("_solid_weapon29")
 var p:CharacterBody3D=scene.get("_player")
 p.global_position=Vector3(0,.05,z);p.velocity=Vector3.ZERO;p._camera_yaw=0.;p._camera_pitch=-.1;p._update_camera_rotation();p.set_mouse_captured(true)
 await frames(30)
func probe(label:String,z:float,scale:float):
 await start(z)
 var before:int=host.clay_cuts
 var previous:int=solid.contacts
 button(true)
 var stroke:=0
 for direction:Vector2 in [Vector2(-10,-2),Vector2(16,0),Vector2(-16,0),Vector2(0,-14),Vector2(0,17),Vector2(13,10)]:
  for tick in 24:
   motion(direction*scale);await physics_frame
   if solid.contacts!=previous:
    var c:Dictionary=solid.last_contact
    rows.append({"scenario":label,"stroke":stroke,"tick":tick,"contact":c.duplicate(true),"clay":host.clay_last_contact28.duplicate(true),"async":host.clay_last_async28.duplicate(true),"cuts":host.clay_cuts,"omega":host._omega,"position":host._player.global_position})
    previous=solid.contacts
  stroke+=1
 button(false);await frames(90)
 scenarios.append({"name":label,"cuts":host.clay_cuts-before,"wounds":host.clay_local_wounds28,"last_contact":host.clay_last_contact28,"last_async":host.clay_last_async28,"unresolved":solid.unresolved,"grip":solid.max_grip_error})
 checks[label+"_expected_cut" if scale>=1.0 else label+"_no_cut"]=host.clay_cuts>before if scale>=1.0 else host.clay_cuts==before
 if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(out.path_join(label+".png"))
func run():
 root.size=Vector2i(1280,720)
 await probe("strong_near",-.75,1.0)
 await probe("strong_far",-.45,1.0)
 await probe("weak_near",-.75,.03)
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scenarios":scenarios,"rows":rows,"scope":"Real LMB and mouse motion, initial setup before input only; no direct contact or cut injection"},"\t"))
 button(false)
 if is_instance_valid(current_scene):
  var old:=current_scene;current_scene=null;old.queue_free()
 await frames(5);quit(0 if passed else 1)
