extends SceneTree
const Registry = preload("res://scripts/transport/transport_civilian_trip_registry.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func actor(id: String, life: int = 1) -> Dictionary:
	return {"actor_id": id, "life_generation": life}
func car(id: String, life: int = 1) -> Dictionary:
	return {"vehicle_id": id, "life_generation": life}
func _initialize() -> void:
	var r = Registry.new()
	check(not r.begin_session("",1),"invalid session")
	check(r.reserve("s",1,"t",actor("n"),car("c")) == "STALE_SESSION","unconfigured")
	check(r.begin_session("s",1),"session")
	check(r.reserve("s",1,"t",actor("n"),car("c")) == "RESERVED","atomic first")
	check(r.reserve("s",1,"t",actor("n"),car("c")) == "RESERVED" and r.count()==1,"idempotent")
	check(r.reserve("s",1,"t",actor("other"),car("other")) == "TOKEN_CONFLICT","token cannot rebound")
	check(r.reserve("s",1,"u",actor("n"),car("other")) == "ACTOR_CONFLICT","actor exclusive")
	check(r.reserve("s",1,"u",actor("other"),car("c")) == "VEHICLE_CONFLICT","vehicle exclusive")
	var row: Dictionary = r.trip("t")
	row.actor.actor_id="changed"
	check(r.trip("t").actor.actor_id=="n" and r.trip("t").phase=="planning","defensive copy planning only")
	check(r.begin_session("s",1) and r.count()==1,"duplicate session retains")
	check(r.reconcile("s",2,[],[]).is_empty() and r.count()==1,"stale reconcile inert")
	check(r.reconcile("s",1,[actor("n")],[car("c")]).is_empty(),"current lifetime retains")
	check(r.reconcile("s",1,[actor("n",2)],[car("c")])==["t"] and r.count()==0,"replaced actor releases both")
	check(r.reserve("s",1,"t",actor("n",2),car("c"))=="RESERVED","released car reusable")
	check(r.reconcile("s",1,[actor("n",2)],[car("c",2)])==["t"],"replaced vehicle")
	check(not r.release("missing", 1),"absent release inert")
	check(r.reserve("s",1,"bad",{"actor_id":"n","life_generation":1.5},car("c"))=="INVALID_REFERENCE","fractional life rejected")
	for i in range(16):
		check(r.reserve("s",1,str(i),actor("n"+str(i)),car("c"+str(i)))=="RESERVED","capacity entry")
	check(r.reserve("s",1,"overflow",actor("extra"),car("extra"))=="LIMIT","source sixteen limit")
	check(r.release("3", r.trip("3").incarnation) and r.count()==15,"release exact")
	check(r.reserve("s",1,"replacement",actor("n3"),car("c3"))=="RESERVED","indices cleaned")
	check(r.begin_session("s",2) and r.count()==0,"session replacement clears")
	check(not r.begin_session("s",1),"same session generation cannot roll back")
	check(r.reserve("s",2,"stale",actor("n"),car("c"))=="RESERVED","old incarnation")
	var old: int = r.trip("stale").incarnation
	check(r.release("stale",old),"old release")
	r.reserve("s",2,"stale",actor("n"),car("c"))
	check(not r.release("stale",old) and r.count()==1,"stale unregister cannot remove replacement")
	r.release("stale",r.trip("stale").incarnation)
	var start := Time.get_ticks_usec()
	for i in range(10000):
		r.reserve("s",2,"perf",actor("real-fixture"),car("real-fixture"))
		r.release("perf", r.trip("perf").incarnation)
	var elapsed := Time.get_ticks_usec()-start
	print("TRANSPORT_CIVILIAN_TRIP_REGISTRY ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"reserve_release_10000_us":elapsed,"scope":"isolated registry fixtures; no real admission/driver/GPU"}))
	quit(0 if failures.is_empty() else 1)

