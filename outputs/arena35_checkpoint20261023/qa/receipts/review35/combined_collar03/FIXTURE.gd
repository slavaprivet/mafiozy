extends SceneTree
const COUNTERS=["geometry_usec","sweep_usec","static_usec","ik_usec","prepare_usec","world_usec","geometry_builds","triangle_candidates","walk_usec","solver_usec","skin_hits_usec31","segment_calls","grid_visits"]
var out:String
var phase:String=""
var host:Node
var solid:RefCounted
var samples:Array=[]
var outcomes:Array=[]
var physics_samples:Array=[]
var physics_previous:Array=[]
var previous_physics_usec:=0
var checks:Dictionary={}
var previous_usec:int=0
var previous_counters:Array=[]
var max_depth:float=0.0
var max_ratio:float=0.0
var observed_entry:bool=false
var observer_usec:int=0
var collar_checked:=false
class HardArmor:
 extends RefCounted
 func evaluate(_a,_b,_c,_d,_e,_f)->Dictionary:return {"protected":true}
func collar_negative35():
 if collar_checked or solid.last_head_collar35.is_empty():return
 collar_checked=true
 var record:Dictionary=solid.last_head_collar35.duplicate(true)
 var ch:Dictionary=host.get_meta("puncture29_channel",{})
 var frame:Transform3D=record.frame
 var point:Vector3=record.point
 var world:Vector3=record.world_hit
 var normal:=frame.basis.z.normalized()
 var hit:Dictionary=solid._segment(world+normal*.00025,world-normal*.00025)
 checks.actual_lip_collar=solid._entry_surface_collar31(ch,frame,point,world,hit,host)
 var old:Dictionary=ch.duplicate(true);old.cut_depth=0.
 checks.no_uncommitted_lip=not solid._entry_surface_collar31(old,frame,point,world,hit,host)
 old=ch.duplicate(true);old.generation+=1
 checks.no_stale_generation=not solid._entry_surface_collar31(old,frame,point,world,hit,host)
 old=ch.duplicate(true);old.entry_collar31.mesh_id+=1
 checks.no_changed_mesh=not solid._entry_surface_collar31(old,frame,point,world,hit,host)
 old=ch.duplicate(true);old.bone+=1
 checks.no_other_bone=not solid._entry_surface_collar31(old,frame,point,world,hit,host)
 var beyond:=point;beyond.z=.013
 checks.no_extended_collar=not solid._entry_surface_collar31(ch,frame,beyond,world,hit,host)
 var side:Transform3D=host._sword.global_transform;side.origin+=frame.basis.x*.08
 checks.no_widened_bore=not solid._channel_allows(host,world,world,side,false,Vector3.INF,"head",hit)
 var armor=host._armor_contact31
 host._armor_contact31=HardArmor.new()
 checks.armor_gate_is_mandatory=not solid._entry_surface_collar31(ch,frame,point,world,hit,host)
 host._armor_contact31=armor
 var buried:Dictionary=solid._segment(world-normal*.0005,world-normal*.03)
 checks.actual_underlying_skin_exists=not buried.is_empty()
 if not buried.is_empty():
  var at:Vector3=buried.position
  checks.no_buried_layer=not solid._entry_surface_collar31(ch,frame,frame.affine_inverse()*at,at,buried,host)
 outcomes.append({"collar_probe":record,"hit":hit,"buried":buried})
func _initialize():
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 run.call_deferred()
func button(value:bool):
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=value;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(value:Vector2):
 var e:=InputEventMouseMotion.new();e.relative=value;e.screen_relative=value;Input.parse_input_event(e);Input.flush_buffered_events()
func move(action:StringName,value:float):
 var e:=InputEventAction.new();e.action=action;e.pressed=value>0;e.strength=value;Input.parse_input_event(e);Input.flush_buffered_events()
func ticks(count:int):
 for i in count:await physics_frame
func frames(count:int):
 for i in count:await process_frame
func draw_sample():
 if phase.is_empty() or not is_instance_valid(host):previous_usec=0;return
 var begin:=Time.get_ticks_usec()
 var channel:Dictionary=host.get_meta("puncture29_channel",{})
 var depth:float=float(channel.get("cut_depth",0.0))
 var thickness:float=float(channel.get("max_depth",0.0))
 max_depth=maxf(max_depth,depth);max_ratio=maxf(max_ratio,depth/maxf(.001,thickness))
 observed_entry=observed_entry or (channel.get("actual_hit",false) and depth>.001)
 var row:Array=[phase,begin,begin-previous_usec if previous_usec>0 else 0,Engine.get_physics_frames(),solid.get("last_solver_usec"),depth,host.clay_cuts,solid.get("unresolved"),Performance.get_monitor(Performance.TIME_PROCESS),Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)]
 for i in COUNTERS.size():
  var current:int=solid.get(COUNTERS[i]);row.append(current-int(previous_counters[i]) if previous_counters.size()==COUNTERS.size() else 0)
  if previous_counters.size()==COUNTERS.size():previous_counters[i]=current
 if previous_counters.is_empty():
  for field in COUNTERS:previous_counters.append(solid.get(field))
 samples.append(row);previous_usec=begin
 observer_usec+=Time.get_ticks_usec()-begin
