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
  item.state="flying";item.velocity=direction*8.;item.damage_done=false
  var basis:=Basis(Vector3.UP,direction,Vector3.UP.cross(direction))
  item.node.global_transform=Transform3D(basis,Vector3(hit.position)-basis*Vector3(.34,.17,0))
  axes.impact(item,hit,Vector3(.34,.17,0))
 checks.no_blood_wound_from_accessory=host.clay_local_wounds28==wounds
 checks.accessory_only=axes.volume.last.get("accessory_only32",false)
 checks.no_hp_from_unreached_body=is_equal_approx(hp,float(host._npc_hp))
 checks.no_reported_tissue_damage=float(axes.last.get("protection",{}).get("damage",-1))==0.
 checks.no_claimed_body_penetration=not axes.last.get("protection",{}).get("penetrates",true)
 rows.append({"scope":"direct actual-impact API at measured garment surface, 8m/s; not a native throw-speed claim","before_hp":hp,"after_hp":host._npc_hp,"volume":axes.volume.last,"event":axes.last})
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"rows":rows},"  "))
 current_scene=null;scene.queue_free();await ticks(4);quit(0 if not checks.values().has(false) else 1)
