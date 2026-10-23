extends SceneTree
const Batch = preload("res://scripts/npc_visual/npc_placement_batch.gd")
const Solver = preload("res://scripts/npc_visual/npc_initial_placement.gd")
const Queue = preload("res://scripts/navigation/path_job_queue.gd")
const ContextPath = "res://../../outputs/astra21_npc_full_startup/d3d0596340658f9e5238977e99d2c900ff7cdbbe40d09c4f3096aa46089880a8/context.json"
const OraclePath = "res://../../outputs/astra21_npc_placement_oracle/ORACLE.json"
class Ports extends Node:
	func body(_key:String,_kind:String,_raw:Dictionary,_r:float,_c:float)->bool:return true
	func clock()->float:return 0.0
	func lease(_receipt:Dictionary)->bool:return true
var checks:=0
var errors:Array[String]=[]
var bytes:PackedByteArray
var owners:Dictionary={}
var batch:RefCounted
var mode:="pass"
var queries:=0
var lease_calls:=0
var clock_value:=0.0
var clock_real:=false
var current:=true
var oracle:Dictionary
var replay_index:=0
var trace:Array=[]
var timings:Array=[]
func _initialize():call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:errors.append(label)
func trust()->Dictionary:
	return {"context_sha256":Solver.CONTEXT_SHA,"source_world_sha256":Solver.SOURCE_SHA,"session_id":Solver.SESSION,"phase":Solver.PHASE,
		"provider":{"id":"TEST_ONLY_batch_source_body","version":"1","semantics":"ROLE_BODY_PASS","sha256":Solver.SOURCE_SHA},
		"interior_state":{"source_world_sha256":Solver.SOURCE_SHA,"_buildingInt":null,"_bankInt":null,"_majorInteriorObjectId":null},"aggregate_revision":1}
func clock_ms()->float:return float(Time.get_ticks_usec())/1000.0 if clock_real else clock_value
func lease(receipt:Dictionary)->Variant:
	lease_calls+=1
	check(receipt.aggregate_revision==1,"aggregate receipt is privately copied")
	receipt.aggregate_revision=999
	if mode=="lease_reentry":batch.step()
	if mode=="lease_dispose":batch.dispose()
	if mode=="lease_badtype":return 1
	if mode=="lease_second_false" and lease_calls%2==0:return false
	return current
func body_pass(key:String,kind:String,raw:Dictionary,r:float,c:float)->Variant:
	queries+=1
	if mode=="replay":
		var expected:Dictionary=oracle.synthetic_search_and_spacing.queries[replay_index]
		check(expected.object_key==key and expected.kind==kind and absf(expected.r-r)<1e-10 and absf(expected.c-c)<1e-10,"exact originalJS query "+str(replay_index))
		replay_index+=1
		return expected.result
	if mode=="unknown":return null
	if mode=="reentry":batch.candidates()
	if mode=="dispose":batch.dispose()
	if mode=="revoke":current=false
	if mode=="death":owners.resident_72.dead=true
	if mode=="blocked":return false
	raw.id="MUTATED_PRIVATE_BODY_ARGUMENT"
	return true
func fresh(use_clock:=false)->void:
	if is_instance_valid(batch):batch.dispose()
	mode="pass";queries=0;lease_calls=0;clock_value=0;clock_real=use_clock;current=true;replay_index=0
	owners={}
	for id in ["resident_72","resident_169","resident_252"]:owners[id]=Queue.Owner.new(id,1)
	batch=Batch.new()
	var started:=Time.get_ticks_usec()
	check(batch.configure(bytes,trust(),body_pass,lease,clock_ms,owners).ok,"full context configured")
	timings.append({"configure_us":Time.get_ticks_usec()-started})
func complete()->void:
	for i in 100:
		var result:Dictionary=batch.step()
		check(not result.has("events"),"no partial events in step result")
		if result.status=="COMPLETE":return
		if result.status!="PENDING":check(false,"unexpected terminal "+str(result));return
		check(batch.candidates().is_empty() and batch.placement_receipt().is_empty(),"private until COMPLETE")
	check(false,"completion bounded fixture limit")
func find_event(events:Array,id:String)->Dictionary:
	for e:Dictionary in events:
		if e.raw_id==id:return e
	return {}
