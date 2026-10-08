extends Node3D
const Sampler = preload("res://hero_water_input_sampler.gd")
const Effects = preload("res://water_contact_fx.gd")
const Consumer = preload("res://integration/consumer.gd")
var checks := 0
var failures: Array[String] = []
var bounds_calls := 0
var water_calls := 0
var level := 3.0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func water_at(x: float, _z: float) -> Variant:
	water_calls += 1
	return {"level":level,"depth":1.0,"floor":level-1.0} if x >= 0.0 else null

func bounds() -> Dictionary:
	bounds_calls += 1
	return {"sourceBounds":{"min":[-0.6,0,-0.3],"max":[0.6,2,0.3]}}

func new_effects() -> Node3D:
	var fx := Effects.new()
	add_child(fx)
	check(fx.setup({"waterAt":Callable(self,"water_at"),"random":func():return 0.5}), "actual FX setup")
	return fx

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout # Scheduler registration, outside measurement.
	var hero := Node3D.new()
	add_child(hero)
	var sampler := Sampler.new()
	var consumer := Consumer.new()
	var fx = new_effects()
	var state := {"diagnostics":Callable(self,"bounds"),"source_scale":0.95}
	check(consumer.bind(sampler,fx), "bind actual modules")
	hero.position = Vector3(0.2,level,0)
	var held := hero.global_transform
	var row: Dictionary = consumer.advance(hero,0.1,state)
	check(row.hero.teleport and fx.stats().bursts == 0, "first wet frame cannot splash")
	check(hero.global_transform == held, "sample/effects leave pose unchanged")
	consumer.reset_sampler()
	hero.position = Vector3(-0.3,level+0.5,0)
	consumer.advance(hero,0.1,state)
	hero.position = Vector3(0.2,level,0)
	row = consumer.advance(hero,0.1,state)
	check(not row.hero.teleport and row.hero.velocity.y < -1.35, "posed descent reaches real sampler velocity")
	check(fx.stats().impacts == 1 and fx.stats().activeDroplets > 0, "real provider shore contact emits impact")
	check(not row.ripples.is_empty(), "consumer returns actual FX ripple output")
	if not row.ripples.is_empty(): check(absf(row.ripples[0].y-level) < 0.02, "ripple uses supplied elevated water level")
	var bursts: int = fx.stats().bursts
	var before_time: float = fx.stats().time
	state.occupied_seat = "driver"
	hero.position = Vector3(8,level,0)
	row = consumer.advance(hero,0.1,state)
	check(not row.hero.enabled and fx.stats().bursts == bursts and fx.stats().trackedActors == 0, "seat suppresses and prunes actor history")
	check(fx.stats().time > before_time, "existing particles keep stepping while hero disabled")
	state.occupied_seat = null
	row = consumer.advance(hero,0.1,state)
	check(row.hero.teleport and fx.stats().bursts == bursts, "exit seat reseeds without stale seat velocity")
	state.transition = {}
	check(not consumer.advance(hero,0.1,state).hero.enabled, "source empty transition disables contact")
	state.transition = null
	check(consumer.advance(hero,0.1,state).hero.teleport and fx.stats().bursts == bursts, "transition end suppresses false impact")
	state.teleport = true
	hero.position = Vector3(16,level,0)
	check(consumer.advance(hero,0.1,state).hero.teleport and fx.stats().bursts == bursts, "explicit teleport")
	state.teleport = false
	check(consumer.advance(hero,0.5,state).hero.teleport and fx.stats().bursts == bursts, "raw dt suppression shared across modules")
	row = consumer.advance(null,0.1,state,Vector3.ZERO)
	check(row.hero.is_empty() and fx.stats().trackedActors == 0, "missing actor removes FX history")
	consumer.reset_sampler()
	check(consumer.advance(hero,0.1,state).hero.teleport and fx.stats().bursts == bursts, "source inspection reset preserves FX but suppresses first resumed contact")
	var callbacks_before := bounds_calls
	var cost: Dictionary = {}
	for scenario in ["dry_idle","wet_idle","wet_motion"]:
		consumer.reset_sampler()
		hero.position = Vector3(-2,level,0) if scenario == "dry_idle" else Vector3(2,level,0)
		consumer.advance(hero,0.016,state)
		var samples: Array[float] = []
		var objects_before := Performance.get_monitor(Performance.OBJECT_COUNT)
		var samples_before := water_calls
		var particle_objects_before: int = fx.stats().particleObjectsCreated
		for batch in 10:
			var start := Time.get_ticks_usec()
			for step in 100:
				if scenario == "wet_motion": hero.position.x += 0.016
				consumer.advance(hero,0.016,state)
			samples.append(float(Time.get_ticks_usec()-start)/100.0)
		samples.sort()
		cost[scenario] = {"updates":1000,"batch_mean_us_p50":samples[5],"batch_mean_us_max":samples[9],"water_queries":water_calls-samples_before,"persistent_object_delta":Performance.get_monitor(Performance.OBJECT_COUNT)-objects_before}
		check(fx.stats().particleObjectsCreated == particle_objects_before and fx.stats().bufferCapacityResizes == 3, "combined hot path keeps particle objects and buffers fixed: "+scenario)
	check(bounds_calls == callbacks_before, "combined hot path does not re-read hero bounds")
	consumer.clear_content()
	check(fx.get_parent() == null and fx.get_child_count() == 0 and fx.stats().disposed, "cleanup detaches FX and releases render children")
	check(fx.stats().trackedActors == 0 and fx.stats().activeDroplets == 0 and fx.stats().activeRings == 0 and fx.stats().activeFoam == 0, "cleanup leaves no live actor or particles")
	check(fx.simulator.water_at.is_null() and fx.simulator.random_callback.is_null(), "cleanup drops supplied provider callbacks")
	consumer.clear_content()
	check(consumer.advance(hero,0.1,state).is_empty(), "cleaned consumer inert")
	fx.free()
	fx = new_effects()
	check(consumer.bind(sampler,fx), "re-enable same sampler with fresh effects")
	check(consumer.advance(hero,0.1,state).hero.teleport and fx.stats().bursts == 0, "re-enable has no stale velocity or contact")
	consumer.clear_content()
	fx.free()
	hero.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"combined_cost":cost,"limits":"Actual Node3D + real immutable sampler/FX headless integration; no current286, swimming or GPU/frame acceptance; transient Variant allocations not measured"}))
	get_tree().quit(0 if failures.is_empty() else 1)
