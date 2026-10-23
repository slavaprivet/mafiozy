extends SceneTree
const H=preload("res://scripts/combat/weapon_interception31.gd")
var out:String
var checks:Dictionary={}
var rows:Array=[]
var host:Node
var bow:Node
func _initialize():
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 run.call_deferred()
func ticks(n:int):
 for i in n:await physics_frame
func key(code:int,down:bool):
 var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func aim_face(weapon:Node3D)->Dictionary:
 var candidates:Array=[]
 for reference:WeakRef in H._parts(weapon):
  var node:MeshInstance3D=reference.get_ref()
  if not is_instance_valid(node) or node.mesh==null or not node.is_visible_in_tree():continue
  var data:Dictionary=H._mesh_data(node.mesh)
  for triangle:Dictionary in data.triangles:
   var material:Material=node.get_active_material(triangle.surface)
   if not material is StandardMaterial3D or material.metallic<.5:continue
   var area:float=(Vector3(triangle.b)-Vector3(triangle.a)).cross(Vector3(triangle.c)-Vector3(triangle.a)).length()
   var point:Vector3=node.to_global((Vector3(triangle.a)+Vector3(triangle.b)+Vector3(triangle.c))/3.)
   var normal:Vector3=(node.global_basis.inverse().transposed()*Vector3(triangle.normal)).normalized()
   candidates.append({"point":point,"normal":normal,"area":area})
 candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.area)>float(b.area))
 for candidate:Dictionary in candidates:
  for side in [1.,-1.]:
   var normal:Vector3=candidate.normal*side
   var start:Vector3=candidate.point+normal*.24
   var end:Vector3=candidate.point-normal*.04
   if not bow._incoming_arrow_ray31(start,candidate.point,{"shooter_rid":RID()}).is_empty():continue
   var hit:=H.player_segment(host,start,end)
   if not hit.is_empty():return {"point":hit.point,"normal":normal,"start":start,"end":end}
 return {}
func launch(from:Vector3,direction:Vector3)->Dictionary:
 var arrow:Node3D=bow._take_arrow()
 var velocity:Vector3=direction.normalized()*40.
 var origin:Vector3=from-direction.normalized()*bow.ARROW_TIP_OFFSET31
 arrow.visible=true;arrow.global_transform=bow._basis_z_along(origin,velocity)
 var entry:Dictionary={"node":arrow,"velocity":velocity,"prev":origin,"prev_tip":from,"alive":true,"stuck":false,"age":0.,"incoming":true,"fired_ms":Time.get_ticks_msec()}
 bow._arrows.append(entry)
 var before:int=host._arrow_parries31
 bow._step_arrows(1./60.)
 var result:Dictionary={"parried":host._arrow_parries31>before,"incoming":entry.get("incoming",false),"deflected":entry.get("deflected",false),"stuck":entry.get("stuck",false),"velocity":entry.get("velocity"),"parries":host._arrow_parries31-before}
 bow._recycle(bow._arrows.find(entry))
 return result
