extends SceneTree
const Adapter=preload("res://scripts/transport/transport_vehicle_deformation.gd")
const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Solver=preload("res://scripts/vehicle_physics/vehicle_crash_solver.gd")
const ORACLE_PATH="res://data/transport/vehicle_deformation_oracle.json"
const ORACLE_SHA="ccd5b46084439ca3aaa12c7d23b94cfdc9b979bd81eed0edd80ac7a9fc7f69e7"
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
	var bytes:=FileAccess.get_file_as_bytes(ORACLE_PATH)
	check(_sha(bytes)==ORACLE_SHA,"pinned actual-source oracle bytes")
	var oracle: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	if not oracle is Dictionary:
		print("TRANSPORT_VEHICLE_DEFORMATION fixture parse failed"); quit(1); return
	check(oracle.schema=="mafiozi.transport-vehicle-deformation-oracle.v1" and oracle.source.vehicle_crash.sha256=="cceffb5b6e65a1d180e8860d471351bf04340439ad605a66d6143daf53b20e44","source receipt")
	var world:=Node3D.new(); root.add_child(world)
	var body:=RigidBody3D.new(); world.add_child(body); body.set_meta("vehicle_id","oracle-vehicle-1"); body.set_meta("life_generation",1); body.set_meta("profile_id",oracle.profile.id)
	var visual:=TestVisual.new(); visual.root=Node3D.new(); visual.root.transform=Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO); visual.profile_id=oracle.profile.id; body.add_child(visual.root)
	var panel:=MeshInstance3D.new(); panel.mesh=_input_mesh(oracle.input); var authored_mesh:=panel.mesh; panel.transform=_transform(oracle.input.mesh_transform); visual.root.add_child(panel); visual.nodes={"panel":panel}
	var adapter:=Adapter.new(); check(adapter.configure(visual,body,{"vehicle_id":"oracle-vehicle-1","life_generation":1},oracle.profile),"synthetic configure")
	var prep_started:=Time.get_ticks_usec(); var prep: Dictionary={}
	while prep.get("status")!="READY": prep=adapter.prepare_step(1)
	var synthetic_prepare_us:=Time.get_ticks_usec()-prep_started
	check(prep.ok and prep.prepared==1,"prepared outside impact")
	var snapshot:=_snapshot(oracle.snapshot)
	var tiny:=snapshot.duplicate(true); tiny.revision=0; tiny.positions_native=tiny.rest_native.duplicate(); tiny.positions_native[40]+=Vector3(.0005,0,0)
	check(adapter.apply_snapshot(tiny).get("changed_meshes")==0 and panel.mesh==authored_mesh,"source reachesMesh threshold keeps original mesh")
	var apply_started:=Time.get_ticks_usec(); var applied: Dictionary=adapter.apply_snapshot(snapshot); var synthetic_apply_us:=Time.get_ticks_usec()-apply_started
	check(applied.ok and applied.changed_meshes==1 and applied.revision==1 and applied.changed_nodes==[panel],"source snapshot applied and dirty node exposed")
	_check_expected(panel.mesh,oracle.expected,"actual source deformation")
	var first_mesh:=panel.mesh
	var wrong_identity:=snapshot.duplicate(true); wrong_identity.vehicle_id="wrong"
	check(adapter.apply_snapshot(wrong_identity).get("error")=="identity","snapshot identity rejected")
	var stale:=snapshot.duplicate(true); stale.revision=0
	check(adapter.apply_snapshot(stale).get("error")=="stale_revision","stale snapshot rejected")
	var same_revision:=adapter.apply_snapshot(snapshot)
	check(same_revision.get("changed_meshes")==0 and panel.mesh==first_mesh,"same revision idempotent "+str(same_revision))
	var hidden:=snapshot.duplicate(true); hidden.revision=2; hidden.positions_native[0]+=Vector3(.02,0,0); panel.visible=false
	check(adapter.apply_snapshot(hidden).get("changed_meshes")==0,"hidden subtree skipped")
	panel.visible=true; check(adapter.apply_snapshot(hidden).get("changed_meshes")==0,"same revision visible later stays skipped like source")
	var root_hidden:=hidden.duplicate(true); root_hidden.revision=3; root_hidden.positions_native[40]+=Vector3(.01,0,0); visual.root.visible=false
	check(adapter.apply_snapshot(root_hidden).get("changed_meshes")==1,"vehicle root visibility excluded like source")
	visual.root.visible=true
	var dent_before:=_vertices(panel.mesh,0); var dented:=dent_before.duplicate(); dented[0]+=Vector3(.013,-.007,.009); _replace_positions(panel.mesh,0,dented)
	var dent_snapshot:=root_hidden.duplicate(true); dent_snapshot.revision=4
	var dent_result:=adapter.apply_snapshot(dent_snapshot); var dent_after:=_vertices(panel.mesh,0)
	check(dent_result.ok and dent_result.changed_meshes==1 and dent_after[0].distance_to(dented[0])<.000002,"in-place bullet dent preserved as source base=current-offset")
	check(adapter.notify_positions_changed(panel),"explicit position version notification")
	var notified:=dent_snapshot.duplicate(true); notified.revision=5
	check(adapter.apply_snapshot(notified).get("changed_meshes")==1,"explicit same-value position version rebuild")
	var stable_transform:=panel.transform; panel.transform.origin.x+=.1; var bad_frame:=notified.duplicate(true); bad_frame.revision=6
	check(adapter.apply_snapshot(bad_frame).get("error")=="assembly_frame_changed","stale visible assembly frame rejected")
	panel.visible=false; check(adapter.apply_snapshot(bad_frame).ok,"hidden changed frame skipped like source"); panel.transform=stable_transform; panel.visible=true
	var nonfinite:=bad_frame.duplicate(true); nonfinite.revision=7; nonfinite.positions_native[0]=Vector3(NAN,0,0)
	check(adapter.apply_snapshot(nonfinite).get("error")=="nonfinite_cage","nonfinite cage rejected")
	adapter.reset(); check(panel.mesh!=first_mesh and panel.mesh==authored_mesh,"reset restores authored mesh")
	adapter.dispose(); visual.root.free(); body.free()
	var actual:=_actual_glb(world)
	check(actual.ok,"actual compact_sedan GLB prepare/apply "+str(actual.get("error","")))
	world.free()
	print("TRANSPORT_VEHICLE_DEFORMATION ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"synthetic_prepare_us":synthetic_prepare_us,"synthetic_apply_us":synthetic_apply_us,"actual_glb":actual,"source":oracle.source,"scope":"presentation mesh deformation only; no impact/HP/body/debris authority; headless CPU"}))
	quit(0 if failures.is_empty() else 1)

func _actual_glb(world: Node3D) -> Dictionary:
	var damage:=Bindings.load_oracle(); if damage.is_empty(): return {"ok":false,"error":"damage_oracle"}
	var row: Dictionary={}
	for value: Dictionary in damage.rows:
		if value.profile_id=="compact_sedan": row=value; break
	var catalog:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json"); var loaded:=Visual.instantiate_visual(catalog.entries.compact_sedan,catalog.base_path)
	if not loaded.ok: return loaded
	var visual=loaded.visual; var body:=RigidBody3D.new(); world.add_child(body); body.set_meta("vehicle_id","actual-glb-1"); body.set_meta("life_generation",1); body.set_meta("profile_id","compact_sedan"); body.add_child(visual.root)
	var bound:=Bindings.bind(visual,row); if not bound.ok: return bound
	var solver:=Solver.new(); if not solver.configure("actual-glb-1",1,"compact_sedan",Solver.VISUAL_MANIFEST_SHA256,bound.crash_profile_source): return {"ok":false,"error":"solver"}
	var adapter:=Adapter.new(); if not adapter.configure(visual,body,{"vehicle_id":"actual-glb-1","life_generation":1},bound.crash_profile_source): return {"ok":false,"error":"adapter"}
	var begin:=Time.get_ticks_usec(); var prepare: Dictionary={}; var max_prepare_step_us:=0
	while prepare.get("status")!="READY":
		var step_begin:=Time.get_ticks_usec()
		prepare=adapter.prepare_step(1)
		max_prepare_step_us=maxi(max_prepare_step_us,Time.get_ticks_usec()-step_begin)
		if not prepare.ok: return prepare
	var prepare_us:=Time.get_ticks_usec()-begin
	var resting:=adapter.apply_snapshot(solver.deformation_snapshot_native()); if not resting.ok or resting.changed_meshes!=0: return {"ok":false,"error":"rest"}
	var hit:=solver.apply_impact_native({"vehicle_id":"actual-glb-1","life_generation":1,"physics_tick":1,"impact_sequence":1,"event_id":"actual-glb-hit","point_native_m":Vector3(-.08,.76,-2.18),"normal_native":Vector3(0,0,-1),"impact_speed_mps":14.0})
	if not hit.applied: return {"ok":false,"error":"impact"}
	begin=Time.get_ticks_usec(); var applied:=adapter.apply_snapshot(solver.deformation_snapshot_native()); var apply_us:=Time.get_ticks_usec()-begin
	if not applied.ok or applied.changed_meshes<1: return {"ok":false,"error":"apply"}
	var vertices:=0
	for node: MeshInstance3D in applied.changed_nodes:
		for surface in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface); vertices+=arrays[Mesh.ARRAY_VERTEX].size()
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				if not vertex.is_finite(): return {"ok":false,"error":"nonfinite_output"}
	var result={"ok":true,"candidate_meshes":int(prepare.total),"changed_meshes":int(applied.changed_meshes),"changed_vertices":vertices,"prepare_us":prepare_us,"max_prepare_step_us":max_prepare_step_us,"apply_us":apply_us}
	adapter.dispose(); visual.dispose(); body.free(); return result

