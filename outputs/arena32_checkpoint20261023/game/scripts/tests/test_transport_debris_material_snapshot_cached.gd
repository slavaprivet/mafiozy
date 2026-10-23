extends SceneTree
const Cached=preload("res://scripts/transport/candidates/transport_vehicle_debris_material_snapshot_cached.gd")
const Frozen=preload("res://scripts/transport/candidates/transport_vehicle_debris_material_snapshot.gd")
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
var checks:=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	check(Cached.SOURCE_EXPLOSION_ORDER==Frozen.SOURCE_EXPLOSION_ORDER,"source explosion order inherited exactly")
	await _shared_alias_and_lifecycle(world)
	var distinct_frozen:=_worst_distinct(world,Frozen,false)
	var distinct_cached:=_worst_distinct(world,Cached,true)
	var frozen_runs: Array=[]; var cached_runs: Array=[]
	for iteration in 8:
		var order: Array=[[Frozen,false,"frozen"],[Cached,true,"cached"]] if iteration%2==0 else [[Cached,true,"cached"],[Frozen,false,"frozen"]]
		for item: Array in order:
			var measured: Dictionary=await _actual_compact(world,item[0],item[1])
			check(measured.ok,String(item[2])+" actual compact run "+str(iteration))
			if measured.ok:
				if item[1]: cached_runs.append(measured)
				else: frozen_runs.append(measured)
	finish({"actual_frozen":_cost_summary(frozen_runs),"actual_cached":_cost_summary(cached_runs),"worst_distinct_frozen":distinct_frozen,"worst_distinct_cached":distinct_cached,"qualification":"eight alternating-order samples; report min/median/max only, no p95/FPS claim"})

func _shared_alias_and_lifecycle(world: Node3D) -> void:
	var setup:=_setup_many(world,4,true,"alias")
	check(setup.ok,"four-surface alias fixture configured")
	if not setup.ok: return
	var helper=setup.helper
	var staged: Dictionary=helper.stage_material_snapshot(0,1)
	check(staged.ok and staged.surfaces==4,"alias fixture staged")
	check(staged.source_signature_reads==1 and staged.source_signature_cache_hits==3,"stage source signature exact-identity cache 1+3")
	check(staged.source_graph_reads==1 and staged.source_graph_cache_hits==3,"stage source graph exact-identity cache 1+3")
	check(_unique_private_materials(helper)==4,"stage keeps four independent prepared materials")
	var foreign:=RefCounted.new()
	check(helper.commit_material_snapshot(foreign).error=="stage_token","foreign stage token rejected")
	var committed: Dictionary=helper.commit_material_snapshot(staged.stage_token)
	check(committed.ok and committed.source_signature_reads==1 and committed.source_signature_cache_hits==3,"commit source signature exact-identity cache 1+3")
	check(_unique_private_materials(helper)==4,"commit keeps four independent copied materials")
	var private_materials:=_private_materials(helper)
	(private_materials[0] as StandardMaterial3D).roughness=.17
	check(helper.launch_with_visual_revision([],1).error=="private_material_changed","independent private byte guard remains active")
	helper.dispose(); setup.root.free()

	var mutation:=_setup_many(world,4,true,"mutation")
	helper=mutation.helper; staged=helper.stage_material_snapshot(0,1)
	(mutation.shared as StandardMaterial3D).roughness=.91
	check(staged.ok and helper.commit_material_snapshot(staged.stage_token).error=="material_content_changed","shared source mutation after cached stage rejected")
	check(helper.material_snapshot_receipt().revision==0 and not helper.material_snapshot_receipt().committed,"source mutation rejection is atomic")
	check(helper.abort_material_snapshot(staged.stage_token).ok,"failed cached transaction aborts")
	check(helper.commit_material_snapshot(staged.stage_token).error=="no_pending","aborted cached token is stale")
	helper.dispose(); mutation.root.free()

	var replacement:=_setup_many(world,4,true,"replacement")
	helper=replacement.helper; staged=helper.stage_material_snapshot(0,1)
	var replacement_material:=StandardMaterial3D.new(); replacement_material.albedo_color=Color.RED
	(replacement.sources[2] as MeshInstance3D).mesh.surface_set_material(0,replacement_material)
	check(helper.commit_material_snapshot(staged.stage_token).error=="source_material_changed","aliased source replacement after stage rejected")
	helper.abort_material_snapshot(staged.stage_token); helper.dispose(); replacement.root.free()

	var nested:=_setup_many(world,4,true,"nested")
	helper=nested.helper; var next_pass:=StandardMaterial3D.new(); (nested.shared as StandardMaterial3D).next_pass=next_pass
	staged=helper.stage_material_snapshot(0,1); next_pass.albedo_color=Color.BLUE; next_pass.emit_changed()
	var nested_commit: Dictionary=helper.commit_material_snapshot(staged.stage_token)
	check(nested_commit.get("error","")=="material_content_changed","nested source Resource mutation remains watched")
	helper.abort_material_snapshot(staged.stage_token); helper.dispose(); nested.root.free()

	var reset_case:=_setup_many(world,4,true,"reset")
	helper=reset_case.helper; staged=helper.stage_material_snapshot(0,1); helper.reset()
	check(helper.commit_material_snapshot(staged.stage_token).error=="no_pending","reset invalidates cached pending token")
	check(helper.stage_material_snapshot(1,2).error=="stale_revision","reset does not invent a visual revision")
	helper.dispose(); reset_case.root.free()

