extends SceneTree
var checks:=0
var failures:Array[String]=[]
var fixture:Dictionary
var native:Object
var rigid:Dictionary={}
var mixed:=PackedInt32Array()
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value and failures.size()<30:failures.append(label)
func summary(values:Array[int])->Dictionary:
	values.sort();return {"p50":values[values.size()/2],"p95":values[int(values.size()*.95)],"max":values[-1],"samples":values.size()}
func pack_frames(frames:Array)->PackedVector3Array:
	var packed:=PackedVector3Array();packed.resize(frames.size()*4)
	for i in frames.size():
		var f:Transform3D=frames[i];packed[i*4]=f.basis.x;packed[i*4+1]=f.basis.y;packed[i*4+2]=f.basis.z;packed[i*4+3]=f.origin
	return packed
func original(vertices:PackedVector3Array,joints:PackedInt32Array,weights:PackedFloat32Array,frames:Array)->PackedVector3Array:
	var out:=PackedVector3Array();out.resize(vertices.size())
	for i in vertices.size():
		var point:=Vector3.ZERO
		for j in 4:
			var at:=i*4+j
			if weights[at]>0:point+=(frames[joints[at]]*vertices[i])*weights[at]
		out[i]=point
	return out
func prepare_groups()->void:
	var vertices:PackedVector3Array=fixture.vertices;var joints:PackedInt32Array=fixture.joints;var weights:PackedFloat32Array=fixture.weights
	for i in vertices.size():
		var active:=0;var slot:=-1
		for j in 4:
			var at:=i*4+j
			if weights[at]>0:active+=1;slot=at
		if active==1 and weights[slot]==1.0:
			var bone:=joints[slot]
			if not rigid.has(bone):rigid[bone]={"points":PackedVector3Array(),"indices":PackedInt32Array()}
			rigid[bone].points.append(vertices[i]);rigid[bone].indices.append(i)
		else:mixed.append(i)
func engine_bulk(vertices:PackedVector3Array,joints:PackedInt32Array,weights:PackedFloat32Array,frames:Array)->PackedVector3Array:
	var out:=PackedVector3Array();out.resize(vertices.size())
	for bone:int in rigid:
		var points:PackedVector3Array=frames[bone]*(rigid[bone].points as PackedVector3Array)
		var ids:PackedInt32Array=rigid[bone].indices
		for i in ids.size():out[ids[i]]=points[i]
	for i in mixed:
		var point:=Vector3.ZERO
		for j in 4:
			var at:=i*4+j
			if weights[at]>0:point+=(frames[joints[at]]*vertices[i])*weights[at]
		out[i]=point
	return out
