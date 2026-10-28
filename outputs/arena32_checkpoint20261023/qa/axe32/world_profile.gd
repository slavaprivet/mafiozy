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
 var profile:Array=load("res://scripts/combat/weapon_contact_profile29.gd").build(host)
 var middle:=false;var valid:=true;var blunt:=false
 for row:Dictionary in profile:
  var p:Vector3=row.local
  if row.sharp:
   valid=valid and absf(p.y-.17)<.00001
   if p.x>.30 and p.x<.38:middle=true
  if p.x<.1 and not row.sharp:blunt=true
 checks.full_center_edge=middle;checks.no_flat_false_sharp=valid;checks.wood_blunt=blunt
 var body:=StaticBody3D.new();body.collision_layer=1
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.006,.006,.004);shape.shape=box;body.add_child(shape)
 scene.add_child(body);body.global_position=Vector3(5.1,5,5.3)
 await ticks(3)
 var pose:=Transform3D(Basis.IDENTITY,Vector3(5,5,5))
 var sweep:Dictionary=axes.world_sweep32(pose,Vector3(0,0,.6))
 checks.thin_world_between_corner_rays=not sweep.is_empty() and float(sweep.fraction32)<.6
 checks.actual_native_normal=not sweep.is_empty() and Vector3(sweep.normal).length()>.9 and not sweep.unresolved_rest32
 pose.origin.z=5.3
 var overlap:Dictionary=axes.world_sweep32(pose,Vector3(0,0,.6))
 checks.initial_overlap_detected=not overlap.is_empty() and float(overlap.fraction32)==0
 checks.initial_overlap_normal=not overlap.is_empty() and Vector3(overlap.normal).length()>.9
 rows.append({"sweep":sweep,"overlap":overlap,"shapes":axes.world_shapes32.size(),"profile_samples":profile.size()})
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks,"rows":rows},"  "))
 current_scene=null;scene.queue_free();await ticks(4);quit(0 if not checks.values().has(false) else 1)
