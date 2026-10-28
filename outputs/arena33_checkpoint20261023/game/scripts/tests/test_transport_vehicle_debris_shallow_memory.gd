extends SceneTree

const Visual=preload("res://scripts/vehicle_visual/vehicle_visual.gd")
const Frozen=preload("res://scripts/transport/transport_vehicle_debris.gd")
const Shallow=preload("res://scripts/transport/candidates/transport_vehicle_debris_shallow_mesh.gd")

var checks:=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var spec:=OS.get_environment("DEBRIS_MEMORY_MODE")
	if spec.is_empty(): spec="shallow:1"
	var pieces:=spec.split(":")
	var kind:=String(pieces[0]); var count:=int(pieces[1]) if pieces.size()==2 else 0
	check(kind in ["frozen","shallow"] and count in [1,3,10],"valid isolated mode")
	if not failures.is_empty(): finish({}); return
	var world:=Node3D.new(); root.add_child(world)
	var catalogue:=Visual.load_catalogue("res://assets/vehicle_visual/manifest.json")
	var visuals: Array=[]; var row_sets: Array=[]
	for index in count:
		var loaded:=Visual.instantiate_visual(catalogue.entries.city_hatchback,catalogue.base_path)
		check(loaded.get("ok",false),"actual hatch visual "+str(index))
		if not loaded.get("ok",false): finish({}); return
		var visual=loaded.visual; visuals.append(visual); world.add_child(visual.root)
		visual.root.global_position=Vector3(index*8.0,2.5,0)
		var sources:=_sources(visual); check(sources.size()==10,"ten assemblies "+str(index)); row_sets.append(_rows(sources))
	await process_frame; await process_frame
	var before_static:=int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var before_resources:=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var before_nodes:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var helpers: Array=[]; var configure_samples: Array=[]; var total_hulls:=0
	for index in count:
		var helper: RefCounted=Frozen.new() if kind=="frozen" else Shallow.new()
		var at:=Time.get_ticks_usec(); var result: Dictionary=helper.configure(visuals[index].root,world,row_sets[index]); configure_samples.append(Time.get_ticks_usec()-at)
		check(result.get("ok",false) and result.get("assemblies",0)==10 and result.get("hulls",0)==76,"configure "+str(index))
		total_hulls+=int(result.get("hulls",0)); helpers.append(helper)
	await process_frame; await process_frame
	var after_static:=int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var after_resources:=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var after_nodes:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var private_meshes: Dictionary={}; var private_materials: Dictionary={}
	for helper in helpers:
		for entry: Dictionary in helper._entries: _collect_private(entry.template,private_meshes,private_materials)
	check(total_hulls==count*76,"all hulls retained")
	check(private_meshes.size()==count*76 and private_materials.size()==count*76,"all private mesh/material resources retained")
	finish({"mode":kind,"providers":count,"assemblies":count*10,"hulls":total_hulls,"private_meshes":private_meshes.size(),"private_materials":private_materials.size(),"memory_static_before":before_static,"memory_static_after":after_static,"memory_static_delta":after_static-before_static,"resource_count_delta":after_resources-before_resources,"node_count_delta":after_nodes-before_nodes,"configure_us":configure_samples,"configure_total_us":_sum(configure_samples)})
	for helper in helpers: helper.dispose()
	for visual in visuals: visual.dispose()

func _sources(visual: RefCounted) -> Array:
	var result: Array=[]
	for id in ["front_left","rear_left","front_right","rear_right"]: result.append(visual.doors[id])
	for source_name in ["Hood_lid","Trunk_lid"]:
		for node in visual.nodes.values():
			if node.get_meta("source_name","")==source_name: result.append(node); break
	for id in ["front_left","front_right","rear_left","rear_right"]: result.append(visual.wheels[id].pivot)
	return result

func _rows(sources: Array) -> Array:
	var result: Array=[]
	for i in sources.size(): result.append({"source":sources[i],"mass_kg":18.0+i,"collision_layer":8,"collision_mask":3,"linear_damp":.35,"angular_damp":2.0,"friction":.75,"bounce":.08})
	return result

func _collect_private(node: Node3D,meshes: Dictionary,materials: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh!=null:
		meshes[node.mesh.get_instance_id()]=true
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			if material!=null: materials[material.get_instance_id()]=true
	for child in node.get_children():
		if child is Node3D: _collect_private(child,meshes,materials)

func _sum(values: Array) -> int:
	var total:=0
	for value in values: total+=int(value)
	return total

func finish(metrics: Dictionary) -> void:
	print("TRANSPORT_VEHICLE_DEBRIS_SHALLOW_MEMORY ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"metrics":metrics,"scope":"separate-process static-memory delta after real hatch visuals are loaded; no GPU/FPS/full-scene/adoption"}))
	quit(1 if not failures.is_empty() else 0)
