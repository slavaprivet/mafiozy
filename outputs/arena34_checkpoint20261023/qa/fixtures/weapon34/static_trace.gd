extends "res://scripts/combat/weapon_solid_contact29.gd"
func _dispatch(host:Node,hit:Dictionary,before:Transform3D,current:Transform3D)->Dictionary:
 if hit.get("overlap",false):
  var sample:Vector3=hit.sample_local
  var from:Vector3=before*sample;var to:Vector3=current*sample
  var exact:Dictionary=_segment(from,to)
  var probe:Dictionary=_segment(from,to+(to-from).normalized()*.00001)
  var profile_rows:Array=[]
  for row:Dictionary in Profile.build_edges(host):
   var a:Vector3=row.edge_from;var b:Vector3=row.edge_to
   var closest:=Geometry3D.get_closest_point_to_segment(sample,a,b)
   if closest.distance_squared_to(sample)<1e-10:profile_rows.append(row)
  hit.trace34={"from":from,"to":to,"actual_delta":to-from,"exact":exact.duplicate(true),"endpoint_10um_diagnostic":probe.duplicate(true),"authored_edges":profile_rows,"omega_before":host.get("_omega")}
 return super._dispatch(host,hit,before,current)
