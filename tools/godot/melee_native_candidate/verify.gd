extends SceneTree
const Ref=preload("res://reference.gd")
var checks:=0
var failures:Array[String]=[]
var native:Object
var max_scalar_error:=0.0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label)
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func appendv(p:PackedFloat64Array,v:Vector3)->void:p.append_array(PackedFloat64Array([v.x,v.y,v.z]))
func decoded(p:PackedFloat64Array,o:int)->Vector3:return Vector3(p[o],p[o+1],p[o+2])
func payload(a:Vector3,b:Vector3,r:float,t:Array)->PackedFloat64Array:
	var p:=PackedFloat64Array([0]);appendv(p,a);appendv(p,b);p.append(r)
	for v:Vector3 in t:appendv(p,v)
	return p
func compare(a:Vector3,b:Vector3,r:float,t:Array,label:String)->PackedFloat64Array:
	var n:PackedFloat64Array=native.call("run",payload(a,b,r,t))
	var s:Dictionary=Ref.sample(a,b,r,t[0],t[1],t[2])
	check((n[0]==1)==s.valid,label+" valid")
	if n[0]!=1:return n
	check((n[1]==1)==s.hit,label+" hit")
	if n[1]!=1:return n
	for pair:Array in [[2,s.point],[5,s.line_point],[8,s.normal],[11,s.weights]]:
		check(decoded(n,pair[0])==pair[1],label+" exact native Vector3 "+str(pair[0]))
	for pair:Array in [[14,s.score],[15,s.distance_squared]]:
		max_scalar_error=maxf(max_scalar_error,absf(n[pair[0]]-pair[1]))
		check(n[pair[0]]==pair[1],label+" exact scalar "+str(pair[0]))
	return n
func summary(a:Array[int])->Dictionary:
	a.sort();return {"p50":a[int(a.size()*.5)],"p95":a[mini(int(a.size()*.95),a.size()-1)],"max":a[-1]}
func overlap(a:Vector3,b:Vector3,c:Vector3,from:Vector3,to:Vector3,r:float)->bool:
	var lo:=a.min(b).min(c);var hi:=a.max(b).max(c)
	for axis in 3:
		if float(hi[axis])<minf(from[axis],to[axis])-r or float(lo[axis])>maxf(from[axis],to[axis])+r:return false
	return true