func _worst_distinct(world: Node3D, snapshot_script: Script, expect_cache: bool) -> Dictionary:
	var label:="cached" if expect_cache else "frozen"
	var setup:=_setup_many(world,72,false,"distinct_"+label,snapshot_script)
	check(setup.ok,"72-distinct "+label+" fixture configured")
	if not setup.ok: return {"ok":false,"error":setup.error}
	var helper=setup.helper
	var stage_begin:=Time.get_ticks_usec(); var staged: Dictionary=helper.stage_material_snapshot(0,1); var stage_us:=Time.get_ticks_usec()-stage_begin
	check(staged.ok and staged.surfaces==72,"72-distinct "+label+" fixture staged")
	if expect_cache:
		check(staged.source_signature_reads==72 and staged.source_signature_cache_hits==0,"distinct stage has no false signature equivalence")
		check(staged.source_graph_reads==72 and staged.source_graph_cache_hits==0,"distinct stage has no false graph equivalence")
	check(_unique_private_materials(helper)==72,"72 distinct prepared private Resources")
	var commit_begin:=Time.get_ticks_usec(); var committed: Dictionary=helper.commit_material_snapshot(staged.stage_token); var commit_us:=Time.get_ticks_usec()-commit_begin
	if expect_cache: check(committed.ok and committed.source_signature_reads==72 and committed.source_signature_cache_hits==0,"distinct commit has no false signature equivalence")
	else: check(committed.ok,"frozen distinct commit succeeds")
	check(_unique_private_materials(helper)==72,"72 distinct committed private Resources")
	helper.dispose(); setup.root.free()
	return {"ok":committed.get("ok",false),"stage_us":stage_us,"commit_us":commit_us,"event_us":stage_us+commit_us,"source_aliases":0}

func _actual_compact(world: Node3D, snapshot_script: Script, expect_cache: bool) -> Dictionary:
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var loaded:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	var profile: Dictionary={}
	for row: Dictionary in Bindings.load_oracle().get("rows",[]):
		if row.profile_id=="compact_sedan": profile=row; break
	if not loaded.ok or profile.is_empty(): return {"ok":false,"error":"load"}
	var visual=loaded.visual; world.add_child(visual.root)
	var bound:=Bindings.bind(visual,profile)
	if not bound.ok: visual.dispose(); return {"ok":false,"error":bound.get("error","")}
	var rows: Array=[]
	for descriptor: Dictionary in bound.explosion:
		if not descriptor.copy_eligible_at_export: continue
		rows.append({"source":descriptor.source,"mass_kg":18.0,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.05})
	var helper=snapshot_script.new()
	var configure_begin:=Time.get_ticks_usec(); var configured: Dictionary=helper.configure(visual.root,world,rows,null,0,0); var configure_us:=Time.get_ticks_usec()-configure_begin
	if not configured.ok: helper.dispose(); visual.dispose(); return {"ok":false,"error":configured.get("error","")}
	while not helper.stats().ready:
		var warm: Dictionary=helper.prewarm_step(rows.size())
		if not warm.ok: helper.dispose(); visual.dispose(); return {"ok":false,"error":warm.get("error","")}
		await physics_frame
	var stage_begin:=Time.get_ticks_usec(); var staged: Dictionary=helper.stage_material_snapshot(0,1); var stage_us:=Time.get_ticks_usec()-stage_begin
	if not staged.ok: helper.dispose(); visual.dispose(); return {"ok":false,"error":staged.get("error","")}
	var prepared_unique:=_unique_private_materials(helper)
	var commit_begin:=Time.get_ticks_usec(); var committed: Dictionary=helper.commit_material_snapshot(staged.stage_token); var commit_us:=Time.get_ticks_usec()-commit_begin
	var committed_unique:=_unique_private_materials(helper)
	var ok: bool=bool(committed.get("ok",false)) and int(staged.surfaces)==72 and prepared_unique==72 and committed_unique==72
	if expect_cache:
		ok=ok and staged.source_signature_reads==29 and staged.source_signature_cache_hits==43
		ok=ok and staged.source_graph_reads==29 and staged.source_graph_cache_hits==43
		ok=ok and committed.source_signature_reads==29 and committed.source_signature_cache_hits==43
	var result={"ok":ok,"assemblies":rows.size(),"surfaces":staged.surfaces,"private_prepared":prepared_unique,"private_committed":committed_unique,"configure_us":configure_us,"stage_us":stage_us,"commit_us":commit_us,"event_us":stage_us+commit_us}
	if expect_cache:
		result["stage_source_signature_reads"]=staged.source_signature_reads; result["stage_source_signature_hits"]=staged.source_signature_cache_hits
		result["stage_source_graph_reads"]=staged.source_graph_reads; result["stage_source_graph_hits"]=staged.source_graph_cache_hits
		result["commit_source_signature_reads"]=committed.source_signature_reads; result["commit_source_signature_hits"]=committed.source_signature_cache_hits
	helper.dispose(); visual.dispose()
	return result