func physics_sample():
 if phase.is_empty() or not is_instance_valid(host):previous_physics_usec=0;physics_previous.clear();return
 var now:=Time.get_ticks_usec()
 var channel:Dictionary=host.get_meta("puncture29_channel",{})
 var player:Node3D=current_scene.get("_player")
 var row:Array=[phase,now,now-previous_physics_usec if previous_physics_usec>0 else 0,Engine.get_physics_frames(),float(channel.get("cut_depth",0)),float(channel.get("max_depth",0)),player.position.x,player.position.y,player.position.z,player.velocity.x,player.velocity.y,player.velocity.z,solid.last_solver_usec]
 for i in COUNTERS.size():
  var value:int=solid.get(COUNTERS[i])
  row.append(value-int(physics_previous[i]) if physics_previous.size()==COUNTERS.size() else 0)
  if physics_previous.size()==COUNTERS.size():physics_previous[i]=value
 if physics_previous.is_empty():
  for field in COUNTERS:physics_previous.append(solid.get(field))
 physics_samples.append(row);previous_physics_usec=now
func set_phase(value:String):
 phase=value;previous_usec=0;previous_counters.clear();previous_physics_usec=0;physics_previous.clear()
func start_scene(weapon:int,x:float,z:float,pitch:float):
 set_phase("")
 if is_instance_valid(current_scene):
  var old:=current_scene;current_scene=null;host=null;solid=null;old.queue_free();await frames(4)
 var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
 while not scene.get("lab_ready"):await physics_frame
 host=scene.get("lab");host.lab_regrow=false;scene.call("_lab_equip",weapon);solid=host.get("_solid_weapon29")
 var player:Node=scene.get("_player")
 player.global_position=Vector3(x,.05,z);player.velocity=Vector3.ZERO;player._camera_yaw=0.;player._camera_pitch=pitch;player._update_camera_rotation();player.set_mouse_captured(true)
 max_depth=0.;max_ratio=0.;observed_entry=false
 await frames(30)
func probe(label:String,weapon:int,aim:Vector2,tier:String):
 await start_scene(weapon,.2 if weapon==0 else 0.,1.8,-.1)
 var equipment:Dictionary={}
 if not tier.is_empty():
  for slot:String in ["head","torso","hands","legs","feet"]:equipment[slot]=tier+"_"+slot
 host.lab_armored=not tier.is_empty();host.set_npc_armor31(equipment)
 host.set_meta("debug_bore31",true)
 await ticks(15);button(true);motion(aim);await ticks(45)
 var rows:Array=[];var peak:=0.0;var last_usec:=Time.get_ticks_usec()
 move("preview_run",1.);move("preview_move_forward",1.)
 for i in 110:
  await physics_frame
  var ch:Dictionary=host.get_meta("puncture29_channel",{})
  var now:=Time.get_ticks_usec();peak=maxf(peak,float(ch.get("cut_depth",0.)))
  rows.append({"tick":i,"wall_usec":now-last_usec,"depth":ch.get("cut_depth",0),"part":ch.get("part",""),"tip":str(preload("res://scripts/combat/puncture29.gd").tip_world(host)),"player":str(host._player.position),"velocity":str(host._player.velocity),"contact":host.clay_last_contact28.duplicate(true),"solid":solid.last_contact.duplicate(true),"armor":host._armor_contact31.last.duplicate(true),"bore_reject":solid.bore_reject31.duplicate(true),"guide":host._sword_puncture_resistance29.last.duplicate(true),"solver_usec":solid.last_solver_usec,"recovery":solid.recovery_attempts})
  collar_negative35();last_usec=now
  if i==65 and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/"+label+".png")
 move("preview_move_forward",0.);button(false)
 outcomes.append({"label":label,"peak":peak,"rows":rows})
func run():
 root.size=Vector2i(1280,720);root.title="QA35 real face entry"
 await probe("sword_run",0,Vector2.ZERO,"light")
 
 checks.actual_sprint_deep_entry=outcomes.back().peak>.15
 checks.collar_probe_ran=collar_checked
 var passed:=true
 for result in checks.values():passed=passed and result
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"outcomes":outcomes},"  "))
 host=null;solid=null
 if is_instance_valid(current_scene):
  var old:=current_scene;current_scene=null;old.queue_free()
 await frames(4);quit()
