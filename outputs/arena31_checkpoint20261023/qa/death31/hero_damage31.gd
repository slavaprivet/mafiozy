extends SceneTree
var out:String
var checks:Dictionary={}
var states:Array=[]
var incoming:bool=false
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
  if arg=="--incoming":incoming=true
 run.call_deferred()
func frames(n:int):
 for i in n:await process_frame
func run():
 root.size=Vector2i(1280,720)
 uv2_check()
 for path:String in ["res://scripts/character/hero_wound31.gd","res://scripts/character/hero_medieval31.gd","res://scripts/weapons/sword_prototype.gd"]:
  var script=load(path);checks[path]=script!=null and script.can_instantiate()
 if false in checks.values():finish();return
 for mode:String in ["bare","gambeson","heavy"]:
  change_scene_to_file("res://scenes/arena27.tscn")
  for i in 600:
   await process_frame
   if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
  var scene:Node=current_scene;var host:Node=scene.lab;var hero:Node=scene.hero_visual31
  checks[mode+"_ready"]=scene.lab_ready
  if not scene.lab_ready:continue
  scene._player.position=Vector3(9,.05,10);scene._player.velocity=Vector3.ZERO
  if mode=="gambeson":hero.set_gambeson(true)
  if mode=="heavy":hero.set_armor_tier("heavy")
  await frames(4)
  if mode=="gambeson" and not incoming:
   scene._lab_equip(6);await frames(20)
   var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_RIGHT;press.pressed=true;Input.parse_input_event(press);Input.flush_buffered_events()
   var turn:=InputEventMouseMotion.new();turn.relative=Vector2(30,-20);turn.screen_relative=turn.relative;Input.parse_input_event(turn);Input.flush_buffered_events()
   await frames(20)
   checks["shield_with_gambeson_equipped"]=host._shield_worn and host._shield.visible and hero.gambeson.visible
   checks["shield_with_gambeson_clear"]=float(host._shield_control31.last.get("clearance_m",-1))>=.008
   checks["shield_with_gambeson_grip"]=float(host._shield_control31.last.get("grip_error",1))<.005
   press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_RIGHT;press.pressed=false;Input.parse_input_event(press);Input.flush_buffered_events()
   host.drop_shield_to_ground31();scene._lab_equip(0);await frames(5)
  var mesh:MeshInstance3D=hero.gambeson if hero.gambeson.visible else hero.body
  var arrays:Array=host._cut_skin_arrays39(mesh.mesh.surface_get_arrays(0),host._cut_skin_transforms39(mesh,host._rig),false)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var center:Vector3=host._rig.global_transform*host._rig.get_bone_global_pose(host._rig.find_bone("chest")).origin
  var desired:Vector3=center+host._rig.global_basis.z.normalized()*.15
  var point:=Vector3.ZERO;var best:float=INF
  for p:Vector3 in vertices:
   var world:Vector3=mesh.to_global(p);var distance:float=world.distance_squared_to(desired)
   if distance<best:best=distance;point=world
  var hp:float=host._sparring_hp
  if mode=="heavy":
   # Central plate fixture: explicit real part and centered Hit chest coordinate.
   host._apply_player_damage(2.0,center,Vector3.FORWARD,"flat","chest",null,Vector3.BACK,1.0)
   checks["blocked_plate_no_open_wound"]=hero.wounds.hits==0
  else:
   if incoming:
    var bow:Node=scene.preview_bow_prototype
    var arrow:Node3D=bow._take_arrow()
    var from:Vector3=point+host._rig.global_basis.z.normalized()*2.0+Vector3.UP*.03
    var aim:Vector3=(point-from).normalized()
    arrow.visible=true;arrow.global_transform=bow._basis_z_along(from,aim)
    var previous_hits:int=bow._incoming_player_hits31
    bow._arrows.append({"node":arrow,"velocity":aim*28.0,"prev":from,"prev_tip":from+aim*bow.ARROW_TIP_OFFSET31,"alive":true,"stuck":false,"age":0.0,"incoming":true,"fired_ms":Time.get_ticks_msec()})
    for tick in 90:
     await physics_frame
     if bow._incoming_player_hits31>previous_hits:break
    checks[mode+"_actual_projectile_contact"]=bow._incoming_player_hits31==previous_hits+1
    states.append({"mode":mode,"projectile_parent":str(arrow.get_parent().name) if is_instance_valid(arrow) else "gone","projectile_position":arrow.global_position if is_instance_valid(arrow) else Vector3.ZERO,"arrow_state":bow._arrows.back() if not bow._arrows.is_empty() else {}})
   else:host._apply_player_arrow_damage31(2.0,point,-host._rig.global_basis.z.normalized())
   checks[mode+"_arrow_hp_damage"]=host._sparring_hp<hp
   checks[mode+"_arrow_surface_wound"]=hero.wounds.hits==1
   checks[mode+"_arrow_on_visible_upper_surface"]=str(hero.wounds.last.get("node",""))==str(mesh.name)
   host._apply_player_damage(1.0,point,Vector3.RIGHT,"slice","chest",null,Vector3.LEFT,1.0)
   checks[mode+"_blade_surface_wound"]=hero.wounds.hits==2
   var visible:bool=hero.gambeson.visible
   for code:Key in [KEY_F10,KEY_F11]:
    for down:bool in [true,false]:
     var key_event:=InputEventKey.new();key_event.keycode=code;key_event.physical_keycode=code;key_event.pressed=down;Input.parse_input_event(key_event);Input.flush_buffered_events()
    checks[mode+"_injury_notice_"+str(code)]=str(scene.lab_notice).contains("F5")
   checks[mode+"_injured_toggle_cannot_heal"]=hero.gambeson.visible==visible
   checks[mode+"_original_template_hidden"]=not hero._source.visible
   var selected:Array=host._npc_skinned_meshes(host._rig)
   checks[mode+"_hidden_templates_excluded"]=not selected.has(hero._source) and not selected.has(hero.body if visible else hero.gambeson)
   if DisplayServer.get_name()!="headless":
    var camera:=Camera3D.new();scene.add_child(camera)
    camera.global_position=point+host._rig.global_basis.z.normalized()*1.7+Vector3.UP*.20
    camera.look_at(point);camera.make_current()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out.path_join(mode+"_wound.png"))
   var bone:int=host._rig.find_bone("forearm_l")
   var parent:int=host._rig.find_bone("upperarm_l")
   var at:Vector3=host._rig.global_transform*host._rig.get_bone_global_pose(bone).origin
   var proximal:Vector3=host._rig.global_transform*host._rig.get_bone_global_pose(parent).origin
   var normal:Vector3=(at-proximal).normalized()
   var done:bool=host.npc_cut_body(Plane(normal,normal.dot(at)),proximal,"forearm_l",false,host._rig)
   checks[mode+"_real_mesh_sever"]=done
   checks[mode+"_wound_material_survives_cut"]=mesh.mesh!=null and mesh.mesh.surface_get_material(0) is ShaderMaterial
  states.append({"mode":mode,"hero":hero.snapshot(),"hp":host._sparring_hp})
  var old:Node=current_scene;current_scene=null;old.queue_free();await frames(8)
 finish()
