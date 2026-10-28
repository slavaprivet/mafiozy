extends SceneTree
var out:String
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")
 run.call_deferred()
func run():
 var checks:Dictionary={}
 for path:String in ["res://scripts/weapons/hatchet_model32.gd","res://scripts/weapons/throwing_axe32.gd","res://scripts/weapons/sword_prototype.gd","res://scripts/weapons/preview_weapons.gd","res://scripts/weapons/walk_weapon_ui.gd","res://scripts/clay_target.gd"]:
  var script=load(path);checks[path]=script!=null and script.can_instantiate()
 FileAccess.open(out+"/RESULT.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not checks.values().has(false),"checks":checks}))
 await create_timer(.3).timeout
 quit(0 if not checks.values().has(false) else 1)
