extends RefCounted
## Candidate44: merged AABB/grid broad phase, exact orthogonal-box SAT contacts.
## One shape pair per work item keeps compound narrow phase resumable/bounded.
## ConvexPolygonShape bounds remain conservative; exact convex contact is not claimed.
## Host: configure after site ready; mark_dirty after each committed geometry
## change (including door motion completion); advance once per physics frame.
## Ground is real native geometry. No implicit y=0 plane or detached debris anchor.
## Local yaw AABBs use a .05m contact tolerance. Work is spatially indexed and
## resumes in bounded batches; unbounded house content is never silently omitted.
const CELL_M := 2.0
const SEAM_M := .05
const RELEASES_PER_FRAME := 8
var _site: WeakRef
var _ground: Array[WeakRef] = []
var _enabled := false
var _dirty := false
var _revision := 0
var _generation := -1
var _building_id := 0
var _job: Dictionary = {}
var _pending: Array = []
var _pending_cursor := 0
var _expanded: Array = []
var _expanded_cursor := 0
var _frame := Transform3D.IDENTITY
var _released_total := 0
var _last: Dictionary = {"state":"unconfigured"}
var _max_advance_usec := 0
var _advance_calls := 0
var _graphs := 0
var _error := ""
var _release_frame := -1
var _released_this_frame := 0
var _expanded_this_frame := 0
var _transferring := false

func configure(site: Node3D, options: Dictionary = {}) -> Dictionary:
	cancel()
	if not is_instance_valid(site) or not site.is_inside_tree() or site.get("site_ready")!=true or not site.has_method("owns_collider") or not site.has_method("_release") or not site.get("pieces") is Array: return {"ok":false,"reason":"ready_native_site_required"}
	var basis: Basis=site.global_basis
	if not site.global_transform.is_finite() or not basis.is_equal_approx(basis.orthonormalized()) or absf(basis.determinant()-1.0)>.00001 or not basis.y.is_equal_approx(Vector3.UP): return {"ok":false,"reason":"unit_upright_site_required"}
	_site=weakref(site); _frame=site.global_transform; _ground.clear()
	var bodies: Array=[]
	for name: String in ["OriginalFoundation","OriginalPlaza"]:
		var body: Node=site.get_node_or_null(NodePath(name))
		if body!=null:
			if not body is StaticBody3D or body.get_parent()!=site: return {"ok":false,"reason":"original_ground_identity"}
			bodies.append(body)
	var supplied: Variant=options.get("ground_bodies",[])
	if not supplied is Array: return {"ok":false,"reason":"explicit_ground_array"}
	for body: Variant in supplied:
		if not body is StaticBody3D or not is_instance_valid(body) or body.has_meta("source_id") or body.get_script()!=null: return {"ok":false,"reason":"explicit_native_terrain_required"}
		var bounds: Dictionary=_body_bounds(body,site)
		if not bounds.get("ok",false) or bounds.bounds.end.y>.02: return {"ok":false,"reason":"explicit_terrain_above_local_ground"}
		if not bodies.has(body): bodies.append(body)
	if bodies.is_empty(): return {"ok":false,"reason":"real_foundation_or_explicit_terrain_required"}
	for body: StaticBody3D in bodies:
		if not body.is_inside_tree() or body.get_world_3d().space!=site.get_world_3d().space or (body.collision_layer&1)==0: return {"ok":false,"reason":"ground_not_collidable"}
		var bounds: Dictionary=_body_bounds(body,site)
		if not bounds.get("ok",false): return {"ok":false,"reason":"unsupported_ground_collision","detail":bounds}
		_ground.append(weakref(body))
	_generation=int(site.rebuild_generation); _building_id=site.building.get_instance_id()
	_enabled=true; _error=""; _released_total=0; _graphs=0; _advance_calls=0; _max_advance_usec=0
	mark_dirty()
	_last={"state":"dirty"}
	return {"ok":true,"ground_bodies":_ground.size(),"contact_tolerance_m":SEAM_M,"grid_m":CELL_M,"release_limit_per_frame":RELEASES_PER_FRAME,"support_model":"ground_connected_collision_AABBs"}

func cancel() -> void:
	_revision+=1; _enabled=false; _dirty=false; _job.clear(); _pending.clear(); _pending_cursor=0; _expanded.clear(); _expanded_cursor=0
	_last={"state":"cancelled"}

func dispose() -> void:
	cancel(); _site=null; _ground.clear()

func is_transferring() -> bool:
	# The host's automatic dirty hook skips its OWN synchronous transfer
	# notification only. External shots/doors still call mark_dirty normally.
	return _transferring