func negative_tests()->void:
	var v:=PackedVector3Array([Vector3(1,2,3)]);var b:=PackedInt32Array([0,999,-1,1000]);var w:=PackedFloat32Array([1,0,0,0])
	var frames:=pack_frames([Transform3D.IDENTITY])
	check(native.call("skin",v,b,w,frames)==v,"zero-weight invalid indices never dereferenced")
	for bad:Variant in [null,[],{},1,PackedFloat64Array()]:check(native.call("skin",bad,b,w,frames).is_empty(),"invalid position Variant")
	check(native.call("skin",PackedVector3Array(),b,w,frames).is_empty(),"empty positions")
	check(native.call("skin",v,PackedInt32Array([0]),w,frames).is_empty(),"short indices")
	check(native.call("skin",v,b,PackedFloat32Array([1]),frames).is_empty(),"short weights")
	for bad:float in [NAN,INF,-.1,1.1]:
		var changed:=w.duplicate();changed[0]=bad
		check(native.call("skin",v,b,changed,frames).is_empty(),"invalid weight")
	for bad:int in [-1,1,2147483647]:
		var changed:=b.duplicate();changed[0]=bad
		check(native.call("skin",v,changed,w,frames).is_empty(),"active bind bounds")
	check(native.call("skin",PackedVector3Array([Vector3.INF]),b,w,frames).is_empty(),"nonfinite positions")
	var changed:=frames.duplicate();changed[3]=Vector3.INF
	check(native.call("skin",v,b,w,changed).is_empty(),"nonfinite bind frame")
	check(native.call("skin",v,b,w,frames.slice(0,3)).is_empty(),"partial frame")
	var snapshot:PackedVector3Array=native.call("skin",v,b,w,frames)
	v[0]=Vector3(3,4,5);frames[3]=Vector3(10,10,10)
	check(snapshot==PackedVector3Array([Vector3(1,2,3)]),"returned snapshot owns data")
	var second:PackedVector3Array=native.call("skin",v,b,w,frames);second[0]=Vector3.ZERO
	check(native.call("skin",v,b,w,frames)==PackedVector3Array([Vector3(13,14,15)]),"result edits do not poison later output")
	var thread:=Thread.new();thread.start(func():return native.call("skin",v,b,w,frames))
	check(thread.wait_to_finish().is_empty(),"worker rejection")
	check(native.call("skin",v,b,w,frames).size()==1,"owner still works")
	var four:Array[Transform3D]=[
		Transform3D(Basis.from_euler(Vector3(.4,-.7,.2)),Vector3(100,-200,300)),
		Transform3D(Basis.from_scale(Vector3(-2,.3,1.2)),Vector3(-80,400,-70)),
		Transform3D(Basis(Vector3(1,.2,.3),Vector3(.4,1,.6),Vector3(.7,.8,1)),Vector3(9,8,7)),
		Transform3D.IDENTITY]
	var unusual:=PackedFloat32Array([.1,.2,.3,.35]);var four_ids:=PackedInt32Array([0,1,2,3]);var f4:=pack_frames(four)
	check((native.call("skin",v,four_ids,unusual,f4) as PackedVector3Array).to_byte_array()==original(v,four_ids,unusual,four).to_byte_array(),"four influences preserve order no normalization with reflection/shear")
	check(native.call("skin",v,b,PackedFloat32Array([0,0,0,0]),frames)==PackedVector3Array([Vector3.ZERO]),"zero influences reproduce source zero")
	var too_many:=PackedVector3Array();too_many.resize(65537)
	check(native.call("skin",too_many,b,w,frames).is_empty(),"vertex cap before data reads")
	var frame_cap:=PackedVector3Array();frame_cap.resize(4100)
	check(native.call("skin",v,b,w,frame_cap).is_empty(),"bind frame cap")
	for cycle in 50:
		var fresh:Object=ClassDB.instantiate("MeleeNativeSkin")
		check(fresh.call("skin",v,b,w,frames).size()==1,"fresh stateless lifetime")
		fresh.free()
