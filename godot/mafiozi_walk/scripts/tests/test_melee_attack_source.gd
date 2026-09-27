extends SceneTree
const Attack=preload("res://scripts/combat/melee_attack_source.gd")
const InputProjection=preload("res://scripts/combat/melee_input.gd")
var checks:=0
var failures:Array=[]
var timings:Array=[]
class Host extends Node:
	var state_data:Dictionary={}
	var clock:=0.0
	var rolls:Array=[]
	var draws:=0
	var effects:Array=[]
	var resolution:Dictionary={}
	var contacts:Array=[]
	var fail_kind:=""
	var attack:RefCounted
	func state()->Dictionary:return state_data.duplicate(true)
	func clock_ms()->float:return clock
	func rng()->Variant:
		if draws>=rolls.size():return null
		var value:Variant=rolls[draws];draws+=1;return value
	func effect(event:Dictionary)->Variant:
		effects.append(event.duplicate(true))
		if fail_kind=="reentry" and event.kind=="heading":attack.beginWalkMelee({"angle":0})
		if fail_kind=="retire" and event.kind=="heading":queue_free()
		if fail_kind=="runtime" and event.kind=="heading":return _broken_effect()
		if fail_kind==event.kind:return null
		return {"ok":true}
	func _broken_effect()->Variant:
		# Intentional actual GDScript runtime failure: the caller must receive
		# null and stop, rather than assuming a caught JS exception.
		var invalid:Variant=7
		return invalid.required_source_effect()
	func resolve_contact(envelope:Dictionary,request:Dictionary)->Variant:
		contacts.append({"envelope":envelope,"request":request})
		return null if fail_kind=="resolve" else resolution.duplicate(true)
	func ports()->Dictionary:return {"state":state,"clock_ms":clock_ms,"rng":rng,"effect":effect,"resolve_contact":resolve_contact}
func _initialize():run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<40:failures.append(label)
func same(a:Variant,b:Variant,path:String)->void:
	if (a is float or a is int) and (b is float or b is int):check(absf(float(a)-float(b))<1e-9,path+":number "+str(a)+" != "+str(b));return
	if a is Dictionary and b is Dictionary:
		check(a.size()==b.size(),path+":keys "+str(a.keys())+" != "+str(b.keys()))
		for key:Variant in b:
			check(a.has(key),path+":missing "+str(key))
			if a.has(key):same(a[key],b[key],path+"/"+str(key))
		return
	if a is Array and b is Array:
		check(a.size()==b.size(),path+":array_size")
		for i in mini(a.size(),b.size()):same(a[i],b[i],path+"/"+str(i))
		return
	check(a==b,path+":value "+str(a)+" != "+str(b))
func make_host(initial:Dictionary)->Host:
	var host:=Host.new();root.add_child(host);host.state_data=initial.duplicate(true);host.attack=Attack.new()
	check(host.attack.configure(host.ports()).get("ok",false),"configure")
	return host
func dispatch(host:Host,operation:Dictionary)->Variant:
	match str(operation.method):
		"begin":return host.attack.beginWalkMelee(operation.arg)
		"block":return host.attack.setWalkMeleeBlock(operation.arg)
		"charge":return host.attack.setWalkMeleeCharge(operation.arg)
		"resolve":return host.attack.resolveWalkMelee(operation.arg)
		"reset":return host.attack.reset(operation.arg)
		"advance":return host.attack.advance()
	return null
