extends RefCounted
## Initiator-only swept-arc exemption in both directions; no actor pose writes.
const MAX_HITS := 32
const MAX_ANGLE_STEP := PI/36.0
const HOLD_INTERVAL := .10
const BLOCKED := 1
const INITIATOR := 2
var _site: WeakRef
var _actor: WeakRef
var _leaf: WeakRef
var _generation := -1
var _start_angle := 0.0
var _target_angle := 0.0
var _target_open := false
var _phase := "idle"
var _hold_elapsed := 0.0
var _parts: Array[Dictionary]=[]
var _added: Array[Dictionary]=[]
var _query := PhysicsShapeQueryParameters3D.new()

func _init(site: Node3D) -> void:
	_site=weakref(site)
	_query.collision_mask=0xFFFFFFFF
	site.tree_exiting.connect(dispose)

func active() -> bool:
	return _phase!="idle"

func _owner() -> Node3D:
	return _site.get_ref() as Node3D if _site!=null else null

func _body() -> CharacterBody3D:
	return _actor.get_ref() as CharacterBody3D if _actor!=null else null

func _current() -> bool:
	var site: Node3D=_owner()
	var leaf: Variant=_leaf.get_ref() if _leaf!=null else null
	return is_instance_valid(site) and site.is_inside_tree() and is_instance_valid(leaf) and leaf==site._door and site.rebuild_generation==_generation and site._door_available()

func _collect(site: Node3D) -> void:
	_parts.clear()
	_parts.append({"body":weakref(site._door),"relative":Transform3D.IDENTITY,"pane":false})
	var glazing: Node=site.get_node_or_null("OwnedWindowGlazing")
	if not is_instance_valid(glazing): return
	for child: Node in glazing.get_children():
		if not child is StaticBody3D: continue
		var proof: Dictionary=glazing.call("validate_pane_contact",child,child.global_position)
		if proof.get("ok",false) and proof.get("wall")==site._door:
			_parts.append({"body":weakref(child),"relative":site._door.global_transform.affine_inverse()*child.global_transform,"pane":true})

func _part_current(row: Dictionary) -> PhysicsBody3D:
	var body: Variant=row.body.get_ref()
	if not is_instance_valid(body) or body.is_queued_for_deletion(): return null
	if not row.pane: return body as PhysicsBody3D
	var site: Node3D=_owner()
	var glazing: Node=site.get_node_or_null("OwnedWindowGlazing")
	if not is_instance_valid(glazing): return null
	var proof: Dictionary=glazing.call("validate_pane_contact",body,body.global_position)
	return body as PhysicsBody3D if proof.get("ok",false) and proof.get("wall")==site._door else null

func _snapshot() -> Dictionary:
	# A proof lives only for this synchronous begin/move/finish/recover call.
	# No await, no retained snapshot and no shape/owner cache across frames.
	if not _current(): return {}
	var site: Node3D=_owner()
	var actor: CharacterBody3D=_body()
	var excluded: Array[RID]=[]
	var shapes: Array[Shape3D]=[]
	var locals: Array[Transform3D]=[]
	var bodies: Array[PhysicsBody3D]=[]
	for row: Dictionary in _parts:
		var body: PhysicsBody3D=_part_current(row)
		if not is_instance_valid(body):
			# Legitimately broken panes have no active collision. A remembered
			# pane that is still colliding but fails its proof cannot disappear
			# from the final-pose check merely because validation failed.
			var previous: Variant=row.body.get_ref()
			if is_instance_valid(previous) and previous.collision_layer!=0:
				for child: Node in previous.get_children():
					if child is CollisionShape3D and not child.disabled and child.shape!=null: return {}
			continue
		excluded.append(body.get_rid()); bodies.append(body)
		for child: Node in body.get_children():
			if not child is CollisionShape3D or child.disabled or child.shape==null: continue
			shapes.append(child.shape); locals.append(row.relative*child.transform)
	if shapes.is_empty(): return {}
	_query.exclude=excluded
	return {"site":site,"actor":actor,"frame":site.building.global_transform,"actor_layer":int(site.ACTOR_LAYER),"space":site.get_world_3d().direct_space_state,"shapes":shapes,"locals":locals,"bodies":bodies}

