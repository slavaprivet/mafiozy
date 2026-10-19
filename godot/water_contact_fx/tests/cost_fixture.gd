extends Node
const Fx = preload("res://water_contact_fx.gd")
const Sim = preload("res://water_contact_simulator.gd")
var water_record := {"level":0.0,"depth":1.0}
func _water(_x: float, _z: float) -> Dictionary: return water_record
func _random() -> float: return .4

static func _percentiles(samples: Array[int]) -> Dictionary:
	samples.sort()
	return {"frames":samples.size(),"p50_us":samples[int(samples.size()*.5)],"p95_us":samples[int(samples.size()*.95)],"max_us":samples[-1]}

func _ready() -> void:
	var fx := Fx.new(); add_child(fx); fx.setup({"waterAt":_water,"random":_random})
	var sim := Sim.new(); sim.configure({"waterAt":_water,"random":_random})
	var hero := {"id":"hero","position":{"x":0.0,"y":1.0,"z":0.0}}
	var input := {"hero":hero}
	var simulation_times: Array[int] = []; var total_times: Array[int] = []; var upload_times: Array[int] = []
	var memory_before := 0.0; var object_before := 0.0
	var peak_drops := 0; var peak_rings := 0; var peak_foam := 0; var peak_arcs := 0; var peak_samples := 0
	for i in range(960):
		hero.position.x = sin(i*.013)*2
		hero.position.y = 1.0 if i%12 == 0 else -.2
		if i == 160:
			memory_before = Performance.get_monitor(Performance.MEMORY_STATIC)
			object_before = Performance.get_monitor(Performance.OBJECT_COUNT)
		var sampled_before: int = fx.simulator.water_samples
		var start := Time.get_ticks_usec(); sim.update(1.0/60,input); var simulation_us := Time.get_ticks_usec()-start
		start = Time.get_ticks_usec(); fx.advance(1.0/60,input); var total_us := Time.get_ticks_usec()-start
		if i >= 160:
			simulation_times.append(simulation_us); total_times.append(total_us); upload_times.append(fx.last_upload_us)
		peak_samples = maxi(peak_samples,fx.simulator.water_samples-sampled_before)
		var st: Dictionary = fx.stats()
		peak_drops = maxi(peak_drops,st.activeDroplets); peak_rings = maxi(peak_rings,st.activeRings); peak_foam = maxi(peak_foam,st.activeFoam); peak_arcs = maxi(peak_arcs,st.ringSegments)
	var export_times: Array[int] = []
	var exported_max := 0
	for i in range(800):
		var started := Time.get_ticks_usec(); var exported: Array = fx.get_ripples()
		export_times.append(Time.get_ticks_usec()-started); exported_max = maxi(exported_max,exported.size())
	var output := {"status":"PASS","scenario":"one hero repeats source downward impact every 12 frames; infinite wet sampler; fixed dt1/60;160warmup+800measured; headless component CPU only",
		"simulation":_percentiles(simulation_times),"upload":_percentiles(upload_times),"combined":_percentiles(total_times),
		"ripple_export":_percentiles(export_times),"ripple_export_active_rings":fx.stats().activeRings,"ripple_export_max_returned":exported_max,
		"peak_active":{"droplets":peak_drops,"rings":peak_rings,"foam":peak_foam,"arcs":peak_arcs,"water_samples_per_frame":peak_samples},
		"capacities":{"droplets":240,"rings":24,"foam":72,"arcs":288,"cpu_upload_bytes":(240+288+72)*16*4,"max_effect_draw_batches":3},
		"allocation_evidence":{"particle_objects_created":fx.simulator.particle_objects_created,"buffer_capacity_resizes":fx.buffer_capacity_resizes,"object_count_change_after_warmup":Performance.get_monitor(Performance.OBJECT_COUNT)-object_before,"static_memory_change_after_warmup_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)-memory_before,"transient_allocator_events":"NOT_INSTRUMENTED; bulk upload packed arrays may copy on write"},
		"fullcity_fps":"NOT_RUN","gpu_time":"NOT_RUN"}
	print("WATER_FX_COST=" + JSON.stringify(output))
	fx.dispose(); fx.free(); sim.dispose(); get_tree().quit()
