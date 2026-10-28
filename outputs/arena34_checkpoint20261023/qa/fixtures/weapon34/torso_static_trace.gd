extends "torso_input.gd"
func start(z:float):
 await super.start(z)
 var previous:RefCounted=solid
 var replacement:RefCounted=load(get_script().resource_path.get_base_dir().path_join("static_trace.gd")).new()
 for property:Dictionary in previous.get_property_list():
  if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:replacement.set(property.name,previous.get(property.name))
 host.set("_solid_weapon29",replacement);solid=replacement