func mark_dirty() -> void:
	_revision+=1; _dirty=true; _job.clear(); _pending.clear(); _pending_cursor=0; _expanded.clear(); _expanded_cursor=0

func _eligible(body: Variant, site: Node3D) -> bool:
	return body is RigidBody3D and is_instance_valid(body) and body.is_inside_tree() and not body.is_queued_for_deletion() and site.owns_collider(body) and body.freeze and (body.collision_layer&1)!=0 and not body.get_meta("detached",false) and not body.get_meta("parked",false)

func _body_bounds(body: CollisionObject3D, site: Node3D) -> Dictionary:
	var result:=AABB()
	var found:=false
	var contacts: Array[Dictionary]=[]
	for node: Node in body.get_children():
		if not node is CollisionShape3D or node.disabled or node.shape==null: continue
		var shape: Shape3D=node.shape
		var local:=AABB()
		if shape is BoxShape3D:
			local=AABB(-shape.size*.5,shape.size)
		elif shape is ConvexPolygonShape3D:
			var points: PackedVector3Array=shape.points
			if points.is_empty(): return {"ok":false,"reason":"empty_convex"}
			local=AABB(points[0],Vector3.ZERO)
			for point: Vector3 in points:
				if not point.is_finite(): return {"ok":false,"reason":"nonfinite_convex"}
				local=local.expand(point)
		else: return {"ok":false,"reason":"collision_shape_requires_explicit_bounds","shape":shape.get_class()}
		var transform: Transform3D=site.global_transform.affine_inverse()*node.global_transform
		if not transform.is_finite() or not local.position.is_finite() or not local.size.is_finite(): return {"ok":false,"reason":"nonfinite_collision"}
		var transformed: AABB=transform*local
		var contact: Dictionary={"kind":"convex_bounds","bounds":transformed}
		if shape is BoxShape3D:
			var scale: Vector3=Vector3(transform.basis.x.length(),transform.basis.y.length(),transform.basis.z.length())
			if scale.x<.000001 or scale.y<.000001 or scale.z<.000001: return {"ok":false,"reason":"degenerate_box_collision"}
			var axes: Array[Vector3]=[transform.basis.x/scale.x,transform.basis.y/scale.y,transform.basis.z/scale.z]
			if absf(axes[0].dot(axes[1]))>.00001 or absf(axes[0].dot(axes[2]))>.00001 or absf(axes[1].dot(axes[2]))>.00001: return {"ok":false,"reason":"sheared_box_collision_requires_adapter"}
			contact={"kind":"box","bounds":transformed,"center":transform.origin,"axes":axes,"half":shape.size*scale*.5}
		contacts.append(contact)
		result=result.merge(transformed) if found else transformed
		found=true
	return {"ok":found,"bounds":result,"contacts":contacts,"reason":"no_enabled_collision" if not found else ""}

func _span(bounds: AABB) -> Dictionary:
	var padded:=bounds.grow(SEAM_M)
	var lo:=Vector3i(floori(padded.position.x/CELL_M),floori(padded.position.y/CELL_M),floori(padded.position.z/CELL_M))
	var hi:=Vector3i(floori(padded.end.x/CELL_M),floori(padded.end.y/CELL_M),floori(padded.end.z/CELL_M))
	return {"lo":lo,"hi":hi,"at":lo,"done":false}

func _next_cell(span: Dictionary) -> void:
	var at: Vector3i=span.at
	at.x+=1
	if at.x>span.hi.x:
		at.x=span.lo.x; at.y+=1
		if at.y>span.hi.y:
			at.y=span.lo.y; at.z+=1
			if at.z>span.hi.z: span.done=true
	span.at=at

func _touch(a: AABB, b: AABB) -> bool:
	return a.position.x<=b.end.x+SEAM_M and a.end.x+SEAM_M>=b.position.x and a.position.y<=b.end.y+SEAM_M and a.end.y+SEAM_M>=b.position.y and a.position.z<=b.end.z+SEAM_M and a.end.z+SEAM_M>=b.position.z

func _shape_touch(a: Dictionary,b: Dictionary) -> bool:
	if not _touch(a.bounds,b.bounds): return false
	# This patch is exact for native BoxShape3D parts. It does not claim an exact
	# convex-polyhedron adapter; that existing conservative policy stays explicit.
	if a.kind!="box" or b.kind!="box": return true
	var axes: Array[Vector3]=[]
	axes.append_array(a.axes); axes.append_array(b.axes)
	for first: Vector3 in a.axes:
		for second: Vector3 in b.axes:
			var cross: Vector3=first.cross(second)
			if cross.length_squared()>.0000000001: axes.append(cross.normalized())
	var delta: Vector3=b.center-a.center
	for axis: Vector3 in axes:
		var radius_a: float=absf(axis.dot(a.axes[0]))*a.half.x+absf(axis.dot(a.axes[1]))*a.half.y+absf(axis.dot(a.axes[2]))*a.half.z
		var radius_b: float=absf(axis.dot(b.axes[0]))*b.half.x+absf(axis.dot(b.axes[1]))*b.half.y+absf(axis.dot(b.axes[2]))*b.half.z
		if absf(delta.dot(axis))>radius_a+radius_b+SEAM_M: return false
	return true

