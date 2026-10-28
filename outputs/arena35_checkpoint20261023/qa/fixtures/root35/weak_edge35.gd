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
var sword_torso:bool=false
var pattern_index:int=-1
var advance:bool=false
var queue_trace:Array=[]
var first_qualified_usec:int=-1
var first_queued_usec:int=-1
var first_committed_usec:int=-1
var last_queue_state:String="idle"
var queued_part:String=""
var committed_parts:Array=[]
var seen_cuts:int=0
var started_usec:int=0
var expected_family:String="any"
var plate_guard:bool=false
var weak_edge:bool=false
var plate_contacts:int=0
var blocked_plate_contacts:int=0
var plate_bypass:bool=false
var queued_armor:Dictionary={}
var committed_jobs:Array=[]
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
  if a=="--sword-torso":sword_torso=true
  if a.begins_with("--pattern="):pattern_index=int(a.trim_prefix("--pattern="))
  if a=="--advance":advance=true
  if a=="--plate-guard":plate_guard=true
  if a=="--weak-edge":weak_edge=true
  if a.begins_with("--expected-cut-family="):expected_family=a.trim_prefix("--expected-cut-family=")
 run.call_deferred()
func button(value:bool):
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=value;Input.parse_input_event(e);Input.flush_buffered_events()
func motion(value:Vector2):
 var e:=InputEventMouseMotion.new();e.relative=value;e.screen_relative=value;Input.parse_input_event(e);Input.flush_buffered_events()
func frames(count:int):
 for i in count:
  await process_frame
  await create_timer(0).timeout
  observe()
func move(value:float):
 var e:=InputEventAction.new();e.action=&"preview_move_right";e.pressed=value>0;e.strength=value;Input.parse_input_event(e);Input.flush_buffered_events()
func forward(value:bool):
 var e:=InputEventAction.new();e.action=&"preview_move_forward";e.pressed=value;e.strength=1.0 if value else 0.0;Input.parse_input_event(e);Input.flush_buffered_events()
func observe():
 if not is_instance_valid(current_scene) or not current_scene.get("lab_ready"):return
 var host:Node=current_scene.lab
 var async_cut:RefCounted=host._async_cut28
 var state:String=async_cut.state
 var contact:Dictionary=host.clay_last_contact28
 var armor:Dictionary=contact.get("armor",{})
 if str(armor.get("region",""))=="plate":
  plate_contacts+=1
  if not bool(armor.get("penetrates",true)):
   blocked_plate_contacts+=1
   if bool(contact.get("strong",false)):plate_bypass=true
 if last_queue_state=="idle" and state!="idle":
  var matched_contact:bool=str(contact.get("part",""))==str(async_cut.context.get("part","")) and str(contact.get("world_point",""))==str(async_cut.context.get("point",Vector3.INF))
  queued_armor=armor.duplicate() if matched_contact else {"region":"unobserved_queued_contact"}
  if matched_contact and str(armor.get("region",""))=="plate" and not bool(armor.get("penetrates",true)):plate_bypass=true
 var elapsed:int=Time.get_ticks_usec()-started_usec
 if bool(host.clay_last_contact28.get("strong",false)) and first_qualified_usec<0:first_qualified_usec=elapsed
 if async_cut.busy() and first_queued_usec<0:first_queued_usec=elapsed
 if async_cut.busy():queued_part=str(async_cut.context.get("part",queued_part))
 if host.clay_cuts>seen_cuts:
  committed_parts.append(queued_part)
  committed_jobs.append({"part":queued_part,"armor":queued_armor.duplicate(),"elapsed_usec":elapsed})
  if first_committed_usec<0:first_committed_usec=elapsed
  seen_cuts=host.clay_cuts
  if DisplayServer.get_name()!="headless":capture_commit.call_deferred()
 if state!=last_queue_state:
  queue_trace.append({"elapsed_usec":elapsed,"state":state,"part":queued_part,"cuts":host.clay_cuts,"grounded":host._sword_grounded,"selected":host._selected,"failure":async_cut.report.get("failure",""),"queue_wait_usec":async_cut.report.get("queue_wait_usec",0),"snapshot_usec":async_cut.report.get("snapshot_usec",0),"worker_usec":async_cut.report.get("worker_usec",0),"total_latency_usec":async_cut.report.get("total_latency_usec",0)})
  last_queue_state=state
func capture_commit():
 var camera:=Camera3D.new();current_scene.add_child(camera)
 var focus:Vector3=current_scene.lab._npc_body.global_position+Vector3.UP*.85
 camera.global_position=focus+Vector3(2.6,.65,1.15);camera.fov=48.;camera.look_at(focus);camera.make_current()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join("commit_side.png"))
 rows.append({"stage":"commit_side_capture","elapsed_usec":Time.get_ticks_usec()-started_usec,"since_commit_usec":Time.get_ticks_usec()-started_usec-first_committed_usec})
