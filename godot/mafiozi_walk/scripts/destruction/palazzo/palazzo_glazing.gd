extends Node3D
## Native contacts are admitted by the host. This helper owns only its panes.
## Call break_for_wall BEFORE hiding/releasing the wall. On reset dispose this
## helper, rebuild the site, then configure a fresh helper for the new generation.
const WalkGlass = preload("res://scripts/destruction/modular30/owner/vendor/glass/walk_glass_breakage.gd")
const MAX_HELPERS := 8
const MAX_PANES := 256
const MAX_EVENTS := 2048
const SHARDS_PER_SITE := 24 # Eight live helpers have at most 192 shard slots.
const MAX_BREAKS_PER_TICK := 4
const THICKNESS := 0.015
const CONTACT_SLOP := 0.002
static var _helpers: Dictionary = {}
var _site: WeakRef
var _generation: int = -1
var _source_id := ""
var _site_frame := Transform3D.IDENTITY
var _glass: Node3D
var _material: StandardMaterial3D
var _panes: Dictionary = {}
var _meshes: Dictionary = {}
var _by_wall: Dictionary = {}
var _events: Dictionary = {}
var _queue: Array[Dictionary] = []
var _configured := false
var _disposed := false
var _broken := 0
var _rejected := 0

func configure(site: Node3D) -> bool:
	if _configured or _disposed or not is_instance_valid(site) or not site.is_inside_tree() or site.is_queued_for_deletion(): return false
	if not site.has_method("owns_collider") or not site.get("source_id") is String or str(site.get("source_id")).is_empty() or not site.get("rebuild_generation") is int: return false
	if get_parent()!=null and get_parent()!=site: return false
	var frame: Transform3D=site.global_transform
	if not _rigid(frame): return false
	for key: int in _helpers.keys():
		var other: Variant=_helpers[key].get_ref()
		if not is_instance_valid(other): _helpers.erase(key)
		elif other._site!=null and other._site.get_ref()==site: return false
	if _helpers.size()>=MAX_HELPERS: return false
	_site=weakref(site); _source_id=site.get("source_id"); _generation=site.get("rebuild_generation"); _site_frame=frame
	name="OwnedWindowGlazing"
	if get_parent()==null: site.add_child(self)
	transform=Transform3D.IDENTITY
	set_meta("source_id",_source_id); set_meta("building_id",_source_id)
	_material=WalkGlass._material(Color("b4dfdc"),0.22,0.0,0.08)
	_material.resource_name="Walk_Transparent_Glass_IOR_1_45"
	# Godot dielectric F0 = 0.08 * metallic_specular. Schlick F0 for IOR 1.45.
	_material.metallic_specular=pow((1.45-1.0)/(1.45+1.0),2.0)/0.08
	_material.set_meta("ior",1.45); _material.set_meta("breakableGlass",true)
	_glass=WalkGlass.new(); add_child(_glass)
	if not _glass.configure({"max_shards":SHARDS_PER_SITE,"shards_per_hit":24,"max_decorated_panels":80,"ground_y":frame.origin.y+0.035}):
		_glass.free(); _glass=null; return false
	_glass.panel_fractured.connect(_on_fractured)
	_glass.fracture_rejected.connect(_on_rejected)
	_configured=true; _helpers[get_instance_id()]=weakref(self)
	set_physics_process(true)
	return true

static func _rigid(frame: Transform3D) -> bool:
	return frame.is_finite() and absf(frame.basis.determinant()-1.0)<0.00001 and frame.basis.is_equal_approx(frame.basis.orthonormalized())

func _current() -> bool:
	var site: Variant=_site.get_ref() if _site!=null else null
	return _configured and not _disposed and is_instance_valid(site) and site.is_inside_tree() and not site.is_queued_for_deletion() and get_parent()==site and site.global_transform==_site_frame and site.get("source_id")==_source_id and site.get("rebuild_generation")==_generation and not site.get("rebuilding")

