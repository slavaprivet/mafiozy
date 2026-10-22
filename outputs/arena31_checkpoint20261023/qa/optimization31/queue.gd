extends SceneTree
const Budget=preload("res://scripts/combat/combat_work_budget31.gd")
var out:String
var checks:Dictionary={}
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 run.call_deferred()
func frames(n:int):
 for i in n:await process_frame
func blockers()->Array[RefCounted]:
 var result:Array[RefCounted]=[]
 for i in 2:
  var block:=RefCounted.new();Budget.enqueue(block)
  while not Budget.ready(block):await process_frame
  result.append(block)
 return result
func point(host:Node)->Vector3:
 var rig:Skeleton3D=host._npc_rig
 return rig.global_transform*rig.get_bone_global_pose(rig.find_bone("chest")).origin-Vector3.UP*.12
func run():
 root.size=Vector2i(1280,720)
 change_scene_to_file("res://scenes/arena27.tscn")
 for i in 900:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
 var host:Node=current_scene.lab
 host.lab_regrow=false
 var hold:Array[RefCounted]=await blockers()
 var initial:int=host.clay_cuts
 var initial_point:=point(host)
 checks.accepted_waiting=host._clay_queue_slice28("chest",initial_point,Vector3.RIGHT*6.,6.)
 await frames(5)
 checks.no_premature_cut=host.clay_cuts==initial and host._async_cut28.state=="waiting"
 var offset:Vector3=host._clay_plane.normal*.30
 host._npc_body.global_position+=offset
 for blocker in hold:Budget.release(blocker)
 for i in 600:
  await process_frame
  if not host._async_cut28.busy():break
 checks.committed_after_admission=host.clay_cuts==initial+1
 checks.plane_follows_material=absf(host._clay_plane.distance_to(initial_point+offset))<.0001
 checks.old_world_plane_not_used=absf(host._clay_plane.distance_to(initial_point))>.1
 host.lab_reset();await frames(15)
 hold=await blockers();initial=host.clay_cuts
 checks.second_waiting=host._clay_queue_slice28("chest",point(host),Vector3.RIGHT*6.,6.)
 await frames(3);host.lab_reset();await frames(10)
 checks.reset_cancels=not host._async_cut28.busy() and host.clay_cuts==initial
 for blocker in hold:Budget.release(blocker)
 await frames(4)
 checks.no_slot_leak=Budget.status().active==0 and Budget.status().waiting==0
 # An abandoned admitted owner cannot permanently consume global capacity.
 var dead:=RefCounted.new();Budget.enqueue(dead)
 while not Budget.ready(dead):await process_frame
 dead=null
 var live:=RefCounted.new();Budget.enqueue(live);await process_frame
 checks.abandoned_active_reclaimed=Budget.ready(live) and Budget.status().active==1
 Budget.release(live)
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"budget":Budget.status(),"scope":"Actual queued cut, native actor transform changes while blocked, plane follows material, async atomic commit, reset cancels waiting job, no leaked admission slots. Geometry API rather than weapon input."},"  "))
 var old:Node=current_scene;current_scene=null;old.queue_free();await frames(4)
 quit(0 if passed else 1)