func _input_mesh(input: Dictionary) -> ArrayMesh:
	var mesh:=ArrayMesh.new(); var source_indices: Array=input.indices
	for group: Dictionary in input.groups:
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
		for name: String in input.attributes: arrays[_slot(name)]=_packed(name,input.attributes[name].values)
		var indices:=PackedInt32Array(); for i in range(int(group.start),int(group.start)+int(group.count)): indices.append(int(source_indices[i]))
		arrays[Mesh.ARRAY_INDEX]=indices; mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,StandardMaterial3D.new()); mesh.surface_set_name(mesh.get_surface_count()-1,"oracle_"+str(group.material_index))
	return mesh
func _check_expected(mesh: ArrayMesh,expected: Dictionary,label: String) -> void:
	check(mesh.get_surface_count()==expected.groups.size(),label+" groups")
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface); var group: Dictionary=expected.groups[surface]
		check(arrays[Mesh.ARRAY_VERTEX].size()==group.count,label+" vertex count")
		for name: String in expected.attributes:
			var wanted: Array=expected.attributes[name].values.slice(int(group.start)*int(expected.attributes[name].item_size),(int(group.start)+int(group.count))*int(expected.attributes[name].item_size))
			var got:=_flat(arrays[_slot(name)],_slot(name)); check(got.size()==wanted.size(),label+" "+name+" size")
			var tolerance:=.00005 if name in ["normal","tangent"] else (2.0/255.0+.000001 if name=="color" else .000003)
			for i in mini(got.size(),wanted.size()):
				checks+=1
				if absf(float(got[i])-float(wanted[i]))>tolerance: failures.append(label+" "+name+"["+str(i)+"]"); break
	var bounds:=mesh.get_aabb(); check(bounds.position.distance_to(_v3(expected.bounding_box.min))<.00001 and bounds.end.distance_to(_v3(expected.bounding_box.max))<.00001,label+" bounds")
