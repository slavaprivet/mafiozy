extends "../homes58/observer_cycle58_v2.gd"
## Read native prepared guide coordinates before walking the distant route.
## This reconstructs the guide, not the full earlier physical scene trajectory.
var guide_started:=0

func _physics_process(delta:float)->void:
	if finished:return
	if not scene.preview_ready or scene.preview_population==null or not scene.preview_population.city_ready:
		if Time.get_ticks_usec()-started>90000000:finish_guide("city readiness deadline")
		return
	var daily:RefCounted=scene.preview_population.daily
	if daily==null:return
	for id:String in daily._lives:
		if not actors.has(id):capture(daily._lives[id],id)
	if finished:return
	Avoidance.refresh_scene(scene)
	for id:String in actors:actors[id].life._frame=Engine.get_physics_frames()
	if actors.size()!=10:
		if Time.get_ticks_usec()-started>120000000:finish_guide("owner acquisition deadline")
		return
	var actor:Dictionary=actors["resident_6"]
	var home:RefCounted=actor.home
	if guide_started==0:
		guide_started=Time.get_ticks_usec();cycle_started=guide_started
		check(home.begin({"kind":"home_sleep","source_id":"resident_6"}),"native assigned home begin")
		check(Engine.physics_ticks_per_second==60,"real60Hz",Engine.physics_ticks_per_second)
		evidence["start"]=vec(actor.body.global_position)
		if not home.active():finish_guide("home refused");return
	home.step(delta,actor.life._life())
	if not home.active() or home._visit==null or home._visit._drive==null:finish_guide("route retired");return
	var drive:RefCounted=home._visit._drive
	var guide:RefCounted=drive._guide
	if guide!=null and guide.status=="ready":
		var points:Array=[];var interiors:Array=[]
		var registry:RefCounted=scene.preview_homes58.registry58
		for index:int in guide._points.size():
			var point:Vector3=guide._points[index]
			var within:Array=[]
			for site:Node3D in scene.preview_homes58.current_sites():
				var slot:Dictionary=registry.assigned(str(site.beds58[0].source_id))
				if AABB(slot.bounds).has_point(point+Vector3.UP*.3):within.append(site.source_id)
			var row:Dictionary={"index":index,"point":vec(point),"inside_houses":within,"standing":drive._route.standing(point)}
			points.append(row)
			if not within.is_empty():interiors.append(row)
		evidence["guide_points"]=points;evidence["interior_checkpoints"]=interiors
		evidence["guide"]=guide.diagnostics();evidence["outer_target"]=vec(drive._target)
		evidence["native_physics_context"]=Engine.is_in_physics_frame()
		check(guide._points.size()>11,"guide includes original checkpoint11")
		check(interiors.is_empty(),"no inaccessible interior intermediate checkpoint",interiors)
		check(guide._home_rejections58>0 and guide._repaired30>0,"native existing radial repair used",guide.diagnostics())
		finish_guide();return
	if Time.get_ticks_usec()-guide_started>15000000:finish_guide("15s native guide deadline")

func finish_guide(reason:String="")->void:
	if finished:return
	finished=true;set_physics_process(false)
	if not reason.is_empty():check(false,reason)
	evidence.checks=checks;evidence.passed=checks.all(func(row:Dictionary)->bool:return row.ok)
	evidence["scope"]="isolated overlay guide repair; no full physical-home acceptance"
	var file:=FileAccess.open(out_path.path_join("GUIDE58.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"));file.close()
	get_tree().quit(0 if evidence.passed else 1)
