extends SceneTree

const FIXTURE_PATH="res://data/transport/source_debris_copy_event.json"
const FIXTURE_SHA="5c748173306afb6b6acd1136f84749fe0f3196465e841849db415e76a4c59281"
const EXPORTER_SHA="bc7cf288fd898335cfd4c39ec6916710314f5bcbaf41167ddb023cd8e1a51d98"
const DAMAGE_SHA="e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92"
const BATCH_SHA="a9b4c0c93652b52e29a2c29fe65748bdf451122594583d3bd455238f766df648"
const PROFILE_IDS:= ["city_hatchback","compact_sedan","family_wagon","executive_sedan","sport_coupe","city_suv","delivery_van","utility_pickup","city_bus","police_interceptor","city_ambulance","fire_engine","city_taxi"]

var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var begin:=Time.get_ticks_usec()
	check(FileAccess.get_sha256(FIXTURE_PATH)==FIXTURE_SHA,"fixture SHA pin")
	var repo_root:=ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	check(FileAccess.get_sha256(repo_root.path_join("tools/godot/export_transport_debris_copy_event_oracle.mjs"))==EXPORTER_SHA,"current exporter SHA")
	check(FileAccess.get_sha256(repo_root.path_join("assets/maps/city_rebuild_v1/vehicle_damage.mjs"))==DAMAGE_SHA,"current production damage source SHA")
	check(FileAccess.get_sha256(repo_root.path_join("assets/maps/city_rebuild_v1/vehicle_render_batches.mjs"))==BATCH_SHA,"current production batch source SHA")
	var file:=FileAccess.open(FIXTURE_PATH,FileAccess.READ)
	check(file!=null,"fixture opens")
	if file==null: return finish(begin,{})
	var parsed: Variant=JSON.parse_string(file.get_as_text())
	check(parsed is Dictionary,"fixture parses")
	if not parsed is Dictionary: return finish(begin,{})
	var root: Dictionary=parsed
	check(root.get("schema")=="mafiozi.transport-debris-copy-event-oracle.v1","schema exact")
	check(root.get("status")=="EXECUTED_SOURCE_TEST_ONLY" and root.get("three_revision")=="180","source execution scope")
	var method: Dictionary=root.get("proof_method",{})
	check(method.get("production_source_modified") == false,"production source untouched")
	check(method.get("damage_sha256")==DAMAGE_SHA and method.get("batches_sha256")==BATCH_SHA,"critical source SHA pins")
	var source_map:={}
	for row: Variant in root.get("source_files",[]):
		if row is Dictionary: source_map[row.get("path")]=row.get("sha256")
	check(source_map.get("assets/maps/city_rebuild_v1/vehicle_damage.mjs")==DAMAGE_SHA,"loaded damage source pin")
	check(source_map.get("assets/maps/city_rebuild_v1/vehicle_render_batches.mjs")==BATCH_SHA,"loaded batch source pin")
	var rows: Array=root.get("profiles",[])
	check(rows.size()==18,"thirteen baseline plus five callback cases")
	var normal_ids: Array=[]; var total_events:=0; var total_accepted:=0; var mutation_seen:=false; var detail_seen:=false; var fallback_seen:=false; var hidden_root_seen:=false; var throw_seen:=false
	for value: Variant in rows:
		check(value is Dictionary,"case row dictionary")
		if not value is Dictionary: continue
		var row: Dictionary=value; total_events+=int(row.get("event_count",0))
		var kind:=String(row.get("case","")); var profile:=String(row.get("profile_id",""))
		if kind=="normal": normal_ids.append(profile)
		var summary: Dictionary=row.get("summary",{}); total_accepted+=int(summary.get("accepted",0))
		check(summary.get("roots",[]).size()<=10 and (kind=="throw" or summary.get("roots",[]).size()>0),"bounded ordered roots "+profile+"/"+kind)
		check(int(summary.get("rng_calls",-1))==int(summary.get("accepted",0))*7,"seven RNG draws per accepted root "+profile+"/"+kind)
		check(int(summary.get("state_calls",-1))==int(summary.get("accepted",0)),"one getState per accepted root "+profile+"/"+kind)
		check(summary.get("hidden",[]).size()==int(summary.get("accepted",0)),"one source hide per accepted root "+profile+"/"+kind)
		check(_monotonic_events(row.get("events",[])),"strict event sequence "+profile+"/"+kind)
		if kind=="throw":
			throw_seen=true; _check_throw(row)
		else:
			_check_completed(row)
		if kind=="mutation":
			mutation_seen=true; _check_mutation(row)
		elif kind=="detail_disabled":
			detail_seen=true; _check_detail_disabled(row)
		elif kind=="hidden_fallback":
			fallback_seen=true; _check_hidden_fallback(row)
		elif kind=="hidden_root":
			hidden_root_seen=true; _check_hidden_root(row)
	normal_ids.sort()
	var expected:=PROFILE_IDS.duplicate(); expected.sort()
	check(normal_ids==expected,"all thirteen exact baseline profiles")
	check(mutation_seen and detail_seen and fallback_seen and hidden_root_seen and throw_seen,"bounded callback replacement/detail/fallback/root-skip/throw cases")
	var elapsed:=Time.get_ticks_usec()-begin
	finish(begin,{"parse_validate_us":elapsed,"fixture_bytes":FileAccess.get_file_as_bytes(FIXTURE_PATH).size(),"cases":rows.size(),"events":total_events,"accepted_roots":total_accepted})