func run():
 root.size=Vector2i(1280,720);root.set_flag(Window.FLAG_NO_FOCUS,true);seed(34023)
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
 started_usec=Time.get_ticks_usec();seen_cuts=host.clay_cuts
 var strong_start:int=host.clay_cuts
 var strong_unresolved_start:int=helper.unresolved
 button(true)
 if sword_torso:
  for stroke:Dictionary in [{"input":Vector2(-10,4),"ticks":24},{"input":Vector2(20,0),"ticks":40}]:
   for tick in int(stroke.ticks):
    motion(stroke.input*amplitude);await physics_frame;await create_timer(0).timeout;observe()
    contacts.append({"frame":Engine.get_physics_frames(),"input":stroke.input,"contact":host.clay_last_contact28.duplicate(true),"cuts":host.clay_cuts,"solid_safe":helper._publish_safe,"solid":helper.last_contact.duplicate(true),"omega":host._omega})
 elif flicks:
  var patterns:Array=[{"aim":Vector2(-90,35),"flick":Vector2(180,0)},{"aim":Vector2(0,-80),"flick":Vector2(0,180)},{"aim":Vector2(-80,-70),"flick":Vector2(160,150)}]
  if pattern_index>=0:patterns=[patterns[pattern_index]]
  for pattern:Dictionary in patterns:
   motion(pattern.aim);await frames(60)
   if advance:forward(true)
   motion(pattern.flick)
   for tick in 36:
    await physics_frame;await create_timer(0).timeout;observe()
    contacts.append({"frame":Engine.get_physics_frames(),"input":pattern.flick,"contact":host.clay_last_contact28.duplicate(true),"cuts":host.clay_cuts,"solid_safe":helper._publish_safe,"solid":helper.last_contact.duplicate(true),"omega":host._omega})
   if advance:forward(false)
 else:
  for direction:Vector2 in [Vector2(-10,-2),Vector2(16,0),Vector2(-16,0),Vector2(0,-14),Vector2(0,17),Vector2(13,10)]:
   for tick in 24:
    motion(direction*amplitude);await physics_frame;await create_timer(0).timeout;observe()
    contacts.append({"frame":Engine.get_physics_frames(),"input":direction,"contact":host.clay_last_contact28.duplicate(true),"cuts":host.clay_cuts,"solid_safe":helper._publish_safe,"solid":helper.last_contact.duplicate(true),"omega":host._omega})
 button(false)
 var drain_until:int=Time.get_ticks_msec()+5000
 while host._async_cut28.busy() and Time.get_ticks_msec()<drain_until:await frames(1)
 await frames(5)
 checks["async_job_drained"]=not host._async_cut28.busy()
 if expected_family!="any":
  var matched:=false
  for part:String in committed_parts:
   matched=matched or (part in ["chest","pelvis"] if expected_family=="torso" else part.begins_with("upperarm") or part.begins_with("forearm") or part.begins_with("hand") or part.begins_with("thigh") or part.begins_with("shin") or part.begins_with("foot"))
  checks["actual_"+expected_family+"_sever"]=matched
  if expected_family=="torso":
   var canonical_commit:=false
   for event:Dictionary in host.lab_events:
    canonical_commit=canonical_commit or (bool(event.get("clay",false)) and bool(event.get("ok",false)) and str(event.get("part","")) in ["chest","pelvis"] and str(event.get("scope",""))=="_clay_torso" and int(event.get("debris_added",0))>0)
   checks["canonical_torso_geometry_commit"]=canonical_commit
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out.path_join("after_strong.png"))
  var camera:=Camera3D.new();scene.add_child(camera)
  var focus:Vector3=host._npc_body.global_position+Vector3.UP*.85
  camera.global_position=focus+Vector3(2.6,.65,1.15);camera.fov=48.;camera.look_at(focus);camera.make_current()
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out.path_join("after_strong_side.png"))
 if plate_guard:
  checks["actual_solid_plate_contact"]=plate_contacts>0
  checks["actual_nonpenetrating_plate_contact"]=blocked_plate_contacts>0
  checks["no_nonpenetrating_plate_bypass"]=not plate_bypass
  var attributed:=true
  for job:Dictionary in committed_jobs:attributed=attributed and str(job.armor.get("region",""))!="unobserved_queued_contact"
  checks["committed_armor_attribution"]=attributed
 elif weak_edge:
  var weak_edge_seen:=false;var peak_effective:=0.
  for row:Dictionary in contacts:
   var c:Dictionary=row.contact
   if not c.is_empty():
    peak_effective=maxf(peak_effective,float(c.get("effective_cutting_speed",0.)))
    weak_edge_seen=weak_edge_seen or (float(c.get("cutting_speed",0.))>.01 and float(c.get("edge_alignment",0.))>=.55)
  checks["actual_weak_sharp_edge"]=weak_edge_seen
  checks["weak_effective_speed_below_gate"]=peak_effective<2.6
  checks["weak_edge_zero_sever"]=host.clay_cuts==strong_start
  rows.append({"weak_edge_peak_effective":peak_effective})
 else:checks["strong_actual_sever"]=host.clay_cuts>strong_start
 checks["strong_no_invalid_pose"]=helper.unresolved==strong_unresolved_start
 checks["strong_grip_attached"]=helper.max_grip_error<.005
 checks["metadata_selection_after_sever"]=helper._skin_nodes(host)==host.call("_npc_skinned_meshes")
 rows.append({"stage":"fresh_scene_strong","cuts":host.clay_cuts-strong_start,"async":host.clay_last_async28,"status":helper.status()})
 finish()
func finish():
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"rows":rows,"tier":tier,"weapon":weapon,"contacts":contacts,"queue_trace":queue_trace,"first_qualified_usec":first_qualified_usec,"first_queued_usec":first_queued_usec,"first_committed_usec":first_committed_usec,"committed_parts":committed_parts,"committed_jobs":committed_jobs,"plate_contacts":plate_contacts,"blocked_plate_contacts":blocked_plate_contacts,"plate_bypass":plate_bypass,"events":current_scene.lab.lab_events,"audio":current_scene.lab.melee_audio_report31(),"scope":"Fresh scene, actual LMB and six directional mouse strokes14-17px. Player placement before input; no midstroke pose/contact injection."},"\t"))
 var old:Node=current_scene;current_scene=null;old.queue_free();await frames(4)
 quit(0 if passed else 1)
