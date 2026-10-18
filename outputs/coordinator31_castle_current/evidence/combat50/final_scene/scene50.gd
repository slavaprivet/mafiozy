extends SceneTree
var s: Node
var p: CharacterBody3D
var checks: Dictionary = {}
func _initialize():
 run.call_deferred()
func ticks(n: int):
 for i in n: await physics_frame
func key(code: int, pressed: bool):
 var e=InputEventKey.new(); e.physical_keycode=code; e.pressed=pressed; Input.parse_input_event(e)
func shot(label: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("D:/MafioziCombat31/merged50/final_scene/"+label+".png")
func run():
 s=load("res://scenes/castle.tscn").instantiate(); root.add_child(s); current_scene=s
 while not s.preview_ready: await process_frame
 p=s._player; await ticks(120)
 var gate_z:float=s.preview_castle.global_position.z+s.preview_castle.wall_half()
 var start:Vector3=p.global_position
 var outside:bool=OS.get_cmdline_user_args().has("--castle-start-outside=1")
 checks["side_matches_flag"]=start.z>gate_z+19.0 if outside else start.z<gate_z-20.0
 checks["grounded"]=p.is_on_floor()
 checks["startup_target"]=s._castle_spawn_target.z>gate_z+19.0 if outside else s._castle_spawn_target.z<gate_z-20.0
 checks["camera_alignment"]=absf(wrapf(p._camera_yaw-p._yaw_pivot.global_rotation.y,-PI,PI))<.001
 checks["catapult_stays_inside"]=s.preview_catapult._cart.global_position.z<gate_z
 await shot("gate_external")
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(640,360);Input.parse_input_event(click);await ticks(2);click.pressed=false;Input.parse_input_event(click);await ticks(2)
 key(KEY_W,true); await ticks(90); key(KEY_W,false)
 var walked:float=start.distance_to(p.global_position)
 checks["walked"]=walked>3.0
 checks["guard_released"]=s._castle_spawn_frames==0
 key(KEY_S,true);await ticks(90);key(KEY_S,false);await ticks(8)
 checks["still_grounded"]=p.is_on_floor()
 checks["field_present"]=is_instance_valid(s.preview_battlefield)
 checks["armor_equipment"]=s.get_node_or_null("CastleArmorEquipment")!=null
 checks["gate38"]=s.preview_castle.has_method("_build_gate_art38")
 # Review-only camera turn at the same physical player position, no actor teleport.
 p._camera_yaw=PI; p._update_camera_rotation();await ticks(15);await shot("siege_field")
 if DisplayServer.get_name()!="headless":
  var review=Camera3D.new();s.add_child(review);review.far=500;review.fov=75;review.global_position=Vector3(105,68,1158);review.look_at(Vector3(0,0,1010));review.make_current();await ticks(8);await shot("siege_wide")
 var ok:bool=true
 for value in checks.values():ok=ok and value
 var result={"passed":ok,"checks":checks,"start":str(start),"gate_z":gate_z,"walked_m":walked,"end":str(p.global_position),"outside_flag":outside}
 print("EXTERIOR_RESULT ",JSON.stringify(result))
 var target="D:/MafioziCombat31/merged50/final_scene/"+("graphical" if DisplayServer.get_name()!="headless" else ("outside" if outside else "default"))+"_RESULT.json"
 var f=FileAccess.open(target,FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 quit(0 if ok else 1)
