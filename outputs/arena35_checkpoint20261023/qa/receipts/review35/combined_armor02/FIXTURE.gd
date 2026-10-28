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
func armor_case(tier:String):
 await start_scene(0,.2,1.3,-.1)
 host.lab_armored=true;host.set_npc_armor31({"head":tier+"_head"})
 await ticks(5)
 var visual:Node=host._npc_armor_visual31
 var anchor:Node3D=visual._roots.head[0]
 var unit:float=visual._unit
 for spec in [{"name":"mouth","x":0.,"y":.08,"covered":false},{"name":"face","x":0.,"y":.40,"covered":tier=="heavy"},{"name":"crown","x":0.,"y":1.0,"covered":true},{"name":"eye","x":.22,"y":.60,"covered":false}]:
  var from:Vector3=anchor.to_global(Vector3(float(spec.x),float(spec.y),1.2)*unit)
  var to:Vector3=anchor.to_global(Vector3(float(spec.x),float(spec.y),-.4)*unit)
  var hits:Array=solid.skin_hits(host,from,to,"head")
  if hits.is_empty():
   outcomes.append({"tier":tier,"spec":spec,"no_skin":true});checks[tier+"_"+spec.name+"_has_skin"]=false;continue
  var at:Vector3=hits[0].point
  var velocity:Vector3=(to-from).normalized()*9.
  var armor:Dictionary=host._armor_contact31.evaluate(host,"head",at,velocity,hits[0].normal,"stab").duplicate(true)
  checks[tier+"_"+spec.name+"_coverage"]=bool(armor.protected)==bool(spec.covered)
  checks[tier+"_"+spec.name+"_penetration"]=bool(armor.penetrates)!=bool(spec.covered)
  outcomes.append({"tier":tier,"spec":spec,"point":at,"armor":armor})
func run():
 root.size=Vector2i(1280,720);root.title="QA35 actual head surfaces"
 for tier in ["light","medium","heavy"]:await armor_case(tier)
 const Armor=preload("res://scripts/combat/armor_damage31.gd")
 for region in ["cloth","mail","plate"]:
  for kind in ["stab","slice"]:
   checks[region+"_"+kind+"_hard_even_at_high_energy"]=not Armor.tissue_penetrates(region,kind,1000.)
 var passed:=true
 for result in checks.values():passed=passed and result
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"outcomes":outcomes},"  "))
 host=null;solid=null
 if is_instance_valid(current_scene):
  var old:=current_scene;current_scene=null;old.queue_free()
 await frames(4);quit(0 if passed else 1)
