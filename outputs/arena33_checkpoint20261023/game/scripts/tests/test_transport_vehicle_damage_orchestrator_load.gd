extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Orchestrator=preload("res://scripts/transport/transport_vehicle_damage_orchestrator.gd")
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func _p(values: Array[float],fraction: float) -> float:
	var copy:=values.duplicate(); copy.sort()
	return copy[clampi(int(ceil((copy.size()-1)*fraction)),0,copy.size()-1)] if not copy.is_empty() else 0.0
func _sample(frames: int) -> Array[float]:
	var samples: Array[float]=[]
	for frame in frames:
		await physics_frame
		samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	return samples
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var ground:=StaticBody3D.new(); ground.collision_layer=1; world.add_child(ground)
	var shape:=CollisionShape3D.new(); shape.shape=BoxShape3D.new(); shape.shape.size=Vector3(100,.5,100); shape.position.y=-.25; ground.add_child(shape)
	for frame in 120: await physics_frame
	var base: Array[float]=await _sample(120)
	var memory_before:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var catalog:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var row: Dictionary={}
	for item: Dictionary in Bindings.load_oracle().rows:
		if item.profile_id=="city_hatchback": row=item; break
	var physical: Dictionary={"mass_kg":18.0,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08}
	var visuals: Array=[]; var adapters: Array=[]; var authority:=RefCounted.new()
	var configure_us: Array[int]=[]
	for i in 10:
		var loaded:=Visual.instantiate_visual(catalog.entries.city_hatchback,catalog.base_path)
		if not loaded.ok: failures.append("visual "+str(i)); break
		var visual: RefCounted=loaded.visual; visuals.append(visual); world.add_child(visual.root)
		visual.root.position=Vector3((i%5)*10,2.5,(i/5)*10)
		var adapter:=Orchestrator.new(); adapters.append(adapter)
		var start:=Time.get_ticks_usec()
		var configured: Dictionary=adapter.configure(authority,"hatch-"+str(i),1,visual,row,world,physical)
		configure_us.append(Time.get_ticks_usec()-start)
		if not configured.ok or configured.assemblies!=10: failures.append("configure "+str(i)+" "+str(configured)); break
	var memory_configured:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var prewarm_frames:=0; var prewarm_frame_us: Array[int]=[]
	while failures.is_empty() and prewarm_frames<120:
		var all_ready:=true; var start:=Time.get_ticks_usec()
		for adapter in adapters:
			if not adapter._debris.stats().ready:
				all_ready=false
				if not adapter.prewarm_step(1).ok: failures.append("prewarm")
		prewarm_frame_us.append(Time.get_ticks_usec()-start)
		if all_ready: break
		prewarm_frames+=1; await physics_frame
	if prewarm_frames>=120: failures.append("prewarm timeout")
	for frame in 120: await physics_frame
	var prepared: Array[float]=await _sample(120)
	var memory_prepared:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var launch_us: Array[int]=[]
	if failures.is_empty():
		for i in adapters.size():
			var adapter=adapters[i]
			var base_receipt: Dictionary={"authority":authority,"vehicle_id":"hatch-"+str(i),"life_generation":1,"revision":1,"kind":"rpg","event_id":"blast-"+str(i),"damage":1.0,"prior_hp":240.0,"prior_explosions":0}
			if not adapter.accept(base_receipt).ok: failures.append("damage "+str(i)); break
			var phase_rows: Array=[]; var draw_groups: Array=[]
			for part: Dictionary in row.explosion:
				phase_rows.append({"source_index":part.source_index,"source":visuals[i].nodes[part.key],"outcome":"copy"})
				draw_groups.append({"source_index":part.source_index,"draws":[.5,.5,.5,.5,.5,.5,.5],"signed_speed_mps":0.0,"travel_yaw_native":0.0})
			var phase: Dictionary={"authority":authority,"vehicle_id":"hatch-"+str(i),"life_generation":1,"revision":2,"phase":"post_char_callback_glass","char_applied":true,"callback_completed":true,"glass_applied":true,"rows":phase_rows}
			var step: Dictionary={"authority":authority,"vehicle_id":"hatch-"+str(i),"life_generation":1,"revision":2,"kind":"step","dt":0.0,"prior_hp":0.0,"prior_explosions":0,"phase_receipt":phase,"draw_groups":draw_groups}
			var start:=Time.get_ticks_usec(); var result: Dictionary=adapter.accept(step); launch_us.append(Time.get_ticks_usec()-start)
			if not result.ok or result.bodies!=10: failures.append("blast "+str(i)+" "+str(result)); break
	for frame in 120: await physics_frame
	var awake: Array[float]=await _sample(120)
	var memory_awake:=Performance.get_monitor(Performance.MEMORY_STATIC)
	for adapter in adapters:
		if not adapter.retire_wreck().ok or not adapter.bodies().is_empty(): failures.append("wreck cleanup")
		adapter.dispose()
	for visual in visuals: visual.dispose()
	world.free()
	print("TRANSPORT_DAMAGE_ORCHESTRATOR_LOAD ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cars":adapters.size(),"physical_pieces":adapters.size()*10,"configure_total_us":configure_us.reduce(func(a,b): return a+b,0),"configure_max_us":configure_us.max() if not configure_us.is_empty() else 0,"prewarm_frames":prewarm_frames,"prewarm_frame_max_us":prewarm_frame_us.max() if not prewarm_frame_us.is_empty() else 0,"launch_max_us":launch_us.max() if not launch_us.is_empty() else 0,"physics_baseline_p50_ms":_p(base,.5),"physics_baseline_p95_ms":_p(base,.95),"physics_prepared_p50_ms":_p(prepared,.5),"physics_prepared_p95_ms":_p(prepared,.95),"physics_awake_p50_ms":_p(awake,.5),"physics_awake_p95_ms":_p(awake,.95),"static_memory_before_bytes":memory_before,"static_memory_configured_bytes":memory_configured,"static_memory_prepared_bytes":memory_prepared,"static_memory_awake_bytes":memory_awake,"scope":"ten real hatchbacks, headless local fixture; not full-city or LIVE FPS"}))
	quit(0 if failures.is_empty() else 1)
