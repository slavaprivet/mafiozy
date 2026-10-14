extends SceneTree
const Adapter=preload("res://scripts/transport/transport_vehicle_deformation.gd")
const ORACLE_PATH="res://data/transport/vehicle_deformation_cell_boundary_oracle.json"
const ORACLE_SHA="482a9a9ffef72c05cf9a4997b29c6853855f7fc07b55c2879d176507f0fdb5df"
const ADAPTER_SHA="74e5f0f2d1973674d497edfec89803b61270eed93d700d3527185b95339e7ddd"
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
	var bytes:=FileAccess.get_file_as_bytes(ORACLE_PATH); var oracle: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	check(_sha(bytes)==ORACLE_SHA,"pinned source boundary oracle")
	check(_sha(FileAccess.get_file_as_bytes("res://scripts/transport/transport_vehicle_deformation.gd"))==ADAPTER_SHA,"pinned parent adapter revision")
	if not oracle is Dictionary: finish({}); return
	var world:=Node3D.new(); root.add_child(world)
	var body:=RigidBody3D.new(); world.add_child(body); body.set_meta("vehicle_id","cell-cache-oracle"); body.set_meta("life_generation",1); body.set_meta("profile_id","cell_oracle")
	var visual:=TestVisual.new(); visual.root=Node3D.new(); visual.profile_id="cell_oracle"; visual.nodes={}; body.add_child(visual.root)
	var rows_by_label: Dictionary={}; var source_rows:=0
	for row: Dictionary in oracle.rows:
		if row.input_kind!="source_float32": continue
		var panel:=MeshInstance3D.new(); panel.name="Boundary_"+row.label; panel.set_meta("case_label",row.label); panel.mesh=_point_triangle(_vector(row.native_point)); visual.root.add_child(panel); visual.nodes[row.label]=panel; rows_by_label[row.label]=row; source_rows+=1
	var profile: Dictionary=oracle.profile.duplicate(true); profile.id="cell_oracle"
	var adapter:=Adapter.new(); check(adapter.configure(visual,body,{"vehicle_id":"cell-cache-oracle","life_generation":1},profile),"synthetic boundary adapter configured")
	var begin:=Time.get_ticks_usec(); var prepared:=adapter.prepare_step(source_rows); var prepare_us:=Time.get_ticks_usec()-begin
	check(prepared.ok and prepared.status=="READY" and prepared.prepared==source_rows,"all boundary rows prepared")
	var max_weight_error:=0.0; var visited: Dictionary={}
	for cached: Dictionary in adapter._rows:
		var label: String=cached.node.get_meta("case_label",""); check(rows_by_label.has(label),"cached row identity "+label)
		if not rows_by_label.has(label): continue
		visited[label]=true; var expected: Dictionary=rows_by_label[label]
		check(cached.surfaces.size()==1,"one cached surface "+label)
		var surface: Dictionary=cached.surfaces[0]
		check(surface.vertex_bindings==PackedInt32Array([0,0,0]),"deduplicated vertex binding "+label)
		check(_bytes_equal(surface.node_indices,expected.node_indices),"actual cached eight indices "+label)
		var weights:=_weights(expected.blend); max_weight_error=maxf(max_weight_error,_weight_error(surface.node_weights,weights))
		check(_weight_error(surface.node_weights,weights)<=1e-15,"actual cached Float64 weights "+label)
		var expected_mask: int=int(expected.mask_lo)|(int(expected.mask_hi)<<32)
		check(int(surface.mask)==expected_mask,"actual cached 45-bit mask "+label)
	check(visited.size()==source_rows and source_rows==108,"all Float32 native oracle cases introspected")
	# Keep one exact-boundary panel active. First apply a node inside its cached
	# cell, then change only a node outside its mask: the cached mask must skip it.
	var witness_label:="x_zero_z_neg_half_y_min"; var witness: MeshInstance3D=visual.nodes[witness_label]; var witness_expected: Dictionary=rows_by_label[witness_label]
	for panel: MeshInstance3D in visual.nodes.values(): panel.visible=panel==witness
	var witness_weights:=_weights(witness_expected.blend); var strongest:=0
	for i in range(1,witness_weights.size()):
		if witness_weights[i]>witness_weights[strongest]: strongest=i
	var included:=int(witness_expected.node_indices[strongest]); var occupied: Dictionary={}; var outside:=0
	for value in witness_expected.node_indices: occupied[int(value)]=true
	while occupied.has(outside): outside+=1
	var rest:=PackedVector3Array(); rest.resize(45); var positions:=rest.duplicate(); positions[included]=Vector3(.1,0,0)
	var first:=adapter.apply_snapshot({"vehicle_id":"cell-cache-oracle","life_generation":1,"profile_id":"cell_oracle","revision":0,"positions_native":positions,"rest_native":rest})
	check(first.ok and first.changed_meshes==1 and first.changed_nodes==[witness],"included cached node updates boundary mesh")
	positions=positions.duplicate(); positions[outside]=Vector3(.2,0,0)
	var second:=adapter.apply_snapshot({"vehicle_id":"cell-cache-oracle","life_generation":1,"profile_id":"cell_oracle","revision":1,"positions_native":positions,"rest_native":rest})
	check(second.ok and second.changed_meshes==0 and second.changed_nodes.is_empty(),"outside cached node causes no false positive")
	adapter.dispose(); visual.root.free(); body.free(); world.free()
	finish({"rows":source_rows,"prepare_us":prepare_us,"max_weight_error":max_weight_error,"witness":witness_label,"included_node":included,"outside_node":outside})
func _point_triangle(point: Vector3) -> ArrayMesh:
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([point,point,point])
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); mesh.surface_set_material(0,StandardMaterial3D.new()); return mesh
func _weights(blend_values: Array) -> PackedFloat64Array:
	var xt:=float(blend_values[0]); var yt:=float(blend_values[1]); var zt:=float(blend_values[2]); var result:=PackedFloat64Array()
	for z in 2:
		for y in 2:
			for x in 2: result.append((xt if x else 1.0-xt)*(yt if y else 1.0-yt)*(zt if z else 1.0-zt))
	return result
func _weight_error(actual: PackedFloat64Array,wanted: PackedFloat64Array) -> float:
	if actual.size()!=wanted.size(): return INF
	var result:=0.0
	for i in actual.size(): result=maxf(result,absf(actual[i]-wanted[i]))
	return result
func _bytes_equal(actual: PackedByteArray,wanted: Array) -> bool:
	if actual.size()!=wanted.size(): return false
	for i in actual.size():
		if actual[i]!=int(wanted[i]): return false
	return true
func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]),float(values[1]),float(values[2]))
func _sha(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes); return context.finish().hex_encode()
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_DEFORMATION_CELL_ADAPTER_CACHE ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"adapter_sha":ADAPTER_SHA,"oracle_sha":ORACLE_SHA,"scope":"prepared adapter cell indices/Float64 weights/mask introspection; no runtime edits"}))
	quit(0 if failures.is_empty() else 1)