func _check_completed(row: Dictionary) -> void:
	var label:=String(row.profile_id)+"/"+String(row.case); var events: Array=row.events
	check(row.get("thrown") == null,"completed case no throw "+label)
	var order:=[]
	for kind in ["after_char","callback_enter","callback_return","after_callback","after_glass","detach_roots","detach_complete","after_detach"]: order.append(_first(events,kind))
	check(_strictly_increasing(order),"char callback glass detach order "+label)
	var getters:=0; var copy_getters:=0; var rejects:=0; var reject_reasons:={}
	for i in events.size():
		var event: Dictionary=events[i]
		if event.kind=="batch_getter": getters+=1
		elif event.kind=="copy_getter": copy_getters+=1
		elif event.kind=="copy_reject":
			rejects+=1
			reject_reasons[event.get("reason")]=true
			check(i+1>=events.size() or events[i+1].kind!="copy_getter" or events[i+1].source!=event.source,"reject skips getter "+label)
	check(getters==copy_getters and getters==int(row.summary.batch_getter_calls),"actual batch getter paired with copy getter "+label)
	if row.get("case")=="hidden_fallback":
		check(rejects>0 and reject_reasons.has("invisible") and not reject_reasons.has("render_batch"),"fallback removes reached batch proxy before copy "+label)
	else:
		check(rejects>0 and reject_reasons.has("invisible") and reject_reasons.has("render_batch"),"post-glass invisible and batch rejection observed "+label)
	var roots: Array=row.summary.roots; var completed: Array=[]; var seen:={}; var expected_cursor:=0
	for event: Variant in events:
		if not event is Dictionary: continue
		if event.kind=="detach_root_complete":
			var index:=int(event.index); check(index>=0 and index<roots.size() and not seen.has(index),"completed original root index unique/in range "+label)
			seen[index]=true; completed.append(index)
		elif event.kind=="random":
			check(int(event.cursor)==expected_cursor,"RNG cursor contiguous "+label); expected_cursor+=1
	check(completed.size()==int(row.summary.accepted),"accepted count equals actual completed indexes "+label)
	for root_index in completed: _check_root_block(events,int(root_index),String(roots[int(root_index)]),label)
	var copied: Array=row.get("after",{}).get("copied_nodes",[])
	check(copied.size()>=int(row.summary.accepted),"copied hierarchy retained as digests "+label)
	var charred: Array=row.get("after",{}).get("charred_materials",[])
	check(not charred.is_empty() and charred.all(func(item): return item is Dictionary and item.get("changed")==true and item.get("before")!=item.get("after")),"captured opaque materials actually charred "+label)
	var mass:=float(row.get("after",{}).get("fleet_mass_kg",0)); var expected_hp:=clampi(roundi(mass*.16),240,1200)
	check(int(row.get("after",{}).get("fleet_damage_max_hp",0))==expected_hp,"actual fleet mass-derived HP "+label)

func _check_root_block(events: Array,root_index: int,root_source: String,label: String) -> void:
	var begin:=-1; var end:=-1
	for i in events.size():
		var event: Dictionary=events[i]
		if event.kind=="detach_root_begin" and int(event.index)==root_index: begin=i
		if event.kind=="detach_root_complete" and int(event.index)==root_index: end=i; break
	check(begin>=0 and end>begin,"root block exists "+label+"/"+str(root_index))
	if begin<0 or end<=begin: return
	check(events[begin].source==root_source and events[end].source==root_source,"root index binds original source identity "+label+"/"+str(root_index))
	var tail: Array=[]
	for i in range(begin,end+1):
		var kind: String=events[i].kind
		if kind in ["source_hidden","random","get_state","detach_root_complete"]: tail.append(kind)
		if kind in ["random","get_state"]: check(int(events[i].index)==root_index,"RNG/state tagged to original root "+label+"/"+str(root_index))
	check(tail==["source_hidden","random","random","get_state","random","random","random","random","random","detach_root_complete"],"exact hide/RNG/getState order "+label+"/"+str(root_index))

func _check_throw(row: Dictionary) -> void:
	var events: Array=row.events
	check(row.get("thrown")=="ORACLE_CALLBACK_THROW","real callback error escapes")
	check(_first(events,"after_char")>=0 and _first(events,"callback_enter")>_first(events,"after_char"),"throw occurs after char")
	check(_first(events,"outer_catch")>_first(events,"callback_enter"),"outer exporter catches source throw")
	for kind in ["callback_return","after_callback","after_glass","detach_roots","copy_visit","source_hidden","random","get_state","after_detach"]:
		check(_first(events,kind)<0,"throw prevents "+kind)
	var charred: Array=row.get("after",{}).get("charred_materials",[])
	check(not charred.is_empty() and charred.all(func(item): return item is Dictionary and item.get("changed")==true and item.get("before")!=item.get("after")),"throw preserves measured partial char")
	check(int(row.summary.accepted)==0 and row.get("after",{}).get("copied_nodes",[]).is_empty(),"throw creates no detached copies")