func _setup_many(world: Node3D, count: int, shared_source: bool, label: String, snapshot_script: Script=Cached) -> Dictionary:
	var vehicle:=Node3D.new(); vehicle.name="Vehicle_"+label; world.add_child(vehicle)
	var assembly:=Node3D.new(); assembly.name="Assembly_"+label; vehicle.add_child(assembly)
	var shared:=_material(0)
	var sources: Array=[]
	for i in count:
		var node:=MeshInstance3D.new(); node.name="Part_"+str(i); assembly.add_child(node)
		var mesh:=ArrayMesh.new(); var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.1,0,0),Vector3(.1,0,0),Vector3(0,.2,0),Vector3(0,0,.2)])
		arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,1,3,1,2,3,2,0,3])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,shared if shared_source else _material(i+1))
		node.mesh=mesh; sources.append(node)
	var helper=snapshot_script.new()
	var configured: Dictionary=helper.configure(vehicle,world,[{"source":assembly,"mass_kg":18.0,"collision_layer":8,"collision_mask":1,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.05}],null,0,0)
	return {"ok":configured.get("ok",false),"error":configured.get("error",""),"helper":helper,"root":vehicle,"source":assembly,"sources":sources,"shared":shared}

func _material(seed: int) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(fposmod(.17+seed*.013,1.0),fposmod(.31+seed*.021,1.0),fposmod(.47+seed*.017,1.0),1)
	material.roughness=fposmod(.2+seed*.009,.75)+.1
	return material

func _private_materials(helper) -> Array:
	var result: Array=[]
	for entry: Dictionary in helper._entries:
		var stack: Array[Node]=[entry.template]
		while not stack.is_empty():
			var node: Node=stack.pop_back()
			if node is MeshInstance3D:
				for surface in node.mesh.get_surface_count(): result.append(node.get_active_material(surface))
			for child: Node in node.get_children(): stack.append(child)
	return result

func _unique_private_materials(helper) -> int:
	var ids: Dictionary={}
	for material: Material in _private_materials(helper): ids[material.get_instance_id()]=true
	return ids.size()

func _cost_summary(rows: Array) -> Dictionary:
	var events: Array=[]; var stages: Array=[]; var commits: Array=[]; var configures: Array=[]
	for row: Dictionary in rows:
		events.append(row.event_us); stages.append(row.stage_us); commits.append(row.commit_us); configures.append(row.configure_us)
	events.sort(); stages.sort(); commits.sort(); configures.sort()
	if events.is_empty(): return {"runs":0}
	return {"runs":rows.size(),"event_us":events,"stage_us":stages,"commit_us":commits,"configure_us":configures,"event_min_us":events[0],"event_median_us":events[events.size()/2],"event_max_us":events[-1]}

func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DEBRIS_MATERIAL_SNAPSHOT_CACHED ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"candidate exact source-identity phase-local cache; no HP/authority/main/GPU"}))
	quit(0 if failures.is_empty() else 1)
