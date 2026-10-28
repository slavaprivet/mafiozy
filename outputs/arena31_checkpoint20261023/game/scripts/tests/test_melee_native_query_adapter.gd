extends SceneTree
## Run in an isolated project containing the accepted combined DLL and real assets.
const Adapter=preload("res://scripts/combat/melee_native_query_adapter.gd")
const Provider=preload("res://scripts/combat/melee_skin_provider.gd")
const Selector=preload("res://scripts/combat/melee_contact_selection.gd")
const Kernel=preload("res://scripts/combat/melee_triangle_contact.gd")
const Cache=preload("res://scripts/npc_visual/npc_visual_cache.gd")
var checks:=0
var failures:Array[String]=[]
var skin:Object
var measurements:Array=[]
var actor_evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<50:failures.append(label)
func publish(actor:Node,revision:int)->void:
	actor.set_meta("melee_skin_pose",{"actor_id":actor.get_meta("actor_id"),"life_generation":actor.get_meta("life_generation"),"pose_revision":revision,"pose_epoch":1,"pose_owner":"TEST_ONLY_displayed_pose"})
func identity(actor:Node,id:String)->void:
	actor.set_meta("actor_id",id);actor.set_meta("life_generation",1);publish(actor,1)
func request(actor:Dictionary,point:Vector3)->Dictionary:
	return {"key":"TEST_ONLY_query","receipt":actor.receipt.duplicate(true),"contacts":[{"from":point+Vector3(0,0,.4),"to":point-Vector3(0,0,.4),"radius":.14}]}
func clear_obstacles(port:Dictionary)->Dictionary:
	return {"valid":true,"token":"TEST_ONLY_no_obstacles","blocker_count":0} if port.phase=="begin" else {"valid":true,"distance":null}
func summary(values:Array)->Dictionary:
	values.sort()
	return {"samples":values.size(),"p50":values[values.size()/2],"p95":values[int(values.size()*.95)],"max":values[-1]}
func scalar_compare(actor:Dictionary,query:Dictionary,result:Dictionary,label:String)->void:
	var expected:Array=[]
	for part:Dictionary in actor.parts:
		for face in part.indices.size()/3:
			for limb in query.contacts.size():
				var s:Dictionary=query.contacts[limb]
				var hit:Dictionary=Kernel.sample(s.from,s.to,s.radius,part.world_vertices[part.indices[face*3]],part.world_vertices[part.indices[face*3+1]],part.world_vertices[part.indices[face*3+2]])
				check(hit.get("valid",false),label+": independent scalar valid")
				if hit.get("hit",false):expected.append({"triangle":part.triangle_first+face,"limb":limb,"hit":hit})
	expected.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		if a.hit.score!=b.hit.score:return a.hit.score<b.hit.score
		return a.triangle<b.triangle if a.triangle!=b.triangle else a.limb<b.limb)
	check(result.get("complete",false),label+": complete native result")
	if not result.get("complete",false):return
	var rows:PackedFloat64Array=result.rows
	check(rows.size()==expected.size()*16,label+": every candidate retained")
	if rows.size()!=expected.size()*16:return
	for index in expected.size():
		var at:=index*16;var ref:Dictionary=expected[index]
		check(rows[at]==ref.triangle and rows[at+1]==ref.limb,label+": exact global order")
		check(rows[at+14]==ref.hit.score and rows[at+15]==ref.hit.distance_squared,label+": exact scalar ranking")
		for field:Array in [[2,"point"],[5,"line_point"],[8,"normal"],[11,"weights"]]:
			var base:int=at+field[0]
			check(Vector3(rows[base],rows[base+1],rows[base+2])==ref.hit[field[1]],label+": exact native vector "+field[1])