func _scan_pose(snapshot: Dictionary,angle: float) -> int:
	var site: Node3D=snapshot.site
	var pose: Transform3D=snapshot.frame*site._door_pose(angle)
	var shapes: Array[Shape3D]=snapshot.shapes
	var locals: Array[Transform3D]=snapshot.locals
	var space: PhysicsDirectSpaceState3D=snapshot.space
	var actor: CharacterBody3D=snapshot.actor
	var actor_layer: int=snapshot.actor_layer
	var found := 0
	for i: int in range(shapes.size()):
		_query.shape=shapes[i]; _query.transform=pose*locals[i]
		var hits: Array[Dictionary]=space.intersect_shape(_query,MAX_HITS)
		if hits.size()>=MAX_HITS: return BLOCKED
		for hit: Dictionary in hits:
			var collider: Variant=hit.get("collider")
			if not ((collider is CollisionObject3D and (collider.collision_layer&actor_layer)!=0) or collider is CharacterBody3D or (collider is RigidBody3D and (collider.collision_layer&(256|1024))!=0)): continue
			if collider==actor: found|=INITIATOR
			else: return BLOCKED
	# Finding the initiator never short-circuits: a later shape/hit may contain
	# another actor, or saturate the query. Every endpoint accepts only zero.
	return found

func _scan_path(snapshot: Dictionary,from: float,to: float,endpoint_result: int=-1) -> int:
	var count: int=maxi(1,int(ceil(absf(to-from)/MAX_ANGLE_STEP)))
	var found := 0
	for i: int in range(1,count+1):
		# The optional endpoint was checked earlier within this SAME synchronous
		# operation, before any state mutation/yield, so its result is identical.
		var scan: int=endpoint_result if i==count and endpoint_result>=0 else _scan_pose(snapshot,lerpf(from,to,float(i)/float(count)))
		if (scan&BLOCKED)!=0: return BLOCKED
		found|=scan
	return found

func begin(actor: CharacterBody3D,opening: bool) -> Dictionary:
	var site: Node3D=_owner()
	if active() or not is_instance_valid(site) or not is_instance_valid(actor): return {"ok":false,"reason":"door_busy_or_actor"}
	_actor=weakref(actor); _leaf=weakref(site._door); _generation=site.rebuild_generation
	_start_angle=site._door_angle; _target_open=opening; _target_angle=PI*.5 if opening else 0.0; _collect(site)
	var snapshot: Dictionary=_snapshot()
	if snapshot.is_empty() or _scan_pose(snapshot,_target_angle)!=0: _forget(); return {"ok":false,"reason":"door_sweep_blocked"}
	# Other actors block the whole movement path, even if the initiating player
	# alone occupies its middle. No NPC/other body is exempted from the query.
	var path: int=_scan_path(snapshot,_start_angle,_target_angle,0)
	if (path&BLOCKED)!=0: _forget(); return {"ok":false,"reason":"door_sweep_blocked"}
	if (path&INITIATOR)!=0:
		for body: PhysicsBody3D in snapshot.bodies: _add_pair(body,actor)
	_phase="moving"; site._door_target_open=_target_open
	site._door_tween=site.create_tween(); site._door_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	site._door_tween.tween_method(Callable(site,"_move_door"),_start_angle,_target_angle,.5)
	site._door_tween.finished.connect(Callable(site,"_door_finished"))
	return {"ok":true,"started":true,"opening":_target_open,"initiator_only_swing":not _added.is_empty()}

func _add_pair(body: PhysicsBody3D,actor: CharacterBody3D) -> void:
	var add_body: bool=not body.get_collision_exceptions().has(actor)
	var add_actor: bool=not actor.get_collision_exceptions().has(body)
	if add_body: body.add_collision_exception_with(actor)
	if add_actor: actor.add_collision_exception_with(body)
	_added.append({"body":weakref(body),"actor":weakref(actor),"added_body":add_body,"added_actor":add_actor})

