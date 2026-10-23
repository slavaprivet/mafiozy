extends SceneTree
var out:String
var host:Node
var solid:RefCounted
var wall:StaticBody3D
var rows:Array=[]
var max_free:=0
var held_rows:=0
var invalid_rows:=0
var interrupted:=0
func _initialize():
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 create_timer(100).timeout.connect(func():quit(2))
 run.call_deferred()
func ticks(n:int):
 for i in n:await physics_frame
func button(value:bool):
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=value;Input.parse_input_event(event);Input.flush_buffered_events()
func motion(value:Vector2):
 var event:=InputEventMouseMotion.new();event.relative=value;event.screen_relative=value;Input.parse_input_event(event);Input.flush_buffered_events()
func move(value:float):
 var event:=InputEventAction.new();event.action="preview_move_forward";event.strength=value;event.pressed=value>0;Input.parse_input_event(event);Input.flush_buffered_events()
func observe():
 if not is_instance_valid(host):return
 var is_wall:bool=host._contact_plane_active and host._contact_rid==wall.get_rid()
 var count:int=solid._free_swing34.size()
 max_free=maxi(max_free,count)
 if is_wall:
  held_rows+=1
  if count!=0:invalid_rows+=1
 if solid._free_block_frame34==Engine.get_physics_frames():interrupted+=1
 rows.append({"frame":Engine.get_physics_frames(),"wall_plane":is_wall,"free_rows":count,"interrupted":solid._free_block_frame34==Engine.get_physics_frames(),"self_evaluations":host._self_pose_evaluations45,"omega":host._omega})
func run():
 root.size=Vector2i(1280,720);root.title="QA34 actual wall consumes sword run-up"
 var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
 while not scene.get("lab_ready"):await physics_frame
 host=scene.lab;host.lab_regrow=false;scene._lab_equip(0);solid=host._solid_weapon29
 wall=StaticBody3D.new();wall.name="LedgerWorldBarrier34";wall.set_meta("surface","wood");wall.collision_layer=1;wall.collision_mask=1
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3,2.8,.18);shape.shape=box;wall.add_child(shape)
 var mesh:=MeshInstance3D.new();var geometry:=BoxMesh.new();geometry.size=box.size;mesh.mesh=geometry;wall.add_child(mesh)
 scene.add_child(wall);wall.global_position=Vector3(0,1.4,-.9)
 var player:CharacterBody3D=scene._player;player.global_position=Vector3(0,.05,1.3);player.velocity=Vector3.ZERO;player._camera_yaw=0.;player._camera_pitch=-.1;player._update_camera_rotation();player.set_mouse_captured(true)
 await ticks(35)
 RenderingServer.frame_post_draw.connect(observe)
 button(true);motion(Vector2(0,100));await ticks(60)
 move(.6);await ticks(120);move(0.)
 for i in 100:
  motion(Vector2(3 if i<50 else -3,0));await physics_frame
 button(false)
 RenderingServer.frame_post_draw.disconnect(observe)
 var audio:Dictionary=host.melee_audio_report31()
 var checks:Dictionary={"actual_world_sweep":int(audio.events.get("wood",0))>0,"free_motion_was_recorded":max_free>0,"sustained_actual_wall_contact":held_rows>=20,"wall_never_banks_free_credit":invalid_rows==0,"real_contact_interrupt_observed":interrupted>0,"no_body_cut_behind_wall":host.clay_cuts==0}
 var passed:bool=not checks.values().has(false)
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"max_free_rows":max_free,"wall_draw_rows":held_rows,"invalid_wall_rows":invalid_rows,"interrupted_draw_rows":interrupted,"rows":rows,"audio":audio,"scope":"Actual mouse/walking InputEvents into pre-existing wall; native world sweep/material audio and RID-identified contact plane. No contact injection, no midstrike teleport; no general FPS claim."},"  "))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/wall_contact.png")
 host=null;solid=null;current_scene=null;scene.queue_free()
 for i in 5:await process_frame
 quit(0 if passed else 1)
