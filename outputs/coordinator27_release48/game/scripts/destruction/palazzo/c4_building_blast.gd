extends Node
## Local game-only charge consumption. Never fabricates an RPG terminal.
const RPG_TILES_PER_HIT:=4
const CHARGE_MULTIPLIER:=12
const EXPECTED_POWER:=1920.0
const EXPECTED_RADIUS:=3.2
const BlastFX45=preload("blast_fx45.gd")
var _fx45: Node3D
var _world: WeakRef
var _sites: Callable
var _events: Array[Dictionary]=[]
var _pending: Array[Dictionary]=[]
var _dispatch: Dictionary={}
var _dispatch_applied:=false

func configure(world: Node3D,site_provider: Callable) -> bool:
	if _world!=null or not is_instance_valid(world) or not world.is_inside_tree() or not site_provider.is_valid(): return false
	_world=weakref(world); _sites=site_provider
	world.add_child(self); name="C4BuildingBlast"
	_fx45=BlastFX45.new()
	var fx_ready: Dictionary=_fx45.configure(world)
	if not fx_ready.get("ok",false):
		_fx45.free(); _fx45=null; _world=null; _sites=Callable(); world.remove_child(self); return false
	set_physics_process(false)
	return true

func detonate(event: Dictionary) -> Dictionary:
	var world: Variant=_world.get_ref() if _world!=null else null
	var equipment: Variant=event.get("equipment_owner")
	if not is_instance_valid(world) or not world.is_inside_tree() or not equipment is Node or not is_instance_valid(equipment) or not equipment.is_inside_tree() or world.get("preview_c4")!=equipment or not world.is_ancestor_of(equipment) or not equipment.has_method("consume_detonation"): return {"ok":false,"reason":"current_native_equipment_required"}
	if _pending.size()>=8: return {"ok":false,"reason":"pending_charge_limit"}
	# Numeric profile is shared with the emitted AND consumed equipment contract.
	# Reject an incomplete root integration before consuming the physical charge.
	if event.get("damage")!=EXPECTED_POWER or event.get("power")!=EXPECTED_POWER or event.get("radius")!=EXPECTED_RADIUS: return {"ok":false,"reason":"c4_profile45_mismatch"}
	var consumed: Dictionary=equipment.consume_detonation(event)
	if not consumed.get("ok",false): return consumed
	var receipt: Dictionary=consumed.receipt
	# All selected physical charges are consumed before the first one changes a
	# wall. Adjacent charges therefore survive the same remote button press.
	var targets: Array[Dictionary]=[]
	for site: Node3D in _sites.call():
		if is_instance_valid(site) and site.is_inside_tree() and site.site_ready and not site.rebuilding:
			targets.append({"site":weakref(site),"generation":site.rebuild_generation,"frame":site.global_transform})
	_pending.append({"receipt":receipt,"targets":targets})
	set_physics_process(true)
	return {"ok":true,"consumed":true,"queued":true,"event_id":receipt.event_id}

func _physics_process(_delta: float) -> void:
	var world: Variant=_world.get_ref() if _world!=null else null
	if not is_instance_valid(world) or not world.is_inside_tree(): _pending.clear(); set_physics_process(false); return
	if _pending.is_empty(): set_physics_process(false); return
	var pending: Dictionary=_pending.pop_front()
	_dispatch=pending.receipt; _dispatch_applied=false
	_apply_consumed(_dispatch,pending.targets)
	_dispatch={}; _dispatch_applied=false
	if _pending.is_empty(): set_physics_process(false)

func current_charge_dispatch(receipt: Dictionary) -> bool:
	return not _dispatch.is_empty() and is_same(_dispatch,receipt) and receipt.get("consumed")==true