class FakeProvider extends "res://scripts/combat/melee_skin_provider.gd":
	var revision:=1
	var generation:=1
	var valid:=true
	var action:Callable
	var current_action:Callable
	var capture_calls:=0
	var out_of_bounds:=false
	func _init()->void:_actor=weakref(self)
	func receipt()->Dictionary:return {"actor_id":"TEST_ONLY_synthetic","life_generation":generation,"pose_revision":revision,"pose_epoch":1,"pose_owner":"TEST_ONLY"}
	func current(value:Dictionary)->bool:
		if current_action.is_valid():current_action.call()
		return valid and value==receipt()
	func capture(wanted:int)->Dictionary:
		capture_calls+=1
		if action.is_valid():action.call()
		if not valid or wanted!=revision:return {"ok":false}
		var vertices:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
		if out_of_bounds:vertices[0]=Vector3(10000001,0,0)
		var indices:=PackedInt32Array()
		for face in 600:indices.append_array(PackedInt32Array([0,1,2]))
		var weights:=PackedFloat32Array([1,0,0,0,1,0,0,0,1,0,0,0])
		return {"ok":true,"vertices":vertices,"indices":indices,"identity":{"actor_id":"TEST_ONLY_synthetic","life_generation":generation},"owner_receipt":receipt(),"pose_revision":revision,"actor_root_world":Transform3D.IDENTITY,"parts":[{"mesh_id":"triangle","mesh_order":0,"visible":true,"world_vertices":vertices,"indices":indices,"head_slot_weights":weights,"triangle_first":0,"vertex_first":0}]}
func negative_tests()->void:
	var provider:=FakeProvider.new();var adapter:=Adapter.new()
	check(adapter.configure(provider).ok,"synthetic binding")
	check(adapter.update(1).ok,"synthetic initial configure")
	var actor:=adapter.actor();var ticket:=request(actor,Vector3(.2,.2,0))
	ticket.contacts.append(ticket.contacts[0].duplicate(true))
	var full:=adapter.query(actor,ticket)
	check(full.get("complete",false) and full.get("pages")==5 and full.get("rows",[]).size()==1200*16,"all five pages including ties")
	scalar_compare(actor,ticket,full,"synthetic pages")
	var retained:PackedFloat64Array=full.rows.duplicate()
	full.rows[0]=9999
	check(adapter.query(actor,ticket).rows==retained,"returned row mutation cannot poison native data")
	actor.parts[0].indices[0]=2
	check(adapter.actor().parts[0].indices[0]==0,"snapshot mutation does not alter cache")
	actor=adapter.actor()
	provider.revision=2;provider.out_of_bounds=true
	check(not adapter.update(2).ok,"actual native failed refit rejects out-of-world skin")
	check(adapter.actor().is_empty() and not adapter.query(actor,ticket).get("valid",false),"failed refit never exposes earlier geometry")
	provider.out_of_bounds=false
	check(adapter.update(2).ok,"fresh context recovers same life after failed refit")
	actor=adapter.actor();ticket=request(actor,Vector3(.2,.2,0))
	provider.valid=false
	check(not adapter.update(3).ok and adapter.actor().is_empty(),"failed capture retires native cache")
	check(not adapter.query(actor,ticket).get("valid",false),"failed capture cannot query previous pose")
	provider.valid=true;provider.revision=3
	check(adapter.update(3).ok,"recover actual provider")
	actor=adapter.actor();ticket=request(actor,Vector3(.2,.2,0))
	provider.generation=2;provider.revision=4
	check(not adapter.update(4).ok and adapter.actor().is_empty(),"different life requires new adapter")
	adapter.dispose()
	check(not adapter.configure(provider).ok,"retired adapter cannot rebind")
	adapter=Adapter.new();check(adapter.configure(provider).ok and adapter.update(4).ok,"explicit new life adapter")
	actor=adapter.actor();ticket=request(actor,Vector3(.2,.2,0))
	ticket.receipt.pose_revision=3
	check(not adapter.query(actor,ticket).get("valid",false),"request receipt must match exact captured revision")
	check(adapter.update(4).ok,"recover after invalid request")
	var count:=[0]
	provider.current_action=func():
		count[0]+=1
		if count[0]==2:provider.valid=false
	actor=adapter.actor();count[0]=0;ticket=request(actor,Vector3(.2,.2,0))
	check(not adapter.query(actor,ticket).get("valid",false),"owner retired at query completion discards all pages")
	provider.current_action=Callable();provider.valid=true
	check(adapter.update(4).ok,"recover after post-query owner retirement")
	provider.revision=5;provider.action=func():adapter.update(5)
	check(not adapter.update(5).ok and adapter.actor().is_empty(),"capture reentry cannot return ready geometry")
	provider.action=Callable()
	check(adapter.update(5).ok,"reentry recovery fresh capture")
	provider.revision=6;provider.action=func():adapter.dispose()
	check(not adapter.update(6).ok,"dispose inside provider capture")
	provider.action=Callable();adapter.dispose()
	adapter=Adapter.new();check(adapter.configure(provider).ok and adapter.update(6).ok,"new isolated provider binding")
	provider._actor=weakref(provider)
	check(not adapter.update(6).ok and adapter.actor().is_empty(),"provider reconfiguration cannot reuse identical source ID/life")
	adapter.dispose();adapter=Adapter.new();check(adapter.configure(provider).ok and adapter.update(6).ok,"new adapter for changed provider binding")
	var thread:=Thread.new()
	check(thread.start(func():return adapter.update(6))==OK,"worker started")
	var worker:Variant=thread.wait_to_finish()
	check(worker is Dictionary and not worker.get("ok",false) and adapter.update(6).get("cached",false),"worker rejection preserves main-thread cache")
	actor=adapter.actor();ticket=request(actor,Vector3(.2,.2,0));ticket.contacts[0].radius=NAN
	check(not adapter.query(actor,ticket).get("valid",false) and adapter.actor().is_empty(),"native query failure discards cached geometry")
	check(adapter.update(6).ok,"fresh context after failed native query")
	provider=null
	check(adapter.actor().is_empty(),"freed provider rejected by weak lifetime")
	adapter.dispose()
	provider=FakeProvider.new();adapter=Adapter.new()
	check(adapter.configure(provider).ok and adapter.update(1).ok,"automatic lifetime cleanup setup")
	var native_id:int=adapter._native.get_instance_id()
	adapter=null
	check(not is_instance_id_valid(native_id),"last adapter reference frees native Object without explicit dispose")
	for interruption in ["dispose","reentry","rebind"]:
		provider=FakeProvider.new();adapter=Adapter.new()
		check(adapter.configure(provider).ok and adapter.update(1).ok,"cached current interruption setup "+interruption)
		var calls:int=provider.capture_calls
		match interruption:
			"dispose":provider.current_action=func():adapter.dispose()
			"reentry":provider.current_action=func():adapter.update(1)
			"rebind":provider.current_action=func():provider._actor=weakref(provider)
		check(not adapter.update(1).ok,"cached current callback interruption rejects "+interruption)
		check(provider.capture_calls==calls,"no capture after cached current interruption "+interruption)
		provider.current_action=Callable();adapter.dispose()
