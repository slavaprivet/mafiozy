extends SceneTree
const Cache=preload("res://scripts/transport/transport_deformation_blueprint_cache.gd")
const Subdivision=preload("res://scripts/transport/transport_mesh_subdivision.gd")
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Solver=preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const SOURCE_SHA="cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44"
class TestVisual extends RefCounted:
	var root: Node3D
	var profile_id: String
	var nodes: Dictionary
var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new(); root.add_child(world)
	var cache:=Cache.new(); var mesh:=_mesh(); var profile={"id":"cache-fixture","halfWidth":1.0,"halfLength":2.0,"height":1.5}
	var provenance={"source_sha256":SOURCE_SHA,"visual_manifest_sha256":Solver.VISUAL_MANIFEST_SHA256,"asset_generation":"cache-fixture-v1"}
	var one:=_visual(world,"one",mesh,profile.id); var built:=cache.acquire(one.visual,one.body,profile,provenance)
	check(built.ok and built.status=="BUILT" and built.candidate_meshes==1 and built.profile==profile and built.provenance==provenance,"first instance builds identity-bound blueprint receipt")
	var direct:=Subdivision.subdivide(mesh,.15,9000)
	_check_mesh_equal(built.rows[0].prepared,direct.mesh,"cached subdivision equals exact helper")
	var indices: PackedByteArray=built.rows[0].surfaces[0].node_indices
	var weights: PackedFloat64Array=built.rows[0].surfaces[0].node_weights
	var bindings: PackedInt32Array=built.rows[0].surfaces[0].vertex_bindings; var base: PackedVector3Array=built.rows[0].surfaces[0].base; var boundary_binding:=-1
	for i in base.size():
		if absf(base[i].x)<.0000001 and absf(base[i].z)<.0000001: boundary_binding=bindings[i]; break
	var boundary_at:=boundary_binding*8
	check(boundary_binding>=0 and indices[boundary_at]%3==0 and int(indices[boundary_at]/9)==1 and weights[boundary_at]<.0000001 and weights[boundary_at+5]>.0,"internal x/z boundary keeps source left cell blend one")
	var two:=_visual(world,"two",mesh,profile.id); var hit:=cache.acquire(two.visual,two.body,profile,provenance)
	check(hit.ok and hit.status=="HIT" and hit.rows[0].prepared!=built.rows[0].prepared,"second instance gets unique ArrayMesh")
	var first_base: PackedVector3Array=built.rows[0].surfaces[0].base; var second_before: Vector3=hit.rows[0].surfaces[0].base[0]
	first_base[0]+=Vector3(9,8,7)
	var first_weights: PackedFloat64Array=built.rows[0].surfaces[0].node_weights; var second_weight: float=hit.rows[0].surfaces[0].node_weights[0]; first_weights[0]=123.0
	check(hit.rows[0].surfaces[0].base[0]==second_before and hit.rows[0].surfaces[0].node_weights[0]==second_weight,"mutable base/support arrays are not shared")
	var third:=cache.acquire(two.visual,two.body,profile,provenance)
	check(third.ok and third.rows[0].surfaces[0].base[0]==second_before and third.rows[0].prepared!=hit.rows[0].prepared,"cache snapshot stays immutable across acquisitions")
	var changed_profile:=profile.duplicate(true); changed_profile.halfWidth=1.01
	check(cache.acquire(two.visual,two.body,changed_profile,provenance).get("error")=="cache_collision","same identity with changed profile fails closed")
	var changed_provenance:=provenance.duplicate(true); changed_provenance.asset_generation="cache-fixture-v2"
	check(cache.acquire(two.visual,two.body,profile,changed_provenance).get("error")=="provenance_changed","bound instance cannot switch provenance generation")
	two.panel.transform.origin.x=.01
	check(cache.acquire(two.visual,two.body,profile,provenance).get("error")=="assembly_frame_changed","local frame mutation fails closed")
	two.panel.transform=Transform3D.IDENTITY; two.panel.mesh=mesh.duplicate()
	check(cache.acquire(two.visual,two.body,profile,provenance).get("error")=="mesh_replaced","identical-content replacement fails closed")
	two.panel.mesh=mesh; _limit_tests(world,mesh,profile,provenance)
	_shift_first_position(mesh,Vector3(.001,0,0))
	check(cache.acquire(two.visual,two.body,profile,provenance).get("error")=="geometry_changed","in-place source mesh mutation fails closed")
	one.body.free(); two.body.free()
	var actual:=_actual(world)
	check(actual.get("ok",false),"actual compact_sedan first/second cache "+str(actual.get("error","")))
	check(cache.stats().blueprint_payload_bytes_estimate>0,"blueprint payload memory estimated")
	cache.dispose(); world.free()
	print("TRANSPORT_DEFORMATION_BLUEPRINT_CACHE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"actual_glb":actual,"cache":cache.stats(),"scope":"immutable deformation preparation data only; no mesh adoption/impact/HP/event authority"}))
	quit(0 if failures.is_empty() else 1)

func _actual(world: Node3D) -> Dictionary:
	var damage:=Bindings.load_oracle(); if damage.is_empty(): return {"ok":false,"error":"damage_oracle"}
	var damage_row: Dictionary={}
	for row: Dictionary in damage.rows:
		if row.profile_id=="compact_sedan": damage_row=row; break
	if damage_row.is_empty(): return {"ok":false,"error":"profile"}
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var first_loaded:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	var second_loaded:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	if not first_loaded.ok or not second_loaded.ok: return {"ok":false,"error":"visual"}
	var first_visual=first_loaded.visual; var second_visual=second_loaded.visual
	var bound:=Bindings.bind(first_visual,damage_row); if not bound.ok: return bound
	var profile: Dictionary=bound.crash_profile_source
	var first_body:=Node3D.new(); var second_body:=Node3D.new(); world.add_child(first_body); world.add_child(second_body); second_body.position=Vector3(20,0,-7)
	first_body.add_child(first_visual.root); second_body.add_child(second_visual.root)
	var provenance={"source_sha256":SOURCE_SHA,"visual_manifest_sha256":Solver.VISUAL_MANIFEST_SHA256,"asset_generation":str(catalogue.get("sha256",Solver.VISUAL_MANIFEST_SHA256))}
	var cache:=Cache.new(); var begin:=Time.get_ticks_usec(); var first:=cache.acquire(first_visual,first_body,profile,provenance); var first_us:=Time.get_ticks_usec()-begin
	if not first.ok: return first
	begin=Time.get_ticks_usec(); var second:=cache.acquire(second_visual,second_body,profile,provenance); var second_us:=Time.get_ticks_usec()-begin
	if not second.ok: return second
	if first.status!="BUILT" or second.status!="HIT" or first.rows.size()!=second.rows.size(): return {"ok":false,"error":"reuse"}
	var output_vertices:=0
	for i in first.rows.size():
		if first.rows[i].prepared==second.rows[i].prepared: return {"ok":false,"error":"shared_mesh"}
		for surface in second.rows[i].prepared.get_surface_count(): output_vertices+=(second.rows[i].prepared.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var result={"ok":true,"candidate_meshes":first.rows.size(),"output_vertices":output_vertices,"first_prepare_us":first_us,"second_prepare_us":second_us,"blueprint_payload_bytes_estimate":first.blueprint_payload_bytes_estimate,"speedup":float(first_us)/maxf(1.0,float(second_us))}
	cache.dispose(); first_visual.dispose(); second_visual.dispose(); first_body.free(); second_body.free(); return result

func _visual(world: Node3D,label: String,mesh: ArrayMesh,profile_id: String) -> Dictionary:
	var body:=Node3D.new(); body.name=label; world.add_child(body)
	var visual:=TestVisual.new(); visual.root=Node3D.new(); visual.profile_id=profile_id; body.add_child(visual.root)
	var panel:=MeshInstance3D.new(); panel.mesh=mesh; visual.root.add_child(panel); visual.nodes={"panel":panel}
	return {"body":body,"visual":visual,"panel":panel}

func _limit_tests(world: Node3D,mesh: ArrayMesh,profile: Dictionary,provenance: Dictionary) -> void:
	var budget:=Cache.new(); check(budget.configure_limits(4,1,8),"custom payload limit accepted")
	var budget_visual:=_visual(world,"budget",mesh,profile.id)
	check(budget.acquire(budget_visual.visual,budget_visual.body,profile,provenance).get("error")=="payload_budget","payload budget fails closed")
	check(budget.stats().entries==0 and budget.stats().instance_bindings==0,"failed payload admission retains nothing")
	budget_visual.body.free(); budget.dispose()
	var bindings_limit:=Cache.new(); check(bindings_limit.configure_limits(4,16*1024*1024,1),"custom binding limit accepted")
	var many_body:=Node3D.new(); world.add_child(many_body); var many_visual:=TestVisual.new(); many_visual.root=Node3D.new(); many_visual.profile_id=profile.id; many_body.add_child(many_visual.root); many_visual.nodes={}
	for i in 2:
		var panel:=MeshInstance3D.new(); panel.mesh=mesh; many_visual.root.add_child(panel); many_visual.nodes["panel_"+str(i)]=panel
	check(bindings_limit.acquire(many_visual,many_body,profile,provenance).get("error")=="instance_binding_limit","instance binding cap fails closed")
	check(bindings_limit.stats().entries==0 and bindings_limit.stats().instance_bindings==0,"failed binding validation retains no entry or partial bindings")
	many_body.free(); bindings_limit.dispose()
	var dead:=Cache.new(); check(dead.configure_limits(2,16*1024*1024,1),"dead-binding fixture limits accepted")
	var dead_one:=_visual(world,"dead_one",mesh,profile.id); check(dead.acquire(dead_one.visual,dead_one.body,profile,provenance).ok,"first binding admitted")
	dead_one.body.free()
	var dead_two:=_visual(world,"dead_two",mesh,profile.id); check(dead.acquire(dead_two.visual,dead_two.body,profile,provenance).ok,"dead weak binding pruned before replacement instance")
	check(dead.stats().instance_bindings==1,"dead binding pruning preserves explicit cap")
	dead_two.body.free(); dead.dispose()
	var entries:=Cache.new(); check(entries.configure_limits(1,16*1024*1024,8),"entry-limit fixture configured")
	var entry_one:=_visual(world,"entry_one",mesh,profile.id); check(entries.acquire(entry_one.visual,entry_one.body,profile,provenance).ok,"first cache entry admitted")
	var profile_two:=profile.duplicate(true); profile_two.id="cache-fixture-second"; var provenance_two:=provenance.duplicate(true); provenance_two.asset_generation="cache-fixture-second"
	var entry_two:=_visual(world,"entry_two",mesh,profile_two.id)
	check(entries.acquire(entry_two.visual,entry_two.body,profile_two,provenance_two).get("error")=="entry_limit","entry cap rejects without eviction")
	check(entries.stats().entries==1,"entry cap preserves admitted blueprint")
	check(not entries.configure_limits(2,32*1024*1024,16),"limits lock after first admission attempt")
	entry_one.body.free(); entry_two.body.free(); entries.dispose()

func _mesh() -> ArrayMesh:
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(0,.6,0),Vector3(.08,.6,0),Vector3(0,.68,0)])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.UP])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2])
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); mesh.surface_set_material(0,StandardMaterial3D.new()); mesh.surface_set_name(0,"fixture")
	return mesh

