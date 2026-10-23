extends "torso_input.gd"
var all_negative:Dictionary={}
func start(z:float):
 if is_instance_valid(solid) and solid.get("negative34") is Dictionary:all_negative.merge(solid.get("negative34"))
 await super.start(z)
 var previous:RefCounted=solid
 var replacement:RefCounted=load(get_script().resource_path.get_base_dir().path_join("static_negative.gd")).new()
 for property:Dictionary in previous.get_property_list():
  if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:replacement.set(property.name,previous.get(property.name))
 host.set("_solid_weapon29",replacement);solid=replacement
func run():
 await super.run()
 var result:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("RESULT.json")))
 result.checks.merge(all_negative)
 result.checks.negative_exercised=all_negative.size()==15
 var passed:=true
 for value in result.checks.values():passed=passed and bool(value)
 result.passed=passed;result.scope="Real InputEvent torso strike plus supplemental rejection oracles at its exact static fallback. Test-only state is restored before valid production dispatch."
 FileAccess.open(out.path_join("RESULT.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 quit(0 if passed else 1)
