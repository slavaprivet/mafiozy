extends RefCounted
## Only completed current local HP receipts can produce cosmetic blood.
## Call receive synchronously in _on_native_impact after the HP result succeeds.
const Renderer=preload("npc_blood_renderer.gd")
var renderer: RefCounted
var _host: RefCounted
var _owner: RefCounted
var _token: Dictionary={}
var _binding: Dictionary={}
var _last_revision:=0
var _retired:=false
var _idle_checked_at_usec: int=-1

func configure(host: RefCounted, token: Dictionary, owner: RefCounted, parent: Node3D, prepared_entry: Dictionary) -> bool:
	if renderer!=null or _retired or not is_instance_valid(host) or not is_instance_valid(owner) or not host.physical_life_current(token): return false
	if prepared_entry.get("descriptor_sha256")!=token.get("descriptor_sha256") or prepared_entry.get("bridge_id")!=token.get("render_id"): return false
	var normalization: Dictionary=prepared_entry.get("normalization",{})
	if not normalization.has("scale") or not normalization.has("target_height") or not normalization.has("source_height"): return false
	var unit:=float(normalization.scale)
	var source_height:=float(normalization.source_height)
	var target_height:=float(normalization.target_height)
	if not is_finite(source_height) or source_height<=0 or not is_finite(unit) or not is_finite(target_height) or absf(unit-target_height/source_height)>1e-10: return false
	_host=host; _owner=owner; _token=token.duplicate(); _binding=owner._binding.duplicate(true)
	if _binding.get("owner_instance_id")!=owner.get_instance_id() or _binding.get("source_id")!=token.get("source_id") or _binding.get("life_generation")!=token.get("life_generation") or owner._current(_binding).is_empty(): return false
	renderer=Renderer.new()
	return renderer.configure(parent,token.body,token.rig,unit,target_height)

func _current() -> bool:
	# The exact same owner/host/token calls physical_life_current inside its
	# _current method. Keep that lease check once; never skip it on idle frames.
	return not _retired and renderer!=null and is_instance_valid(_host) and is_instance_valid(_owner) and _owner._host==_host and _owner._token==_token and not _owner._current(_binding).is_empty()

func receive(event_id: String, point: Vector3, normal: Vector3) -> bool:
	if not _current(): retire(); return false
	if event_id.is_empty() or not point.is_finite() or not normal.is_finite() or normal.length_squared()<.5: return false
	var receipt: Dictionary=_owner._adapter.receipt(event_id)
	# Receipt must be the owner's latest completed transaction, never its queued
	# bleeding/death_blood callback (a later source callback may still fail).
	if receipt.is_empty() or receipt!=_owner.last_result or receipt.get("binding")!=_binding or receipt.get("event_id")!=event_id: return false
	if not receipt.get("ok",false) or not receipt.get("applied",false) or receipt.get("reason") not in ["hit","surrender","medical_downed","final_death"]: return false
	var revision:=int(receipt.get("revision",0))
	var damage:=float(receipt.get("hit",{}).get("damage",0))
	var now:=float(receipt.get("source_now_ms",-1))*.001
	if revision<=_last_revision or not is_finite(damage) or damage<=0 or not is_finite(now) or now<0: return false
	var contact: Dictionary=_owner.last_contact
	if contact.get("event_id")!=event_id or contact.get("point")!=point or contact.get("normal")!=normal or contact.get("source_id")!=_token.source_id or contact.get("life_generation")!=_token.life_generation: return false
	if not contact.get("actor_transform_at_impact") is Transform3D or not contact.get("incoming_direction") is Vector3: return false
	var before: Transform3D=contact.actor_transform_at_impact
	if not before.is_finite() or absf(before.basis.determinant())<1e-9: return false
	var frame: Transform3D=_token.body.global_transform*before.affine_inverse()
	var attached_point: Vector3=frame*point
	var attached_normal: Vector3=(frame.basis.inverse().transposed()*normal).normalized()
	var incoming: Vector3=(frame.basis*contact.incoming_direction).normalized()
	if _owner.marks==null or _owner.marks.renderer==null: return false
	var surface: RefCounted=_owner.marks.renderer
	var anchor: Dictionary={}
	if contact.get("contact_kind")=="melee":
		anchor={"surface_index":contact.get("surface_index"),"face_indices":contact.get("face_indices"),"barycentric":contact.get("barycentric")}
	else:
		anchor=surface.contact_anchor_from_ray(attached_point,incoming,renderer._height*1.5)
	if anchor.is_empty(): return false
	var sampled: Dictionary=surface.sample_surface_anchor(anchor)
	if sampled.is_empty(): return false
	if contact.get("contact_kind")=="melee" and sampled.point.distance_to(attached_point)>.15*renderer._unit: return false
	if not _current(): retire(); return false
	_last_revision=revision
	var heavy: bool=contact.get("contact_kind")=="melee" and receipt.hit.get("attack_type") in ["heavy","dropkick"]
	renderer.accept(sampled.point,attached_normal,now,heavy,Callable(surface,"sample_surface_anchor"),anchor)
	return true

## Scheduler hint only; receive/step still perform the full current lease.
## A generation replacement without disposal can retain only an empty pool
## for at most250ms. Ordinary owner disposal still frees the pool immediately.
func should_step() -> bool:
	if _retired or renderer==null: return false
	if not is_instance_valid(_owner) or not _owner._ready: return true
	if renderer._has_particles or not renderer._wounds.is_empty(): return true
	return _idle_checked_at_usec<0 or Time.get_ticks_usec()-_idle_checked_at_usec>=250000

func step(delta: float) -> void:
	if not _current(): retire(); return
	_idle_checked_at_usec=Time.get_ticks_usec()
	renderer.update(delta,float(_owner._now())*.001,_token.body.global_position.y)

func retire() -> void:
	_retired=true
	if renderer!=null: renderer.dispose()
	renderer=null; _owner=null; _host=null; _token.clear(); _binding.clear()

func dispose() -> void:
	retire()
