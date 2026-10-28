extends SceneTree
const COUNTERS=["geometry_usec","sweep_usec","static_usec","ik_usec","prepare_usec","world_usec","geometry_builds","triangle_candidates","walk_usec","solver_usec"]
var out:String
var phase:String=""
var host:Node
var solid:RefCounted
var samples:Array=[]
var outcomes:Array=[]
var checks:Dictionary={}
var previous_usec:int=0
var previous_counters:Array=[]
var max_depth:float=0.0
var max_ratio:float=0.0
var observed_entry:bool=false
var observer_usec:int=0
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
func set_phase(value:String):
 phase=value;previous_usec=0;previous_counters.clear()
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
func puncture(label:String,weapon:int):
 await start_scene(weapon,.2 if weapon==0 else 0.,1.3,-.00814)
 set_phase(label+"_idle");await ticks(240)
 set_phase(label+"_aim");button(true);motion(Vector2(0,100));await ticks(60)
 set_phase(label+"_approach");move("preview_move_forward",.6);await ticks(240);move("preview_move_forward",0.)
 set_phase(label+"_hold");await ticks(180)
 set_phase(label+"_withdraw");move("preview_move_back",.6);await ticks(180);move("preview_move_back",0.);button(false)
 set_phase("")
 checks[label+"_actual_entry"]=observed_entry
 outcomes.append({"scenario":label,"actual_entry":observed_entry,"max_depth":max_depth,"max_ratio":max_ratio,"cuts":host.clay_cuts,"dead":host._npc_dead,"solid":solid.status(),"last_async":host.clay_last_async28})
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+label+"_final.png")
func stroke():
 button(true)
 for direction:Vector2 in [Vector2(-10,-2),Vector2(16,0),Vector2(-16,0),Vector2(0,-14),Vector2(0,17),Vector2(13,10)]:
  for tick in 24:motion(direction);await physics_frame
 button(false);await frames(30)
func sever():
 await start_scene(0,0.,-.75,-.1)
 var initial:int=host.clay_cuts
 set_phase("sever_first");await stroke()
 set_phase("sever_commit_settle");await ticks(180)
 var first:int=host.clay_cuts
 set_phase("sever_repeat");await stroke()
 set_phase("sever_repeat_settle");await ticks(180)
 set_phase("")
 checks["sever_first_actual_cut"]=first>initial
 outcomes.append({"scenario":"sever","first_cuts":first-initial,"repeat_additional_cuts":host.clay_cuts-first,"solid":solid.status(),"last_async":host.clay_last_async28})
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/sever_repeat_final.png")
func run():
 root.size=Vector2i(1280,720);root.title="QA31 independent frame profile"
 RenderingServer.frame_post_draw.connect(draw_sample)
 await puncture("sword",0)
 await puncture("spear",4)
 await sever()
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"outcomes":outcomes,"samples":samples,"columns":["phase","wall_usec","frame_interval_usec","physics_frame","last_solver_usec","committed_depth","cuts","unresolved","engine_process_sec","engine_physics_sec"]+COUNTERS,"observer_usec":observer_usec,"scope":"Native GUI InputEvents, actual render timestamps and scalar production counters. No geometry probes, deep trace, AudioEffectRecord or midstrike teleport. Initial setup per fresh scenario only. Repeated strike stays on same cut target. Engine cap60 is a controlled condition, not uncapped FPS. Sample count reported per phase; no 20frame FPS acceptance."},"  "))
 host=null;solid=null
 if is_instance_valid(current_scene):
  var old:=current_scene;current_scene=null;old.queue_free()
 await frames(4);quit(0 if passed else 1)