func _initialize()->void:run.call_deferred()
func run()->void:
	check(GDExtensionManager.load_extension("res://candidate.gdextension")==OK,"load extension")
	native=ClassDB.instantiate("MeleeNativeGeometry")
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://oracle.json"))
	for i in oracle.rows.size():
		var row:Dictionary=oracle.rows[i];var t:Array=[]
		for v:Array in row.triangle:t.append(vec(v))
		var n:=compare(vec(row.from),vec(row.to),row.radius,t,"oracle "+str(i))
		check(n.size()==16 and (n[1]==1)==(row.expected!=null),"source oracle hit "+str(i))
		if row.expected!=null and n.size()==16 and n[1]==1:
			check(decoded(n,2).distance_to(vec(row.expected.point))<.00003,"source point "+str(i))
			check(decoded(n,8).distance_to(vec(row.expected.normal))<.00003,"source normal "+str(i))
			check(decoded(n,11).distance_to(vec(row.expected.weights))<.00005,"source anchor "+str(i))
			check(absf(sqrt(n[14])-row.expected.distance)<.00003,"source score "+str(i))
	for width:float in [.01,.001,.0003,.0001,.00001]:
		var n:=compare(Vector3(.5,width*.25,1),Vector3(.5,width*.25,-1),.1,[Vector3.ZERO,Vector3.RIGHT,Vector3(1,width,0)],"thin "+str(width))
		check(n[1]==1 and decoded(n,11).distance_to(Vector3(.5,.25,.25))<.0001,"thin source anchor")
	var parallel:=compare(Vector3(-.2,-.05,0),Vector3(1.2,-.05,0),.1,[Vector3.ZERO,Vector3.RIGHT,Vector3.UP],"parallel")
	check(decoded(parallel,2)==Vector3.ZERO and decoded(parallel,11)==Vector3(1,0,0),"strict first edge tie")
	for tri:Array in [[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO],[Vector3.ZERO,Vector3.RIGHT,Vector3.RIGHT*2]]:compare(Vector3(0,0,1),Vector3.ZERO,.1,tri,"degenerate")
	for radius:float in [NAN,INF,-1,0,.500001]:compare(Vector3.ZERO,Vector3.ONE,radius,[Vector3.ZERO,Vector3.RIGHT,Vector3.UP],"invalid radius")
	compare(Vector3(NAN,0,0),Vector3.ONE,.1,[Vector3.ZERO,Vector3.RIGHT,Vector3.UP],"nonfinite")
	state_tests()
	epsilon_tests()
	var cost:=benchmark()
	native.free()
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"oracle_rows":oracle.rows.size(),"max_double_scalar_error":max_scalar_error,"cost":cost,"dll_sha":FileAccess.get_sha256("res://melee_native.dll"),"reference_sha":FileAccess.get_sha256("res://reference.gd"),"scope":"Isolated CPU; same real hero geometry; excludes upstream skin deformation; no loaded-scene FPS/authority claim"}
	var f:=FileAccess.open("res://../report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func state_tests()->void:
	var obj:Object=ClassDB.instantiate("MeleeNativeGeometry")
	# Two identical triangles and two identical limbs: total order tri then limb.
	var mesh:=PackedFloat64Array([1,0,3,2, 0,0,0, 1,0,0, 0,1,0, 0,1,2, 0,1,2])
	check(obj.call("run",mesh)[0]==1,"configure ties")
	var query:=PackedFloat64Array([3,0,2,1, .2,.2,1,.2,.2,-1,.1, .2,.2,1,.2,.2,-1,.1])
	var page:PackedFloat64Array=obj.call("run",query);var id:=page[2]
	for i in 4:
		check(page[3]==4 and page[5]==1 and page[7]==int(i/2) and page[8]==i%2,"stable candidate pagination "+str(i))
		page=obj.call("run",PackedFloat64Array([4,0,id,1]))
	check(page[5]==0,"all later candidates retained")
	obj.call("run",PackedFloat64Array([5]))
	check(obj.call("run",PackedFloat64Array([4,0,id,1]))[0]==-1,"cancel rejects old query")
	page=obj.call("run",query);id=page[2]
	check(obj.call("run",PackedFloat64Array([2,1,3,0,0,0,1,0,0,0,1,0]))[0]==1,"refit")
	check(obj.call("run",PackedFloat64Array([4,0,id,1]))[0]==-1,"refit rejects old query")
	check(obj.call("run",query)[0]==-1,"query rejects old revision")
	check(obj.call("run",PackedFloat64Array([2,2,3,NAN,0,0,1,0,0,0,1,0]))[0]==-1,"invalid refit")
	query[1]=1
	check(obj.call("run",query)[0]==-1,"invalid refit not stale ready")
	check(obj.call("run",PackedFloat64Array([2,2,3,0,0,0,1,0,0,0,1,0]))[0]==1,"valid refit recovers")
	check(obj.call("refit_vertices",PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]),3)[0]==1,"direct vector3 refit")
	query[1]=3
	check(obj.call("run",query)[3]==4,"direct vector3 unchanged contacts")
	check(obj.call("refit_vertices",PackedVector3Array([Vector3.INF,Vector3.RIGHT,Vector3.UP]),4)[0]==-1,"direct invalid vertex")
	check(obj.call("run",query)[0]==-1,"direct failure invalidates ready")
	check(obj.call("refit_vertices",PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]),4)[0]==1,"direct recover")
	check(obj.call("refit_vertices",PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]),4)[0]==-1,"direct same revision rejected")
	check(obj.call("refit_vertices",PackedVector3Array(),5)[0]==-1,"direct short array rejected")
	var moved:=PackedVector3Array([Vector3(3,4,5),Vector3(4,4,5),Vector3(3,5,5)])
	check(obj.call("refit_vertices",moved,5)[0]==1,"direct translated pose")
	moved[0]=Vector3(999,999,999)
	query=PackedFloat64Array([3,5,1,8, 3.2,4.2,6,3.2,4.2,4,.1])
	page=obj.call("run",query)
	check(page[3]==2 and decoded(page,9).distance_to(Vector3(3.2,4.2,5))<.000001,"native owns copied vertices not borrowed pointers")
	for bad:Variant in [null,[],{},42,"payload",PackedVector3Array()]:
		check(obj.call("run",bad)==PackedFloat64Array([-1,12]),"malformed variant rejected")
	for bad:PackedFloat64Array in [PackedFloat64Array(),PackedFloat64Array([NAN]),PackedFloat64Array([INF]),PackedFloat64Array([.5]),PackedFloat64Array([3]),PackedFloat64Array([4]),PackedFloat64Array([5,1]),PackedFloat64Array([3,5,5,1]),PackedFloat64Array([3,5,1,257,0,0,0,0,0,0,.1])]:
		check(obj.call("run",bad)[0]==-1,"malformed shape/caps rejected")
	for bad:float in [-1,.5,3,INF,NAN]:
		var fresh:Object=ClassDB.instantiate("MeleeNativeGeometry");var invalid:=mesh.duplicate();invalid[13]=bad
		check(fresh.call("run",invalid)[0]==-1,"invalid index before native pointer read")
		fresh.free()
	obj.free()
	for cycle in 100:
		obj=ClassDB.instantiate("MeleeNativeGeometry")
		check(obj.call("run",mesh)[0]==1,"lifetime configure "+str(cycle))
		obj.call("run",PackedFloat64Array([3,0,1,1,.2,.2,1,.2,.2,-1,.1]))
		obj.free()
	obj=ClassDB.instantiate("MeleeNativeGeometry")
	var thread:=Thread.new()
	thread.start(func():return obj.call("run",mesh))
	check(thread.wait_to_finish()==PackedFloat64Array([-1,1]),"worker thread cannot mutate cache")
	check(obj.call("run",mesh)[0]==1,"main thread cache remains usable")
	obj.free()
	var good:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	var malformed:Array=[[[],1],[{},1],[null,1],[42,1],[PackedFloat64Array(),1],[good,1.0],[good,"1"],[good,null],[good,true],[],[good],[good,1,2]]
	for args:Array in malformed:
		obj=ClassDB.instantiate("MeleeNativeGeometry")
		obj.call("run",mesh)
		var q:=PackedFloat64Array([3,0,1,1,.2,.2,1,.2,.2,-1,.1])
		var pending:PackedFloat64Array=obj.call("run",q)
		check(obj.callv("refit_vertices",args)==PackedFloat64Array([-1,12]),"malformed direct refit returns explicit error")
		check(obj.call("run",PackedFloat64Array([4,0,pending[2],1]))[0]==-1,"malformed refit clears old pages")
		check(obj.call("run",q)[0]==-1,"malformed refit invalidates old geometry")
		check(obj.call("refit_vertices",good,1)[0]==1,"valid refit after malformed recovers")
		obj.free()
	obj=ClassDB.instantiate("MeleeNativeGeometry");obj.call("run",mesh)
	thread=Thread.new();thread.start(func():return obj.call("refit_vertices",null,null))
	check(thread.wait_to_finish()==PackedFloat64Array([-1,1]),"wrong-thread malformed refit is fenced first")
	check(obj.call("run",PackedFloat64Array([3,0,1,1,.2,.2,1,.2,.2,-1,.1]))[0]==1,"foreign thread cannot invalidate owner's ready pose")
	obj.free()