func finish():
 var passed:bool=not false in checks.values()
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"states":states,"scope":"Existing accepted blade damage and real MeshSever API; optional incoming mode launches a real simulated arrow and awaits actual player collision. Not a natural enemy melee acceptance."},"  "))
 quit(0 if passed else 1)

func uv2_check():
 var mesh:=BoxMesh.new();var source:Array=mesh.get_mesh_arrays()
 var positions:PackedVector3Array=source[Mesh.ARRAY_VERTEX]
 var uv2:=PackedVector2Array()
 for p:Vector3 in positions:uv2.append(Vector2(p.z+p.x*.3,p.y*.7))
 source[Mesh.ARRAY_TEX_UV2]=uv2
 var result=preload("res://scripts/weapons/mesh_sever.gd").cut_surfaces28([source],Plane(Vector3(1,.2,.1).normalized(),.03))
 var worst:float=0.0;var count:int=0
 for arrays:Array in result.front_arrays+result.back_arrays:
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var values:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
  if values.size()!=points.size():worst=INF;continue
  for i in points.size():
   worst=maxf(worst,values[i].distance_to(Vector2(points[i].z+points[i].x*.3,points[i].y*.7)));count+=1
 checks["uv2_cut_interpolates_original_coordinates"]=count>0 and worst<.00001
