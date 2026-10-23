extends SceneTree
const Index = preload("res://scripts/combat/melee_triangle_index.gd")
const Kernel = preload("res://scripts/combat/melee_triangle_contact.gd")
var checks := 0
var failures: Array[String] = []
var oracle_worst := 0.0
class Filter extends Node:
	var reject_triangle := -1
	var index: RefCounted
	var reenter := false
	func accept(candidate: Dictionary) -> bool:
		if reenter: index.cancel_query(1)
		var accepted: bool = candidate.triangle_index != reject_triangle
		candidate.candidate.point = Vector3(999,999,999)
		return accepted
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size()<40: failures.append(label)
func v(values: Array) -> Vector3: return Vector3(values[0],values[1],values[2])
func finish_query(index: RefCounted, contacts: Array, revision: int, chunk: int=1000000, filter: Callable=Callable()) -> Dictionary:
	var start: Dictionary = index.begin_query(contacts,revision,filter)
	check(start.status=="PENDING","query starts pending")
	if start.status!="PENDING": return start
	var last_calls := 0; var last_nodes := 0
	for i in 100000:
		var result: Dictionary = index.advance_query(start.query_id,chunk,mini(chunk,Index.MAX_TRIANGLES*4),1000000)
		if result.has("stats"):
			check(result.stats.kernel_calls-last_calls<=chunk and result.stats.nodes-last_nodes<=chunk,"hard work caps respected")
			last_calls=result.stats.kernel_calls;last_nodes=result.stats.nodes
		if result.status!="PENDING": return result
	check(false,"finite query completes"); return {"status":"ERROR","hit":false}
func linear(vertices: PackedVector3Array, indices: PackedInt32Array, contacts: Array, reject: int=-1) -> Dictionary:
	var best := INF; var result := {"hit":false,"triangle_index":-1,"contact_index":-1,"candidate":{}}
	for tri in indices.size()/3:
		var a:=vertices[indices[tri*3]]; var b:=vertices[indices[tri*3+1]]; var c:=vertices[indices[tri*3+2]]
		var lo:=a.min(b).min(c);var hi:=a.max(b).max(c)
		for limb in contacts.size():
			var row:Dictionary=contacts[limb];var overlap:=true
			for axis in 3:
				if hi[axis]<minf(row.from[axis],row.to[axis])-row.radius or lo[axis]>maxf(row.from[axis],row.to[axis])+row.radius:overlap=false
			if not overlap:continue
			var hit:Dictionary=Kernel.sample(row.from,row.to,row.radius,a,b,c)
			if not hit.valid:return {"status":"ERROR","hit":false}
			if hit.hit and hit.score<best and tri!=reject:
				best=hit.score;result={"hit":true,"triangle_index":tri,"contact_index":limb,"candidate":hit}
	return result
func compare(actual: Dictionary, expected: Dictionary, label: String) -> void:
	check(actual.get("status")=="COMPLETE",label+" complete")
	check(actual.get("hit",false)==expected.hit,label+" hit/miss")
	if expected.hit and actual.get("hit",false):
		check(actual.triangle_index==expected.triangle_index and actual.contact_index==expected.contact_index,label+" source tie/winner ordering")
		check(actual.candidate==expected.candidate,label+" exact unchanged kernel result")
func oracle() -> void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/melee_triangle_oracle.json"))
	for i in fixture.rows.size():
		var row:Dictionary=fixture.rows[i];var index:=Index.new()
		check(index.configure(PackedInt32Array([0,1,2]),PackedVector3Array([v(row.triangle[0]),v(row.triangle[1]),v(row.triangle[2])]),1).status=="READY","oracle configure")
		var result:=finish_query(index,[{"from":v(row.from),"to":v(row.to),"radius":row.radius}],1)
		check(result.status=="COMPLETE" and result.hit==(row.expected!=null),"original fullsource oracle hit "+str(i))
		if row.expected!=null and result.get("hit",false):
			var distance:float=result.candidate.point.distance_to(v(row.expected.point));oracle_worst=maxf(oracle_worst,distance)
			check(distance<.00003,"original source surface "+str(i))
			check(result.candidate.normal.distance_to(v(row.expected.normal))<.00003,"original source normal "+str(i))
			check(result.candidate.weights.distance_to(v(row.expected.weights))<.00005,"original source weights "+str(i))
		index.dispose()
