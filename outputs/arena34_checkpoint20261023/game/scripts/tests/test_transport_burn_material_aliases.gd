extends SceneTree

const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const MANIFEST_PATH="res://assets/vehicle_visual/manifest.json"
const MANIFEST_SHA="38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03"
const VISUAL_SHA="d586952de302b7ec0467b89b91ba117e3350e8a5c217f48c303f06ff88494e34"
const PROFILE_IDS:=["city_hatchback","compact_sedan","family_wagon","executive_sedan","sport_coupe","city_suv","delivery_van","utility_pickup","city_bus","police_interceptor","city_ambulance","fire_engine","city_taxi"]
const EXPECTED_RAW:={"city_hatchback":[270,57],"compact_sedan":[267,57],"family_wagon":[267,57],"executive_sedan":[272,57],"sport_coupe":[221,58],"city_suv":[273,57],"delivery_van":[227,57],"utility_pickup":[221,58],"city_bus":[233,59],"police_interceptor":[272,60],"city_ambulance":[234,60],"fire_engine":[250,61],"city_taxi":[276,59]}

var checks:=0
var failures: Array[String]=[]
var world: Node3D
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: run.call_deferred()

func run() -> void:
	check(FileAccess.get_sha256(MANIFEST_PATH)==MANIFEST_SHA,"pinned 13-profile native manifest")
	check(FileAccess.get_sha256("res://scripts/vehicle_visual/vehicle_visual.gd")==VISUAL_SHA,"pinned visual private-resource loader")
	var catalogue:=Visual.load_catalogue(MANIFEST_PATH)
	check(catalogue.ok and catalogue.entries.size()==13,"exact thirteen-entry catalogue")
	check(_sorted_keys(catalogue.entries)==_sorted_strings(PROFILE_IDS),"catalogue profile set exact")
	world=Node3D.new(); get_root().add_child(world)
	var reports: Array=[]; var total_begin:=Time.get_ticks_usec()
	for profile_id in PROFILE_IDS:
		var begin:=Time.get_ticks_usec(); var loaded:=Visual.instantiate_visual(catalogue.entries[profile_id],catalogue.base_path); var elapsed:=Time.get_ticks_usec()-begin
		check(loaded.ok,"instantiate actual "+profile_id)
		if not loaded.ok: continue
		var visual=loaded.visual; world.add_child(visual.root)
		var census:=_census(visual,catalogue.entries[profile_id])
		check(census.ok,"material identity census "+profile_id+":"+str(census.get("error","")))
		if census.ok:
			check(census.profile_id==profile_id,"profile metadata "+profile_id)
			check(census.surfaces>=census.unique_source_material_ids and census.unique_source_material_ids>0,"bounded alias counts "+profile_id)
			check(census.raw_manifest_slots==EXPECTED_RAW[profile_id][0] and census.raw_manifest_source_material_ids==EXPECTED_RAW[profile_id][1],"exact raw manifest table "+profile_id)
			check(census.surfaces+census.missing_native_slots.size()==census.raw_manifest_slots,"native plus explicitly missing covers raw slots "+profile_id)
			reports.append({"profile_id":profile_id,"instantiate_us":elapsed,"mesh_nodes":census.mesh_nodes,"raw_manifest_slots":census.raw_manifest_slots,"raw_manifest_source_material_ids":census.raw_manifest_source_material_ids,"surface_slots":census.surfaces,"unique_source_material_ids":census.unique_source_material_ids,"alias_slots":census.surfaces-census.unique_source_material_ids,"missing_native_slots":census.missing_native_slots,"source_material_ids":census.source_material_ids})
		visual.dispose()
	var total_elapsed:=Time.get_ticks_usec()-total_begin
	check(reports.size()==13,"all profile census rows")
	var cross:=_two_compact_instances(catalogue)
	check(cross.ok,"two compact instances load")
	if cross.ok:
		check(cross.first_ids==cross.second_ids and cross.first_ids.size()==cross.unique_ids,"compact source ID sets match")
		check(cross.shared_resources==0,"two compact instances share no StandardMaterial resource")
	_lifecycle_receipt(catalogue)
	finish({"profiles":reports,"profile_count":reports.size(),"total_load_only_us":total_elapsed,"compact_two_instance":cross,"limitations":["Native GLTF surfaces do not prove original Three scalar versus one-element material-array identity","No burn preset, material mutation, rendering, GPU, FPS or authority is exercised"]})