func _apply_consumed(receipt: Dictionary,targets: Array[Dictionary]) -> Dictionary:
	# Only the exact native dequeue owns this one-use apply. Keep dispatch current
	# during application so the glass owner can validate its same receipt.
	if not Thread.is_main_thread() or not current_charge_dispatch(receipt) or _dispatch_applied: return {"ok":false,"reason":"current_unapplied_consumed_dispatch_required"}
	_dispatch_applied=true
	var position: Vector3=receipt.position
	var radius: float=receipt.radius
	# Every authentic consumed charge has visible FX, including world-owned props
	# or ground with zero nearby Palazzo bodies. Cosmetic API issues no receipts.
	var visual: Dictionary=_fx45.emit_blast(position,receipt.normal,receipt.power,radius) if is_instance_valid(_fx45) else {"ok":false,"reason":"fx_owner_ended"}
	var candidates: Array[Dictionary]=[]
	for target: Dictionary in targets:
		var site: Variant=target.site.get_ref()
		if not is_instance_valid(site) or not site.is_inside_tree() or not site.site_ready or site.rebuilding or site.collapsing: continue
		# J starts a new building generation. Old queued blasts cannot damage it.
		if site.rebuild_generation!=target.generation or site.global_transform!=target.frame: continue
		if is_instance_valid(site.get("_glazing")):
			site._glazing.apply_consumed_charge(self,receipt)
		# Resolve the actual material closest to this physical planted charge.
		# Prewarmed tile activation allocates no new rigid bodies during a blast.
		for body: RigidBody3D in site.pieces.duplicate():
			if not _intact(site,body): continue
			var near: Dictionary=_closest(body,position)
			if not near.ok or near.distance>radius: continue
			var children: Array=[]
			if body.has_meta("pooled_fragments") and not body.get_meta("fracture_active",false) and site.has_method("_support_expand_piece"):
				children=site._support_expand_piece(body)
			if children.is_empty(): children=[body]
			for part: RigidBody3D in children:
				if not _intact(site,part): continue
				near=_closest(part,position)
				if near.ok and near.distance<=radius: candidates.append({"site":site,"body":part,"distance":near.distance,"point":near.point})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.distance<b.distance)
	var released: Array[int]=[]
	var affected: Dictionary={}
	var launch_evidence: Array[Dictionary]=[]
	for target: Dictionary in candidates:
		if released.size()>=RPG_TILES_PER_HIT*CHARGE_MULTIPLIER: break
		if released.has(target.body.get_instance_id()) or not _intact(target.site,target.body): continue
		var direction: Vector3=(target.body.global_position-position).normalized()
		if direction.length_squared()<.001: direction=receipt.normal
		var local_direction: Vector3=target.site.global_basis.inverse()*direction
		# Near field is sqrt(12/6)x frozen960 speed (2x energy for the same body).
		# Pressure fades continuously to half-speed at the edge; no uniform kick.
		var depth: float=clampf(1.0-target.distance/radius,0.0,1.0)
		var speed: float=3.8*sqrt(float(CHARGE_MULTIPLIER))*lerpf(.5,1.0,depth*depth*(3.0-2.0*depth))
		target.site._release(target.body,position,speed,local_direction)
		launch_evidence.append({"body_id":target.body.get_instance_id(),"distance":target.distance,"initial_speed_m_s":speed})
		released.append(target.body.get_instance_id()); affected[target.site.source_id]=target.site
	for site: Node3D in affected.values():
		if site.has_method("_mark_structure_dirty"): site._mark_structure_dirty()
		elif site.get("_structure")!=null: site._structure.mark_dirty()
	# The shared FX pool already owns flash/fire/smoke/dust once per charge.
	var result: Dictionary={"ok":true,"committed":true,"event_id":receipt.event_id,"weapon_id":"c4","damage":receipt.damage,"power":receipt.power,"radius":radius,"strength_multiplier":CHARGE_MULTIPLIER,"direct_fragment_budget":RPG_TILES_PER_HIT*CHARGE_MULTIPLIER,"released":released,"launch_evidence":launch_evidence,"visual":visual,"affected_houses":affected.keys(),"physical_charge_consumed":true}
	_events.append(result.duplicate(true)); if _events.size()>64: _events.pop_front()
	return result

func _intact(site: Node3D,body: Variant) -> bool:
	return is_instance_valid(body) and body is RigidBody3D and site.owns_collider(body) and body.freeze and (body.collision_layer&1)!=0 and not body.get_meta("detached",false)

func _closest(body: RigidBody3D,position: Vector3) -> Dictionary:
	var closest: Vector3=Vector3.ZERO
	var distance: float=INF
	for node: Node in body.get_children():
		if not node is CollisionShape3D or node.disabled or not node.shape is BoxShape3D: continue
		var point: Vector3=node.to_local(position)
		var half: Vector3=node.shape.size*.5
		point=point.clamp(-half,half)
		var at: Vector3=node.to_global(point)
		var d: float=at.distance_to(position)
		if d<distance: distance=d; closest=at
	return {"ok":is_finite(distance),"distance":distance,"point":closest}

func snapshot() -> Dictionary:
	return {"events":_events.duplicate(true),"pending":_pending.size(),"strength_multiplier":CHARGE_MULTIPLIER,"expected_power":EXPECTED_POWER,"expected_radius":EXPECTED_RADIUS,"fx":_fx45.snapshot() if is_instance_valid(_fx45) else {}}

func dispose() -> void:
	set_physics_process(false); _pending.clear(); _dispatch={}; _sites=Callable(); _world=null
	_dispatch_applied=false
	if is_instance_valid(_fx45): _fx45.dispose()
	_fx45=null
	if is_inside_tree(): queue_free()

func _exit_tree() -> void:
	# The pool is a world sibling for world-space smoke; keep its owner lifetime.
	if is_instance_valid(_fx45): _fx45.dispose()
	_fx45=null