func _check_mutation(row: Dictionary) -> void:
	var events: Array=row.events; var mutation: Dictionary={}
	for event: Variant in events:
		if event is Dictionary and event.get("kind")=="callback_mutation": mutation=event; break
	check(not mutation.is_empty(),"callback replacement recorded")
	if mutation.is_empty(): return
	var getter: Dictionary={}
	for event: Variant in events:
		if event is Dictionary and event.get("kind")=="batch_getter" and event.get("source")==mutation.get("source"): getter=event; break
	check(not getter.is_empty(),"postcallback source traversed")
	if getter.is_empty(): return
	check(getter.get("registered")==true,"replacement node retained batch registration")
	check(getter.get("current",[])==[mutation.get("replacement_material")],"getter sees callback replacement current identity")
	check(getter.get("result",[])==getter.get("current",[]) and getter.get("result",[])!=getter.get("canonical",[]),"actual getter returns replacement after callback")

func _check_detail_disabled(row: Dictionary) -> void:
	var events: Array=row.events
	check(_first(events,"callback_detail_disabled")>_first(events,"callback_enter"),"detail disable happens inside callback")
	var registered:=0; var canonical_current:=0; var hidden_current:=0
	for event: Variant in events:
		if event is Dictionary and event.get("kind")=="batch_getter" and event.get("registered")==true:
			registered+=1
			check(event.get("result",[])==event.get("canonical",[]),"detail-disabled getter resolves canonical")
			if event.get("current",[])==event.get("canonical",[]): canonical_current+=1
			elif event.get("current",[])==event.get("hidden",[]): hidden_current+=1
			else: check(false,"detail-disabled registered current is canonical or hidden")
	check(registered>0 and canonical_current>0 and hidden_current>0,"detail toggle affects only source detail groups")

func _check_hidden_fallback(row: Dictionary) -> void:
	var events: Array=row.events; var fallback: Dictionary={}
	for event: Variant in events:
		if event is Dictionary and event.get("kind")=="callback_hidden_fallback": fallback=event; break
	check(not fallback.is_empty(),"hidden mutation fallback recorded")
	if fallback.is_empty(): return
	var getter: Dictionary={}
	for event: Variant in events:
		if event is Dictionary and event.get("kind")=="batch_getter" and event.get("source")==fallback.get("source"): getter=event; break
	check(not getter.is_empty(),"fallback source copied after callback")
	if getter.is_empty(): return
	check(getter.get("registered")==false,"hidden mutation removes batch registration before detach")
	check(getter.get("current",[])==[fallback.get("hidden_material")] and getter.get("result",[])==getter.get("current",[]),"fallback getter returns retained mutated hidden identity")

func _check_hidden_root(row: Dictionary) -> void:
	var events: Array=row.events; var hidden: Dictionary={}; var rejected: Dictionary={}; var completed: Array=[]
	for event: Variant in events:
		if not event is Dictionary: continue
		if event.kind=="callback_hidden_root": hidden=event
		elif event.kind=="detach_root_reject" and int(event.index)==0: rejected=event
		elif event.kind=="detach_root_complete": completed.append(int(event.index))
	check(not hidden.is_empty() and int(hidden.get("original_index",-1))==0,"callback hides original root zero")
	check(row.summary.roots.size()==10 and hidden.get("source")==row.summary.roots[0],"hidden callback identity is roots[0]")
	check(not rejected.is_empty() and rejected.get("source")==hidden.get("source"),"source rejects hidden original index zero")
	check(int(row.summary.rejected)==1 and int(row.summary.accepted)==9 and not completed.has(0) and completed.has(1) and completed.has(9),"later roots retain original indexes after gap")
	for event: Variant in events:
		if event is Dictionary and event.kind in ["source_hidden","random","get_state"]: check(int(event.get("index",-1))!=0,"skipped root consumes no hide/RNG/getState")

func _monotonic_events(events: Variant) -> bool:
	if not events is Array: return false
	for i in events.size():
		if not events[i] is Dictionary or int(events[i].get("seq",-1))!=i: return false
	return true
func _first(events: Array,kind: String) -> int:
	for i in events.size():
		if events[i] is Dictionary and events[i].get("kind")==kind: return i
	return -1
func _strictly_increasing(values: Array) -> bool:
	var prior:=-1
	for value in values:
		if int(value)<=prior: return false
		prior=int(value)
	return true
func finish(_begin: int,metrics: Dictionary) -> void:
	print("TRANSPORT_DEBRIS_COPY_EVENT_ORACLE "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"fixture_sha":FIXTURE_SHA,"metrics":metrics,"scope":"executed source test oracle only; no native event seam, authority, physics, GPU, LIVE or FPS"}))
	quit(0 if failures.is_empty() else 1)
