extends SceneTree
const Cut=preload("res://scripts/combat/async_cut28.gd")
const Budget=preload("res://scripts/combat/combat_work_budget31.gd")
const Anatomy=preload("res://scripts/combat/cut_anatomy28.gd")
var out:String
var samples:Array[float]=[]
var raw_frames:Array=[]
var previous:=0
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 run.call_deferred()
func run():
 root.size=Vector2i(1280,720)
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 change_scene_to_file("res://scenes/arena27.tscn")
 for i in 900:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
 var host:Node=current_scene.lab
 var helper:RefCounted=host._async_cut28
 var rig:Skeleton3D=host._npc_rig
 var point:Vector3=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("chest")).origin
 point.y-=.12
 var context:Dictionary=host._clay_prepare_cut28("chest",point,Vector3.RIGHT*6.,6.)
 var inputs:Array=[]
 for node:MeshInstance3D in helper._skinned_meshes29(host):
  var binds:Dictionary=host._npc_limb_bind_ids(node,context.scope,rig)
  if binds.is_empty():continue
  var plane:Plane=host._plane_in_local(node,context.plane)
  var transforms:Array[Transform3D]=host._cut_skin_transforms39(node,rig)
  var cached:Dictionary=helper.surface_cache29[node.mesh.get_instance_id()]
  var row={"surfaces":helper._cached_surfaces29(node.mesh),"binds":transforms,"part_binds":binds,"plane":plane,"keep_front":plane.distance_to(node.to_local(context.keep))>=0.,"transform":node.global_transform,"name":str(node.name),"visible":node.is_visible_in_tree()}
  if cached.has("posed") and cached.get("binds",[])==transforms:row.posed=cached.posed
  if cached.has("topology"):row.topology=cached.topology
  var contact_binds:=PackedInt32Array();contact_binds.resize(transforms.size());contact_binds.fill(-1)
  for bind in transforms.size():
   if node.skin!=null and bind<node.skin.get_bind_count():
    var bind_name:=node.skin.get_bind_name(bind)
    contact_binds[bind]=rig.find_bone(bind_name) if bind_name!=&"" else node.skin.get_bind_bone(bind)
  var names:=PackedStringArray()
  for bone in rig.get_bone_count():names.append(str(rig.get_bone_name(bone)))
  row.contact_binds=contact_binds;row.contact_names=names
  inputs.append(row)
 var normal:Vector3=context.plane.normal
 var u:=normal.cross(Vector3.UP if absf(normal.y)<.9 else Vector3.RIGHT).normalized()
 var frame={"u":u,"v":normal.cross(u).normalized(),"n":normal,"origin":normal*context.plane.d}
 var snapshot={"layers":inputs,"scope":context.scope,"frame":frame,"anatomy":Anatomy._anatomy(rig,frame),"moving":false,"shards":1}
 var armor:Node=host._npc_armor_visual31
 if is_instance_valid(armor):snapshot.rigid31=armor._rigid_cut31.snapshot(armor,context,host._clay_branches).inputs
 var owners:Array[RefCounted]=[]
 var running:Dictionary={}
 var results:Array=[]
 var completed:=0
 var errors:=0
 var begun:=Time.get_ticks_usec()
 var peak_threads:=0
 for i in 100:owners.append(RefCounted.new());Budget.enqueue(owners.back())
 for i in 90:await process_frame
 begun=Time.get_ticks_usec()
 previous=Time.get_ticks_usec()
 while completed<100 and Time.get_ticks_usec()-begun<120000000:
  await process_frame
  var now:=Time.get_ticks_usec();samples.append(float(now-previous)/1000.);raw_frames.append({"frame":Engine.get_process_frames(),"ms":float(now-previous)/1000.,"completed":completed,"active":running.size()});previous=now
  for id:int in running.keys():
   var thread:Thread=running[id]
   if thread.is_alive():continue
   var result:Dictionary=thread.wait_to_finish()
   if not result.get("ok",false):errors+=1
   results.append({"id":id,"ok":result.get("ok",false),"layers":result.get("layers",[]).size(),"worker_usec":result.get("profile",{}).get("worker_usec",0)})
   result.clear();running.erase(id);Budget.release(owners[id]);completed+=1
  for i in 100:
   if Budget.ready(owners[i]):
    var thread:=Thread.new()
    var before:=Time.get_ticks_usec()
    thread.start(Cut._work.bind(snapshot));running[i]=thread
    Budget.charge(Time.get_ticks_usec()-before)
  peak_threads=maxi(peak_threads,running.size())
 for id:int in running:
  running[id].wait_to_finish();Budget.release(owners[id])
 for owner in owners:Budget.release(owner)
 samples.sort()
 var checks={"all_100_real_cut_jobs":completed==100,"all_geometry_valid":errors==0,"global_threads_at_most_two":peak_threads<=2,"queue_drained":Budget.status().waiting==0 and Budget.status().active==0}
 var passed:=true
 for v in checks.values():passed=passed and bool(v)
 var stats={"frames":samples.size(),"p95_ms":samples[int(samples.size()*.95)],"p99_ms":samples[int(samples.size()*.99)],"max_ms":samples.back(),"elapsed_ms":float(Time.get_ticks_usec()-begun)/1000.}
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"profile":stats,"budget":Budget.status(),"results":results,"frames_raw":raw_frames,"scope":"100 simultaneous real full-body sever geometry jobs on one immutable authored NPC snapshot, including cut caps/rigid fittings and exact retained contact topology/BVH; shared two-job admission while arena renders. Does not upload/commit100 meshes, simulate100 AI actors, or destructible castle."},"  "))
 var old:Node=current_scene;current_scene=null;old.queue_free()
 for i in 5:await process_frame
 quit(0 if passed else 1)
