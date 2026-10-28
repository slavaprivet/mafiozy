extends RefCounted
## Isolated host-receipt adapter. The host owns event identity, lifetime and RNG.
## This component never creates an authoritative damage or random event.
const Damage=preload("res://scripts/transport/transport_vehicle_damage_state.gd")
const Bindings=preload("res://scripts/transport/transport_vehicle_damage_bindings.gd")
const Launch=preload("res://scripts/transport/transport_vehicle_debris_launch.gd")
const Debris=preload("res://scripts/transport/transport_vehicle_wreck_debris.gd")

var _authority: RefCounted
var _vehicle_id: String
var _generation: int
var _revision:=0
var _state: Dictionary={}
var _ordered: Array=[]
var _copied_visibility: Array=[]
var _contact_events: Array[String]=[]
var _debris: RefCounted
var _vehicle_root: Node3D
var _geometry_invalidated:=false
var _wreck_retired:=false
var _disposed:=false

## The capability object must be retained privately by the authoritative host.
## All receipt dictionaries are untrusted even when they carry that capability.
func configure(authority: RefCounted, vehicle_id: String, generation: int, visual: RefCounted, oracle_row: Dictionary, debris_parent: Node3D, physical: Dictionary, owner: CollisionObject3D=null, max_hp: float=240.0, armor: float=1.0) -> Dictionary:
	if _disposed or _authority!=null: return {"ok":false,"error":"already_configured"}
	if authority==null or vehicle_id.is_empty() or generation<1 or visual==null: return {"ok":false,"error":"identity"}
	var bound: Dictionary=Bindings.bind(visual,oracle_row)
	if not bound.get("ok",false): return bound
	var state:=Damage.create(max_hp,armor)
	if state.is_empty(): return {"ok":false,"error":"damage_config"}
	var root_node:=visual.get("root") as Node3D
	if not is_instance_valid(root_node) or not is_instance_valid(debris_parent): return {"ok":false,"error":"scene"}
	var ordered: Array=[]
	var provider_rows: Array=[]
	for item: Dictionary in bound.explosion:
		var source: Node3D=item.source
		# Prewarm every construction-eligible root. A post-callback phase receipt
		# selects a subset without renumbering these original source indices.
		if not is_instance_valid(source): return {"ok":false,"error":"assembly_lifetime"}
		var provider_index: int=provider_rows.size() if item.copy_eligible_at_export else -1
		ordered.append({"source":source,"source_index":int(item.source_index),"provider_index":provider_index,"copy_eligible_at_export":item.copy_eligible_at_export})
		if not item.copy_eligible_at_export: continue
		if not source.visible: return {"ok":false,"error":"initial_source_hidden"}
		provider_rows.append({"source":source,"mass_kg":physical.get("mass_kg"),"collision_layer":physical.get("collision_layer"),"collision_mask":physical.get("collision_mask"),"linear_damp":physical.get("linear_damp"),"angular_damp":physical.get("angular_damp"),"friction":physical.get("friction"),"bounce":physical.get("bounce")})
	if ordered.is_empty(): return {"ok":false,"error":"no_copyable_assemblies"}
	var debris:=Debris.new()
	var prepared: Dictionary=debris.configure(root_node,debris_parent,provider_rows,owner)
	if not prepared.get("ok",false):
		debris.dispose()
		return prepared
	_authority=authority; _vehicle_id=vehicle_id; _generation=generation
	_state=state; _ordered=ordered; _debris=debris; _vehicle_root=root_node
	return {"ok":true,"assemblies":provider_rows.size(),"source_slots":ordered.size(),"hulls":prepared.hulls,"vertices":prepared.vertices}

func prewarm_step(budget: int=1) -> Dictionary:
	if _disposed or _debris==null: return {"ok":false,"error":"not_configured"}
	if _geometry_invalidated: return {"ok":false,"error":"GEOMETRY_INVALIDATED"}
	return _debris.prewarm_step(budget)

## Call BEFORE every deformation or in-place source vertex write. Cached convex
## hulls are permanently retired for this vehicle lifetime; create a fresh
## instance only from a new host binding/geometry revision. No later blast can
## launch the stale hulls, even when a write keeps the same Mesh resource ID.
func invalidate_geometry() -> Dictionary:
	if _disposed or _debris==null: return {"ok":false,"error":"not_configured"}
	if _geometry_invalidated: return {"ok":false,"error":"GEOMETRY_INVALIDATED"}
	if _debris.stats().launched: return {"ok":false,"error":"already_launched"}
	_geometry_invalidated=true
	if not _debris.invalidate_geometry(): return {"ok":false,"error":"provider_invalidation"}
	return {"ok":true,"error":"GEOMETRY_INVALIDATED"}