func ordering_and_refit() -> void:
	var vertices:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3(0,0,-.05),Vector3(1,0,-.05),Vector3(0,1,-.05)])
	var indices:=PackedInt32Array([0,1,2,0,1,2,3,4,5])
	var contacts:Array=[{"from":Vector3(.2,.3,1),"to":Vector3(.2,.3,-1),"radius":.1},{"from":Vector3(.2,.3,1),"to":Vector3(.2,.3,-1),"radius":.14}]
	var index:=Index.new();check(index.configure(indices,vertices,1).status=="READY","tie configure")
	compare(finish_query(index,contacts,1,1),linear(vertices,indices,contacts),"source triangle then limb tie")
	var filter:=Filter.new();filter.reject_triangle=0
	compare(finish_query(index,contacts,1,1,Callable(filter,"accept")),linear(vertices,indices,contacts,0),"rejected geometric winner does not hide next candidate")
	filter.free()
	var pending:Dictionary=index.begin_query(contacts,1)
	for i in vertices.size():vertices[i]+=Vector3(10,0,0)
	check(index.refit(vertices,2).status=="READY","current pose refit")
	check(index.advance_query(pending.query_id).status=="ERROR","refit invalidates pending work")
	compare(finish_query(index,contacts,2),linear(vertices,indices,contacts),"refit misses old skin")
	vertices[0]=Vector3.ZERO
	check(not finish_query(index,contacts,2).hit,"private current vertices cannot be mutated by caller")
	check(index.refit(vertices,2).status=="ERROR","same/old revision rejected")
	check(index.begin_query(contacts,2).status=="ERROR","failed refit cannot expose stale skin")
	check(index.refit(vertices,3).status=="READY","corrected new pose restores readiness")
	index.dispose()
func random_and_edges() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=991773
	for batch in 32:
		var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
		for triangle in 64:
			var origin:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-.5,.5))
			vertices.append(origin);vertices.append(origin+Vector3(rng.randf_range(.01,.8),0,0));vertices.append(origin+Vector3(0,rng.randf_range(.00001,.8),0))
			indices.append_array(PackedInt32Array([triangle*3,triangle*3+1,triangle*3+2]))
		var contacts:Array=[]
		for limb in 4:contacts.append({"from":Vector3(rng.randf_range(-.5,.5),rng.randf_range(-.5,.5),1),"to":Vector3(rng.randf_range(-.5,.5),rng.randf_range(-.5,.5),-1),"radius":rng.randf_range(.01,.3)})
		var index:=Index.new();check(index.configure(indices,vertices,batch).status=="READY","random hierarchy")
		compare(finish_query(index,contacts,batch,3),linear(vertices,indices,contacts),"random batch "+str(batch));index.dispose()
	for width:float in [.01,.0003,.0001,.00001]:
		var vertices:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3(1,width,0)])
		var contacts:Array=[{"from":Vector3(.5,width*.25,1),"to":Vector3(.5,width*.25,-1),"radius":.1}]
		var index:=Index.new();index.configure(PackedInt32Array([0,1,2]),vertices,1)
		var result:=finish_query(index,contacts,1,1)
		check(result.hit and result.candidate.weights.distance_to(Vector3(.5,.25,.25))<.0001,"legitimate skinny triangle retained");index.dispose()
	var index:=Index.new();var vertices:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	index.configure(PackedInt32Array([0,1,2]),vertices,1)
	for segment:Array in [[Vector3(-.2,-.05,0),Vector3(1.2,-.05,0)],[Vector3(.2,.3,.1),Vector3(.2,.3,.1)],[Vector3(.2,.3,.000001),Vector3(.2,.3,.0000009)]]:
		var contacts:Array=[{"from":segment[0],"to":segment[1],"radius":.1}]
		compare(finish_query(index,contacts,1),linear(vertices,PackedInt32Array([0,1,2]),contacts),"parallel/stationary/short-ray epsilon")
	var filter:=Filter.new();filter.index=index;filter.reenter=true
	check(finish_query(index,[{"from":Vector3(.2,.3,1),"to":Vector3(.2,.3,-1),"radius":.1}],1,1,Callable(filter,"accept")).status=="ERROR","filter reentry rejects without exposing stale candidate")
	filter.index=null;filter.free();index.dispose()
