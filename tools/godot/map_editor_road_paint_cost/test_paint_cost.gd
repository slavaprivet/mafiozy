extends SceneTree
const Base = preload("res://scripts/procedural_factory.gd")
const Candidate = preload("res://paint_array_candidate.gd")
const SHA := "82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd"
var checks := 0
var failures: Array = []
var mode := "allow"
var heap_deltas := {"base":[],"candidate":[]}
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value and failures.size()<20: failures.append(label)
func authorize(_request: Dictionary) -> Dictionary:
	if mode == "deny": return {"approved":false}
	return {"approved":true,"commit":commit,"rollback":rollback}
func commit() -> bool: return mode != "fail"
func rollback() -> bool: return true
func stats(values: Array) -> Dictionary:
	values.sort(); return {"p50_us":values[values.size()/2],"p95_us":values[floori(values.size()*.95)],"samples":values.size()}
func input_bytes(arrays: Array) -> int:
	var total := 0
	for channel in arrays:
		if channel != null: total += channel.to_byte_array().size()
	return total
func bytes_equal(left: Array,right: Array) -> bool:
	for i in left.size():
		if (left[i]==null)!=(right[i]==null): return false
		if left[i]!=null and left[i].to_byte_array()!=right[i].to_byte_array(): return false
	return true
func compare(a: RefCounted,b: RefCounted,key: String) -> void:
	var x: Dictionary=a._paint_batches[key];var y: Dictionary=b._paint_batches[key]
	check(x.current.to_byte_array()==y.current.to_byte_array(),"Exact current vertex bytes")
	check(bytes_equal(x.arrays,y.arrays),"Original immutable channels byte parity")
	check(bytes_equal(x.node.mesh.surface_get_arrays(0),y.node.mesh.surface_get_arrays(0)),"Baseline/candidate native array readback parity, not source GPU proof")
	check(x.node.material_override.get_instance_id()==a._materials[x.source.material].get_instance_id() and y.node.material_override.get_instance_id()==b._materials[y.source.material].get_instance_id(),"Original materials unchanged")
	check(x.node.mesh.get_meta("source_geometry")==y.node.mesh.get_meta("source_geometry") and x.node.mesh.get_meta("source_geometry")==a._meshes[x.source.geometry].get_meta("source_geometry"),"Exact source descriptor/groups/drawRange metadata preserved")
	check(a._history.size()==b._history.size() and a._redo.size()==b._redo.size(),"History parity")
func timed_move(factory: RefCounted,id: String,frame: Transform3D) -> int:
	var heap_before:=OS.get_static_memory_usage()
	var start:=Time.get_ticks_usec();var ok:bool=factory.set_object_transform(id,frame);var elapsed:=Time.get_ticks_usec()-start
	heap_deltas[factory.get_meta("benchmark_label")].append(OS.get_static_memory_usage()-heap_before)
	check(ok,"Measured move allowed");return elapsed
func timed_history(factory: RefCounted,redo: bool) -> int:
	var start:=Time.get_ticks_usec();var ok:bool=factory.redo() if redo else factory.undo();var elapsed:=Time.get_ticks_usec()-start
	check(ok,"Measured history allowed");return elapsed