func run():
 root.size=Vector2i(1280,720);root.title="QA31 physical weapon interception"
 var scene:Node=load("res://scenes/arena27.tscn").instantiate();root.add_child(scene);current_scene=scene
 while not scene.get("lab_ready"):await physics_frame
 host=scene.lab;host.lab_regrow=false
 bow=scene.get("preview_bow_prototype")
 if not is_instance_valid(bow):
  for node:Node in scene.get_children():
   if node.has_method("_step_arrows"):bow=node;break
 checks["bow_ready"]=is_instance_valid(bow)
 if not is_instance_valid(bow):await finish();return
 var player:Node=scene._player;player.global_position=Vector3(15,.05,6);player.velocity=Vector3.ZERO
 await ticks(30)
 for index in 5:
  scene._lab_equip(index);await ticks(30)
  var id:String=host._weapon_id
  var weapon:Node3D=host._sword
  host._arrow_parry_until_ms31=-1000
  var face:=aim_face(weapon)
  checks[id+"_authored_metal_face_found"]=not face.is_empty()
  if face.is_empty():continue
  var before_audio:int=host.melee_audio_report31().events.get("metal",0)
  var projectile:=launch(face.start,-Vector3(face.normal))
  checks[id+"_idle_actual_arrow_deflected"]=projectile.parried and projectile.deflected and not projectile.incoming
  checks[id+"_one_parry_event"]=projectile.parries==1
  checks[id+"_accepted_metal_sound"]=int(host.melee_audio_report31().events.get("metal",0))==before_audio+1
  # Outside the whole authored mesh AABB: a pass inside the old 11cm capsule
  # is still a near miss for a thin sword, while all weapons share the oracle.
  var bounds:=AABB();var first:=true
  for reference:WeakRef in H._parts(weapon):
   var node:MeshInstance3D=reference.get_ref()
   if not is_instance_valid(node) or node.mesh==null or not node.is_visible_in_tree():continue
   var local_bounds:AABB=(weapon.global_transform.affine_inverse()*node.global_transform)*node.mesh.get_aabb()
   bounds=local_bounds if first else bounds.merge(local_bounds);first=false
  var a:=weapon.to_global(Vector3(bounds.get_center().x,bounds.end.y+.035,bounds.position.z-.10))
  var b:=weapon.to_global(Vector3(bounds.get_center().x,bounds.end.y+.035,bounds.end.z+.10))
  checks[id+"_authored_near_miss"]=H.player_segment(host,a,b).is_empty()
  var miss:=launch(a,(b-a).normalized())
  checks[id+"_near_miss_arrow_not_parried"]=not miss.parried
  if index==0:
   # Actual player hit shape in front of steel must win, even though the same
   # longer segment subsequently intersects the displayed weapon surface.
   var body_case:Dictionary={}
   for body_height:float in [.5,.8,1.1,1.4]:
    var center:Vector3=player.global_position+Vector3.UP*body_height
    var direction:Vector3=(Vector3(face.point)-center).normalized()
    var start:Vector3=center-direction*.025
    var end:Vector3=face.point+direction*.04
    var body_ray:Dictionary=bow._incoming_arrow_ray31(start,end,{"shooter_rid":RID()})
    var steel:=H.player_segment(host,start,end)
    if body_ray.is_empty() or steel.is_empty() or body_ray.collider!=player:continue
    if start.distance_to(body_ray.position)+.001>=start.distance_to(steel.point):continue
    body_case={"start":start,"direction":direction,"part":"actual_player_capsule"};break
   checks["real_player_body_before_weapon_fixture"]=not body_case.is_empty()
   if not body_case.is_empty():
    var body_arrow:=launch(body_case.start,body_case.direction)
    checks["real_player_body_wins_before_weapon"]=not body_arrow.parried
  # Actual collider in front of the held surface must win the arrow's ray.
  var wall:=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.12,.12,.025);shape.shape=box;wall.add_child(shape);root.add_child(wall)
  wall.global_transform=Transform3D(Basis.looking_at(Vector3(face.normal),Vector3.UP if absf(Vector3(face.normal).dot(Vector3.UP))<.98 else Vector3.RIGHT),Vector3(face.start).lerp(Vector3(face.point),.5))
  await ticks(2)
  var wall_ray:Dictionary=bow._incoming_arrow_ray31(face.start,face.point,{"shooter_rid":RID()})
  checks[id+"_wall_fixture_between_launch_and_weapon"]=wall_ray.get("collider")==wall
  var blocked:=launch(face.start,-Vector3(face.normal))
  checks[id+"_nearer_wall_priority"]=not blocked.parried
  wall.queue_free();await ticks(2)
  # Controlled transform trajectory of the real NPC sword, resolved by the
  # production strike path. Previous samples come from the actual prior pose.
  # Separate independent arrow and sword blows beyond the90ms audio merge window.
  await ticks(6)
  var npc_weapon:Node3D=host._npc_sword
  var npc_saved:=npc_weapon.global_transform
  var npc_visible:=npc_weapon.visible
  npc_weapon.visible=true
  var strike_face:=aim_face(weapon)
  if not strike_face.is_empty():
   var normal:Vector3=strike_face.normal
   var axis:=normal.cross(Vector3.UP).normalized()
   if axis.length_squared()<.5:axis=normal.cross(Vector3.RIGHT).normalized()
   var side:=normal.cross(axis).normalized()
   npc_weapon.global_transform=Transform3D(Basis(axis,side,axis.cross(side)),Vector3(strike_face.start)-axis*.06)
   host._npc_blade_prev=host._npc_blade_points()
   host._npc_strike_had_hit=false;host._last_clash_ms=-10000
   var blocks_before:int=host._npc_blocked
   var audio_before:int=int(host.melee_audio_report31().events.get("metal",0))+int(host.melee_audio_report31().events.get("wood",0))
   npc_weapon.global_position-=normal*.28
   host._npc_resolve_strike(1./60.)
   checks[id+"_actual_npc_strike_intercepted"]=host._npc_blocked==blocks_before+1
   checks[id+"_npc_clash_material_audio_once"]=int(host.melee_audio_report31().events.get("metal",0))+int(host.melee_audio_report31().events.get("wood",0))==audio_before+1
  else:checks[id+"_actual_npc_strike_intercepted"]=false
  npc_weapon.global_transform=npc_saved;npc_weapon.visible=npc_visible
  host._npc_blade_prev=host._npc_blade_points()
  # Reverse direction: production player sweep vs the actual NPC blade.
  # This is a controlled mesh trajectory unit/integration test, not mouse input.
  var reverse_face:=aim_face(weapon)
  if not reverse_face.is_empty():
   var saved_weapon:=weapon.global_transform
   var saved_origin:Vector3=host._sword_origin
   var saved_dir:Vector3=host._dir
   var normal:Vector3=reverse_face.normal
   var axis:=normal.cross(Vector3.UP).normalized()
   if axis.length_squared()<.5:axis=normal.cross(Vector3.RIGHT).normalized()
   var side:=normal.cross(axis).normalized()
   npc_weapon.visible=true
   npc_weapon.global_transform=Transform3D(Basis(axis,side,axis.cross(side)),Vector3(reverse_face.point)-axis*.5)
   weapon.global_position-=normal*.1;host._sword_origin-=normal*.1
   if weapon.has_meta("interception_sweep31"):weapon.remove_meta("interception_sweep31")
   host._prev_points=PackedVector3Array()
   host._sweep(1./60.)
   host._last_clash_ms=-10000
   var blocks_before:int=host._player_blocks
   weapon.global_position+=normal*.2;host._sword_origin+=normal*.2
   var prior_query:Dictionary=weapon.get_meta("interception_sweep31",{}).duplicate()
   var actual_query:Dictionary=H.outgoing(host,1./60.)
   weapon.set_meta("interception_sweep31",prior_query)
   rows.append({"outgoing_weapon":id,"edge_usec":weapon.get_meta("interception_edge_usec31",0),"query":actual_query,"prior":prior_query,"eligible":H.eligible(host),"sword_origin":host._sword_origin,"mesh_transform":weapon.global_transform,"npc_transform":npc_weapon.global_transform,"previous_points":host._prev_points,"shield_resume_frame":host._shield_resume_frame29,"current_frame":Engine.get_physics_frames()})
   host._sweep(1./60.)
   checks[id+"_outgoing_actual_mesh_sweep_clash"]=host._player_blocks==blocks_before+1
   weapon.global_transform=saved_weapon;host._sword_origin=saved_origin;host._dir=saved_dir
   npc_weapon.global_transform=npc_saved;npc_weapon.visible=npc_visible
   host._prev_points=PackedVector3Array()
  else:checks[id+"_outgoing_actual_mesh_sweep_clash"]=false
  # Native G drop removes interception ownership; geometry still exists.
  key(KEY_G,true);key(KEY_G,false);await ticks(2)
  checks[id+"_drop_not_guard"]=host._sword_grounded and H.player_segment(host,face.start,face.end).is_empty()
  rows.append({"weapon":id,"projectile":projectile,"near_miss":miss,"wall":blocked,"audio":host.melee_audio_report31().events})
  scene._lab_equip(index);await ticks(10)
 await finish()
func finish():
 var passed:=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"rows":rows,"scope":"Native engine actual authored weapon models, real arrow pool + ballistic integrator + nearest physics ray and accepted parry callback. Deterministic projectile initial conditions; no forced contact or audio. Native G drop. Controlled actual NPC sword translation resolved by production strike callback, previous samples from actual prior pose; not natural AI or OS input. Geometry oracle used only to choose a metal face before launch. Not a player-aim skill test or OS input."},"  "))
 host=null;bow=null
 if is_instance_valid(current_scene):
  var old:=current_scene;current_scene=null;old.queue_free()
 await ticks(4);quit(0 if passed else 1)