func epsilon_tests()->void:
	for axis in 3:
		for shift:Vector3 in [Vector3.ZERO,Vector3(2,-3,4)]:
			for gap:float in [2e-10,4e-10,1e-6]:
				var triangle:Array=[Vector3.ZERO,Vector3.RIGHT,Vector3.UP]
				var from:=Vector3(.2,.2,.1);var to:=Vector3(.3,.2,.1)
				for i in 3:
					var p:Vector3=triangle[i]
					triangle[i]=(Vector3(p.y,p.z,p.x) if axis==1 else Vector3(p.z,p.x,p.y) if axis==2 else p)+shift
				from=(Vector3(from.y,from.z,from.x) if axis==1 else Vector3(from.z,from.x,from.y) if axis==2 else from)+shift
				to=(Vector3(to.y,to.z,to.x) if axis==1 else Vector3(to.z,to.x,to.y) if axis==2 else to)+shift
				var normal_axis:=2 if axis==0 else 1 if axis==1 else 0
				var radius:=float(from[normal_axis])-float(shift[normal_axis])-gap
				var expected:Dictionary=Ref.sample(from,to,radius,triangle[0],triangle[1],triangle[2])
				var obj:Object=ClassDB.instantiate("MeleeNativeGeometry")
				var mesh:=PackedFloat64Array([1,0,3,1])
				for p:Vector3 in triangle:appendv(mesh,p)
				mesh.append_array(PackedFloat64Array([0,1,2]));obj.call("run",mesh)
				var query:=PackedFloat64Array([3,0,1,4]);appendv(query,from);appendv(query,to);query.append(radius)
				var answer:PackedFloat64Array=obj.call("run",query)
				check((answer[3]==1)==expected.hit,"epsilon broadphase matches exact kernel across transformed plane")
				if expected.hit:
					check(answer[21]==expected.score,"epsilon exact score")
					check(decoded(answer,9)==expected.point,"epsilon exact point")
				obj.free()
