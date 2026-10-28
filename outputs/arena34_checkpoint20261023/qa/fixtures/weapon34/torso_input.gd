extends "strong_input.gd"
func run():
 root.size=Vector2i(1280,720)
 var torso_cuts:=0
 for down:float in [0.,4.,8.,12.]:
  await start(-.45)
  var before:int=host.clay_cuts
  var count:int=solid.contacts
  button(true)
  for tick in 24:motion(Vector2(-10,down));await physics_frame
  for tick in 40:
   motion(Vector2(20,0));await physics_frame
   if count!=solid.contacts:
    var c:Dictionary=solid.last_contact;var clay:Dictionary=host.clay_last_contact28
    rows.append({"aim_down":down,"tick":tick,"contact":c.duplicate(true),"clay":clay.duplicate(true)})
    count=solid.contacts
  button(false);await frames(90)
  var committed:Array=[]
  for event:Dictionary in host.lab_events:
   if event.get("clay",false) and event.get("ok",false):
    committed.append(event.get("part",""))
    if str(event.get("part","")) in ["chest","pelvis"]:torso_cuts+=1
  scenarios.append({"down":down,"cuts":host.clay_cuts-before,"committed_parts":committed,"last_async":host.clay_last_async28,"unresolved":solid.unresolved})
  if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(out.path_join("down_%d.png"%down))
 checks["actual_torso_cut"]=torso_cuts>0
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":torso_cuts>0,"checks":checks,"rows":rows,"scenarios":scenarios,"scope":"Actual LMB side windup then horizontal cut; setup only before input."},"\t"))
 if is_instance_valid(current_scene):
  var old:=current_scene;current_scene=null;old.queue_free()
 await frames(5);quit(0 if torso_cuts>0 else 1)