func pending_and_negatives() -> void:
	var vertices:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3(0,0,-.1),Vector3(1,0,-.1),Vector3(0,1,-.1)])
	var ids:=PackedInt32Array([0,1,2,3,4,5]);var index:=Index.new()
	check(index.configure(PackedInt32Array([0,1,9]),vertices,0).status=="ERROR","malformed index rejected")
	check(index.configure(ids,vertices,0).status=="READY","corrected topology accepted")
	var contacts:Array=[{"from":Vector3(.2,.3,1),"to":Vector3(.2,.3,-1),"radius":.1}]
	var old:Dictionary=index.begin_query(contacts,0)
	var begun:Dictionary=index.begin_refit(vertices,1)
	check(begun.status=="PENDING","refit cannot publish unchecked vertices")
	check(index.begin_query(contacts,1).status=="ERROR","partially refitted geometry cannot be queried")
	check(index.advance_query(old.query_id).status=="ERROR","starting refit cancels previous query immediately")
	var validated:=0;var remaining:int=index._left.size()
	for attempt in 20:
		var result:Dictionary=index.advance_refit(begun.refit_id,1,1,1000000)
		if result.status=="READY":break
		check(result.status=="PENDING","bounded refit explicitly pending")
		check(result.validated_vertices-validated<=1 and remaining-result.remaining_nodes<=1,"refit enforces vertex/node work caps")
		validated=result.validated_vertices;remaining=result.remaining_nodes
	compare(finish_query(index,contacts,1),linear(vertices,ids,contacts),"bounded refit commits full geometry")
	var first:Dictionary=index.begin_refit(vertices,2);var second:Dictionary=index.begin_refit(vertices,3)
	check(index.advance_refit(first.refit_id).status=="ERROR","new refit supersedes pending revision")
	check(index.cancel_refit(second.refit_id).status=="CANCELLED","explicit refit cancellation")
	check(index.begin_query(contacts,1).status=="ERROR","cancel never resurrects old skin")
	vertices[0]=Vector3(NAN,0,0)
	check(index.refit(vertices,4).status=="ERROR","nonfinite current pose rejected")
	check(index.begin_query(contacts,4).status=="ERROR","nonfinite refit remains unavailable")
	vertices[0]=Vector3.ZERO;check(index.refit(vertices,5).status=="READY","fresh valid revision recovers")
	var started:Dictionary=index.begin_query(contacts,5)
	check(index.advance_query(started.query_id,0).status=="ERROR","zero work budget rejected explicitly")
	check(index.cancel_query(started.query_id).status=="CANCELLED","query cancelled")
	check(index.cancel_query(-1).status=="ERROR","unissued query token is never a valid cancellation")
	check(index.advance_query(started.query_id).status=="ERROR","cancelled query cannot complete")
	var owner:=Filter.new();var port:=Callable(owner,"accept")
	started=index.begin_query(contacts,5,port);owner.free()
	check(index.advance_query(started.query_id).status=="ERROR","freed filter cannot return an unfiltered hit")
	owner=Filter.new();port=Callable(owner,"accept");owner.queue_free()
	check(index.begin_query(contacts,5,port).status=="ERROR","queued filter rejected before dispatch")
	owner.free()
	index.dispose();check(index.refit(vertices,6).status=="ERROR","disposed lifetime terminal")
func _initialize() -> void:
	var kernel_hash:=FileAccess.get_sha256("res://scripts/combat/melee_triangle_contact.gd")
	oracle();ordering_and_refit();random_and_edges();pending_and_negatives()
	check(kernel_hash==FileAccess.get_sha256("res://scripts/combat/melee_triangle_contact.gd"),"stable kernel bytes")
	var report:={"checks":checks,"passed":failures.is_empty(),"failures":failures,"kernel_sha256":kernel_hash,"index_sha256":FileAccess.get_sha256("res://scripts/combat/melee_triangle_index.gd"),"max_original_source_point_error_m":oracle_worst}
	DirAccess.make_dir_recursive_absolute("../../outputs/melee_triangle_index")
	var file:=FileAccess.open("../../outputs/melee_triangle_index/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MELEE_TRIANGLE_INDEX ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
