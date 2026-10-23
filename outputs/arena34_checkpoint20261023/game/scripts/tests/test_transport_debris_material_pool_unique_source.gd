extends SceneTree
const Pool=preload("res://scripts/transport/candidates/transport_debris_material_pool_unique_source.gd")
const Baseline=preload("res://scripts/transport/transport_debris_material_pool.gd")
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const CORRECTNESS_ONLY_ENV:="MAFIOZI_TRANSPORT_UNIQUE_SOURCE_CORRECTNESS_ONLY"
var checks:=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var actual: Dictionary=await _actual_compact(world)
	await _guards(world)
	finish(actual)

func _actual_compact(world: Node3D) -> Dictionary:
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	var profile: Dictionary={}
	for row: Dictionary in Bindings.load_oracle().get("rows",[]):
		if row.profile_id=="compact_sedan": profile=row; break
	check(loaded.ok and not profile.is_empty(),"actual compact visual/profile load")
	if not loaded.ok or profile.is_empty(): return {"ok":false,"error":"load"}
	var visual=loaded.visual; world.add_child(visual.root)
	var bound:=Bindings.bind(visual,profile)
	check(bound.ok,"actual compact exact damage bindings")
	if not bound.ok: visual.dispose(); return {"ok":false,"error":bound.get("error","")}
	var sources: Array=[]
	for descriptor: Dictionary in bound.explosion:
		if not descriptor.copy_eligible_at_export: continue
		_collect_opaque_surface_materials(descriptor.source,sources)
	var source_ids: Dictionary={}
	for material: StandardMaterial3D in sources: source_ids[material.get_instance_id()]=true
	check(sources.size()==72 and source_ids.size()==29,"actual compact 72 surfaces / 29 exact source identities")
	var pool:=Pool.new(); var configured: Dictionary=pool.configure(sources,7,11)
	check(configured.get("ok",false) and configured.get("total",0)==72 and configured.get("prepared",-1)==0 and not configured.get("ready",true),"actual pool configured empty: "+str(configured.get("error","")))
	if not configured.get("ok",false): visual.dispose(); pool.dispose(); return {"ok":false,"error":configured.get("error","")}
	var token: RefCounted=configured.preparation_token
	check(token!=null,"opaque preparation token issued")
	check(pool.prewarm_step(sources,8,11).error=="stale_generation","foreign generation rejected without mutation")
	check(pool.prewarm_step(sources,7,12).error=="stale_revision","foreign revision rejected without mutation")
	check(pool.prewarm_step(sources,7,11,2).error=="budget","budget above one rejected")
	var step_us: Array=[]
	for i in sources.size():
		var begin:=Time.get_ticks_usec(); var stepped: Dictionary=pool.prewarm_step(sources,7,11); step_us.append(Time.get_ticks_usec()-begin)
		check(stepped.ok and stepped.prepared==i+1,"one private material prepared at step "+str(i))
	var last_step_us: int=step_us[-1]
	var receipt_begin:=Time.get_ticks_usec(); var receipt: Dictionary=pool.receipt(sources,7,11); var receipt_us:=Time.get_ticks_usec()-receipt_begin
	var private_ids: Dictionary={}
	for id: int in receipt.private_instance_ids: private_ids[id]=true
	check(receipt.ready and receipt.prepared==72 and private_ids.size()==72,"ready owns 72 independent private Resources")
	check(pool.take_prepared(sources,7,11,RefCounted.new()).error=="preparation_token","foreign preparation token rejected")
	var take_begin:=Time.get_ticks_usec(); var taken: Dictionary=pool.take_prepared(sources,7,11,token); var take_us:=Time.get_ticks_usec()-take_begin
	check(taken.ok and taken.count==72 and taken.materials.size()==72 and taken.consumed,"one-shot ownership transfer")
	var transferred_ids: Dictionary={}; var source_identity_set: Dictionary={}
	for material: StandardMaterial3D in sources: source_identity_set[material.get_instance_id()]=true
	for material: StandardMaterial3D in taken.materials:
		transferred_ids[material.get_instance_id()]=true
		check(not source_identity_set.has(material.get_instance_id()),"transferred Resource is private")
	check(transferred_ids.size()==72,"transferred materials remain per-surface independent")
	check(pool.take_prepared(sources,7,11,token).error=="consumed" and pool.receipt(sources,7,11).error=="consumed","consumed pool never retransfers or claims ready")
	var retained:=taken.materials[0] as StandardMaterial3D; retained.roughness=.123; pool.dispose()
	check(is_instance_valid(retained) and is_equal_approx(retained.roughness,.123),"dispose does not free transferred caller ownership")
	var comparison: Dictionary={"skipped":true,"reason":"correctness_only"} if OS.get_environment(CORRECTNESS_ONLY_ENV)=="1" else _comparison(sources)
	visual.dispose()
	step_us.sort(); var true_median: float=(float(step_us[35])+float(step_us[36]))*.5
	return {"ok":true,"surfaces":72,"source_identities":29,"private_resources":72,"step_min_us":step_us[0],"step_true_median_us":true_median,"step_max_us":step_us[-1],"final_validation_step_us":last_step_us,"ready_receipt_us":receipt_us,"take_prepared_us":take_us,"step_samples_us":step_us,"comparison_20_pairs":comparison}