func run() -> void:
	var baseline:=Base.new();var candidate:=Candidate.new()
	baseline.set_meta("benchmark_label","base");candidate.set_meta("benchmark_label","candidate")
	check(baseline.configure(SHA,authorize) and candidate.configure(SHA,authorize),"Actual source admission")
	var base_result:Dictionary=baseline.build_roads();var candidate_result:Dictionary=candidate.build_roads()
	root.add_child(base_result.root);root.add_child(candidate_result.root)
	var batches:Array=baseline._paint_batches.keys()
	batches.sort_custom(func(x,y):return baseline._paint_batches[x].current.size()<baseline._paint_batches[y].current.size())
	check(batches.size()==59 and baseline._paint_ids.size()==6449,"Original 59 chunks/6449 IDs")
	for key in batches:
		var batch:Dictionary=baseline._paint_batches[key];var spec:Dictionary=baseline._meshes[batch.source.geometry].get_meta("source_geometry")
		check(batch.arrays[Mesh.ARRAY_VERTEX].to_byte_array()==baseline._buffers[spec.attributes.position.buffer],"All59 source original vertex submission bytes")
		check(batch.arrays[Mesh.ARRAY_NORMAL].to_byte_array()==baseline._buffers[spec.attributes.normal.buffer],"All59 source original normal submission bytes")
		check(bytes_equal(batch.arrays,candidate._paint_batches[key].arrays),"All59 initial candidate array submissions equal")
		check(batch.arrays[Mesh.ARRAY_TEX_UV]==null and spec.get("index")==null,"Original paint no invented UV/index source")
		var indices:PackedInt32Array=batch.arrays[Mesh.ARRAY_INDEX]
		for triangle in range(0,indices.size(),3):
			check(indices[triangle]==triangle and indices[triangle+1]==triangle+2 and indices[triangle+2]==triangle+1,"Exact generated original winding, no index quality changes")
		for marker in batch.source.objectIds.size():
			var source_id:String=batch.source.objectIds[marker]
			check(baseline.resolve_paint_vertex(key,marker*6)==source_id and candidate.resolve_paint_vertex(key,marker*6+5)==source_id,"All6449 stable paint IDs/six-vertex mappings")
	var report:=[]
	for key in [batches[0],batches[batches.size()/2],batches.back()]:
		var paint:Dictionary=baseline._paint_batches[key];var id:String=paint.source.objectIds[0]
		var original:Transform3D=baseline.object_transform(id);var shifted:=original;shifted.origin+=Vector3(8,0,2)
		var base_mesh:Mesh=paint.node.mesh;var new_mesh:Mesh=candidate._paint_batches[key].node.mesh
		var arrays: Array=paint.arrays;var prototype:Array=arrays.duplicate(true)
		# Warm full source operations; history returns exact original meshes.
		for i in 5:
			baseline.set_object_transform(id,shifted);candidate.set_object_transform(id,shifted);baseline.undo();candidate.undo()
		var times:Dictionary={"base_move":[],"candidate_move":[],"base_undo":[],"candidate_undo":[],"base_redo":[],"candidate_redo":[]}
		heap_deltas={"base":[],"candidate":[]}
		for i in 60:
			if i%2==0:
				times.base_move.append(timed_move(baseline,id,shifted));times.candidate_move.append(timed_move(candidate,id,shifted))
			else:
				times.candidate_move.append(timed_move(candidate,id,shifted));times.base_move.append(timed_move(baseline,id,shifted))
			compare(baseline,candidate,key)
			times.base_undo.append(timed_history(baseline,false));times.candidate_undo.append(timed_history(candidate,false))
			check(paint.node.mesh==base_mesh and candidate._paint_batches[key].node.mesh==new_mesh,"Undo exact original prototype identity")
			times.base_redo.append(timed_history(baseline,true));times.candidate_redo.append(timed_history(candidate,true));compare(baseline,candidate,key)
			baseline.undo();candidate.undo()
		check(bytes_equal(arrays,prototype),"Prototype normal/index/vertices untouched after all edits")
		var copied:Array=candidate.copy_paint_channels(arrays);var normal:PackedVector3Array=copied[Mesh.ARRAY_NORMAL];normal[0]=Vector3(9,8,7);copied[Mesh.ARRAY_NORMAL]=normal
		check(bytes_equal(arrays,prototype),"Explicit nonvertex packed-channel copies cannot alias source")
		var result:Dictionary={"batch":key,"vertices":paint.current.size(),"markings":paint.source.objectIds.size(),"native_submission_payload_bytes":input_bytes(arrays),"changed_vertex_array_bytes":paint.current.to_byte_array().size(),"avoided_old_vertex_channel_copy_bytes":paint.current.to_byte_array().size(),"new_mesh_per_move":1,"new_mesh_per_undo_redo":0,"allocator_bytes_measured":false}
		for label in times:result[label]=stats(times[label])
		for label in heap_deltas:
			var ordered:Array=heap_deltas[label];ordered.sort()
			result[label+"_process_static_live_delta"]={"p50_bytes":ordered[ordered.size()/2],"p95_bytes":ordered[floori(ordered.size()*.95)],"samples":ordered.size(),"not_private_batch_allocation_or_gpu":true}
		report.append(result)
		check(baseline.delete_object(id) and candidate.delete_object(id),"Delete parity");compare(baseline,candidate,key);baseline.undo();candidate.undo()
		for refused in ["deny","fail"]:
			mode=refused;var n:int=baseline._history.size();var old:Mesh=paint.node.mesh
			check(not baseline.set_object_transform(id,shifted) and not candidate.set_object_transform(id,shifted),"Owner refusal parity")
			check(paint.node.mesh==old and baseline._history.size()==n and candidate._history.size()==n,"Failed transaction resource/history preserved")
			mode="allow"
	print(JSON.stringify({"suite":"actual-original-road-paint-cpu-cost","checks":checks,"failures":failures,"results":report,"sourceBatchCount":59,"gpu":false,"performanceCommonScene":"NOT_CHECKED","nativeReadback":"Baseline/candidate parity only; exact submission source arrays checked separately"}))
	base_result.root.free();candidate_result.root.free();quit(0 if failures.is_empty() else 1)
