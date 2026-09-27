extends SceneTree
const InputPort = preload("res://scripts/combat/melee_input.gd")
var checks := 0
var failures: Array[String] = []
var metrics := {}

class Bridge extends Node:
	var clock := 0.0
	var serial := 0
	var calls: Array = []
	var settings := {}
	var last_reply := {}
	var reenter: RefCounted
	var free_on_begin := false
	var free_on_clock := false
	var reentry_result := {}
	func now_seconds() -> float:
		if free_on_clock: queue_free()
		return clock
	func charge(value: bool) -> bool:
		calls.append(["charge",value]); return true
	func block_port(value: bool) -> bool:
		calls.append(["block",value]); return settings.get("blockAccept") != false
	func begin(request: Dictionary) -> Variant:
		calls.append(["begin",request.duplicate(true)]); serial += 1
		if reenter != null: reentry_result = reenter.cancel()
		if free_on_begin: queue_free(); return null
		if settings.get("nullReply",false): return null
		var type: String = "dropkick" if request.airborne else "heavy" if request.heavy else "punch"
		last_reply = {"accepted":true,"seq":serial,"type":type,"side":-1 if serial%2 else 1,"startAt":clock*1000+17,"duration":1.25 if type=="dropkick" else .5 if type=="heavy" else .34,"contactWindow":[160,380] if type=="dropkick" else [70,360] if type=="heavy" else [35,190]}
		last_reply.merge(settings,true)
		return last_reply
	func ports() -> Dictionary:
		return {"beginWalkMelee":Callable(self,"begin"),"setWalkMeleeCharge":Callable(self,"charge"),"setWalkMeleeBlock":Callable(self,"block_port")}
	func missing_ack(value: bool) -> Variant:
		calls.append(["charge",value]); return null
	func wrong_charge(_value: bool, _required_extra: bool) -> bool: return true

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size()<30: failures.append(label)

func equal(actual: Variant, expected: Variant, label: String) -> void:
	if (expected is int or expected is float) and (actual is int or actual is float):
		check(absf(float(actual)-float(expected)) <= 1e-10*maxf(1,absf(float(expected))),label+" number")
	elif expected is Dictionary and actual is Dictionary:
		check(actual.size()==expected.size(),label+" dictionary size")
		for key: String in expected:
			check(actual.has(key),label+" key "+key)
			if actual.has(key): equal(actual[key],expected[key],label+"."+key)
	elif expected is Array and actual is Array:
		check(actual.size()==expected.size(),label+" array size")
		for i in mini(actual.size(),expected.size()): equal(actual[i],expected[i],label+"["+str(i)+"]")
	else: check(typeof(actual)==typeof(expected) and actual==expected,label+" value actual="+str(actual)+" expected="+str(expected))

func fresh(bridge: Bridge) -> RefCounted:
	var input := InputPort.new()
	check(input.configure(bridge.ports(),Callable(bridge,"now_seconds")).get("ok",false),"configure live bound bridge")
	return input

func parity() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/melee_input_oracle.json"))
	check(FileAccess.get_sha256("../../assets/maps/city_rebuild_v1/world_walk_melee_input.mjs")==fixture.source_sha256,"oracle pinned to current unchanged source bytes")
	for scenario: Dictionary in fixture.scenarios:
		var bridge := Bridge.new(); bridge.settings = scenario.initial.duplicate(true)
		var input := fresh(bridge)
		for i in scenario.operations.size():
			var op: Dictionary = scenario.operations[i]
			if op.has("now"): bridge.clock = op.now
			if op.has("bridge"): bridge.settings.merge(op.bridge,true)
			var result: Dictionary
			if op.method == "cancel": result = input.cancel()
			elif op.method == "block": result = input.block(op.value)
			else: result = input.call(op.method,op.get("options",{}))
			equal({"snapshot":result,"calls":bridge.calls},scenario.expected[i],scenario.name+":"+str(i))
			bridge.calls.clear()
		input.dispose(); bridge.free()
	metrics.oracle_scenarios = fixture.scenarios.size(); metrics.oracle_source_sha256 = fixture.source_sha256