func _begin_contact(a: Dictionary,b: Dictionary,target: int,anchor: bool) -> void:
	_job.contact={"a":a.contacts,"b":b.contacts,"i":0,"j":0,"target":target,"anchor":anchor,"resume":_job.phase}
	_job.phase="contact"

func _contact_work() -> void:
	var test: Dictionary=_job.contact
	if test.i>=test.a.size():
		_job.phase=test.resume; _job.erase("contact"); return
	var a: Dictionary=test.a[test.i]
	var b: Dictionary=test.b[test.j]
	test.j+=1
	if test.j>=test.b.size(): test.j=0; test.i+=1
	_job.narrow_checks+=1
	if not _shape_touch(a,b): return
	if test.anchor and (b.bounds.end.y<a.bounds.position.y-SEAM_M or b.bounds.end.y>a.bounds.end.y+SEAM_M): return
	_job.supported[test.target]=true; _job.queue.append(test.target)
	if test.anchor: _job.anchor_entry+=1; _job.anchor_ground=0
	_job.phase=test.resume; _job.erase("contact")

func _start(site: Node3D) -> void:
	_job={"phase":"ground","revision":_revision,"ground_cursor":0,"ground":[],"input":site.pieces.duplicate(),"cursor":0,"entries":[],"grid":{},"queue":[],"queue_cursor":0,"supported":{},"anchor_entry":0,"anchor_ground":0,"active":-1,"neighbors":[],"neighbor_cursor":0,"seen":{},"checks":0,"narrow_checks":0,"validate":0,"unsupported":[],"started_usec":Time.get_ticks_usec(),"advance_calls":0}
	_dirty=false; _graphs+=1

func _bad(reason: String) -> void:
	_error=reason; _job.clear(); _pending.clear(); _pending_cursor=0; _expanded.clear(); _expanded_cursor=0; _dirty=false
	_last={"state":"invalid_geometry","reason":reason}