## local_transform is relative to parent, usually the source wall. The resulting
## pane is parented HERE, not to the wall or its visual batching subtree.
func add_pane(parent: Node3D, local_transform: Transform3D, size: Vector2, wall: RigidBody3D) -> Dictionary:
	if not _current() or _panes.size()>=MAX_PANES: return {"ok":false,"reason":"owner_or_pane_budget"}
	var site: Node3D=_site.get_ref()
	if not is_instance_valid(parent) or not parent.is_inside_tree() or not (parent==site or site.is_ancestor_of(parent)) or not site.owns_collider(wall) or wall.get_meta("detached",false): return {"ok":false,"reason":"owned_wall_parent"}
	if not size.is_finite() or size.x<0.05 or size.y<0.05 or size.x>8.0 or size.y>8.0 or not _rigid(local_transform): return {"ok":false,"reason":"pane_dimensions"}
	var frame: Transform3D=global_transform.affine_inverse()*parent.global_transform*local_transform
	if not _rigid(frame): return {"ok":false,"reason":"unit_pane_frame"}
	var body:=StaticBody3D.new(); body.name="GlassPane_%03d"%_panes.size(); body.transform=frame
	body.collision_layer=1; body.collision_mask=0
	body.set_meta("source_id",_source_id); body.set_meta("building_id",_source_id); body.set_meta("material_class","glass"); body.set_meta("breakableGlass",true)
	var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(size.x,size.y,THICKNESS); shape.shape=box; body.add_child(shape)
	var mesh:=MeshInstance3D.new(); mesh.name="TransparentGlass"; mesh.set_meta("breakableGlass",true); mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var half:=size*0.5
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-half.x,-half.y,0),Vector3(half.x,-half.y,0),Vector3(half.x,half.y,0),Vector3(-half.x,half.y,0)])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
	# Godot front faces are clockwise; both triangles share one complete edge.
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,3,2])
	var geometry:=ArrayMesh.new(); geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); geometry.surface_set_material(0,_material)
	mesh.mesh=geometry; body.add_child(mesh); add_child(body)
	var id: int=body.get_instance_id()
	var row: Dictionary={"body":body,"mesh":mesh,"collision":shape,"shape":box,"wall":weakref(wall),"wall_local":wall.global_transform.affine_inverse()*body.global_transform,"wall_frame":wall.global_transform,"size":size,"frame":body.global_transform,"pending":false,"broken":false}
	_panes[id]=row; _meshes[mesh.get_instance_id()]=id
	if not _by_wall.has(wall.get_instance_id()): _by_wall[wall.get_instance_id()]=[]
	_by_wall[wall.get_instance_id()].append(id)
	if _glass.prepare(mesh)!=1:
		_panes.erase(id); _meshes.erase(mesh.get_instance_id()); _by_wall[wall.get_instance_id()].erase(id); body.free(); return {"ok":false,"reason":"walk_glass_prepare"}
	return {"ok":true,"collider":body,"mesh":mesh,"pane_id":id,"source_id":_source_id,"generation":_generation}

func owns_collider(body: Variant) -> bool:
	if not _current() or not body is StaticBody3D or not is_instance_valid(body) or body.is_queued_for_deletion() or body.get_parent()!=self or not _panes.has(body.get_instance_id()): return false
	var row: Dictionary=_panes[body.get_instance_id()]
	return row.body==body and not row.broken and body.collision_layer==1 and body.get_meta("source_id","")==_source_id and body.global_transform==row.frame

## Read-only proof of the original native pane contact. Pending glass remains a
## valid collider until Walk completes its delayed fracture; broken/stale panes
## and altered collision resources are rejected. Never substitutes a wall hit.
func validate_pane_contact(body: Variant,world_point: Vector3) -> Dictionary:
	if not world_point.is_finite() or not owns_collider(body): return {"ok":false,"reason":"exact_owned_pane_required"}
	var row: Dictionary=_panes[body.get_instance_id()]
	var collision: CollisionShape3D=row.collision
	var size: Vector3=Vector3(row.size.x,row.size.y,THICKNESS)
	if not is_instance_valid(collision) or collision.get_parent()!=body or collision.disabled or collision.transform!=Transform3D.IDENTITY or collision.shape!=row.shape or not collision.shape is BoxShape3D or collision.shape.size!=size: return {"ok":false,"reason":"pane_collision_changed"}
	var local: Vector3=collision.to_local(world_point)
	var half: Vector3=size*.5
	if absf(local.x)>half.x+CONTACT_SLOP or absf(local.y)>half.y+CONTACT_SLOP or absf(local.z)>half.z+CONTACT_SLOP: return {"ok":false,"reason":"contact_outside_pane"}
	return {"ok":true,"pane_id":body.get_instance_id(),"generation":_generation,"wall":row.wall.get_ref()}

func _event_error(event: Dictionary) -> String:
	if not _current(): return "owner_or_generation"
	if event.get("admitted")!=true or event.get("authority")!="local_preview" or event.get("server_authority",false)!=false: return "authority"
	if not event.get("event_id") is String or event.event_id.is_empty() or event.event_id.length()>200 or _events.has(event.event_id) or _events.size()>=MAX_EVENTS: return "event_id_or_budget"
	if event.has("generation") and event.generation!=_generation: return "stale_generation"
	if not event.get("position") is Vector3 or not event.position.is_finite() or not event.get("direction") is Vector3 or not event.direction.is_finite() or event.direction.length_squared()<0.000001: return "coordinates"
	var power: Variant=event.get("power")
	if not (power is int or power is float) or not is_finite(float(power)) or float(power)<=0.0 or float(power)>10000.0: return "power"
	return ""