func boundaries() -> void:
	var absent := InputPort.new()
	check(not absent.configure({}).get("ok",false),"missing bridge rejected")
	check(absent.press().get("error")=="unavailable","unconfigured cannot admit")
	var bridge := Bridge.new(); var other := Bridge.new()
	var mixed := bridge.ports(); mixed.setWalkMeleeBlock = Callable(other,"block_port")
	check(absent.configure(mixed).get("error")=="mixed_bridge_owners","single actual bridge owner required")
	check(absent.configure(bridge.ports()).get("ok",false),"failed configure may be corrected before any mutation")
	absent.dispose(); other.free(); bridge.free()
	bridge = Bridge.new(); var input := fresh(bridge)
	check(input.configure(bridge.ports()).get("error")=="configuration","no silent bridge rebind")
	var reply: Dictionary = input.press({"time":0})
	bridge.last_reply.contactWindow[0] = -999
	reply.start.contactWindow[1] = -999; reply.start.type = "tampered"
	var untouched: Dictionary = input.step({"time":.1})
	check(untouched.start.contactWindow==[35,190] and untouched.start.type=="punch","source and public reply windows/metadata privately copied")
	var before := bridge.calls.size()
	check(input.step({"allowed":"yes"}).get("error")=="options" and bridge.calls.size()==before,"invalid boundary type cannot call source")
	input.cancel(); input.dispose()
	check(input.press().get("error")=="unavailable","disposed port cannot call source")
	bridge.free()
	bridge = Bridge.new(); input = fresh(bridge); bridge.free()
	check(input.press({"time":0}).get("error")=="bridge_lifetime","freed bridge rejected")
	input.dispose()
	bridge = Bridge.new(); input = fresh(bridge); bridge.reenter = input
	var reentered: Dictionary = input.press({"time":0})
	check(reentered.get("error")=="reentry" and reentered.get("may_have_dispatched",false),"callback reentry faults without falsely reporting a safe rejection")
	check(bridge.reentry_result.get("error")=="reentry" and bridge.calls.size()==2,"reentry sends no cancellation/duplicate source command")
	before = bridge.calls.size()
	check(input.cancel().get("error")=="reentry" and bridge.calls.size()==before,"faulted input never retries source")
	bridge.reenter = null; input.dispose(); bridge.free()
	bridge = Bridge.new(); input = fresh(bridge); bridge.free_on_begin = true
	var freed: Dictionary = input.press({"time":0})
	check(freed.get("error")=="bridge_lifetime" and freed.get("may_have_dispatched",false),"owner queued for deletion inside callback fails closed after one attempt")
	input.dispose(); bridge.free()
	bridge = Bridge.new(); input = fresh(bridge); bridge.clock = NAN
	check(input.step().get("error")=="finite_time_required" and bridge.calls.is_empty(),"invalid fallback time rejects before dispatch")
	input.dispose(); bridge.free()
	bridge = Bridge.new(); input = fresh(bridge); bridge.free_on_clock = true
	check(input.step().get("error")=="clock_lifetime" and bridge.calls.is_empty(),"clock queued for deletion fails before input state/dispatch")
	input.dispose(); bridge.free()
	bridge = Bridge.new(); other = Bridge.new(); input = InputPort.new()
	check(input.configure(bridge.ports(),Callable(other,"now_seconds")).get("ok",false),"separate clock provider allowed")
	other.free()
	check(input.step({"time":3}).has("action"),"explicit finite source time does not need clock callback")
	check(input.step().get("error")=="clock_lifetime" and bridge.calls.is_empty(),"freed fallback clock rejected")
	input.dispose(); bridge.free()
	bridge = Bridge.new(); input = fresh(bridge); bridge.clock = 4
	var fallback: Dictionary = input.press({"time":NAN,"yaw":NAN,"airHeight":NAN})
	check(fallback.start.time==4 and fallback.start.yaw==0 and fallback.start.airHeight==0,"source nonfinite fallback conversions retained")
	input.cancel(); input.dispose(); bridge.free()
	bridge = Bridge.new(); input = fresh(bridge); bridge.settings.contactWindow = [Node.new()]
	check(input.press({"time":0}).get("error")=="bridge_reply","object-bearing successful reply rejected")
	bridge.settings.contactWindow[0].free(); input.dispose(); bridge.free()
	bridge = Bridge.new(); input = InputPort.new()
	var invalid_ports := bridge.ports(); invalid_ports.setWalkMeleeCharge = Callable(bridge,"wrong_charge")
	check(input.configure(invalid_ports).get("error") == "bridge_arity:setWalkMeleeCharge","wrong callback arity rejected before dispatch")
	check(bridge.calls.is_empty(),"arity check does not invoke source")
	invalid_ports.setWalkMeleeCharge = Callable(bridge,"missing_ack")
	check(input.configure(invalid_ports).get("ok",false),"one-argument acknowledgement fixture configured")
	var failed_ack: Dictionary = input.press({"time":0})
	check(failed_ack.get("error") == "bridge_ack:setWalkMeleeCharge" and failed_ack.get("may_have_dispatched",false),"missing setter acknowledgement faults after possible source mutation")
	check(bridge.calls == [["charge",true]],"failed charge cannot dispatch begin")
	before = bridge.calls.size()
	check(input.press({"time":1}).get("error") == "bridge_ack:setWalkMeleeCharge" and bridge.calls.size() == before,"failed callback cannot retry")
	input.dispose(); bridge.free()

func cost() -> void:
	var bridge := Bridge.new(); var input := fresh(bridge)
	var idle: Array[int] = []; var active: Array[int] = []
	for i in 2400:
		var start := Time.get_ticks_usec(); input.step({"time":float(i)/60.0})
		if i>=400: idle.append(Time.get_ticks_usec()-start)
	check(bridge.calls.is_empty(),"idle benchmark makes zero source callbacks")
	for i in 2400:
		var time := 50.0+i*2.0
		var start := Time.get_ticks_usec()
		input.press({"time":time}); input.step({"time":time+.17}); input.release({"time":time+.2})
		if i>=400: active.append(Time.get_ticks_usec()-start)
		bridge.calls.clear()
	idle.sort(); active.sort()
	metrics.cpu_us = {"idle_step":{"p50":idle[1000],"p95":idle[1900],"max":idle[-1]},"press_sample_release_triplet":{"p50":active[1000],"p95":active[1900],"max":active[-1]},"samples_per_case":2000,"scope":"Headless input module only; no full scene FPS claim"}
	input.cancel(); input.dispose(); bridge.free()

func _initialize() -> void:
	parity(); boundaries(); cost()
	metrics.merge({"checks":checks,"passed":failures.is_empty(),"failures":failures,"module_sha256":FileAccess.get_sha256("res://scripts/combat/melee_input.gd")})
	DirAccess.make_dir_recursive_absolute("../../outputs/melee_input")
	var file := FileAccess.open("../../outputs/melee_input/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t")); file.close()
	print("MELEE_INPUT_TEST ",JSON.stringify(metrics))
	quit(0 if failures.is_empty() else 1)