func run()->void:
	check(GDExtensionManager.load_extension("res://skin.gdextension")==OK,"load")
	native=ClassDB.instantiate("MeleeNativeSkin")
	var f:=FileAccess.open("res://skin_fixture.bin",FileAccess.READ);fixture=f.get_var();f.close()
	var vertices:PackedVector3Array=fixture.vertices;var joints:PackedInt32Array=fixture.joints;var weights:PackedFloat32Array=fixture.weights
	check(fixture.errors.is_empty(),"capture valid")
	check(vertices.size()==8338 and fixture.indices.size()==13034*3,"complete actual hero")
	check(fixture.cases.size()==22,"all source and ordinary-action canaries captured")
	for key in fixture.bind_tests:check(fixture.bind_tests[key],"bind resolver "+key)
	prepare_groups()
	var poses:Array=[];var all_exact:=true;var greatest:=0.0;var rms_total:=0.0;var source_count:=0
	for c in fixture.cases.size():
		var row:Dictionary=fixture.cases[c];var frames:Array=row.frames;var packed:=pack_frames(frames)
		var reference:=original(vertices,joints,weights,frames)
		var bulk:=engine_bulk(vertices,joints,weights,frames)
		var got:PackedVector3Array=native.call("skin",vertices,joints,weights,packed)
		check(got.size()==vertices.size(),"native full output "+str(c))
		check(reference.to_byte_array()==got.to_byte_array(),"float32 operation bytes exact "+str(c))
		check(reference.to_byte_array()==bulk.to_byte_array(),"engine rigid bulk bytes exact "+str(c))
		all_exact=all_exact and reference.to_byte_array()==got.to_byte_array()
		var source_max:=0.0;var source_sum:=0.0
		for i in vertices.size():
			check(got[i]==reference[i],"native vertex "+str(c)+":"+str(i))
			if c>=fixture.source_manifest.cases.size():continue
			var native_index:int=fixture.source_to_native[i]
			var at:int=(c*vertices.size()+i)*3
			var dx:=float(got[native_index].x)-float(fixture.source_skin[at]);var dy:=float(got[native_index].y)-float(fixture.source_skin[at+1]);var dz:=float(got[native_index].z)-float(fixture.source_skin[at+2])
			var error:=sqrt(dx*dx+dy*dy+dz*dz);source_max=maxf(source_max,error);source_sum+=error*error
		if c<fixture.source_manifest.cases.size():
			check(source_max<.0001,"original JS skin bound "+str(c));greatest=maxf(greatest,source_max);rms_total+=source_sum;source_count+=vertices.size()
		poses.append({"case":row.case,"action":row.action,"vertices":got.size(),"original_js_max_m":source_max,"original_js_rms_m":sqrt(source_sum/vertices.size())})
	negative_tests()
	var slow:Array[int]=[];var engine:Array[int]=[];var native_times:Array[int]=[];var packed_times:Array[int]=[];var native_total:Array[int]=[]
	# Alternate order each iteration to reduce order bias. Same pose and full content.
	for iteration in 96:
		var frames:Array=fixture.cases[iteration%fixture.cases.size()].frames
		for method:int in ([0,1,2] if iteration%2==0 else [2,1,0]):
			var begin:=Time.get_ticks_usec()
			if method==0:
				original(vertices,joints,weights,frames)
				if iteration>=16:slow.append(Time.get_ticks_usec()-begin)
			elif method==1:
				engine_bulk(vertices,joints,weights,frames)
				if iteration>=16:engine.append(Time.get_ticks_usec()-begin)
			else:
				var packed:=pack_frames(frames);var packed_end:=Time.get_ticks_usec()
				native.call("skin",vertices,joints,weights,packed);var finish:=Time.get_ticks_usec()
				if iteration>=16:packed_times.append(packed_end-begin);native_times.append(finish-packed_end);native_total.append(finish-begin)
	native.free()
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"all_native_float32_bytes_exact":all_exact,"vertices":vertices.size(),"triangles":fixture.indices.size()/3,"poses":poses,"rigid_vertices":vertices.size()-mixed.size(),"mixed_vertices":mixed.size(),"rigid_groups":rigid.size(),"bind_slots":fixture.bindings.size(),"source_max_m":greatest,"source_rms_m":sqrt(rms_total/source_count),"original_loop_us":summary(slow),"engine_bulk_groups_us":summary(engine),"pack_196_bind_frames_us":summary(packed_times),"native_skin_boundary_us":summary(native_times),"native_plus_frame_pack_us":summary(native_total),"asset_sha":fixture.asset_sha,"sampler_sha":fixture.sampler_sha,"source_skin_sha":fixture.source_skin_sha,"dll_sha":FileAccess.get_sha256("res://melee_skin.dll"),"scope":"Output-only prototype. Whole skin at22 actual-rig poses; original JS12canary comparisons. CPU includes validation and output allocation; excludes pose sampling/global bind composition/lifecycle checks/query/refit/GPU. No FPS claim."}
	f=FileAccess.open("res://../report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
