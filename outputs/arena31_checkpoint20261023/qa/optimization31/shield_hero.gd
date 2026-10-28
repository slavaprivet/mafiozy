extends SceneTree
var out:String
var checks:Dictionary={}
var rows:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 run.call_deferred()
func frames(n:int):
 for i in n:await process_frame
func button(down:bool):
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down
 Input.parse_input_event(e);Input.flush_buffered_events()
func motion(delta:Vector2):
 var e:=InputEventMouseMotion.new();e.relative=delta;e.screen_relative=delta
 Input.parse_input_event(e);Input.flush_buffered_events()
func capture(name:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(name+".png"))
func run():
 root.size=Vector2i(1280,720)
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 change_scene_to_file("res://scenes/arena27.tscn")
 for i in 600:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
 var scene:Node=current_scene
 var host:Node=scene.get("lab")
 var player:Node3D=scene.get("_player")
 player.global_position=Vector3(0,.05,2);player.set_mouse_captured(true)
 scene._lab_equip(6)
 for pressed in [true,false]:
  var wardrobe_key:=InputEventKey.new();wardrobe_key.keycode=KEY_F10;wardrobe_key.physical_keycode=KEY_F10;wardrobe_key.pressed=pressed
  Input.parse_input_event(wardrobe_key);Input.flush_buffered_events()
 await frames(3)
 checks.new_gambeson_visible=scene.hero_visual31.gambeson.visible and not scene.hero_visual31.body.visible
 await frames(40)
 var helper:RefCounted=host.get("_shield_control31")
 checks.equipped=host._shield_worn and host._shield.visible
 checks.rest_clear=float(helper.last.get("clearance_m",-1))>=.008
 rows.append({"stage":"rest","status":helper.last.duplicate()})
 var camera:=Camera3D.new();scene.add_child(camera);camera.fov=42
 camera.global_position=player.global_position+Vector3(1.5,1.3,-2.2)
 camera.look_at(player.global_position+Vector3(0,1.05,0));camera.make_current()
 await frames(2);await capture("shield_rest")
 button(true);await frames(35)
 checks.guard_steers=host.is_steering()
 var initial:Vector3=host._shield.global_basis.z
 var initial_yaw:float=player._visual.global_rotation.y
 var min_gap:=INF
 var worst_grip:=0.0
 var changed_pitch:=false
 var count:=0
 for delta:Vector2 in [Vector2(160,0),Vector2(-320,0),Vector2(160,-180),Vector2(0,360),Vector2(0,-180)]:
  motion(delta)
  for tick in 25:
   await process_frame
   min_gap=minf(min_gap,float(helper.last.get("clearance_m",-1)))
   worst_grip=maxf(worst_grip,float(helper.last.get("grip_error",1)))
   changed_pitch=changed_pitch or absf(host._shield.global_basis.z.y)>.10
  rows.append({"stage":count,"status":helper.last.duplicate(),"heading":player._visual.global_rotation.y})
  await capture("shield_guard_"+str(count))
  count+=1
 checks.aim_clear=min_gap>=.008
 checks.grip_attached=worst_grip<.001
 checks.vertical_aim=changed_pitch
 checks.horizontal_turn=absf(float(rows[1].heading)-initial_yaw)>.1
 checks.no_sword_attack=not host._held
 button(false);await frames(35)
 checks.released_clear=float(helper.last.get("clearance_m",-1))>=.008
 checks.release_stops_steering=not host.is_steering()
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"rows":rows,"min_gap_m":min_gap,"max_grip_error_m":worst_grip,"scope":"Actual shield equip and RMB/mouse InputEvents, final displayed shield bounds vs head/chest/spine proxies, exact hand attachment, horizontal body turn and vertical guard steering. Graphical captures supplement proxies."},"  "))
 var old:Node=current_scene;current_scene=null;old.queue_free();await frames(4)
 quit(0 if passed else 1)