func apply_bullet(event: Dictionary) -> Dictionary:
	var error:=_event_error(event)
	if not error.is_empty(): return {"ok":false,"reason":error}
	if event.get("scope")!="new_local_session_building_glass" or event.get("explosive")!=false or event.get("source_id")!=_source_id or event.get("weapon_id")=="rpg": return {"ok":false,"reason":"bullet_contract"}
	var body: Variant=event.get("collider")
	if not owns_collider(body): return {"ok":false,"reason":"exact_owned_pane_required"}
	var row: Dictionary=_panes[body.get_instance_id()]
	var local: Vector3=body.to_local(event.position); var half: Vector2=row.size*0.5
	if absf(local.x)>half.x+CONTACT_SLOP or absf(local.y)>half.y+CONTACT_SLOP or absf(local.z)>THICKNESS*0.5+CONTACT_SLOP: return {"ok":false,"reason":"contact_outside_pane"}
	if row.pending: return {"ok":false,"reason":"pane_already_pending"}
	_events[event.event_id]=true
	return _hit(row,event.position,event.direction,float(event.power),str(event.get("weapon_id","")))

func apply_blast(event: Dictionary) -> Dictionary:
	var error:=_event_error(event)
	if not error.is_empty(): return {"ok":false,"reason":error}
	var radius: Variant=event.get("radius")
	if event.get("scope")!="new_local_session_building_damage" or event.get("weapon_id")!="rpg" or event.get("explosive")!=true or not (radius is float or radius is int) or not is_finite(float(radius)) or float(radius)<=0.0 or float(radius)>11.0: return {"ok":false,"reason":"native_rpg_glass_contract"}
	return _area_blast(event.position,event.direction,float(event.power),float(radius),event.event_id,"rpg")

func apply_consumed_charge(owner: Node,receipt: Dictionary) -> Dictionary:
	if not _current() or not is_instance_valid(owner): return {"ok":false,"reason":"charge_owner"}
	var site: Node3D=_site.get_ref()
	var world: Node=site.get_parent()
	if owner!=world.get("preview_c4_blast") or not owner.has_method("current_charge_dispatch") or not owner.current_charge_dispatch(receipt): return {"ok":false,"reason":"consumed_charge_dispatch_required"}
	if receipt.get("weapon_id")!="c4" or receipt.get("scope")!="new_local_session_c4" or receipt.get("consumed")!=true or receipt.get("world_instance_id")!=world.get_instance_id(): return {"ok":false,"reason":"charge_contract"}
	if _events.has(receipt.event_id): return {"ok":false,"reason":"duplicate_charge"}
	return _area_blast(receipt.position,receipt.normal,receipt.power,receipt.radius,receipt.event_id,"c4")

func _area_blast(at: Vector3,direction: Vector3,power: float,radius: float,event_id: String,weapon: String) -> Dictionary:
	_events[event_id]=true
	var queued:=0; var occluded:=0
	for row: Dictionary in _panes.values():
		if row.broken or row.pending or not owns_collider(row.body): continue
		var local: Vector3=row.body.to_local(at); var half: Vector2=row.size*0.5
		var nearest: Vector3=row.body.to_global(Vector3(clampf(local.x,-half.x,half.x),clampf(local.y,-half.y,half.y),0))
		var delta: Vector3=nearest-at
		if delta.length_squared()>float(radius)*float(radius): continue
		if delta.length_squared()>0.000001:
			var query:=PhysicsRayQueryParameters3D.create(at,nearest,1|512)
			query.hit_from_inside=true
			var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.get("collider")!=row.body: occluded+=1; continue
		if _enqueue(row,nearest,delta.normalized() if delta.length_squared()>0.000001 else direction,power,weapon): queued+=1
	return {"ok":true,"queued":queued,"occluded":occluded,"generation":_generation}

func _enqueue(row: Dictionary, at: Vector3, direction: Vector3, power: float, weapon: String) -> bool:
	if row.broken or row.pending or _queue.size()>=MAX_PANES: return false
	row.pending=true
	_queue.append({"row":row,"at":at,"direction":direction,"power":power,"weapon":weapon})
	return true

