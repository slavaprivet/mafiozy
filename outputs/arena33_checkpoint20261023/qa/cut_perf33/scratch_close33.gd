extends "D:/MafioziCombat31/c33_coordination/agents/perf_qa31/gui_profile_nofocus.gd"
const Wound=preload("res://scripts/combat/local_wound28.gd")
const Puncture=preload("res://scripts/combat/puncture29.gd")
func run():
 root.size=Vector2i(1280,720);root.title="QA33 exact surface scratch cost"
 RenderingServer.frame_post_draw.connect(draw_sample)
 var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
 for i in 1200:
  if scene.get("lab_ready")==true:break
  await process_frame
 checks.startup=scene.get("lab_ready")==true
 if not checks.startup:quit(1);return
 host=scene.lab;host.lab_regrow=false;solid=host._solid_weapon29;host.set_meta("profile_cut31",true)
 var rig:Skeleton3D=host._npc_rig
 var center:Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("chest")).origin-Vector3.UP*.08
 var hits:Array[Dictionary]=Puncture._hits(host,"chest",center+Vector3.BACK,center+Vector3.FORWARD)
 checks.actual_skin_target=not hits.is_empty()
 if hits.is_empty():quit(1);return
 var point:Vector3=hits[0].point
 set_phase("scratch_idle")
 for i in 120:await RenderingServer.frame_post_draw
 var old_draw:int=previous_usec;set_phase("scratch_apply");previous_usec=old_draw
 var started:int=Time.get_ticks_usec()
 var result:Dictionary=Wound.apply(host,"chest",point,Vector3.RIGHT,Vector3.RIGHT,1.)
 var apply_usec:int=Time.get_ticks_usec()-started
 checks.real_visible_wound=result.get("ok",false) and result.get("created",false)
 await RenderingServer.frame_post_draw
 old_draw=previous_usec;set_phase("scratch_after");previous_usec=old_draw
 for i in 60:await RenderingServer.frame_post_draw
 set_phase("")
 root.get_texture().get_image().save_png(out+"/scratch.png")
 var close_camera:=Camera3D.new();scene.add_child(close_camera);close_camera.near=.01;close_camera.fov=45.
 close_camera.global_position=point+Vector3(0,.08,.65);close_camera.look_at(point,Vector3.UP);close_camera.make_current()
 for i in 20:await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/scratch_close.png")
 var controller:Node=host.get_meta("local_wound28_controller",null)
 started=Time.get_ticks_usec()
 var exact:Dictionary=controller._surface_point(point,"chest")
 var surface_usec:int=Time.get_ticks_usec()-started
 var passed:bool=not checks.values().has(false)
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"apply_usec":apply_usec,"surface_query_after_usec":surface_usec,"point":point,"surface_result":exact,"wound_profile":host.get_meta("wound_profile31",{}),"samples":samples,"columns":["phase","wall_usec","frame_interval_usec","physics_frame","last_solver_usec","committed_depth","cuts","unresolved","engine_process_sec","engine_physics_sec"]+COUNTERS,"scope":"Real surface first scratch API, phase attribution with live user process preserved; not clean FPS or native-input acceptance."},"  "))
 host=null;solid=null;current_scene=null;scene.queue_free();await frames(6);quit(0 if passed else 1)
