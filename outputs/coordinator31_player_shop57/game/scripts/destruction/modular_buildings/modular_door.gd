extends Node3D
## One state adapter per interior leaf. The accepted DoorClose43 v5 owns native
## sweeps, initiator-only exceptions, safe rollback/hold and cleanup unchanged.
const DoorClose = preload("res://scripts/destruction/palazzo/door_close43.gd")
const ACTOR_LAYER := 2
var _host: WeakRef
var _generation := -1
var door_id := ""
var building: Node3D
var rebuild_generation := -1
var site_status := "intact"
var _door: RigidBody3D
var _door_closed := Transform3D.IDENTITY
var _door_hinge := Vector3.ZERO
var _door_angle := 0.0
var _door_open := false
var _door_target_open := false
var _door_tween: Tween
var _controller: RefCounted
var _retired := false

func configure(host: Node3D, leaf: RigidBody3D, id: String) -> void:
	_host = weakref(host); _generation = int(host.rebuild_generation)
	rebuild_generation = _generation; building = host.building
	_door = leaf; door_id = id; _door_closed = leaf.transform
	_door_hinge = _door_closed.origin-_door_closed.basis.x*float(leaf.get_meta("section_size").x)*.5
	# Real pin axis lies on the leaf's near face. The leftmost corner then
	# stays inside the aperture throughout the entire positive 0..90° arc.
	_door_hinge -= _door_closed.basis.z*float(leaf.get_meta("section_size").z)*.5
	_controller = DoorClose.new(self)
	set_physics_process(false)

func _owner() -> Node3D:
	return _host.get_ref() as Node3D if _host != null else null

func _door_available() -> bool:
	var host: Node3D = _owner()
	return not _retired and is_instance_valid(host) and host.is_inside_tree() and host.site_ready and not host.rebuilding and not host.collapsing and int(host.rebuild_generation)==_generation and is_instance_valid(_door) and not _door.is_queued_for_deletion() and host.owns_collider(_door) and not _door.get_meta("detached",false) and not _door.get_meta("fracture_active",false)

func get_prompt(actor: Node3D) -> Dictionary:
	if not _door_available() or not actor is CharacterBody3D or not actor.is_inside_tree() or actor.get_world_3d()!=get_world_3d(): return {"available":false,"door_id":door_id}
	var frame: Transform3D = building.global_transform*_door_closed
	var size: Vector3 = _door.get_meta("section_size")
	var local_actor: Vector3 = frame.affine_inverse()*actor.global_position
	var nearest: Vector3 = frame*Vector3(clampf(local_actor.x,-size.x*.5,size.x*.5),clampf(local_actor.y,-size.y*.5,size.y*.5),0)
	var distance: float = actor.global_position.distance_to(nearest)
	var prompt: Dictionary = {"available":false,"door_id":door_id,"distance":distance,"open":_door_open,"busy":_controller.active(),"text":"Закрыть дверь" if _door_open else "Открыть дверь"}
	if distance>3.0 or _controller.active(): return prompt
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or camera.get_world_3d()!=get_world_3d(): return prompt
	var screen: Vector2 = get_viewport().get_visible_rect().get_center()
	var origin: Vector3 = camera.project_ray_origin(screen)
	var inverse: Transform3D = frame.affine_inverse()
	var local_origin: Vector3 = inverse*origin
	var local_direction: Vector3 = inverse.basis*camera.project_ray_normal(screen)
	if absf(local_direction.z)<.000001: return prompt
	var along: float = -local_origin.z/local_direction.z
	if along<=0: return prompt
	var hit: Vector3 = local_origin+local_direction*along
	if absf(hit.x)>size.x*.5 or absf(hit.y)>size.y*.5: return prompt
	var target: Vector3 = frame*Vector3(hit.x,hit.y,0)
	var capsule: CollisionShape3D = actor.get_node_or_null("PlayerCapsule") as CollisionShape3D
	if not is_instance_valid(capsule) or capsule.disabled or not capsule.shape is CapsuleShape3D: return prompt
	if not _visible(origin,target,actor) or not _visible(capsule.global_position,target,actor): return prompt
	prompt.available = true; prompt.target = target
	return prompt

func _visible(origin: Vector3, target: Vector3, actor: CollisionObject3D) -> bool:
	if origin.distance_squared_to(target)<.000001: return true
	var excluded: Array[RID] = [actor.get_rid(),_door.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(origin,target,0xFFFFFFFF,excluded)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func interact(actor: CharacterBody3D) -> Dictionary:
	if not get_prompt(actor).get("available",false): return {"ok":false,"reason":"interior_door_not_available"}
	var result: Dictionary = _controller.begin(actor,not _door_open)
	if result.get("ok",false): set_physics_process(true)
	return result

func _door_pose(angle: float) -> Transform3D:
	var rotation := Basis(Vector3.UP,angle)
	return Transform3D(rotation*_door_closed.basis,_door_hinge+rotation*(_door_closed.origin-_door_hinge))

func _move_door(angle: float) -> void:
	_controller.move(angle)

func _door43_commit(angle: float) -> void:
	if not _door_available(): return
	_door_angle = angle; _door.transform = _door_pose(angle)
	var host: Node3D = _owner()
	host._queue_render(_door); host._mark_structure_dirty()

func _door_finished() -> void:
	_controller.finish()
	if not _controller.active(): set_physics_process(false)

func _physics_process(delta: float) -> void:
	if _controller == null:
		set_physics_process(false); return
	if _controller.active(): _controller.tick(delta)
	# A blocked tween can enter hold/rollback; active() remains true there.
	# Only the accepted helper's actual idle state disables these callbacks.
	if not _controller.active(): set_physics_process(false)

func retire() -> void:
	if _controller != null: _controller.retire()
	if is_instance_valid(_door_tween): _door_tween.kill()
	_retired = true; set_physics_process(false)

func _exit_tree() -> void:
	retire()
