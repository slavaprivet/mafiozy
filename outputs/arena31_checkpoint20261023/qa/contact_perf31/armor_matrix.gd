extends SceneTree
var out:String
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 run.call_deferred()
func run():
 root.size=Vector2i(1280,720)
 var scene=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
 for tick in 120:
  if scene.get("lab_ready")==true:break
  await physics_frame
 var host:Node=scene.lab
 var collider:CollisionObject3D=host._solid_collider29("forearm_l")
 var shape:CollisionShape3D
 for child:Node in collider.get_children():
  if child is CollisionShape3D:shape=child;break
 var point:Vector3=shape.to_global(Vector3(shape.shape.size.x*.5,0,0))
 var normal:Vector3=shape.global_basis.x.normalized()
 var rows:Array=[];var checks:Dictionary={};var residuals:Array=[]
 for weapon:int in [0,2]:
  scene._lab_equip(weapon)
  for tier:String in ["none","light","medium","heavy"]:
   var equipment:Dictionary={}
   if tier!="none":
    for slot:String in ["head","torso","hands","legs","feet"]:equipment[slot]=tier+"_"+slot
   host._npc_armor_loadout31=equipment
   for speed:float in [.3,3.2,6.,10.5]:
    var law:Dictionary=host._armor_contact31.evaluate(host,"forearm_l",point,-normal*speed,normal,"slice")
    var can_sever:bool=law.penetrates and speed*float(law.speed_factor)>=host.CLAY_SEVER_SPEED28
    rows.append({"weapon":host._weapon_id,"tier":tier,"speed":speed,"law":law.duplicate(true),"sever_energy_gate":can_sever})
    if speed==3.2 and weapon==0:residuals.append(float(law.speed_factor))
    if tier=="none":checks["bare_exact_"+str(weapon)+"_"+str(speed)]=law.factor==1.0 and law.penetrates
    if tier=="heavy" and speed==.3:checks["heavy_weak_blocks_"+str(weapon)]=not law.penetrates
    if tier=="heavy" and speed==10.5:checks["heavy_very_strong_finite_"+str(weapon)]=can_sever
 checks.monotonic_resistance=residuals[0]>residuals[1] and residuals[1]>residuals[2] and residuals[2]>residuals[3]
 var profile:Array=preload("res://scripts/combat/weapon_contact_profile29.gd").build(host)
 var sharp:Array=[]
 for sample:Dictionary in profile:
  if sample.sharp:sharp.append(sample.local)
 checks.axe_real_ridge_end_positive=false;checks.axe_real_ridge_end_negative=false;checks.axe_no_flat_marked_sharp=true
 for ridge_point:Vector3 in sharp:
  if ridge_point.z>.017:checks.axe_real_ridge_end_positive=true
  if ridge_point.z<-.017:checks.axe_real_ridge_end_negative=true
  if absf(ridge_point.y-.210435)>.00001:checks.axe_no_flat_marked_sharp=false
 var result={"sharp_points":sharp,"passed":not checks.values().has(false),"checks":checks,"rows":rows,"scope":"Canonical actual actor forearm coverage and native impact formula at prescribed speeds. Energy-law oracle only; actual strikes tested separately."}
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 scene.queue_free();await process_frame;await process_frame;quit(0 if result.passed else 1)