func _shift_first_position(mesh: ArrayMesh,delta: Vector3) -> void:
	var arrays: Array=mesh.surface_get_arrays(0); var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; vertices[0]+=delta; arrays[Mesh.ARRAY_VERTEX]=vertices
	var material:=mesh.surface_get_material(0); var name:=mesh.surface_get_name(0); mesh.clear_surfaces(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); mesh.surface_set_material(0,material); mesh.surface_set_name(0,name)

func _check_mesh_equal(a: ArrayMesh,b: ArrayMesh,label: String) -> void:
	check(a.get_surface_count()==b.get_surface_count(),label+" surfaces")
	for surface in mini(a.get_surface_count(),b.get_surface_count()):
		var aa:=a.surface_get_arrays(surface); var bb:=b.surface_get_arrays(surface)
		for slot in Mesh.ARRAY_MAX:
			var av: Variant=aa[slot]; var bv: Variant=bb[slot]
			check(typeof(av)==typeof(bv),label+" slot type "+str(slot))
			if av is PackedVector3Array:
				check(av.size()==bv.size(),label+" vec3 size")
				for i in mini(av.size(),bv.size()): check(av[i].is_equal_approx(bv[i]),label+" vec3 value")
			elif av is PackedVector2Array:
				check(av.size()==bv.size(),label+" vec2 size")
				for i in mini(av.size(),bv.size()): check(av[i].is_equal_approx(bv[i]),label+" vec2 value")
			elif av is PackedInt32Array or av is PackedFloat32Array or av is PackedColorArray:
				check(av==bv,label+" packed value")