## Host receipt: {authority,vehicle_id,life_generation,revision,kind,event_id,
## damage|impact_mps|dt,prior_hp,prior_explosions}. On the sole explosion edge:
## {phase_receipt:{authority,vehicle_id,life_generation,revision,
## phase:"post_char_callback_glass",char_applied:true,
## callback_completed:true,glass_applied:true,
## rows:[{source_index,source,outcome:"copy|hidden|transparent|ineligible"}]},
## draw_groups:[{source_index,draws:[seven host RNG values],signed_speed_mps,
## travel_yaw_native}]}. Per-root motion is sampled by the host after draw2.
## No RNG or callback is sampled here.
func accept(receipt: Dictionary) -> Dictionary:
	if _disposed or _authority==null or _debris==null: return {"ok":false,"error":"not_configured"}
	if receipt.get("authority")!=_authority or receipt.get("vehicle_id")!=_vehicle_id or receipt.get("life_generation")!=_generation or not receipt.get("revision") is int or receipt.revision!=_revision+1:
		return {"ok":false,"error":"authority_or_order"}
	if receipt.get("prior_hp")!=_state.hp or receipt.get("prior_explosions")!=_state.explosions:
		return {"ok":false,"error":"prior_state"}
	var next: Dictionary={}
	match receipt.get("kind"):
		"gun", "rpg":
			if not receipt.get("event_id") is String or receipt.event_id.is_empty() or not _number(receipt.get("damage")) or float(receipt.damage)<=0.0:
				return {"ok":false,"error":"damage_receipt"}
			next=Damage.apply(_state,float(receipt.damage),receipt.event_id,receipt.kind)
			if next==_state: return {"ok":false,"error":"duplicate_or_terminal"}
		"collision":
			if not receipt.get("event_id") is String or receipt.event_id.is_empty() or _contact_events.has(receipt.event_id) or not _number(receipt.get("impact_mps")) or float(receipt.impact_mps)<=0.0: return {"ok":false,"error":"collision_receipt"}
			next=Damage.collision(_state,float(receipt.impact_mps))
			if next==_state: return {"ok":false,"error":"no_contact_damage"}
		"step":
			if not _number(receipt.get("dt")) or float(receipt.dt)<0.0: return {"ok":false,"error":"clock_receipt"}
			next=Damage.step(_state,float(receipt.dt))
		_: return {"ok":false,"error":"kind"}
	if next.is_empty() or next.explosions<_state.explosions or next.explosions>_state.explosions+1: return {"ok":false,"error":"explosion_state"}
	var launched:=false
	if next.explosions>_state.explosions:
		var motion_result:=_explosion_motions(receipt)
		if not motion_result.ok: return motion_result
		var result: Dictionary=_debris.launch_selected(motion_result.provider_indices,motion_result.motions)
		if not result.get("ok",false): return result
		_copied_visibility=motion_result.copied_visibility
		launched=true
	elif receipt.has("draw_groups"):
		return {"ok":false,"error":"unexpected_rng"}
	_state=next; _revision=receipt.revision
	if receipt.kind=="collision":
		_contact_events.append(receipt.event_id)
		if _contact_events.size()>64: _contact_events.pop_front()
	return {"ok":true,"revision":_revision,"state":_state.duplicate(true),"launched":launched,"bodies":_debris.bodies().size()}

