extends RefCounted
## Read-only observer. No scene, body, population, camera or input mutations.
const FIELDS := ["frame_ms","process_ms","physics_ms","draw_calls","render_primitives","static_bytes","static_peak_bytes","video_bytes","node_count","resource_count","physics_active_objects","physics_collision_pairs","physics_islands"]
const MONITORS := [Performance.TIME_PROCESS,Performance.TIME_PHYSICS_PROCESS,Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,Performance.MEMORY_STATIC,Performance.MEMORY_STATIC_MAX,Performance.RENDER_VIDEO_MEM_USED,Performance.OBJECT_NODE_COUNT,Performance.OBJECT_RESOURCE_COUNT,Performance.PHYSICS_3D_ACTIVE_OBJECTS,Performance.PHYSICS_3D_COLLISION_PAIRS,Performance.PHYSICS_3D_ISLAND_COUNT]

static func vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

static func frame(value: Transform3D) -> Dictionary:
	return {"origin":vector(value.origin),"x":vector(value.basis.x),"y":vector(value.basis.y),"z":vector(value.basis.z)}

static func camera_state(player: CharacterBody3D,camera: Camera3D,site: Node3D) -> Dictionary:
	return {"frame":frame(camera.global_transform),"actor_local":vector(site.to_local(player.global_position)),"fov":camera.fov,"near":camera.near,"far":camera.far,"yaw":player._camera_yaw,"pitch":player._camera_pitch}

static func settings(viewport: Window) -> Dictionary:
	var result: Dictionary={}
	for item: Dictionary in ProjectSettings.get_property_list():
		var key: String=str(item.name)
		if key.begins_with("rendering/") or key.begins_with("display/window/") or key.begins_with("physics/"): result[key]=ProjectSettings.get_setting(key)
	result.renderer=RenderingServer.get_current_rendering_method(); result.vsync=DisplayServer.window_get_vsync_mode()
	result.window_size=str(DisplayServer.window_get_size()); result.viewport=str(viewport.get_visible_rect().size)
	result.max_fps=Engine.max_fps; result.time_scale=Engine.time_scale; result.physics_ticks=Engine.physics_ticks_per_second
	return result

static func population(game: Node3D) -> Dictionary:
	var owner: RefCounted=game.get("preview_population")
	var rows: Array=[]; var ids: Array[String]=[]; var actors: Array[Dictionary]=[]; var live:=0; var hp:=0
	if owner!=null:
		if owner.get("residents")!=null: rows=owner.residents.snapshot().get("rows",[])
		var contacts: Array=owner.get("hit_owners"); hp=contacts.size()
		for contact: RefCounted in contacts:
			if not contact._current(contact.get("_binding")).is_empty(): live+=1
	for row: Dictionary in rows:
		ids.append(str(row.source_id)); actors.append({"id":row.source_id,"position":vector(row.position) if row.position is Vector3 else null,"generation":row.life_generation,"status":row.status})
	ids.sort()
	var block: Dictionary=game.get("_block")
	return {"ids":ids,"actors":actors,"hp_owners":hp,"live_hp_owners":live,"legacy_buildings":block.buildings.size(),"decor":block.decor.size(),"water_status":game.get("water_status")}

