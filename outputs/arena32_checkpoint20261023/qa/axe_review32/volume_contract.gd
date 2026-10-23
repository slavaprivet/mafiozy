extends SceneTree
const Volume=preload("res://scripts/weapons/hatchet_volume32.gd")
class FakeSolid extends RefCounted:
 var rows:Array[Dictionary]=[]
 func skin_hits_detailed32(_host:Node,_a:Vector3,_b:Vector3,_part:String)->Array[Dictionary]:return rows
class Host extends Node3D:
 var _world:Node3D
 var _solid_weapon29:RefCounted
var out:String
var checks:Dictionary={}
var details:Dictionary={}
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 run.call_deferred()
func box(x:float,depth:float)->Dictionary:
 var points:=PackedVector3Array([Vector3(x,0,0),Vector3(x,1,0),Vector3(x,1,1),Vector3(x,0,1),Vector3(x+depth,0,0),Vector3(x+depth,1,0),Vector3(x+depth,1,1),Vector3(x+depth,0,1)])
 var faces:Array=[Vector3i(0,2,1),Vector3i(0,3,2),Vector3i(4,5,6),Vector3i(4,6,7),Vector3i(0,1,5),Vector3i(0,5,4),Vector3i(1,2,6),Vector3i(1,6,5),Vector3i(2,3,7),Vector3i(2,7,6),Vector3i(3,0,4),Vector3i(3,4,7)]
 return {"points":points,"bones":PackedInt32Array(),"weights":PackedFloat32Array(),"entry_faces31":faces}
func row(key:String,data:Dictionary,face:int,x:float,normal:Vector3)->Dictionary:
 if not data.has("hatchet_volume32"):data.hatchet_volume32=Volume.build_topology(data)
 return {"source_key":key,"source":{"data":data},"face":face,"point":Vector3(x,.5,.5),"raw_normal":normal}
func run():
 var volume=Volume.new()
 var data:=box(0,.02);var far:=box(.2,.1)
 var combined:Dictionary=data.duplicate(true)
 combined.points=data.points+far.points
 for face:Vector3i in far.entry_faces31:combined.entry_faces31.append(face+Vector3i(8,8,8))
 var entry:=row("disconnected",combined,0,0,Vector3.LEFT)
 var hits:Array[Dictionary]=[row("cloth",box(.004,.001),2,.005,Vector3.RIGHT),row("disconnected",combined,2,.02,Vector3.RIGHT),row("disconnected",combined,14,.3,Vector3.RIGHT)]
 var depth:float=volume.coherent_exit(entry,hits,Vector3.RIGHT)
 checks.nearest_coherent_exit_not_far_shell=absf(depth-.02)<.000001
 hits.remove_at(1)
 checks.disconnected_exit_refused=volume.coherent_exit(entry,hits,Vector3.RIGHT)==0.
 var open_data:=box(0,.1);open_data.entry_faces31=[open_data.entry_faces31[0],open_data.entry_faces31[1]]
 entry=row("open",open_data,0,0,Vector3.LEFT)
 var open_hits:Array[Dictionary]=[]
 checks.open_plane_no_exit=volume.coherent_exit(entry,open_hits,Vector3.RIGHT)==0.
 var folded:=box(0,.1);folded.entry_faces31=folded.entry_faces31.slice(0,6)
 entry=row("open_fold",folded,0,0,Vector3.LEFT)
 var folded_hits:Array[Dictionary]=[row("open_fold",folded,2,.1,Vector3.RIGHT)]
 depth=volume.coherent_exit(entry,folded_hits,Vector3.RIGHT)
 checks.open_connected_fold_not_proven_volume=depth==0.
 details.open_fold_depth=depth
 var world:=Node3D.new();root.add_child(world)
 var host:=Host.new();world.add_child(host);host._world=world
 var solid:=FakeSolid.new();host._solid_weapon29=solid
 var closed:=box(0,.1)
 solid.rows=[row("wallcase",closed,0,0,Vector3.LEFT),row("wallcase",closed,2,.1,Vector3.RIGHT)]
 var wall:=StaticBody3D.new();world.add_child(wall);wall.position=Vector3(.04,.5,.5)
 var collider:=CollisionShape3D.new();wall.add_child(collider);var shape:=BoxShape3D.new();shape.size=Vector3(.01,1,1);collider.shape=shape
 for i in 20:await physics_frame
 var excluded:Array[RID]=[]
 depth=volume.depth(host,{"position":Vector3(0,.5,.5),"part31":"chest"},Vector3.RIGHT,.08,excluded)
 checks.actual_world_caps_requested_depth=depth>.03 and depth<.034
 details.world_depth=depth;details.world_report=volume.last
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"details":details,"scope":"isolated volume contract; actual native wall ray, synthetic exact topology/hit DTOs; not a gameplay collision claim"},"  "))
 world.queue_free()
 for i in 8:await physics_frame
 quit(0 if not checks.values().has(false) else 1)