func _snapshot(row: Dictionary) -> Dictionary:
	var out:=row.duplicate(true); out.life_generation=int(row.life_generation); out.revision=int(row.revision); out.positions_native=PackedVector3Array(); out.rest_native=PackedVector3Array()
	for v: Array in row.positions_native: out.positions_native.append(_v3(v))
	for v: Array in row.rest_native: out.rest_native.append(_v3(v))
	return out
func _replace_positions(mesh: ArrayMesh,surface_index: int,vertices: PackedVector3Array) -> void:
	var rows: Array=[]
	for i in mesh.get_surface_count(): rows.append({"arrays":mesh.surface_get_arrays(i),"material":mesh.surface_get_material(i),"name":mesh.surface_get_name(i)})
	rows[surface_index].arrays[Mesh.ARRAY_VERTEX]=vertices; mesh.clear_surfaces()
	for row: Dictionary in rows:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,row.arrays); var at:=mesh.get_surface_count()-1; mesh.surface_set_material(at,row.material); mesh.surface_set_name(at,row.name)
func _vertices(mesh: ArrayMesh,surface: int) -> PackedVector3Array: return mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
func _transform(row: Dictionary) -> Transform3D: return Transform3D(Basis(Quaternion(float(row.quaternion[0]),float(row.quaternion[1]),float(row.quaternion[2]),float(row.quaternion[3]))).scaled_local(_v3(row.scale)),_v3(row.position))
func _slot(name: String) -> int: return {"position":Mesh.ARRAY_VERTEX,"normal":Mesh.ARRAY_NORMAL,"tangent":Mesh.ARRAY_TANGENT,"color":Mesh.ARRAY_COLOR,"uv":Mesh.ARRAY_TEX_UV}[name]
func _packed(name: String,values: Array) -> Variant:
	if name in ["position","normal"]:
		var out:=PackedVector3Array()
		for i in range(0,values.size(),3): out.append(Vector3(float(values[i]),float(values[i+1]),float(values[i+2])))
		return out
	if name=="tangent":
		var out:=PackedFloat32Array()
		for v in values: out.append(float(v))
		return out
	if name=="color":
		var out:=PackedColorArray()
		for i in range(0,values.size(),4): out.append(Color(float(values[i]),float(values[i+1]),float(values[i+2]),float(values[i+3])))
		return out
	var out:=PackedVector2Array()
	for i in range(0,values.size(),2): out.append(Vector2(float(values[i]),float(values[i+1])))
	return out
func _flat(value: Variant,slot: int) -> Array:
	var out: Array=[]
	if slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL]: for v: Vector3 in value: out.append_array([v.x,v.y,v.z])
	elif slot==Mesh.ARRAY_TANGENT: for v in value: out.append(v)
	elif slot==Mesh.ARRAY_COLOR: for v: Color in value: out.append_array([v.r,v.g,v.b,v.a])
	else: for v: Vector2 in value: out.append_array([v.x,v.y])
	return out
func _v3(v: Array) -> Vector3: return Vector3(float(v[0]),float(v[1]),float(v[2]))
func _sha(bytes: PackedByteArray) -> String:
	var h:=HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes); return h.finish().hex_encode()