static func geometry(site: Node3D) -> Dictionary:
	# The production ready signal calls this BEFORE the first support update.
	# Stable owner order avoids generated names/instance IDs in cross-run hashes.
	var rows: Array[Dictionary]=[]; var missing:=0; var shapes:=0
	var bodies: Array[PhysicsBody3D]=[]
	for ref: WeakRef in site._owned_bodies.values():
		var body: Variant=ref.get_ref()
		if is_instance_valid(body): bodies.append(body)
		else: missing+=1
	for node: Node in site.find_children("*","StaticBody3D",true,false): bodies.append(node)
	for body: PhysicsBody3D in bodies:
		var collision: Array[Dictionary]=[]
		for child: Node in body.get_children():
			if not child is CollisionShape3D or child.shape==null: continue
			var shape: Shape3D=child.shape
			collision.append({"frame":frame(child.transform),"type":shape.get_class(),"size":vector(shape.size) if shape is BoxShape3D else null,"disabled":child.disabled})
			shapes+=1
		rows.append({"class":body.get_class(),"frame":frame(site.global_transform.affine_inverse()*body.global_transform),"layer":body.collision_layer,"mask":body.collision_mask,"frozen":body.freeze if body is RigidBody3D else true,"shapes":collision})
	return {"sha256":JSON.stringify(rows).sha256_text(),"body_count":bodies.size(),"shape_count":shapes,"missing":missing,"site_frame":frame(site.global_transform),"native_stats":site.get_stats(),"support":site._structure.diagnostics()}

static func physics_state(site: Node3D) -> Dictionary:
	var released: Array[int]=[]; var frozen: Array[Dictionary]=[]; var index:=0; var dynamic:=0; var awake:=0
	for ref: WeakRef in site._owned_bodies.values():
		var body: RigidBody3D=ref.get_ref()
		if not is_instance_valid(body): index+=1; continue
		if not body.freeze:
			dynamic+=1
			if not body.sleeping: awake+=1
		if body.get_meta("support_released",false) or body.get_meta("detached",false) or not body.freeze: released.append(index)
		else: frozen.append({"index":index,"frame":frame(body.transform),"layer":body.collision_layer,"mask":body.collision_mask})
		index+=1
	return {"released_indices":released,"frozen_sha256":JSON.stringify(frozen).sha256_text(),"dynamic":dynamic,"awake":awake,"support":site._structure.diagnostics(),"native_stats":site.get_stats()}

static func static_geometry_after_host(site: Node3D) -> Dictionary:
	# host.prepare installs three real Convex ramps AFTER the site's ready hook.
	# Capture those actual points as well as the other static pane/ground shapes.
	var rows: Array[Dictionary]=[]; var convex:=0; var unknown: Array[String]=[]
	for body: Node in site.find_children("*","StaticBody3D",true,false):
		var shapes: Array[Dictionary]=[]
		for child: Node in body.get_children():
			if not child is CollisionShape3D or child.shape==null: continue
			var data: Dictionary={"class":child.shape.get_class(),"frame":frame(child.transform),"disabled":child.disabled}
			if child.shape is BoxShape3D: data.size=vector(child.shape.size)
			elif child.shape is ConvexPolygonShape3D:
				var points: Array=[]
				for point: Vector3 in child.shape.points: points.append(vector(point))
				data.points=points; convex+=1
			else: unknown.append(str(child.get_path()))
			shapes.append(data)
		rows.append({"path":str(site.get_path_to(body)),"frame":frame(site.global_transform.affine_inverse()*body.global_transform),"layer":body.collision_layer,"mask":body.collision_mask,"shapes":shapes})
	return {"sha256":JSON.stringify(rows).sha256_text(),"convex_shapes":convex,"unknown_shapes":unknown,"rows":rows}

static func samples() -> Dictionary:
	var data: Dictionary={}
	for field: String in FIELDS: data[field]=PackedFloat64Array()
	return data

static func append_sample(data: Dictionary,wall_ms: float) -> void:
	data.frame_ms.append(wall_ms)
	for index: int in MONITORS.size():
		var value: float=Performance.get_monitor(MONITORS[index])
		if index<2: value*=1000.0
		data[FIELDS[index+1]].append(value)

static func summary(data: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for field: String in FIELDS:
		var values: PackedFloat64Array=data[field].duplicate(); values.sort()
		var count: int=values.size()
		if count>0: result[field]={"count":count,"p50":values[maxi(0,ceili(count*.5)-1)],"p95":values[maxi(0,ceili(count*.95)-1)],"max":values[count-1]}
	return result
