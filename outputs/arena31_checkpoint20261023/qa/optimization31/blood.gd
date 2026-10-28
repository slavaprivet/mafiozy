extends SceneTree
const Budget=preload("res://scripts/combat/blood_budget31.gd")
var out:String
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 run.call_deferred()
func run():
 var world:=Node3D.new();root.add_child(world)
 var source=load("res://scripts/weapons/sword_prototype.gd")
 var hosts:Array[Node]=[]
 for i in 100:
  var host:Node=source.new();host._world=world;hosts.append(host)
 var checks={"frame_spawn_limit":true,"global_live_limit":true}
 var maximum_usec:=0
 for frame in 12:
  await process_frame
  var begun:=Time.get_ticks_usec()
  for host in hosts:host._spray_blood(Vector3.ZERO,Vector3.UP,20)
  maximum_usec=maxi(maximum_usec,Time.get_ticks_usec()-begun)
  var state:=Budget.status(world)
  checks.frame_spawn_limit=checks.frame_spawn_limit and state.spawned<=48
  checks.global_live_limit=checks.global_live_limit and state.live<=384
 checks.filled_global_pool=Budget.status(world).live==384
 var count:=0
 for host in hosts:count+=host._blood_count
 checks.real_nodes_match=count==384 and world.get_child_count()==384
 checks.topology_bounded=hosts[0]._blood_meshes[0].radial_segments==12 and hosts[0]._blood_meshes[0].rings==6
 for child in world.get_children():child.queue_free()
 for i in 2:await process_frame
 checks.cleanup_returns_capacity=Budget.available(world) and Budget.status(world).live==0
 for host in hosts:host.free()
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"max_100_emitters_usec":maximum_usec,"budget":Budget.status(world),"scope":"100 actual base combat hosts emit real MeshInstance blood drops. Global live/spawn limits and cleanup; no wound HP modified. Not 100 active AI simulation."},"  "))
 world.queue_free()
 for i in 3:await process_frame
 quit(0 if passed else 1)
