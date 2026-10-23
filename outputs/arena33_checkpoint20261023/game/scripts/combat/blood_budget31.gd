extends RefCounted
## Cosmetic drops are shared-budgeted across the world; wound damage is separate.
const LIVE_LIMIT := 384
const SPAWN_PER_FRAME := 48
static var worlds:Dictionary={}
static func _state(world:Node)->Dictionary:
 var id:=world.get_instance_id()
 if not worlds.has(id) or worlds[id].owner.get_ref()!=world:
  for key in worlds.keys():
   if worlds[key].owner.get_ref()==null:worlds.erase(key)
  worlds[id]={"owner":weakref(world),"drops":[],"frame":-1,"spawned":0,"peak_live":0}
 var state:Dictionary=worlds[id]
 var frame:=Engine.get_process_frames()
 if state.frame!=frame:
  state.frame=frame;state.spawned=0
  for i in range(state.drops.size()-1,-1,-1):
   var drop:Node=state.drops[i].get_ref()
   if not is_instance_valid(drop) or drop.is_queued_for_deletion():state.drops.remove_at(i)
 return state
static func available(world:Node)->bool:
 var state:=_state(world)
 return state.drops.size()<LIVE_LIMIT and state.spawned<SPAWN_PER_FRAME
static func track(world:Node,drop:Node)->void:
 var state:=_state(world)
 state.drops.append(weakref(drop));state.spawned+=1
 state.peak_live=maxi(state.peak_live,state.drops.size())
static func status(world:Node)->Dictionary:
 var state:=_state(world)
 return {"live":state.drops.size(),"spawned":state.spawned,"peak_live":state.peak_live,"limit":LIVE_LIMIT,"spawn_limit":SPAWN_PER_FRAME}