func run()->void:
	bytes=FileAccess.get_file_as_bytes(ContextPath)
	check(Solver._hash(bytes)==Solver.CONTEXT_SHA,"actual full source bytes pinned")
	var solver_hash:=FileAccess.get_sha256("res://scripts/npc_visual/npc_initial_placement.gd")
	check(solver_hash=="7450d532ccf12e85eb04411c1d676faad43427fac472b44befa8ef10a667106a","accepted actual solver pin")
	oracle=JSON.parse_string(FileAccess.get_file_as_string(OraclePath))
	fresh()
	check(batch.state().source_objects==326 and batch.state().eligible==306 and batch.state().target_owners==3,"326 fullspacing objects,306eligible,3 realtargets")
	check(batch.candidates().is_empty() and batch.placement_receipt().is_empty(),"no startup candidates")
	var first:Dictionary=batch.step()
	check(queries==128 and first.collected_events==128 and first.status=="PENDING","source first128/4 withheld")
	check(batch.candidates().is_empty(),"first successful slice remains private")
	batch.step();check(queries==224,"source next96/2")
	complete()
	var events:Array=batch.candidates()
	check(events.size()==306 and queries==306,"complete306sourceevents only afterfullsolve")
	var chosen:Dictionary=find_event(events,"resident_72")
	check(batch.validate_candidate(chosen,"resident_72",1),"exact target candidate current")
	check(not batch.validate_candidate(chosen,"resident_72",2),"wrong life rejected")
	check(not batch.validate_candidate(chosen,"resident_169",1),"wrong rawidentity rejected")
	var unowned:Dictionary=find_event(events,"resident_1")
	check(not batch.validate_candidate(unowned,"resident_1",1),"unowned logical event cannot physicaladmit")
	for key in ["r","object_key","provider","commands","physical_admission"]:
		var altered:=chosen.duplicate(true)
		match key:
			"r":altered.r+=.000000001
			"object_key":altered.object_key="object_0"
			"provider":altered.provider.version="2"
			"commands":altered.commands.append("invented")
			"physical_admission":altered.physical_admission=true
		check(not batch.validate_candidate(altered,"resident_72",1),"exact delivered event rejects "+key)
	chosen.r=999;events.clear()
	var pristine:Dictionary=find_event(batch.candidates(),"resident_72")
	check(pristine.r!=999 and batch.validate_candidate(pristine,"resident_72",1),"publication deep copies")
	var receipt:Dictionary=batch.placement_receipt();receipt.provider.id="mutated"
	check(batch.placement_receipt().provider.id=="TEST_ONLY_batch_source_body","receipt copy")
	# Actual source search oracle: full326 spacing,765 originalJS queries.
	fresh();mode="replay"
	for slice:Dictionary in oracle.synthetic_search_and_spacing.slices:
		var result:Dictionary=batch.step()
		check(result.ok and replay_index==int(slice.query_end),"exact source slice scheduling")
		if result.status!="COMPLETE":check(batch.candidates().is_empty(),"relocations private untilcomplete")
	events=batch.candidates()
	check(events.size()==306 and replay_index==765 and batch.state().stats.moved==306,"real solver source765queries/306relocations")
	var final_rows:Dictionary={}
	for row:Dictionary in oracle.synthetic_search_and_spacing.slices[-1].state.rows:final_rows[row.object_key]=row
	for e:Dictionary in events:
		check(e.status=="relocated" and not e.physical_admission,"candidate is not a birth/physicalreceipt")
		check(absf(e.r-final_rows[e.object_key].r)<1e-10 and absf(e.c-final_rows[e.object_key].c)<1e-10,"sourcefloat64 finalposition "+e.object_key)
	# Whole batch failures suppress earlier successful private slices.
	for failure in ["unknown","reentry","dispose","revoke","death"]:
		fresh();batch.step();mode=failure
		var result:Dictionary=batch.step()
		check(result.status in ["FAULT","DISPOSED"] and batch.candidates().is_empty() and batch.placement_receipt().is_empty(),"terminal no partialadmit "+failure)
	# Exhaustion injection shortens ONLY the source search radius in this fixture;
	# batch still consumes the real solver's UNRESOLVED terminal result.
	fresh();batch.step();mode="blocked"
	for row:Dictionary in batch._solver._rows:
		if row.has("maxRadius"):row.maxRadius=0.0
	for i in 5:
		if batch.step().status=="UNRESOLVED":break
	check(batch.state().status=="UNRESOLVED" and batch.candidates().is_empty() and batch.state().collected_events==0,"real solver unresolved discards partialcollection")
	fresh();batch.step();clock_value=-1
	check(batch.step().status=="FAULT" and batch.candidates().is_empty(),"backward monotonicclockfault")
	fresh();complete();chosen=find_event(batch.candidates(),"resident_72");current=false
	check(not batch.validate_candidate(chosen,"resident_72",1) and batch.state().status=="FAULT","final lease revocation permanent")
	current=true;check(batch.candidates().is_empty(),"revocation cannot resurrect oldcapturedsolve")
	for failure in ["lease_reentry","lease_dispose","lease_badtype"]:
		fresh();mode=failure
		check(batch.step().status in ["FAULT","DISPOSED"],"aggregate callback failclosed "+failure)
	fresh();complete();mode="lease_second_false";lease_calls=0
	check(batch.candidates().is_empty() and batch.state().status=="FAULT","lease revoked afterpublicationcopy withheld")
	var ports:=Ports.new();root.add_child(ports)
	batch=Batch.new();check(batch.configure(bytes,trust(),ports.body,ports.lease,ports.clock,owners).ok,"lifetime fixture ports")
	ports.free();check(batch.step().status=="FAULT" and batch.candidates().is_empty(),"freedprovider cleanfail")
	# Real monotonic clock exercises actual scheduling; provider remains TEST_ONLY.
	fresh(true)
	var started:=Time.get_ticks_usec();complete()
	timings.append({"real_clock_full_solve_us":Time.get_ticks_usec()-started,"slices":batch.state().slices})
	check(batch.candidates().size()==306,"real monotonicclockfullsolve")
	check(Solver._hash(bytes)==Solver.CONTEXT_SHA,"input fullcontext bytes unchanged")
	check(FileAccess.get_sha256("res://scripts/npc_visual/npc_initial_placement.gd")==solver_hash,"solver unchanged")
	batch.dispose()
	var report={"pass":errors.is_empty(),"checks":checks,"errors":errors,"batch_sha256":FileAccess.get_sha256("res://scripts/npc_visual/npc_placement_batch.gd"),"solver_sha256":solver_hash,"context_sha256":Solver.CONTEXT_SHA,"timings":timings,"scope":"actual fullcontext+real source solver; TEST_ONLY BODY proof, no runtime physical or fullcity sourceprovider claim"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../../outputs/coordinator21_npc_placement_batch"))
	var file:=FileAccess.open("res://../../outputs/coordinator21_npc_placement_batch/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report));quit(0 if errors.is_empty() else 1)
