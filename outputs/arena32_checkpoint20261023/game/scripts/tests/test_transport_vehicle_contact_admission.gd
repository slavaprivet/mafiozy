extends SceneTree
const Gate=preload("res://scripts/transport/transport_vehicle_contact_admission.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void:
	var host:=RefCounted.new(); var intruder:=RefCounted.new()
	var gate:=Gate.new()
	check(gate.configure(host,"taxi-7",4),"host capability and vehicle lifetime")
	check(not gate.configure(host,"taxi-7",4),"single configuration")
	for pair in [[0.0,0],[2.4,0],[2.5,1],[4.1,1],[50.0,80],[INF,0],[NAN,0]]:
		check(Gate.crash_damage(pair[0])==pair[1],"source vehicleCrashDamage "+str(pair[0]))
	var contact: Dictionary={"authority":host,"vehicle_id":"taxi-7","life_generation":4,"clock_revision":0,"contact_sequence":1,"status":{"disposed":false,"destroying":false,"wrecked":false},"point_native_m":Vector3(3,0,0),"normal_native":Vector3(-4,0,0),"center_native_m":Vector3.ZERO,"impact_speed_mps":2.4,"slide_speed_mps":1.5}
	var wrong:=contact.duplicate(true); wrong.authority=intruder
	check(not gate.begin_contact(wrong).ok and gate.stats().last_crash_s==-INF,"wrong authority cannot consume cooldown")
	wrong=contact.duplicate(true); wrong.life_generation=5
	check(not gate.begin_contact(wrong).ok,"stale vehicle lifetime")
	wrong=contact.duplicate(true); wrong.normal_native=Vector3.ZERO
	check(not gate.begin_contact(wrong).ok and gate.stats().last_crash_s==-INF,"zero normal does not consume cooldown")
	wrong=contact.duplicate(true); wrong.slide_speed_mps=1.49
	check(gate.begin_contact(wrong).reason=="below_damage_and_scrape" and gate.stats().last_crash_s==-INF,"subthreshold contact does not consume cooldown")
	var scrape_plan: Dictionary=gate.begin_contact(contact)
	check(scrape_plan.ok and scrape_plan.prepared and scrape_plan.damage==0 and gate.stats().last_crash_s==-INF,"zero-damage scrape waits for raycast before cooldown")
	check(scrape_plan.normalized_outward_native==Vector3.RIGHT,"normal flips outward using host body center")
	var finish_receipt: Dictionary={"authority":host,"vehicle_id":"taxi-7","life_generation":4,"clock_revision":0,"contact_sequence":1,"ticket":scrape_plan.ticket,"raycast_complete":true,"hit":false}
	var invalid_finish:=finish_receipt.duplicate(); invalid_finish.ticket=RefCounted.new()
	check(not gate.finish_raycast(invalid_finish).ok and gate.stats().raycast_pending,"wrong raycast ticket cannot consume cooldown")
	var blocked_clock: Dictionary={"authority":host,"vehicle_id":"taxi-7","life_generation":4,"clock_revision":1,"dt":.1}
	check(not gate.advance_clock(blocked_clock).ok,"clock cannot interleave source synchronous raycast")
	var scrape: Dictionary=gate.finish_raycast(finish_receipt)
	check(scrape.ok and scrape.admitted and scrape.damage==0 and scrape.cooldown_consumed and not scrape.source_return and not scrape.hit,"zero-damage no-hit scrape consumes cooldown but returns false")
	check(gate.stats().last_crash_s==0.0 and not gate.stats().raycast_pending,"cooldown assigned after raycast")
	wrong=contact.duplicate(true); wrong.contact_sequence=2
	check(gate.begin_contact(wrong).reason=="cooldown","immediate valid contact blocked")
	var clock: Dictionary={"authority":host,"vehicle_id":"taxi-7","life_generation":4,"clock_revision":1,"dt":.249}
	check(gate.advance_clock(clock).ok,"host clock advances .249s")
	wrong=contact.duplicate(true); wrong.clock_revision=1; wrong.contact_sequence=2; wrong.impact_speed_mps=50.0
	check(gate.begin_contact(wrong).reason=="cooldown" and gate.stats().last_crash_s==0.0,".249s cooldown still blocks high damage")
	clock.clock_revision=2; clock.dt=.001
	check(gate.advance_clock(clock).ok and absf(gate.stats().time_s-.25)<1e-12,"host clock reaches .25s boundary")
	wrong.clock_revision=2; wrong.impact_speed_mps=2.5
	var edge_plan: Dictionary=gate.begin_contact(wrong)
	check(edge_plan.ok and edge_plan.prepared and edge_plan.damage==1 and absf(gate.stats().last_crash_s)<1e-12,".25s boundary prepares damage before raycast")
	finish_receipt.clock_revision=2; finish_receipt.contact_sequence=2; finish_receipt.ticket=edge_plan.ticket; finish_receipt.hit=false
	var edge: Dictionary=gate.finish_raycast(finish_receipt)
	check(edge.ok and edge.admitted and edge.damage==1 and edge.source_return,"damage contact returns true without hit")
	check(absf(gate.stats().last_crash_s-.25)<1e-12,"successful contact records source clock")
	wrong=contact.duplicate(true); wrong.clock_revision=2; wrong.contact_sequence=2
	check(not gate.begin_contact(wrong).ok,"accepted contact sequence cannot replay")
	clock.clock_revision=3; clock.dt=.25
	check(gate.advance_clock(clock).ok,"second cooldown window")
	wrong=contact.duplicate(true); wrong.clock_revision=3; wrong.contact_sequence=3; wrong.slide_speed_mps=0.0
	check(gate.begin_contact(wrong).reason=="below_damage_and_scrape" and absf(gate.stats().last_crash_s-.25)<1e-12,"zero damage without scrape preserves prior cooldown")
	wrong.slide_speed_mps=1.5
	var second_scrape: Dictionary=gate.begin_contact(wrong)
	check(second_scrape.prepared and absf(gate.stats().last_crash_s-.25)<1e-12,"second scrape prepared without cooldown mutation")
	finish_receipt.clock_revision=3; finish_receipt.contact_sequence=3; finish_receipt.ticket=second_scrape.ticket; finish_receipt.hit=true
	check(gate.finish_raycast(finish_receipt).source_return and absf(gate.stats().last_crash_s-.5)<1e-12,"zero-damage panel hit returns true after cooldown commit")
	wrong=contact.duplicate(true); wrong.clock_revision=3; wrong.contact_sequence=4; wrong.status.destroying=true
	check(gate.begin_contact(wrong).reason=="terminal" and absf(gate.stats().last_crash_s-.5)<1e-12,"destroying vehicle rejects before payload")
	wrong.status.destroying=false; wrong.status.wrecked=true
	check(gate.begin_contact(wrong).reason=="terminal","wrecked vehicle rejects")
	wrong.status.wrecked=false; wrong.status.disposed=true
	check(gate.begin_contact(wrong).reason=="terminal","disposed host vehicle rejects")
	wrong.status.disposed=false; wrong.clock_revision=2
	check(not gate.begin_contact(wrong).ok,"stale host clock receipt rejected")
	clock.clock_revision=4; clock.dt=.25
	check(gate.advance_clock(clock).ok,"host advances while idle")
	wrong=contact.duplicate(true); wrong.clock_revision=4; wrong.contact_sequence=4
	var canceled_plan: Dictionary=gate.begin_contact(wrong)
	check(canceled_plan.prepared and gate.cancel_pending(canceled_plan.ticket) and absf(gate.stats().last_crash_s-.5)<1e-12,"aborted raycast leaves cooldown untouched")
	var retry_plan: Dictionary=gate.begin_contact(wrong)
	finish_receipt.clock_revision=4; finish_receipt.contact_sequence=4; finish_receipt.ticket=retry_plan.ticket; finish_receipt.hit=false
	check(gate.finish_raycast(finish_receipt).ok and absf(gate.stats().last_crash_s-.75)<1e-12,"new completed raycast commits after canceled attempt")
	clock.clock_revision=5; clock.dt=INF
	check(not gate.advance_clock(clock).ok and gate.stats().clock_revision==4,"invalid time does not advance")
	clock.dt=-.1
	check(not gate.advance_clock(clock).ok,"negative time rejected")
	var start:=Time.get_ticks_usec()
	for i in 100000: Gate.crash_damage(4.1+i%27*.2)
	var kernel_us:=Time.get_ticks_usec()-start
	var bench:=Gate.new(); check(bench.configure(host,"bench",1),"bench host configured")
	var bench_clock: Dictionary={"authority":host,"vehicle_id":"bench","life_generation":1,"clock_revision":0,"dt":.25}
	var bench_contact: Dictionary={"authority":host,"vehicle_id":"bench","life_generation":1,"clock_revision":0,"contact_sequence":0,"status":{"disposed":false,"destroying":false,"wrecked":false},"point_native_m":Vector3(2,0,0),"normal_native":Vector3.RIGHT,"center_native_m":Vector3.ZERO,"impact_speed_mps":2.5,"slide_speed_mps":0.0}
	var bench_finish: Dictionary={"authority":host,"vehicle_id":"bench","life_generation":1,"clock_revision":0,"contact_sequence":0,"ticket":null,"raycast_complete":true,"hit":false}
	start=Time.get_ticks_usec(); var benchmark_ok:=true
	for i in 5000:
		bench_clock.clock_revision=i+1
		if not bench.advance_clock(bench_clock).ok: benchmark_ok=false; break
		bench_contact.clock_revision=i+1; bench_contact.contact_sequence=i+1
		var prepared: Dictionary=bench.begin_contact(bench_contact)
		if not prepared.get("prepared",false): benchmark_ok=false; break
		bench_finish.clock_revision=i+1; bench_finish.contact_sequence=i+1; bench_finish.ticket=prepared.ticket
		if not bench.finish_raycast(bench_finish).get("admitted",false): benchmark_ok=false; break
	var admission_5000_us:=Time.get_ticks_usec()-start
	check(benchmark_ok and bench.stats().last_contact_sequence==5000,"5000 ordered full admission receipts")
	bench.dispose()
	gate.dispose()
	check(not gate.begin_contact(contact).ok and not gate.advance_clock(clock).ok,"disposed gate cannot accept receipts")
	print("TRANSPORT_CONTACT_ADMISSION ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"crash_damage_100k_us":kernel_us,"admission_5000_us":admission_5000_us,"source":"vehicle_damage.mjs contactImpact lines 206-224 and vehicleCrashDamage lines 11-14","scope":"clock/contact admission only; host owns raycast, collision payload, HP and callbacks"}))
	quit(0 if failures.is_empty() else 1)
