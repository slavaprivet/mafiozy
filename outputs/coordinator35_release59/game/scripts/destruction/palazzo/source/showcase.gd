extends Node3D
## Isolated native Godot showcase. No production saves, damage or world IDs.
## Pre-sectioned architecture, not arbitrary runtime mesh cutting.

const STONE = Color("b7ad96")
const TRIM = Color("c8bfaa")
const DARK = Color("283f3e")
const GLASS = Color("294f50")
const BRASS = Color("b69861")
const WINE = Color("6d3037")
const FragmentBody = preload("fragment_body.gd")

var pieces: Array[RigidBody3D] = []
var mesh_cache: Dictionary = {}
var materials: Dictionary = {}
var initial_transforms: Dictionary = {}
var camera: Camera3D
var building: Node3D
var status: Label
var stats: Label
var yaw: float = 0.57
var pitch: float = 0.42
var distance: float = 19.0
var dragging: bool = false
var flash: OmniLight3D
var status_clock: float = 0.0
var blast_serial: int = 0
var rebuild_generation: int = 0
var rebuilding: bool = false
var collapsing: bool = false
var rng = RandomNumberGenerator.new()
var qa_mode: bool = false
var capture_mode: bool = false
var perf_phase: String = ""
var perf_samples: Dictionary = {}
var perf_draw_calls: Dictionary = {}
var last_frame_usec: int = 0
var batched: bool = true
var batch_records: Array = []
var batch_mesh_count: int = 0
var batch_group_count: int = 0
var action_buttons: Array[Button] = []
var batch_nodes: Array[MultiMeshInstance3D] = []
var pooled_fragments: Array[RigidBody3D] = []
var walker: CharacterBody3D
var walker_shape: CapsuleShape3D
var walker_visual: Node3D
var walk_mode: bool = false
var walk_yaw: float = 0.0
var walk_pitch: float = -.10
var walk_clock: float = 0.0
var dust_pool: Array[CPUParticles3D] = []
var dust_cursor: int = 0
var walk_test_input: Vector3 = Vector3.ZERO
var walk_testing: bool = false
var shove_query: PhysicsShapeQueryParameters3D
var stand_query: PhysicsShapeQueryParameters3D
var last_blast_cpu_usec: int = 0
var render_by_id: Dictionary = {}
var render_dirty: Dictionary = {}
var active_debris: Dictionary = {}
var wall_panels: Array[RigidBody3D] = []
var last_render_body_visits: int = 0
var push_ray: PhysicsRayQueryParameters3D
var support_wakes: Array = []
var support_wake_ids: Dictionary = {}
var support_query: PhysicsShapeQueryParameters3D

func _ready() -> void:
	rng.seed = 7302026
	qa_mode = "--qa" in OS.get_cmdline_user_args() or "--walk-qa" in OS.get_cmdline_user_args()
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	batched = not "--unbatched" in OS.get_cmdline_user_args()
	Engine.max_fps = 60
	_build_environment()
	_build_building()
	_build_walker()
	_build_dust_pool()
	_build_ui()
	_update_camera()
	if qa_mode:
		get_tree().create_timer(35.0).timeout.connect(func(): get_tree().quit(2))
		if "--walk-qa" in OS.get_cmdline_user_args():
			_run_walk_qa.call_deferred()
		else:
			_run_qa.call_deferred()
	elif capture_mode:
		_capture_sequence.call_deferred()