func run_actor(actor:Node3D,visual:Node3D,rig:Skeleton3D,label:String)->void:
	var provider:=Provider.new()
	check(provider.configure(actor,visual,rig,skin,{"actor_id":actor.get_meta("actor_id"),"life_generation":1}).ok,label+": actual provider binding")
	var adapter:=Adapter.new();check(adapter.configure(provider).ok,label+": adapter binding")
	var start:=Time.get_ticks_usec();var initial:=adapter.update(1);var setup_us:=Time.get_ticks_usec()-start
	check(initial.ok,label+": capture and actual native configure")
	if not initial.ok:adapter.dispose();provider.dispose();return
	var view:=adapter.actor()
	var head:=rig.find_bone("head")
	check(head>=0,label+": actual head bone")
	var point:Vector3=(rig.global_transform*rig.get_bone_global_pose(head)).origin
	var ticket:=request(view,point)
	var result:=adapter.query(view,ticket)
	scalar_compare(view,ticket,result,label)
	check(result.get("rows",[]).size()>0,label+": actual head has contacts")
	var selector:=Selector.new();check(selector.configure(adapter.current,adapter.query,clear_obstacles),label+": selector adapter contract")
	var selected:=selector.select({"previous":ticket.contacts[0].from,"current":ticket.contacts[0].to,"radius":.14,"attackType":"punch"},[view])
	check(selected.get("valid",false) and selected.get("hit",false),label+": end-to-end current skin contact")
	var updates:Array=[];var queries:Array=[];var cached:Array=[]
	for revision in range(2,66):
		# Real current frames vary under an explicit TEST_ONLY displayed receipt.
		rig.set_bone_pose_rotation(head,Quaternion(Vector3.UP,sin(float(revision)*.13)*.03))
		publish(actor,revision)
		start=Time.get_ticks_usec();var updated:=adapter.update(revision);var update_us:=Time.get_ticks_usec()-start
		check(updated.ok,label+": moving pose refit")
		view=adapter.actor();ticket=request(view,point)
		start=Time.get_ticks_usec();result=adapter.query(view,ticket);var query_us:=Time.get_ticks_usec()-start
		check(result.get("complete",false),label+": moving current query complete")
		start=Time.get_ticks_usec();var cache_hit:=adapter.update(revision);var cache_us:=Time.get_ticks_usec()-start
		check(cache_hit.get("ok",false) and cache_hit.get("cached",false),label+": same exact current pose cached")
		if revision>=18:updates.append(update_us);queries.append(query_us);cached.append(cache_us)
	measurements.append({"actor":label,"setup_us":setup_us,"update_capture_refit_us":summary(updates),"query_all_pages_us":summary(queries),"cached_pose_check_us":summary(cached)})
	actor_evidence.append({"actor":label,"vertices":initial.vertices,"triangles":initial.triangles,"rows":result.rows.size()/16,"pages":result.pages})
	var old_view:=view;var old_ticket:=ticket
	actor.position.x+=.01
	check(not adapter.current(old_view) and adapter.actor().is_empty(),label+": unpublished root move retires cache")
	check(not adapter.query(old_view,old_ticket).get("valid",false),label+": unpublished move cannot query stale triangles")
	publish(actor,66);check(adapter.update(66).ok,label+": published moved root recovers")
	var mesh:MeshInstance3D=visual.find_children("*","MeshInstance3D",true,false)[0]
	mesh.mesh=mesh.mesh.duplicate(true)
	check(not adapter.update(67).ok and adapter.actor().is_empty(),label+": replaced actual mesh retires context")
	adapter.dispose();provider.dispose()
	publish(actor,67)
	check(provider.configure(actor,visual,rig,skin,{"actor_id":actor.get_meta("actor_id"),"life_generation":1}).ok,label+": explicit actual replacement binding")
	adapter=Adapter.new();check(adapter.configure(provider).ok and adapter.update(67).ok,label+": new adapter after actual replacement")
	rig.queue_free()
	check(adapter.actor().is_empty(),label+": queued actual skeleton retires before deletion")
	adapter.dispose();provider.dispose()