func _census(visual: Variant,record: Dictionary) -> Dictionary:
	if visual==null or not is_instance_valid(visual.root) or visual.root.is_queued_for_deletion(): return {"ok":false,"error":"lifecycle"}
	if visual.profile_id!=record.get("profile_id") or not record.get("mesh_materials") is Dictionary: return {"ok":false,"error":"profile"}
	var by_source_id: Dictionary={}; var by_resource_id: Dictionary={}; var metadata_by_source: Dictionary={}; var surfaces:=0; var mesh_nodes:=0
	var native_mesh_keys: Dictionary={}
	for key: String in visual.nodes:
		var node: Node=visual.nodes[key]
		if not node is MeshInstance3D: continue
		native_mesh_keys[key]=true
		mesh_nodes+=1
		var expected_rows: Variant=record.mesh_materials.get(key)
		if not expected_rows is Array or expected_rows.size()!=1 or not expected_rows[0] is Dictionary: return {"ok":false,"error":"manifest_slot:"+key}
		var expected: Dictionary=expected_rows[0]; var source_id:=String(expected.get("source_material_id","")); var expected_metadata: Variant=expected.get("source_metadata")
		if source_id.is_empty() or not expected_metadata is Dictionary: return {"ok":false,"error":"manifest_identity:"+key}
		var mesh_instance:=node as MeshInstance3D
		if mesh_instance.mesh==null or mesh_instance.mesh.get_surface_count()<1: return {"ok":false,"error":"surface:"+key}
		for surface in mesh_instance.mesh.get_surface_count():
			surfaces+=1; var material:=mesh_instance.get_active_material(surface)
			if not material is StandardMaterial3D: return {"ok":false,"error":"material_type:"+key}
			var native_id:=String(material.get_meta("source_material_id",String()))
			var native_metadata: Variant=material.get_meta("source_metadata",null)
			if native_id!=source_id or not native_metadata is Dictionary or native_metadata!=expected_metadata: return {"ok":false,"error":"metadata:"+key}
			var object_id:=material.get_instance_id()
			if by_source_id.has(source_id) and by_source_id[source_id]!=object_id: return {"ok":false,"error":"alias_split:"+source_id}
			if by_resource_id.has(object_id) and by_resource_id[object_id]!=source_id: return {"ok":false,"error":"identity_alias:"+source_id}
			if metadata_by_source.has(source_id) and metadata_by_source[source_id]!=native_metadata: return {"ok":false,"error":"metadata_alias:"+source_id}
			by_source_id[source_id]=object_id; by_resource_id[object_id]=source_id; metadata_by_source[source_id]=native_metadata
	var raw_ids: Dictionary={}; var missing: Array=[]
	for raw_key: String in record.mesh_materials:
		var raw_rows: Variant=record.mesh_materials[raw_key]
		if not raw_rows is Array or raw_rows.size()!=1 or not raw_rows[0] is Dictionary: return {"ok":false,"error":"raw_manifest:"+raw_key}
		var raw: Dictionary=raw_rows[0]; var raw_id:=String(raw.get("source_material_id","")); raw_ids[raw_id]=true
		if native_mesh_keys.has(raw_key): continue
		var placeholder: Node=visual.nodes.get(raw_key)
		if placeholder==null or not placeholder is Node3D: return {"ok":false,"error":"missing_node:"+raw_key}
		missing.append({"node_key":raw_key,"source_material_id":raw_id,"native_class":placeholder.get_class(),"source_name":String(placeholder.get_meta("source_name","")),"visible":placeholder.visible,"child_count":placeholder.get_child_count(),"reason":"imported_non_mesh_node_no_native_surface","source_metadata":raw.get("source_metadata",{}).duplicate(true)})
	return {"ok":true,"profile_id":visual.profile_id,"mesh_nodes":mesh_nodes,"raw_manifest_slots":record.mesh_materials.size(),"raw_manifest_source_material_ids":raw_ids.size(),"surfaces":surfaces,"unique_source_material_ids":by_source_id.size(),"missing_native_slots":missing,"source_material_ids":_sorted_keys(by_source_id),"resource_ids":by_source_id}

func _two_compact_instances(catalogue: Dictionary) -> Dictionary:
	var a:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path); var b:=Visual.instantiate_visual(catalogue.entries.compact_sedan,catalogue.base_path)
	if not a.ok or not b.ok:
		if a.ok: a.visual.dispose()
		if b.ok: b.visual.dispose()
		return {"ok":false,"error":"instantiate"}
	world.add_child(a.visual.root); world.add_child(b.visual.root)
	var ca:=_census(a.visual,catalogue.entries.compact_sedan); var cb:=_census(b.visual,catalogue.entries.compact_sedan); var shared:=0
	if ca.ok and cb.ok:
		var second_resources:={}; for resource_id in cb.resource_ids.values(): second_resources[resource_id]=true
		for resource_id in ca.resource_ids.values():
			if second_resources.has(resource_id): shared+=1
	var result={"ok":ca.ok and cb.ok,"unique_ids":ca.get("unique_source_material_ids",0),"first_ids":ca.get("source_material_ids",[]),"second_ids":cb.get("source_material_ids",[]),"shared_resources":shared}
	a.visual.dispose(); b.visual.dispose(); return result

func _lifecycle_receipt(catalogue: Dictionary) -> void:
	var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
	check(loaded.ok,"lifecycle visual instantiates")
	if not loaded.ok: return
	var visual=loaded.visual; world.add_child(visual.root); var retained_root: Node3D=visual.root
	check(_census(visual,catalogue.entries.city_hatchback).ok,"inside-tree visual admitted")
	retained_root.queue_free()
	check(not _census(visual,catalogue.entries.city_hatchback).ok,"queued visual rejected by census")
	await process_frame
	check(not is_instance_valid(retained_root),"queued visual root frees")
	visual.dispose()

func _sorted_keys(dictionary: Dictionary) -> Array:
	var values: Array=dictionary.keys(); values.sort(); return values
func _sorted_strings(values: Array) -> Array:
	var result: Array=[]; for value in values: result.append(value)
	result.sort(); return result
func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_BURN_MATERIAL_ALIASES "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"manifest_sha":MANIFEST_SHA,"visual_sha":VISUAL_SHA,"metrics":metrics,"scope":"actual 13-profile native GLB material alias/resource census; load-only CPU, no source scalar/array inference, burn mutation, GPU, FPS or authority"}))
	if is_instance_valid(world): world.free()
	quit(0 if failures.is_empty() else 1)