func _work(site: Node3D) -> void:
	var phase: String=_job.phase
	if phase=="ground":
		if _job.ground_cursor>=_ground.size(): _job.phase="collect"; return
		var body: Variant=_ground[_job.ground_cursor].get_ref()
		_job.ground_cursor+=1
		# A removed/disabled real ground ceases to anchor; never retain its ghost.
		if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or (body.collision_layer&1)==0: return
		var bounds: Dictionary=_body_bounds(body,site)
		if not bounds.ok: _bad("ground_collision_changed"); return
		_job.ground.append({"body":weakref(body),"bounds":bounds.bounds,"contacts":bounds.contacts,"frame":body.global_transform})
	elif phase=="collect":
		if _job.cursor>=_job.input.size(): _job.phase="anchor"; return
		var body: Variant=_job.input[_job.cursor]
		_job.cursor+=1
		if not _eligible(body,site): return
		var bounds: Dictionary=_body_bounds(body,site)
		if not bounds.ok: _bad("structural_collision:"+str(bounds.reason)); return
		var entry: Dictionary={"body":weakref(body),"frame":body.global_transform,"bounds":bounds.bounds,"contacts":bounds.contacts,"id":body.get_instance_id()}
		_job.entries.append(entry)
		_job.insert_index=_job.entries.size()-1; _job.span=_span(bounds.bounds); _job.phase="insert"
	elif phase=="insert":
		var key: Vector3i=_job.span.at
		if not _job.grid.has(key): _job.grid[key]=[]
		_job.grid[key].append(_job.insert_index)
		_next_cell(_job.span)
		if _job.span.done: _job.phase="collect"
	elif phase=="anchor":
		if _job.anchor_entry>=_job.entries.size(): _job.phase="walk"; return
		if _job.anchor_ground>=_job.ground.size(): _job.anchor_entry+=1; _job.anchor_ground=0; return
		var i: int=_job.anchor_entry
		var a: AABB=_job.entries[i].bounds
		var b: AABB=_job.ground[_job.anchor_ground].bounds
		var ground_index: int=_job.anchor_ground
		_job.anchor_ground+=1
		# Contact with the TOP of a real supporting ground solid, including the
		# original source floor that slightly intersects its underlying terrain.
		if _touch(a,b) and b.end.y>=a.position.y-SEAM_M and b.end.y<=a.end.y+SEAM_M:
			_begin_contact(_job.entries[i],_job.ground[ground_index],i,true)
	elif phase=="contact":
		_contact_work()
	elif phase=="walk":
		if _job.active<0:
			if _job.queue_cursor>=_job.queue.size(): _job.phase="validate_ground"; _job.validate=0; return
			_job.active=_job.queue[_job.queue_cursor]; _job.queue_cursor+=1
			_job.span=_span(_job.entries[_job.active].bounds); _job.seen={}; _job.neighbors=[]; _job.neighbor_cursor=0
			return
		if _job.neighbor_cursor<_job.neighbors.size():
			var other: int=_job.neighbors[_job.neighbor_cursor]; _job.neighbor_cursor+=1
			if _job.supported.has(other) or _job.seen.has(other): return
			_job.seen[other]=true; _job.checks+=1
			if _touch(_job.entries[_job.active].bounds,_job.entries[other].bounds): _begin_contact(_job.entries[_job.active],_job.entries[other],other,false)
			return
		if _job.span.done: _job.active=-1; return
		_job.neighbors=_job.grid.get(_job.span.at,[]); _job.neighbor_cursor=0
		_next_cell(_job.span)
	elif phase=="validate_ground":
		if _job.validate>=_job.ground.size(): _job.phase="validate"; _job.validate=0; return
		var ground: Dictionary=_job.ground[_job.validate]; _job.validate+=1
		var body: Variant=ground.body.get_ref()
		if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or (body.collision_layer&1)==0:
			mark_dirty(); return
		var bounds: Dictionary=_body_bounds(body,site)
		if not bounds.ok or bounds.bounds!=ground.bounds or bounds.contacts!=ground.contacts or body.global_transform!=ground.frame: mark_dirty(); return
	elif phase=="validate":
		if site.pieces.size()!=_job.input.size(): mark_dirty(); return
		if _job.validate>=_job.entries.size():
			_pending=_job.unsupported; _pending_cursor=0
			_last={"state":"releasing" if not _pending.is_empty() else "stable","candidates":_job.entries.size(),"supported":_job.supported.size(),"unsupported":_pending.size(),"neighbor_checks":_job.checks,"shape_pair_checks":_job.narrow_checks,"grid_cells":_job.grid.size(),"graph_advance_calls":_job.advance_calls,"graph_elapsed_usec":Time.get_ticks_usec()-int(_job.started_usec)}
			_job.clear(); return
		var i: int=_job.validate; _job.validate+=1
		var entry: Dictionary=_job.entries[i]
		var body: Variant=entry.body.get_ref()
		if not _eligible(body,site) or body.global_transform!=entry.frame: mark_dirty(); return
		var bounds: Dictionary=_body_bounds(body,site)
		if not bounds.ok or bounds.bounds!=entry.bounds or bounds.contacts!=entry.contacts: mark_dirty(); return
		if not _job.supported.has(i): _job.unsupported.append(entry)

