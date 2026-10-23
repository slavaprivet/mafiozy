extends SceneTree
var out:String
var disabled:=false
var pitch:float=-.1
var cases:Array=[]
var checks:Dictionary={}
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
  if a=="--presentation-off":disabled=true
  if a.begins_with("--pitch="):pitch=float(a.trim_prefix("--pitch="))
 run.call_deferred()
func button(down:bool):
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(x:float,y:float=0):
 var e:=InputEventMouseMotion.new();e.relative=Vector2(x,y);e.screen_relative=e.relative;Input.parse_input_event(e);Input.flush_buffered_events()
func frames(n:int):
 for i in n:await process_frame
func v3(v:Vector3)->Array:return [v.x,v.y,v.z]
func probe(weapon:int,contact:bool):
 button(false)
 if is_instance_valid(current_scene):
  var old:=current_scene;current_scene=null;old.queue_free();await frames(4)
 var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
 while not scene.get("lab_ready"):await physics_frame
 var host:Node=scene.lab
 host.lab_regrow=false
 scene._lab_equip(weapon)
 host._swing_presentation30.enabled=not disabled
 var p:CharacterBody3D=scene._player
 p.global_position=Vector3(0,.05,-.75 if contact else 5.0);p.velocity=Vector3.ZERO
 p._camera_yaw=0.;p._camera_pitch=pitch;p._update_camera_rotation();p.set_mouse_captured(true)
 await frames(60)
 var solid:RefCounted=host._solid_weapon29
 var label:String=("sword" if weapon==0 else "sledge")+("_contact" if contact else "_air")
 var rows:Array=[]
 var max_grip:=0.;var min_y:=1.;var max_y:=-1.;var contacts_before:int=solid.contacts
 var pre_axis_y:float=host._dir.y
 button(true)
 for stroke:Dictionary in [{"name":"settle","x":0.,"y":0.,"n":30},{"name":"lower","x":0.,"y":8.,"n":20 if weapon==3 else 0},{"name":"level_settle","x":0.,"y":0.,"n":30},{"name":"left","x":-8.,"y":0.,"n":35},{"name":"right","x":8.,"y":0.,"n":70},{"name":"up","x":0.,"y":-8.,"n":65},{"name":"down","x":0.,"y":8.,"n":80},{"name":"hold","x":0.,"y":0.,"n":20}]:
  for i in int(stroke.n):
   if float(stroke.x)!=0 or float(stroke.y)!=0:motion(stroke.x,stroke.y)
   await physics_frame;await process_frame;await create_timer(0).timeout
   var snap:Dictionary=host.snapshot()
   var axis:Vector3=host._dir;var target:Vector3=host._target_direction()
   var tip:Vector3=host._sword.global_transform*Vector3(host._weapon_length,0,0)
   max_grip=maxf(max_grip,float(snap.get("grip_hand_error",0)))
   min_y=minf(min_y,axis.y);max_y=maxf(max_y,axis.y)
   rows.append({"stroke":stroke.name,"tick":i,"frame":Engine.get_physics_frames(),"input_x":stroke.x,"input_y":stroke.y,"hand":v3(Vector3(host._hand.x,host._hand.y,0)),"target":v3(target),"steer_target":v3(host._steer_target),"axis":v3(axis),"origin":v3(host._sword_origin),"tip":v3(tip),"omega":v3(host._omega),"camera":v3(-host._camera.global_basis.z),"body_yaw":p._visual.global_rotation.y,"contacts":solid.contacts,"solid_safe":solid._publish_safe,"last_contact":solid.last_contact.duplicate(true),"self_clear":snap.get("self_pose_clear",false),"grip":snap.get("grip_hand_error",-1),"support":snap.get("left_hand_error",-1),"presentation":host._swing_presentation30.status()})
   if i==int(stroke.n)/2 and DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out.path_join(label+"_"+str(stroke.name)+".png"))
 button(false)
 if weapon==3 and not contact:
  await frames(20)
  var rep:Vector3=host._dir
  button(true)
  checks["sledge_repress_recaptures"]=host._target_direction().dot(rep)>.99999
  motion(8,0);await frames(4)
  checks["switch_sword_held"]=host.set_weapon("sword")
  await frames(4)
  var switched:Vector3=host._dir
  checks["switch_sledge_held"]=host.set_weapon("sledge")
  checks["sledge_switch_recaptures"]=host._target_direction().dot(switched)>.99999
  await frames(8)
  checks["sledge_switch_finite"]=host._dir.is_finite()
  button(false)
 checks[label+"_finite"]=is_finite(min_y) and is_finite(max_y)
 checks[label+"_grip"]=max_grip<.005
 checks[label+"_scope"]=solid.contacts==contacts_before if not contact else solid.contacts>contacts_before
 var lateral:Array=rows.filter(func(r):return r.stroke in ["left","right"])
 var target_min:=1.;var target_max:=-1.;var lateral_contacts:=0
 for r in lateral:
  target_min=minf(target_min,r.target[1]);target_max=maxf(target_max,r.target[1])
 for name in ["left","right"]:
  var rr:Array=rows.filter(func(r):return r.stroke==name)
  lateral_contacts+=int(rr[-1].contacts)-int(rr[0].contacts)
 checks[label+"_horizontal_target_height"]=target_max-target_min<.0001
 if contact:checks[label+"_actual_horizontal_contacts"]=lateral_contacts>0
 if not contact:
  var up_rows:Array=rows.filter(func(r):return r.stroke=="up")
  var down_rows:Array=rows.filter(func(r):return r.stroke=="hold")
  checks[label+"_vertical_up"]=float(up_rows[-1].axis[1])>.5
  checks[label+"_vertical_down"]=float(down_rows[-1].axis[1])<-.3
 if weapon==3:
  var settled:Array=rows.filter(func(r):return r.stroke=="settle")
  checks[label+"_press_preserves_axis"]=absf(float(settled[-1].axis[1])-pre_axis_y)<.01
 cases.append({"label":label,"min_axis_y":min_y,"max_axis_y":max_y,"max_grip":max_grip,"contact_count":solid.contacts-contacts_before,"cuts":host.clay_cuts,"rows":rows})
func run():
 root.size=Vector2i(1280,720);root.set_flag(Window.FLAG_NO_FOCUS,true);seed(35023)
 for weapon in [0,3]:
  for contact in [false,true]:await probe(weapon,contact)
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"cases":cases,"presentation_disabled":disabled,"scope":"Real LMB horizontal and vertical mouse input; lower deliberately before contact. Diagnostic finite/grip/contact checks."},"\t"))
 var old:=current_scene;current_scene=null;old.queue_free();await frames(4);quit(0 if passed else 1)
