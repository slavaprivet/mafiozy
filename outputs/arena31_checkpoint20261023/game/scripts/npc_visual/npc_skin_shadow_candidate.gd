extends RefCounted
## Opt-in diagnostic candidate, NOT installed by cache/host.
## Disables only SKIN shadow reception to isolate shadow-map dots in Root's
## visual A/B. It also removes genuine received skin shadows, so GPU comparison
## and an explicit visual decision are mandatory before any lasting use.
var _rows: Array = []
var _active := false

func apply(visual: Node3D) -> Dictionary:
	if not Thread.is_main_thread() or _active: return {"ok":false,"reason":"lifetime"}
	if not is_instance_valid(visual) or visual.is_queued_for_deletion() or not visual.get_meta("npc_bridge_id","") is String or not str(visual.get_meta("npc_bridge_id","")).begins_with("npc_"): return {"ok":false,"reason":"npc_instance_required"}
	var pending: Array = []
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		if mesh.skin == null or mesh.material_override != null or mesh.material_overlay != null: continue
		for index in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(index)
			if not material is StandardMaterial3D or material.resource_name != "SKIN": continue
			if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL: return {"ok":false,"reason":"unsupported_skin"}
			var candidate := material.duplicate(true) as StandardMaterial3D
			candidate.resource_local_to_scene = true
			candidate.set_flag(BaseMaterial3D.FLAG_DONT_RECEIVE_SHADOWS,true)
			pending.append({"mesh":weakref(mesh),"surface":index,"prior":mesh.get_surface_override_material(index),"candidate":candidate})
	if pending.is_empty(): return {"ok":false,"reason":"skin_missing"}
	for row: Dictionary in pending: row.mesh.get_ref().set_surface_override_material(row.surface,row.candidate)
	_rows = pending; _active = true
	return {"ok":true,"skin_surfaces":_rows.size(),"diagnostic_only":true,"visual_accepted":false,"changes_shadow_reception":true,"changes_shadow_casting":false}

func restore() -> Dictionary:
	if not Thread.is_main_thread(): return {"ok":false,"reason":"thread"}
	var restored := 0
	var replaced := 0
	for row: Dictionary in _rows:
		var mesh: Variant = row.mesh.get_ref()
		if not is_instance_valid(mesh) or mesh.is_queued_for_deletion(): continue
		if mesh.get_surface_override_material(row.surface) != row.candidate:
			replaced += 1; continue # Preserve later owner's material replacement.
		mesh.set_surface_override_material(row.surface,row.prior); restored += 1
	_rows.clear(); _active = false
	return {"ok":true,"restored":restored,"owner_replaced":replaced}
