extends SceneTree
## Read-only source assembly dependencies. Input assertions use real registries
## and Camera3D rays, never an overridden pick. Owner callbacks are explicit
## geometry-only test admissions, not production pause/nav/traffic approval.
const HouseFactory = preload("res://scripts/map_editor/catalog_factory.gd")
const HouseRegistry = preload("res://scripts/map_editor/object_registry.gd")
const ForestFactory = preload("res://scripts/procedural_factory.gd")
const ForestRegistry = preload("res://scripts/procedural_registry.gd")
const ParkingFactory = preload("res://transport_decor_factory.gd")
const ParkingRegistry = preload("res://transport_registry.gd")
const Controller = preload("res://scripts/map_editor/editor_controller.gd")
var checks := 0
var failures: Array[String] = []
var tested: Array = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func owner(_request: Dictionary) -> Dictionary:
	return {"approved":true,"commit":func():return true,"rollback":func():pass}
func begin() -> Dictionary: return {"ok":true}
func end(_data: Dictionary) -> Dictionary: return {"ok":true}
func button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	return event
func snapshot_node(node: Node, output: Array) -> void:
	if node is MeshInstance3D:
		output.append([node,node.mesh,node.material_override,node.transform,node.visible,node.cast_shadow])
	if node is CollisionObject3D: output.append([node,node.collision_layer,node.collision_mask])
	for child: Node in node.get_children(): snapshot_node(child,output)
func snapshot_parts(factory: RefCounted, id: String, family: String) -> Array:
	var output: Array = []
	for part: Dictionary in factory._parts[id]:
		var batch: Dictionary = factory._batches[part.batch]
		var mm: MultiMesh = batch.mesh if family == "tree" else batch.multimesh
		var transforms: Array = batch.transforms if family == "tree" else batch.cpu_transforms
		output.append([batch.node,mm,mm.mesh,batch.node.material_override,batch.node.cast_shadow,mm.instance_count,transforms.duplicate(true),mm.get_instance_transform(part.index),mm.get_instance_color(part.index)])
	return output
func aim(controller: Node, registry: RefCounted, id: String) -> Vector2:
	var bounds: AABB = registry.world_bounds(id)
	var pixel := Vector2(640,360)
	var center := bounds.get_center()
	controller.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	controller.camera.global_position = center + Vector3(0,maxf(40,bounds.size.length()*3),0)
	controller.camera.look_at(center,Vector3.FORWARD)
	return pixel
func choose(controller: Node, registry: RefCounted, candidates: Array) -> Dictionary:
	for id: String in candidates:
		if registry.world_bounds(id) == null or not registry.is_editable(id): continue
		var pixel := aim(controller,registry,id)
		if registry.pick(controller.camera.project_ray_origin(pixel),controller.camera.project_ray_normal(pixel)) == id:
			return {"id":id,"pixel":pixel}
	return {}
