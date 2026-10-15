extends SceneTree
const Clock = preload("res://day_night_clock.gd")
const Routine = preload("res://npc_routine58.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func check(name: String, value: bool) -> void: checks.append({"name":name,"passed":value})
func _run() -> void:
	await create_timer(3.0).timeout # Scheduler must register the exact owned child.
	var clock = Clock.new()
	clock.hour=23.9; clock.advance(30.0)
	check("natural_midnight_once", clock.day_index==1 and is_equal_approx(clock.hour,.1))
	clock.hour=5.9; clock.advance(30.0)
	check("dawn_not_new_day", clock.day_index==1 and is_equal_approx(clock.hour,6.05))
	clock.hour=17.5; clock.advance(Clock.CYCLE_SECONDS*3.0)
	check("whole_cycles_counted",clock.day_index==4 and is_equal_approx(clock.hour,17.5))
	clock.running=false; clock.advance(10000.0)
	check("paused_shared_clock",clock.day_index==4 and clock.hour==17.5)
	for frame: int in 121: clock.set_hour(22.0+14.0*float(frame)/120.0)
	check("N_transition_no_daily_replay",clock.day_index==4 and is_equal_approx(clock.hour,12.0))
	clock.set_hour(NAN)
	check("invalid_clock_does_not_change",clock.hour==12.0 and clock.day_index==4)
	clock.running=true
	var routine = Routine.new(); routine.configure("resident7")
	var profile: Dictionary=routine.snapshot().profile
	clock.hour=profile.lunch+.01
	var intent: Dictionary=routine.choose(clock,0.0)
	check("lunch_real_restaurant_intent",intent.kind=="restaurant" and intent.event=="lunch")
	check("ticket_requires_real_owned_receipt",not routine.note_paid(intent.ticket,"","restaurant"))
	check("wrong_service_cannot_complete",not routine.note_paid(intent.ticket,"receipt1","shop"))
	check("wrong_ticket_cannot_complete",not routine.note_paid("other","receipt1","restaurant"))
	clock.hour=3.0
	check("night_sleep_keeps_pending_ticket",routine.choose(clock,0.0).kind=="home_sleep" and routine.snapshot().pending==intent)
	clock.hour=float(profile.wake)+.01
	check("interrupted_errand_resumes_after_wake",routine.choose(clock,0.0)==intent)
	check("receipt_completes_same_errand",routine.note_paid(intent.ticket,"receipt1","restaurant"))
	check("duplicate_receipt_rejected",not routine.note_paid(intent.ticket,"receipt1","restaurant"))
	clock.hour=profile.lunch+.01
	check("paid_lunch_not_repeated_same_day",routine.due_purchase(clock).get("event","")!="lunch")
	clock.advance(Clock.CYCLE_SECONDS)
	check("new_day_rearms_lunch",routine.due_purchase(clock).get("event","")=="lunch")
	check("sleep_is_intent_not_teleport_or_energy",not routine.snapshot().has("energy") and routine.snapshot().random_world_targets==false)
	var missing = Routine.new(); missing.configure("withoutclock")
	check("missing_clock_fails_to_supported_ambient",missing.choose(null,0.0).kind=="ambient")
	var hours: Dictionary={}; var late_count:=0; var normal_count:=0
	for id: int in 100:
		var person = Routine.new(); person.configure("resident"+str(id))
		var p: Dictionary=person.snapshot().profile
		hours[str(p.lunch)]=true
		if p.late: late_count+=1
		else: normal_count+=1
		clock.hour=fposmod(float(p.bedtime)+.1,24.0)
		if person.home_intent(clock).get("kind","")!="home_sleep": check("profile_bedtime_"+str(id),false)
		clock.hour=float(p.wake)+.01
		if person.home_intent(clock).get("kind","")=="home_sleep": check("profile_wake_"+str(id),false)
	check("individual_windows_not_crowd",hours.size()>90)
	check("day_and_late_profiles",late_count>0 and late_count<40 and normal_count>0)
	var first_ten: Dictionary={}; var ten_late:=0; var ten_lunch: Dictionary={}
	for index: int in range(1,11):
		var resident = Routine.new(); var id: String="resident_"+str(index);resident.configure(id)
		var p: Dictionary=resident.snapshot().profile
		first_ten[id]=p; ten_lunch[str(p.lunch)]=true
		if p.late: ten_late+=1
	check("actual_first_ten_individual_windows",ten_lunch.size()==10)
	check("actual_first_ten_include_night_and_day",ten_late>0 and ten_late<10)
	var night = Routine.new();night.configure("resident_2");clock.hour=22.5
	check("late_resident_has_real_leisure_intent",night.choose(clock,0.0).kind=="leisure")
	night.leisure_attempt(0.0)
	check("failed_leisure_has_bounded_retry",night.choose(clock,1000.0).kind!="leisure" and night.choose(clock,45001.0).kind=="leisure")
	night.after_ambient(50000.0,.5,clock)
	check("ambient_pause_precedes_leisure",night.choose(clock,50001.0).kind=="rest" and night.choose(clock,64001.0).kind=="leisure")
	var deferred = Routine.new();deferred.configure("resident_1")
	clock.hour=float(deferred.snapshot().profile.lunch)+.01
	var saved: Dictionary=deferred.choose(clock,0.0)
	check("defer_preserves_exact_ticket",deferred.choose(clock,1000.0,true).kind!="restaurant" and deferred.snapshot().pending==saved)
	var passed:=true
	for row: Dictionary in checks: passed=passed and row.passed
	var result: Dictionary={"passed":passed,"checks":checks,"scope":"Pure native policy/clock only; no physical home, payment or city acceptance", "late_profiles":late_count,"first_ten":first_ten}
	var output=FileAccess.open("res://POLICY58.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t"));output.close()
	print("ROUTINE58_POLICY ",JSON.stringify(result))
	quit(0 if passed else 2)
