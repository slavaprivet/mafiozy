extends "D:/MafioziCombat31/c33_coordination/agents/perf_qa31/gui_profile_nofocus.gd"
func run():
 root.size=Vector2i(1280,720);root.title="QA31 isolated rendered cut commit profile"
 RenderingServer.frame_post_draw.connect(draw_sample)
 var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
 for i in 1200:
  if scene.get("lab_ready")==true:break
  await process_frame
 checks.startup=scene.get("lab_ready")==true
 if not checks.startup:
  FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"checks":checks}));quit(1);return
 host=scene.get("lab");host.lab_regrow=false;solid=host.get("_solid_weapon29")
 set_phase("cut_idle")
 for i in 120:await RenderingServer.frame_post_draw
 var rig:Skeleton3D=host.get("_npc_rig")
 var point:Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("chest")).origin-Vector3.UP*.12
 var before:int=host.clay_cuts
 var previous_draw:int=previous_usec
 set_phase("cut_queue_through_commit")
 # Retain the preceding draw timestamp so synchronous queue time is included.
 previous_usec=previous_draw
 var start:int=Time.get_ticks_usec()
 checks.queue_accepted=host._clay_queue_slice28("chest",point,Vector3.RIGHT*6.,6.)
 var queue_usec:int=Time.get_ticks_usec()-start
 var committed_at:int=0
 for i in 600:
  await RenderingServer.frame_post_draw
  if host.clay_cuts>before:
   committed_at=Time.get_ticks_usec();break
 checks.actual_geometry_cut=host.clay_cuts==before+1
 previous_draw=previous_usec
 set_phase("cut_postcommit_60_draws")
 # The first postcommit frame may rebuild contact caches; never discard it.
 previous_usec=previous_draw
 for i in 60:await RenderingServer.frame_post_draw
 set_phase("")
 root.get_texture().get_image().save_png(out+"/cut_postcommit.png")
 var passed:bool=not checks.values().has(false)
 outcomes.append({"scenario":"isolated_geometry_cut","cuts":host.clay_cuts-before,"queue_call_usec":queue_usec,"queue_to_first_committed_draw_usec":committed_at-start if committed_at>0 else -1,"last_async":host.clay_last_async28,"solid":solid.status()})
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"outcomes":outcomes,"samples":samples,"columns":["phase","wall_usec","frame_interval_usec","physics_frame","last_solver_usec","committed_depth","cuts","unresolved","engine_process_sec","engine_physics_sec"]+COUNTERS,"observer_usec":observer_usec,"scope":"Identical direct real geometry queue API on frozen30/candidate31, chest bone minus12cm, RIGHT*6, speed6; unchanged initial arena/player placement, no weapon input and no forced geometry queries. Every rendered interval from queue through actual commit plus60draws. This isolates render/commit aftermath and is not weapon-input acceptance or 100fighter FPS."},"  "))
 host=null;solid=null;current_scene=null;scene.queue_free();await frames(6)
 quit(0 if passed else 1)
