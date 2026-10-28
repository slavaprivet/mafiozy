extends SceneTree
const Wound=preload("res://scripts/combat/local_wound28.gd")
var out:String
var checks:Dictionary={}
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 run.call_deferred()
func run():
 root.size=Vector2i(1280,720)
 var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
 for i in 1200:
  if scene.get("lab_ready")==true:break
  await process_frame
 checks.ready=scene.get("lab_ready")==true
 if not checks.ready:quit(1);return
 var host:Node=scene.lab
 var controller:Node=Wound.new();controller.host=host;host.add_child(controller);controller._sync_actor()
 var rig:Skeleton3D=host._npc_rig
 var bone:int=rig.find_bone("chest");var rest:Transform3D=rig.get_bone_pose(bone)
 var count:=0;var hit_count:=0;var failures:Array=[];var max_point:=0.;var max_normal:=0.;var old_usec:=0;var new_usec:=0;var max_new:=0;var max_old:=0;var fallbacks:=0
 for angle in [0.,.12,-.16]:
  var pose:Transform3D=rest;pose.basis=rest.basis*Basis(Vector3.RIGHT,angle);rig.set_bone_pose(bone,pose);rig.force_update_all_bone_transforms()
  for part in ["chest","head","forearm_l","thigh_r"]:
   var center:Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone(part)).origin
   for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK,Vector3(1,0,1).normalized(),Vector3(-1,0,-1).normalized()]:
    for reach in [.06,.12,.22]:
     var point:Vector3=center+direction*reach
     var begun:=Time.get_ticks_usec();var legacy:Dictionary=controller._surface_point_legacy33(point,part);var old_elapsed:=Time.get_ticks_usec()-begun;old_usec+=old_elapsed;max_old=maxi(max_old,old_elapsed)
     begun=Time.get_ticks_usec();var current:Dictionary=controller._surface_point(point,part);var elapsed:=Time.get_ticks_usec()-begun;new_usec+=elapsed;max_new=maxi(max_new,elapsed)
     count+=1
     if controller.surface_query33.last.get("fallback",true):fallbacks+=1
     if legacy.is_empty()!=current.is_empty():failures.append({"part":part,"angle":angle,"point":point,"old":legacy,"new":current});continue
     if legacy.is_empty():continue
     hit_count+=1;var pe:float=Vector3(legacy.point).distance_to(current.point);var ne:float=Vector3(legacy.normal).distance_to(current.normal)
     max_point=maxf(max_point,pe);max_normal=maxf(max_normal,ne)
     if pe>.000001 or ne>.00001:failures.append({"part":part,"angle":angle,"point":point,"point_error":pe,"normal_error":ne,"old":legacy,"new":current})
 rig.set_bone_pose(bone,rest);rig.force_update_all_bone_transforms()
 checks.exhaustive_match=failures.is_empty();checks.actual_hits=hit_count>30;checks.no_cold_fallback=fallbacks==0
 var passed:bool=not checks.values().has(false)
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"queries":count,"hits":hit_count,"max_point_error":max_point,"max_normal_error":max_normal,"old_usec":old_usec,"new_usec":new_usec,"max_old_usec":max_old,"max_new_usec":max_new,"fallbacks":fallbacks,"failures":failures,"scope":"Exact unchanged legacy exhaustive nearest surface law versus BVH on actual loaded surfaces, four body parts, three explicit skeletal poses; not native combat."},"  "))
 current_scene=null;scene.queue_free();await process_frame;await process_frame;quit(0 if passed else 1)
