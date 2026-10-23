extends "res://scripts/destruction/palazzo/palazzo_structural_site.gd"
## New content, accepted Palazzo ownership, support, door and damage authority.
## Cold authored sections replace the fixed Palazzo layout; there are no hidden
## twenty-body pools. Engine/loaded-city acceptance is still required.
static var _unit_box: BoxMesh
static var _shared_materials: Dictionary = {}
var _recipe: Dictionary = {}
var _part_by_key: Dictionary = {}
var _terrain_pending := false
var _terrain_result: Dictionary = {}
var _native_ground_ready := false
var _interior_doors: Dictionary = {}
var _door_by_body: Dictionary = {}
const InteriorDoor = preload("modular_door.gd")
const RecipeValidator = preload("recipe_validator.gd")
const COLLAPSE_RELEASES_PER_FRAME := 8
const COLLAPSE_RELEASE_BUDGET_USEC := 750
var _collapse_queue: Array[RigidBody3D] = []
var _collapse_cursor := 0
var _collapse_generation := -1
var _collapse_release_frame := -1
var _collapse_releases_this_frame := 0
var _collapse_max_releases_per_frame := 0
const MAX_PARTS := 768

func configure(recipe: Dictionary) -> Dictionary:
	if is_inside_tree() or not _recipe.is_empty(): return {"ok":false,"reason":"configure_once_before_add_child"}
	var checked: Dictionary = RecipeValidator.validate(recipe)
	if not checked.get("ok",false): return checked
	_recipe = recipe.duplicate(true)
	source_id = recipe.source_id
	_terrain_pending = not recipe.get("terrain_cutouts",[]).is_empty()
	return {"ok":true,"source_id":source_id,"parts":recipe.parts.size(),"terrain_clearance_pending":_terrain_pending,"preflight":checked}

static func _finite_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true

