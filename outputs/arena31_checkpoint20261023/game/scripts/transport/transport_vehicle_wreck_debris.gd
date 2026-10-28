extends "res://scripts/transport/transport_vehicle_debris.gd"
## Wreck-lifetime cleanup. Frozen provider reset()/dispose() restores originals;
## source clearDebris removes flying copies while the wreck remains stripped.
## This subclass never invokes reset after launch.
var _wreck_retired:=false
var _static_settled:=false
## provider_indices refer to the original prewarmed order. The source index is
## carried separately by the host; no compaction is allowed in launch math.
func launch_selected(provider_indices: Array, motions: Array) -> Dictionary:
	if _disposed or _launched or not _ready: return {"ok":false,"error":"PREWARM_PENDING_OR_LAUNCHED"}
	if provider_indices.size()!=motions.size(): return {"ok":false,"error":"selection_size"}
	var previous:=-1
	var selected: Array=[]; var skipped: Array=[]
	for value in provider_indices:
		if not value is int or value<=previous or value<0 or value>=_entries.size(): return {"ok":false,"error":"selection_order"}
		previous=value
	for i in _entries.size():
		if provider_indices.has(i): selected.append(_entries[i])
		else: skipped.append(_entries[i])
	var all_entries:=_entries
	_entries=selected
	var launched: Dictionary=super.launch(motions)
	if not launched.get("ok",false):
		_entries=all_entries
		return launched
	# The frozen provider has validated all accepted sources and committed them.
	# Discard only the unused frozen bodies. Skipped source visibility is untouched.
	for entry: Dictionary in skipped:
		for collision: CollisionShape3D in entry.collisions:
			if is_instance_valid(collision) and collision.get_parent()==null: collision.free()
		var body: RigidBody3D=entry.body
		if is_instance_valid(body): body.free()
	return {"ok":true,"bodies":launched.bodies,"skipped":skipped.size(),"hulls":launched.hulls}

## Source detached parts stop updating permanently after settling. Preserve the
## complete real visual/collision wreck, but remove sleeping-body simulation only
## after every launched body has reached native sleep.
func settle_wreck() -> Dictionary:
	if _wreck_retired or _disposed: return {"ok":false,"error":"not_configured"}
	if not _launched or _static_settled: return {"ok":false,"error":"not_launched_or_already_settled"}
	if _bodies.size()!=_entries.size() or _bodies.is_empty(): return {"ok":false,"error":"body_layout"}
	for i in _bodies.size():
		var body:=_bodies[i] as RigidBody3D; var entry: Dictionary=_entries[i]
		if not is_instance_valid(body) or body!=entry.body or body.get_parent()!=_debris_parent or body.get_child_count()!=entry.collisions.size()+1: return {"ok":false,"error":"body_changed"}
		if not body.sleeping or body.freeze or body.collision_layer!=entry.layer or body.collision_mask!=entry.mask: return {"ok":false,"error":"NOT_SETTLED"}
		if not is_instance_valid(entry.template) or not entry.template.visible: return {"ok":false,"error":"visual_changed"}
	# Validate the whole wreck before changing any body.
	for body: RigidBody3D in _bodies:
		body.freeze_mode=RigidBody3D.FREEZE_MODE_STATIC
		body.freeze=true
		body.sleeping=true
	_static_settled=true
	return {"ok":true,"state":"STATIC_SETTLED","bodies":_bodies.size(),"hulls":_hull_count(),"persistent":true}

func settled_receipt() -> Dictionary:
	var valid:=_static_settled and _launched and _bodies.size()==_entries.size()
	if valid:
		for i in _bodies.size():
			var body:=_bodies[i] as RigidBody3D; var entry: Dictionary=_entries[i]
			if not is_instance_valid(body) or not body.freeze or body.freeze_mode!=RigidBody3D.FREEZE_MODE_STATIC or body.collision_layer!=entry.layer or body.collision_mask!=entry.mask or not is_instance_valid(entry.template) or not entry.template.visible:
				valid=false; break
	return {"ok":valid,"state":"STATIC_SETTLED" if valid else "CHANGED","bodies":_bodies.size(),"hulls":_hull_count() if not _entries.is_empty() else 0}

func reset() -> void:
	super.reset()
	_static_settled=false

func stats() -> Dictionary:
	var result: Dictionary=super.stats(); result["static_settled"]=_static_settled; return result

func retire_wreck() -> Dictionary:
	if _wreck_retired or _disposed: return {"ok":false,"error":"already_retired"}
	if not _launched: return {"ok":false,"error":"not_launched"}
	var hidden:=0; var freed:=0
	for entry: Dictionary in _entries:
		var source: Node3D=entry.source
		if is_instance_valid(source):
			source.visible=false
			hidden+=1
		for collision: CollisionShape3D in entry.collisions:
			if is_instance_valid(collision) and collision.get_parent()==null: collision.free()
		var body: RigidBody3D=entry.body
		if is_instance_valid(body):
			body.free(); freed+=1
	_entries.clear(); _bodies.clear()
	_vehicle_root=null; _debris_parent=null; _owner=null
	_ready=false; _disposed=true; _wreck_retired=true
	return {"ok":true,"hidden_originals":hidden,"freed_bodies":freed}