func _comparison(sources: Array) -> Dictionary:
	var samples:={"baseline":{"configure":[],"final":[],"receipt":[],"take":[]},"candidate":{"configure":[],"final":[],"receipt":[],"take":[]}}
	for sample in 20:
		var order: Array=[["baseline",Baseline],["candidate",Pool]]
		if sample%2==1: order.reverse()
		for entry: Array in order:
			var measured:=_measure_pool(entry[1],sources,100+sample,23)
			check(measured.ok,"comparison "+entry[0]+" sample "+str(sample)+": "+str(measured.get("error","")))
			if measured.ok:
				for key in ["configure","final","receipt","take"]: samples[entry[0]][key].append(measured[key])
	var result:={}
	for label in ["baseline","candidate"]:
		result[label]={}
		for key in ["configure","final","receipt","take"]: result[label][key]=_distribution(samples[label][key])
	return result

func _measure_pool(script: Script,sources: Array,generation: int,revision: int) -> Dictionary:
	var pool: RefCounted=script.new(); var begin:=Time.get_ticks_usec(); var configured: Dictionary=pool.configure(sources,generation,revision); var configure_us:=Time.get_ticks_usec()-begin
	if not configured.get("ok",false): pool.dispose(); return {"ok":false,"error":"configure:"+str(configured.get("error",""))}
	for i in sources.size()-1:
		var step: Dictionary=pool.prewarm_step(sources,generation,revision)
		if not step.get("ok",false): pool.dispose(); return {"ok":false,"error":"prewarm:"+str(step.get("error",""))}
	begin=Time.get_ticks_usec(); var final: Dictionary=pool.prewarm_step(sources,generation,revision); var final_us:=Time.get_ticks_usec()-begin
	begin=Time.get_ticks_usec(); var receipt: Dictionary=pool.receipt(sources,generation,revision); var receipt_us:=Time.get_ticks_usec()-begin
	begin=Time.get_ticks_usec(); var taken: Dictionary=pool.take_prepared(sources,generation,revision,configured.preparation_token); var take_us:=Time.get_ticks_usec()-begin
	var ok: bool=bool(final.get("ready",false)) and bool(receipt.get("ready",false)) and bool(taken.get("ok",false)) and int(taken.get("count",0))==sources.size()
	pool.dispose(); return {"ok":ok,"error":"transfer" if not ok else "","configure":configure_us,"final":final_us,"receipt":receipt_us,"take":take_us}

func _distribution(values: Array) -> Dictionary:
	var sorted:=values.duplicate(); sorted.sort(); var count:=sorted.size()
	if count==0: return {"count":0}
	var median: float=float(sorted[count/2]) if count%2 else (float(sorted[count/2-1])+float(sorted[count/2]))*.5
	var p95_index:=clampi(ceili(float(count)*.95)-1,0,count-1)
	return {"count":count,"min_us":sorted[0],"median_us":median,"p95_us":sorted[p95_index],"max_us":sorted[-1],"samples_us":sorted}

