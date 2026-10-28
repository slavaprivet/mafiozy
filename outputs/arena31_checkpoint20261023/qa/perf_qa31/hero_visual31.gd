extends SceneTree
var out:String=""
var checks:Dictionary={}
var details:Dictionary={}
var graphical:bool=false
func _initialize():
 graphical=DisplayServer.get_name()!="headless"
 if graphical:DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 run.call_deferred()
func frames(n:int):
 for i in n:await process_frame
func run():
 root.size=Vector2i(1280,900);root.title="QA31 hero body and medieval wardrobe"
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.12,.145,.18);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.82,.86,1);env.ambient_light_energy=.55;environment.environment=env;world.add_child(environment)
 var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-32,-38,0);light.light_energy=1.25
 var actor=load("res://scripts/preview_player.gd").new();world.add_child(actor);actor.set_physics_process(false);actor.set_process(false)
 var rig:Skeleton3D=actor._pose_skeleton
 var before:Array=[]
 for bone in rig.get_bone_count():before.append(rig.get_bone_pose(bone))
 var transform:Transform3D=actor._visual.transform;var model_scale:float=actor._model_scale
 var helper=load("res://scripts/character/hero_medieval31.gd").new();world.add_child(helper)
 details["configure"]=helper.configure(actor)
 checks["configured"]=details.configure.get("ok",false)
 if not checks.configured:finish();return
 checks["rig_28_bones"]=rig.get_bone_count()==28
 var same:bool=true
 for bone in rig.get_bone_count():same=same and rig.get_bone_pose(bone)==before[bone]
 checks["rig_pose_unchanged"]=same
 checks["model_normalization_unchanged"]=actor._visual.transform==transform and actor._model_scale==model_scale
 var valid_weights:bool=true;var vertices:int=0;var weight_errors:Array=[]
 for mesh:MeshInstance3D in [helper.body,helper.gambeson,helper.trousers]:
  checks[str(mesh.name)+"_uses_original_skin"]=mesh.skin==helper._source.skin
  var arrays:Array=mesh.mesh.surface_get_arrays(0);var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  for id in arrays[Mesh.ARRAY_VERTEX].size():
   vertices+=1;var total:float=0.0
   for k in 4:
    var w:float=weights[id*4+k];total+=w;valid_weights=valid_weights and is_finite(w) and w>=0 and bones[id*4+k]>=0 and bones[id*4+k]<28
   if absf(total-1.0)>=.000032 and weight_errors.size()<8:weight_errors.append({"mesh":mesh.name,"id":id,"sum":total,"weights":weights.slice(id*4,id*4+4),"bones":bones.slice(id*4,id*4+4)})
   valid_weights=valid_weights and absf(total-1.0)<.000032
 checks["all_weights_valid_normalized"]=valid_weights
 checks["body_inside_original_clothing_bounds"]=helper._source.mesh.get_aabb().grow(.001).encloses(helper.body.mesh.get_aabb())
 checks["bare_default_no_gambeson"]=not helper.gambeson.visible and helper.body.visible and not helper._source.visible
 details["weight_tolerance"]=2.0/65535.0+.000001 # Godot ArrayMesh GPU UNORM16 weight packing.
 details["vertices_checked"]=vertices;details["weight_errors"]=weight_errors
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.95;camera.make_current()
 var center:Vector3=rig.to_global(Vector3(0,2.55,0))
 for state:String in ["bare_front","bare_side","bare_back","gambeson","light","medium","heavy","bare_restored"]:
  if state=="gambeson":helper.set_gambeson(true)
  elif state in ["light","medium","heavy"]:helper.set_gambeson(false);helper.set_armor_tier(state)
  elif state=="bare_restored":helper.set_armor_tier("");helper.set_gambeson(false)
  var offset:=Vector3(0,2.55,7)
  if state=="bare_side":offset=Vector3(6,2.55,3)
  if state=="bare_back":offset=Vector3(0,2.55,-7)
  camera.global_position=rig.to_global(offset);camera.look_at(center)
  light.global_position=camera.global_position+Vector3(1.3,2,0);light.look_at(center)
  await frames(4)
  if graphical:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out.path_join(state+".png"))
  details[state]=helper.snapshot()
 checks["armor_underlayer_automatic"]=details.heavy.gambeson_visible
 checks["bare_restored_without_old_fabric"]=not helper.gambeson.visible and not helper._source.visible and helper.body.visible
 helper.set_gambeson(true);helper.set_armor_tier("heavy");helper.set_armor_tier("")
 checks["preenabled_gambeson_restored"]=helper.gambeson.visible and helper.gambeson_enabled
 helper.set_gambeson(false)
 checks["equipment_snapshot_empty_after_clear"]=helper.equipped_snapshot().is_empty() and helper.speed_multiplier()==1.0
 await frames(120)
 finish()
func finish():
 var passed:bool=true
 for value in checks.values():passed=passed and bool(value)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"details":details,"scope":"Player-only generated skin/wardrobe bind invariance and rendered tier states; no combat input/physics changed."},"  "))
 var old:Node=current_scene;current_scene=null;old.queue_free();await frames(4)
 quit(0 if passed else 1)