func mat(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var key = str(color) + str(metallic)
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.72 if metallic == 0.0 else 0.38
	m.metallic = metallic
	materials[key] = m
	return m

func _bevel_mesh(size: Vector3) -> ArrayMesh:
	var key = str(size)
	if mesh_cache.has(key):
		return mesh_cache[key]
	var half = size * 0.5
	var radius = minf(0.07, minf(half.x, minf(half.y, half.z)) * 0.32)
	var inner = half - Vector3.ONE * radius
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six flat faces, twelve rounded bevel strips and eight corner facets.
	for axis in range(3):
		var a = (axis + 1) % 3
		var b = (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var poly: Array[Vector3] = []
			for signs in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
				var p = Vector3.ZERO
				p[axis] = half[axis] * sign_value
				p[a] = inner[a] * signs.x
				p[b] = inner[b] * signs.y
				poly.append(p)
			_emit_face(surface, poly, inner)
	for along in range(3):
		var a = (along + 1) % 3
		var b = (along + 2) % 3
		for sa in [-1.0,1.0]:
			for sb in [-1.0,1.0]:
				var poly: Array[Vector3] = []
				for values in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
					var p = Vector3.ZERO
					p[along] = inner[along] * values.x
					p[a] = (half[a] if values.y == 0 else inner[a]) * sa
					p[b] = (inner[b] if values.y == 0 else half[b]) * sb
					poly.append(p)
				_emit_face(surface, poly, inner)
	for sx in [-1.0,1.0]:
		for sy in [-1.0,1.0]:
			for sz in [-1.0,1.0]:
				var poly: Array[Vector3] = []
				for axis in range(3):
					var p = inner
					p[axis] = half[axis]
					poly.append(p * Vector3(sx,sy,sz))
				_emit_face(surface, poly, inner)
	var result = surface.commit()
	mesh_cache[key] = result
	return result

func _emit_face(surface: SurfaceTool, points: Array[Vector3], inner: Vector3) -> void:
	var center = Vector3.ZERO
	for p in points:
		center += p
	# Godot's front face is clockwise.
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(center) > 0:
		points.reverse()
	for i in range(1,points.size()-1):
		for p in [points[0],points[i],points[i+1]]:
			var normal = Vector3(signf(p.x)*maxf(0,absf(p.x)-inner.x), signf(p.y)*maxf(0,absf(p.y)-inner.y), signf(p.z)*maxf(0,absf(p.z)-inner.z)).normalized()
			surface.set_normal(normal)
			surface.add_vertex(p)

func visual(parent: Node3D, size: Vector3, at: Vector3, color: Color, metallic: float = 0.0) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	mesh.mesh = _bevel_mesh(size)
	mesh.material_override = mat(color,metallic)
	mesh.set_meta("box_size",size)
	mesh.set_meta("box_color",color)
	mesh.set_meta("box_metallic",metallic)
	parent.add_child(mesh)
	mesh.position = at
	return mesh

func static_box(size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body = StaticBody3D.new()
	add_child(body)
	body.position = at
	visual(body,size,Vector3.ZERO,color)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func piece(label: String, size: Vector3, at: Vector3, color: Color, rotation_y: float = 0.0) -> RigidBody3D:
	var body = FragmentBody.new()
	body.name = label + str(pieces.size())
	body.set_meta("section_size",size)
	body.set_meta("section_color",color)
	body.mass = maxf(2.0,size.x*size.y*size.z*18.0)
	body.freeze = true
	body.linear_damp = 0.45
	body.angular_damp = 1.8
	body.continuous_cd = true
	body.max_contacts_reported = 4
	body.sleeping_state_changed.connect(_on_sleep_changed.bind(body))
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = 0.78
	physics_material.bounce = 0.0
	body.physics_material_override = physics_material
	building.add_child(body)
	body.position = at
	body.rotation.y = rotation_y
	visual(body,size,Vector3.ZERO,color)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size * 0.98
	collision.shape = shape
	body.add_child(collision)
	pieces.append(body)
	initial_transforms[body.get_instance_id()] = body.global_transform
	return body

func window_on(body: Node3D, center: Vector3, width: float = 1.10, height: float = 1.5) -> void:
	visual(body,Vector3(width+0.18,height+0.18,0.10),center,DARK)
	visual(body,Vector3(width,height,0.08),center+Vector3(0,0,0.07),GLASS,0.22)
	visual(body,Vector3(0.045,height,0.045),center+Vector3(0,0,0.12),BRASS,0.5)
	visual(body,Vector3(width,0.045,0.045),center+Vector3(0,-0.23,0.12),BRASS,0.5)
	visual(body,Vector3(width+0.34,0.14,0.40),center+Vector3(0,-height/2-0.1,0.08),TRIM)
	# A subdued reflection keeps the stylized glass readable without a texture.
	visual(body,Vector3(width*0.28,height*0.77,0.009),center+Vector3(-width*.24,0.08,0.118),Color("567a78"),0.15)

func _build_building() -> void:
	building = Node3D.new()
	building.name = "Palazzo_Destructible"
	add_child(building)
	pieces.clear()
	initial_transforms.clear()
	batch_records.clear()
	batch_nodes.clear()
	pooled_fragments.clear()
	render_by_id.clear()
	render_dirty.clear()
	active_debris.clear()
	support_wakes.clear()
	support_wake_ids.clear()
	wall_panels.clear()
	for floor_index in range(2):
		var y = 1.57 + floor_index * 2.70
		for side in [-1.0,1.0]:
			for i in range(4):
				var x = -3.0 + i*2.0
				if floor_index == 0 and side == 1 and i == 2:
					var door = piece("Entrance",Vector3(1.90,2.62,.26),Vector3(x,y,3.0),DARK)
					window_on(door,Vector3(0,0,.16),1.40,2.2)
					visual(door,Vector3(.055,.40,.08),Vector3(.12,-.05,.34),BRASS,.65)
					continue
				var wall = piece("Facade",Vector3(1.98,2.62,.34),Vector3(x,y,side*3.0),STONE,0 if side == 1 else PI)
				window_on(wall,Vector3(0,.1,.21))
				visual(wall,Vector3(1.85,.15,.10),Vector3(0,1.04,.20),TRIM)
		for side in [-1.0,1.0]:
			for i in range(3):
				var wall = piece("Side",Vector3(1.96,2.62,.34),Vector3(side*4.0,y,-2+i*2.0),STONE,side*PI/2)
				window_on(wall,Vector3(0,.1,.21),.95,1.5)
	for y in [.34,2.94,5.66]:
		for side in [-1.0,1.0]:
			for i in range(4):
				piece("Cornice",Vector3(2.04,.22,.54),Vector3(-3+i*2,y,side*3.04),TRIM)
			for i in range(3):
				piece("Cornice",Vector3(.54,.22,1.94),Vector3(side*4.03,y,-2+i*2),TRIM)
	for i in range(4):
		for j in range(3):
			var roof = piece("Roof",Vector3(1.99,.25,1.99),Vector3(-3+i*2,5.87,-2+j*2),Color("697572"))
			if i == 0 and j == 0:
				visual(roof,Vector3(.65,.95,.70),Vector3(0,.60,0),STONE)
				visual(roof,Vector3(.81,.14,.84),Vector3(0,1.13,0),TRIM)
	for side in [-1.0,1.0]:
		for i in range(4):
			piece("Parapet",Vector3(1.99,.40,.26),Vector3(-3+i*2,6.15,side*3.0),STONE)
	for i in range(4):
		piece("Floor",Vector3(1.92,.18,5.6),Vector3(-3+i*2,2.94,0),Color("8d7360"))
	var canopy = piece("Canopy",Vector3(3.9,.22,1.05),Vector3(1,2.63,3.63),WINE)
	visual(canopy,Vector3(3.94,.26,.09),Vector3(0,-.12,.50),WINE)
	visual(canopy,Vector3(3.80,.038,.035),Vector3(0,-.18,.56),BRASS,.4)
	var sign_body = piece("Sign",Vector3(3.9,.48,.16),Vector3(1,3.36,3.28),DARK)
	var lettering = Label3D.new()
	lettering.text = "П А Л А Ц Ц О"
	lettering.font_size = 58
	lettering.pixel_size = .0053
	lettering.modulate = Color("ead5a4")
	lettering.outline_size = 0
	sign_body.add_child(lettering)
	lettering.position.z = .09
	var table = piece("LobbyTable",Vector3(1.5,.12,.8),Vector3(-1.2,.95,.5),Color("694b3d"))
	for x in [-.6,.6]:
		visual(table,Vector3(.09,.8,.09),Vector3(x,-.46,0),BRASS,.3)
	for body in pieces.duplicate():
		if body.name.begins_with("Facade") or body.name.begins_with("Side") or body.name.begins_with("Entrance"):
			_prepare_wall_fragments(body)
			_pool_wall_fragments(body)
			wall_panels.append(body)
	if batched:
		_build_batches()
	collapsing = false
	if is_instance_valid(status):
		status.text = "Здание цело. Выберите точку на фасаде или нажмите «Взрыв»."

func _build_batches() -> void:
	# Preserve every mesh/material/collider; only combine identical draw submissions.
	for node in batch_nodes:
		if is_instance_valid(node):
			node.hide()
			node.queue_free()
	batch_nodes.clear()
	batch_records.clear()
	var groups: Dictionary = {}
	batch_mesh_count = 0
	for body in pieces + pooled_fragments:
		var record = {"body":body, "last":body.transform, "visible":body.visible,"instances":[]}
		for child in body.get_children():
			if not child is MeshInstance3D:
				continue
			var key = str(child.mesh.get_instance_id()) + ":" + str(child.material_override.get_instance_id())
			if not groups.has(key):
				groups[key] = {"mesh":child.mesh, "material":child.material_override, "items":[]}
			var item = {"local":child.transform, "source":child, "body":body}
			groups[key].items.append(item)
			record.instances.append(item)
			child.visible = false
			batch_mesh_count += 1
		batch_records.append(record)
		render_by_id[body.get_instance_id()] = record
	batch_group_count = groups.size()
	for group in groups.values():
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = group.mesh
		mm.instance_count = group.items.size()
		var node = MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = group.material
		building.add_child(node)
		batch_nodes.append(node)
		var visible_count = 0
		for i in range(group.items.size()):
			var item: Dictionary = group.items[i]
			item["batch"] = mm
			item["node"] = node
			item["index"] = i
			if item.body.visible:
				visible_count += 1
			mm.set_instance_transform(i,_batch_transform(item.body,item.local))
		node.set_meta("visible_count",visible_count)
		node.visible = visible_count > 0

func _batch_transform(body: Node3D, local: Transform3D) -> Transform3D:
	if not body.visible:
		return Transform3D(Basis.from_scale(Vector3.ZERO),body.position)
	return body.transform * local

func _queue_render(body: RigidBody3D) -> void:
	var id = body.get_instance_id()
	if render_by_id.has(id):
		render_dirty[id] = render_by_id[id]

func _on_sleep_changed(body: RigidBody3D) -> void:
	if rebuilding or body.freeze:
		return
	_queue_render(body) # Capture the final sleeping pose, or resume on collision wake.
	if not body.sleeping:
		active_debris[body.get_instance_id()] = body

func _wake_debris(body: RigidBody3D) -> void:
	if body.get_meta("parked",false):
		var id = body.get_instance_id()
		# At most one queued request per pooled body; never discard a moved support.
		if not support_wake_ids.has(id):
			support_wakes.append({"body":body,"transform":body.global_transform,"size":body.get_meta("section_size")})
			support_wake_ids[id] = true
		body.freeze = false
		body.set_meta("parked",false)
	body.park_pending = false
	body.stable_time = 0.0
	body.quiet_time = 0.0
	body.sleeping = false
	active_debris[body.get_instance_id()] = body
	_queue_render(body)

func _wake_supported_rubble() -> void:
	# Moving a parked support must not leave a frozen pile hanging in mid-air.
	# Spread the wake through upper neighbours, with bounded work per physics tick.
	for i in range(mini(4,support_wakes.size())):
		var request: Dictionary = support_wakes.pop_front()
		var source: RigidBody3D = request.body
		support_wake_ids.erase(source.get_instance_id())
		var size: Vector3 = request.size
		support_query.shape.size = size+Vector3(.16,.32,.16)
		support_query.transform = request.transform
		support_query.transform.origin.y += .12
		# A wide roof slab can support more than16 chunks. The preallocated pool
		# bounds results; spread requests over ticks instead of omitting neighbours.
		for hit in get_world_3d().direct_space_state.intersect_shape(support_query,pieces.size()):
			var other = hit.collider as RigidBody3D
			if other != null and other != source and other.get_meta("parked",false) and other.position.y > request.transform.origin.y+.08:
				_wake_debris(other)

func _park_debris(body: RigidBody3D) -> void:
	if rebuilding or not is_instance_valid(body) or not body.is_inside_tree():
		return
	if not body.get_meta("detached",false) or not body.park_pending:
		return
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.set_meta("parked",true)
	body.freeze = true
	active_debris.erase(body.get_instance_id())
	_queue_render(body)

func _impact_wake(body: RigidBody3D, velocity: Vector3) -> void:
	if rebuilding or not is_instance_valid(body) or not body.get_meta("parked",false):
		return
	_wake_debris(body)
	body.linear_velocity = velocity.limit_length(4)*.25

func _sync_batches(force_all: bool = false) -> void:
	if rebuilding or not batched:
		return
	if force_all:
		for record in batch_records:
			render_dirty[record.body.get_instance_id()] = record
	last_render_body_visits = render_dirty.size()
	for id in render_dirty.keys():
		var record: Dictionary = render_dirty[id]
		var transform: Transform3D = record.body.transform
		if record.body.freeze or record.body.sleeping:
			render_dirty.erase(id)
		if transform == record.last and record.visible == record.body.visible:
			continue
		var visibility_changed: bool = record.visible != record.body.visible
		record.last = transform
		record.visible = record.body.visible
		for item in record.instances:
			if visibility_changed:
				var visible_count: int = item.node.get_meta("visible_count") + (1 if record.visible else -1)
				item.node.set_meta("visible_count",visible_count)
				item.node.visible = visible_count > 0
			item.batch.set_instance_transform(item.index,_batch_transform(record.body,item.local))

func _check_batches() -> void:
	if not batched:
		return
	_sync_batches() # Verification must not repair a missing active/dirty entry.
	var count = 0
	for record in batch_records:
		for item in record.instances:
			var actual: Transform3D = item.batch.get_instance_transform(item.index)
			var expected: Transform3D = _batch_transform(record.body,item.local)
			if DisplayServer.get_name() != "headless" and not actual.is_equal_approx(expected):
				push_error("Batch transform mismatch: actual=%s expected=%s" % [actual,expected])
				get_tree().quit(1)
				return
			assert(not item.source.visible,"no duplicate draws")
			count += 1
	assert(count == batch_mesh_count and count > 250,"all architecture retained")

func _prepare_wall_fragments(body: RigidBody3D) -> void:
	# Prewarm shared geometry at scene load; no mesh triangulation during a blast.
	var size: Vector3 = body.get_meta("section_size")
	var tiles: Array = []
	var tile_size = Vector3(size.x/4.0,size.y/5.0,size.z)
	for row in range(5):
		for col in range(4):
			var center = Vector3(-size.x*.5+(col+.5)*tile_size.x,-size.y*.5+(row+.5)*tile_size.y,0)
			var tile = {"center":center,"size":tile_size,"decor":[]}
			_bevel_mesh(tile_size)
			for child in body.get_children():
				if not child is MeshInstance3D or child.position == Vector3.ZERO:
					continue
				var decor_size: Vector3 = child.get_meta("box_size")
				var lo = child.position-decor_size*.5
				var hi = child.position+decor_size*.5
				# Outer tiles retain sills that extend beyond the panel edge.
				lo.x = maxf(lo.x,center.x-tile_size.x*.5) if col > 0 else lo.x
				hi.x = minf(hi.x,center.x+tile_size.x*.5) if col < 3 else hi.x
				lo.y = maxf(lo.y,center.y-tile_size.y*.5) if row > 0 else lo.y
				hi.y = minf(hi.y,center.y+tile_size.y*.5) if row < 4 else hi.y
				if hi.x-lo.x < .004 or hi.y-lo.y < .004:
					continue
				var clipped_size = hi-lo
				_bevel_mesh(clipped_size)
				tile.decor.append({"size":clipped_size,"at":(hi+lo)*.5-center,"color":child.get_meta("box_color"),"metallic":child.get_meta("box_metallic")})
			tiles.append(tile)
	body.set_meta("fracture_tiles",tiles)

func _pool_wall_fragments(body: RigidBody3D) -> void:
	var fragments: Array[RigidBody3D] = []
	for tile in body.get_meta("fracture_tiles"):
		var chunk = piece("WallFragment",tile.size,Vector3.ZERO,body.get_meta("section_color"))
		chunk.transform = body.transform * Transform3D(Basis.IDENTITY,tile.center)
		initial_transforms[chunk.get_instance_id()] = chunk.global_transform
		for decor in tile.decor:
			visual(chunk,decor.size,decor.at,decor.color,decor.metallic)
		pieces.erase(chunk)
		chunk.hide()
		chunk.collision_layer = 0
		chunk.collision_mask = 0
		chunk.set_meta("panel_center",tile.center)
		chunk.set_meta("wall_panel",body)
		pooled_fragments.append(chunk)
		fragments.append(chunk)
	body.set_meta("pooled_fragments",fragments)

func _breach_wall(body: RigidBody3D, at: Vector3, passage: bool = false) -> int:
	var hit_local = body.to_local(at)
	var parent_transform = body.transform
	var detached = 0
	var first_hit = not body.get_meta("fracture_active",false)
	var hit_count: int = body.get_meta("hit_count",0)
	var candidates: Array = []
	for chunk in body.get_meta("pooled_fragments"):
		var center: Vector3 = chunk.get_meta("panel_center")
		if first_hit:
			chunk.show()
			chunk.collision_layer = 1
			chunk.collision_mask = 3
			pieces.append(chunk)
			_queue_render(chunk)
		if chunk.get_meta("detached",false):
			continue
		# Roughly a one-metre breach, not the full 2 x 2.6 metre wall module.
		var distance_to_hit = Vector2(center.x-hit_local.x,center.y-hit_local.y).length()
		var selected = distance_to_hit < minf(1.5,.63+hit_count*.28)
		if passage:
			selected = absf(center.x) < .51+hit_count*.28 and center.y < .9
		if selected:
			candidates.append({"body":chunk,"distance":distance_to_hit})
	candidates.sort_custom(func(a,b): return a.distance < b.distance)
	for candidate in candidates:
		if detached >= (8 if first_hit and passage else 4):
			break
		var chunk: RigidBody3D = candidate.body
		var center: Vector3 = chunk.get_meta("panel_center")
		var outward = parent_transform.basis.z.normalized()
		var spread = parent_transform.basis.x * (center.x-hit_local.x)*.18
		_release(chunk,at,3.8,(outward+spread+Vector3.UP*.12).normalized())
		detached += 1
	if first_hit:
		pieces.erase(body)
		initial_transforms.erase(body.get_instance_id())
		body.hide()
		_queue_render(body)
		for child in body.get_children():
			if child is CollisionShape3D:
				child.disabled = true
	body.set_meta("fracture_active",true)
	body.set_meta("hit_count",hit_count+1)
	# Keep the retired parent/pool render slots; no allocations/rebatching at impact.
	body.collision_layer = 0
	body.collision_mask = 0
	_sync_batches()
	return detached

func _build_environment() -> void:
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	var sky = Sky.new()
	var atmosphere = ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("738eaf")
	atmosphere.sky_horizon_color = Color("c6cfce")
	atmosphere.ground_bottom_color = Color("484c46")
	atmosphere.ground_horizon_color = Color("bec7c7")
	sky.sky_material = atmosphere
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = .65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env_node.environment = env
	add_child(env_node)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53,-35,0)
	sun.light_color = Color("fff0d8")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	static_box(Vector3(90,.30,90),Vector3(0,-.22,0),Color("79836f"))
	static_box(Vector3(22,.24,18),Vector3(0,-.03,0),Color("b8b3a2"))
	static_box(Vector3(8.5,.22,6.5),Vector3(0,.19,0),Color("d8d0b9"))
	static_box(Vector3(70,.04,7),Vector3(0,-.05,13),Color("535d59"))
	for i in range(-7,8):
		visual(self,Vector3(2,.012,.09),Vector3(i*4,.01,13),Color("d8d1ac"))
	for x in [-7.4,7.4]:
		for z in [-5.5,4.7]:
			_tree(Vector3(x,.1,z))
	for x in [-6.2,6.6]:
		var bench = Node3D.new()
		add_child(bench)
		bench.position = Vector3(x,.15,6.2)
		for z in [-.16,.04,.24]:
			visual(bench,Vector3(1.7,.10,.15),Vector3(0,.43,z),Color("80634b"))
		for sx in [-.64,.64]:
			visual(bench,Vector3(.09,.47,.48),Vector3(sx,.22,.02),DARK)
		visual(bench,Vector3(1.7,.34,.10),Vector3(0,.83,-.22),Color("80634b"))
	flash = OmniLight3D.new()
	flash.light_color = Color("ffb76b")
	flash.light_energy = 0
	flash.omni_range = 12
	add_child(flash)
	camera = Camera3D.new()
	camera.fov = 46
	camera.near = .10
	add_child(camera)
	camera.current = true

func _tree(at: Vector3) -> void:
	visual(self,Vector3(.3,2.0,.3),at+Vector3(0,1,0),Color("6e5d43"))
	for i in range(3):
		var mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 1.06-i*.13
		sphere.height = .98
		sphere.radial_segments = 16
		sphere.rings = 8
		mesh.mesh = sphere
		mesh.material_override = mat(Color("526f55").lightened(i*.055))
		add_child(mesh)
		mesh.position = at+Vector3(0,2.0+i*.62,0)

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left",28)
	margin.add_theme_constant_override("margin_top",24)
	margin.add_theme_constant_override("margin_right",28)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(margin)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var title = Label.new()
	title.text = "МАФИОЗИ  /  ПОЛИГОН РАЗРУШЕНИЙ"
	title.add_theme_color_override("font_color",Color("eadbbd"))
	title.add_theme_color_override("font_shadow_color",Color("182521"))
	title.add_theme_constant_override("shadow_offset_x",1)
	title.add_theme_constant_override("shadow_offset_y",1)
	title.add_theme_font_size_override("font_size",25)
	column.add_child(title)
	var sub = Label.new()
	sub.text = "ПАЛАЦЦО  •  Камень, латунь и стекло  •  Отдельная тестовая сцена"
	sub.add_theme_color_override("font_color",Color("eadbbd"))
	sub.add_theme_color_override("font_shadow_color",Color("182521"))
	sub.add_theme_constant_override("shadow_offset_x",1)
	sub.add_theme_constant_override("shadow_offset_y",1)
	column.add_child(sub)
	stats = Label.new()
	stats.add_theme_color_override("font_color",Color("eadbbd"))
	stats.add_theme_color_override("font_shadow_color",Color("182521"))
	stats.add_theme_constant_override("shadow_offset_x",1)
	stats.add_theme_constant_override("shadow_offset_y",1)
	column.add_child(stats)
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -148
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_bottom = -20
	var style = StyleBoxFlat.new()
	style.bg_color = Color("203432")
	style.border_color = BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation",9)
	panel.add_child(layout)
	status = Label.new()
	status.text = "Здание цело. ЛКМ по фасаду — взрыв в выбранной точке."
	status.add_theme_color_override("font_color",Color("eadbbd"))
	layout.add_child(status)
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation",12)
	layout.add_child(buttons)
	for data in [["1   Пробить проход",_entry_blast], ["2   Обрушить здание",collapse], ["R   Восстановить",reset_building], ["TAB   Пройти самому",_toggle_walk]]:
		var button = Button.new()
		button.text = data[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(220,38)
		button.pressed.connect(data[1])
		button.disabled = capture_mode or qa_mode
		action_buttons.append(button)
		buttons.add_child(button)
	var hint = Label.new()
	hint.text = "ЛКМ — точечный взрыв • TAB — ходьба/обзор • WASD — идти • C — присесть • ПКМ + мышь — смотреть"
	hint.add_theme_font_size_override("font_size",14)
	hint.add_theme_color_override("font_color",Color("b5c5bd"))
	layout.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if capture_mode or qa_mode:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(10,distance-1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(36,distance+1)
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var from = camera.project_ray_origin(event.position)
			var query = PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(event.position)*100)
			query.collision_mask = 1 # Loose debris cannot steal clicks from the wall.
			var hit = get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider is RigidBody3D and hit.collider in pieces:
				explode(hit.position,3.0,hit.collider)
	if event is InputEventMouseMotion and dragging:
		if walk_mode:
			walk_yaw -= event.relative.x*.005
			walk_pitch = clampf(walk_pitch-event.relative.y*.005,-1.25,1.25)
		else:
			yaw -= event.relative.x*.007
			pitch = clampf(pitch+event.relative.y*.006,.12,1.12)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _entry_blast()
			KEY_2: collapse()
			KEY_R: reset_building()
			KEY_TAB: _toggle_walk()
	_update_camera()

func _update_camera() -> void:
	if walk_mode and is_instance_valid(walker):
		camera.position = walker.position + Vector3(0,walker_shape.height-.18,0)
		camera.rotation = Vector3(walk_pitch,walk_yaw,0)
		camera.fov = 70
		return
	camera.fov = 46
	var target = Vector3(0,2.1,0)
	camera.position = target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(target)

func _entry_blast() -> void:
	explode(Vector3(1,1.2,3.2),3.2,null,true)

func _toggle_walk() -> void:
	walk_mode = not walk_mode
	walker_visual.visible = not walk_mode
	_update_camera()
	status.text = "WASD — пройти через пробоину. Обломки легко раздвигаются. TAB — общий вид." if walk_mode else "Общий вид. 1 — пробить проход; TAB — проверить его персонажем."

func _build_walker() -> void:
	walker = CharacterBody3D.new()
	walker.name = "PassageTestCharacter"
	walker.collision_layer = 4
	walker.collision_mask = 1 # Loose debris is pushed, never a solid character blocker.
	walker.floor_snap_length = .42
	add_child(walker)
	walker.position = Vector3(1,.12,6.5)
	walker_shape = CapsuleShape3D.new()
	walker_shape.radius = .28
	walker_shape.height = 1.72
	shove_query = PhysicsShapeQueryParameters3D.new()
	var shove_shape = CapsuleShape3D.new()
	shove_shape.radius = .52
	shove_shape.height = 1.80
	shove_query.shape = shove_shape
	shove_query.collision_mask = 2
	stand_query = PhysicsShapeQueryParameters3D.new()
	var stand_shape = CapsuleShape3D.new()
	stand_shape.radius = .28
	stand_shape.height = 1.72
	stand_query.shape = stand_shape
	stand_query.collision_mask = 1
	push_ray = PhysicsRayQueryParameters3D.new()
	push_ray.collision_mask = 1
	support_query = PhysicsShapeQueryParameters3D.new()
	support_query.shape = BoxShape3D.new()
	support_query.collision_mask = 2
	var collision = CollisionShape3D.new()
	collision.name = "Capsule"
	collision.shape = walker_shape
	collision.position.y = .86
	walker.add_child(collision)
	walker_visual = Node3D.new()
	walker.add_child(walker_visual)
	visual(walker_visual,Vector3(.48,.62,.26),Vector3(0,1.08,0),Color("294033"))
	visual(walker_visual,Vector3(.33,.34,.31),Vector3(0,1.56,0),Color("bcae8c"))
	for side in [-1,1]:
		visual(walker_visual,Vector3(.15,.62,.19),Vector3(side*.14,.43,0),Color("303633"))
		visual(walker_visual,Vector3(.14,.56,.17),Vector3(side*.31,1.02,0),Color("294033"))

func _walk_step(delta: float) -> void:
	if not is_instance_valid(walker):
		return
	var wish = walk_test_input if walk_testing else Vector3.ZERO
	if walk_mode and not capture_mode and not qa_mode:
		var keys = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		wish = Basis(Vector3.UP,walk_yaw)*Vector3(keys.x,0,keys.y).limit_length(1)
		var crouching = Input.is_physical_key_pressed(KEY_C)
		var desired_height = 1.05 if crouching else 1.72
		if desired_height != walker_shape.height and (desired_height < walker_shape.height or _can_stand()):
			walker_shape.height = desired_height
			walker.get_node("Capsule").position.y = desired_height*.5
	var speed = 2.5 if walker_shape.height > 1.2 else 1.4
	walker.velocity.x = wish.x*speed
	walker.velocity.z = wish.z*speed
	if not walker.is_on_floor():
		walker.velocity.y -= 9.8*delta
	else:
		walker.velocity.y = -.1
	var travel = Vector3(walker.velocity.x,0,walker.velocity.z)*delta
	if walker.is_on_floor() and travel.length_squared() > .000001 and walker.test_move(walker.transform,travel):
		var raised = walker.transform.translated(Vector3.UP*.38)
		if not walker.test_move(walker.transform,Vector3.UP*.38) and not walker.test_move(raised,travel):
			walker.position.y += .38
	var before_move = walker.position
	walker.move_and_slide()
	var moved = walker.position-before_move
	moved.y = 0
	if moved.length_squared() > .000001:
		_push_debris((moved/maxf(delta,.001)).limit_length(1.0),delta)
	if walk_mode:
		_update_camera()

func _can_stand() -> bool:
	stand_query.transform = Transform3D(Basis.IDENTITY,walker.position+Vector3(0,.88,0))
	return get_world_3d().direct_space_state.intersect_shape(stand_query,1).is_empty()

func _push_debris(direction: Vector3, delta: float) -> void:
	shove_query.shape.height = walker_shape.height+.08
	shove_query.transform = Transform3D(Basis.IDENTITY,walker.position+Vector3(0,walker_shape.height*.5,0)+direction*.16)
	for hit in get_world_3d().direct_space_state.intersect_shape(shove_query,24):
		var body = hit.collider as RigidBody3D
		if body == null or not body.get_meta("detached",false):
			continue
		# Don't remotely push a fragment on the other side of an intact thin wall.
		push_ray.from = walker.position+Vector3.UP*.7
		push_ray.to = body.global_position
		if not get_world_3d().direct_space_state.intersect_ray(push_ray).is_empty():
			continue
		var away = body.global_position-walker.position
		away.y = 0
		var wanted = direction*2.1+away.normalized()*.9
		var horizontal = Vector3(body.linear_velocity.x,0,body.linear_velocity.z)
		_wake_debris(body)
		body.apply_central_impulse((wanted-horizontal).limit_length(3.2)*body.mass*minf(1,delta*12))
		body.set_meta("pushed_by_walker",true)

func _release(body: RigidBody3D, at: Vector3, power: float, exit_direction: Vector3 = Vector3.ZERO) -> void:
	if not is_instance_valid(body):
		return
	body.freeze = false
	body.set_meta("detached",true)
	_wake_debris(body)
	body.collision_layer = 2
	body.collision_mask = 3
	var size: Vector3 = body.get_meta("section_size")
	body.mass = clampf(size.x*size.y*size.z*.7,.12,3.0)
	body.physics_material_override.friction = .32
	var delta = body.global_position-at
	delta.y = maxf(.4,delta.y*.4+1.0)
	var direction = delta.normalized() if exit_direction == Vector3.ZERO else exit_direction
	# A freshly changed PhysicsServer mass is committed on the next physics tick.
	# Set the initial blast velocity directly so activation never uses stale mass.
	body.linear_velocity = direction*power
	# A mass-scaled torque explodes angular speed on tiny fragments (small inertia).
	# Use the same modest initial tumble irrespective of the fragment's size.
	body.angular_velocity = Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))*1.15

func explode(at: Vector3, radius: float, target: RigidBody3D = null, passage: bool = false) -> void:
	var started_usec = Time.get_ticks_usec()
	if rebuilding or collapsing:
		return
	# Repeated hits expand only the same panel, never switch to a distant neighbour.
	if target == null:
		var nearest = radius
		for body in wall_panels:
			var d = body.global_position.distance_to(at)
			if d < nearest:
				nearest = d
				target = body
	if target != null and target.has_meta("wall_panel"):
		target = target.get_meta("wall_panel")
	if target == null or not target.freeze:
		status.text = "Этот участок уже разрушен. Выберите другую стену; R — восстановить."
		return
	blast_serial += 1
	var detached = 1
	if target.has_meta("fracture_tiles"):
		detached = _breach_wall(target,at,passage)
	else:
		_release(target,at,2.2)
	if detached == 0:
		status.text = "Здесь уже свободно. Для новой пробоины выберите другую часть стены."
		return
	_dust(at)
	flash.position = at+Vector3(0,1,0)
	flash.light_energy = 3
	status.text = "Локальная пробоина: %d небольших фрагментов. Остальная стена и дом стоят." % detached
	last_blast_cpu_usec = Time.get_ticks_usec()-started_usec

func collapse() -> void:
	if rebuilding or collapsing:
		return
	collapsing = true
	var generation = rebuild_generation
	_dust(Vector3(0,1.1,0))
	status.text = "Обрушение: нижний ярус → фасады → перекрытие и крыша."
	for level in [0,1,2]:
		await get_tree().create_timer(.65).timeout
		if generation != rebuild_generation:
			return
		for body in pieces:
			if body.freeze and not body.get_meta("detached",false) and body.position.y < [2.9,5.6,20.0][level]:
				_release(body,Vector3(0,-1,0),1.5 if level < 2 else .8)
		_dust(Vector3(0,1.1+level*1.6,0))
	status.text = "Обрушение завершено. R — восстановить дом и попробовать другой взрыв."

func reset_building() -> void:
	if rebuilding:
		return
	rebuilding = true
	rebuild_generation += 1
	rng.seed = 7302026
	collapsing = false
	building.queue_free()
	await get_tree().process_frame
	_build_building()
	rebuilding = false
	flash.light_energy = 0
	for particles in dust_pool:
		particles.emitting = false
		particles.visible = false
	dragging = false
	if is_instance_valid(walker):
		walker.position = Vector3(1,.12,6.5)
		walker.velocity = Vector3.ZERO
		walk_yaw = 0
		walk_pitch = -.10
		walker_shape.height = 1.72
		walker.get_node("Capsule").position.y = .86
		_update_camera()

func _build_dust_pool() -> void:
	for i in range(4):
		var particles = _make_dust()
		dust_pool.append(particles)
		# Prepare particle draw pipelines during loading, below the opaque pavement.
		particles.position = Vector3(0,-3,0)
		particles.emitting = true

func _make_dust() -> CPUParticles3D:
	var particles = CPUParticles3D.new()
	particles.amount = 32
	particles.one_shot = true
	particles.explosiveness = .94
	particles.lifetime = 1.55
	particles.direction = Vector3.UP
	particles.spread = 105
	particles.initial_velocity_min = 1.1
	particles.initial_velocity_max = 3.6
	particles.gravity = Vector3(0,-.85,0)
	particles.scale_amount_min = .12
	particles.scale_amount_max = .42
	var sphere = SphereMesh.new()
	sphere.radius = .55
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	particles.mesh = sphere
	var dust_mat = StandardMaterial3D.new()
	dust_mat.albedo_color = Color(.69,.62,.49,.34)
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particles.material_override = dust_mat
	var gradient = Gradient.new()
	gradient.set_color(0,Color(1,1,1,.46))
	gradient.set_color(1,Color(1,1,1,0))
	particles.color_ramp = gradient
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.emitting = false
	return particles

func _dust(at: Vector3) -> void:
	var particles = dust_pool[dust_cursor % dust_pool.size()]
	dust_cursor += 1
	particles.position = at
	particles.visible = true
	particles.restart()
	particles.emitting = true

func _process(delta: float) -> void:
	_sync_batches()
	var now = Time.get_ticks_usec()
	if not perf_phase.is_empty():
		if not perf_samples.has(perf_phase):
			perf_samples[perf_phase] = []
			perf_draw_calls[perf_phase] = []
		if last_frame_usec > 0:
			perf_samples[perf_phase].append((now-last_frame_usec)/1000.0)
			perf_draw_calls[perf_phase].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	last_frame_usec = now
	flash.light_energy = maxf(0,flash.light_energy-delta*28)
	status_clock += delta
	if status_clock > .25:
		status_clock = 0
		var active = 0
		var broken = 0
		for body in pieces:
			if is_instance_valid(body) and body.get_meta("detached",false):
				broken += 1
				if not body.freeze and not body.sleeping:
					active += 1
		stats.text = "%d секций  •  Отделено: %d  •  В движении: %d  •  %d FPS" % [pieces.size(),broken,active,Engine.get_frames_per_second()]

func _physics_process(delta: float) -> void:
	if rebuilding:
		return
	_walk_step(delta)
	_wake_supported_rubble()
	for id in active_debris.keys():
		var body: RigidBody3D = active_debris[id]
		if body.freeze or body.sleeping:
			active_debris.erase(id)
			continue
		# Keep swept collision for every moving fragment, including thin floor slabs.
		# Parked bodies cost no dynamic integration, so CCD needn't be weakened.

func _run_qa() -> void:
	await get_tree().physics_frame
	var total = pieces.size()
	assert(total > 50 and total <= 110,"bounded native debris count")
	for body in pieces:
		assert(body.freeze and body.get_child_count() >= 2)
	_check_batches()
	explode(Vector3(1,1.5,3.2),3.2)
	await get_tree().create_timer(.45).timeout
	var local_count = 0
	for body in pieces:
		if not body.freeze:
			local_count += 1
	assert(local_count >= 2 and local_count <= 6,"local blast removes only a small patch of one wall")
	var exited_wall = 0
	for body in pieces:
		if not body.freeze:
			var origin: Transform3D = initial_transforms[body.get_instance_id()]
			if body.global_position.z-origin.origin.z > .35:
				exited_wall += 1
	assert(exited_wall == local_count,"every entry fragment exits outward: opening is actually clear")
	assert(pieces.size() == total+19,"only the struck module splits into twenty small fragments")
	explode(Vector3(1,1.5,3.2),3.2)
	for body in pieces:
		if body.name.begins_with("Roof") or body.name.begins_with("Cornice"):
			assert(body.freeze,"local damage leaves structure intact")
	var expanded_count = pieces.filter(func(p): return not p.freeze).size()
	assert(expanded_count > local_count and expanded_count <= local_count+4,"repeat blast locally widens the same panel by at most four pieces")
	assert(pieces.size() == total+19,"repeat hit reuses the same fragments without node growth")
	_check_batches()
	collapse()
	await get_tree().create_timer(5.0).timeout
	var moved = 0
	for body in pieces:
		assert(body.get_meta("detached",false) and body.global_position.is_finite())
		assert(body.global_position.y > -.8,"ground collision holds falling rubble")
		var original: Transform3D = initial_transforms[body.get_instance_id()]
		if body.global_position.distance_to(original.origin) > .15:
			moved += 1
	assert(moved > total*.6,"pieces actually move under physics")
	_check_batches()
	reset_building()
	await get_tree().create_timer(.2).timeout
	assert(pieces.size() == total)
	for body in pieces:
		assert(body.freeze)
	# Reset during a pending collapse must cancel its delayed releases.
	collapse()
	reset_building()
	await get_tree().create_timer(2.3).timeout
	for body in pieces:
		assert(body.freeze,"old collapse cannot damage rebuilt building")
	_check_batches()
	# Every facade orientation uses the same local-space damage rule.
	var wall_targets = pieces.filter(func(p): return p.has_meta("fracture_tiles"))
	var walls_checked = 0
	for wall in wall_targets:
		var before_count = pieces.filter(func(p): return not p.freeze).size()
		var hit = wall.to_global(Vector3(0,.12,.24))
		explode(hit,3.0,wall)
		var released = pieces.filter(func(p): return not p.freeze).size()-before_count
		assert(released >= 2 and released <= 6,"all walls: bounded local breach")
		for other in wall_targets:
			if is_instance_valid(other) and other != wall and other in pieces:
				assert(other.freeze,"neighbouring wall stays intact")
		walls_checked += 1
		await get_tree().process_frame
	_check_batches()
	reset_building()
	await get_tree().create_timer(.2).timeout
	assert(pieces.size() == total)
	print("DESTRUCTION_QA_PASS ",JSON.stringify({"sections":total,"local_detached":local_count,"moved":moved,"reset":true,"mid_collapse_reset":true,"batched":batched,"meshes":batch_mesh_count,"groups":batch_group_count}))
	print("LOCAL_WALL_QA_PASS walls=",walls_checked)
	get_tree().quit(0)

func _capture_sequence() -> void:
	await get_tree().create_timer(5.0).timeout
	perf_phase = "intact"
	await get_tree().create_timer(2.0).timeout
	perf_phase = ""
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://intact.png")
	# Screenshot readback/PNG encoding is not gameplay work. Drain its frame before
	# starting the next measurement; otherwise it masquerades as a first-hit hitch.
	await get_tree().process_frame
	await get_tree().process_frame
	perf_phase = "local_breach_including_first_split"
	# Exercise the actual entrance button connection, not only the damage helper.
	action_buttons[0].pressed.emit()
	await get_tree().create_timer(1.5).timeout
	perf_phase = ""
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://partial.png")
	await get_tree().process_frame
	await get_tree().process_frame
	perf_phase = "collapse"
	collapse()
	await get_tree().create_timer(6.0).timeout
	perf_phase = "rubble"
	await get_tree().create_timer(2.0).timeout
	perf_phase = ""
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://destroyed.png")
	var report = {"scope":"Isolated 97-section showcase, not city performance", "engine":Engine.get_version_info().string, "renderer":"forward_plus", "batched":batched, "fps_cap":60, "clock":"Time.get_ticks_usec wall clock", "viewport":get_viewport().get_visible_rect().size, "sections":pieces.size(), "batched_meshes":batch_mesh_count,"batch_groups":batch_group_count,"phases":{}, "static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
	report["screenshot_io_excluded"] = true
	report["local_blast_cpu_ms"] = last_blast_cpu_usec/1000.0
	for key in perf_samples:
		var values: Array = perf_samples[key]
		values.sort()
		var calls: Array = perf_draw_calls[key]
		calls.sort()
		report.phases[key] = {"frames":values.size(), "frame_ms_p50":values[int(values.size()*.5)], "frame_ms_p95":values[mini(values.size()-1,int(values.size()*.95))],"frame_ms_max":values.back(),"draw_calls_p50":calls[int(calls.size()*.5)]}
	var output = FileAccess.open("res://performance_%s.json" % ("batched" if batched else "unbatched"),FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	reset_building()
	capture_mode = false
	for button in action_buttons:
		button.disabled = false
	print("DESTRUCTION_CAPTURE_READY")
	if "--quit-after-capture" in OS.get_cmdline_user_args():
		get_tree().quit()

func _run_walk_qa() -> void:
	walk_testing = true
	walker.position = Vector3(1,.12,4.5)
	walk_test_input = Vector3.FORWARD
	for i in range(100):
		await get_tree().physics_frame
	assert(walker.position.z > 3.35,"intact wall blocks the actual capsule")
	var blocked_position = walker.position
	# A piece just behind the intact facade must not react to walking into the wall.
	var behind: RigidBody3D = pooled_fragments[0]
	behind.show()
	behind.global_transform = Transform3D(Basis.IDENTITY,Vector3(1,.58,2.70))
	behind.set_meta("detached",true)
	behind.set_meta("parked",true)
	behind.collision_layer = 2
	behind.collision_mask = 3
	behind.freeze = true
	_queue_render(behind)
	var behind_start = behind.position
	for i in range(30):
		await get_tree().physics_frame
	assert(not behind.get_meta("pushed_by_walker",false) and behind.position.distance_to(behind_start) < .01,"blocked walking never pushes rubble through intact walls")
	walk_test_input = Vector3.ZERO
	reset_building()
	await get_tree().create_timer(.25).timeout
	walker.position = blocked_position
	_entry_blast()
	await get_tree().create_timer(.6).timeout
	var released = pieces.filter(func(p): return not p.freeze)
	assert(released.size() == 8,"passage is a narrow floor-connected hole, not whole facade")
	walk_test_input = Vector3.FORWARD
	for i in range(120):
		await get_tree().physics_frame
	assert(walker.position.z < 2.3 and walker.position.y > .2,"standing character really walks inside through breach")
	var inside_position = walker.position
	if DisplayServer.get_name() != "headless":
		walk_test_input = Vector3.ZERO
		walk_mode = true
		walk_yaw = PI
		walker_visual.hide()
		_update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://walkthrough.png")
		walk_mode = false
		walk_yaw = 0
		walker_visual.show()
		_update_camera()
	walk_test_input = Vector3.BACK
	for i in range(150):
		await get_tree().physics_frame
	print("WALK_ROUTE ",blocked_position," -> ",inside_position," -> ",walker.position)
	assert(walker.position.z > 3.7,"passage is traversable in reverse too")
	walk_test_input = Vector3.ZERO
	# Put a sleeping loose piece in the path: it must wake and move, not block actor.
	var test_piece: RigidBody3D = released[0]
	test_piece.global_position = Vector3(1,.36,5.0)
	test_piece.linear_velocity = Vector3.ZERO
	test_piece.angular_velocity = Vector3.ZERO
	test_piece.sleeping = true
	walker.position = Vector3(1,.12,6.2)
	walker.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var before = test_piece.position
	walk_test_input = Vector3.FORWARD
	for i in range(120):
		await get_tree().physics_frame
	assert(test_piece.get_meta("pushed_by_walker",false),"actor wakes and pushes sleeping rubble")
	assert(test_piece.position.distance_to(before) > .4,"light debris actually moves away")
	assert(walker.position.z < 2.5,"rubble never forms an invisible character barrier")
	walk_test_input = Vector3.ZERO
	var pool_count = pooled_fragments.size()
	var node_count = building.get_child_count()
	reset_building()
	await get_tree().create_timer(.3).timeout
	assert(pooled_fragments.size() == pool_count and pieces.size() == 97,"reset restores bounded reusable pool")
	_check_batches()
	print("WALK_DEBRIS_QA_PASS ",JSON.stringify({"intact_blocked":blocked_position,"inside":inside_position,"passage_pieces":8,"sleeping_debris_pushed":true,"bidirectional":true,"pool":pool_count,"building_nodes":node_count}))
	get_tree().quit()
