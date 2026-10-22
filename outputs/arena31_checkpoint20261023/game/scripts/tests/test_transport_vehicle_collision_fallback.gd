extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Fallback=preload("res://scripts/transport/transport_vehicle_collision_fallback.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func _base(host: RefCounted,frame: Transform3D) -> Dictionary:
	return {"authority":host,"vehicle_id":"real-hatch","life_generation":1,"before":{"speed":10.0,"travelYaw":0.0,"yaw":1.2},"after":{"bumped":true,"speed":4.0,"contact":null},"source_object_world":frame,"source_object_rotation_y":2.1}
func _reply(host: RefCounted,ticket: RefCounted,hits: Array) -> Dictionary:
	return {"authority":host,"vehicle_id":"real-hatch","life_generation":1,"ticket":ticket,"raycast_complete":true,"hits":hits}
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.ok,"actual hatch imported for source pose")
	if not loaded.ok: finish({}); return
	var visual: RefCounted=loaded.visual; world.add_child(visual.root)
	visual.root.global_transform=Transform3D((Basis(Vector3.UP,.4)*Basis(Vector3.RIGHT,.27)*Basis(Vector3.FORWARD,-.16)).scaled(Vector3(1.1,.92,1.03)),Vector3(7,2.8,-4))
	var frame: Transform3D=visual.root.global_transform
	var host:=RefCounted.new(); var wrong_host:=RefCounted.new()
	var helper:=Fallback.new(); check(helper.configure(host,"real-hatch",1),"host capability/lifetime")
	var request:=_base(host,frame)
	var wrong:=request.duplicate(true); wrong.authority=wrong_host
	check(not helper.plan(wrong).ok,"wrong host denied")
	wrong=request.duplicate(true); wrong.after.bumped=false
	check(helper.plan(wrong).action=="none","not bumped returns false without raycast")
	var direct: Dictionary={"point":"authored","normal":"untouched"}
	wrong=request.duplicate(true); wrong.after.contact=direct
	var direct_result: Dictionary=helper.plan(wrong)
	check(direct_result.action=="direct_contact" and direct_result.contact_source==direct,"explicit after.contact forwarded without fallback")
	for false_contact: Variant in [false,0,""]:
		wrong=request.duplicate(true); wrong.after.contact=false_contact
		var false_plan: Dictionary=helper.plan(wrong)
		check(false_plan.ok and false_plan.action=="raycast","falsy after.contact uses source fallback")
		if false_plan.get("ok",false): helper.cancel_pending(false_plan.ticket)
	var start:=Time.get_ticks_usec(); var plan: Dictionary=helper.plan(request); var plan_us:=Time.get_ticks_usec()-start
	check(plan.ok and plan.action=="raycast" and plan.impact_speed_mps==6.0,"source abs speed loss")
	var center: Vector3=frame*Vector3(0,.75,0)
	check(plan.center_source.distance_to(center)<.000001 and center.distance_to(frame.origin+Vector3(0,.75,0))>.01,"full localToWorld center honors roll/pitch/scale")
	check(plan.normal_source==Vector3.BACK and plan.ray_origin_source.distance_to(center+Vector3.BACK*4)<.000001 and plan.ray_direction_source==Vector3.FORWARD and plan.ray_near_m==0.0 and plan.ray_far_m==5.0,"zero travelYaw wins over yaw/rotation; +Z source ray")
	var hits: Array=[
		{"point_source":center+Vector3(1,0,0),"distance_m":.3,"object_visible":false,"direct_scalar_material_transparent":false},
		{"point_source":center+Vector3(2,0,0),"distance_m":.6,"object_visible":true,"direct_scalar_material_transparent":true},
		{"point_source":center+Vector3(3,0,0),"distance_m":1.2,"object_visible":true,"direct_scalar_material_transparent":false},
		{"point_source":center+Vector3(4,0,0),"distance_m":1.5,"object_visible":true,"direct_scalar_material_transparent":false}]
	var bad:=_reply(host,plan.ticket,hits.duplicate(true)); bad.hits[2].distance_m=.1
	check(helper.resolve_raycast(bad).get("error")=="raycast_order_or_range","unsorted host hits rejected without consuming ticket")
	bad=_reply(wrong_host,plan.ticket,hits)
	check(not helper.resolve_raycast(bad).ok,"forged raycast receipt rejected")
	var resolved: Dictionary=helper.resolve_raycast(_reply(host,plan.ticket,hits))
	check(resolved.ok and resolved.used_hit and resolved.contact_source.point==hits[2].point_source and resolved.contact_source.normal==Vector3.BACK and resolved.contact_source.impactSpeed==6.0 and resolved.contact_source.slideSpeed==0.0,"first visible nontransparent hit chosen after recursive raycast")
	check(not helper.resolve_raycast(_reply(host,plan.ticket,hits)).ok,"one-use raycast ticket")
	wrong=request.duplicate(true); wrong.before.travelYaw=null; wrong.before.yaw=PI/2; wrong.before.speed=-10.0; wrong.after.speed=-4.0
	var reverse: Dictionary=helper.plan(wrong)
	check(reverse.ok and reverse.normal_source.distance_to(Vector3.LEFT)<.000001 and reverse.impact_speed_mps==6.0,"reverse sign with yaw fallback")
	var fallback_hit: Dictionary=helper.resolve_raycast(_reply(host,reverse.ticket,[{"point_source":center,"distance_m":1.0,"object_visible":false,"direct_scalar_material_transparent":false}]))
	check(fallback_hit.ok and not fallback_hit.used_hit and fallback_hit.contact_source.point.distance_to(center+Vector3.LEFT*2)<.000001,"no eligible hit uses center+normal*2")
	wrong=request.duplicate(true); wrong.before.travelYaw=null; wrong.before.yaw=null; wrong.source_object_rotation_y=.4
	var rotation_fallback: Dictionary=helper.plan(wrong)
	check(rotation_fallback.ok and rotation_fallback.normal_source.distance_to(Vector3(sin(.4),0,cos(.4)))<.000001,"object.rotation.y final nullish fallback")
	check(helper.cancel_pending(rotation_fallback.ticket),"aborted host raycast releases ticket")
	wrong=request.duplicate(true); wrong.before.travelYaw=NAN
	check(not helper.plan(wrong).ok,"present but invalid yaw does not fall through nullish chain")
	wrong=request.duplicate(true); wrong.before.speed=2.0; wrong.after.speed=8.0
	var gain: Dictionary=helper.plan(wrong)
	check(gain.ok and gain.impact_speed_mps==0.0,"speed gain clamps lost to zero")
	check(helper.cancel_pending(gain.ticket),"cancel speed-gain request")
	var bench_ok:=true; start=Time.get_ticks_usec()
	for i in 5000:
		var proposed: Dictionary=helper.plan(request)
		if not proposed.get("ok",false): bench_ok=false; break
		if not helper.resolve_raycast(_reply(host,proposed.ticket,[])).get("ok",false): bench_ok=false; break
	var plan_resolve_5000_us:=Time.get_ticks_usec()-start
	check(bench_ok,"5000 source fallback plans and empty host ray receipts")
	helper.dispose(); visual.dispose(); world.free()
	finish({"plan_us":plan_us,"plan_resolve_5000_us":plan_resolve_5000_us,"actual_glb":"city_hatchback"})
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_COLLISION_FALLBACK ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"source +Z fallback math with actual hatch transform; host performs recursive geometry raycast"}))
	quit(0 if failures.is_empty() else 1)