func benchmark()->Dictionary:
	var f:=FileAccess.open("res://hero.bin",FileAccess.READ);var hero:Dictionary=f.get_var();f.close()
	var vertices:PackedVector3Array=hero.vertices;var indices:PackedInt32Array=hero.indices
	check(vertices.size()==8338 and indices.size()==13034*3,"actual hero full geometry")
	var obj:Object=ClassDB.instantiate("MeleeNativeGeometry")
	var mesh:=PackedFloat64Array([1,0,vertices.size(),indices.size()/3])
	for p in vertices:appendv(mesh,p)
	for i in indices:mesh.append(i)
	var begin:=Time.get_ticks_usec();var built:PackedFloat64Array=obj.call("run",mesh);var build_us:=Time.get_ticks_usec()-begin
	check(built[0]==1,"actual hero topology")
	var packs:Array[int]=[];var refits:Array[int]=[];var refit:=PackedFloat64Array()
	for iteration in 80:
		begin=Time.get_ticks_usec();refit=PackedFloat64Array([2,iteration+1,vertices.size()])
		for p in vertices:appendv(refit,p)
		if iteration>=16:packs.append(Time.get_ticks_usec()-begin)
		begin=Time.get_ticks_usec();var r:PackedFloat64Array=obj.call("run",refit)
		if iteration>=16:refits.append(Time.get_ticks_usec()-begin)
		check(r[0]==1,"actual refit")
	var direct:Array[int]=[]
	for iteration in 80:
		begin=Time.get_ticks_usec();var r:PackedFloat64Array=obj.call("refit_vertices",vertices,81+iteration)
		if iteration>=16:direct.append(Time.get_ticks_usec()-begin)
		check(r[0]==1,"actual direct refit")
	var cases:Array=[]
	for name:String in hero.targets:
		for radius:float in [.10,.14]:
			var from:Vector3=hero.targets[name]+Vector3(0,0,.5);var to:Vector3=hero.targets[name]-Vector3(0,0,.1)
			var q:=PackedFloat64Array([3,160,1,256]);appendv(q,from);appendv(q,to);q.append(radius)
			var expected:Array=[]
			begin=Time.get_ticks_usec()
			for t in int(indices.size()/3):
				var a:=vertices[indices[t*3]];var b:=vertices[indices[t*3+1]];var c:=vertices[indices[t*3+2]]
				if not overlap(a,b,c,from,to,radius):continue
				var hit:Dictionary=Ref.sample(from,to,radius,a,b,c)
				if hit.hit:expected.append({"triangle":t,"hit":hit})
			var scan_us:=Time.get_ticks_usec()-begin
			expected.sort_custom(func(a,b):return a.hit.score<b.hit.score if a.hit.score!=b.hit.score else a.triangle<b.triangle)
			var query_times:Array[int]=[];var all_pages:Array[int]=[]
			for iteration in 80:
				begin=Time.get_ticks_usec();var answer:PackedFloat64Array=obj.call("run",q)
				if iteration>=16:query_times.append(Time.get_ticks_usec()-begin)
				var count:=0
				while true:
					if iteration==0:
						check(answer[3]==expected.size(),"all native hits "+name+str(radius))
						for j in int(answer[5]):
							var at:=7+j*16;var e:Dictionary=expected[count+j]
							check(answer[at]==e.triangle,"candidate stable triangle")
							check(answer[at+14]==e.hit.score,"candidate exact score")
							check(decoded(answer,at+2)==e.hit.point and decoded(answer,at+11)==e.hit.weights,"candidate exact surface/anchor")
					count+=int(answer[5])
					if count>=int(answer[3]):break
					answer=obj.call("run",PackedFloat64Array([4,160,answer[2],256]))
				if iteration>=16:all_pages.append(Time.get_ticks_usec()-begin)
			cases.append({"bone":name,"radius":radius,"hits":expected.size(),"gdscript_linear_scan_us_single":scan_us,"native_query_boundary_first256_us":summary(query_times),"native_all_pages_us":summary(all_pages)})
	obj.free()
	return {"vertices":vertices.size(),"triangles":indices.size()/3,"build_us":build_us,"pack_vertices_gdscript_us":summary(packs),"native_refit_boundary_us":summary(refits),"native_direct_vector3_refit_boundary_us":summary(direct),"cases":cases,"skin_capture_us_single":hero.skin_us,"player_sha":hero.player_sha}
