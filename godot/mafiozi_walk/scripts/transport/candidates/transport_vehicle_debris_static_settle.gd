extends "res://scripts/transport/transport_vehicle_wreck_debris.gd"
## Experimental post-settle state only. Geometry, visuals, materials, bodies and
## all 76 compound hulls are inherited unchanged. Once every launched body is
## naturally sleeping, the complete wreck becomes static while retaining hits.

var _static_settled:=false

func freeze_settled_static() -> Dictionary:
	if _disposed or _vehicle_root==null: return {"ok":false,"error":"not_configured"}
	if not _launched or _static_settled: return {"ok":false,"error":"not_launched_or_already_static"}
	if _bodies.size()!=_entries.size() or _bodies.is_empty(): return {"ok":false,"error":"body_layout"}
	for i in _bodies.size():
		var body:=_bodies[i] as RigidBody3D; var entry: Dictionary=_entries[i]
		if not is_instance_valid(body) or body!=entry.body or body.get_parent()!=_debris_parent or body.get_child_count()!=entry.collisions.size()+1: return {"ok":false,"error":"body_changed"}
		if not body.sleeping or body.freeze or body.collision_layer!=entry.layer or body.collision_mask!=entry.mask: return {"ok":false,"error":"NOT_SETTLED"}
		if not is_instance_valid(entry.template) or not entry.template.visible: return {"ok":false,"error":"visual_changed"}
	# Validation is complete before any body changes mode.
	for body: RigidBody3D in _bodies:
		body.freeze_mode=RigidBody3D.FREEZE_MODE_STATIC
		body.freeze=true
		body.sleeping=true
	_static_settled=true
	return {"ok":true,"state":"STATIC_SETTLED","bodies":_bodies.size(),"hulls":_hull_count(),"persistent":true}

func static_receipt() -> Dictionary:
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