func run()->void:
	check(FileAccess.get_sha256("res://melee_kernels.dll")=="a5695c0b117e42a4847d10cdef0f7b71485f6243a7f412b6d6cb0eb5924c2add","frozen combined DLL")
	if not ClassDB.class_exists("MeleeNativeGeometry"):check(GDExtensionManager.load_extension("res://melee_kernels.gdextension")==OK,"isolated explicit extension load")
	if not ClassDB.class_exists("MeleeNativeGeometry"):quit(2);return
	skin=ClassDB.instantiate("MeleeNativeSkin")
	negative_tests()
	var scene:PackedScene=load("res://assets/hero.glb")
	var actor:=Node3D.new();root.add_child(actor);identity(actor,"TEST_ONLY_actual_hero")
	var visual:Node3D=scene.instantiate();actor.add_child(visual)
	var skeletons:=visual.find_children("*","Skeleton3D",true,false)
	check(skeletons.size()==1,"actual hero skeleton")
	if skeletons.size()==1:run_actor(actor,visual,skeletons[0],"hero")
	actor.free()
	var directory:="res://assets/npc_visual/session/prepared"
	var bytes:=FileAccess.get_file_as_bytes(directory+"/manifest.json")
	var manifest:Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
	for entry:Dictionary in manifest.entries:
		var prepared:=Cache.load_verified(bytes,FileAccess.get_sha256(directory+"/manifest.json"),entry.entry.bridge_id,entry.entry.descriptor_sha256,directory)
		check(prepared.ok,"actual prepared NPC "+str(entry.entry.bridge_id))
		if not prepared.ok:continue
		actor=Node3D.new();root.add_child(actor);identity(actor,str(entry.entry.descriptor.id))
		var built:Dictionary=prepared.cache.instantiate_actor();check(built.ok,"prepared NPC instantiate")
		if built.ok:actor.add_child(built.visual);run_actor(actor,built.visual,built.skeleton,str(entry.entry.bridge_id))
		actor.free()
	skin.free()
	check(GDExtensionManager.unload_extension("res://melee_kernels.gdextension")==OK,"all private native objects freed before unload")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"actors":actor_evidence,"measurements":measurements,"adapter_sha":FileAccess.get_sha256("res://scripts/combat/melee_native_query_adapter.gd"),"scope":"Isolated actual hero/prepared rig CPU; TEST_ONLY receipts/zero obstacles; no main/GPU/HP/source target authority"}
	FileAccess.open("res://../report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MELEE_NATIVE_QUERY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