func _explosion_motions(receipt: Dictionary) -> Dictionary:
	if _geometry_invalidated: return {"ok":false,"error":"GEOMETRY_INVALIDATED"}
	if not _debris.stats().ready: return {"ok":false,"error":"PREWARM_PENDING"}
	if not receipt.get("draw_groups") is Array or not receipt.get("phase_receipt") is Dictionary:
		return {"ok":false,"error":"blast_receipt"}
	var phase: Dictionary=receipt.phase_receipt
	if phase.get("authority")!=_authority or phase.get("vehicle_id")!=_vehicle_id or phase.get("life_generation")!=_generation or phase.get("revision")!=receipt.revision or phase.get("phase")!="post_char_callback_glass" or phase.get("char_applied")!=true or phase.get("callback_completed")!=true or phase.get("glass_applied")!=true or not phase.get("rows") is Array or phase.rows.size()!=_ordered.size():
		return {"ok":false,"error":"phase_authority"}
	if not is_instance_valid(_vehicle_root) or not _vehicle_root.is_inside_tree(): return {"ok":false,"error":"vehicle_lifetime"}
	var motions: Array=[]; var provider_indices: Array=[]; var copied_visibility: Array=[]; var draw_cursor:=0
	var origin: Vector3=_vehicle_root.global_position
	for i in _ordered.size():
		var phase_row: Variant=phase.rows[i]
		var item: Dictionary=_ordered[i]
		var source: Node3D=item.source
		if not phase_row is Dictionary or phase_row.get("source_index")!=item.source_index or phase_row.get("source")!=source or not is_instance_valid(source) or not _vehicle_root.is_ancestor_of(source): return {"ok":false,"error":"phase_order_or_source"}
		var transparent: bool=_direct_scalar_transparent(source)
		var ineligible: bool=not item.copy_eligible_at_export or source.get_meta("source_copy_ineligible",false)==true
		match phase_row.get("outcome"):
			"hidden":
				if source.visible: return {"ok":false,"error":"phase_hidden_mismatch"}
				continue
			"transparent":
				if not source.visible or not transparent or ineligible: return {"ok":false,"error":"phase_transparent_mismatch"}
				continue
			"ineligible":
				if not source.visible or not ineligible: return {"ok":false,"error":"phase_ineligible_mismatch"}
				continue
			"copy":
				if not source.visible or transparent or ineligible or item.provider_index<0: return {"ok":false,"error":"phase_copy_mismatch"}
			_: return {"ok":false,"error":"phase_outcome"}
		if draw_cursor>=receipt.draw_groups.size(): return {"ok":false,"error":"draw_count"}
		var group: Variant=receipt.draw_groups[draw_cursor]
		if not group is Dictionary or group.get("source_index")!=item.source_index or not group.get("draws") is Array or not _number(group.get("signed_speed_mps")) or not _number(group.get("travel_yaw_native")):
			return {"ok":false,"error":"blast_draw_order"}
		var offset: Vector3=source.global_position-origin
		var plan: Dictionary=Launch.explosion(item.source_index,offset,float(group.signed_speed_mps),float(group.travel_yaw_native),group.draws)
		if not plan.get("ok",false): return {"ok":false,"error":"blast_draws"}
		motions.append({"linear_velocity":plan.linear_velocity_mps,"angular_velocity":plan.angular_velocity_rad_s})
		provider_indices.append(item.provider_index)
		copied_visibility.append({"source":source,"visible":source.visible})
		draw_cursor+=1
	if draw_cursor!=receipt.draw_groups.size(): return {"ok":false,"error":"draw_count"}
	return {"ok":true,"motions":motions,"provider_indices":provider_indices,"copied_visibility":copied_visibility,"accepted":draw_cursor}

static func _direct_scalar_transparent(source: Node3D) -> bool:
	if not source is MeshInstance3D: return false
	var mesh_node:=source as MeshInstance3D
	var material: Material=mesh_node.material_override
	if material==null and mesh_node.mesh!=null and mesh_node.mesh.get_surface_count()==1:
		material=mesh_node.mesh.surface_get_material(0)
	return material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED

func state() -> Dictionary: return _state.duplicate(true)
func revision() -> int: return _revision
func bodies() -> Array: return _debris.bodies() if _debris!=null else []
## Source parts stop updating after natural settlement. This keeps every real
## visual and exact compound hull queryable while removing sleeping simulation.
func settle_wreck() -> Dictionary:
	if _disposed or _debris==null: return {"ok":false,"error":"not_configured"}
	if _wreck_retired: return {"ok":false,"error":"already_retired"}
	return _debris.settle_wreck()
## Source clearDebris: remove flying pieces, leave the stripped wreck visible.
func retire_wreck() -> Dictionary:
	if _disposed or _debris==null: return {"ok":false,"error":"not_configured"}
	if _wreck_retired: return {"ok":false,"error":"already_retired"}
	var result: Dictionary=_debris.retire_wreck()
	if result.get("ok",false): _wreck_retired=true
	return result

## Source onReset/respawn: restore originals, retire this adapter lifetime.
## A fresh host generation must bind a new adapter for the new vehicle.
func reset_for_respawn() -> Dictionary:
	if _disposed or _debris==null: return {"ok":false,"error":"not_configured"}
	var restored:=_copied_visibility.size()
	if _wreck_retired:
		for item: Dictionary in _copied_visibility:
			var source: Node3D=item.source
			if is_instance_valid(source): source.visible=item.visible
	else:
		_debris.dispose()
	_clear()
	return {"ok":true,"restored_originals":restored}

## Generic teardown is valid before launch only. A launched wreck requires an
## explicit choice between retire_wreck and reset_for_respawn.
func dispose() -> Dictionary:
	if _disposed: return {"ok":false,"error":"already_disposed"}
	if _debris!=null and _debris.stats().launched and not _wreck_retired:
		return {"ok":false,"error":"wreck_requires_explicit_lifecycle"}
	if _debris!=null and not _wreck_retired: _debris.dispose()
	_clear()
	return {"ok":true}

func _clear() -> void:
	_authority=null; _ordered.clear(); _copied_visibility.clear(); _contact_events.clear(); _state.clear(); _vehicle_root=null; _debris=null; _disposed=true
static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
