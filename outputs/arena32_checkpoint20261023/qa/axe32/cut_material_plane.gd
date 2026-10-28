extends SceneTree
var out:String
var checks:Dictionary={}
var rows:Array=[]
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 run.call_deferred()
func ticks(n:int):
 for i in n:await physics_frame;await create_timer(0).timeout
func run():
 root.size=Vector2i(1280,720)
 change_scene_to_file("res://scenes/arena27.tscn")
 for i in 600:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
 var scene:Node=current_scene
 var host:Node=scene.lab
 var axes:Node=host._hatchet32
 host.set_weapon("hatchet");await ticks(3)
 host.lab_regrow=false;host.lab_armored=false;host.set_npc_armor31({});await ticks(4)
 var from:=Vector3(0,1.,-.8);var direction:=Vector3.FORWARD
 var ray:Dictionary=axes.contact.ray(host,host._world.get_world_3d().direct_space_state,from,from+direction*2.,1,axes.projectile_exclusions())
 var hit:Dictionary=ray.get("hit",{})
 checks.actual_clothing_contact=hit.get("actual_skin31",false)
 var hp:float=host._npc_hp
 var wounds:int=host.clay_local_wounds28
 var item:Dictionary=axes.pool[0]
 if not hit.is_empty():
  item.state="flying";item.velocity=direction*23.;item.damage_done=false
  var basis:=Basis(Vector3.UP,direction,Vector3.UP.cross(direction))
  item.node.global_transform=Transform3D(basis,Vector3(hit.position)-basis*Vector3(.34,.17,0))
  axes.impact(item,hit,Vector3(.34,.17,0))
 var rig:Skeleton3D=host._npc_rig
 var bone:int=item.skin_bone31
 var frame:Transform3D=rig.global_transform*rig.get_bone_global_pose(bone)
 var stored:Vector3=frame*Vector3(item.skin_hit_local31)
 var outer:Vector3=hit.position
 var body_entry:Vector3=axes.volume.last.get("body_entry32",outer)
 checks.reached_real_body=not axes.volume.last.get("accessory_only32",true) and item.depth>float(axes.volume.last.get("body_entry_gap32",INF))
 checks.stored_actual_body_material=stored.distance_to(body_entry)<.00001
 checks.body_differs_from_garment=stored.distance_to(outer)>.01
 var plane:=Plane(direction,(outer+body_entry)*.5)
 var poses:Array=[]
 for index in rig.get_bone_count():poses.append(rig.get_bone_global_pose(index))
 var context:Dictionary={"scope":"chest","rig_snapshot31":rig.global_transform,"bone_poses31":poses,"plane":plane,"keep":outer,"branches31":{}}
 checks.actual_material_detaches=axes.contact.detached_by_cut(item,rig,context)
 var old:Dictionary=item.duplicate();old.skin_hit_local31=frame.affine_inverse()*outer
 checks.outer_accessory_counterexample=not axes.contact.detached_by_cut(old,rig,context)
 rows.append({"scope":"actual measured contact+impact API; independent cut plane BETWEEN garment/body, not a natural swing claim","stored":stored,"outer":outer,"body":body_entry,"volume":axes.volume.last})
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"rows":rows},"  "))
 current_scene=null;scene.queue_free();await ticks(4);quit(0 if not checks.values().has(false) else 1)
