extends RefCounted
## Shared MAIN-THREAD admission/upload budget for every actor, not per-NPC limits.
const MAX_ACTIVE := 2
const MAIN_USEC := 3000
static var waiting:Array[WeakRef]=[]
static var active:Dictionary={}
static var frame := -1
static var used_usec := 0
static var starts := 0
static var commits := 0
static var peak_active := 0
static var peak_waiting := 0
static var peak_main_usec := 0
static func _frame()->void:
 var now:=Engine.get_process_frames()
 if frame==now:return
 peak_main_usec=maxi(peak_main_usec,used_usec)
 frame=now;used_usec=0;starts=0;commits=0
static func enqueue(owner:RefCounted)->void:
 for ref in waiting:
  if ref.get_ref()==owner:return
 waiting.append(weakref(owner));peak_waiting=maxi(peak_waiting,waiting.size())
static func ready(owner:RefCounted)->bool:
 _frame()
 for key in active.keys():
  if active[key].get_ref()==null:active.erase(key)
 while not waiting.is_empty() and waiting[0].get_ref()==null:waiting.pop_front()
 if waiting.is_empty() or waiting[0].get_ref()!=owner or active.size()>=MAX_ACTIVE or starts>=1 or used_usec>=MAIN_USEC:return false
 waiting.pop_front();active[owner.get_instance_id()]=weakref(owner);starts+=1
 peak_active=maxi(peak_active,active.size())
 return true
static func available()->bool:
 _frame();return used_usec<MAIN_USEC
static func commit_allowed()->bool:
 _frame()
 if commits>=1 or used_usec>=MAIN_USEC:return false
 commits+=1;return true
static func charge(usec:int)->void:
 _frame();used_usec+=maxi(0,usec);peak_main_usec=maxi(peak_main_usec,used_usec)
static func release(owner:RefCounted)->void:
 active.erase(owner.get_instance_id())
 for i in range(waiting.size()-1,-1,-1):
  if waiting[i].get_ref()==null or waiting[i].get_ref()==owner:waiting.remove_at(i)
static func status()->Dictionary:
 _frame()
 return {"waiting":waiting.size(),"active":active.size(),"max_active":MAX_ACTIVE,"main_budget_usec":MAIN_USEC,"used_usec":used_usec,"peak_active":peak_active,"peak_waiting":peak_waiting,"peak_main_usec":peak_main_usec,"starts_this_frame":starts,"commits_this_frame":commits}