func advance(delta: float, max_items: int = 256, budget_usec: int = 1000) -> Dictionary:
	var started:=Time.get_ticks_usec()
	if not _enabled: return diagnostics()
	var site: Variant=_site.get_ref() if _site!=null else null
	if not is_instance_valid(site) or not site.is_inside_tree() or site.is_queued_for_deletion(): cancel(); return diagnostics()
	if not is_finite(delta) or delta<=0 or delta>.25 or max_items<1 or budget_usec<1: return {"ok":false,"reason":"advance_budget"}
	_advance_calls+=1
	if site.rebuilding: _job.clear(); _pending.clear(); _pending_cursor=0; _expanded.clear(); _expanded_cursor=0; _dirty=true; _last={"state":"waiting_for_reset"}; return diagnostics()
	if not is_instance_valid(site.building): _bad("building_owner_missing"); return diagnostics()
	if int(site.rebuild_generation)!=_generation or site.building.get_instance_id()!=_building_id or site.global_transform!=_frame:
		_generation=int(site.rebuild_generation); _building_id=site.building.get_instance_id(); _frame=site.global_transform; mark_dirty()
	# Explicit manual full collapse already owns these releases. Wait for reset.
	if site.collapsing: _job.clear(); _pending.clear(); _pending_cursor=0; _expanded.clear(); _expanded_cursor=0; _last={"state":"manual_collapse_owned"}; return diagnostics()
	if _dirty and _job.is_empty(): _start(site)
	if not _job.is_empty(): _job.advance_calls+=1
	var work:=0
	while not _job.is_empty() and work<max_items and Time.get_ticks_usec()-started<budget_usec:
		_work(site); work+=1
	var released:=0
	var revision:=_revision
	var physics_id:=int(Engine.get_physics_frames())
	if physics_id!=_release_frame: _release_frame=physics_id; _released_this_frame=0; _expanded_this_frame=0
	while _job.is_empty() and not _dirty and (_pending_cursor<_pending.size() or _expanded_cursor<_expanded.size()) and _released_this_frame<RELEASES_PER_FRAME:
		var chunk_queue: bool=_expanded_cursor<_expanded.size()
		var entry: Dictionary=_expanded[_expanded_cursor] if chunk_queue else _pending[_pending_cursor]
		var body: Variant=entry.body.get_ref()
		if not _eligible(body,site):
			if chunk_queue: _expanded_cursor+=1
			else: _pending_cursor+=1
			continue
		var bounds: Dictionary=_body_bounds(body,site)
		if body.global_transform!=entry.frame or not bounds.ok or bounds.bounds!=entry.bounds or bounds.contacts!=entry.contacts: mark_dirty(); break
		if not chunk_queue and site.has_method("_support_expand_piece"):
			var pool: Array=body.get_meta("pooled_fragments",[])
			if not pool.is_empty() and _expanded_this_frame>=1: break
			# Optional host hook may activate existing source tiles only. It must
			# not issue an explosion or mark_dirty inside this synchronous transfer.
			_transferring=true
			var fragments: Variant=site._support_expand_piece(body)
			_transferring=false
			if _revision!=revision: break
			if not fragments is Array or fragments.is_empty(): _bad("support_expansion_contract"); break
			if fragments.size()!=1 or fragments[0]!=body:
				if pool.is_empty() or fragments.size()!=pool.size() or _eligible(body,site): _bad("support_expansion_requires_exact_pool_and_retired_parent"); break
				var seen: Dictionary={}
				_expanded=[]; _expanded_cursor=0
				for chunk: Variant in fragments:
					if not _eligible(chunk,site) or not pool.has(chunk) or seen.has(chunk.get_instance_id()) or not site.pieces.has(chunk): _bad("support_expansion_foreign_or_inactive_chunk"); break
					seen[chunk.get_instance_id()]=true
					var chunk_bounds: Dictionary=_body_bounds(chunk,site)
					if not chunk_bounds.ok: _bad("support_expansion_collision"); break
					_expanded.append({"body":weakref(chunk),"frame":chunk.global_transform,"bounds":chunk_bounds.bounds,"contacts":chunk_bounds.contacts,"id":chunk.get_instance_id()})
				if not _error.is_empty(): break
				_pending_cursor+=1; _expanded_this_frame+=1
				continue
		if chunk_queue: _expanded_cursor+=1
		else: _pending_cursor+=1
		# Zero launch speed: native gravity causes the fall, with the original
		# lightweight body/material/pool behavior. No synthetic explosion receipt.
		_transferring=true
		site._release(body,body.global_position,0.0,Vector3.ZERO)
		_transferring=false
		body.set_meta("support_released",true)
		released+=1; _released_total+=1; _released_this_frame+=1
		if _revision!=revision: break
	if not _pending.is_empty() and _pending_cursor>=_pending.size() and _expanded_cursor>=_expanded.size():
		_pending.clear(); _pending_cursor=0; _expanded.clear(); _expanded_cursor=0; _dirty=true # One final ground-connectivity confirmation.
	var spent:=Time.get_ticks_usec()-started
	_max_advance_usec=maxi(_max_advance_usec,spent)
	_last.last_advance_usec=spent; _last.last_work_items=work; _last.last_released=released
	return diagnostics()

func diagnostics() -> Dictionary:
	var result: Dictionary=_last.duplicate()
	result.ok=_enabled and _error.is_empty(); result.error=_error
	result.busy=_dirty or not _job.is_empty() or _pending_cursor<_pending.size() or _expanded_cursor<_expanded.size()
	result.phase=_job.get("phase",""); result.pending=maxi(0,_pending.size()-_pending_cursor)+maxi(0,_expanded.size()-_expanded_cursor)
	result.released_total=_released_total; result.graphs=_graphs; result.advance_calls=_advance_calls; result.max_advance_usec=_max_advance_usec
	result.generation=_generation; result.support_model="ground_connected_collision_AABBs"; result.seam_m=SEAM_M
	result.narrow_phase="one_shape_pair_per_work_item_box_SAT"; result.convex_policy="per_shape_conservative_bounds"
	return result