func exercise(world: Node3D, registry: RefCounted, candidates: Array, family: String, factory: RefCounted = null, house_root: Node = null) -> void:
	var game_camera := Camera3D.new()
	world.add_child(game_camera)
	var controller := Controller.new()
	world.add_child(controller)
	check(controller.setup(registry,registry.source_document("native-input-"+family),game_camera,begin,end).ok,family+" real controller setup")
	check(controller.enter_editor().ok,family+" fixture lease")
	await process_frame
	controller.set_process(false) # Explicit native input only; no camera drift.
	var choice := choose(controller,registry,candidates)
	check(not choice.is_empty(),family+" actual original camera ray intersects native bounds")
	if choice.is_empty(): world.free(); return
	var id: String = choice.id
	var pixel: Vector2 = choice.pixel
	var before_record: Dictionary = controller.document.get_record(id)
	var before_shape: Array = []
	if family == "house": snapshot_node(house_root,before_shape)
	else: before_shape = snapshot_parts(factory,id,family)
	check(not controller.panel.is_pointer_over_panel(pixel),family+" map ray outside actual UI rect")
	var left := InputEventMouseButton.new()
	left.position = pixel
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	controller.handle_input(left)
	check(controller.selected_id == id,family+" LMB selects real ray-picked original")
	controller.handle_input(button(pixel,true))
	controller.handle_input(button(pixel,false))
	check(controller.selected_id == id,family+" short RMB selected actual original")
	check(registry.world_bounds(id) == null and not controller.document.has_record(id),family+" short RMB deletes picked original")
	check(controller.handle_action("undo").ok,family+" undo native original")
	check(controller.document.get_record(id) == before_record and registry.world_bounds(id) != null,family+" exact opaque source record/frame restored")
	var restored: Array = []
	if family == "house": snapshot_node(house_root,restored)
	else: restored = snapshot_parts(factory,id,family)
	check(restored == before_shape,family+" exact source mesh/material/MM slots/shadow/shape restoration")
	pixel = aim(controller,registry,id)
	controller.handle_input(button(pixel,true))
	var motion := InputEventMouseMotion.new()
	motion.position = pixel+Vector2(20,0)
	motion.relative = Vector2(20,0)
	controller.handle_input(motion)
	controller.handle_input(button(motion.position,false))
	check(controller.document.get_record(id) == before_record and registry.world_bounds(id) != null,family+" RMB look drag never deletes")
	pixel = aim(controller,registry,id)
	var ui_point: Vector2 = controller.panel._root.get_global_rect().get_center()
	check(controller.panel.is_pointer_over_panel(ui_point),family+" real UI pointer guard")
	check(not controller.handle_input(button(ui_point,true)) and not controller.handle_input(button(ui_point,false)),family+" UI RMB belongs to Controls")
	check(controller.document.get_record(id) == before_record and registry.world_bounds(id) != null,family+" UI click cannot delete")
	controller.panel._search.grab_focus()
	check(controller.panel.is_text_focused(),family+" actual LineEdit focus")
	check(not controller.handle_input(button(pixel,true)) and not controller.handle_input(button(pixel,false)),family+" text focus blocks map RMB")
	check(controller.document.get_record(id) == before_record and registry.world_bounds(id) != null,family+" text focus cannot delete")
	controller.panel._search.release_focus()
	controller.handle_input(button(pixel,true))
	controller.panel._search.grab_focus()
	controller.handle_input(button(pixel,false))
	controller.panel._search.release_focus()
	controller.handle_input(button(pixel,false))
	var stale_focus_safe := controller.document.has_record(id)
	check(stale_focus_safe,family+" text-focus interruption cancels pending map RMB")
	if not stale_focus_safe:
		check(controller.handle_action("undo").ok,family+" repair reproduced stale-focus deletion")
	controller.handle_input(button(pixel,true))
	controller.panel._search.grab_focus()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	check(not controller.handle_input(key) and controller.active,family+" focused K stays text input/editor held")
	controller.panel._search.release_focus()
	controller.handle_input(button(pixel,false))
	check(controller.document.has_record(id),family+" early focused K cancels pending map RMB")
	# Press on map then leave to UI: pending click must be cancelled.
	controller.handle_input(button(pixel,true))
	controller.handle_input(button(ui_point,false))
	controller.handle_input(button(pixel,false))
	check(controller.document.get_record(id) == before_record and registry.world_bounds(id) != null,family+" map-to-UI release cannot trigger later stale deletion")
	tested.append({"family":family,"original_id":id,"baseline_records":registry.ids().size(),"snapshot_entries":before_shape.size()})
	world.free()
func run() -> void:
	root.size = Vector2i(1280,720)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var house_factory := HouseFactory.new()
	check(house_factory.configure(catalog),"authored GLB checksum admission")
	var row: Dictionary = {}
	for candidate: Dictionary in catalog.objects:
		if candidate.get("assetId","") == "old_town_narrow_townhouse_v1": row=candidate; break
	check(not row.is_empty(),"actual GLB house source descriptor")
	var built: Dictionary = house_factory.spawn_key(row.key,{"exterior_collisions":true})
	check(built.ok and built.pending.is_empty(),"actual house native imported mesh/colliders")
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(built.root)
	var houses := HouseRegistry.new()
	check(houses.register_object(row.key,built.root,{"kind":row.dataset,"model":row.resourceId,"source":row.sourceRecord},[],true).ok,"authored original identity")
	await exercise(world,houses,[row.key],"house",null,built.root)
	var forest := ForestFactory.new()
	check(forest.configure("82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd"),"actual tree source SHA")
	var exploration: Dictionary = forest.build_exploration()
	var roads: Dictionary = forest.build_roads()
	check(exploration.ok and roads.ok,"actual tree V3 original buffers")
	world=Node3D.new(); root.add_child(world)
	world.add_child(exploration.root); world.add_child(roads.root)
	var trees := ForestRegistry.new()
	check(trees.configure(forest,owner).ok,"real tree V3 identity owner")
	var pines: Array = []
	for id: String in trees.ids():
		if id.begins_with("explore-pine-"): pines.append(id)
	await exercise(world,trees,pines,"tree",forest)
	var parking := ParkingFactory.new()
	check(parking.configure("res://transport_source","69ecbd14108fd151b504a41dc3d00ab5dbeca98b8c5ccd6251553fb60189546b").ok,"actual parking source SHA")
	var bays: Dictionary = parking.build_parking()
	check(bays.ok,"actual parking V1 mesh buffers")
	world=Node3D.new(); root.add_child(world); world.add_child(bays.root)
	var parking_registry := ParkingRegistry.new()
	check(parking_registry.configure(parking,owner).ok,"real parking V1 owner")
	var bay_ids: Array = []
	for id: String in parking_registry.ids():
		if id.begins_with("parking-") and parking._parts.has(id): bay_ids.append(id)
	await exercise(world,parking_registry,bay_ids,"parking",parking)
	parking_registry.dispose(); parking.dispose()
	for failure in failures: push_error(failure)
	print(JSON.stringify({"suite":"actual-native-input-conformance","checks":checks,"failures":failures,"objects_tested":tested,"pick_mocked":false,"gpu":false,"production_wired":false,"owner_callbacks":"test-only geometry admission; no production pause/nav/traffic proof"}))
	quit(0 if failures.is_empty() else 1)
