extends SceneTree
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Gate=preload("res://scripts/transport/transport_vehicle_contact_admission.gd")
const Orchestrator=preload("res://scripts/transport/transport_vehicle_damage_orchestrator.gd")
const Bridge=preload("res://scripts/transport/candidates/transport_vehicle_contact_bridge.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func _receipt(host: RefCounted,clock_revision: int,sequence: int,impact: float,slide: float,hp: float,orchestrator_revision: int) -> Dictionary:
	return {"authority":host,"vehicle_id":"real-hatch","life_generation":1,"clock_revision":clock_revision,"contact_sequence":sequence,"event_id":"contact-"+str(sequence),"status":{"disposed":false,"destroying":false,"wrecked":false},"point_native_m":Vector3(3,0,0),"normal_native":Vector3.LEFT,"center_native_m":Vector3.ZERO,"impact_speed_mps":impact,"slide_speed_mps":slide,"prior_hp":hp,"prior_explosions":0,"prior_revision":orchestrator_revision}
func _finish(receipt: Dictionary,ticket: RefCounted,hit: bool) -> Dictionary:
	return {"authority":receipt.authority,"vehicle_id":receipt.vehicle_id,"life_generation":receipt.life_generation,"clock_revision":receipt.clock_revision,"contact_sequence":receipt.contact_sequence,"ticket":ticket,"raycast_complete":true,"hit":hit}
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.ok,"actual hatch imported")
	if not loaded.ok: finish({}); return
	var visual: RefCounted=loaded.visual; world.add_child(visual.root)
	var row: Dictionary={}
	for item: Dictionary in Bindings.load_oracle().rows:
		if item.profile_id=="city_hatchback": row=item; break
	var host:=RefCounted.new(); var intruder:=RefCounted.new()
	var physical: Dictionary={"mass_kg":18.0,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08}
	var orchestrator:=Orchestrator.new(); var memory_before:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var start:=Time.get_ticks_usec(); var setup: Dictionary=orchestrator.configure(host,"real-hatch",1,visual,row,world,physical); var configure_us:=Time.get_ticks_usec()-start
	check(setup.ok and setup.assemblies==10,"actual bound hatch orchestrator")
	if not setup.ok: visual.dispose(); finish({"configure_us":configure_us}); return
	var gate:=Gate.new(); check(gate.configure(host,"real-hatch",1),"source clock gate")
	var bridge:=Bridge.new(); check(bridge.configure(host,"real-hatch",1,gate,orchestrator),"candidate bridge configured")
	var zero:=_receipt(host,0,1,2.4,1.5,240.0,0)
	var wrong:=zero.duplicate(true); wrong.authority=intruder
	check(not bridge.begin_contact(wrong).ok and gate.stats().last_crash_s==-INF,"forged host cannot prepare")
	var phase: Dictionary=bridge.begin_contact(zero)
	check(phase.prepared and orchestrator.revision()==0 and orchestrator.state().hp==240.0,"scrape prepares without HP/revision mutation")
	var malformed:=_finish(zero,RefCounted.new(),false)
	check(not bridge.finish_raycast(malformed).ok and gate.stats().raycast_pending,"wrong raycast ticket fails closed")
	var scrape: Dictionary=bridge.finish_raycast(_finish(zero,phase.ticket,false))
	check(scrape.ok and scrape.cooldown_consumed and scrape.damage==0 and not scrape.hp_committed and not scrape.source_return and scrape.callbacks_pending,"no-hit zero-damage scrape consumes cooldown without HP")
	check(orchestrator.revision()==0 and orchestrator.state().hp==240.0 and gate.stats().last_crash_s==0.0,"scrape leaves HP and revision intact")
	var immediate:=_receipt(host,0,2,2.5,0.0,240.0,0)
	check(bridge.begin_contact(immediate).reason=="cooldown","damage blocked inside .25s")
	var clock: Dictionary={"authority":host,"vehicle_id":"real-hatch","life_generation":1,"clock_revision":1,"dt":.25}
	check(bridge.advance_clock(clock).ok,"host clock reaches boundary")
	var damaging:=_receipt(host,1,2,2.5,0.0,240.0,0)
	var damage_phase: Dictionary=bridge.begin_contact(damaging)
	check(damage_phase.prepared and orchestrator.state().hp==240.0,"damage waits for completed raycast")
	var damage_result: Dictionary=bridge.finish_raycast(_finish(damaging,damage_phase.ticket,false))
	check(damage_result.ok and damage_result.damage==1 and damage_result.hp_committed and damage_result.revision==1 and damage_result.state.hp==239.0 and damage_result.source_return,"source damage committed after cooldown, before host callbacks")
	check(damage_result.callbacks_pending and orchestrator.state().hp==239.0 and not orchestrator.state().destroying and orchestrator.state().explosions==0,"callback continuation remains host-owned; crash cannot autoexplode")
	clock.clock_revision=2; clock.dt=.25; check(bridge.advance_clock(clock).ok,"next host update")
	var stale:=_receipt(host,2,3,2.4,1.5,240.0,0)
	check(bridge.begin_contact(stale).get("error")=="state_authority" and gate.stats().last_crash_s==.25,"stale HP/revision rejected before cooldown")
	var scratch:=_receipt(host,2,3,2.4,1.5,239.0,1)
	var pending: Dictionary=bridge.begin_contact(scratch)
	check(pending.prepared and bridge.cancel_pending(pending.ticket) and gate.stats().last_crash_s==.25,"aborted host raycast leaves cooldown unused")
	var resumed: Dictionary=bridge.begin_contact(scratch)
	check(bridge.finish_raycast(_finish(scratch,resumed.ticket,true)).source_return and orchestrator.revision()==1 and orchestrator.state().hp==239.0,"hit scrape callback path without HP/revision loss")
	var bench_ok:=true; start=Time.get_ticks_usec()
	for i in 1000:
		clock.clock_revision=i+3; clock.dt=.25
		if not bridge.advance_clock(clock).ok: bench_ok=false; break
		var receipt:=_receipt(host,i+3,i+4,2.4,1.5,239.0,1)
		var planned: Dictionary=bridge.begin_contact(receipt)
		if not planned.get("prepared",false): bench_ok=false; break
		var applied: Dictionary=bridge.finish_raycast(_finish(receipt,planned.ticket,false))
		if not applied.get("ok",false) or applied.get("hp_committed",true) or orchestrator.revision()!=1: bench_ok=false; break
	var scrape_1000_us:=Time.get_ticks_usec()-start
	check(bench_ok and orchestrator.state().hp==239.0 and orchestrator.revision()==1,"1000 ordered scrapes preserve HP and revision")
	for i in 3:
		clock.clock_revision=1003+i; clock.dt=.25
		check(bridge.advance_clock(clock).ok,"host clock before severe contact "+str(i))
		var severe:=_receipt(host,1003+i,1004+i,50.0,0.0,float(orchestrator.state().hp),orchestrator.revision())
		var severe_plan: Dictionary=bridge.begin_contact(severe)
		check(severe_plan.prepared,"severe contact prepared "+str(i))
		var severe_result: Dictionary=bridge.finish_raycast(_finish(severe,severe_plan.ticket,false))
		check(severe_result.ok and severe_result.hp_committed and not severe_result.state.destroying,"source floor keeps crash nonexplosive "+str(i))
	check(orchestrator.state().hp==1.0,"three impacts reach mechanical HP floor")
	clock.clock_revision=1006; clock.dt=.25; check(bridge.advance_clock(clock).ok,"host clock at HP floor")
	var floor_contact:=_receipt(host,1006,1007,50.0,0.0,1.0,orchestrator.revision())
	var last_crash_before: float=gate.stats().last_crash_s
	var floor_plan: Dictionary=bridge.begin_contact(floor_contact)
	check(floor_plan.prepared and gate.stats().last_crash_s==last_crash_before,"HP-floor contact prepares without early cooldown")
	var floor_result: Dictionary=bridge.finish_raycast(_finish(floor_contact,floor_plan.ticket,false))
	check(floor_result.ok and floor_result.damage==80 and floor_result.hp_floor_noop and not floor_result.hp_committed and floor_result.callbacks_pending and floor_result.source_return,"HP-floor contact consumes cooldown and preserves source callback path")
	check(gate.stats().last_crash_s>last_crash_before and orchestrator.state().hp==1.0 and orchestrator.revision()==4,"HP-floor no-op leaves native revision unchanged")
	var memory_after:=Performance.get_monitor(Performance.MEMORY_STATIC)
	bridge.dispose(); gate.dispose(); check(orchestrator.dispose().ok,"preblast provider cleanup")
	visual.dispose(); world.free()
	finish({"configure_us":configure_us,"scrape_1000_us":scrape_1000_us,"memory_before_bytes":memory_before,"memory_after_bytes":memory_after,"assemblies":setup.assemblies,"hulls":setup.hulls})
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_CONTACT_BRIDGE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"actual hatch; candidate gate-to-orchestrator contact only; host raycast/callbacks and LIVE unverified"}))
	quit(0 if failures.is_empty() else 1)
