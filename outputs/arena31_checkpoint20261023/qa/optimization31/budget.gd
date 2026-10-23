extends SceneTree
const Budget=preload("res://scripts/combat/combat_work_budget31.gd")
var out:String
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 run.call_deferred()
func run():
 var owners:Array[RefCounted]=[]
 var live:Dictionary={}
 var admitted:Array[int]=[]
 var checks={"bounded_workers":true,"single_snapshot_per_frame":true,"shared_upload_budget":true,"single_commit_per_frame":true}
 for i in 100:
  owners.append(RefCounted.new());Budget.enqueue(owners.back())
 var waited:=0
 while admitted.size()<100 or not live.is_empty():
  await process_frame;waited+=1
  if waited>1000:break
  for id:int in live.keys():
   if waited-live[id]<3:continue
   if not Budget.commit_allowed():continue
   Budget.charge(650);Budget.release(owners[id]);live.erase(id)
  for i in 100:
   if Budget.ready(owners[i]):
    admitted.append(i);live[i]=waited;Budget.charge(900)
  # Many actors compete for one frame's upload budget; denied tasks remain queued.
  for i in live:
   for j in 8:
    if Budget.available():Budget.charge(350)
  var state:=Budget.status()
  checks.bounded_workers=checks.bounded_workers and state.active<=2
  checks.single_snapshot_per_frame=checks.single_snapshot_per_frame and state.starts_this_frame<=1
  checks.shared_upload_budget=checks.shared_upload_budget and state.used_usec<3350
  checks.single_commit_per_frame=checks.single_commit_per_frame and state.commits_this_frame<=1
 checks.no_lost_requests=admitted.size()==100
 checks.fifo=admitted==range(100)
 checks.drained=Budget.status().active==0 and Budget.status().waiting==0
 var canceled:=RefCounted.new();Budget.enqueue(canceled);Budget.release(canceled)
 checks.cancel_releases_queue=Budget.status().waiting==0
 var abandoned:=RefCounted.new();Budget.enqueue(abandoned);abandoned=null
 var survivor:=RefCounted.new();Budget.enqueue(survivor)
 await process_frame
 checks.dead_owner_does_not_block=Budget.ready(survivor);Budget.release(survivor)
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"frames":waited,"budget":Budget.status(),"scope":"100 simultaneous scheduler requests with deterministic charged work; verifies global admission, FIFO, upload accounting and cancellation. NOT 100 rendered AI fighters or castle FPS."},"  "))
 quit(0 if passed else 1)