func run()->void:
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/melee_attack_source_oracle.json"))
	var source_path:="res://../../world.html"
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-path="):source_path=arg.trim_prefix("--source-path=")
	var observed_source:=FileAccess.get_file_as_string(source_path)
	check(oracle.source.sections.size()==4,"four_source_sections")
	for section:Dictionary in oracle.source.sections:
		var begin:=observed_source.find(section.start)
		var end:=observed_source.find(section.end,begin+str(section.start).length()) if begin>=0 else -1
		check(begin>=0 and end>begin and observed_source.find(section.start,begin+str(section.start).length())<0,"source_slice_boundaries "+section.start)
		if begin<0 or end<=begin:continue
		var used:=observed_source.substr(begin,end-begin).replace("\r\n","\n")
		check(used.to_utf8_buffer().size()==int(section.bytes),"source_slice_bytes "+section.start)
		check(used.sha256_text()==section.sha256,"source_slice_hash "+section.start)
	var operations:=0;var delegated:=0
	for scenario:Dictionary in oracle.scenarios:
		var host:=make_host(scenario.initial);host.rolls=scenario.rolls.duplicate()
		for row:Dictionary in scenario.operations:
			operations+=1;host.clock=float(row.time);host.state_data.merge(row.state,true);host.effects=[];host.contacts=[]
			host.resolution=row.reply if row.reply is Dictionary else {}
			var before_draws:=host.draws;var at:=Time.get_ticks_usec();var reply:Variant=dispatch(host,row);timings.append(Time.get_ticks_usec()-at)
			var label:String=scenario.name+":"+str(operations)+":"+row.method
			same(reply,row.reply,label+"/reply");same(host.effects,row.effects,label+"/effects");same(host.attack.snapshot(),row.snapshot,label+"/state")
			check(host.draws==int(row.draws),label+"/rng_count")
			if not host.contacts.is_empty():
				delegated+=1;check(row.method=="resolve",label+"/only_resolve_delegates")
				check(not host.attack.snapshot().pending.size(),label+"/consumed_before_owner")
				check(host.contacts[0].envelope.contactAge<=host.contacts[0].envelope.age,label+"/no_future_contact")
			if row.method!="begin":check(host.draws==before_draws,label+"/no_extra_rng")
		host.attack=null;host.free()
	var initial:Dictionary=oracle.scenarios[0].initial
	# Godot callback runtime failures return null, not catchable JS exceptions.
	# Every required acknowledgement must stop all later source effects.
	for kind:String in ["heading","telemetry","camera_kick","cooldown","renew_locks","reentry","retire","runtime"]:
		var host:=make_host(initial);host.clock=500;host.rolls=[.8];host.fail_kind=kind
		var result:Dictionary=host.attack.beginWalkMelee({"angle":.3})
		check(result.get("valid")==false,"fault_rejected:"+kind)
		check(not host.attack.snapshot().begin_context,"fault_clears_begin:"+kind)
		check(host.attack.snapshot().pending.is_empty(),"fault_no_pending:"+kind)
		check(host.effects.back().kind==("heading" if kind in ["reentry","retire","runtime"] else kind),"no_later_effect:"+kind)
		var count:=host.effects.size();host.clock=1000;host.attack.beginWalkMelee({"angle":0})
		check(host.effects.size()==count,"fault_latches:"+kind)
		host.attack=null;host.free()
	var missing:=Host.new();root.add_child(missing);var partial:=missing.ports();partial.erase("resolve_contact")
	check(not Attack.new().configure(partial).get("ok",true),"mandatory_contact_owner")
	missing.free()
	var no_network:=make_host(initial);no_network.state_data.erase("ws_open");no_network.clock=500
	check(no_network.attack.beginWalkMelee({"angle":0}).get("valid")==false,"no_assumed_offline")
	check(no_network.effects.is_empty(),"missing_state_no_effects");no_network.attack=null;no_network.free()
	var bad_rng:=make_host(initial);bad_rng.clock=500
	check(bad_rng.attack.beginWalkMelee({"angle":0}).get("valid")==false,"missing_rng_fault")
	check(bad_rng.effects.size()==1 and bad_rng.effects[0].kind=="heading","no_effect_after_rng_fault");bad_rng.attack=null;bad_rng.free()
	var retired:=make_host(initial);retired.clock=500;retired.rolls=[.5];retired.queue_free()
	check(retired.attack.beginWalkMelee({"angle":0}).get("valid")==false,"queued_owner")
	check(retired.effects.is_empty(),"queued_no_effects");retired.attack=null;retired.free()
	for reply:Variant in [null,{}, {"accepted":true}, {"accepted":true,"hit":true}, {"accepted":false}]:
		var host:=make_host(initial);host.clock=500;host.rolls=[.8];host.attack.beginWalkMelee({"angle":0});host.clock=550;host.effects=[]
		if reply==null:host.fail_kind="resolve"
		else:host.resolution=reply
		check(host.attack.resolveWalkMelee({"seq":1,"contact":{"npcId":"TEST_ONLY"}}).get("valid")==false,"contact_ack_required")
		check(host.attack.snapshot().pending.is_empty(),"bad_contact_reply_consumed")
		check(host.effects.is_empty(),"no_extra_effect_after_contact_fault");host.attack=null;host.free()
	# Real input projection wired to this real admission owner, with one shared
	# explicit clock. This is still TEST_ONLY host state, not actual gameplay.
	var integrated:=make_host(initial);integrated.clock=500;integrated.rolls=[.8]
	var input:=InputProjection.new()
	check(input.configure({"beginWalkMelee":integrated.attack.beginWalkMelee,"setWalkMeleeCharge":integrated.attack.setWalkMeleeCharge,"setWalkMeleeBlock":integrated.attack.setWalkMeleeBlock}).get("ok",false),"actual_input_ports")
	var first:Dictionary=input.press({"time":.5,"yaw":.2})
	check(first.get("started",false) and first.action.type=="punch","actual_input_first_punch")
	integrated.clock=1700;integrated.attack.advance()
	var heavy:Dictionary=input.step({"time":1.7})
	check(heavy.get("started",false) and heavy.action.type=="heavy","actual_input_charged_heavy")
	check(integrated.draws==1,"actual_input_no_heavy_rng")
	integrated.clock=1710;input.release({"time":1.71})
	check(integrated.attack.snapshot().pending.get("chargeHeld",false),"actual_input_retains_server_charge")
	integrated.clock=1770
	check(integrated.attack.resolveWalkMelee({"seq":2})=={"accepted":true,"hit":false},"actual_input_window_miss")
	check(integrated.attack.snapshot().pending.is_empty(),"actual_input_pending_consumed")
	integrated.attack=null;integrated.free()
	# Host contract violation: begin at the allowed cadence without ever
	# servicing advance. Bound the queue without silently expiring callbacks.
	var backlog:=make_host(initial);backlog.rolls=Array([.8,.8,.8,.8,.8,.8,.8,.8,.8,.8])
	for i in Attack.MAX_PENDING_TIMERS:
		backlog.clock=float((i+1)*300)
		check(backlog.attack.beginWalkMelee({"angle":0}).get("accepted",false),"backlog_within_capacity")
	var retained:Dictionary=backlog.attack.snapshot();backlog.effects=[]
	for i in 100:
		backlog.clock+=300
		check(backlog.attack.beginWalkMelee({"angle":0})=={"accepted":false,"reason":"timer-backlog"},"backlog_explicit_rejection")
	check(backlog.attack.snapshot()==retained,"backlog_preserves_all_source_state_and_timers")
	check(backlog.effects.is_empty() and backlog.draws==Attack.MAX_PENDING_TIMERS,"backlog_no_effect_or_rng")
	check(backlog.attack.advance().get("ok",false),"backlog_explicit_drain")
	check(backlog.effects.size()==Attack.MAX_PENDING_TIMERS and backlog.attack.snapshot().timers==0,"backlog_runs_every_original_callback")
	for event:Dictionary in backlog.effects:check(event.kind=="cooldown" and event.active==false,"backlog_callback_not_discarded")
	check(backlog.attack.beginWalkMelee({"angle":0}).get("accepted",false),"backlog_recovers_after_real_service")
	backlog.attack=null;backlog.free()
	var heavy_backlog:=make_host(initial);heavy_backlog.rolls=[.8,.8,.8,.8,.8,.8,.8]
	for i in 7:
		heavy_backlog.clock=float((i+1)*300);heavy_backlog.attack.beginWalkMelee({"angle":0})
	heavy_backlog.clock=2200;heavy_backlog.attack.setWalkMeleeCharge(true)
	heavy_backlog.clock=3400;heavy_backlog.effects=[];retained=heavy_backlog.attack.snapshot()
	check(heavy_backlog.attack.beginWalkMelee({"angle":0,"heavy":true})=={"accepted":false,"reason":"timer-backlog"},"heavy_reserves_both_callbacks")
	check(heavy_backlog.attack.snapshot()==retained and heavy_backlog.effects.is_empty() and heavy_backlog.draws==7,"heavy_refusal_has_no_partial_commit")
	heavy_backlog.attack.advance()
	check(heavy_backlog.attack.beginWalkMelee({"angle":0,"heavy":true}).get("accepted",false),"heavy_charge_preserved_until_service")
	check(heavy_backlog.attack.snapshot().timers==2,"heavy_exact_two_reserved_callbacks")
	heavy_backlog.attack=null;heavy_backlog.free()
	timings.sort()
	var report:Dictionary={"checks":checks,"failures":failures,"scenarios":oracle.scenarios.size(),"operations":operations,"delegated_contact_calls":delegated,"cpu_us":{"p50":timings[timings.size()/2],"p95":timings[int(timings.size()*.95)]},"sha256":FileAccess.get_sha256("res://scripts/combat/melee_attack_source.gd"),"source":oracle.source,"qualification":"Executed original JS admission/setter/pending transcript parity. Remaining actual contact/ref/HP/server resolution is a required external owner, not implemented or authenticated by this fixture. Headless CPU only."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../../outputs/coordinator21_melee_attack_source"))
	var f:=FileAccess.open("res://../../outputs/coordinator21_melee_attack_source/report.json",FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(report,"\t"));f.close()
	print("MELEE_ATTACK_SOURCE ",JSON.stringify(report));quit(0 if failures.is_empty() and f!=null else 1)