func _guards(_world: Node3D) -> void:
	var a:=_material(.2); var b:=_material(.4); var sources: Array=[a,b]
	var pool:=Pool.new(); var configured: Dictionary=pool.configure(sources,1,3)
	check(configured.get("ok",false),"guard pool configured: "+str(configured.get("error","")))
	if not configured.get("ok",false): pool.dispose(); return
	var old_token: RefCounted=configured.preparation_token
	check(pool.prewarm_step(sources,1,3).prepared==1,"guard pool prepares exactly one")
	var replacement:=_material(.6); var replaced: Array=[a,replacement]
	check(pool.prewarm_step(replaced,1,3).error=="source_identity_changed","ordered source replacement invalidates pool")
	check(pool.receipt(sources,1,3).error=="source_identity_changed","identity invalidation is sticky")
	pool.dispose()

	pool=Pool.new(); configured=pool.configure(sources,1,3); a.roughness=.77
	check(pool.prewarm_step(sources,1,3).error=="source_content_changed","direct source property mutation invalidates pool")
	pool.dispose(); a=_material(.2); b=_material(.4); sources=[a,b]

	pool=Pool.new(); a.set_meta("source_metadata",{"paint":"red"}); configured=pool.configure(sources,1,3)
	var metadata: Dictionary=a.get_meta("source_metadata"); metadata.paint="blue"
	check(pool.receipt(sources,1,3).error=="source_content_changed","silent in-place metadata Dictionary mutation caught by byte receipt")
	pool.dispose(); a=_material(.2); b=_material(.4); sources=[a,b]

	# Nonadjacent aliases must share only the per-call source read. Their ordered
	# admission signatures and their private copies remain independent.
	var alias:=_material(.28); alias.set_meta("source_metadata",{"paint":"red"})
	var other:=_material(.61); var aliases: Array=[alias,other,alias,alias]
	pool=Pool.new(); configured=pool.configure(aliases,2,4)
	for i in aliases.size(): check(pool.prewarm_step(aliases,2,4).get("ok",false),"nonadjacent alias prewarm "+str(i))
	var alias_receipt: Dictionary=pool.receipt(aliases,2,4)
	var alias_private_ids: Dictionary={}
	for id: int in alias_receipt.get("private_instance_ids",[]): alias_private_ids[id]=true
	check(alias_receipt.get("ready",false) and alias_private_ids.size()==4,"source aliases still own four independent private materials")
	var mismatched_signature: PackedByteArray=pool._source_signatures[2].duplicate()
	mismatched_signature[0]=mismatched_signature[0]^1; pool._source_signatures[2]=mismatched_signature
	check(pool.receipt(aliases,2,4).get("error","")=="source_content_changed","cached source bytes compare with every aliased surface admission signature")
	pool.dispose()
	alias=_material(.28); alias.set_meta("source_metadata",{"paint":"red"}); other=_material(.61); aliases=[alias,other,alias,alias]
	pool=Pool.new(); configured=pool.configure(aliases,2,4)
	for i in aliases.size(): pool.prewarm_step(aliases,2,4)
	# Prove a fresh call, rather than a persistent cache, observes silent mutation.
	var alias_metadata: Dictionary=alias.get_meta("source_metadata"); alias_metadata.paint="blue"
	check(pool.receipt(aliases,2,4).get("error","")=="source_content_changed","fresh receipt catches silent mutation of aliased source")
	pool.dispose()
	var restored:=_material(.44); pool=Pool.new(); configured=pool.configure([restored,restored],3,4)
	var original_roughness:=restored.roughness; restored.roughness=.12; restored.roughness=original_roughness
	var restored_receipt: Dictionary=pool.receipt([restored,restored],3,4)
	check(restored_receipt.get("ok",false) and restored_receipt.get("error","").is_empty(),"silent exact restore is observationally identical at fresh signature boundary")
	pool.dispose(); restored=_material(.44); pool=Pool.new(); configured=pool.configure([restored,restored],3,4)
	restored.emit_changed()
	check(pool.receipt([restored,restored],3,4).get("error","")=="source_content_changed","explicit changed signal remains sticky-invalid")
	pool.dispose()
	# Equal-valued Resources are distinct identities and may not collapse.
	var equal_a:=_material(.37); var equal_b:=_material(.37); var equal_sources: Array=[equal_a,equal_b,equal_a]
	pool=Pool.new(); configured=pool.configure(equal_sources,3,5)
	equal_b.roughness=.73
	check(pool.receipt(equal_sources,3,5).get("error","")=="source_content_changed","equal-valued distinct source Resource is validated independently")
	pool.dispose(); a=_material(.2); b=_material(.4); sources=[a,b]

	pool=Pool.new(); configured=pool.configure(sources,1,3); pool.prewarm_step(sources,1,3)
	(pool._private[0] as StandardMaterial3D).roughness=.09
	check(pool.receipt(sources,1,3).error=="private_content_changed","private mutation before transfer invalidates ready")
	pool.dispose()

	a=_material(.2); a.set_meta("source_metadata",{"nested":{"paint":"red"}}); sources=[a]
	pool=Pool.new(); configured=pool.configure(sources,2,0); pool.prewarm_step(sources,2,0)
	var transferred: Dictionary=pool.take_prepared(sources,2,0,configured.preparation_token)
	var private_meta: Dictionary=(transferred.materials[0] as StandardMaterial3D).get_meta("source_metadata")
	private_meta.nested.paint="blue"
	check(a.get_meta("source_metadata").nested.paint=="red","private metadata containers do not alias source metadata")
	pool.dispose(); a=_material(.2); b=_material(.4); sources=[a,b]

	var nested:=_material(.3); nested.next_pass=_material(.5)
	pool=Pool.new(); check(pool.configure([nested],1,0).error=="unsupported_nested_resource","nested Resource graph rejected instead of false clone parity"); pool.dispose()
	var shader:=ShaderMaterial.new(); pool=Pool.new(); check(pool.configure([shader],1,0).error=="material_type","non-StandardMaterial3D rejected"); pool.dispose()
	var scripted:=_material(.31); var scripted_class:=GDScript.new(); scripted_class.source_code="extends StandardMaterial3D\n"
	check(scripted_class.reload()==OK,"scripted material adversary compiles"); scripted.set_script(scripted_class)
	pool=Pool.new(); check(pool.configure([scripted],1,0).error=="scripted_material","scripted material getter surface rejects before signature caching"); pool.dispose()
	var attached_later:=_material(.32); pool=Pool.new(); configured=pool.configure([attached_later],1,0); attached_later.set_script(scripted_class)
	check(pool.receipt([attached_later],1,0).error=="source_content_changed","script attached after admission rejects before validation cache read"); pool.dispose()
	var nonfinite:=_material(.3); nonfinite.albedo_color=Color(NAN,.2,.3,1)
	pool=Pool.new(); check(pool.configure([nonfinite],1,0).error=="material_content","nonfinite stored property rejected"); pool.dispose()
	var packed_bad:=_material(.3); packed_bad.set_meta("bad",PackedFloat32Array([1.0,NAN]))
	pool=Pool.new(); check(pool.configure([packed_bad],1,0).error=="material_content","nonfinite packed metadata rejected"); pool.dispose()
	var cyclic:=_material(.3); var cycle: Array=[]; cycle.append(cycle); cyclic.set_meta("cycle",cycle)
	pool=Pool.new(); check(pool.configure([cyclic],1,0).error=="material_content","cyclic metadata rejected without recursion"); pool.dispose()
	var deep:=_material(.3); var nested_array: Array=[]; var cursor: Array=nested_array
	for i in 10:
		var child: Array=[]; cursor.append(child); cursor=child
	deep.set_meta("deep",nested_array)
	pool=Pool.new(); check(pool.configure([deep],1,0).error=="material_content","over-depth metadata rejected"); pool.dispose()
	var oversized:=_material(.3); var many: Array=[]; many.resize(Pool.MAX_VARIANT_ITEMS+1); oversized.set_meta("many",many)
	pool=Pool.new(); check(pool.configure([oversized],1,0).error=="material_content","oversized metadata rejected"); pool.dispose()
	var callable_bad:=_material(.3); callable_bad.set_meta("callable",Callable(self,"finish"))
	pool=Pool.new(); check(pool.configure([callable_bad],1,0).error=="material_content","callable metadata rejected"); pool.dispose()
	var shared_container:={"paint":"red"}; var aliased:=_material(.3); aliased.set_meta("first",shared_container); aliased.set_meta("second",shared_container)
	pool=Pool.new(); check(pool.configure([aliased],1,0).error=="material_content","repeated mutable container identity rejected"); pool.dispose()
	var huge_string:=_material(.3); huge_string.set_meta("huge","я".repeat(Pool.MAX_VARIANT_ITEMS))
	pool=Pool.new(); check(pool.configure([huge_string],1,0).error=="material_content","UTF-8 byte budget rejects oversized string"); pool.dispose()

	a=_material(.2); b=_material(.4); sources=[a,b]; pool=Pool.new(); configured=pool.configure(sources,4,8); old_token=configured.preparation_token
	pool.prewarm_step(sources,4,8); pool.prewarm_step(sources,4,8)
	var c:=_material(.1); var d:=_material(.9); var reset_sources: Array=[c,d]
	check(pool.reset(reset_sources,4,9).error=="stale_generation","same generation reset rejected")
	var old_receipt: Dictionary=pool.receipt(sources,4,8); check(old_receipt.ready,"failed stale reset leaves old pool intact")
	var abandoned_private:=pool._private[0] as StandardMaterial3D; var private_callback:=Callable(pool,"_on_private_changed")
	check(abandoned_private.changed.is_connected(private_callback),"private watcher connected before reset")
	var reset_result: Dictionary=pool.reset(reset_sources,5,0)
	check(reset_result.ok and reset_result.preparation_token!=old_token and reset_result.prepared==0,"new generation reset installs new opaque token")
	check(not abandoned_private.changed.is_connected(private_callback),"reset disconnects abandoned private watcher")
	abandoned_private.roughness=.66
	pool.prewarm_step(reset_sources,5,0); pool.prewarm_step(reset_sources,5,0)
	check(pool.take_prepared(reset_sources,5,0,old_token).error=="preparation_token","old generation token cannot transfer reset pool")
	var new_taken: Dictionary=pool.take_prepared(reset_sources,5,0,reset_result.preparation_token)
	check(new_taken.ok and new_taken.count==2,"new generation token transfers exact pool")
	var kept:=new_taken.materials[0] as StandardMaterial3D; pool.dispose(); kept.albedo_color=Color.GREEN
	check(is_instance_valid(kept) and kept.albedo_color.is_equal_approx(Color.GREEN),"reset/dispose never reclaim transferred Resource")

	a=_material(.25); pool=Pool.new(); configured=pool.configure([a],9,1)
	var callback:=Callable(pool,"_on_source_changed")
	check(a.changed.is_connected(callback),"source watcher connected during ownership")
	pool.dispose()
	check(not a.changed.is_connected(callback),"dispose disconnects retained source watcher")
	a.roughness=.55
	check(pool.receipt([a],9,1).error=="disposed","disposed pool stays inert")

func _collect_opaque_surface_materials(node: Node3D, output: Array) -> void:
	if not node.visible: return
	if node is MeshInstance3D:
		if node.mesh==null: return
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			if not material is StandardMaterial3D or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: return
		for surface in node.mesh.get_surface_count(): output.append(node.get_active_material(surface))
	for child: Node in node.get_children():
		if child is Node3D: _collect_opaque_surface_materials(child,output)

func _material(value: float) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new(); material.albedo_color=Color(value,.3,.5,1); material.roughness=.42
	return material

func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DEBRIS_MATERIAL_POOL ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"load-only private material storage; no burn/callback/HP/authority/event/GPU/FPS"}))
	quit(0 if failures.is_empty() else 1)
