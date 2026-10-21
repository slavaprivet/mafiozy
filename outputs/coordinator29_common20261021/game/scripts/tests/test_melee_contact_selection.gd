extends SceneTree
## Unchanged executed JS selection/occlusion oracle plus adversarial caller lifetime.
## Query uses the independently accepted scalar kernel over every fixture triangle.
const Selection = preload("res://scripts/combat/melee_contact_selection.gd")
const Kernel = preload("res://scripts/combat/melee_triangle_contact.gd")
var checks := 0
var failures: Array[String] = []
var selector: RefCounted
var fixture: Dictionary
var ray_index := 0
var current_ids: Dictionary = {}
var mode := ""
var query_count := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func vec(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
func input_row(raw: Dictionary) -> Dictionary:
	var row := raw.duplicate(true)
	# JSON decodes numbers as float; this fixture's source IDs are integers.
	if row.get("excludeId") is float:row.excludeId=int(row.excludeId)
	for key in ["previous","current","from","to","origin"]:
		if row.get(key) is Array: row[key]=vec(row[key])
	if row.get("contacts") is Array:
		for index in row.contacts.size(): row.contacts[index]=input_row(row.contacts[index])
	return row
func actors() -> Array:
	var result: Array=[]
	for raw: Dictionary in fixture.actors:
		var actor := raw.duplicate(true)
		if actor.actor_id is float:actor.actor_id=int(actor.actor_id)
		actor.root_position=vec(raw.root_position)
		actor.receipt={"actor_id":actor.actor_id,"pose_revision":1,"life_generation":1}
		current_ids[actor.actor_id]=true
		var vertices := 0; var faces := 0
		for part: Dictionary in actor.parts:
			part.mesh_order=int(part.mesh_order)
			part.vertex_first=vertices;part.triangle_first=faces
			var points:=PackedVector3Array()
			for point: Array in part.world_vertices:points.append(vec(point))
			part.world_vertices=points;part.indices=PackedInt32Array(part.indices)
			part.head_slot_weights=PackedFloat32Array(part.head_slot_weights)
			vertices+=points.size();faces+=part.indices.size()/3
		result.append(actor)
	return result
func current(actor: Dictionary) -> bool:
	return current_ids.get(actor.actor_id,false)
func query(actor: Dictionary, request: Dictionary) -> Dictionary:
	query_count+=1
	if mode=="stale_winner" and query_count==2:current_ids[fixture.actors[0].actor_id]=false
	if mode=="stale_query":current_ids[actor.actor_id]=false
	if mode=="dispose_query":selector.dispose()
	if mode=="reentry":selector.select({},[])
	var rows:=PackedFloat64Array()
	for part: Dictionary in actor.parts:
		for face in part.indices.size()/3:
			for limb in request.contacts.size():
				var sweep: Dictionary=request.contacts[limb]
				var a: Vector3=part.world_vertices[part.indices[face*3]]
				var b: Vector3=part.world_vertices[part.indices[face*3+1]]
				var c: Vector3=part.world_vertices[part.indices[face*3+2]]
				var hit: Dictionary=Kernel.sample(sweep.from,sweep.to,sweep.radius,a,b,c)
				check(hit.get("valid",false),str(fixture.name)+": scalar geometry valid")
				if not hit.get("hit",false):continue
				rows.append_array(PackedFloat64Array([part.triangle_first+face,limb,hit.point.x,hit.point.y,hit.point.z,hit.line_point.x,hit.line_point.y,hit.line_point.z,hit.normal.x,hit.normal.y,hit.normal.z,hit.weights.x,hit.weights.y,hit.weights.z,hit.score,hit.distance_squared]))
	# Deliberately reverse page order: selector must restore source triangle/limb order.
	var shuffled:=PackedFloat64Array()
	for row in range(rows.size()/16-1,-1,-1):shuffled.append_array(rows.slice(row*16,row*16+16))
	return {"valid":true,"complete":mode!="incomplete","key":request.key,"receipt":request.receipt.duplicate(true),"rows":shuffled}
func occlusion(request: Dictionary) -> Dictionary:
	if request.phase=="begin":return {"valid":true,"token":"TEST_ONLY_blockers","blocker_count":int(fixture.blocker_count)}
	if mode=="stale_ray":
		current_ids[request.actor_id]=false
		return {"valid":true,"distance":null}
	if ray_index>=fixture.rays.size():
		check(false,str(fixture.name)+": unexpected ray")
		return {"valid":false}
	var expected: Dictionary=fixture.rays[ray_index];ray_index+=1
	check(request.from.distance_to(vec(expected.from))<0.000002,str(fixture.name)+": source ray origin/order")
	check(request.to.distance_to(vec(expected.to))<0.000002,str(fixture.name)+": source ray endpoint/order")
	return {"valid":true,"distance":expected.distance}
func execute(row: Dictionary, test_mode: String="") -> Dictionary:
	fixture=row;mode=test_mode;ray_index=0;query_count=0;current_ids.clear()
	selector=Selection.new()
	check(selector.configure(current,query,occlusion),str(row.name)+": binding")
	return selector.select(input_row(row.input),actors())
func run() -> void:
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/melee_contact_selection_oracle.json"))
	check(oracle.get("source_hash_normalization")=="crlf_to_lf","explicit source hash normalization")
	check(oracle.source_sha256==FileAccess.get_file_as_string("res://../../assets/maps/city_rebuild_v1/npc_melee_contact.mjs").replace("\r\n","\n").sha256_text(),"original source pin after CRLF to LF only")
	check(oracle.anchor_source_sha256==FileAccess.get_file_as_string("res://../../assets/maps/city_rebuild_v1/npc_contact_anchor.mjs").replace("\r\n","\n").sha256_text(),"original anchor helper pin after CRLF to LF only")
	for row: Dictionary in oracle.rows:
		var result:=execute(row)
		var label:=str(row.name)
		check(result.get("hit",false)==(row.expected!=null),label+": source hit/miss")
		check(ray_index==row.rays.size(),label+": exact source ray count")
		if row.expected==null:continue
		check(result.get("valid",false),label+": valid hit")
		if not result.get("hit",false):continue
		var contact: Dictionary=result.contact;var expected: Dictionary=row.expected
		for key in ["actor_id","mesh_id","zone","attack_type"]:check(contact.get(key)==expected[key],label+": "+key)
		check(contact.indices==PackedInt32Array(expected.face),label+": original face order")
		check(contact.point.distance_to(vec(expected.point))<0.000002,label+": source point")
		check(contact.normal.distance_to(vec(expected.normal))<0.000002,label+": source normal")
		check(absf(contact.distance-float(expected.distance))<0.000002,label+": source rank distance")
		var weights: Variant=contact.get("weights")
		check(weights is PackedFloat64Array and weights.size()==3,label+": anchor barycentric payload")
		if weights is PackedFloat64Array and weights.size()==3:
			for corner in 3:check(absf(weights[corner]-expected.weights[corner])<0.000002,label+": source anchor weight "+str(corner))
		check(contact.get("normal_side",0)==expected.normal_side,label+": source anchor normal side")
	var ordinary: Dictionary=oracle.rows[0]
	for test_mode in ["stale_query","stale_ray","incomplete","dispose_query","reentry"]:
		var result:=execute(ordinary,test_mode)
		check(not result.get("valid",false) and not result.get("hit",false),test_mode+": fails closed")
	var tie: Dictionary=oracle.rows[2]
	var stale:=execute(tie,"stale_winner")
	check(not stale.get("valid",false) and not stale.get("hit",false),"earlier winner invalidated by later actor cannot escape")
	var report:={"checks":checks,"failures":failures,"passed":failures.is_empty(),"oracle_cases":oracle.rows.size(),"selector_sha":FileAccess.get_sha256("res://scripts/combat/melee_contact_selection.gd"),"scope":"Executed original JS source selection/occlusion plus callback lifetime; CPU only, no live actor/HP/native loading"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../../outputs/coordinator22_contact_selection"))
	FileAccess.open("res://../../outputs/coordinator22_contact_selection/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MELEE_CONTACT_SELECTION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