static func _v3(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _ready() -> void:
	if _recipe.is_empty():
		site_error = "configure_recipe_before_add_child"
		set_process(false); set_physics_process(false)
		return
	super._ready()
	if not _native_ground_ready and site_ready:
		site_ready = false
		site_status = "awaiting_native_external_soil"
	elif _terrain_pending and site_ready:
		# Host must first remove actual terrain under the full basement footprint,
		# then wait a native physics step and call verify_terrain_clearance().
		site_ready = false
		site_status = "awaiting_native_basement_clearance"

func _build_site() -> void:
	flash = OmniLight3D.new()
	flash.name = "OriginalBlastFlash"
	flash.light_color = Color("ffb76b"); flash.light_energy = 0; flash.omni_range = 12
	add_child(flash)

func configure_structure(ground: Array[StaticBody3D] = []) -> Dictionary:
	if ground.is_empty():
		support_setup = {"ok":false,"reason":"bind_explicit_external_native_soil"}
		return support_setup.duplicate(true)
	return super.configure_structure(ground)

func attach_native_ground(ground: Array[StaticBody3D]) -> Dictionary:
	if not is_inside_tree() or rebuilding or not _finished_errors.is_empty() or ground.is_empty(): return {"ok":false,"reason":"site_or_native_ground_unavailable"}
	# Synchronous support configuration itself verifies the actual soil bodies,
	# space, collision and bounds. This method is not an authority receipt.
	site_ready = true
	var result: Dictionary = configure_structure(ground)
	_native_ground_ready = result.get("ok",false)
	if _native_ground_ready: site_error = ""
	site_ready = _native_ground_ready and not _terrain_pending
	if site_ready: site_status = "intact"
	elif _native_ground_ready: site_status = "awaiting_native_basement_clearance"
	return result

func mat(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var palette: Dictionary = _recipe.get("palette",{})
	if color == TRIM and palette.has("trim"): color = Color(palette.trim)
	elif color == DARK and palette.has("frame"): color = Color(palette.frame)
	elif color == BRASS and palette.has("metal"): color = Color(palette.metal)
	var roughness := 0.78 if metallic < 0.1 else 0.34
	for properties: Dictionary in _recipe.get("material_properties",{}).values():
		if properties.has("base_color") and Color(properties.base_color).is_equal_approx(color):
			roughness = float(properties.get("roughness",roughness)); metallic = float(properties.get("metallic",metallic))
	var key: String = color.to_html()+":"+str(metallic)+":"+str(roughness)
	if not _shared_materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color; material.metallic = metallic
		material.roughness = roughness
		_shared_materials[key] = material
	return _shared_materials[key]

func visual(parent: Node3D, size: Vector3, at: Vector3, color: Color, metallic: float = 0.0) -> MeshInstance3D:
	if _unit_box == null:
		_unit_box = BoxMesh.new(); _unit_box.size = Vector3.ONE
	var mesh := MeshInstance3D.new()
	mesh.mesh = _unit_box; mesh.material_override = mat(color,metallic)
	mesh.position = at; mesh.scale = size
	mesh.set_meta("box_size",size); mesh.set_meta("box_color",color); mesh.set_meta("box_metallic",metallic)
	parent.add_child(mesh)
	return mesh

func piece(label: String, size: Vector3, at: Vector3, color: Color, rotation_y: float = 0.0) -> RigidBody3D:
	# Keep the accepted FragmentBody and ownership; exact collision sizes have no
	# loose-foam shrink until _release(). Unique shapes are required by that code.
	var body: RigidBody3D = FragmentBody.new()
	body.name = label+str(pieces.size())
	body.set_meta("section_size",size); body.set_meta("section_color",color)
	body.set_meta("source_id",source_id); body.set_meta("building_id",source_id)
	var no_pool: Array[RigidBody3D] = []
	body.set_meta("pooled_fragments",no_pool)
	body.mass = maxf(2.0,size.x*size.y*size.z*18.0)
	body.freeze = true; body.linear_damp = 0.45; body.angular_damp = 1.8
	body.continuous_cd = true; body.max_contacts_reported = 4
	body.collision_layer = 1; body.collision_mask = 1|RUBBLE_LAYER
	body.sleeping_state_changed.connect(_on_sleep_changed.bind(body))
	var friction := PhysicsMaterial.new(); friction.friction = 0.78; friction.bounce = 0
	body.physics_material_override = friction
	building.add_child(body); body.position = at; body.rotation.y = rotation_y
	_owned_bodies[body.get_instance_id()] = weakref(body)
	var mesh: MeshInstance3D = visual(body,size,Vector3.ZERO,color)
	mesh.set_meta("finished_primary",true); mesh.set_meta("finished_physical",true)
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size
	collision.shape = shape; collision.set_meta("finished_primary",true); collision.set_meta("finished_intact_size",size)
	body.add_child(collision); pieces.append(body)
	initial_transforms[body.get_instance_id()] = body.global_transform
	return body

func _finished_box(body: RigidBody3D, size: Vector3, at: Vector3, color: Color, metallic: float, physical: bool, role: String = "detail") -> MeshInstance3D:
	var mesh: MeshInstance3D = visual(body,size,at,color,metallic)
	mesh.set_meta("finished_physical",physical); mesh.set_meta("finished_role",role)
	if physical:
		var node := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size
		node.shape = shape; node.position = at
		node.set_meta("finished_intact_size",size); node.set_meta("finished_role",role)
		body.add_child(node)
	return mesh

func _build_building() -> void:
	_collapse_queue.clear(); _collapse_cursor = 0; _collapse_generation = -1
	for controller: Node3D in _interior_doors.values():
		if is_instance_valid(controller): controller.retire(); controller.queue_free()
	_interior_doors.clear()
	_door_by_body.clear()
	building = Node3D.new(); building.name = "ModularDestructible"
	add_child(building)
	pieces.clear(); initial_transforms.clear(); batch_records.clear(); batch_nodes.clear()
	pooled_fragments.clear(); render_by_id.clear(); render_dirty.clear(); active_debris.clear()
	support_wakes.clear(); support_wake_ids.clear(); wall_panels.clear(); _part_by_key.clear()
	_finished_errors.clear(); _finished_omitted_cells = 0
	for row: Dictionary in _recipe.parts:
		var body: RigidBody3D = piece(str(row.role),_v3(row.size),_v3(row.at),Color(row.color),float(row.rotation[1]))
		body.rotation = _v3(row.rotation)
		body.set_meta("modular_part_id",row.id); body.set_meta("modular_role",row.role)
		_part_by_key[row.id] = body
		if row.has("window"):
			var window: Dictionary = row.window
			window_on(body,_v3(window.center),float(window.width),float(window.height))
		# Existing RPG area admission recognises native material, not air behind
		# a pane. Self is an explicit module owner, not a fabricated receipt.
		if str(row.role).contains("Facade") or str(row.role).contains("Partition") or row.get("door",false):
			body.set_meta("wall_panel",body)
			wall_panels.append(body)
		for detail: Dictionary in row.get("details",[]):
			var mesh: MeshInstance3D = visual(body,_v3(detail.size),_v3(detail.at),Color(detail.color))
			mesh.rotation = _v3(detail.rotation)
			if detail.get("physical",false):
				var collision := CollisionShape3D.new(); var shape := BoxShape3D.new()
				shape.size = _v3(detail.size); collision.shape = shape
				collision.position = _v3(detail.at); collision.rotation = _v3(detail.rotation)
				collision.set_meta("finished_intact_size",shape.size)
				body.add_child(collision)
		if row.has("text"):
			var sign := Label3D.new(); sign.text = str(row.text)
			sign.font_size = 54; sign.pixel_size = .0045; sign.outline_size = 0
			sign.modulate = Color(row.get("text_color","ead5a4"))
			sign.position.z = -float(row.size[2])*.5-.01; sign.rotation.y = PI
			body.add_child(sign)
		if row.has("room_signs"):
			for sign_data: Dictionary in row.room_signs:
				var side: int = int(sign_data.side)
				var label := Label3D.new(); label.text = str(sign_data.name_ru)
				label.font_size = 38; label.pixel_size = .004; label.outline_size = 4
				label.modulate = Color("e8d6ac"); label.outline_modulate = Color("263c3d")
				label.position = Vector3(0,-float(row.size[1])*.5+.18,side*(float(row.size[2])*.5+.045))
				label.rotation.y = 0.0 if side>0 else PI
				body.add_child(label)
				visual(body,Vector3(minf(1.3,float(row.size[0])-.06),.24,.025),label.position-Vector3(0,0,side*.02),Color("263c3d"))
		if row.has("interior_door"):
			var controller: Node3D = InteriorDoor.new()
			add_child(controller)
			controller.configure(self,body,str(row.interior_door.id))
			_interior_doors[str(row.interior_door.id)] = controller
			_door_by_body[body.get_instance_id()] = controller
		initial_transforms[body.get_instance_id()] = body.global_transform
	_finished_initial_sections = pieces.size()
	if batched: _build_batches()
	collapsing = false
	if not rebuilding: _prepare_glazing()

func runtime_ground_cutout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cut: Dictionary in _recipe.get("terrain_cutouts",[]):
		var r: Array = cut.rect
		result.append({"source_id":source_id,"generation":rebuild_generation,"site_frame":global_transform,"min_x":float(r[0]),"max_x":float(r[2]),"min_z":float(r[1]),"max_z":float(r[3]),"floor_y":float(cut.bottom),"roof_y":float(cut.top),"depth":float(cut.top)-float(cut.bottom)})
	return result

func verify_terrain_clearance() -> Dictionary:
	if not is_inside_tree() or rebuilding or not _finished_errors.is_empty() or not _native_ground_ready: return {"ok":false,"reason":"site_or_native_ground_unavailable"}
	if not _terrain_pending: return {"ok":true,"required":false}
	var excluded: Array[RID] = []
	var queue: Array[Node] = [self]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		if node is CollisionObject3D: excluded.append(node.get_rid())
		for child: Node in node.get_children(): queue.append(child)
	for cut: Dictionary in runtime_ground_cutout():
		var shape := BoxShape3D.new()
		shape.size = Vector3(cut.max_x-cut.min_x,cut.roof_y-cut.floor_y,cut.max_z-cut.min_z)
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape
		query.transform = global_transform*Transform3D(Basis.IDENTITY,Vector3((cut.max_x+cut.min_x)*.5,(cut.roof_y+cut.floor_y)*.5,(cut.max_z+cut.min_z)*.5))
		query.collision_mask = 1; query.exclude = excluded; query.collide_with_areas = false
		var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query,16)
		if not hits.is_empty():
			_terrain_result = {"ok":false,"reason":"native_basement_volume_occupied","hits":hits.size(),"source_id":source_id,"generation":rebuild_generation,"physics_frame":Engine.get_physics_frames()}
			return _terrain_result.duplicate(true)
	_terrain_pending = false; site_ready = true; site_status = "intact"
	_terrain_result = {"ok":true,"required":true,"native_physics_query":true,"source_id":source_id,"generation":rebuild_generation,"physics_frame":Engine.get_physics_frames()}
	return _terrain_result.duplicate(true)

func actions_registry() -> Dictionary:
	return {"source_id":source_id,"generation":rebuild_generation,"main_door_available":_door_available(),"interior_door_ids":_interior_doors.keys(),"door_prompt":"get_door_prompt","door_action":"interact_door","rooms":_recipe.get("rooms",[]).duplicate(true),"room_graph":_recipe.get("room_graph",{}).duplicate(true),"stairs":_recipe.get("stair_routes",[]).duplicate(true)}

func get_door_prompt(actor: Node3D) -> Dictionary:
	var selected: Dictionary = super.get_door_prompt(actor)
	selected.door_id = "main"
	for controller: Node3D in _interior_doors.values():
		var candidate: Dictionary = controller.get_prompt(actor)
		if candidate.get("available",false) and (not selected.get("available",false) or float(candidate.distance)<float(selected.get("distance",INF))): selected = candidate
	return selected

func interact_door(actor: Node3D) -> Dictionary:
	var prompt: Dictionary = get_door_prompt(actor)
	if not prompt.get("available",false) or not actor is CharacterBody3D: return {"ok":false,"reason":"door_out_of_reach_busy_or_unavailable"}
	var door_id: String = str(prompt.get("door_id","main"))
	if door_id != "main": return _interior_doors[door_id].interact(actor)
	if _door_close43 == null: _door_close43 = DoorClose43.new(self)
	return _door_close43.begin(actor as CharacterBody3D,not _door_open)

func _release(body: RigidBody3D, at: Vector3, power: float, exit_direction: Vector3 = Vector3.ZERO) -> void:
	if is_instance_valid(body) and _door_by_body.has(body.get_instance_id()): _door_by_body[body.get_instance_id()].retire()
	super._release(body,at,power,exit_direction)

func _bind_door() -> void:
	super._bind_door()
	if is_instance_valid(_door):
		_door_hinge -= _door_closed.basis.z*float(_door.get_meta("section_size").z)*.5

func collapse() -> void:
	if not site_ready or rebuilding or collapsing: return
	_stop_door()
	for controller: Node3D in _interior_doors.values(): controller.retire()
	_break_all_glass()
	collapsing = true; collapse_stage = -1
	_collapse_generation = rebuild_generation
	_collapse_queue.clear(); _collapse_cursor = 0
	_collapse_max_releases_per_frame = 0
	for body: RigidBody3D in pieces:
		if owns_collider(body) and body.freeze and not body.get_meta("detached",false): _collapse_queue.append(body)
	# Bottom-up collapse retains all content; each native rigid activation is
	# deferred to the bounded queue instead of three unbounded timer loops.
	_collapse_queue.sort_custom(func(a: RigidBody3D,b: RigidBody3D) -> bool: return a.position.y<b.position.y)
	site_status = "collapsing"
	_dust(Vector3(0,1.1,0))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_advance_modular_collapse()

func _advance_modular_collapse() -> void:
	if not collapsing or rebuilding or not site_ready: return
	if _collapse_generation!=rebuild_generation:
		_collapse_queue.clear(); _collapse_cursor = 0; return
	var frame: int = Engine.get_physics_frames()
	if frame!=_collapse_release_frame:
		_collapse_release_frame = frame; _collapse_releases_this_frame = 0
	var started: int = Time.get_ticks_usec()
	while _collapse_cursor<_collapse_queue.size() and _collapse_releases_this_frame<COLLAPSE_RELEASES_PER_FRAME and Time.get_ticks_usec()-started<COLLAPSE_RELEASE_BUDGET_USEC:
		var body: RigidBody3D = _collapse_queue[_collapse_cursor]
		_collapse_cursor += 1
		if not owns_collider(body) or not body.freeze or body.get_meta("detached",false): continue
		_release(body,to_global(Vector3(0,-1,0)),1.5 if body.position.y<3.0 else .8)
		_collapse_releases_this_frame += 1
		_collapse_max_releases_per_frame = maxi(_collapse_max_releases_per_frame,_collapse_releases_this_frame)
	if not _collapse_queue.is_empty():
		collapse_stage = mini(int(_recipe.storeys)-1,int(float(_collapse_cursor)*int(_recipe.storeys)/_collapse_queue.size()))
	if _events.has(_collapse_event_id):
		_events[_collapse_event_id].stage = collapse_stage
		_events[_collapse_event_id].released_sections = _collapse_cursor
		_events[_collapse_event_id].total_sections = _collapse_queue.size()
	if _collapse_cursor>=_collapse_queue.size():
		site_status = "all_sections_released"
		if _events.has(_collapse_event_id):
			_events[_collapse_event_id].state = "all_sections_released"
			_events[_collapse_event_id].completed = true
		_collapse_queue.clear(); _collapse_cursor = 0
		_collapse_generation = -1

func _exit_tree() -> void:
	_collapse_queue.clear(); _collapse_cursor = 0; _collapse_generation = -1
	super._exit_tree()

func get_stats() -> Dictionary:
	var result: Dictionary = super.get_stats()
	result.profile_id = _recipe.get("profile_id","")
	result.authored_budget = _recipe.get("budget",{}).duplicate(true)
	result.hidden_fragment_bodies = pooled_fragments.size()
	result.terrain_pending = _terrain_pending
	result.native_ground_ready = _native_ground_ready
	result.terrain_result = _terrain_result.duplicate(true)
	result.loaded_city_performance = "unverified"
	result.modular_collapse = {"queued":maxi(0,_collapse_queue.size()-_collapse_cursor),"release_limit_per_physics_frame":COLLAPSE_RELEASES_PER_FRAME,"soft_budget_usec":COLLAPSE_RELEASE_BUDGET_USEC,"maximum_releases_per_physics_frame":_collapse_max_releases_per_frame}
	return result
