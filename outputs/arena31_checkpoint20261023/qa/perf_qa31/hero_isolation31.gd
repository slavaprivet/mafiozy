extends SceneTree
var out:String=""
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 run.call_deferred()
func signature(host:Node)->Dictionary:
 var rows:Dictionary={}
 for node:MeshInstance3D in host._npc_skinned_meshes():
  var source:Array=[]
  for surface in node.mesh.get_surface_count():
   var arrays:Array=node.mesh.surface_get_arrays(surface)
   source.append([arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_INDEX],arrays[Mesh.ARRAY_BONES],arrays[Mesh.ARRAY_WEIGHTS]])
  var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(var_to_bytes(source))
  rows[str(node.name)]={"geometry_sha256":digest.finish().hex_encode(),"visible":node.visible,"vertices":node.mesh.surface_get_array_len(0)}
 return rows
func run():
 root.size=Vector2i(1280,720);change_scene_to_file("res://scenes/arena27.tscn")
 for i in 600:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get("lab_ready")==true:break
 var scene:Node=current_scene;var host:Node=scene.lab;var initial:Dictionary=signature(host);var checks:Dictionary={"ready":scene.get("lab_ready")==true,"no_hero_mesh_on_npc":true}
 for name:String in initial:
  if name.begins_with("Hero"):checks.no_hero_mesh_on_npc=false
 if scene.get("hero_visual31")!=null:
  for tier:String in ["light","medium","heavy",""]:
   scene.hero_visual31.set_armor_tier(tier)
   await process_frame
   checks["npc_unchanged_playerarmor_"+tier]=signature(host)==initial
  scene.hero_visual31.set_gambeson(true);await process_frame
  checks["npc_unchanged_playerclothing"]=signature(host)==initial
  scene.hero_visual31.set_gambeson(false)
 for i in 120:await process_frame
 var passed:bool=true
 for v in checks.values():passed=passed and bool(v)
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"npc_geometry":initial,"npc_armor":host._npc_armor_loadout31},"  "))
 var old:Node=current_scene;current_scene=null;old.queue_free()
 for i in 4:await process_frame
 quit(0 if passed else 1)