func _remove_pairs() -> void:
	for pair: Dictionary in _added:
		var body: Variant=pair.body.get_ref(); var actor: Variant=pair.actor.get_ref()
		if not is_instance_valid(body) or not is_instance_valid(actor): continue
		if pair.added_body: body.remove_collision_exception_with(actor)
		if pair.added_actor: actor.remove_collision_exception_with(body)
	_added.clear()

func move(angle: float) -> void:
	if _phase!="moving": return
	if not _current(): retire(); return
	var site: Node3D=_owner()
	var actor: CharacterBody3D=_body()
	# Endpoint never excludes the initiator. Dynamic intrusion aborts before
	# this tick moves the leaf. Every intermediate step still tests other actors.
	var snapshot: Dictionary=_snapshot()
	if not is_instance_valid(actor) or snapshot.is_empty() or _scan_pose(snapshot,_target_angle)!=0:
		_abort(); return
	var path: int=_scan_path(snapshot,site._door_angle,angle,0 if angle==_target_angle else -1)
	if (path&BLOCKED)!=0 or ((path&INITIATOR)!=0 and _added.is_empty()): _abort(); return
	site._door43_commit(angle)

func finish() -> void:
	if _phase!="moving": return
	var site: Node3D=_owner()
	var snapshot: Dictionary=_snapshot()
	if snapshot.is_empty() or _scan_pose(snapshot,_target_angle)!=0: _abort(); return
	site._door43_commit(_target_angle); site._door_open=_target_open; site._door_target_open=_target_open
	_remove_pairs(); _forget()

func _abort() -> void:
	var site: Node3D=_owner()
	if not is_instance_valid(site): dispose(); return
	if is_instance_valid(site._door_tween): site._door_tween.kill()
	site._door_open=site._door_angle>.001; site._door_target_open=site._door_open
	site.site_status="door_motion_blocked"
	_phase="hold"; _hold_elapsed=0.0
	_recover()

func _recover() -> void:
	if not _current(): retire(); return
	var site: Node3D=_owner()
	var snapshot: Dictionary=_snapshot()
	if snapshot.is_empty(): return
	# Remove our exceptions only at an actually clear current/end pose. If the
	# starting pose is also clear, return there only through a fresh safe path.
	if _scan_pose(snapshot,site._door_angle)==0: _remove_pairs(); _forget(); return
	if _scan_pose(snapshot,_start_angle)!=0: return
	var path: int=_scan_path(snapshot,site._door_angle,_start_angle,0)
	if (path&BLOCKED)==0 and ((path&INITIATOR)==0 or not _added.is_empty()):
		site._door43_commit(_start_angle); site._door_open=_start_angle>.001; site._door_target_open=site._door_open
		_remove_pairs(); _forget()
	# Otherwise hold still, keeping ONLY our initiator pairs. All other actors
	# still collide. No timeout removes an exception from overlapping bodies.

func tick(delta: float) -> void:
	if _phase!="hold": return
	_hold_elapsed+=delta
	if _hold_elapsed<HOLD_INTERVAL: return
	_hold_elapsed=0.0; _recover()

func retire() -> void:
	# Called synchronously before the old leaf's destruction/reset/exit path.
	# Old bodies become non-colliding before our symmetric pairs are removed.
	for row: Dictionary in _parts:
		var body: Variant=row.body.get_ref()
		if is_instance_valid(body): body.collision_layer=0; body.collision_mask=0
	_remove_pairs(); _forget()

func dispose() -> void:
	if active(): retire()
	else: _remove_pairs(); _forget()

func _forget() -> void:
	_phase="idle"; _actor=null; _leaf=null; _generation=-1; _parts.clear(); _hold_elapsed=0.0

func snapshot() -> Dictionary:
	return {"phase":_phase,"generation":_generation,"initiator_id":_body().get_instance_id() if is_instance_valid(_body()) else 0,"owned_exception_pairs":_added.size(),"parts":_parts.size(),"target_open":_target_open,"target_angle":_target_angle}