func _hit(row: Dictionary, at: Vector3, direction: Vector3, power: float, weapon: String) -> Dictionary:
	if row.broken or not is_instance_valid(row.mesh): return {"ok":false,"reason":"pane_ended"}
	# The native box edge can return a side normal; the glass surface is XY.
	var local_direction: Vector3=row.mesh.global_basis.transposed()*direction.normalized()
	var normal: Vector3=Vector3.FORWARD if local_direction.z>0.0 else Vector3.BACK
	var result: Dictionary=_glass.hit({"object":row.mesh,"surface_index":0,"face_index":0,"position":at,"normal":normal},{"direction":direction.normalized(),"impulse":power,"weapon_id":weapon})
	row.pending=result.get("broken",false) and not row.broken
	return {"ok":result.get("broken",false),"pending":row.pending,"walk":result,"generation":_generation}

func break_for_wall(wall: RigidBody3D) -> Dictionary:
	if not _current() or not is_instance_valid(wall) or not _by_wall.has(wall.get_instance_id()): return {"ok":false,"reason":"wall_not_registered"}
	var queued:=0
	for id: int in _by_wall[wall.get_instance_id()]:
		var row: Dictionary=_panes[id]
		if row.wall.get_ref()!=wall: continue
		_sync_one(row,wall)
		if _enqueue(row,row.mesh.global_position,row.mesh.global_basis.z,20.0,"wall_release"): queued+=1
	return {"ok":true,"queued":queued}

func break_all() -> Dictionary:
	if not _current(): return {"ok":false,"reason":"owner_or_generation"}
	sync_moving_panes()
	var queued:=0
	for row: Dictionary in _panes.values():
		if _enqueue(row,row.mesh.global_position,row.mesh.global_basis.z,20.0,"full_house"): queued+=1
	return {"ok":true,"queued":queued}

func _sync_one(row: Dictionary, wall: RigidBody3D) -> void:
	if row.broken or wall.get_meta("detached",false) or not wall.freeze or wall.global_transform==row.wall_frame: return
	if not _rigid(wall.global_transform): return
	row.body.global_transform=wall.global_transform*row.wall_local
	row.frame=row.body.global_transform; row.wall_frame=wall.global_transform

## The original Palazzo door has glazing. Its panes remain separate from visual
## batches, but follow the still-intact owned door before the physics queries.
func sync_moving_panes() -> void:
	if not _current(): return
	var site: Node3D=_site.get_ref()
	for row: Dictionary in _panes.values():
		var wall: Variant=row.wall.get_ref()
		if is_instance_valid(wall) and site.owns_collider(wall): _sync_one(row,wall)

func _on_fractured(receipt: Dictionary) -> void:
	var mesh: Variant=receipt.get("object")
	if _disposed or not is_instance_valid(mesh) or not _meshes.has(mesh.get_instance_id()): return
	var row: Dictionary=_panes[_meshes[mesh.get_instance_id()]]
	if row.mesh!=mesh or row.broken: return
	row.broken=true; row.pending=false; _broken+=1
	# Retain the owned node for identity/history, but immediately stop collisions.
	row.body.collision_layer=0; row.body.collision_mask=0
	for child: Node in row.body.get_children():
		if child is CollisionShape3D: child.set_deferred("disabled",true)

func _on_rejected(receipt: Dictionary) -> void:
	var mesh: Variant=receipt.get("object")
	if _disposed or not is_instance_valid(mesh) or not _meshes.has(mesh.get_instance_id()): return
	_panes[_meshes[mesh.get_instance_id()]].pending=false; _rejected+=1

func _physics_process(dt: float) -> void:
	if not _current():
		if _configured and not _disposed: dispose()
		return
	sync_moving_panes()
	var started: int=Time.get_ticks_usec(); var count:=0
	while not _queue.is_empty() and count<MAX_BREAKS_PER_TICK and Time.get_ticks_usec()-started<1000:
		var request: Dictionary=_queue.pop_front()
		_hit(request.row,request.at,request.direction,request.power,request.weapon); count+=1
	_glass.advance(dt)

func stats() -> Dictionary:
	return {"ready":_current(),"source_id":_source_id,"generation":_generation,"panes":_panes.size(),"broken":_broken,"queued":_queue.size(),"rejected":_rejected,"walk":_glass.stats() if is_instance_valid(_glass) else {},"shard_slots_per_site":SHARDS_PER_SITE,"maximum_live_helpers":MAX_HELPERS,"maximum_total_shard_slots":MAX_HELPERS*SHARDS_PER_SITE}

func dispose() -> void:
	if _disposed: return
	_disposed=true; set_physics_process(false); _queue.clear()
	for row: Dictionary in _panes.values():
		if is_instance_valid(row.body): row.body.collision_layer=0; row.body.collision_mask=0
	if is_instance_valid(_glass): _glass.dispose()
	_helpers.erase(get_instance_id()); _events.clear()
	if is_inside_tree(): queue_free()

func _exit_tree() -> void:
	dispose()
